# -*- mode: perl -*-
# Copyright (C) 2017–2021  Alex Schroeder <alex@gnu.org>

# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

=head1 App::Phoebe::Css

By default, Phoebe comes with its own, minimalistic CSS when serving HTML
rendition of pages: they all refer to C</default.css> and when this URL is
requested, Phoebe serves a small CSS.

With this extension, Phoebe serves an actual F<default.css> in the wiki
directory.

There is no configuration. Simply add it to your F<config> file:

    use App::Phoebe::Css;

Then create F<default.css> and make it look good. 😁

=cut

package App::Phoebe::Css;
use App::Phoebe qw($server $log);
use Modern::Perl;
use File::Slurper qw(read_text);

no warnings 'redefine';
*App::Phoebe::serve_css_via_http = \&serve_css_via_http;

sub serve_css_via_http {
  my $stream = shift;
  $log->debug("Serving default.css via HTTP");
  $stream->write("HTTP/1.1 200 OK\r\n");
  $stream->write("Content-Type: text/css\r\n");
  $stream->write("Cache-Control: public, max-age=86400, immutable\r\n"); # 24h
  $stream->write("\r\n");
  my $dir = $server->{wiki_dir};
  $stream->write(read_text("$dir/default.css"));
}
