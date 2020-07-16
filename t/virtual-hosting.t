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
use File::Slurper qw(write_text write_binary read_binary);

our $host;
our @hosts = qw(127.0.0.1 localhost);
our @spaces = qw(127.0.0.1/alex localhost/berta);
our @pages = qw(Alex);
our $port;
our $base;
our $dir;

require './t/test.pl';

my $titan = "titan://$host:$port";

# save haiku in the alex space

my $haiku = <<EOT;
Mad growl from the bowl
Back hurts, arms hurt, must go pee
Just one more to finish
EOT

my $page = query_gemini("$titan/alex/raw/Haiku;size=83;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 $base\/alex\/page\/Haiku\r$/, "Titan haiku");
ok(-d "$dir/127.0.0.1/alex", "alex subdirectory created");

$page = query_gemini("$base/alex/page/Haiku");
like($page, qr/Mad growl from the bowl/, "alex space has haiku");
like($page, qr/^=> $base\/alex\/raw\/Haiku Raw text/m, "Links work inside alex space");

# save haiku in the main space

$haiku = <<EOT;
Children shout and run.
Then silence. A distant plane.
And soft summer rain.
EOT

$page = query_gemini("titan://localhost:$port/raw/Haiku;size=77;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 gemini:\/\/localhost:$port\/page\/Haiku\r$/, "Haiku saved for localhost");

$page = query_gemini("gemini://localhost:$port/page/Haiku");
like($page, qr/Children shout and run/, "Haiku for localhost namespace found");
like($page, qr/^=> gemini:\/\/localhost:$port\/raw\/Haiku Raw text/m, "Links work inside localhost space");

$page = query_gemini("$base/page/Haiku");
like($page, qr/This page does not yet exist/, "Haiku for 127.0.0.1 in the main space still does not exist");

ok(!-d "$dir/127.0.0.1/127.0.0.1", "no duplication of host subdirectory");

$page = query_gemini("gemini://localhost:$port/do/changes");
like($page, qr/^=> gemini:\/\/localhost:$port\/page\/Haiku Haiku \(current\)$/m,
     "localhost haiku listed");

# save haiku in the berta space

$haiku = <<EOT;
Spoons scrape over plates
The sink is full of dishes
I love tomato soup
EOT

$page = query_gemini("titan://localhost:$port/berta/raw/Haiku;size=72;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 gemini:\/\/localhost:$port\/berta\/page\/Haiku\r$/, "Haiku saved for localhost/berta");

$page = query_gemini("$base/page/Haiku");
unlike($page, qr/Spoons scrape over plates/, "Haiku for 127.0.0.1 not found");

$page = query_gemini("gemini://localhost:$port/berta/page/Haiku");
like($page, qr/Spoons scrape over plates/, "Haiku for localhost/berta namespace found");
like($page, qr/^=> gemini:\/\/localhost:$port\/berta\/raw\/Haiku Raw text/m, "Links work inside localhost/berta space");

$page = query_gemini("gemini://$base/berta/page/Haiku");
unlike($page, qr/Spoons scrape over plates/, "Haiku for 127.0.0.1/berta namespace not found");

# List of all spaces

$page = query_gemini("$base/do/spaces");
like($page, qr/^=> gemini:\/\/localhost:$port\/berta\/ localhost\/berta$/m, "berta space listed");
like($page, qr/^=> gemini:\/\/localhost:$port\/ localhost$/m, "localhost space listed");
like($page, qr/^=> $base\/alex\/ 127\.0\.0\.1\/alex$/m, "alex space listed");
like($page, qr/^=> $base\/ 127\.0\.0\.1$/m, "127.0.0.1 space listed");

# Unified changes

$page = query_gemini("$base/do/all/changes");
like($page, qr/^=> gemini:\/\/localhost:$port\/berta\/page\/Haiku \[localhost\/berta\] Haiku \(current\)$/m,
     "berta haiku listed");
like($page, qr/^=> $base\/alex\/page\/Haiku \[127\.0\.0\.1\/alex\] Haiku \(current\)$/m,
     "alex haiku listed");
like($page, qr/^=> gemini:\/\/localhost:$port\/page\/Haiku \[localhost\] Haiku \(current\)$/m,
     "localhost haiku listed");

done_testing();