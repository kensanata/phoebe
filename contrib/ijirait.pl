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
our (@extensions, $log, $server);

package App::Phoebe::Ijirait;
use Modern::Perl;
use Encode qw(encode_utf8 decode_utf8);
use File::Slurper qw(read_binary write_binary read_text);
use Mojo::JSON qw(decode_json encode_json);
use List::Util qw(first);
use Graph::Easy;
use URI::Escape;
use utf8;

*success = \&App::Phoebe::success;

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

# by default, /play/ijirait on all hosts is the same game
our $ijirait_host = App::Phoebe::host_regex();

Mojo::IOLoop->next_tick(sub {
  $log->info("Serving Ijirait on $ijirait_host") });

# global commands
our $ijirait_commands = {
  help     => \&ijirait_help,
  look     => \&ijirait_look,
  type     => \&ijirait_type,
  save     => \&ijirait_save,
  say      => \&ijirait_say,
  who      => \&ijirait_who,
  go       => \&ijirait_go,
  examine  => \&ijirait_examine,
  describe => \&ijirait_describe,
  name     => \&ijirait_name,
  create   => \&ijirait_create,
  rooms    => \&ijirait_rooms,
  connect  => \&ijirait_connect,
  map      => \&ijirait_map,
};

# load world on startup
Mojo::IOLoop->next_tick(sub {
  my $dir = $server->{wiki_dir};
  if (-f "$dir/ijirait.json") {
    my $bytes = read_binary("$dir/ijirait.json");
    $ijirait_data = decode_json $bytes;
  } else {
    ijirait_init();
  } } );

sub ijirait_init {
  my $next = 1;
  $ijirait_data = {
    people => [
      {
	id => $next++, # 1
	name => "Ijiraq",
	description => "A shape-shifter with red eyes.",
	fingerprint => "",
	location => $next, # 2
	ts => time(),
      } ],
    rooms => [
      {
	id => $next++, # 2
	name => "The Tent",
	description => "This is a large tent, illuminated by candles.",
	exits => [
	  {
	    id => $next++, # 3
	    name => "An exit leads outside.",
	    direction => "out",
	    destination => $next,
	  } ],
	words => [
	  {
	    text => "Welcome!",
	    by => 1, # Ijirait
	    ts => time,
	  } ],
      },
      {
	id => $next++, # 4
	name => "Outside The Tent",
	description => "You’re standing in a rocky hollow, somewhat protected from the wind. There’s a large tent, here.",
	exits => [
	  {
	    id => $next++, # 5
	    name => "A tent flap leads inside.",
	    direction => "tent",
	    destination => 2, # The Tent
	  } ] } ] };
  $ijirait_data->{next} = $next;
};

# save every half hour
Mojo::IOLoop->recurring(1800 => \&ijirait_save_world);

# main loop
push(@extensions, \&ijirait_main);

sub ijirait_main {
  my $stream = shift;
  my $url = shift;
  my $port = App::Phoebe::port($stream);
  if ($url =~ m!^gemini://(?:$ijirait_host)(?::$port)?/play/ijirait(?:/([a-z]+))?(?:\?(.*))?!) {
    my $command = $1 || "look";
    my $arg = decode_utf8 uri_unescape($2) || "";
    $log->debug("Handling $url - $command $arg");
    my $fingerprint = $stream->handle->get_fingerprint();
    if ($fingerprint) {
      my $p = first { $_->{fingerprint} eq $fingerprint} @{$ijirait_data->{people}};
      if ($p) {
	$log->info("Successfully identified client certificate: " . $p->{name});
	$p->{ts} = time();
	my $routine = $ijirait_commands->{$command};
	if ($routine) {
	  $log->debug("Running $command");
	  $routine->($stream, $p, $arg);
	} else {
	  $log->debug("Unknown command '$command'");
	  success($stream);
	  $stream->write("# Unknown command\n");
	  $stream->write(encode_utf8 "“$command” is an unknown command.\n");
	  ijirait_menu($stream);
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
    id => $ijirait_data->{next}++,
    name => ijirait_person_name(),
    description => "A shape-shifter with red eyes.",
    fingerprint => $fingerprint,
    location => 2, # The Tent
    ts => time,
  };
  push(@{$ijirait_data->{people}}, $p);
  return $p;
}

sub ijirait_person_name {
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
  $stream->write(encode_utf8 "# " . $room->{name} . "\n");
  $stream->write(encode_utf8 $room->{description} . "\n") if $room->{description};
  $stream->write("## Exits\n") if $room->{exits};
  for my $exit (@{$room->{exits}}) {
    my $direction = uri_escape $exit->{direction};
    $stream->write(encode_utf8 "=> /play/ijirait/go?$direction $exit->{name} ($exit->{direction})\n");
  }
  $stream->write("## People\n");
  my $n = 0;
  my $now = time();
  for my $o (@{$ijirait_data->{people}}) {
    next unless $o->{location} == $p->{location};
    next if $now - $o->{ts} > 600;      # don't show people inactive for 10min or more
    $n++;
    my $name = uri_escape $o->{name};
    if ($o->{id} == $p->{id}) {
      $stream->write(encode_utf8 "=> /play/ijirait/examine?$name $o->{name} (you)\n");
    } else {
      $stream->write(encode_utf8 "=> /play/ijirait/examine?$name $o->{name}\n");
    }
  }
  my $title = 0;
  for my $word (@{$room->{words}}) {
    next if $now - $word->{ts} > 600; # don't show messages older than 10min
    $stream->write("## Words\n") unless $title++;
    my $o = first { $_->{id} == $word->{by} } @{$ijirait_data->{people}};
    $stream->write(encode_utf8 ijirait_time($now - $word->{ts}) . ", " . $o->{name} . " said “" . $word->{text} . "”\n");
  }
  ijirait_menu($stream);
}

sub ijirait_time {
  my $seconds = shift;
  return "some time ago" if not defined $seconds;
  return "just now" if $seconds == 0;
  return sprintf("%d days ago", int($seconds/86400)) if abs($seconds) > 172800; # 2d
  return sprintf("%d hours ago", int($seconds/3600)) if abs($seconds) > 7200; # 2h
  return sprintf("%d minutes ago", int($seconds/60)) if abs($seconds) > 120; # 2min
  return sprintf("%d seconds ago", $seconds);
}

sub ijirait_menu {
  my $stream = shift;
  $stream->write("## Commands\n");
  $stream->write("=> /play/ijirait/look look\n");
  $stream->write("=> /play/ijirait/help help\n");
  $stream->write("=> /play/ijirait/type type\n");
}

sub ijirait_help {
  my ($stream, $p) = @_;
  success($stream);
  $stream->write("## Help\n");
  my $dir = $server->{wiki_dir};
  my $file = "$dir/ijirait-help.gmi";
  if (-f $file) {
    $stream->write(encode_utf8 read_text($file));
  } else {
    $stream->write("The help file does not exist.\n");
  }
  $stream->write("## Automatically Generated Command List\n");
  for my $command (sort keys %$ijirait_commands) {
    $stream->write("* $command\n");
  }
  $stream->write("=> /play/ijirait Back\n");
}

sub ijirait_type {
  my ($stream, $p, $str) = @_;
  if ($str) {
    my ($command, $arg) = split(/\s+/, $str, 2);
    my $routine = $ijirait_commands->{$command};
    if ($routine) {
      $log->debug("Running $command");
      $routine->($stream, $p, $arg);
    } else {
      $log->debug("Unknown command '$command'");
      success($stream);
      $stream->write("# Unknown command\n");
      $stream->write(encode_utf8 "“$command” is an unknown command.\n");
      ijirait_menu($stream);
    }
  } else {
    $stream->write("10 Type your command\r\n");
  }
}

sub ijirait_go {
  my ($stream, $p, $direction) = @_;
  my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
  my $exit = first { $_->{direction} eq $direction } @{$room->{exits}};
  if ($exit) {
    $log->debug("Taking the exit '$direction'");
    $p->{location} = $exit->{destination};
    $stream->write("30 /play/ijirait/look\r\n");
  } else {
    success($stream);
    $log->debug("Unknown exit '$direction'");
    $stream->write(encode_utf8 "# Unknown exit “$direction”\n");
    $stream->write("The exit does not exist.\n");
    $stream->write("=> /play/ijirait Back\n");
  }
}

sub ijirait_examine {
  my ($stream, $p, $name) = @_;
  success($stream);
  my $o = first { $_->{location} eq $p->{location} and $_->{name} eq $name } @{$ijirait_data->{people}};
  if ($o) {
    $log->debug("Looking at '$name'");
    $stream->write(encode_utf8 "# $o->{name}\n");
    $stream->write(encode_utf8 "$o->{description}\n");
    $stream->write("=> /play/ijirait Back\n");
  } else {
    $log->debug("Unknown target '$name'");
    $stream->write(encode_utf8 "# Unknown target “$name”\n");
    $stream->write("No such person or object is visible.\n");
    $stream->write("=> /play/ijirait Back\n");
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

sub ijirait_save {
  my ($stream, $p) = @_;
  ijirait_save_world();
  success($stream);
  $stream->write("# World Save\n");
  $stream->write("Data was saved.\n");
  $stream->write("=> /play/ijirait Back\n");
}

sub ijirait_save_world {
  ijirait_cleanup();
  my $bytes = encode_json $ijirait_data;
  my $dir = $server->{wiki_dir};
  write_binary("$dir/ijirait.json", $bytes);
}

sub ijirait_cleanup() {
  my $now = time();
  my %people = map { $_->{location} => 1 } @{$ijirait_data->{people}};
  for my $room (@{$ijirait_data->{rooms}}) {
    my @words;
    for my $word (@{$room->{words}}) {
      next if $now - $word->{ts} > 600; # don't show messages older than 10min
      push(@words, $word);
    }
    $room->{words} = \@words;
    # unpopulated rooms get a timestamp
    if ($people{$room->{id}}) {
      delete $room->{ts};
    } elsif (not $room->{ts}) {
      $room->{ts} = time();
    }
  }
}

sub ijirait_who {
  my ($stream, $p) = @_;
  my $now = time();
  success($stream);
  $stream->write("# Who are the shape shifters?\n");
  for my $o (sort { $b->{ts} <=> $a->{ts} } @{$ijirait_data->{people}}) {
    $stream->write(encode_utf8 "* $o->{name}, active " . ijirait_time($now - $o->{ts}) . "\n");
  }
  $stream->write("=> /play/ijirait Back\n");
}

sub ijirait_describe {
  my ($stream, $p, $text) = @_;
  if ($text) {
    my ($obj, $description) = split(/\s+/, $text, 2);
    if ($obj eq "me") {
      $log->debug("Describing $p->{name}");
      $p->{description} = $description;
      my $name = uri_escape $p->{name};
      $stream->write("30 /play/ijirait/examine?$name\r\n");
      return;
    } elsif ($obj eq "room") {
      my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
      $log->debug("Describing $room->{name}");
      $room->{description} = $description;
      $stream->write("30 /play/ijirait/look\r\n");
      return;
    }
  }
  success($stream);
  $log->debug("Describing unknown object");
  $stream->write(encode_utf8 "# I don’t know what to describe\n");
  $stream->write(encode_utf8 "The description needs needs to start with what to describe, e.g. “describe me A shape-shifter with red eyes.”\n");
  $stream->write(encode_utf8 "You can describe yourself (“me”), the room you are in (“room”), or an exit (using its shortcut).\n");
  $stream->write("=> /play/ijirait Back\n");
}

sub ijirait_name {
  my ($stream, $p, $text) = @_;
  if ($text) {
    my ($obj, $name) = split(/\s+/, $text, 2);
    if ($obj eq "me" and $name !~ /\s/) {
      $log->debug("Name $p->{name}");
      $p->{name} = $name;
      my $nm = uri_escape $p->{name};
      $stream->write("30 /play/ijirait/examine?$nm\r\n");
      return;
    } elsif ($obj eq "room") {
      my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
      $log->debug("Name $room->{name}");
      $room->{name} = $name;
      $stream->write("30 /play/ijirait/look\r\n");
      return;
    } else {
      my $direction;
      if ($name =~ /(^.*) \((\w+)\)$/) {
	$name = $1;
	$direction = $2;
      }
      my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
      my $exit = first { $_->{direction} eq $obj } @{$room->{exits}};
      if ($exit) {
	$log->debug("Name $exit->{name}");
	$exit->{name} = $name;
	$exit->{direction} = $direction if $direction;
	$stream->write("30 /play/ijirait/look\r\n");
	return;
      }
    }
  }
  success($stream);
  $log->debug("Naming unknown object");
  $stream->write(encode_utf8 "# I don’t know what to name\n");
  $stream->write(encode_utf8 "The command needs needs to start with what to name, e.g. “name me Sogeeran.”\n");
  $stream->write("=> /play/ijirait Back\n");
}

sub ijirait_create {
  my ($stream, $p, $obj) = @_;
  if ($obj eq "room") {
    $log->debug("Create room");
    my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
    my $dest = ijirait_new_room();
    my $exit = ijirait_new_exit($room, $dest);
    ijirait_new_exit($dest, $room);
    $stream->write("30 /play/ijirait\r\n");
  } else {
    success($stream);
    $log->debug("Cannot create '$obj'");
    $stream->write(encode_utf8 "# Cannot create new “$obj”\n");
    $stream->write(encode_utf8 "Currently, all you can create is a room: “create room”.\n");
    $stream->write("=> /play/ijirait Back\n");
  }
}

sub ijirait_new_room {
  my $r = {
    id => $ijirait_data->{next}++,
    name => "Lost in fog",
    description => "Dense fog surrounds you. Nothing can be discerned in this gloom.",
    exits => [],
    ts => time,
  };
  push(@{$ijirait_data->{rooms}}, $r);
  return $r;
}

sub ijirait_new_exit {
  # $from and $to are rooms
  my ($from, $to) = @_;
  my $e = {
    id => $ijirait_data->{next}++,
    name => "A tunnel",
    direction => "tunnel",
    destination => $to->{id},
  };
  push(@{$from->{exits}}, $e);
  return $e;
}

sub ijirait_rooms {
  my ($stream, $p) = @_;
  $log->debug("Listing all rooms");
  success($stream);
  $stream->write("# Rooms\n");
  my $now = time();
  my %activity;
  for my $o (@{$ijirait_data->{people}}) {
    $activity{$o->{location}} = $o->{ts} if not $activity{$o->{location}} or $o->{ts} > $activity{$o->{location}};
  }
  for my $room (sort { ($activity{$b->{id}}||$b->{ts}||0) <=> ($activity{$a->{id}}||$a->{ts}||0) } @{$ijirait_data->{rooms}}) {
    $stream->write(encode_utf8 "* $room->{name}");
    $stream->write(", last activity " . ijirait_time($now - $activity{$room->{id}})) if $activity{$room->{id}};
    $stream->write(", last visit more than " . ijirait_time($now - $room->{ts})) if $room->{ts};
    $stream->write("\n");
  }
  $stream->write("=> /play/ijirait Back\n");
}

sub ijirait_connect {
  my ($stream, $p, $name) = @_;
  if ($name) {
    my $room = first { $_->{id} == $p->{location} } @{$ijirait_data->{rooms}};
    my $dest = first { $_->{name} eq $name } @{$ijirait_data->{rooms}};
    if ($dest) {
      $log->debug("Connecting $name");
      ijirait_new_exit($room, $dest);
      ijirait_new_exit($dest, $room);
      $stream->write("30 /play/ijirait\r\n");
      return;
    }
  }
  success($stream);
  $log->debug("Cannot connect '$name'");
  $stream->write(encode_utf8 "# Cannot connect “$name”\n");
  $stream->write(encode_utf8 "You need to provide the name of an existing room: “connect <room>”.\n");
  $stream->write(encode_utf8 "You can get a list of all existing rooms using “rooms”.\n");
  $stream->write("=> /play/ijirait Back\n");
}

sub ijirait_map {
  my ($stream, $p) = @_;
  success($stream);
  $log->debug("Drawing a map");
  my $graph = Graph::Easy->new();
  my %rooms;
  for (@{$ijirait_data->{rooms}}) {
    my $name = "$_->{name} ($_->{id})";
    $rooms{$_->{id}} = $name;
    $graph->add_node($name);
  }
  for my $room (@{$ijirait_data->{rooms}}) {
    my $from = $rooms{$room->{id}};
    for my $exit (@{$room->{exits}}) {
      my $to = $rooms{$exit->{destination}};
      my $edge = $graph->add_edge($from, $to);
      $edge->set_attribute("label", $exit->{direction});
    }
  }
  $stream->write("# Map\n");
  $stream->write("```\n");
  $stream->write(encode_utf8 $graph->as_boxart());
  $stream->write("```\n");
  $stream->write("=> /play/ijirait Back\n");
}

1;
