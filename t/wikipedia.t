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
our @config = qw(wikipedia.pl);

plan skip_all => 'Contributions are author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# make sure starting phoebe starts knows localhost is the proxy
push(@config, <<"EOF");
\$App::Phoebe::Wikipedia::host = "localhost";
EOF

require './t/test.pl';

my $page = query_gemini("$base/");
like($page, qr/^10/, "Top level is a prompt");

done_testing;
