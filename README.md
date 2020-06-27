# Gemini Wiki

This server serves a wiki as a Gemini site.

It does two things:

- It's a program that you run on a computer and other people connect to it
      using their [client](https://gemini.circumlunar.space/clients.html) in
      order to read the pages on it.
- It's a wiki, which means that people can edit the pages without needing an
      account. All they need is a client that speaks both
      [Gemini](https://gemini.circumlunar.space/) and Titan, and the password.
      The default password is "hello". 😃

## How do you edit a Gemini Wiki?

You need to use a Titan-enabled client.

Known clients:

- [Gemini Write](https://alexschroeder.ch/cgit/gemini-write/) is an
      extension for the Emacs Gopher and Gemini client
      [Elpher](https://thelambdalab.xyz/elpher/)
- [Gemini & Titan for Bash](https://alexschroeder.ch/cgit/gemini-titan/about/?h=main)
      are two shell functions that allow you to download and upload files

## What is Titan?

Titan is a companion protocol to Gemini: it allows clients to upload files to
Gemini sites, if servers allow this. Gemini Wiki, you can edit the "raw" pages.
That is, at the bottom of a page you'll see a link to the "raw" page. If you
follow it, you'll see the page content as plain text. You can submit a changed
version of this text to the same URL using Titan. There is more information for
developers available [on Community Wiki](https://communitywiki.org/wiki/Titan).

## Dependencies

Perl libraries you need to install if you want to run Gemini wiki:

- [Algorithm::Diff](https://metacpan.org/pod/Algorithm::Diff)
- [File::ReadBackwards](https://metacpan.org/pod/File::ReadBackwards)
- [File::Slurper](https://metacpan.org/pod/File::Slurper)
- [Modern::Perl](https://metacpan.org/pod/Modern::Perl)
- [Net::Server](https://metacpan.org/pod/Net::Server)
- [URI::Escape](https://metacpan.org/pod/URI::Escape)

On Debian:

    sudo apt install \
      libalgorithm-diff-xs-perl \
      libfile-readbackwards-perl \
      libfile-slurper-perl \
      libmodern-perl-perl \
      libnet-server-perl \
      liburi-escape-xs-perl

## Installing Gemini Wiki

It implements [Net::Server](https://metacpan.org/pod/Net::Server) and thus all the options available to
`Net::Server` are also available here. Additional options are available:

    wiki           - the path to the Oddmuse script
    wiki_dir       - the path to the Oddmuse data directory
    wiki_pages     - a page to show on the entry menu
    cert_file      - the filename containing a certificate in PEM format
    key_file       - the filename containing a private key in PEM format

There are many more options in the `Net::Server` documentation. This is
important if you want to daemonize the server. You'll need to use `--pid_file`
so that you can stop it using a script, `--setsid` to daemonize it,
`--log_file` to write keep logs, and you'll need to set the user or group using
`--user` or `--group` such that the server has write access to the data
directory.

For testing purposes, you can start with the following:

    --port=2000
        The port to listen to, defaults to 1965
    --log_level=4
        The log level to use, defaults to 2
    --wiki_dir=/var/wiki
        The wiki directory, defaults to the value of the "GEMINI_WIKI_DATA_DIR"
        environment variable, or the "./wiki" subdirectory
    --wiki_pages=HomePage
    --wiki_pages=About
        This adds pages to the main index; can be used multiple times
    --cert_file=/var/lib/dehydrated/certs/alexschroeder.ch/fullchain.pem
    --key_file=/var/lib/dehydrated/certs/alexschroeder.ch/privkey.pem
        Gemini requires certificates. You can use C<make cert> to generate new
        certificates! The default values are C<cert.pem> and C<key.pem>.
    --help
        Prints this message

You need to provide PEM files containing certificate and private key. To create
self-signed files, use the following (or use `make cert`):

    openssl req -new -x509 -nodes -out cert.pem -keyout key.pem

Example invocation, using all the defaults:

    ./gemini-wiki.pl

Run Gemini Wiki and test it from the command-line:

    (sleep 1; echo gemini://localhost) \
        | openssl s_client --quiet --connect localhost:1965 2>/dev/null

You should see something like the following:

    20 text/gemini; charset=UTF-8
    Welcome to the Gemini Wiki.

## Wiki Directory

There are various files and subdirectories that will be created in your wiki
directory.

- `page` is a directory where the current pages are stored.
- `keep` is a directory where older revisions of the pages are stored. If
      you don't care about the older revisions, you can delete them. Surely
      there is a command involving `find` and `rm` that you could run from a
      `cron` job to do this.
- `index` is a file listing all the pages. It is updated whenever a new
      page is created, It will be regenerated if you delete it.
- `changes.log` is a the log file of all changes.
- `config` is an optional file containing Perl code where you can mess with
      the code. See _Configuration_ below.

## Configuration

This section describes some hooks you can use to customize your wiki using the
`config` file.

### @extensions

`@extensions` is a list of additional URLs you want the wiki to handle. One
example to do this would be:

    package Gemini::Wiki;

    # shared with gemini-wiki.pl
    our (@extensions);

    push(@extensions, \&serve_other);

    sub serve_other {
      my $self = shift;
      my $url = shift;
      if ($url =~ m!^gemini://communitywiki.org:1965/(.*)!) {
        say "30 gemini://communitywiki.org:1966/$1\r";
        return 1;
      }
      return;
    }

The example above is from my setup where the `alexschroeder.ch` and
`communitywiki.org` point to the same machine. On this machine, I have two
Gemini servers running: one of them is serving port 1965 and the other is
serving port 1966. If you visit `communitywiki.org:1965` you're ending up on
the Gemini server that serves `alexschroeder.ch`. So what it does is when it
sees the domain `communitywiki.org`, it redirects you to
`communitywiki.org:1966`.

### @main\_menu\_links

`@main_menu_links` adds more links to the main menu that aren't simply links to
existing pages. You probably want to use this together with the previous code to
handle new URLs. The following code is how I make my photo galleries available
via Gemini.

    package Gemini::Wiki;
    use Modern::Perl;
    use Mojo::JSON;
    use Mojo::DOM;
    use File::Slurper qw(read_text read_binary read_dir);

    # shared with gemini-wiki.pl
    our (@extensions, @main_menu_links);

    # galleries
    push(@extensions, \&galleries);

    push(@main_menu_links, "=> gemini://alexschroeder.ch/do/gallery Galleries");

    push(@extensions, \&galleries);

    my $parent = "/home/alex/alexschroeder.ch/gallery";

    sub galleries {
      my $self = shift;
      my $url = shift;
      if ($url =~ m!/do/gallery$!) {
        $self->success();
        $self->log(3, "Serving galleries");
        say "# Galleries";
        for my $dir (
          sort {
            my ($year_a, $title_a) = split(/-/, $a, 2);
            my ($year_b, $title_b) = split(/-/, $b, 2);
            return ($year_b <=> $year_a || $title_a cmp $title_b);
          } grep {
            -d "$parent/$_"
          } read_dir($parent)) {
          $self->print_link(ucfirst($dir), "do/gallery/$dir");
        };
        return 1;
      } elsif (my ($dir) = $url =~ m!/do/gallery/([^/?]*)$!) {
        if (not -d "$parent/$dir") {
          say "40 This is not actuall a gallery";
          return 1;
        }
        if (not -r "$parent/$dir/data.json") {
          say "40 This gallery does not contain a data.json file like the one created by sitelen-mute or fgallery";
          return 1;
        }
        my $bytes = read_binary("$parent/$dir/data.json");
        if (not $bytes) {
          say "40 Cannot read the data.json file in this gallery";
          return 1;
        }
        my $data;
        eval { $data = decode_json $bytes };
        $self->log(1, "decode_json: $@") if $@;
        if ($@ or not %$data) {
          say "40 Cannot decode the data.json file in this gallery";
          return 1;
        }
        $self->success();
        $self->log(3, "Serving gallery $dir");
        if (-r "$parent/$dir/index.html") {
          my $dom = Mojo::DOM->new(read_text("$parent/$dir/index.html"));
          $self->log(3, "Parsed index.html");
          my $title = $dom->at('*[itemprop="name"]');
          $title = $title ? $title->text : ucfirst($dir);
          say "# $title";
          my $description = $dom->at('*[itemprop="description"]');
          say $description->text if $description;
          say "## Images";
        } else {
          say "# " . ucfirst($dir);
        }
        for my $image (@{$data->{data}}) {
          say join("\n", @{$image->{caption}}) if $image->{caption};
          $self->print_link("Thumbnail", "do/gallery/$dir/" . $image->{thumb}->[0]);
          $self->print_link("Image", "do/gallery/$dir/" . $image->{img}->[0]);
        }
        return 1;
      } elsif (my ($file, $extension) = $url =~ m!/do/gallery/([^/?]*/(?:thumbs|imgs)/[^/?]*\.(jpe?g|png))$!i) {
        if (not -r "$parent/$file") {
          say "40 Cannot read $file";
        } else {
          $self->success($extension =~ /^png$/i ? "image/png" : "image/jpg");
          $self->log(3, "Serving image $file");
          print(read_binary("$parent/$file"));
        }
        return 1;
      }
      return;
    }
