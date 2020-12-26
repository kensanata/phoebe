# -*- mode: perl -*-
# Copyright (C) 2017–2020  Alex Schroeder <alex@gnu.org>

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

package App::Phoebe;
use Modern::Perl;
use List::Util qw(sum);

our (@extensions, $log);

our @known_fingerprints = qw(
  sha256$54c0b95dd56aebac1432a3665107d3aec0d4e28fef905020ed6762db49e84ee1);

=head1 Speed Bump

We want to block crawlers that are too fast or that don't follow the
instructions in robots.txt. We do this by keeping a list of recent visitors: for
every IP number, we remember the timestamps of their last visits. If they make
more than 30 requests in 60s, we block them for an ever increasing amount of
seconds, starting with 60s and doubling every time this happens.

The exact number of requests and the length of this time window (in seconds) can
be changed in the config file.

    our $speed_bump_requests = 20;
    our $speed_bump_window = 20;

=cut

our $speed_bump_requests = 30;
our $speed_bump_window = 60;

# $speed_data->{$ip}->{visits} = [$last, ... , $oldest]
# $speed_data->{$ip}->{warnings} = [1, ... , 0]
# $speed_data->{$ip}->{seconds} = $sec
# $speed_data->{$ip}->{until} = $ts
# $speed_data->{$ip}->{probation} = $ts + $sec
my $speed_data;

# order is important: we must be able to reset the stats for tests
push(@extensions, \&speed_bump_admin, \&speed_bump);

sub speed_bump {
  my ($stream, $url) = @_;
  my $now = time;
  # go through the data we keep and delete it if the two time limits ellapsed
  # and the last visit is past the time window we're interested in
  for my $ip (keys %$speed_data) {
    if ((not $speed_data->{$ip}->{until}
	 or $speed_data->{$ip}->{until} < $now)
	and (not $speed_data->{$ip}->{probation}
	     or $speed_data->{$ip}->{probation} < $now)
	and (not $speed_data->{$ip}->{visits}
	     or $speed_data->{$ip}->{visits}->[0] < $now - $speed_bump_window)) {
      delete($speed_data->{$ip});
    }
  }
  # check if we are currently blocked
  my $ip = $stream->handle->peerhost;
  if (exists $speed_data->{$ip}) {
    my $until = $speed_data->{$ip}->{until};
    if ($until and $until > $now) {
      my $seconds = speed_bump_add($ip, $now);
      $log->debug("Extending the block by $seconds");
      my $delta = $speed_data->{$ip}->{until} - $now;
      $stream->write("44 $delta\r\n");
      # no more processing
      return 1;
    }
  }
  # add a timestamp to the front for the current $ip
  unshift(@{$speed_data->{$ip}->{visits}}, $now);
  # add a warning to the front for the current $ip if the current URL could be a bot
  unshift(@{$speed_data->{$ip}->{warnings}},
	  scalar $url =~ m!/(raw|html|diff|history|do/(?:comment|do/(?:all/(?:latest/)?)?changes/|rss|(?:all)?atom|new|more|match|search|index|tag))/!);
  # if there are enough timestamps, pop the last one and see if it falls within
  # the time window; if so, all the requests happened within the time window
  # we're watching
  if (@{$speed_data->{$ip}->{visits}} > $speed_bump_requests) {
    pop(@{$speed_data->{$ip}->{warnings}});
    my $oldest = pop(@{$speed_data->{$ip}->{visits}});
    if ($now < $oldest + $speed_bump_window) {
      my $seconds = speed_bump_add($ip, $now);
      $log->debug("Block for $seconds because of too many requests");
      $stream->write("44 $seconds\r\n");
      # no more processing
      return 1;
    }
  }
  # even if the browsing speed is ok, we want to block you if you're visiting a
  # lot of URLs that a human would not
  my $warnings = sum(@{$speed_data->{$ip}->{warnings}}) || 0;
  if ($warnings > $speed_bump_requests / 3) {
    my $seconds = speed_bump_add($ip, $now);
    $log->debug("Block for $seconds because of too many suspicious requests");
    $stream->write("44 $seconds\r\n");
    # no more processing
    return 1;
  }
  # maintenance is done and no block was required, carry on
  return 0;
}

sub speed_bump_add {
  my $ip = shift;
  my $now = shift;
  # if so, we're going to block you, and if you're a repeating offender, we're
  # going to double the block
  my $probation = $speed_data->{$ip}->{probation};
  # the default block time is 60s for first time offenders
  my $seconds = $speed_data->{$ip}->{seconds} || 60;
  # if this happened within the probation time, double the block time
  $seconds *= 2 if $seconds and $probation and $probation > $now;
  # protect against integer overflows, haha: 1y is 365*24*60*60 = 31536000
  $seconds = 31536000 if $seconds > 31536000;
  $speed_data->{$ip}->{seconds} = $seconds;
  $speed_data->{$ip}->{until} = $now + $seconds;
  $speed_data->{$ip}->{probation} = $now + 2 * $seconds;
  return $seconds;
}

sub speed_bump_admin {
  my $stream = shift;
  my $url = shift;
  my $hosts = host_regex();
  my $port = port($stream);
  if ($url =~ m!^gemini://(?:$hosts)(?::$port)?/do/speed-bump/reset$!) {
    with_speed_bump_fingerprint($stream, sub {
      $speed_data = undef;
      success($stream);
      $stream->write("Speed Bump Reset\n");
      $stream->write("The speed bump data has been reset.\n");
      $stream->write("=> status Show speed bump status\n") });
    return 1;
  } elsif ($url =~ m!^gemini://(?:$hosts)(?::$port)?/do/speed-bump/status$!) {
    with_speed_bump_fingerprint($stream, sub {
      success($stream);
      speed_bump_status($stream) });
    return 1;
  } elsif ($url =~ m!^gemini://(?:$hosts)(?::$port)?/do/speed-bump/debug$!) {
    with_speed_bump_fingerprint($stream, sub {
      success($stream, 'text/plain; charset=UTF-8');
      use Data::Dumper;
      $stream->write(Dumper($speed_data)) });
    return 1;
  }
  return;
}

sub with_speed_bump_fingerprint {
  my $stream = shift;
  my $fun = shift;
  my $fingerprint = $stream->handle->get_fingerprint();
  if ($fingerprint and grep { $_ eq $fingerprint} @known_fingerprints) {
    $fun->();
  } elsif ($fingerprint) {
    $log->info("Unknown client certificate $fingerprint");
    $stream->write("61 Your client certificate is not authorised for speed bump administration\r\n");
  } else {
    $log->info("Requested client certificate");
    $stream->write("60 You need an authorised client certificate to administer speed bumps\r\n");
  }
}

sub speed_bump_status {
  my $stream = shift;
  $stream->write("# Speed Bump Status\n");
  my $now = time;
  $stream->write("```\n");
  #               <-4s> <-4s> <2/2> <-4s> <-4s>    <-4s>
  $stream->write(" From    To Warns Block Until Probation IP\n");
  for my $ip (keys %$speed_data) {
    $stream->write(sprintf("%s %s %2d/%2d %s %s     %s $ip\n",
			   speed_bump_time($speed_data->{$ip}->{visits}->[-1], $now),
			   speed_bump_time($speed_data->{$ip}->{visits}->[0], $now),
			   sum(@{$speed_data->{$ip}->{warnings}}) || 0,
			   scalar(@{$speed_data->{$ip}->{warnings}}) || 0,
			   speed_bump_time($speed_data->{$ip}->{seconds}),
			   speed_bump_time($speed_data->{$ip}->{until}, $now),
			   speed_bump_time($speed_data->{$ip}->{probation}, $now)));
    # use Net::Whois::IP qw(whoisip_query); my $response = whoisip_query($ip); $response->{OrgName};
  }
  $stream->write("```\n");
  $stream->write("=> debug Debug speed bumps\n");
  $stream->write("=> reset Reset speed bumps\n");
}

sub speed_bump_time {
  my $seconds = shift;
  my $now = shift;
  return "  n/a" unless $seconds;
  $seconds -= $now if $now;
  return sprintf("%4dd", int($seconds/86400)) if abs($seconds) > 172800; # 2d
  return sprintf("%4dh", int($seconds/3600)) if abs($seconds) > 7200; # 2h
  return sprintf("%4dm", int($seconds/60)) if abs($seconds) > 120; # 2min
  return sprintf("%4ds", $seconds);
}
