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
use utf8; # tests contain UTF-8

my $msg;
if (not $ENV{TEST_AUTHOR}) {
  $msg = 'Contributions are an author test. Set $ENV{TEST_AUTHOR} to a true value to run.';
}
plan skip_all => $msg if $msg;

our @config = qw(ijirait.pl);
our $base;
our $port;
our $dir;
require './t/test.pl';

my $page = query_gemini("$base/play/ijirait");
like($page, qr(^20), "Ijirait");
like($page, qr(Ijiraq said “Welcome!”), "Welcome");
$page =~ /(\S+) \(you\)/;
my $name = $1;
ok($name, "Name set");

$page = query_gemini("$base/play/ijirait/examine?Ijiraq");
like($page, qr(^# Ijiraq)m, "Heading");
like($page, qr(^A shape-shifter with red eyes\.)m, "Description");

$page = query_gemini("$base/play/ijirait/type?say Hello");
like($page, qr(said “Hello”), "Hello");

$page = query_gemini("$base/play/ijirait/go?out");
like($page, qr(^30), "Redirect after a move");

$page = query_gemini("$base/play/ijirait/look");
like($page, qr(^# Outside The Tent)m, "Outside");

$page = query_gemini("$base/play/ijirait/go?tent");
like($page, qr(^30), "Redirect after a move");

$page = query_gemini("$base/play/ijirait/look");
like($page, qr(^# The Tent)m, "Back inside");

$page = query_gemini("$base/play/ijirait/describe?I%E2%80%99’m%20cool%2E");
like($page, qr(^30)m, "Redirect after describe");

$page = query_gemini("$base/play/ijirait/examine?$name");
like($page, qr(^# $name$)m, "Name");
like($page, qr(^I’m cool\.)m, "Description");

done_testing();
