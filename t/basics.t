# Copyright (C) 2017–2020  Alex Schroeder <alex@gnu.org>
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
use File::Slurper qw(write_text read_binary);
use utf8; # tests contain UTF-8 characters and it matters

our $host;
our $port;
our $base;
our $dir;
our @pages = qw(Alex Berta Chris);

require './t/test.pl';

# main menu
my $page = query_gemini("$base/");

unlike($page, qr/^=> .*\/$/m, "No empty links in the menu");

# --wiki_page
for my $item(qw(Alex Berta Chris)) {
  like($page, qr/^=> $base\/page\/$item $item/m, "main menu contains $item");
}

# upload text

my $titan = "titan://$host:$port";

my $haiku = <<EOT;
Quiet disk ratling
Keyboard clicking, then it stops.
Rain falls and I think
EOT

$page = query_gemini("$titan/raw/Haiku;size=76;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 $base\/page\/Haiku\r$/, "Titan Haiku");

$page = query_gemini("$base/page/Haiku");
like($page, qr/^20 text\/gemini; charset=UTF-8\r\n# Haiku\n$haiku/, "Haiku saved");

# plain text

$page = query_gemini("$base\/raw\/Haiku");
like($page, qr/$haiku/m, "Raw text");

# upload image

my $data = read_binary("t/alex.jpg");
my $size = length($data);
$page = query_gemini("$titan/raw/Alex;size=$size;mime=image/png;token=hello", $data);
# in this situation the client simply returns undef!?
# like($page, qr/^59 This wiki does not allow image\/png$/, "Upload image with wrong MIME type");
$page = query_gemini("$base/page/Alex");
like($page, qr/This page does not yet exist/, "Save of unsupported MIME type failed");

$page = query_gemini("$titan/raw/Alex;size=$size;mime=image/jpeg;token=hello", $data);
like($page, qr/^30 $base\/file\/Alex\r/, "Upload image");

# fake creation of some files for the blog

for (qw(2017-12-25 2017-12-26 2017-12-27)) {
  write_text("$dir/page/$_.gmi", "yo");
  unlink("$dir/index");
}

# blog on the main page
$page = query_gemini("$base/");
for my $item(qw(2017-12-25 2017-12-26 2017-12-27)) {
  like($page, qr/^=> $base\/page\/$item $item/m, "main menu contains $item");
}

# history

$haiku = <<EOT;
Muffled honking cars
Keyboard clicking, then it stops.
Rain falls and I think
EOT

$page = query_gemini("$titan/raw/Haiku;size=78;mime=text/plain;token=hello", $haiku);
like($page, qr/^30 $base\/page\/Haiku\r$/, "Titan Haiku 2");

$page = query_gemini("$base/history/Haiku");
like($page, qr/^=> $base\/page\/Haiku\/1 Haiku \(1\)/m, "Revision 1 is listed");
like($page, qr/^=> $base\/diff\/Haiku\/1 Diff/m, "Diff 1 link");
like($page, qr/^=> $base\/page\/Haiku Haiku \(current\)/m, "Current revision is listed");
$page = query_gemini("$base/page/Haiku/1");
like($page, qr/Quiet disk ratling/m, "Revision 1 content");

#diffs
$page = query_gemini("$base/diff/Haiku/1/colour");
like($page, qr/^> \e\[31m\e\[1mQuiet\e\[22m \e\[1mdisk\e\[22m \e\[1mratling\e\[22m\e\[0m/m, "Removed content");
like($page, qr/^> \e\[32m\e\[1mMuffled\e\[22m \e\[1mhonking\e\[22m \e\[1mcars\e\[22m\e\[0m\n$/sm, "Added content");

# index
$page = query_gemini("$base/do/index");
for my $item(qw(2017-12-25 2017-12-26 2017-12-27 Haiku)) {
  like($page, qr/^=> $base\/page\/$item $item$/m, "index contains $item");
}

# files
$page = query_gemini("$base/do/files");
for my $item(qw(Alex)) {
  like($page, qr/^=> $base\/file\/$item $item$/m, "files contains $item");
}

# match
$page = query_gemini("$base/do/match?2017");
for my $item(qw(2017-12-25 2017-12-26 2017-12-27)) {
  like($page, qr/^=> $base\/page\/$item $item$/m, "match menu contains $item");
}
like($page, qr/2017-12-27.*2017-12-26.*2017-12-25/s,
     "match menu sorted newest first");

# search
$page = query_gemini("$base/do/search?yo");
for my $item(qw(2017-12-25 2017-12-26 2017-12-27)) {
  like($page, qr/^=> $base\/page\/$item $item/m, "search menu contains $item");
}
like($page, qr/2017-12-27.*2017-12-26.*2017-12-25/s,
     "search menu sorted newest first");

# rc
$page = query_gemini("$base/do/changes");
like($page, qr/^=> $base\/page\/Haiku Haiku \(current\)/m, "Current revision of Haiku in recent chanegs");
like($page, qr/^=> $base\/page\/Haiku\/1 Haiku \(1\)/m, "Older revision of Haiku in recent chanegs");

# extension

$page = query_gemini($base);
like($page, qr/^=> gemini:\/\/localhost:1965\/do\/test Test\n/m, "Extension installed Test menu");
$page = query_gemini("$base/do/test");
like($page, qr/^Test\n/m, "Extension runs");

done_testing();
