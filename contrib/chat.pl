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

our (@extensions, @request_handlers, $log);

# Each chat member is {stream => $stream, host => $host, space => $space, name => $name}
my (@chat_members);

# needs a special handler because the stream never closes
my $spaces = space_regex();
unshift(@request_handlers, '^gemini://([^/?#]*)(?:/$spaces)?/do/chat/listen' => \&chat_listen);

sub chat_listen {
  my $stream = shift;
  my $data = shift;
  $log->debug("Handle chat listen request");
  $log->debug("Discarding " . length($data->{buffer}) . " bytes")
      if $data->{buffer};
  my $url = $data->{request};
  my $host_regex = host_regex();
  my $port = port($stream);
  if (($host, $space) =
      $url =~ m!^(?:gemini:)?//($host_regex)(?::$port)?(?:/($spaces))?/do/chat/listen$!) {
    chat_register($stream, $host, space($stream, $host, $space));
    # don't lose the stream!
  } else {
    $stream->write("59 Don't know how to handle $url\r\n");
    $stream->close_gracefully();
  }
}

sub chat_register {
  my $stream = shift;
  my $host = shift;
  my $space = shift;
  my $name = $stream->handle->peer_certificate('cn');
  if (not $name) {
    $stream->write("60 You need a client certificate with a common name to listen to this chat\r\n");
    $stream->close_gracefully();
    return;
  }
  # 1h timeout
  $stream->timeout(3600);
  # remove from channel members if an error happens
  $stream->on(close => sub {
    my ($stream, $err) = @_;
    $log->debug("Closed connection to $name")});
  $stream->on(error => sub {
    my ($stream, $err) = @_;
    $log->debug("Disconnected $name: $err");
    @chat_members = grep { $stream ne $_->{stream} } @chat_members;
    for (@chat_members) {
      next unless $host eq $_->{host} and $space eq $_->{space} and $name ne $_->{name};
      $_->{stream}->write("$name left\n");
    }});
  # add myself
  push(@chat_members, { host => $host, space => $space, name => $name, stream => $stream });
  # announce myself
  my @names;
  for (@chat_members) {
    next unless $host eq $_->{host} and $space eq $_->{space} and $name ne $_->{name};
    push(@names, $_->{name});
    $_->{stream}->write("$name joined\n");
  }
  # and get a welcome message
  success($stream);
  $stream->write("# Welcome to $host" . ($space ? "/$space" : "") . "\n");
  if (@names) {
    $stream->write("Other chat members: @names\n");
  } else {
    $stream->write("You are the only one.\n");
  }
  $log->debug("Added $name to the chat");
}

push(@extensions, \&handle_chat_say);

sub handle_chat_say {
  my $stream = shift;
  my $url = shift;
  my $host_regex = host_regex();
  my $port = port($stream);
  my $text;
  if (($host, $spacem, $text) =
      $url =~ m!^(?:gemini:)?//($host_regex)(?::$port)?(?:/($spaces))?/do/chat/say(?:\?([^#]*))?$!) {
    return process_chat_say($stream, $host, $space, $text);
  }
  return 0;
}

sub process_chat_say {
  my $stream = shift;
  my $host = shift;
  my $space = shift;
  my $text = shift;
  my $name = $stream->handle->peer_certificate('cn');
  if (not $name) {
    $stream->write("60 You need a client certificate with a common name to talk on this chat\r\n");
    return 1;
  }
  my @found = grep { $host eq $_->{host} and $space eq $_->{space} and $name eq $_->{name} } @chat_members;
  if (not @found) {
    $stream->write("40 You need to join the chat before you can say anything\r\n");
    return 1;
  }
  if (not $text) {
    $stream->write("10 Post to the channel as $name:\r\n");
    return 1;
  }
  $text = decode_utf8(uri_unescape($text));
  # send message
  for (@chat_members) {
    next unless $host eq $_->{host} and $space eq $_->{space} and $name ne $_->{name};
    $_->{stream}->write("$name: $text\n");
  }
  # and ask to send another one
  $stream->write("31 gemini://$host:$port" . ($space ? "/$space" : "") . "/do/chat/say\r\n");
  return 1;
}
