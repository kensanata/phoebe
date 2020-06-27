# Copyright (C) 2017–2020  Alex Schroeder <alex@gnu.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Modern::Perl;
use Test::More;
use IO::Socket::SSL;
use File::Slurper qw(write_text);
use utf8; # tests contain UTF-8 characters and it matters

sub random_port {
  use Errno qw(EADDRINUSE);
  use Socket;

  my $family = PF_INET;
  my $type   = SOCK_STREAM;
  my $proto  = getprotobyname('tcp')  or die "getprotobyname: $!";
  my $host   = INADDR_ANY;  # Use inet_aton for a specific interface

  for my $i (1..3) {
    my $port   = 1024 + int(rand(65535 - 1024));
    socket(my $sock, $family, $type, $proto) or die "socket: $!";
    my $name = sockaddr_in($port, $host)     or die "sockaddr_in: $!";
    setsockopt($sock, SOL_SOCKET, SO_REUSEADDR, 1);
    bind($sock, $name)
	and close($sock)
	and return $port;
    die "bind: $!" if $! != EADDRINUSE;
    print "Port $port in use, retrying...\n";
  }
  die "Tried 3 random ports and failed.\n"
}

my $host = "127.0.0.1";
my $port = random_port();
my $pid = fork();

my $dir = "./" . sprintf("test-%04d", int(rand(10000)));
mkdir($dir);
write_text("$dir/config", <<'EOT');
package Gemini::Wiki;
use Modern::Perl;
our (@extensions, @main_menu_links);
push(@main_menu_links, "=> gemini://localhost:1965/do/test Test");
push(@extensions, \&serve_test);
sub serve_test {
  my $self = shift;
  my $url = shift;
  my $host = $self->host();
  my $port = $self->port();
  if ($url =~ m!^gemini://$host:$port/do/test$!) {
    say "20 text/plain\r";
    say "Test";
    return 1;
  }
  return;
}
1;
EOT

END {
  # kill server
  if ($pid) {
    kill 'KILL', $pid or warn "Could not kill server $pid";
  }
}

if (!defined $pid) {
  die "Cannot fork: $!";
} elsif ($pid == 0) {
  say "This is the server...";
  use Config;
  my $secure_perl_path = $Config{perlpath};
  exec($secure_perl_path,
       "./gemini-wiki.pl",
       "--host=$host",
       "--port=$port",
       "--log_level=0", # set to 4 for verbose logging
       "--wiki_dir=$dir",
       "--wiki_pages=Alex",
       "--wiki_pages=Berta",
       "--wiki_pages=Chris")
      or die "Cannot exec: $!";
}

sub query_gemini {
  my $query = shift;
  my $text = shift;

  # create client
  my $socket = IO::Socket::SSL->new(
    PeerHost => "127.0.0.1",
    PeerService => $port,
    SSL_cert_file => 'cert.pem',
    SSL_key_file => 'key.pem',
    SSL_verify_mode => SSL_VERIFY_NONE)
      or die "Cannot construct client socket: $@";

  $socket->print("$query\r\n");
  $socket->print($text) if defined $text;

  undef $/; # slurp
  return <$socket>;
}

my $base = "gemini://$host:$port";

say "This is the client waiting for the server to start...";
sleep 1;

# main menu
my $page = query_gemini("$base/");

unlike($page, qr/^=> .*\/$/m, "No empty links in the menu");

# --wiki_pages
for my $item(qw(Alex Berta Chris)) {
  like($page, qr/^=> $base\/page\/$item $item/m, "main menu contains $item");
}

# upload text

my $titan = "titan://$host:$port";

my $haiku = <<EOT;
Quiet disk ratling
Keyboard clicking, then it stops.
Rain falls and I think
EOT

$page = query_gemini("$titan/raw/Haiku;size=76;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 $base\/page\/Haiku\r$/, "Titan Haiku");

$page = query_gemini("$base/page/Haiku");
like($page, qr/^20 text\/gemini; charset=UTF-8\r\n$haiku/, "Haiku saved");

# plain text

$page = query_gemini("$base\/raw\/Haiku");
like($page, qr/$haiku/m, "Raw text");

# fake creation of some files for the blog

for (qw(2017-12-25 2017-12-26 2017-12-27)) {
  write_text("$dir/page/$_.gmi", "yo");
  unlink("$dir/index");
}

# blog on the main page
$page = query_gemini("$base/");
for my $item(qw(2017-12-25 2017-12-26 2017-12-27)) {
  like($page, qr/^=> $base\/page\/$item $item/m, "main menu contains $item");
}

# history

$haiku = <<EOT;
Muffled honking cars
Keyboard clicking, then it stops.
Rain falls and I think
EOT

$page = query_gemini("$titan/raw/Haiku;size=78;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 $base\/page\/Haiku\r$/, "Titan Haiku 2");

$page = query_gemini("$base/history/Haiku");
like($page, qr/^=> $base\/page\/Haiku\/1 Haiku \(1\)/m, "Revision 1 is listed");
like($page, qr/^=> $base\/diff\/Haiku\/1 Diff between revision 1 and the current one/m, "Diff 1 link");
like($page, qr/^=> $base\/page\/Haiku Haiku \(current\)/m, "Current revision is listed");
$page = query_gemini("$base/page/Haiku/1");
like($page, qr/Quiet disk ratling/m, "Revision 1 content");

#diffs
$page = query_gemini("$base/diff/Haiku/1");
like($page, qr/^< Quiet disk ratling\n-+\n> Muffled honking cars\n$/m, "Diff 1 content");

# match
$page = query_gemini("$base/do/match?2017");
for my $item(qw(2017-12-25 2017-12-26 2017-12-27)) {
  like($page, qr/^=> $base\/page\/$item $item\r$/m, "match menu contains $item");
}
like($page, qr/2017-12-27.*2017-12-26.*2017-12-25/s,
     "match menu sorted newest first");

# search
$page = query_gemini("$base/do/search?yo");
for my $item(qw(2017-12-25 2017-12-26 2017-12-27)) {
  like($page, qr/^=> $base\/page\/$item $item\r/m, "search menu contains $item");
}
like($page, qr/2017-12-27.*2017-12-26.*2017-12-25/s,
     "search menu sorted newest first");

# rc
$page = query_gemini("$base/do/changes");
like($page, qr/^=> $base\/page\/Haiku Haiku \(current\)\r/m, "Current revision of Haiku in recent chanegs");
like($page, qr/^=> $base\/page\/Haiku\/1 Haiku \(1\)\r/m, "Older revision of Haiku in recent chanegs");

# extension

$page = query_gemini($base);
like($page, qr/^=> gemini:\/\/localhost:1965\/do\/test Test\n/m, "Extension installed Test menu");
$page = query_gemini("$base/do/test");
like($page, qr/^Test\n/m, "Extension runs");

done_testing();
