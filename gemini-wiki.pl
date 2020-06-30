#!/usr/bin/env perl
# Copyright (C) 2017–2020  Alex Schroeder <alex@gnu.org>

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

=encoding utf8

=head1 Gemini Wiki

This server serves a wiki as a Gemini site.

It does two and a half things:

=over

=item It's a program that you run on a computer and other people connect to it
      using their L<client|https://gemini.circumlunar.space/clients.html> in
      order to read the pages on it.

=item It's a wiki, which means that people can edit the pages without needing an
      account. All they need is a client that speaks both
      L<Gemini|https://gemini.circumlunar.space/> and Titan, and the password.
      The default password is "hello". 😃

=item People can also access it using a regular web browser. They'll get a very
      simple, read-only version of the site.

=back

=head2 How do you edit a Gemini Wiki?

You need to use a Titan-enabled client.

Known clients:

=over

=item L<Gemini Write|https://alexschroeder.ch/cgit/gemini-write/> is an
      extension for the Emacs Gopher and Gemini client
      L<Elpher|https://thelambdalab.xyz/elpher/>

=item L<Gemini & Titan for Bash|https://alexschroeder.ch/cgit/gemini-titan/about/?h=main>
      are two shell functions that allow you to download and upload files

=back

=head2 What is Titan?

Titan is a companion protocol to Gemini: it allows clients to upload files to
Gemini sites, if servers allow this. On the Gemini Wiki, you can edit "raw"
pages. That is, at the bottom of a page you'll see a link to the "raw" page. If
you follow it, you'll see the page content as plain text. You can submit a
changed version of this text to the same URL using Titan. There is more
information for developers available
L<on Community Wiki|https://communitywiki.org/wiki/Titan>.

=head2 Dependencies

Perl libraries you need to install if you want to run Gemini Wiki:

=over

=item L<Algorithm::Diff>

=item L<File::ReadBackwards>

=item L<File::Slurper>

=item L<Modern::Perl>

=item L<Net::Server>

=item L<URI::Escape>

=back

I'm going to be using F<curl> and F<openssl> in the L</Quickstart> instructions,
so you'll need those tools as well.

On Debian:

    sudo apt install \
      libalgorithm-diff-xs-perl \
      libfile-readbackwards-perl \
      libfile-slurper-perl \
      libmodern-perl-perl \
      libnet-server-perl \
      liburi-escape-xs-perl \
      curl openssl

=head2 Quickstart

Right now there aren't any releases. You just get the latest version from the
repository and that's it. I'm going to assume that you're going to create a new
user just to be safe.

    sudo adduser --disabled-login --disabled-password gemini
    sudo su gemini
    cd

Now you're in your home directory, F</home/gemini>. We're going to install
things right here. First, get the source code:

    curl --output gemini-wiki.pl \
      https://alexschroeder.ch/cgit/gemini-wiki/plain/gemini-wiki.pl?h=main

Since Gemini traffic is encrypted, we need to generate a certificate and a key.
These are both stored in PEM files. To create your own copies of these files
(and you should!), use the following:

    openssl req -new -x509 -nodes -out cert.pem -keyout key.pem

You should have three files, now: F<gemini-wiki.pl>, F<cert.pem>, and
F<key.pem>. That's enough to get started! Start the server:

    perl gemini-wiki.pl

This starts the server in the foreground. Open a second terminal and test it:

    echo gemini://localhost \
      | openssl s_client --quiet --connect localhost:1965 2>/dev/null

You should see a Gemini page starting with the following:

    20 text/gemini; charset=UTF-8
    Welcome to the Gemini version of this wiki.

Success!! 😀 🚀🚀

Let's create a new page using the Titan protocol, from the command line:

    echo "Welcome to the wiki!" > test.txt
    echo "Please be kind." >> test.txt
    echo "titan://localhost/raw/"`date --iso-8601=date`";mime=text/plain;size="`wc --bytes < test.txt`";token=hello" \
      | cat - test.txt | openssl s_client --quiet --connect localhost:1965 2>/dev/null

You should get a nice redirect message, with an appropriate date.

    30 gemini://localhost:1965/page/2020-06-27

You can check the page, now (replacing the appropriate date):

    echo gemini://localhost:1965/page/2020-06-27 \
      | openssl s_client --quiet --connect localhost:1965 2>/dev/null

You should get back a page that starts as follows:

    20 text/gemini; charset=UTF-8
    Welcome to the wiki!
    Please be kind.

Yay! 😁🎉 🚀🚀

=head2 Wiki Directory

You home directory should now also contain a wiki directory called F<wiki>. In
it, you'll find a few more files:

=over

=item F<page> is the directory with all the page files in it

=item F<index> is a file containing all the files in your F<page> directory for
      quick access; if you create new files in the F<page> directory, you should
      delete the F<index> file – dont' worry, it will get regenerated when
      needed

=item F<keep> is the directory with all the old revisions of pages in it – if
      you've only made one change, then it won't exist, yet; and if you don't
      care about the older revisions, you can delete them

=item F<file> is the directory with all the uploaded files in it – if you
      haven't uploaded any files, then it won't exist, yet; you must explicitly
      allow MIME types for upload using the C<--wiki_mime_type> option (see
      I<Options> below)

=item F<meta> is the directory with all the meta data for uploaded files in it –
      there should be a file here for every file in the F<file> directory; if
      you create new files in the F<file> directory, you should create a
      matching file here

=item F<changes.log> is a file listing all the pages made to the wiki; if you
      make changes to the files in the F<page> or F<file> directory, they aren't
      going to be listed in this file and thus people will be confused by the
      changes you made – your call (but in all fairness, if you're collaborating
      with others you probably shouldn't do this)

=item F<config> probably doesn't exist, yet; it is an optional file containing
      Perl code where you can mess with the code (see L</Configuration> below)

=back

=head2 Options

The Gemini Wiki has a bunch of options, and it uses L<Net::Server> in the
background, which has even more options. Let's try to focus on the options you
might want to use right away.

Here's an example:

    perl gemini-wiki.pl \
      --wiki_token=Elrond \
      --wiki_token=Thranduil \
      --wiki_pages=Welcome \
      --wiki_pages=About

And here's some documentation:

=over

=item C<--wiki_token> is for the token that users editing pages have to provide;
      the default is "hello"; you can use this option multiple times and give
      different users different passwords, if you want

=item C<--wiki_main_page> is the page containing your header for the main page;
      that's were you would put your ASCII art header, your welcome message, and
      so on, see L</Main Page and Title> below

=item C<--wiki_pages> is an extra page to show in the main menu; you can use
      this option multiple times

=item C<--wiki_mime_type> is a MIME type to allow for uploads; text/plain is
      always allowed and doesn't need to be listed; you can also just list the
      type without a subtype, eg. C<image> will allow all sorts of images (make
      sure random people can't use your server to exchange images – set a
      password using C<--wiki_token>)

=item C<--host> is the hostname to serve; the default is C<localhost> – you
      probably want to pick the name of your machine, if it is reachable from
      the Internet

=item C<--port> is the port to use; the default is 1965

=item C<--wiki_dir> is the wiki data directory to use; the default is either the
      value of the C<GEMINI_WIKI_DATA_DIR> environment variable, or the "./wiki"
      subdirectory

=item C<--cert_file> is the certificate PEM file to use; the default is
      F<cert.pem>

=item C<--key_file> is the private key PEM file to use; the default is
      F<key.pem>

=item C<--log_level> is the log level to use, 0 is quiet, 1 is errors, 2 is
      warnings, 3 is info, and 4 is debug; the default is 2

=back

=head2 Running the Gemini Wiki as a Daemon

If you want to start the Gemini Wiki as a daemon, the following options come in
handy:

=over

=item C<--setsid> makes sure the Gemini Wiki runs as a daemon in the background

=item C<--pid_file> is the file where the process id (pid) gets written once the
      server starts up; this is useful if you run the server in the background
      and you need to kill it

=item C<--log_file> is the file to write logs into; the default is to write log
      output to the standard error (stderr)

=item C<--user> and C<--group> might come in handy if you start the Gemini Wiki
      using a different user

=back

=head2 Using systemd

I have no idea. Help me out?

=head2 Security

The server uses "access tokens" to check whether people are allowed to edit
files. You could also call them "passwords", if you want. They aren't associated
with a username. You set them using the C<--wiki_token> option. By default, the
only password is "hello". That's why the Titan command above contained
"token=hello". 😊

If you're going to check up on your wiki often, looking at Recent Changes on a
daily basis, you could just tell people about the token on a page of your wiki.
Spammers would at least have to read the instructions and in my experience the
hardly ever do.

You could also create a separate password for every contributor and when they
leave the project, you just remove the token from the options and restart Gemini
Wiki. They will no longer be able to edit the site.

=head2 Privacy

The server only actively logs changes to pages. It calculates a "code" for every
contribution: its a four digit octal code. The idea is that you could colour
every digit using one of the eight standard terminal colours and thus get little
four-coloured flags.

This allows you to make a pretty good guess about edits made by the same person,
without telling you their IP numbers.

The code is computed as follows: the IP numbers is turned into a 32bit number
using a hash function, converted to octal, and the first four digits are the
code. Thus all possible IP numbers are mapped into 8⁴=4096 codes.

If you increase the log level, the server will produce more output, including
information about the connections happening, like C<2020/06/29-15:35:59 CONNECT
SSL Peer: "[::1]:52730" Local: "[::1]:1965"> and the like (in this case C<::1>
is my local address so that isn't too useful but it could also be your visitor's
IP numbers, in which case you will need to tell them about it using in order to
comply with the
L<GDPR|https://en.wikipedia.org/wiki/General_Data_Protection_Regulation>.

=head2 Files

If you allow uploads of binary files, these are stored separately from the
regular pages; the wiki also doesn't keep old revisions of files around. That
also means that if somebody overwrites a file, the old revision is gone.

You definitely don't want random people uploading all sorts of images, videos
and binaries files to your server. Make sure you set up those L<tokens|/Security>
using C<--wiki_token>!

=head2 Main Page and Title

The main page will include ("transclude") a page of your choosing if you use the
C<--wiki_main_page> option. This also sets the title of your wiki in various
places like the RSS and Atom feeds.

=head2 Limited, read-only HTTP support

You can actually look at your wiki pages using a browser! But beware: these days
browser will refuse to connect to sites that have self-signed certificates.
You'll have to click buttons and make exceptions and all of that, or get your
certificate from Let's Encrypt or the like. Anyway, it works in theory. If you
went through the L</Quickstart>, visiting C<https://localhost:1965/> should
work!

Notice that Gemini Wiki doesn't have to live behind another web server like
Apache or nginx. It's a (simple) web server, too!

Here's how you could serve the wiki both on Gemini, and the standard HTTPS port,
443:

    sudo ./gemini-wiki.pl --port=443 --port=1965 \
      --user=$(id --user --name) --group=$(id --group  --name)

We need to use F<sudo> because all the ports below 1024 are priviledge ports and
that includes the standard HTTPS port. Since we don't want the server itself to
run with all those priviledges, however, I'm using the C<--user> and C<--group>
options to change effective and user and group ID. The F<id> command is used to
get your user and your group IDs instead. If you've followed the L</Quickstart>
and created a separate C<gemini> user, you could simply use C<--user=gemini> and
C<--group=gemini> instead. 👍

=head2 Configuration

This section describes some hooks you can use to customize your wiki using the
F<config> file.

=over

=item C<@extensions> is a list of additional URLs you want the wiki to handle;
      return 1 if you handle a URL

=item C<@main_menu> adds more lines to the main menu, possibly links that aren't
      simply links to existing pages

=back

The following example illustrates this:

    package Gemini::Wiki;
    use Modern::Perl;
    our (@extensions, @main_menu);
    push(@main_menu, "=> gemini://localhost/do/test Test");
    push(@extensions, \&serve_test);
    sub serve_test {
      my $self = shift;
      my $url = shift;
      my $host = $self->host();
      my $port = $self->port();
      if ($url =~ m!^gemini://$host(:$port)?/do/test$!) {
	say "20 text/plain\r";
	say "Test";
	return 1;
      }
      return;
    }
    1;

=cut

package Gemini::Wiki;
use Encode qw(encode_utf8 decode_utf8);
use File::Slurper qw(read_text read_binary read_lines read_dir write_text write_binary);
use List::Util qw(first min);
use Modern::Perl '2018';
use Pod::Text;
use URI::Escape;
use Algorithm::Diff;
use File::ReadBackwards;
use B;
use base qw(Net::Server::Fork); # any personality will do

# Gemini server variables you can set in the config file
our (@extensions, @main_menu);

# Help
if ($ARGV[0] and $ARGV[0] eq '--help') {
  my $parser = Pod::Text->new();
  $parser->parse_file($0);
  exit;
}

# Sadly, we need this information before doing anything else
my %args = (proto => 'ssl', SSL_cert_file => 'cert.pem', SSL_key_file => 'key.pem');
for (grep(/--(key|cert)_file=/, @ARGV)) {
  $args{SSL_cert_file} = $1 if /--cert_file=(.*)/;
  $args{SSL_key_file} = $1 if /--key_file=(.*)/;
}
die "I must have both --key_file and --cert_file\n"
    unless $args{SSL_cert_file} and $args{SSL_key_file};

my $env = {};
my $protocols = 'https?|ftp|afs|news|nntp|mid|cid|mailto|wais|prospero|telnet|gophers?|irc|feed';
my $chars = '[-a-zA-Z0-9/@=+$_~*.,;:?!\'"()&#%]'; # see RFC 2396
$env->{full_url_regexp} ="((?:$protocols):$chars+)"; # when used in square brackets

my $server = Gemini::Wiki->new($env);
$server->run(%args);

sub default_values {
  return {
    host => 'localhost',
    port => 1965,
    wiki_token => ['hello'],
    wiki_space => [],
    wiki_mime_type => [],
    wiki_dir => './wiki',
    wiki_main_page => '',
    wiki_page_size_limit => 100000,
  };
}

sub options {
  my $self = shift;
  my $prop = $self->{'server'};
  my $template = shift;
  $self->SUPER::options($template);
  $prop->{wiki_dir} ||= undef;
  $template->{wiki_dir} = \$prop->{wiki_dir};
  $prop->{wiki_main_page} ||= undef;
  $template->{wiki_main_page} = \$prop->{wiki_main_page};
  $prop->{wiki_token} ||= [];
  $template->{wiki_token} = $prop->{wiki_token};
  $prop->{wiki_pages} ||= [];
  $template->{wiki_pages} = $prop->{wiki_pages};
  $prop->{wiki_space} ||= [];
  $template->{wiki_space} = $prop->{wiki_space};
  $prop->{wiki_mime_type} ||= [];
  $template->{wiki_mime_type} = $prop->{wiki_mime_type};
  $prop->{wiki_page_size_limit} ||= undef;
  $template->{wiki_page_size_limit} = \$prop->{wiki_page_size_limit};
}

sub post_configure_hook {
  my $self = shift;
  $self->{server}->{wiki_dir} = $ENV{GEMINI_WIKI_DATA_DIR} if $ENV{GEMINI_WIKI_DATA_DIR};
  $self->log(3, "PID $$");
  $self->log(3, "Host " . ("@{$self->{server}->{host}}" || "*"));
  $self->log(3, "Port @{$self->{server}->{port}}");
  $self->log(3, "Token @{$self->{server}->{wiki_token}}");
  $self->log(3, "Main $self->{server}->{wiki_main_page}");
  $self->log(3, "Pages @{$self->{server}->{wiki_pages}}");
  $self->log(3, "Space @{$self->{server}->{wiki_space}}");
  $self->log(3, "MIME types @{$self->{server}->{wiki_mime_type}}");

  # Note: if you use sudo to run gemini-server.pl, these options might not work!
  $self->log(4, "--wikir_dir says $self->{server}->{wiki_dir}");
  $self->log(4, "\$GEMINI_WIKI_DATA_DIR says " . ($ENV{GEMINI_WIKI_DATA_DIR}||""));
  $self->log(3, "Wiki data directory is $self->{server}->{wiki_dir}");
}

run();

sub success {
  my $self = shift;
  my $type = shift || 'text/gemini; charset=UTF-8';
  my $lang = shift;
  if ($lang) {
    say "20 $type; lang=$lang\r";
  } else {
    say "20 $type\r";
  }
}

sub host {
  my $self = shift;
  return $self->{server}->{host}->[0]
      || $self->{server}->{sockaddr};
}

sub port {
  my $self = shift;
  return $self->{server}->{sockport};
}

# if you call this yourself, $id must look like "page/foo"
sub link {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $schema = shift || "gemini";
  my $host = $self->host();
  my $port = $self->port();
  # don't encode the slash
  return "$schema://$host:$port/"
      . ($space ? uri_escape_utf8($space) . "/" : "")
      . join("/", map { uri_escape_utf8($_) } split (/\//, $id));
}

sub link_html {
  my $self = shift;
  my $space = shift;
  my $title = shift;
  my $id = shift;
  if (not $id) {
    $id = "html/$title";
  }
  my $host = $self->host();
  my $port = $self->port();
  # don't encode the slash
  return "<a href=\"https://$host:$port/"
      . ($space ? "$space/" : "")
      . join("/", map { uri_escape_utf8($_) } split (/\//, $id))
      . "\">"
      . $self->quote_html($title)
      . "</a>";
}

sub gemini_link {
  my $self = shift;
  my $space = shift;
  my $title = shift;
  my $id = shift;
  if (not $id) {
    $id = "page/$title";
  }
  return "=> $id $title" if $id =~ /^$self->{server}->{full_url_regexp}$/;
  my $url = $self->link($space, $id);
  return "=> $url $title";
}

sub print_link {
  my $self = shift;
  my $space = shift;
  my $title = shift;
  my $id = shift;
  say $self->gemini_link($space, $title, $id);
}

sub pages {
  my $self = shift;
  my $space = shift;
  my $re = shift;
  my $dir = $self->{server}->{wiki_dir};
  $dir .= "/$space" if $space;
  my $index = "$dir/index";
  if (not -f $index) {
    return if not -d "$dir/page";
    my @pages = map { s/\.gmi$//; $_ } read_dir("$dir/page");
    write_text($index, join("\n", @pages, ""));
    return @pages;
  }
  return grep /$re/i, read_lines $index if $re;
  return read_lines $index;
}

sub blog_pages {
  my $self = shift;
  my $space = shift;
  return sort { $b cmp $a } $self->pages($space, '^\d\d\d\d-\d\d-\d\d');
}

sub blog {
  my $self = shift;
  my $space = shift;
  my @blog = $self->blog_pages($space);
  return unless @blog;
  say "Blog:";
  # we should check for pages marked for deletion!
  for my $id (@blog[0..min($#blog, 9)]) {
    $self->print_link($space, $id);
  }
  $self->print_link($space, "More...", "do/more") if @blog > 10;
  say "";
}

sub blog_html {
  my $self = shift;
  my $space = shift;
  my @blog = $self->blog_pages($space);
  return unless @blog;
  say "<p>Blog:";
  say "<ul>";
  # we should check for pages marked for deletion!
  for my $id (@blog[0..min($#blog, 9)]) {
    say "<li>" . $self->link_html($space, $id);
  }
  say "</ul>";
}

sub serve_main_menu {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving main menu $space");
  $self->success();
  my $page = $self->{server}->{wiki_main_page};
  if ($page) {
    say $self->text($space, $page);
  } else {
    say "# Welcome to the Gemini Wiki!";
    say "";
  }
  $self->blog($space);
  for my $id (@{$self->{server}->{wiki_pages}}) {
    $self->print_link($space, $id);
  }
  for my $line (@main_menu) {
    say $line;
  }
  $self->print_link($space, "Recent Changes", "do/changes");
  $self->print_link($space, "Search matching page names", "do/match");
  $self->print_link($space, "Search matching page content", "do/search");
  $self->print_link($space, "New page", "do/new");
  say "";
  $self->print_link($space, "Index of all pages", "do/index");
  # a requirement of the GNU Affero General Public License
  $self->print_link(undef, "Source code", "do/source");
  say "";
}

sub serve_main_menu_via_http {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving main menu via HTTP");
  my $page = $self->{server}->{wiki_main_page};
  say "HTTP/1.1 200 OK\r";
  say "Content-Type: text/html\r";
  say "\r";
  say "<!DOCTYPE html>";
  say "<html>";
  say "<head>";
  say "<meta charset=\"utf-8\">";
  if ($page) {
    say "<title>" . $self->quote_html($page) . "</title>";
  } else {
    say "<title>Gemini Wiki</title>";
  }
  say "</head>";
  say "<body>";
  if ($page) {
    $self->print_html($space, $page);
  } else {
    say "<h1>Welcome to the Gemini Wiki!</h1>";
  }
  $self->blog_html($space);
  say "<p>Important links:";
  say "<ul>";
  my @pages = @{$self->{server}->{wiki_pages}};
  for my $id (@pages) {
    say "<li>" . $self->link_html($space, $id);
  }
  say "<li>" . $self->link_html($space, "Index of all pages", "do/index");
  say "<li>" . $self->link_html($space, "Atom feed", "do/atom");
  say "<li>" . $self->link_html($space, "RSS feed", "do/rss");
  # a requirement of the GNU Affero General Public License
  say "<li>" . $self->link_html("Source", "do/source");
  say "</ul>";
  say "</body>";
  say "</html>";
}

sub quote_html {
  my $self = shift;
  my $html = shift;
  $html =~ s/&/&amp;/g;
  $html =~ s/</&lt;/g;
  $html =~ s/>/&gt;/g;
  $html =~ s/[\x00-\x08\x0b\x0c\x0e-\x1f]/ /g; # legal xml: #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
  return $html;
}

sub serve_blog {
  my $self = shift;
  my $space = shift;
  $self->success();
  $self->log(3, "Serving blog");
  say "# Blog";
  my @blog = $self->blog($space);
  say "The are no blog pages." unless @blog;
  for my $id (@blog) {
    $self->print_link($space, $id);
  }
}

sub serve_index {
  my $self = shift;
  my $space = shift;
  $self->success();
  $self->log(3, "Serving index of all pages");
  say "# All Pages";
  my @pages = $self->pages($space);
  say "The are no pages." unless @pages;
  for my $id (sort { $self->newest_first($a, $b) } @pages) {
    $self->print_link($space, $id);
  }
}

sub serve_index_via_http {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving index of all pages via HTTP");
  say "HTTP/1.1 200 OK\r";
  say "Content-Type: text/html\r";
  say "\r";
  say "<!DOCTYPE html>";
  say "<html>";
  say "<head>";
  say "<meta charset=\"utf-8\">";
  say "<title>All Pages</title>";
  say "</head>";
  say "<body>";
  say "<h1>All Pages</h1>";
  my @pages = $self->pages($space);
  if (@pages) {
    say "<ul>";
    for my $id (sort { $self->newest_first($a, $b) } @pages) {
      say "<li>" . $self->link_html($space, $id);
    }
    say "</ul>";
  } else {
    say "<p>The are no pages."
  }
}

sub serve_match {
  my $self = shift;
  my $space = shift;
  my $match = shift;
  if (not $match) {
    say("59 Search term is missing\r");
    return;
  }
  $self->success();
  $self->log(3, "Serving pages matching $match");
  say "# Search page titles for $match";
  say "Use a Perl regular expression to match page titles.";
  my @pages = $self->pages($space, $match);
  say "No matching page names found." unless @pages;
  for my $id (sort { $self->newest_first($a, $b) } @pages) {
    $self->print_link($space, $id);
  }
}

sub serve_search {
  my $self = shift;
  my $space = shift;
  my $str = shift;
  if (not $str) {
    say("59 Search term is missing\r");
    return;
  }
  $self->success();
  $self->log(3, "Serving search result for $str");
  say "# Search page content for $str";
  say "Use a Perl regular expression to match page titles and page content.";
  if (not $self->search($space, $str, sub { $self->highlight(@_) })) {
    say "Search term not found."
  }
}

sub search {
  my $self = shift;
  my $space = shift;
  my $str = shift;
  my $func = shift;
  my @pages = sort { $self->newest_first($a, $b) } $self->pages($space);
  return unless @pages;
  my $found = 0;
  for my $id (@pages) {
    my $text = $self->text($space, $id);
    if ($id =~ /$str/ or $text =~ /$str/) {
      $func->($space, $id, $text, $str);
      $found++;
    }
  }
  return $found;
}

sub highlight {
  my $self = shift;
  my $space = shift;
  $self->log(4, "highlight: @_");
  my $id = shift;
  my $text = shift;
  my $str = shift;
  my ($snippetlen, $maxsnippets) = (100, 4); #  these seem nice.
  # show a snippet from the beginning of the document
  my $j = index($text, ' ', $snippetlen); # end on word boundary
  my $t = substr($text, 0, $j);
  my $result = "## $id\n$t … ";
  $text = substr($text, $j);  # to avoid rematching
  my $jsnippet = 0 ;
  while ($jsnippet < $maxsnippets and $text =~ m/($str)/i) {
    $jsnippet++;
    if (($j = index($text, $1)) > -1 ) {
      # get substr containing (start of) match, ending on word boundaries
      my $start = index($text, ' ', $j - $snippetlen / 2);
      $start = 0 if $start == -1;
      my $end = index($text, ' ', $j + $snippetlen / 2);
      $end = length($text) if $end == -1;
      $t = substr($text, $start, $end - $start);
      $result .= $t . ' … ';
      # truncate text to avoid rematching the same string.
      $text = substr($text, $end);
    }
  }
  say $result;
  $self->print_link($space, $id);
}

sub serve_changes {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving recent changes");
  $self->success();
  say "# Recent Changes";
  $self->print_link($space, "Show Atom", "do/atom");
  $self->print_link($space, "Show RSS", "do/rss");
  my $dir = $self->{server}->{wiki_dir};
  $dir .= "/$space" if $space;
  my $log = "$dir/changes.log";
  if (not -e $log) {
    say "No changes.";
    return;
  } elsif (my $fh = File::ReadBackwards->new($log)) {
    my $last_day = '';
    my %seen;
    for (1 .. 100) {
      last unless $_ = $fh->readline;
      chomp;
      my ($ts, $id, $revision, $code) = split(/\x1f/);
      my $day = $self->day($ts);
      if ($day ne $last_day) {
	say "## $day";
	$last_day = $day;
      }
      say $self->time_of_day($ts) . " by " . $self->colourize($code);
      if ($seen{$id}) {
	if ($revision) {
	  $self->print_link($space, "$id ($revision)", "page/$id/$revision");
	} else {
	  say "$id (file)";
	}
      } else {
	$seen{$id} = 1;
	if ($revision) {
	  $self->print_link($space, "$id (current)", "page/$id");
	} else {
	  $self->print_link($space, "$id (file)", "file/$id");
	}
      }
    }
  } else {
    say "Error: $!";
  }
}

sub colourize {
  my $self = shift;
  my $code = shift;
  $code = join("", map { "\033[3${_};4${_}m${_}" } split //, $code) . "\033[0m ";
  return $code;
}

sub serve_rss {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving Gemini RSS");
  $self->success("application/rss+xml");
  $self->rss($space, 'gemini');
}

sub serve_rss_via_http {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving RSS via HTTP");
  say "HTTP/1.1 200 OK\r";
  say "Content-Type: application/xml\r";
  say "\r";
  $self->rss($space, 'https');
}

sub rss {
  my $self = shift;
  my $space = shift;
  my $schema = shift;
  my $name = $self->{server}->{wiki_main_page} || "Gemini Wiki";
  my $host = $self->host();
  my $port = $self->port();
  say "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">";
  say "<channel>";
  say "<title>" . $self->quote_html($name) . "</title>";
  say "<description>Recent changes on this wiki.</description>";
  say "<link>$schema://$host:$port/</link>";
  say "<atom:link rel=\"self\" type=\"application/rss+xml\" href=\"$schema://$host:$port/do/rss\" />";
  say "<generator>Gemini Wiki</generator>";
  say "<docs>http://blogs.law.harvard.edu/tech/rss</docs>";
  my $dir = $self->{server}->{wiki_dir};
  $dir .= "/$space" if $space;
  my $log = "$dir/changes.log";
  if (-e $log and my $fh = File::ReadBackwards->new($log)) {
    my %seen;
    for (1 .. 100) {
      last unless $_ = $fh->readline;
      chomp;
      my ($ts, $id, $revision, $code) = split(/\x1f/);
      next if $seen{$id};
      $seen{$id} = 1;
      say "<item>";
      say "<title>" . $self->quote_html($id) . "</title>";
      my $link = $self->link($space, "page/$id", $schema);
      say "<link>$link</link>";
      say "<guid>$link</guid>";
      say "<description>" . $self->quote_html($self->text($space, $id)) . "</description>";
      my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime($ts); # Sat, 07 Sep 2002 00:00:01 GMT
      say "<pubDate>"
	  . sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT", qw(Sun Mon Tue Wed Thu Fri Sat)[$wday], $mday,
		    qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon], $year + 1900, $hour, $min, $sec)
	  . "</pubDate>";
      say "</item>";
    }
  }
  say "</channel>";
  say "</rss>";
}

sub serve_atom {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving Gemini Atom");
  $self->success("application/atom+xml");
  $self->atom($space, 'gemini');
}

sub serve_atom_via_http {
  my $self = shift;
  my $space = shift;
  $self->log(3, "Serving Atom via HTTP");
  say "HTTP/1.1 200 OK\r";
  say "Content-Type: application/xml\r";
  say "\r";
  $self->atom($space, 'https');
}

sub atom {
  my $self = shift;
  my $space = shift;
  my $schema = shift;
  my $name = $self->{server}->{wiki_main_page} || "Gemini Wiki";
  my $host = $self->host();
  my $port = $self->port();
  say "<?xml version=\"1.0\" encoding=\"utf-8\"?>";
  say "<feed xmlns=\"http://www.w3.org/2005/Atom\">";
  say "<title>" . $self->quote_html($name) . "</title>";
  say "<link href=\"$schema://$host:$port/\"/>";
  say "<link rel=\"self\" type=\"application/atom+xml\" href=\"$schema://$host:$port/do/atom\"/>";
  say "<id>$schema://$host:$port/do/atom</id>";
  my $dir = $self->{server}->{wiki_dir};
  $dir .= "/$space" if $space;
  my $log = "$dir/changes.log";
  my ($sec, $min, $hour, $mday, $mon, $year) = gmtime($self->modified($log)); # 2003-12-13T18:30:02Z
  say "<updated>"
      . sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year + 1900, $mon, $mday, $hour, $min, $sec)
      . "</updated>";
  say "<generator uri=\"https://alexschroeder.ch/cgit/gemini-wiki/about/\" version=\"1.0\">Gemini Wiki</generator>";
  if (-e $log and my $fh = File::ReadBackwards->new($log)) {
    my %seen;
    for (1 .. 100) {
      last unless $_ = $fh->readline;
      chomp;
      my ($ts, $id, $revision, $code) = split(/\x1f/);
      next if $seen{$id};
      $seen{$id} = 1;
      say "<entry>";
      say "<title>" . $self->quote_html($id) . "</title>";
      my $link = $self->link($space, "page/$id", $schema);
      say "<link href=\"$link\"/>";
      say "<id>$link</id>";
      say "<summary>" . $self->quote_html($self->text($space, $id)) . "</summary>";
      ($sec, $min, $hour, $mday, $mon, $year) = gmtime($ts); # 2003-12-13T18:30:02Z
      say "<updated>"
	  . sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year + 1900, $mon, $mday, $hour, $min, $sec)
	  . "</updated>";
      say "<author><name>$code</name></author>";
      say "</entry>";
    }
  }
  say "</feed>";
}

sub serve_raw {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serving raw $id");
  $self->success('text/plain; charset=UTF-8');
  print $self->text($space, $id, $revision);
}

sub serve_diff {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serving the diff of $id");
  $self->success();
  say "# Differences for $id";
  say "Showing the differences between revision $revision and the current revision of $id.";
  # Order is important because $new is a reference to %Page!
  my $new = $self->text($space, $id);
  my $old = $self->text($space, $id, $revision);
  say "```";
  say $self->diff($old, $new);
  say "```";
}

sub diff {
  my $self = shift;
  my @old = split(/\n/, shift);
  my @new = split(/\n/, shift);
  $self->log(4, "Preparing a diff");
  my $diff = Algorithm::Diff->new(\@old, \@new);
  $diff->Base(1); # line numbers, not indices
  my $result = '';
  while($diff->Next()) {
    next if $diff->Same();
    my $sep = '';
    if(not $diff->Items(2)) {
      $result .= "%d,%dd%d\n", $diff->Get(qw(Min1 Max1 Max2));
    } elsif(not $diff->Items(1)) {
      $result .= sprintf "%da%d,%d\n", $diff->Get(qw(Max1 Min2 Max2));
    } else {
      $sep = "---\n";
      $result .= sprintf "%d,%dc%d,%d\n", $diff->Get(qw(Min1 Max1 Min2 Max2));
    }
    $result .= "< $_\n" for $diff->Items(1);
    $result .= $sep;
    $result .= "> $_\n" for $diff->Items(2);
  }
  return $result;
}

sub serve_html {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  $self->success('text/html');
  $self->log(3, "Serving $id as HTML");
  $self->html_page($space, $id, $revision);
}

sub serve_html_via_http {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serving $id as HTML via HTTP");
  say "HTTP/1.1 200 OK\r";
  say "Content-Type: text/html\r";
  say "\r";
  $self->html_page($space, $id, $revision);
}

sub html_page {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  say "<!DOCTYPE html>";
  say "<html>";
  say "<head>";
  say "<meta charset=\"utf-8\">";
  say "<title>" . $self->quote_html($id) . "</title>";
  say "</head>";
  say "<body>";
  $self->print_html($space, $id, $revision);
  say "</body>";
  say "</html>";
}

sub print_html {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  say "<h1>" . $self->quote_html($id) . "</h1>";
  my $text = $self->quote_html($self->text($space, $id, $revision));
  my $list;
  my $code;
  for (split /\n/, $text) {
    if (/^```/) {
      if ($code) {
	say "</pre>";
	$code = 0;
      } else {
	say "</ul>" if $list;
	say "<pre>";
	$list = 0;
	$code = 1;
      }
    } elsif (/^\* /) {
      say "<ul>" unless $list;
      say "<li>$_";
      $list = 1;
    } elsif (my ($url, $text) = /^=&gt;\s*(\S+)\s+(.*)/) { # quoted HTML!
      say "<ul>" unless $list;
      $text ||= $url;
      say "<li><a href=\"$url\">$text</a>";
      $list = 1;
    } elsif (/^(#{1,6})\s*(.*)/) {
      say "</ul>" if $list;
      $list = 0;
      my $level = length($1);
      say "<h$level>$2</h$level>";
    } elsif (/^&gt;\s*(.*)/) { # quoted HTML!
      say "</ul>" if $list;
      $list = 0;
      say "<blockquote>$1</blockquote>";
    } else {
      say "</ul>" if $list;
      $list = 0;
      say "<p>$_";
    }
  }
}

sub day {
  my $self = shift;
  my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(shift);
  return sprintf('%4d-%02d-%02d', $year + 1900, $mon + 1, $mday);
}

sub time_of_day {
  my $self = shift;
  my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(shift);
  return sprintf('%02d:%02d UTC', $hour, $min);
}

sub modified {
  my $self = shift;
  my $ts = (stat(shift))[9];
  return $ts;
}

sub serve_history {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  $self->success();
  $self->log(3, "Serve history for $id");
  say "# Page history for $id";
  $self->print_link($space, "$id (current)", "page/$id");
  my $dir = $self->{server}->{wiki_dir};
  $dir .= "/$space" if $space;
  my @revisions = sort { $b cmp $a } map { s/\.gmi$//; $_ } read_dir("$dir/keep/$id");
  my $last_day = '';
  my $last_time = '';
  for my $revision (@revisions) {
    my $ts = $self->modified("$dir/keep/$id/$revision.gmi");
    my $day = $self->day($ts);
    if ($day ne $last_day) {
      say "## $day";
      $last_day = $day;
      $last_time = '';
    }
    my $time = $self->time_of_day($ts);
    say $time if $time ne $last_time;
    $last_time = $time;
    $self->print_link($space, "$id ($revision)", "page/$id/$revision");
    $self->print_link($space, "Diff between revision $revision and the current one", "diff/$id/$revision");
  }
}

sub footer {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $page = shift;
  my $revision = shift||"";
  my @links;
  push(@links, $self->gemini_link($space, "History", "history/$id"));
  push(@links, $self->gemini_link($space, "Raw text", "raw/$id/$revision"));
  push(@links, $self->gemini_link($space, "HTML", "html/$id/$revision"));
  return join("\n", "\n\nMore:", @links, ""); # includes a trailing newline
}

sub serve_gemini {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serve Gemini page $id");
  $self->success();
  print $self->text($space, $id, $revision);
  print $self->footer($space, $id, $revision);
}

sub text {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  my $dir = $self->{server}->{wiki_dir};
  $dir .= "/$space" if $space;
  return read_text "$dir/keep/$id/$revision.gmi" if $revision and -f "$dir/keep/$id/$revision.gmi";
  return read_text "$dir/page/$id.gmi" if -f "$dir/page/$id.gmi";
  return "This this revision is no longer available." if $revision;
  return "This page does not yet exist.";
}

sub serve_file {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serve file $id");
  my $dir = $self->{server}->{wiki_dir};
  $dir .= "/$space" if $space;
  my $file = "$dir/file/$id";
  my $meta = "$dir/meta/$id";
  if (not -f $file) {
    say "40 File not found\r";
    return;
  } elsif (not -f $meta) {
    say "40 Metadata not found\r";
    return;
  }
  my %meta = (map { split(/: /, $_, 2) } read_lines($meta));
  if (not $meta{'content-type'}) {
    say "59 Metadata corrupt\r";
    return;
  }
  $self->success($meta{'content-type'});
  print read_binary($file);
}

sub newest_first {
  my $self = shift;
  my ($date_a, $article_a) = $a =~ /^(\d\d\d\d-\d\d(?:-\d\d)? ?)?(.*)/;
  my ($date_b, $article_b) = $b =~ /^(\d\d\d\d-\d\d(?:-\d\d)? ?)?(.*)/;
  return (($date_b and $date_a and $date_b cmp $date_a)
	  || ($article_a cmp $article_b)
	  # this last one should be unnecessary
	  || ($a cmp $b));
}

sub bogus_hash {
  my $self = shift;
  my $str = shift;
  my $num = unpack("L",B::hash($str)); # 32-bit integer
  my $code = sprintf("%o", $num); # octal is 0-7
  return substr($code, 0, 4); # four numbers
}

sub write_file {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $data = shift;
  my $type = shift;
  $self->log(3, "Writing file $id");
  my $dir = $self->{server}->{wiki_dir};
  mkdir $dir unless -d $dir;
  $dir .= "/$space" if $space;
  mkdir $dir if $space and not -d $dir;
  my $file = "$dir/file/$id";
  my $meta = "$dir/meta/$id";
  if (-e $file) {
    my $old = read_binary($file);
    if ($old eq $data) {
      $self->log(3, "$id is unchanged");
      say "30 " . $self->link($space, "page/$id") . "\r";
      return;
    }
  }
  my $log = "$dir/changes.log";
  if (not open(my $fh, ">>:encoding(UTF-8)", $log)) {
    $self->log(1, "Cannot write log $log");
    say "59 Unable to write log: $!\r";
    return;
  } else {
    my $peeraddr = $self->{server}->{'peeraddr'};
    say $fh join("\x1f", scalar(time), "$id", 0, $self->bogus_hash($peeraddr));
    close($fh);
  }
  mkdir "$dir/file" unless -d "$dir/file";
  eval { write_binary($file, $data) };
  if ($@) {
    say "59 Unable to save $id: $@\r";
    return;
  }
  mkdir "$dir/meta" unless -d "$dir/meta";
  eval { write_text($meta, "content-type: $type\n") };
  if ($@) {
    say "59 Unable to save metadata for $id: $@\r";
    return;
  }
  $self->log(3, "Wrote $id");
  say "30 " . $self->link($space, "file/$id") . "\r";
}

sub write {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $text = shift;
  $self->log(3, "Writing page $id");
  my $dir = $self->{server}->{wiki_dir};
  mkdir $dir unless -d $dir;
  $dir .= "/$space" if $space;
  mkdir $dir if $space and not -d $dir;
  my $file = "$dir/page/$id.gmi";
  my $revision = 0;
  if (-e $file) {
    my $old = read_text($file);
    if ($old eq $text) {
      $self->log(3, "$id is unchanged");
      say "30 " . $self->link($space, "page/$id") . "\r";
      return;
    }
    mkdir "$dir/keep" unless -d "$dir/keep";
    if (-d "$dir/keep/$id") {
      foreach (read_dir("$dir/keep/$id")) {
	$revision = $1 if m/^(\d+)\.gmi$/ and $1 > $revision;
      }
      $revision++;
    } else {
      mkdir "$dir/keep/$id";
      $revision = 1;
    }
    rename $file, "$dir/keep/$id/$revision.gmi";
  } else {
    my $index = "$dir/index";
    if (not open(my $fh, ">>:encoding(UTF-8)", $index)) {
      $self->log(1, "Cannot write index $index");
      say "59 Unable to write index: $!\r";
      return;
    } else {
      say $fh "$id";
      close($fh);
    }
  }
  my $log = "$dir/changes.log";
  if (not open(my $fh, ">>:encoding(UTF-8)", $log)) {
    $self->log(1, "Cannot write log $log");
    say "59 Unable to write log: $!\r";
    return;
  } else {
    my $peeraddr = $self->{server}->{'peeraddr'};
    say $fh join("\x1f", scalar(time), "$id", $revision + 1, $self->bogus_hash($peeraddr));
    close($fh);
    $revision = 1;
  }
  mkdir "$dir/page" unless -d "$dir/page";
  eval { write_text($file, $text) };
  if ($@) {
    $self->log(1, "Unable to save $id: $@");
    say "59 Unable to save $id: $@\r";
  } else {
    $self->log(3, "Wrote $id");
    say "30 " . $self->link($space, "page/$id") . "\r";
  }
}

sub write_page {
  my $self = shift;
  my $space = shift;
  my $id = shift;
  my $params = shift;
  if (not $id) {
    $self->log(4, "The URL lacks a page name");
    say "59 The URL lacks a page name\r";
    return;
  }
  if (my $error = $self->valid($id)) {
    $self->log(4, "$id is not a valid page name: $error");
    say "59 $id is not a valid page name: $error\r";
    return;
  }
  my $token = $params->{token};
  if (not $token and @{$self->{server}->{wiki_token}}) {
    $self->log(4, "Uploads require a token");
    say "59 Uploads require a token\r";
    return;
  } elsif (not grep(/^$token$/, @{$self->{server}->{wiki_token}})) {
    $self->log(4, "Your token is the wrong token");
    say "59 Your token is the wrong token\r";
    return;
  }
  my $type = $params->{mime};
  my ($main_type) = split(/\//, $type, 1);
  my @types = @{$self->{server}->{wiki_mime_type}};
  if (not $type) {
    $self->log(4, "Uploads require a MIME type");
    say "59 Uploads require a MIME type\r";
    return;
  } elsif ($type ne "text/plain" and not grep(/^$type$/, @types) and not grep(/^$main_type$/, @types)) {
    $self->log(4, "This wiki does not allow $type");
    say "59 This wiki does not allow $type\r";
    return;
  }
  my $length = $params->{size};
  if ($length > $self->{server}->{wiki_page_size_limit}) {
    $self->log(4, "This wiki does not allow more than $self->{server}->{wiki_page_size_limit} bytes per page");
    say "59 This wiki does not allow more than $self->{server}->{wiki_page_size_limit} bytes per page\r";
    return;
  } elsif ($length !~ /^\d+$/) {
    $self->log(4, "You need to send along the number of bytes, not $length");
    say "59 You need to send along the number of bytes, not $length\r";
    return;
  }
  local $/ = undef;
  my $data;
  my $actual = read STDIN, $data, $length;
  if ($actual != $length) {
    $self->log(4, "Got $actual bytes instead of $length");
    say "59 Got $actual bytes instead of $length\r";
    return;
  }
  if ($type ne "text/plain") {
    $self->log(3, "Writing $type to $id, $actual bytes");
    $self->write_file($space, $id, $data, $type);
    return;
  } elsif (utf8::decode($data)) {
    $self->log(3, "Writing $type to $id, $actual bytes");
    $self->write($space, $id, $data);
    return;
  } else {
    $self->log(4, "The text is invalid UTF-8");
    say "59 The text is invalid UTF-8\r";
    return;
  }
}

sub allow_deny_hook {
  my $self = shift;
  my $client = shift;
  # gemini config file with extra code, run it for every request
  my $config = $self->{server}->{wiki_dir} . "/config";
  $self->log(3, "Running $config");
  do $config if -r $config;
  # consider adding rate limiting?
  return 1;
}

sub run_extensions {
  my $self = shift;
  my $url = shift;
  foreach my $sub (@extensions) {
    return 1 if $sub->($self, $url);
  }
  return;
}

sub valid {
  my $self = shift;
  my $id = shift;
  return 'Page names must not control characters' if $id =~ /[[:cntrl:]]/;
  return 0;
}

my %headers;

sub headers {
  my $self = shift;
  return \%headers if %headers;
  my %result;
  my ($key, $value);
  while (<STDIN>) {
    if (/^(\S+?): (.*?)\r$/) {
      ($key, $value) = (lc($1), $2);
      $result{$key} = $value;
    } elsif (/^\s+(.*)\r$/) {
      $result{$key} .= " $2";
    } else {
      last;
    }
  }
  $result{host} .= ":" . $self->port() unless $result{host} =~ /:\d+$/;
  $self->log(4, "HTTP headers: " . join(", ", map { "$_ => '$result{$_}'" } keys %result));
  return \%result;
}

sub process_request {
  my $self = shift;
  eval {
    local $SIG{'ALRM'} = sub {
      $self->log(1, "Timeout!");
      die "Timed Out!\n";
    };
    alarm(10); # timeout
    my $host = $self->host();
    my $port = $self->port();
    my $spaces = join("|", map {quotemeta} @{$self->{server}->{wiki_space}});
    $self->log(4, "Serving $host:$port");
    my $url = <STDIN>; # no loop
    $url =~ s/\s+$//g; # no trailing whitespace
    %headers = ();     # first call to $self->headers() sets them again
    # $url =~ s!^([^/:]+://[^/:]+)(/.*|)$!$1:$port$2!; # add port
    # $url .= '/' if $url =~ m!^[^/]+://[^/]+$!; # add missing trailing slash
    my($scheme, $authority, $path, $query, $fragment) =
	$url =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;
    $self->log(3, "Looking at $url");
    my ($space, $id, $n);
    if ($self->run_extensions($url)) {
      # config file goes first
    } elsif ($url =~ m!^titan://$host(?::$port)?!) {
      if ($path !~ m!^(?:/($spaces))?(?:/raw)?/([^/;=&]+(?:;\w+=[^;=&]+)+)!) {
	$self->log(4, "The path $path is malformed");
	say "59 The path $path is malformed\r";
      } else {
	$space = $1;
	my ($id, @params) = split(/[;=&]/, $2);
	$self->write_page((map {decode_utf8(uri_unescape($_))} $space, $id),
			  {map {decode_utf8(uri_unescape($_))} @params});
      }
    } elsif (($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/?$!) {
      $self->serve_main_menu(decode_utf8(uri_unescape($space)));
    } elsif (($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/more$!) {
      $self->serve_blog(decode_utf8(uri_unescape($space)));
    } elsif (($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/index$!) {
      $self->serve_index(decode_utf8(uri_unescape($space)));
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/source$!) {
      $self->success('text/plain; charset=UTF-8');
      seek DATA, 0, 0;
      local $/ = undef; # slurp
      print <DATA>;
    } elsif ($url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/match$!) {
      say "10 Find page by name (Perl regexp)\r";
    } elsif ($query and ($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/match\?!) {
      $self->serve_match(map {decode_utf8(uri_unescape($_))} $space, $query);
    } elsif ($url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/search$!) {
      say "10 Find page by content (Perl regexp)\r";
    } elsif ($query and ($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/search\?!) {
      $self->serve_search(map {decode_utf8(uri_unescape($_))} $space, $query); # search terms include spaces
    } elsif ($url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/new$!) {
      say "10 New page\r";
    } elsif ($query and ($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/new\?!) {
      # no URI escaping required
      say "30 gemini://$host:$port/$space/raw/$query\r" if $space;
      say "30 gemini://$host:$port/raw/$query\r";
    } elsif (($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/changes$!) {
      $self->serve_changes(decode_utf8(uri_unescape($space)));
    } elsif (($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/rss$!) {
      $self->serve_rss(decode_utf8(uri_unescape($space)));
    } elsif (($space) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/do/atom$!) {
      $self->serve_atom(decode_utf8(uri_unescape($space)));
    } elsif (($space, $id) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?([^/]*\.txt)$!) {
      $self->serve_raw(map {decode_utf8(uri_unescape($_))} $space, $id);
    } elsif (($space, $id) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/history/([^/]*)$!) {
      $self->serve_history(map {decode_utf8(uri_unescape($_))} $space, $id);
    } elsif (($space, $id, $n) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/diff/([^/]*)(?:/(\d+))?$!) {
      $self->serve_diff(map {decode_utf8(uri_unescape($_))} $space, $id, $n);
    } elsif (($space, $id, $n) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/raw/([^/]*)(?:/(\d+))?$!) {
      $self->serve_raw(map {decode_utf8(uri_unescape($_))} $space, $id, $n);
    } elsif (($space, $id, $n) = $url =~ m!^gemini://$host(?::$port)?(?:/($spaces))?/html/([^/]*)(?:/(\d+))?$!) {
      $self->serve_html(map {decode_utf8(uri_unescape($_))} $space, $id, $n);
    } elsif (($space, $id, $n) = $url =~ m!gemini://$host(?::$port)?(?:/($spaces))?/page/([^/]+)(?:/(\d+))?$!) {
      $self->serve_gemini(map {decode_utf8(uri_unescape($_))} $space, $id, $n);
    } elsif (($space, $id) = $url =~ m!gemini://$host(?::$port)?(?:/($spaces))?/file/([^/]+)?$!) {
      $self->serve_file(map {decode_utf8(uri_unescape($_))} $space, $id);
    } elsif (($space) = $url =~ m!^GET (?:/($spaces))?/ HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_main_menu_via_http(decode_utf8(uri_unescape($space)));
    } elsif (($space, $id, $n) = $url =~ m!^GET (?:/($spaces))?/html/([^/]*)(?:/(\d+))? HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_html_via_http(map {decode_utf8(uri_unescape($_))} $space, $id, $n);
    } elsif (($space, $id, $n) = $url =~ m!^GET (?:/($spaces))?/do/index HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_index_via_http(decode_utf8(uri_unescape($space)));
    } elsif (($space, $id, $n) = $url =~ m!^GET (?:/($spaces))?/do/rss HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_rss_via_http(decode_utf8(uri_unescape($space)));
    } elsif (($space, $id, $n) = $url =~ m!^GET (?:/($spaces))?/do/atom HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_atom_via_http(decode_utf8(uri_unescape($space)));
    } elsif ($url =~ m!^GET (?:/($spaces))?/do/source HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      say "HTTP/1.1 200 OK\r";
      say "Content-Type: text/plain; charset=UTF-8\r";
      say "\r";
      seek DATA, 0, 0;
      local $/ = undef; # slurp
      print <DATA>;
    } else {
      $self->log(3, "Unknown $url");
      say "40 Don't know how to handle $url\r";
    }
    $self->log(4, "Done");
  };
}

__DATA__
