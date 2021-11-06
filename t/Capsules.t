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
like($page, qr/^=> $base\/capsule\/$name\/upload/m, "Upload link");

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

# sharing and getting the temporary password

like($page, qr/^=> $base\/capsule\/$name\/share Share access/m, "Share link");

$page = query_gemini("$base/capsule/$name/share", undef, 0);
like($page, qr/^60 You need a client certificate/, "Sharing without certificate");

$page = query_gemini("$base/capsule/$name/share");
like($page, qr/^This password .*: (\S+)$/m, "Temporary password");
$page =~ qr/^This password .*: (\S+)$/m;
my $pwd = $1;
ok($pwd, "Password");

$page = query_gemini("$base/capsule/$name/share", undef, 2);
like($page, qr/^60 You need a different client certificate/, "Sharing with the wrong certificate");

# access using the temporary password

$page = query_gemini("$base/capsule/$name/access");
like($page, qr/^10/m, "Access requires password");

$page = query_gemini("$base/capsule/$name/access?$pwd", undef, 0);
like($page, qr/^60 You need a client certificate/, "Access without certificate");

$page = query_gemini("$base/capsule/$name/access?$pwd");
like($page, qr/^30 $base\/capsule\/$name/m, "Redirect to my own capsule");
ok(! -f "$dir/fingerprint_equivalents", "Fingerprint equivalents unnecessary");

$page = query_gemini("$base/capsule/$name/access?$pwd", undef, 2); # a different certificate
like($page, qr/^30 $base\/capsule\/$name/m, "Redirect to the same capsule");
ok(-f "$dir/fingerprint_equivalents", "Fingerprint equivalents saved");
like(read_text("$dir/fingerprint_equivalents"), qr/^sha256\S+ sha256\S+$/, "Fingerprint equivalents");

# testing the fingerprint equivalency

$page = query_gemini("$base/capsule/$name", undef, 2);
like($page, qr/# $name/mi, "Title");
like($page, qr/^=> $base\/capsule\/$name\/upload/m, "Equivalent upload link");

done_testing;
