# Copyright (C) 2021  Alex Schroeder <alex@gnu.org>
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
use utf8;

our @use = qw(Capsules);

require './t/test.pl';

# variables set by test.pl
our $base;
our $host;
our $port;
our $dir;

my $haiku = <<"EOT";
On the red sofa
We both read our books at night
Winter nights are long
EOT

my $titan = "titan://$host:$port/capsule";

my $page = query_gemini("$base/capsule");
like($page, qr/^# Capsules/m, "Capsules");

my ($name) = $page =~ qr/^=> \S+ (\S+)/m;
ok($name, "Link to capsule");

$page = query_gemini("$base/capsule/$name");
like($page, qr/# $name/mi, "Title");
like($page, qr/^=> upload/m, "Upload link");

$page = query_gemini("$base/capsule/$name/upload");
like($page, qr/^10 /, "Filename");

$page = query_gemini("$base/capsule/$name/upload?haiku.gmi");
like($page, qr/^30 $base\/capsule\/$name\/haiku\.gmi/, "Redirect");

$page = query_gemini("$base/capsule/$name/haiku.gmi");
like($page, qr/This file does not exist. Upload it using Titan!/, "Invitation");

# no client cert
$page = query_gemini("$titan/$name/haiku.gmi;size=71;mime=text/plain;token=hello", $haiku, 0);
like($page, qr/^60 Uploading files requires a client certificate/, "Client certificate required");

$page = query_gemini("$titan/xxx/haiku.gmi;size=71;mime=text/plain;token=hello", $haiku);
like($page, qr/^61 This is not your space/, "Wrong client certificate");

$page = query_gemini("$base/capsule/login", undef, 0);
like($page, qr/^60 You need a client certificate to access your capsule/, "Login without certificate");

$page = query_gemini("$base/capsule/login");
$page =~ qr/^30 $base\/capsule\/([a-z]+)\r\n/;
is($name, $1, "Login");

$page = query_gemini("$titan/$name/haiku.gmi;size=71;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 $base\/capsule\/$name/, "Saved haiku");

$page = query_gemini("$base/capsule/$name/haiku.gmi");
is($page, "20 text\/gemini\r\n$haiku", "Read haiku");

$page = query_gemini("$base/capsule/$name");
like($page, qr/^=> $base\/capsule\/$name\/haiku\.gmi haiku\.gmi/m, "List haiku");

done_testing;
