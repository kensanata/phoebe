# Gemini Wiki

This server serves a wiki as a Gemini site.

It does two and a half things:

- It's a program that you run on a computer and other people connect to it
      using their [client](https://gemini.circumlunar.space/clients.html) in
      order to read the pages on it.
- It's a wiki, which means that people can edit the pages without needing an
      account. All they need is a client that speaks both
      [Gemini](https://gemini.circumlunar.space/) and Titan, and the password.
      The default password is "hello". 😃
- People can also access it using a regular web browser. They'll get a very
      simple, read-only version of the site.

    To take a look for yourself, check out the Gemini Test Wiki via the
    [HTTP](https://alexschroeder.ch:1968/) or via
    [gemini](gemini://alexschroeder.ch:1968/).

**Table of Contents**

- [How do you edit a Gemini Wiki?](#how-do-you-edit-a-gemini-wiki)
- [What is Titan?](#what-is-titan)
- [Dependencies](#dependencies)
- [Quickstart](#quickstart)
- [Wiki Directory](#wiki-directory)
- [Options](#options)
- [Running the Gemini Wiki as a Daemon](#running-the-gemini-wiki-as-a-daemon)
- [Using systemd](#using-systemd)
- [Security](#security)
- [Privacy](#privacy)
- [Files](#files)
- [Main Page and Title](#main-page-and-title)
- [GUS and robots.txt](#gus-and-robots-txt)
- [Limited, read-only HTTP support](#limited-read-only-http-support)
- [Configuration](#configuration)
- [Wiki Spaces](#wiki-spaces)
- [Tokens per Wiki Space](#tokens-per-wiki-space)
- [Client Certificates](#client-certificates)
- [Virtual Hosting](#virtual-hosting)

## How do you edit a Gemini Wiki?

You need to use a Titan-enabled client.

Known clients:

- This repository comes with a Perl script called
      [titan](https://alexschroeder.ch/cgit/gemini-wiki/plain/titan) to upload
      files
- [Gemini Write](https://alexschroeder.ch/cgit/gemini-write/) is an
      extension for the Emacs Gopher and Gemini client
      [Elpher](https://thelambdalab.xyz/elpher/)
- [Gemini & Titan for Bash](https://alexschroeder.ch/cgit/gemini-titan/about/)
      are two shell functions that allow you to download and upload files

## What is Titan?

Titan is a companion protocol to Gemini: it allows clients to upload files to
Gemini sites, if servers allow this. On the Gemini Wiki, you can edit "raw"
pages. That is, at the bottom of a page you'll see a link to the "raw" page. If
you follow it, you'll see the page content as plain text. You can submit a
changed version of this text to the same URL using Titan. There is more
information for developers available
[on Community Wiki](https://communitywiki.org/wiki/Titan).

## Dependencies

Perl libraries you need to install if you want to run Gemini Wiki:

- [Algorithm::Diff](https://metacpan.org/pod/Algorithm%3A%3ADiff)
- [File::ReadBackwards](https://metacpan.org/pod/File%3A%3AReadBackwards)
- [File::Slurper](https://metacpan.org/pod/File%3A%3ASlurper)
- [Modern::Perl](https://metacpan.org/pod/Modern%3A%3APerl)
- [Net::Server](https://metacpan.org/pod/Net%3A%3AServer)
- [URI::Escape](https://metacpan.org/pod/URI%3A%3AEscape)

I'm going to be using `curl` and `openssl` in the ["Quickstart"](#quickstart) instructions,
so you'll need those tools as well. And finally, when people download their
data, the code calls `tar`.

On Debian:

    sudo apt install \
      libalgorithm-diff-xs-perl \
      libfile-readbackwards-perl \
      libfile-slurper-perl \
      libmodern-perl-perl \
      libnet-server-perl \
      liburi-escape-xs-perl \
      curl openssl tar

The `update-readme.pl` script I use to generate `README.md` also requires
[Pod::Markdown](https://metacpan.org/pod/Pod%3A%3AMarkdown) and [Text::Slugify](https://metacpan.org/pod/Text%3A%3ASlugify).

## Quickstart

Right now there aren't any releases. You just get the latest version from the
repository and that's it. I'm going to assume that you're going to create a new
user just to be safe.

    sudo adduser --disabled-login --disabled-password gemini
    sudo su gemini
    cd

Now you're in your home directory, `/home/gemini`. We're going to install
things right here. First, get the source code:

    curl --output gemini-wiki.pl \
      https://alexschroeder.ch/cgit/gemini-wiki/plain/gemini-wiki.pl?h=main

Since Gemini traffic is encrypted, we need to generate a certificate and a key.
These are both stored in PEM files. To create your own copies of these files
(and you should!), use "make cert" if you have a copy of the Makefile. If you
don't, use this:

    openssl req -new -x509 -newkey ec \
    -pkeyopt ec_paramgen_curve:prime256v1 \
    -days 1825 -nodes -out cert.pem -keyout key.pem

This creates a certificate and a private key, both of them unencrypted, using
eliptic curves of a particular kind, valid for five years.

You should have three files, now: `gemini-wiki.pl`, `cert.pem`, and
`key.pem`. That's enough to get started! Start the server:

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

Let me return to the topic of Titan-enabled clients for a moment. With those,
you can do simple things like this:

    echo "Hello! This is a test!" | titan localhost/test hello

Or this:

    titan localhost/test hello test.txt

That makes it a lot easier to upload new content! 😅

If you have a bunch of Gemtext files in a directory, you can upload them all in
one go:

    titan titan://localhost/ hello *.gmi

## Wiki Directory

You home directory should now also contain a wiki directory called `wiki`. In
it, you'll find a few more files:

- `page` is the directory with all the page files in it; each file has the
      `gmi` extension and should be written in Gemtext format
- `index` is a file containing all the files in your `page` directory for
      quick access; if you create new files in the `page` directory, you should
      delete the `index` file – it will get regenerated when needed; the format
      is one page name (without the `.gmi` extension) per line, with lines
      separated from each other by a single `\n`
- `keep` is the directory with all the old revisions of pages in it – if
      you've only made one change, then it won't exist, yet; and if you don't
      care about the older revisions, you can delete them; assuming you have a
      page called `Welcome` and edit it once, you have the current revision as
      `page/Welcome.gmi`, and the old revision in `keep/Welcome/1.gmi` (the
      page name turns into a subdirectory and each revision gets an apropriate
      number)
- `file` is the directory with all the uploaded files in it – if you
      haven't uploaded any files, then it won't exist, yet; you must explicitly
      allow MIME types for upload using the `--wiki_mime_type` option (see
      _Options_ below)
- `meta` is the directory with all the meta data for uploaded files in it –
      there should be a file here for every file in the `file` directory; if
      you create new files in the `file` directory, you should create a
      matching file here; if you have a file `file/alex.jpg` you want to create
      a file `meta/alex.jpg` containing the line `content-type: image/jpeg`
- `changes.log` is a file listing all the pages made to the wiki; if you
      make changes to the files in the `page` or `file` directory, they aren't
      going to be listed in this file and thus people will be confused by the
      changes you made – your call (but in all fairness, if you're collaborating
      with others you probably shouldn't do this); the format is one change per
      line, with lines separated from each other by a single `\n`, and each
      line consisting of time stamp, pagename or filename, revision number if a
      page or 0 if a file, and the numeric code of the user making the edit (see
      ["Privacy"](#privacy) below)
- `config` probably doesn't exist, yet; it is an optional file containing
      Perl code where you can mess with the code (see ["Configuration"](#configuration) below)

## Options

The Gemini Wiki has a bunch of options, and it uses [Net::Server](https://metacpan.org/pod/Net%3A%3AServer) in the
background, which has even more options. Let's try to focus on the options you
might want to use right away.

Here's an example:

    perl gemini-wiki.pl \
      --wiki_token=Elrond \
      --wiki_token=Thranduil \
      --wiki_page=Welcome \
      --wiki_page=About

And here's some documentation:

- `--wiki_token` is for the token that users editing pages have to provide;
      the default is "hello"; you can use this option multiple times and give
      different users different passwords, if you want
- `--wiki_page` is an extra page to show in the main menu; you can use
      this option multiple times
- `--wiki_main_page` is the page containing your header for the main page;
      that's were you would put your ASCII art header, your welcome message, and
      so on, see ["Main Page and Title"](#main-page-and-title) below
- `--wiki_mime_type` is a MIME type to allow for uploads; text/plain is
      always allowed and doesn't need to be listed; you can also just list the
      type without a subtype, eg. `image` will allow all sorts of images (make
      sure random people can't use your server to exchange images – set a
      password using `--wiki_token`)
- `--host` is the hostname to serve; the default is `localhost` – you
      probably want to pick the name of your machine, if it is reachable from
      the Internet
- `--port` is the port to use; the default is 1965
- `--wiki_dir` is the wiki data directory to use; the default is either the
      value of the `GEMINI_WIKI_DATA_DIR` environment variable, or the "./wiki"
      subdirectory
- `--wiki_space` adds an extra space that acts as its own wiki; a
      subdirectory with the same name gets created in your wiki data directory
      and thus you shouldn't name spaces like any of the files and directories
      already there (see ["Wiki Directory"](#wiki-directory))
- `--cert_file` is the certificate PEM file to use; the default is
      `cert.pem`
- `--key_file` is the private key PEM file to use; the default is
      `key.pem`
- `--log_level` is the log level to use, 0 is quiet, 1 is errors, 2 is
      warnings, 3 is info, and 4 is debug; the default is 2

## Running the Gemini Wiki as a Daemon

If you want to start the Gemini Wiki as a daemon, the following options come in
handy:

- `--setsid` makes sure the Gemini Wiki runs as a daemon in the background
- `--pid_file` is the file where the process id (pid) gets written once the
      server starts up; this is useful if you run the server in the background
      and you need to kill it
- `--log_file` is the file to write logs into; the default is to write log
      output to the standard error (stderr)
- `--user` and `--group` might come in handy if you start the Gemini Wiki
      using a different user

## Using systemd

In this case, we don't want to daemonize the process. Systemd is going to handle
that for us. There's more documentation [available
online](https://www.freedesktop.org/software/systemd/man/systemd.service.html).

Basically, this is the template for our service:

    [Unit]
    Description=Gemini Wiki
    After=network.target
    [Service]
    Type=simple
    WorkingDirectory=/home/gemini
    ExecStart=/home/gemini/gemini-wiki.pl
    Restart=always
    User=gemini
    Group=gemini
    [Install]
    WantedBy=multi-user.target

Save this as `gemini-wiki.service`, and then link it:

    sudo ln -s /home/gemini/gemini-wiki.service /etc/systemd/system/

Start it:

    sudo systemctl start gemini-wiki

Check the log output:

    sudo journalctl --unit gemini-wiki

## Security

The server uses "access tokens" to check whether people are allowed to edit
files. You could also call them "passwords", if you want. They aren't associated
with a username. You set them using the `--wiki_token` option. By default, the
only password is "hello". That's why the Titan command above contained
"token=hello". 😊

If you're going to check up on your wiki often, looking at Changes on a daily
basis, you could just tell people about the token on a page of your wiki.
Spammers would at least have to read the instructions and in my experience the
hardly ever do.

You could also create a separate password for every contributor and when they
leave the project, you just remove the token from the options and restart Gemini
Wiki. They will no longer be able to edit the site.

## Privacy

The server only actively logs changes to pages. It calculates a "code" for every
contribution: it is a four digit octal code. The idea is that you could colour
every digit using one of the eight standard terminal colours and thus get little
four-coloured flags.

This allows you to make a pretty good guess about edits made by the same person,
without telling you their IP numbers.

The code is computed as follows: the IP numbers is turned into a 32bit number
using a hash function, converted to octal, and the first four digits are the
code. Thus all possible IP numbers are mapped into 8⁴=4096 codes.

If you increase the log level, the server will produce more output, including
information about the connections happening, like `2020/06/29-15:35:59 CONNECT
SSL Peer: "[::1]:52730" Local: "[::1]:1965"` and the like (in this case `::1`
is my local address so that isn't too useful but it could also be your visitor's
IP numbers, in which case you will need to tell them about it using in order to
comply with the
[GDPR](https://en.wikipedia.org/wiki/General_Data_Protection_Regulation).

## Files

If you allow uploads of binary files, these are stored separately from the
regular pages; the wiki also doesn't keep old revisions of files around. That
also means that if somebody overwrites a file, the old revision is gone.

You definitely don't want random people uploading all sorts of images, videos
and binaries files to your server. Make sure you set up those [tokens](#security)
using `--wiki_token`!

## Main Page and Title

The main page will include ("transclude") a page of your choosing if you use the
`--wiki_main_page` option. This also sets the title of your wiki in various
places like the RSS and Atom feeds.

In order to be more flexible, the name of the main page does not get printed. If
you want it, you need to add it yourself using a header. This allows you to keep
the main page in a page called "Welcome" containing some ASCII art such that the
word "Welcome" does not show on the main page.

If you have pages with names that start with an ISO date like 2020-06-30, then
I'm assuming you want some sort of blog. In this case, up to ten of them will be
shown on your front page.

## GUS and robots.txt

There are search machines out there that will index your site. Ideally, these
wouldn't index the history pages and all that: they would only get the list of
all pages, and all the pages. I'm not even sure that we need them to look at all
the files. The [robots exclusion
standard](https://en.wikipedia.org/wiki/Robots_exclusion_standard) lets you
control what the bots ought to index and what they ought to skip. It doesn't
always work.

Here's my suggestion:

    User-agent: *
    Disallow: raw/*
    Disallow: html/*
    Disallow: diff/*
    Disallow: history/*
    Disallow: do/changes
    Disallow: do/rss
    Disallow: do/atom
    Disallow: do/new
    Disallow: do/more
    Disallow: do/match
    Disallow: do/search
    # allowing do/index!
    Crawl-delay: 10

In fact, as long as you don't create a page called `robots` then this is what
gets served. I think it's a good enough way to start. If you're using spaces,
the `robots` pages of all the spaces are concatenated.

If you want to be more paranoid, create a page called `robots` and put this on
it:

    User-agent: *
    Disallow: /

Note that if you've created your own `robots` page, and you haven't decided to
disallow them all, then you also have to do the right thing for all your spaces,
if you use them at all.

## Limited, read-only HTTP support

You can actually look at your wiki pages using a browser! But beware: these days
browser will refuse to connect to sites that have self-signed certificates.
You'll have to click buttons and make exceptions and all of that, or get your
certificate from Let's Encrypt or the like. Anyway, it works in theory. If you
went through the ["Quickstart"](#quickstart), visiting `https://localhost:1965/` should
work!

Notice that Gemini Wiki doesn't have to live behind another web server like
Apache or nginx. It's a (simple) web server, too!

Here's how you could serve the wiki both on Gemini, and the standard HTTPS port,
443:

    sudo ./gemini-wiki.pl --port=443 --port=1965 \
      --user=$(id --user --name) --group=$(id --group  --name)

We need to use `sudo` because all the ports below 1024 are priviledge ports and
that includes the standard HTTPS port. Since we don't want the server itself to
run with all those priviledges, however, I'm using the `--user` and `--group`
options to change effective and user and group ID. The `id` command is used to
get your user and your group IDs instead. If you've followed the ["Quickstart"](#quickstart)
and created a separate `gemini` user, you could simply use `--user=gemini` and
`--group=gemini` instead. 👍

## Configuration

This section describes some hooks you can use to customize your wiki using the
`config` file.

- `@init` is a list of code references allowing you to change the
      configuration of the server; it gets executed as the server starts, after
      regular configuration
- `@extensions` is a list of code references allowing you to handle
      additional URLs; return 1 if you handle a URL; each code reference gets
      called with the first line of the request (a Gemini URL, a Gopher
      selector, a finger user, a HTTP request line), and a hash reference for
      the headers (in the case of HTTP requests)
- `@main_menu` adds more lines to the main menu, possibly links that aren't
      simply links to existing pages

The following example illustrates this:

    package Gemini::Wiki;
    use Modern::Perl;
    our (@extensions, @main_menu);
    push(@main_menu, "=> gemini://localhost/do/test Test");
    push(@extensions, \&serve_test);
    sub serve_test {
      my $self = shift;
      my $url = shift;
      my $headers = shift;
      my $host = $self->host_regex();
      my $port = $self->port();
      if ($url =~ m!^gemini://($host)(?::$port)?/do/test$!) {
        say "20 text/plain\r";
        say "Test";
        return 1;
      }
      return;
    }
    1;

## Wiki Spaces

Wiki spaces are separate wikis managed by the same Gemini Wiki server, on the
same machine, but with data stored in a different directory. If you used
`--wiki_space=alex` and `--wiki_space=berta`, for example, then you'd have
three wikis in total:

- `gemini://localhost/` is the main space that continues to be available
- `gemini://localhost/alex/` is the wiki space for Alex
- `gemini://localhost/berta/` is the wiki space for Berta

Note that all three spaces are still editable by anybody who knows any of the
[tokens](#security).

## Tokens per Wiki Space

Per default, there is simply one set of tokens which allows the editing of the
wiki, and all the wiki spaces you defined. If you want to give users a token
just for their space, you can do that, too. Doing this is starting to strain the
command line interface, however, and therefore the following illustrates how to
do more advanced configuration using `@init` in the config file:

    package Gemini::Wiki;
    use Modern::Perl;
    our (@init);
    push(@init, \&init_tokens);
    sub init_tokens {
      my $self = shift;
      $self->{server}->{wiki_space_token}->{alex} = ["*secret*"];
    };

The code above sets up the `wiki_space_token` property. It's a hash reference
where keys are existing wiki spaces and values are array references listing the
valid tokens for that space (in addition to the global tokens that you can set
up using `--wiki_token` which defaults to the token "hello"). Thus, the above
code sets up the token `*secret*` for the `alex` wiki space.

You can use the config file to change the values of other properties as well,
even if these properties are set via the command line. The config file allows
you to overwrite those, and the config file is read for every request!

    package Gemini::Wiki;
    use Modern::Perl;
    our (@init);
    push(@init, \&init_tokens);
    sub init_tokens {
      my $self = shift;
      $self->{server}->{wiki_token} = [];
    };

This code simply deactivates the token list. No more tokens!

## Client Certificates

Gemini Wiki serves a public wiki by default. In theory, limiting editing to
known users (that is, known client certificates) is possible. I say "in theory"
because this requires a small change to [Net::Server::Proto::SSL](https://metacpan.org/pod/Net%3A%3AServer%3A%3AProto%3A%3ASSL). For your
convenience, this repository comes with a patched version (based on
[Net::Server](https://metacpan.org/pod/Net%3A%3AServer) 2.009). All this does is add SSL\_verify\_callback to the list of
options for [IO::Socket::SSL](https://metacpan.org/pod/IO%3A%3ASocket%3A%3ASSL). Gemini Wiki includes the local `lib` directory
in its library search path, so if you have the `lib/Net/Server/Proto/SSL.pm`
file in the current directory where you start `gemini-wiki`, it should simply
work.

Here's a config file using client certificates to limit writing to a single,
known fingerprint:

    # -*- mode: perl -*-
    package Gemini::Wiki;
    use Modern::Perl;
    our (@init, @extensions);
    my @fingerprints = ('sha256$e4b871adf0d74d9ab61fbf0b6773d75a152594090916834278d416a769712570');
    push(@extensions, \&protected_wiki);
    sub protected_wiki {
      my $self = shift;
      my $url = shift;
      my $host_regex = $self->host_regex();
      my $port = $self->port();
      my $spaces = join("|", map { quotemeta } $self->spaces());
      my $fingerprint = $self->{server}->{client}->get_fingerprint();
      if (my ($host, $path) = $url =~ m!^titan://($host_regex)(?::$port)?([^?#]*)!) {
        my ($space, $resource) = $path =~ m!^(?:/($spaces))?(?:/raw)?/([^/;=&]+(?:;\w+=[^;=&]+)+)!;
        if (not $resource) {
          $self->log(4, "The Titan URL is malformed: $path $spaces");
          say "59 The Titan URL is malformed\r";
        } elsif ($fingerprint and grep { $_ eq $fingerprint} @fingerprints) {
          $self->log(3, "Successfully identified client certificate");
          my ($id, @params) = split(/[;=&]/, $resource);
          $self->write_page($host, $self->space($host, $space), decode_utf8(uri_unescape($id)),
                            {map {decode_utf8(uri_unescape($_))} @params});
        } elsif ($fingerprint) {
          $self->log(3, "Unknown client certificate $fingerprint");
          say "61 Your client certificate is not authorized for editing\r";
        } else {
          $self->log(3, "Requested client certificate");
          say "60 You need a client certificate to edit this wiki\r";
        }
        return 1;
      }
      return;
    }
    1;

`@fingerprints` is a list, so you could add more fingerprints:

    my @fingerprints = qw(
      sha256$e4b871adf0d74d9ab61fbf0b6773d75a152594090916834278d416a769712570
      sha256$4a948f5a11f4a81d0a2e8b60b1e4b3c9d1e25f4d95694965d98b333a443a3b25);

Or you could read them from a file:

    use File::Slurper qw(read_lines);
    my @fingerprints = read_lines("fingerprints");

The important part is that this code matches the same Titan requests as the
default code, and it comes first. Thus, the old code can no longer be reached
and this code checks for a known fingerprint.

To be sure, it doesn't check anything else! It doesn't check whether the client
certificate has expired, for example.

## Virtual Hosting

Sometimes you want have a machine reachable under different domain names and you
want each domain name to have their own wiki space, automatically. You can do
this by using `--wiki_space=*` and the appropriate `--host=example.org`
arguments.

Here's a simple, stand-alone setup that will work on your local machine. These
are usually reachable using the IPv4 `127.0.0.1` or the name `localhost`. The
following command tells Gemini Wiki to serve both `localhost` and `127.0.0.1`
(the default is to just use `localhost`), and to use a wiki space of the same
name.

    perl gemini-wiki.pl --host=localhost --host=127.0.0.1 --wiki_space=*

Visit both [gemini://localhost/](gemini://localhost/) and [gemini://127.0.0.1/](gemini://127.0.0.1/) and create a new
page, then examine the data directory `wiki`. You'll see both `wiki/localhost`
and `wiki/127.0.0.1`.

Beware, however: if you specify more spaces in addition to `--wiki_space=*`,
then those spaces can be seen from both hostnames. Here's an example:

    perl gemini-wiki.pl --host=localhost --host=127.0.0.1 --wiki_space=* --wiki_space=oops

In this situation, you can visit both [gemini://localhost/oops/](gemini://localhost/oops/) and
[gemini://127.0.0.1/oops/](gemini://127.0.0.1/oops/) and the content will be the same. This may or may
not be what you intended. A search index would index both, for example. My guess
is that you should should either specify the wiki spaces explicity, or you
should use virtual hosting by specifying `--wiki_space=*`, but not both. Not
using spaces is fine, too. 😀
