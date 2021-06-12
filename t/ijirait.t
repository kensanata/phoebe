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
like($page, qr(^And you, (\S+)\.)m, "And you");
like($page, qr(Ijiraq said “Welcome!”), "Welcome");

$page = query_gemini("$base/play/ijirait?Ijiraq");
like($page, qr(^# Ijiraq)m, "Heading");
like($page, qr(^A shape-shifter with red eyes\.)m, "Description");

$page = query_gemini("$base/play/ijirait/type?%22Hello%22");
like($page, qr(said “Hello”), "Hello");

$page = query_gemini("$base/play/ijirait?out");
like($page, qr(^30), "Redirect after a move");

$page = query_gemini("$base/play/ijirait?look");
like($page, qr(^# Outside The Tent)m, "Outside");

$page = query_gemini("$base/play/ijirait?tent");
like($page, qr(^30), "Redirect after a move");

$page = query_gemini("$base/play/ijirait?look");
like($page, qr(^# The Tent)m, "Back inside");

done_testing();
