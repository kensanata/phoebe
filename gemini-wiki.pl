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

It does two things:

=over

=item It's a program that you run on a computer and other people connect to it
      using their L<client|https://gemini.circumlunar.space/clients.html> in
      order to read the pages on it.

=item It's a wiki, which means that people can edit the pages without needing an
      account. All they need is a client that speaks both
      L<Gemini|https://gemini.circumlunar.space/> and Titan, and the password.
      The default password is "hello". 😃

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
Gemini sites, if servers allow this. Gemini Wiki, you can edit the "raw" pages.
That is, at the bottom of a page you'll see a link to the "raw" page. If you
follow it, you'll see the page content as plain text. You can submit a changed
version of this text to the same URL using Titan. There is more information for
developers available L<on Community Wiki|https://communitywiki.org/wiki/Titan>.

=head2 Dependencies

Perl libraries you need to install if you want to run Gemini wiki:

=over

=item L<Algorithm::Diff>

=item L<File::ReadBackwards>

=item L<File::Slurper>

=item L<Modern::Perl>

=item L<Net::Server>

=item L<URI::Escape>

=back

We are also going to be using C<curl> and C<openssl> in these installation
instructions.

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
repository and that's it. These instructions assume that you're going to create
a new user in order to be safe.

    sudo adduser --disabled-login --disabled-password gemini
    sudo su gemini
    cd

Now you're in your home directory, C</home/gemini>. We're going to install
things right here.

    curl --output gemini-wiki.pl \
      https://alexschroeder.ch/cgit/gemini-wiki/plain/gemini-wiki.pl?h=main

Since Gemini traffic is encrypted, we need to generate a certificate and a key.
These are both stored in PEM files. To create these files, use the following:

    openssl req -new -x509 -nodes -out cert.pem -keyout key.pem

You should have three files, now: C<gemini-wiki.pl>, C<cert.pem>, and
C<key.pem>. That's enough to get started! Start the server:

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

=head2 Wiki Directory

You home directory should now also contain a wiki directory called C<wiki>. In
it, you'll find a few more files:

=over

=item C<page> is the directory with all the page files in it

=item C<keep> is the directory with all the old revisions of pages in it – if
      you've only made one change, then it won't exist, yet; and if you don't
      care about the older revisions, you can delete them

=item C<index> is a file containing all the files in your C<page> directory for
      quick access; if you create new files in the C<page> directory, you should
      delete the C<index> file – dont' worry, it will get regenerated when
      needed

=item C<changes.log> is a file listing all the pages made to the wiki; if you
      make changes to the files in the C<page> directory, they aren't going to
      be listed in this file and thus people will be confused by the changes you
      made – your call (but in all fairness, if you're collaborating with others
      you probably shouldn't do this)

=item C<config> probably doesn't exist, yet; it is an optional file containing
      Perl code where you can mess with the code (see I<Configuration> below)

=back

The server uses "access tokens" to check whether people are allowed to edit
files. You could also call them passwords, if you want. They aren't associated
with a username. By default, the only password is "hello". That's why the Titan
command above contained "token=hello". 😊

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
      the default is "hello"; you use this option multiple times and give
      different users different passwords, if you want

=item C<--wiki_main_page> is the page containing your header for the main page;
      that's were you would put your ASCII art header, your welcome message, and
      so on

=item C<--wiki_pages> is an extra page to show in the main menu; you can use
      this option multiple times

=item C<--host> is the hostname to serve; the default is C<localhost> – you
      probably want to pick the name of your machine, if it is reachable from
      the Internet

=item C<--port> is the port to use; the default is 1965

=item C<--wiki_dir> is the wiki data directory to use; the default is either the
      value of the C<GEMINI_WIKI_DATA_DIR> environment variable, or the "./wiki"
      subdirectory

=item C<--cert_file> is the certificate PEM file to use; the default is
      "cert.pem"

=item C<--key_file> is the private key PEM file to use; the default is
      "key.pem"

=item C<--log_level> is the log level to use, 0 is quiet, 1 is errors, 2 is
      warnings, 3 is info, and 4 is debug; the default is 2

=back

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

=head2 Limited, read-only HTTP support

You can actually look at your wiki pages using a browser! But beware: these days
browser will refuse to connect to sites that have self-signed certificates.
You'll have to click buttons and make exceptions and all of that, or get your
certificate from Let's Encrypt or the like. Anyway, it works in theory:
C<https://localhost:1965/> should work, now!

=head2 Configuration

This section describes some hooks you can use to customize your wiki using the
C<config> file.

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
use File::Slurper qw(read_text read_lines read_dir write_text);
use List::Util qw(first min);
use MIME::Base64;
use Modern::Perl '2018';
use Pod::Text;
use URI::Escape;
use Algorithm::Diff;
use File::ReadBackwards;
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
    print "20 $type; lang=$lang\r\n";
  } else {
    print "20 $type\r\n";
  }
}

sub host {
  my $self = shift;
  return $self->{server}->{host}->[0]
      || $self->{server}->{sockaddr};
}

sub port {
  my $self = shift;
  return $self->{server}->{port}->[0]
      || $self->{server}->{sockport};
}

sub link {
  my $self = shift;
  my $id = shift;
  my $host = $self->host();
  my $port = $self->port();
  # don't encode the slash
  return "gemini://$host:$port/"
      . join("/", map { uri_escape_utf8($_) } split (/\//, $id));
}

sub link_html {
  my $self = shift;
  my $id = shift;
  my $host = $self->host();
  my $port = $self->port();
  # don't encode the slash
  return "<a href=\"https://$host:$port/html/"
	. join("/", map { uri_escape_utf8($_) } split (/\//, $id))
	. "\">$id</a>";
}

sub gemini_link {
  my $self = shift;
  my $title = shift;
  my $id = shift;
  if (not $id) {
    $id = "page/$title";
  }
  return "=> $id $title\r" if $id =~ /^$self->{server}->{full_url_regexp}$/;
  my $url = $self->link($id);
  return "=> $url $title\r";
}

sub print_link {
  my $self = shift;
  my $title = shift;
  my $id = shift;
  say $self->gemini_link($title, $id);
}

sub pages {
  my $self = shift;
  my $re = shift;
  my $dir = $self->{server}->{wiki_dir};
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
  return sort { $b cmp $a } $self->pages('^\d\d\d\d-\d\d-\d\d');
}

sub blog {
  my $self = shift;
  my @blog = $self->blog_pages();
  return unless @blog;
  say "Blog:";
  # we should check for pages marked for deletion!
  for my $id (@blog[0..min($#blog, 9)]) {
    $self->print_link($id);
  }
  $self->print_link("More...", "do/more") if @blog > 10;
  say "";
}

sub blog_html {
  my $self = shift;
  my @blog = $self->blog_pages();
  return unless @blog;
  say "<p>Blog:";
  say "<ul>";
  # we should check for pages marked for deletion!
  for my $id (@blog[0..min($#blog, 9)]) {
    say "<li>" . $self->link_html($id);
  }
  say "</ul>";
}

sub serve_main_menu {
  my $self = shift;
  $self->log(3, "Serving main menu");
  $self->success();
  my $page = $self->{server}->{wiki_main_page};
  if ($page) {
    say $self->text($page);
  } else {
    say "# Welcome to the Gemini Wiki!";
    say "";
  }
  $self->blog();
  for my $id (@{$self->{server}->{wiki_pages}}) {
    $self->print_link($id);
  }
  for my $line (@main_menu) {
    say $line;
  }
  $self->print_link("Recent Changes", "do/changes");
  $self->print_link("Search matching page names", "do/match");
  $self->print_link("Search matching page content", "do/search");
  $self->print_link("New page", "do/new");
  say "";
  $self->print_link("Index of all pages", "do/index");
  # a requirement of the GNU Affero General Public License
  $self->print_link("Source code", "do/source");
  say "";
}

sub serve_main_menu_via_http {
  my $self = shift;
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
    say "<title>$page</title>";
  } else {
    say "<title>Gemini Wiki</title>";
  }
  say "</head>";
  say "<body>";
  if ($page) {
    $self->print_html($page);
  } else {
    say "<h1>Welcome to the Gemini Wiki!</h1>";
  }
  $self->blog_html();
  say "<p>Important links:";
  say "<ul>";
  my @pages = @{$self->{server}->{wiki_pages}};
  for my $id (@pages) {
    say "<li>" . $self->link_html($id);
  }
  say "<li><a href=\"/do/index\">Index of all pages</a>";
  # a requirement of the GNU Affero General Public License
  say "<li><a href=\"/do/source\">Source</a>";
  say "</ul>";
  say "</body>";
  say "</html>";
}

sub serve_blog {
  my $self = shift;
  $self->success();
  $self->log(3, "Serving blog");
  say "# Blog";
  my @blog = $self->blog();
  say "The are no blog pages." unless @blog;
  for my $id (@blog) {
    $self->print_link($id);
  }
}

sub serve_index {
  my $self = shift;
  $self->success();
  $self->log(3, "Serving index of all pages");
  say "# All Pages";
  my @pages = $self->pages();
  say "The are no pages." unless @pages;
  for my $id (sort { $self->newest_first($a, $b) } @pages) {
    $self->print_link($id);
  }
}

sub serve_index_via_http {
  my $self = shift;
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
  my @pages = $self->pages();
  if (@pages) {
    say "<ul>";
    for my $id (sort { $self->newest_first($a, $b) } @pages) {
      say "<li>" . $self->link_html($id);
    }
    say "</ul>";
  } else {
    say "<p>The are no pages."
  }
}

sub serve_match {
  my $self = shift;
  my $match = shift;
  if (not $match) {
    print("59 Search term is missing");
    return;
  }
  $self->success();
  $self->log(3, "Serving pages matching $match");
  say "# Search page titles for $match";
  say "Use a Perl regular expression to match page titles.";
  my @pages = $self->pages($match);
  say "No matching page names found." unless @pages;
  for my $id (sort { $self->newest_first($a, $b) } @pages) {
    $self->print_link($id);
  }
}

sub serve_search {
  my $self = shift;
  my $str = shift;
  if (not $str) {
    print("59 Search term is missing");
    return;
  }
  $self->success();
  $self->log(3, "Serving search result for $str");
  say "# Search page content for $str";
  say "Use a Perl regular expression to match page titles and page content.";
  if (not $self->search($str, sub { $self->highlight(@_) })) {
    say "Search term not found."
  }
}

sub search {
  my $self = shift;
  my $str = shift;
  my $func = shift;
  my @pages = sort { $self->newest_first($a, $b) } $self->pages();
  return unless @pages;
  my $found = 0;
  for my $id (@pages) {
    my $text = $self->text($id);
    if ($id =~ /$str/ or $text =~ /$str/) {
      $func->($id, $text, $str);
      $found++;
    }
  }
  return $found;
}

sub highlight {
  my $self = shift;
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
  $self->print_link($id);
}

sub serve_changes {
  my $self = shift;
  $self->log(3, "Serving recent changes");
  $self->success();
  say "# Recent Changes";
  $self->print_link("Show RSS", "do/rss");
  my $dir = $self->{server}->{wiki_dir};
  my $log = "$dir/changes.log";
  if (not -e $log) {
    say "No changes.";
    return;
  } elsif (my $fh = File::ReadBackwards->new($log)) {
    my $last_day = '';
    my $last_time = '';
    my %seen;
    for (1 .. 100) {
      last unless $_ = $fh->readline;
      my ($ts, $id, $revision, $addr) = split(/\x1f/);
      my $day = $self->day($ts);
      if ($day ne $last_day) {
	say "## $day";
	$last_day = $day;
	$last_time = '';
      }
      my $time = $self->time_of_day($ts);
      say $time if $time ne $last_time;
      if ($seen{$id}) {
	$self->print_link("$id ($revision)", "page/$id/$revision");
      } else {
	$seen{$id} = 1;
	$self->print_link("$id (current)", "page/$id");
      }
    }
  } else {
    say "Error: $!";
  }
}

sub serve_rss {
  my $self = shift;
  $self->log(3, "Serving Gemini RSS");
  say "59 Not implemented, yet."
  # $self->success("application/rss+xml");
  # my $rss = GetRcRss();
  # $rss =~ s!$ScriptName\?action=rss!${gemini}1do/rss!g;
  # $rss =~ s!$ScriptName\?action=history;id=([^[:space:]<]*)!${gemini}1$1/history!g;
  # $rss =~ s!$ScriptName/([^[:space:]<]*)!${gemini}0$1!g;
  # $rss =~ s!<wiki:diff>.*</wiki:diff>\n!!g;
  # print $rss;
}

sub serve_raw {
  my $self = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serving raw $id");
  $self->success('text/plain; charset=UTF-8');
  print $self->text($id, $revision);
}

sub serve_diff {
  my $self = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serving the diff of $id");
  $self->success();
  say "# Differences for $id";
  say "Showing the differences between revision $revision and the current revision of $id.";
  # Order is important because $new is a reference to %Page!
  my $new = $self->text($id);
  my $old = $self->text($id, $revision);
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
  my $id = shift;
  my $revision = shift;
  $self->success('text/html');
  $self->log(3, "Serving $id as HTML");
  $self->html_page($id, $revision);
}

sub serve_html_via_http {
  my $self = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serving $id as HTML via HTTP");
  say "HTTP/1.1 200 OK\r";
  say "Content-Type: text/html\r";
  say "\r";
  $self->html_page($id, $revision);
}

sub html_page {
  my $self = shift;
  my $id = shift;
  my $revision = shift;
  say "<!DOCTYPE html>";
  say "<html>";
  say "<head>";
  say "<meta charset=\"utf-8\">";
  say "<title>$id</title>";
  say "</head>";
  say "<body>";
  $self->print_html($id, $revision);
  say "</body>";
  say "</html>";
}

sub print_html {
  my $self = shift;
  my $id = shift;
  my $revision = shift;
  my $text = $self->text($id, $revision);
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
    } elsif (my ($url, $text) = /^=>\s*(\S+)\s*(\S*)/) {
      say "<ul>" unless $list;
      $text ||= $url;
      say "<li><a href=\"$url\">$text</a>";
      $list = 1;
    } elsif (/^(#{1,6})\s*(.*)/) {
      say "</ul>" if $list;
      $list = 0;
      my $level = length($1);
      say "<h$level>$2</h$level>";
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
  my $id = shift;
  $self->success();
  $self->log(3, "Serve history for $id");
  say "# Page history for $id";
  $self->print_link("$id (current)", "page/$id");
  my $dir = $self->{server}->{wiki_dir};
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
    $self->print_link("$id ($revision)", "page/$id/$revision");
    $self->print_link("Diff between revision $revision and the current one", "diff/$id/$revision");
  }
}

sub footer {
  my $self = shift;
  my $id = shift;
  my $page = shift;
  my $revision = shift||"";
  my @links;
  push(@links, $self->gemini_link("History", "history/$id"));
  push(@links, $self->gemini_link("Raw text", "raw/$id/$revision"));
  push(@links, $self->gemini_link("HTML", "html/$id/$revision"));
  return join("\n", "\n\nMore:", @links, "") if @links;
  return "";
}

sub serve_gemini {
  my $self = shift;
  my $id = shift;
  my $revision = shift;
  $self->log(3, "Serve Gemini page $id");
  $self->success();
  print $self->text($id, $revision);
  print $self->footer($id, $revision);
}

sub text {
  my $self = shift;
  my $id = shift;
  my $revision = shift;
  my $dir = $self->{server}->{wiki_dir};
  return read_text "$dir/keep/$id/$revision.gmi" if $revision and -f "$dir/keep/$id/$revision.gmi";
  return read_text "$dir/page/$id.gmi" if -f "$dir/page/$id.gmi";
  return "This this revision is no longer available." if $revision;
  return "This page does not yet exist.";
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

sub write {
  my $self = shift;
  my $id = shift;
  my $token = shift;
  my $text = shift;
  $self->log(3, "Writing $id");
  my $dir = $self->{server}->{wiki_dir};
  mkdir $dir unless -d $dir;
  my $file = "$dir/page/$id.gmi";
  my $revision = 0;
  if (-e $file) {
    my $old = read_text($file);
    if ($old eq $text) {
      $self->log(3, "$id is unchanged");
      print "30 " . $self->link("page/$id") . "\r\n";
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
      print "59 Unable to write index: $!\r\n";
      return;
    } else {
      say $fh "$id";
      close($fh);
    }
  }
  my $log = "$dir/changes.log";
  if (not open(my $fh, ">>:encoding(UTF-8)", $log)) {
    $self->log(1, "Cannot write log $log");
    print "59 Unable to write log: $!\r\n";
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
    print "59 Unable to save $id: $@\r\n";
  } else {
    $self->log(3, "Wrote $id");
    print "30 " . $self->link("page/$id") . "\r\n";
  }
}

sub write_page {
  my $self = shift;
  my $id = shift;
  my $params = shift;
  if (not $id) {
    print "59 The URL lacks a page name\r\n";
    return;
  }
  if (my $error = $self->valid($id)) {
    print "59 $id is not a valid page name: $error\r\n";
    return;
  }
  my $token = $params->{token};
  if (not $token and @{$self->{server}->{wiki_token}}) {
    print "59 Uploads require a token\r\n";
    return;
  } elsif (not grep(/^$token$/, @{$self->{server}->{wiki_token}})) {
    print "59 Your token is the wrong token\r\n";
    return;
  }
  my $type = $params->{mime};
  if (not $type) {
    print "59 Uploads require a MIME type\r\n";
    return;
  } elsif ($type ne "text/plain") {
    print "59 This wiki does not allow $type\r\n";
    return;
  }
  my $length = $params->{size};
  if ($length > $self->{server}->{wiki_page_size_limit}) {
    print "59 This wiki does not allow more than $self->{server}->{wiki_page_size_limit} bytes per page\r\n";
    return;
  } elsif ($length !~ /^\d+$/) {
    print "59 You need to send along the number of bytes, not $length\r\n";
    return;
  }
  local $/ = undef;
  my $data;
  my $actual = read STDIN, $data, $length;
  if ($actual != $length) {
    print "59 Got $actual bytes instead of $length\r\n";
    return;
  }
  if ($type ne "text/plain") {
    $self->log(3, "Writing $type to $id, $actual bytes");
    $self->write($id, $token, "#FILE $type\n" . encode_base64($data));
    return;
  } elsif (utf8::decode($data)) {
    $self->log(3, "Writing $type to $id, $actual bytes");
    $self->write($id, $token, $data);
    return;
  } else {
    print "59 The text is invalid UTF-8\r\n";
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

sub headers {
  my $self = shift;
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
    $self->log(4, "Serving $host:$port");
    my $url = <STDIN>; # no loop
    $url =~ s/\s+$//g; # no trailing whitespace
    # $url =~ s!^([^/:]+://[^/:]+)(/.*|)$!$1:$port$2!; # add port
    # $url .= '/' if $url =~ m!^[^/]+://[^/]+$!; # add missing trailing slash
    my($scheme, $authority, $path, $query, $fragment) =
	$url =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;
    $self->log(3, "Looking at $url");
    my ($id, $n, $answer);
    if ($self->run_extensions($url)) {
      # config file goes first
    } elsif ($url =~ m!^titan://$host(?::$port)?! and $path !~ /^\/raw\//) {
      $self->log(3, "Cannot write $url");
      print "59 This server only allows writing of raw pages\r\n";
    } elsif ($url =~ m!^titan://$host(?::$port)?!) {
      if ($path !~ m!^/raw/([^/;=&]+(?:;\w+=[^;=&]+)+)!) {
	print "59 The path $path is malformed.\r\n";
      } else {
	my ($id, %params) = split(/[;=&]/, $1);
	$self->write_page(decode_utf8(uri_unescape($id)), \%params);
      }
    } elsif ($url =~ m!^gemini://$host(?::$port)?\/?$!) {
      $self->serve_main_menu();
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/more$!) {
      $self->serve_blog();
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/index$!) {
      $self->serve_index();
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/source$!) {
      $self->success('text/plain; charset=UTF-8');
      seek DATA, 0, 0;
      local $/ = undef; # slurp
      print <DATA>;
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/match$!) {
      print "10 Find page by name (Perl regexp)\r\n";
    } elsif ($query and $url =~ m!^gemini://$host(?::$port)?/do/match\?!) {
      $self->serve_match(decode_utf8(uri_unescape($query)));
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/search$!) {
      print "10 Find page by content (Perl regexp)\r\n";
    } elsif ($query and $url =~ m!^gemini://$host(?::$port)?/do/search\?!) {
      $self->serve_search(decode_utf8(uri_unescape($query))); # search terms include spaces
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/new$!) {
      print "10 New page\r\n";
    } elsif ($query and $url =~ m!^gemini://$host(?::$port)?/do/new\?!) {
      print "30 gemini://$host:$port/raw/$query\r\n";
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/changes$!) {
      $self->serve_changes();
    } elsif ($url =~ m!^gemini://$host(?::$port)?/do/rss$!) {
      $self->serve_rss();
    } elsif ($url =~ m!^gemini://$host(?::$port)?([^/]*\.txt)$!) {
      $self->serve_raw(decode_utf8(uri_unescape($1)));
    } elsif ($url =~ m!^gemini://$host(?::$port)?/history/([^/]*)$!) {
      $self->serve_history(decode_utf8(uri_unescape($1)));
    } elsif ($url =~ m!^gemini://$host(?::$port)?/diff/([^/]*)(?:/(\d+))?$!) {
      $self->serve_diff(decode_utf8(uri_unescape($1)), $2);
    } elsif ($url =~ m!^gemini://$host(?::$port)?/raw/([^/]*)(?:/(\d+))?$!) {
      $self->serve_raw(decode_utf8(uri_unescape($1)), $2);
    } elsif ($url =~ m!^gemini://$host(?::$port)?/html/([^/]*)(?:/(\d+))?$!) {
      $self->serve_html(decode_utf8(uri_unescape($1)), $2);
    } elsif ($url =~ m!gemini://$host(?::$port)?/page/([^/]+)(?:/(\d+))?$!) {
      $self->serve_gemini(decode_utf8(uri_unescape($1)), $2);
    } elsif (($id, $n) = $url =~ m!^GET / HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_main_menu_via_http(decode_utf8(uri_unescape($id)), $n);
    } elsif (($id, $n) = $url =~ m!^GET /html/([^/]*)(?:/(\d+))? HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_html_via_http(decode_utf8(uri_unescape($id)), $n);
    } elsif (($id, $n) = $url =~ m!^GET /do/index HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      $self->serve_index_via_http();
    } elsif (($id, $n) = $url =~ m!^GET /do/source HTTP/1.[01]$!
	     and $self->headers()->{host} =~ m!^$host(?::$port)$!) {
      say "HTTP/1.1 200 OK\r";
      say "Content-Type: text/plain; charset=UTF-8\r";
      say "\r";
      seek DATA, 0, 0;
      local $/ = undef; # slurp
      print <DATA>;
    } else {
      $self->log(3, "Unknown $url");
      print "40 Don't know how to handle $url\r\n";
    }
    $self->log(4, "Done");
  };
  $self->log(1, $@) if $@;
}

__DATA__
