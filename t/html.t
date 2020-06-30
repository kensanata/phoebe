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
use utf8; # tests contain UTF-8 characters and it matters

our $host;
our $port;
our $base;
our $dir;

require './t/test.pl';

# set up the main space with some test data

mkdir("$dir/page");
write_text("$dir/page/Alex.gmi", "Alex Schroeder\n=> /page/Berta Berta");
mkdir("$dir/file");
write_binary("$dir/file/alex.jpg", read_binary("t/alex.jpg"));
mkdir("$dir/meta");
write_text("$dir/meta/alex.jpg", "content-type: image/jpeg");

# html

my $page = query_gemini("GET / HTTP/1.0\nhost: $host:$port\n");
like($page, qr!<a href="https://$host:$port/html/Alex">Alex</a>!, "main menu contains Alex");

my $page = query_gemini("GET /html/Alex HTTP/1.0\nhost: $host:$port\n");
like($page, qr!<p>Alex Schroeder!, "Alex content");
like($page, qr!<a href="/html/Berta">Berta</a>!, "Alex contains Berta link");

done_testing();
