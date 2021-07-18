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
use utf8; # tests contain UTF-8 characters and it matters

our $base;
our @use = qw(Wikipedia);

plan skip_all => 'Contributions are an author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# make sure starting phoebe starts knows localhost is the proxy
our @config = '$App::Phoebe::Wikipedia::host = "localhost";';

require './t/test.pl';

like(query_gemini("$base/"),
     qr/^10.*language/, "Top level is a prompt");
like(query_gemini("$base/?en"),
     qr/^30.*\/en\r\n/, "Redirect for the language");
like(query_gemini("$base/en"),
     qr/^10.*term/, "Search term prompt");
like(query_gemini("$base/en?Project%20Gemini"),
     qr/^30.*\/search\/en\/Project%20Gemini\r\n/, "Redirect for the term");

 SKIP: {
   skip "Making requests to Wikipedia requires \$ENV{TEST_AUTHOR} > 2", 2
       unless $ENV{TEST_AUTHOR} and $ENV{TEST_AUTHOR} > 2;

   like(query_gemini("$base/search/en/Project%20Gemini"),
	qr/^20/, "List of terms");
   like(query_gemini("$base/text/en/Project%20Gemini"),
	qr/^20/, "Term");

}

done_testing;
