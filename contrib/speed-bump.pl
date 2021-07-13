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
use File::Slurper qw(read_binary write_binary);
use List::Util qw(sum);
use Mojo::JSON qw(decode_json encode_json);
use Net::IP;
use Net::DNS qw(rr);
our (@extensions, $log, $server);

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
# $speed_cidr_data->{$cidr} = $ts
my $speed_cidr_data;

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
	and (not @{$speed_data->{$ip}->{visits}}
	     or $speed_data->{$ip}->{visits}->[0] < $now - $speed_bump_window)) {
      delete($speed_data->{$ip});
    }
  }
  for my $cidr (keys %$speed_cidr_data) {
    delete($speed_cidr_data->{$cidr}) if $speed_cidr_data->{$cidr} < $now;
  }
  # check whether the range is blocked
  my $ip = $stream->handle->peerhost;
  my $ob = new Net::IP($ip);
  for my $cidr (keys %$speed_cidr_data) {
    my $range = new Net::IP($cidr) or $log->error(Net::IP::Error());
    my $overlap = $range->overlaps($ob);
    # $IP_PARTIAL_OVERLAP (ranges overlap) $IP_NO_OVERLAP (no overlap)
    # $IP_A_IN_B_OVERLAP (range2 contains range1) $IP_B_IN_A_OVERLAP (range1
    # contains range2) $IP_IDENTICAL (ranges are identical) undef (problem)
    if (defined $overlap and $overlap != $IP_NO_OVERLAP) {
      $log->info("Net range $cidr is blocked");
      my $delta = $speed_cidr_data->{$cidr} - $now;
      result($stream, "44", "$delta");
      # no more processing
      return 1;
    }
  }
  # check if the ip is currently blocked and extend the block if so
  if (exists $speed_data->{$ip}) {
    my $until = $speed_data->{$ip}->{until};
    if ($until and $until > $now) {
      my $seconds = speed_bump_add($ip, $now);
      $log->info("IP is blocked, extending by $seconds");
      my $delta = $speed_data->{$ip}->{until} - $now;
      result($stream, "44", "$delta");
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
      $log->info("Blocked for $seconds because of too many requests");
      result($stream, "44", "$seconds");
      # no more processing
      return 1;
    }
  }
  # even if the browsing speed is ok, we want to block you if you're visiting a
  # lot of URLs that a human would not
  my $warnings = sum(@{$speed_data->{$ip}->{warnings}}) || 0;
  if ($warnings > $speed_bump_requests / 3) {
    my $seconds = speed_bump_add($ip, $now);
    $log->info("Blocked for $seconds because of too many suspicious requests");
    result($stream, "44", "$seconds");
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
  # protect against integer overflows, haha: 28d is 28*24*60*60 = 2419200
  $seconds = 2419200 if $seconds > 2419200;
  $speed_data->{$ip}->{seconds} = $seconds;
  $speed_data->{$ip}->{until} = $now + $seconds;
  $speed_data->{$ip}->{probation} = $now + 2 * $seconds;
  return $seconds if $seconds < 2419200;
  # finally, check if there are enough other IPs in the same network to warrant a net range block
  $speed_data->{$ip}->{cidr} ||= speed_bump_cidr($ip, $now);
  my $cidr = $speed_data->{$ip}->{cidr};
  if ($cidr) {
    my $count = 0;
    for (keys %$speed_data) {
      $count++ if exists $speed_data->{$_}->{cidr} and $speed_data->{$_}->{cidr} eq $cidr;
    }
    speed_bump_add_cidr($cidr, $now + $seconds) if $count >= 3;
  }
  return $seconds;
}

sub speed_bump_add_cidr {
  my $cidr = shift;
  my $until = shift;
  $log->info("Blocking CIDR $cidr");
  $speed_cidr_data->{$cidr} = $until;
}

# load on startup
Mojo::IOLoop->next_tick(sub {
  my $dir = $server->{wiki_dir};
  return unless -f "$dir/speed-bump.json";
  my $bytes = read_binary("$dir/speed-bump.json");
  $speed_data = decode_json $bytes;
  speed_bump_compute_cidr_blocks() });

# save every half hour
Mojo::IOLoop->recurring(1800 => sub {
  my $bytes = encode_json $speed_data;
  my $dir = $server->{wiki_dir};
  write_binary("$dir/speed-bump.json", $bytes) });

sub speed_bump_admin {
  my $stream = shift;
  my $url = shift;
  my $hosts = host_regex();
  my $port = port($stream);
  if ($url =~ m!^gemini://(?:$hosts)(?::$port)?/do/speed-bump$!) {
    success($stream);
    $stream->write("# Speed Bump\n");
    $stream->write("Administer the block lists from this menu.\n");
    $stream->write("=> /do/speed-bump/status status\n");
    $stream->write("=> /do/speed-bump/debug debug\n");
    $stream->write("=> /do/speed-bump/save save\n");
    $stream->write("=> /do/speed-bump/load load\n");
    $stream->write("=> /do/speed-bump/reset reset\n");
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
  } elsif ($url =~ m!^gemini://(?:$hosts)(?::$port)?/do/speed-bump/save$!) {
    with_speed_bump_fingerprint($stream, sub {
      success($stream);
      my $bytes = encode_json $speed_data;
      my $dir = $server->{wiki_dir};
      write_binary("$dir/speed-bump.json", $bytes);
      $stream->write("# Speed Bump Saved\n");
      $stream->write("=> /do/speed-bump menu\n") });
    return 1;
  } elsif ($url =~ m!^gemini://(?:$hosts)(?::$port)?/do/speed-bump/load$!) {
    with_speed_bump_fingerprint($stream, sub {
      success($stream);
      my $dir = $server->{wiki_dir};
      my $bytes = read_binary("$dir/speed-bump.json");
      $speed_data = decode_json $bytes;
      speed_bump_compute_cidr_blocks();
      $stream->write("# Speed Bump Loaded\n");
      $stream->write("=> /do/speed-bump menu\n") });
    return 1;
  } elsif ($url =~ m!^gemini://(?:$hosts)(?::$port)?/do/speed-bump/reset$!) {
    with_speed_bump_fingerprint($stream, sub {
      $speed_data = undef;
      success($stream);
      $stream->write("# Speed Bump Reset\n");
      $stream->write("The speed bump data has been reset.\n");
      $stream->write("=> /do/speed-bump menu\n") });
    return 1;
  }
  return;
}

sub speed_bump_compute_cidr_blocks {
  my %count;
  my %until;
  # check which CIDR has been blocked at least three times
  for my $ip (keys %$speed_data) {
    my $cidr = $speed_data->{$ip}->{cidr};
    next unless $cidr;
    $count{$cidr}++;
    $until{$cidr} ||= $speed_data->{$ip}->{until};
    $until{$cidr} = $speed_data->{$ip}->{until} if $speed_data->{$ip}->{until} > $until{$cidr};
  }
  # only copy the blocked-until timestamp for those CIDRs that were listed at least three times
  for my $cidr (keys %count) {
    next unless $count{$cidr} >= 3;
    speed_bump_add_cidr($cidr, $until{$cidr});
  }
}

sub with_speed_bump_fingerprint {
  my $stream = shift;
  my $fun = shift;
  my $fingerprint = $stream->handle->get_fingerprint();
  if ($fingerprint and grep { $_ eq $fingerprint} @known_fingerprints) {
    $fun->();
  } elsif ($fingerprint) {
    $log->info("Unknown client certificate $fingerprint");
    result($stream, "61", "Your client certificate is not authorised for speed bump administration");
  } else {
    $log->info("Requested client certificate");
    result($stream, "60", "You need an authorised client certificate to administer speed bumps");
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
    $stream->write(sprintf("%s %s %2d/%2d %s %s     %s $ip %s\n",
			   speed_bump_time($speed_data->{$ip}->{visits}->[-1], $now),
			   speed_bump_time($speed_data->{$ip}->{visits}->[0], $now),
			   sum(@{$speed_data->{$ip}->{warnings}} || 0),
			   scalar(@{$speed_data->{$ip}->{warnings}}) || 0,
			   speed_bump_time($speed_data->{$ip}->{seconds}),
			   speed_bump_time($speed_data->{$ip}->{until}, $now),
			   speed_bump_time($speed_data->{$ip}->{probation}, $now),
			   $speed_data->{$ip}->{cidr} || ""));
  }
  if (%$speed_cidr_data) {
    $stream->write("\n");
    $stream->write("Until CIDR\n");
    for my $cidr (keys %$speed_cidr_data) {
      $stream->write(sprintf("%s $cidr\n", speed_bump_time($speed_cidr_data->{$cidr}, $now)));
    }
  }
  $stream->write("```\n");
  $stream->write("=> /do/speed-bump menu\n");
}

my $resolver;

sub speed_bump_cidr {
  my $ip = shift;
  my $now = shift;
  my $cidr = $speed_data->{$ip}->{cidr};
  my $until = $speed_data->{$ip}->{until};
  return $cidr if $cidr or not $until or $until - $now < 604800;
  # if blocked for at least 7d and no cidr is available, get it: 7*24*60*60 = 604800
  $ip = new Net::IP ($ip) or return;
  my $reverse = $ip->reverse_ip();
  $reverse =~ s/in-addr\.arpa\.$/asn.routeviews.org/;
  $log->debug("DNS TXT query for $reverse");
  $resolver ||= Net::DNS::Resolver->new;
  for my $rr (rr($reverse, "TXT")) {
    next unless $rr->type eq "TXT";
    my @data = $rr->txtdata;
    $log->debug("DNS TXT @data");
    return join("/", @data[1..2]); # CIDR
  }
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
