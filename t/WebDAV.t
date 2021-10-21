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
use File::Slurper qw(write_text write_binary read_binary);
use utf8; # tests contain UTF-8 characters and it matters
use List::Util qw(first);

plan skip_all => 'This is an author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'This test requires HTTP::DAV.' unless eval { require HTTP::DAV };

our $host;
our $port;
our $dir;
our @use = qw(WebDAV);

require './t/test.pl';

# Make sure the user agent doesn't check hostname and cert validity
my $url = "https://$host:$port/";
my $dav = HTTP::DAV->new();
my $ua = $dav->get_user_agent();
$ua->ssl_opts(SSL_verify_mode => 0x00);
$ua->ssl_opts(verify_hostname => 0);

# Open a fresh wiki
ok($dav->open(-url => $url), "Open URL: " . $dav->message);
my $resource = $dav->propfind(-url=>"/", -depth=>1);
ok($resource->is_collection, "Found /");
my @list = $resource->get_resourcelist->get_resources;
my $item = first { $_->get_property('displayname') eq "page" } @list;
ok($item->is_collection, "Found /page");
$item = first { $_->get_property('displayname') eq "raw" } @list;
ok($item->is_collection, "Found /raw");
$item = first { $_->get_property('displayname') eq "file" } @list;
ok($item->is_collection, "Found /files");

# Attempt to write a file without credentials
my $str = "Ganymede\n";
ok(not($dav->put(-local=>\$str, -url=>"https://$host:$port/raw/Moon")),
   "Failed to post without token");

# Retry with credentials
$dav->credentials(-user => "alex", -pass => "hello", -realm => "Phoebe");
ok($dav->put(-local=>\$str, -url=>"https://$host:$port/raw/Moon"),
   "Post gemtext with token");

# /raw
$resource = $dav->propfind(-url=>"/raw", -depth=>1);
ok($resource->is_collection, "Found /raw");
@list = $resource->get_resourcelist->get_resources;
$item = first { $_->get_property('displayname') eq "Moon.gmi" } @list;
ok(!$item->is_collection, "Found /raw/Moon.gmi");
$str = undef;
$dav->get(-url=>"/raw/Moon", -to=>\$str);
like($str, qr/^Ganymede/, "Moon retrieved");

# /page
$resource = $dav->propfind(-url=>"/page", -depth=>1);
ok($resource->is_collection, "Found /page");
@list = $resource->get_resourcelist->get_resources;
$item = first { $_->get_property('displayname') eq "Moon.html" } @list;
ok(!$item->is_collection, "Found /page/Moon.html");
$str = undef;
$dav->get(-url=>"/page/Moon", -to=>\$str);
like($str, qr/<p>Ganymede/, "Moon retrieved");

# Upload a file
ok($dav->put(-local=>"t/alex.jpg", -url=>"https://$host:$port/file/Alex"),
   "Post file with token");
my $data;
$dav->get(-url=>"/file/Alex", -to=>\$data);
is($data, read_binary("t/alex.jpg"), "Alex retrieved");

done_testing();
