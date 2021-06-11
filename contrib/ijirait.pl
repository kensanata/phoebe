# -*- mode: perl -*-
# Copyright (C) 2021  Alex Schroeder <alex@gnu.org>

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
use File::Slurper qw(read_binary write_binary read_text);
use List::Util qw(first);
use Mojo::JSON qw(decode_json encode_json);
use URI::Escape;
our (@extensions, $log, $server);

=head1 Ijirait

The ijirait are red-eyed shape shifters, and a game one plays via the Gemini
protocol, and Ijiraq is also one of the moons of Saturn.

The Ijirait game is modelled along traditional MUSH games ("multi-user shared
hallucination"), that is: players have a character in the game world; the game
world consists of rooms; these rooms are connected to each other; if two
characters are in the same room, they see each other; if one of them says
something, the other hears it.

=head2 Your Character

When you visit the URL using your Gemini browser, you're asked for a client
certificate. The common name of the certificate is the name of your character in
the game.

=head2 Time

As the server doesn't know whether you're still active or not, it assumes a
10min timout. If you were active in the last 10min, other people in the same
"room". Similarly, if you "say" something, whatever you said hangs on the room
description for up to 10min as long as your character is still in the room.

=cut

# see "load world on startup" for the small world generated if no save file is
# available
my $ijirait_data;

# the sequence from where all ids are generated
my $ijirait_next;

# by default, /play/ijirait on all hosts is the same game
our $ijirait_host = host_regex();

# global commands
our $ijirait_commands = {
  help => \&ijirait_help,
  look => \&ijirait_look,
  type => \&ijirait_type,
};

# load world on startup
Mojo::IOLoop->next_tick(sub {
  my $dir = $server->{wiki_dir};
  if (-f "$dir/ijirait.json") {
    my $bytes = read_binary("$dir/ijirait.json");
    $ijirait_data = decode_json $bytes;
  } else {
    $ijirait_next = 1;
    $ijirait_data = {
      people => [
	{
	  id => $ijirait_next++, # 1
	  name => "Ijiraq",
	  description => "A shape-shifter with red eyes.",
	  fingerprint => "",
	  location => $ijirait_next, # 2
	  ts => time,
	} ],
      rooms => [
	{
	  id => $ijirait_next++, # 2
	  name => "The Tent",
	  description => "This is a large tent, illuminated by candles.",
	  exits => [
	    {
	      id => $ijirait_next++, # 3
	      name => "An exit leads outside.",
	      direction => "out",
	      destination => $ijirait_next,
	    } ],
	  words => [
	    {
	      text => "Welcome!",
	      by => 1, # Ijirait
	      ts => time,
	    } ],
	},
	{
	  id => $ijirait_next++, # 4
	  name => "Outside The Tent",
	  description => "You're standing in a rocky hollow, somewhat protected from the wind. There's a large tent, here.",
	  exits => [
	    {
	      id => $ijirait_next++, # 5
	      name => "A tent flap leads inside.",
	      direction => "tent",
	      destination => 2, # The Tent
	    } ] } ] };
    } } );

# save every half hour
Mojo::IOLoop->recurring(1800 => sub {
  my $bytes = encode_json $ijirait_data;
  my $dir = $server->{wiki_dir};
  write_binary("$dir/ijirait.json", $bytes) });

# main loop
push(@extensions, \&ijirait_main);

sub ijirait_main {
  my $stream = shift;
  my $url = shift;
  my $port = port($stream);
  if ($url =~ m!^gemini://$ijirait_host(?::$port)?/play/ijirait(/type)?(?:\?(.*))?$!) {
    # We're using /play/ijirait/type to ask the user to type a command so that
    # we can process /play/ijirait/type?command; otherwise things get difficult:
    # /play/ijirait could mean "look around" or "ask the user for input", which
    # is awkward; or we could ask the user for input using /play/ijirait?more
    # and then expect to receive /play/ijirait?more?command (maybe?). In short,
    # better to use a different URL.
    my ($type, $command) = ($1, $2);
    $command = uri_unescape($command);
    my $fingerprint = $stream->handle->get_fingerprint();
    if ($fingerprint) {
      my $p = first { $_->{fingerprint} eq $fingerprint} @{$ijirait_data->{people}};
      if ($p) {
	$log->info("Successfully identified client certificate: " . $p->{name});
	$p->{ts} = time();
	if ($command) {
	  my $routine = $ijirait_commands->{$command};
	  if ($routine) {
	    $routine->($stream, $p, "");
	  } else {
	    ijirait_command($stream, $p, $command);
	  }
	} else {
	  if ($type) {
	    $stream->write("10 Type your command\r\n");
	  } else {
	    ijirait_look($stream, $p);
	  }
	}
      } else {
	$log->info("New client certificate $fingerprint");
	ijirait_look($stream, ijirait_new_person($fingerprint));
      }
    } else {
      $log->info("Requested client certificate");
      $stream->write("60 You need a client certificate to play\r\n");
    }
    return 1;
  }
  return 0;
}

sub ijirait_new_person {
  my $fingerprint = shift;
  my $p = {
    id => $ijirait_next++,
    name => ijirait_name(),
    description => "A shape-shifter with red eyes.",
    fingerprint => $fingerprint,
    location => 2, # The Tent
  };
  push(@{$ijirait_data->{people}}, $p);
  return $p;
}

sub ijirait_name {
  my $digraphs = "..lexegezacebisousesarmaindire.aeratenberalavetiedorquanteisrion";
  my $max = length($digraphs);
  my $length = 4 + rand(7); # 4-8
  my $name = '';
  while (length($name) < $length) {
    $name .= substr($digraphs, 2*int(rand($max/2)), 2);
  }
  $name =~ s/\.//g;
  return ucfirst $name;
}

sub ijirait_look {
  my ($stream, $p) = @_;
  success($stream);
  my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
  $stream->write("# " . $room->{name} . "\n");
  $stream->write($room->{description} . "\n") if $room->{description};
  $stream->write("## Exits\n") if $room->{exits};
  for my $exit (@{$room->{exits}}) {
    $stream->write("=> /play/ijirait?" . $exit->{direction} . " " . $exit->{name} . "\n");
  }
  $stream->write("## People\n");
  my $n = 0;
  for my $o (@{$ijirait_data->{people}}) {
    next unless $o->{location} == $p->{location};
    if ($o->{id} != $p->{id}) {
      $n++;
      $stream->write("=> /play/ijirait?$o->{name} $o->{name}\n");
    }
  }
  if ($n) {
    $stream->write("And you, $p->{name}.\n");
  } else {
    $stream->write("Just you, $p->{name}.\n");
  }
  $stream->write("## Words\n") if $room->{words};
  for my $word (@{$room->{words}}) {
    next if time() - $word->{ts} > 600; # don't show messages older than 10min
    my $o = first { $_->{id} == $word->{by} } @{$ijirait_data->{people}};
    $stream->write(ijirait_time($word->{ts}) . ", " . $o->{name} . " said “" . $word->{text} . "”\n");
  }
  ijirait_menu($stream);
}

sub ijirait_time {
  my $ts = shift;
  return "Some time ago" unless $ts;
  my $seconds = time() - $ts;
  return sprintf("%d days ago", int($seconds/86400)) if abs($seconds) > 172800; # 2d
  return sprintf("%d hours ago", int($seconds/3600)) if abs($seconds) > 7200; # 2h
  return sprintf("%d minutes ago", int($seconds/60)) if abs($seconds) > 120; # 2min
  return sprintf("%d seconds ago", $seconds);
}

sub ijirait_menu {
  my $stream = shift;
  $stream->write("## Commands\n");
  $stream->write("=> /play/ijirait?look look\n");
  $stream->write("=> /play/ijirait?help help\n");
  $stream->write("=> /play/ijirait/type type\n");
}

sub ijirait_help {
  my ($stream, $p) = @_;
  success($stream);
  $stream->write("## Help\n");
  my $dir = $server->{wiki_dir};
  my $file = "$dir/ijirait-help.gmi";
  if (-f $file) {
    $stream->write(read_text($file));
  } else {
    $stream->write("The help file does not exist.\n");
  }
}

sub ijirait_command {
  my ($stream, $p, $command) = @_;
  if ($command) {
    if ($command =~ /^["“„«]/) {
      ijirait_say($stream, $p, $command);
      return;
    }
    # these are local commands, like exits
    my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
    my $exit = first { $_->{direction} eq $command } @{$room->{exits}};
    if ($exit) {
      $p->{location} = $exit->{destination};
      $stream->write("30 /play/ijirait?look\r\n");
      return;
    }
    my $o = first { $_->{location} eq $p->{location} and $_->{name} eq $command } @{$ijirait_data->{people}};
    if ($o) {
      success($stream);
      $stream->write("# $o->{name}\n");
      $stream->write("$o->{description}\n");
      $stream->write("=> /play/ijirait Back\n");
      return;
    }
    success($stream);
    $stream->write("# Unknown command\n");
    $stream->write("“$command” is an unknown command.\n");
    ijirait_menu($stream);
  } else {
    $stream->write("10 Type your command\r\n");
  }
}

sub ijirait_say {
  my ($stream, $p, $text) = @_;
  $text =~ s/^["“„«]//;
  $text =~ s/["”»]$//;
  $text =~ s/^\s+//;
  $text =~ s/\s+$//;
  my $w = {
    text => $text,
    by => $p->{id},
    ts => time(),
  };
  my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
  push(@{$room->{words}}, $w);
  ijirait_look($stream, $p);
}

1;
