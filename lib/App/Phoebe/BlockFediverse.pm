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

package App::Phoebe::BlockFediverse;
use App::Phoebe qw(@extensions);
use App::Phoebe::Web qw(http_error);
use Modern::Perl;

=head1 App::Phoebe::BlockFediverse

This extension blocks the Fediverse user agent from your website (Mastodon,
Friendica, Pleroma). The reason is this: when these sites federate a status
linking to your site, each instance will fetch a preview, so your site will get
hit by hundreds of requests from all over the Internet. Blocking them helps us
weather the storm.

There is no configuration. Simply add it to your F<config> file:

    use App::Phoebe::BlockFediverse;

=cut

push(@extensions, \&block_fediverse);

sub block_fediverse {
  my ($stream, $url, $headers) = @_;
  # quit as quickly as possible: return 1 means the request has been handled
  return 0 unless $headers and $headers->{"user-agent"} and $headers->{"user-agent"} =~ m!Mastodon|Friendica|Pleroma!i;
  http_error($stream, "Blocking Fediverse previews");
  return 1;
}

1;
