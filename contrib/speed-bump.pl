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

# $speed_data->{visitors}->{$ip} = [$last, ... , $oldest]
# $speed_data->{warnings}->{$ip} = [1, ... , 0]
# $speed_data->{blocks}->{$ip}->{seconds} = $sec
# $speed_data->{blocks}->{$ip}->{until} = $ts
# $speed_data->{blocks}->{$ip}->{probation} = $ts + $sec
my $speed_data;

# order is important: we must be able to reset the stats for tests
push(@extensions, \&speed_bump_admin, \&speed_bump);

sub speed_bump {
  my ($stream, $url) = @_;
  my $now = time;
  # go through all the blocks we kept and delete the old data
  for my $ip (keys %{$speed_data->{blocks}}) {
    # delete the time limits if they are in the past
    if ($speed_data->{blocks}->{$ip}->{until} and $speed_data->{blocks}->{$ip}->{until} < $now) {
      delete($speed_data->{blocks}->{$ip}->{until});
    }
    # if the probation period elapsed, delete all the info
    if ($speed_data->{blocks}->{$ip}->{probation} and $speed_data->{blocks}->{$ip}->{probation} < $now) {
      delete($speed_data->{blocks}->{$ip});
    }
  }
  # go through all the request time stamps and delete data outside the time window
  for my $ip (keys %{$speed_data->{visitors}}) {
    # if the latest visit was longer ago than the time window, forget it
    if (not $speed_data->{visitors}->{$ip}
	or $speed_data->{visitors}->{$ip}->[0] + $speed_bump_window < $now) {
      delete($speed_data->{visitors}->{$ip});
      delete($speed_data->{warnings}->{$ip});
    }
  }
  # check if we are currently blocked now that maintenance is done
  my $ip = $stream->handle->peerhost;
  if (exists $speed_data->{blocks}->{$ip}) {
    my $until = $speed_data->{blocks}->{$ip}->{until};
    if ($until and $until > $now) {
      $log->debug("Extending a block");
      my $seconds = $speed_data->{blocks}->{$ip}->{seconds};
      $speed_data->{blocks}->{$ip}->{probation} += 2 * $seconds;
      $speed_data->{blocks}->{$ip}->{until} += $seconds;
      $until = $speed_data->{blocks}->{$ip}->{until};
      my $delta = $until - $now;
      $stream->write("44 $delta\r\n");
      # no more processing
      return 1;
    }
  }
  # add a timestamp to the front for the current $ip
  unshift(@{$speed_data->{visitors}->{$ip}}, $now);
  # add a warning to the front for the current $ip if the current URL could be a bot
  unshift(@{$speed_data->{warnings}->{$ip}}, scalar $url =~ m!/(raw|html|diff|history|do/(?:comment|do/(?:all/(?:latest/)?)?changes/|rss|(?:all)?atom|new|more|match|search|index|tag))/!);
  # if there are enough timestamps, pop the last one and see if it falls within
  # the time window
  if (@{$speed_data->{visitors}->{$ip}} > $speed_bump_requests) {
    pop(@{$speed_data->{warnings}->{$ip}}); # ignore: we just want the same number in both arrays
    my $oldest = pop(@{$speed_data->{visitors}->{$ip}});
    if ($now < $oldest + $speed_bump_window) {
      my $seconds = speed_bump_add($ip, $now);
      $stream->write("44 $seconds\r\n");
      # no more processing
      return 1;
    }
  }
  # even if the browsing speed is ok, we want to block you if you're visiting a
  # lot of URLs that a human would not
  my $warnings = sum(@{$speed_data->{warnings}->{$ip}}) || 0;
  if ($warnings > $speed_bump_requests / 3) {
    my $seconds = speed_bump_add($ip, $now);
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
  $log->debug("Adding peer block");
  # if so, we're going to block you, and if you're a repeating offender, we're
  # going to double the block
  my $probation = $speed_data->{blocks}->{$ip}->{probation};
  my $seconds = $speed_data->{blocks}->{$ip}->{seconds};
  $seconds *= 2 if $seconds and $probation and $probation > $now;
  $seconds ||= 60; # the default for first time offenders
  $speed_data->{blocks}->{$ip}->{seconds} = $seconds;
  $speed_data->{blocks}->{$ip}->{until} = $now + $seconds;
  $speed_data->{blocks}->{$ip}->{probation} = $now + 2 * $seconds;
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
  # get a list of unique IPs
  my %ips;
  for my $item (qw(visitors warnings blocks)) {
    for my $ip (keys %{$speed_data->{$item}}) {
      $ips{$ip} = 1;
    }
  }
  my $now = time;
  $stream->write("```\n");
  #               <-4s> <-4s> <2/2> <-4s> <-4s>    <-4s>
  $stream->write(" From    To Warns Block Until Probation IP\n");
  for my $ip (keys %ips) {
    $stream->write(sprintf("%s %s %2d/%2d %s %s     %s $ip\n",
			   $speed_data->{visitors}->{$ip}
			   ? speed_bump_time($speed_data->{visitors}->{$ip}->[-1] - $now)
			   : " n/a ",
			   $speed_data->{visitors}->{$ip}
			   ? speed_bump_time($speed_data->{visitors}->{$ip}->[0] - $now)
			   : " n/a ",
			   sum(@{$speed_data->{warnings}->{$ip}}) || 0,
			   scalar(@{$speed_data->{warnings}->{$ip}}) || 0,
			   $speed_data->{blocks}->{$ip}
			   ? speed_bump_time($speed_data->{blocks}->{$ip}->{seconds})
			   : " n/a ",
			   $speed_data->{blocks}->{$ip} && $speed_data->{blocks}->{$ip}->{until}
			   ? speed_bump_time($speed_data->{blocks}->{$ip}->{until} - $now)
			   : " n/a ",
			   $speed_data->{blocks}->{$ip} && $speed_data->{blocks}->{$ip}->{probation}
			   ? speed_bump_time($speed_data->{blocks}->{$ip}->{probation} - $now)
			   : " n/a "));
    # use Net::Whois::IP qw(whoisip_query); my $response = whoisip_query($ip); $response->{OrgName};
  }
  $stream->write("```\n");
  $stream->write("=> debug Debug speed bumps\n");
  $stream->write("=> reset Reset speed bumps\n");
}

sub speed_bump_time {
  my $seconds = shift;
  return sprintf("%4dh", int($seconds/3600)) if $seconds > 7200; # 2h
  return sprintf("%4dm", int($seconds/60)) if $seconds > 120; # 2min
  return sprintf("%4ds", $seconds);
}
