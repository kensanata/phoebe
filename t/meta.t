# Copyright (C) 2017–2021  Alex Schroeder <alex@gnu.org>
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
use File::Slurper qw(read_text read_dir);

for my $module (grep /\.pl$/, read_dir("contrib")) {
  my $test = $module;
  $test =~ s/pl$/t/;
  ok(-f "t/$test", "$test exists");
  # these tests don't use 'like' to prevent errors from printing the entire source
  my $source = read_text("contrib/$module");
  ok($source =~ /^package App::Phoebe::/m, "$module is in a separate package");
  ok($source =~ /^use App::Phoebe qw/m, "$module uses the App::Phoebe module");
}

done_testing;
