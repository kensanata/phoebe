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

=encoding utf8

=head1 NAME

App::Phoebe::Capsules - provide every visitor with a writeable capsule

=head1 DESCRIPTION

By default, Phoebe creates a wiki editable by all. With this extension, the
C</capsule> space turns into a special site: if you have a client certificate,
you automatically get an editable capsule with an assigned fantasy name.

Simply add it to your F<config> file. If you are virtual hosting, name the host
or hosts for your capsules.

    use App::Phoebe::Capsule;
    package App::Phoebe::Capsule;
    @capsule_hosts = qw(transjovian.org);

Every client certificate gets assigned a capsule name.

=cut

package App::Phoebe::Capsules;
use App::Phoebe qw($server $log @extensions @request_handlers host_regex port success result print_link wiki_dir
		   valid_params process_titan to_url);
use File::Slurper qw(read_dir read_binary write_binary);
use Net::IDN::Encode qw(domain_to_ascii);
use Encode qw(encode_utf8 decode_utf8);
use Modern::Perl;
use URI::Escape;

push(@extensions, \&capsules);

our $capsule_space = "capsule";
our @capsule_hosts;

sub capsules {
  my $stream = shift;
  my $url = shift;
  my $hosts = capsule_regex();
  my $port = port($stream);
  my ($host, $capsule, $id);
  if (($host, $capsule) = $url =~ m!^gemini://($hosts)(?::$port)?/$capsule_space/([^/]+)/upload$!) {
    return result($stream, "10", "Filename");
  } elsif (($host, $capsule, $id) = $url =~ m!^gemini://($hosts)(?::$port)?/$capsule_space/([^/]+)/upload\?([^/]+)$!) {
    return result($stream, "30", "gemini://$host:$port/$capsule_space/$capsule/$id");
  } elsif (($host, $capsule, $id) = $url =~ m!^gemini://($hosts)(?::$port)?/$capsule_space/([^/]+)/([^/]+)$!) {
    $capsule = decode_utf8(uri_unescape($capsule));
    my $dir = capsule_dir($host, $capsule);
    $id = decode_utf8(uri_unescape($id));
    my $file = "$dir/$id";
    if (-f $file) {
      $log->info("Serving $file");
      # this works for text files, too!
      success($stream, mime_type($id));
      $stream->write(read_binary($file));
    } else {
      $log->info("Serving invitation to upload $file");
      success($stream);
      $stream->write("This file does not exist. Upload it using Titan!\n");
      $stream->write("=> gemini://transjovian.org/titan What is Titan?\n");
    }
    return 1;
  } elsif (($host) = $url =~ m!^gemini://($hosts)(?::$port)?/$capsule_space/login$!) {
    my $capsule = capsule_name($stream);
    if ($capsule) {
      $log->info("Redirect to capsule");
      result($stream, "30", "gemini://$host:$port/$capsule_space/$capsule");
    } else {
      $log->info("Requested client certificate for capsule");
      result($stream, "60", "You need a client certificate to access your capsule");
    }
    return 1;
  } elsif (($host, $capsule) = $url =~ m!^gemini://($hosts)(?::$port)?/$capsule_space/([^/]+)/?$!) {
    my $name = capsule_name($stream);
    $capsule = decode_utf8(uri_unescape($capsule));
    my $dir = capsule_dir($host, $capsule);
    my @files;
    @files = read_dir($dir) if -d $dir;
    if (not @files) {
      if ($name and $name eq $capsule) {
	success($stream);
	$log->info("New capsule $capsule");
	$stream->write("# " . ucfirst($capsule) . "\n");
	$stream->write("This capsule is empty. Upload files using Titan!\n");
	$stream->write("=> gemini://transjovian.org/titan What is Titan?\n");
	$stream->write("=> upload Specify file for upload\n");
	return 1;
      } else {
	return result($stream, "51", "This capsule does not exist");
      }
    }
    success($stream);
    $log->info("Serving $capsule");
    $stream->write("# " . ucfirst($capsule) . "\n");
    $stream->write("=> upload Specify file for upload\n") if $name and $name eq $capsule;
    $stream->write("Files:\n");
    for my $file (@files) {
      print_link($stream, $host, $capsule_space, $file, "$capsule/$file");
    };
    return 1;
  } elsif (($host) = $url =~ m!^gemini://($hosts)(?::$port)?/$capsule_space/?$!) {
    success($stream);
    $log->info("Serving capsules");
    $stream->write("# Capsules\n");
    my $capsule = capsule_name($stream);
    if ($capsule) {
      $stream->write("This is your capsule:\n");
      print_link($stream, $host, $capsule_space, $capsule, $capsule); # must provide $id to avoid page/ prefix
    } else {
      $stream->write("Login if you are interested in a capsule:\n");
      print_link($stream, $host, $capsule_space, "login", "login"); # must provide $id to avoid page/ prefix
    }
    my @capsules = read_dir(wiki_dir($host, $capsule_space));
    $stream->write("Capsules:\n") if @capsules;
    for my $dir (@capsules) {
      print_link($stream, $host, $capsule_space, $dir, $dir); # must provide $id to avoid page/ prefix
    };
    return 1;
  }
  return;
}

sub capsule_dir {
  my $host = shift;
  my $capsule = shift;
  my $dir = $server->{wiki_dir};
  if (keys %{$server->{host}} > 1) {
    $dir .= "/$host";
    mkdir($dir) unless -d $dir;
  }
  $dir .= "/$capsule_space";
  mkdir($dir) unless -d $dir;
  $dir .= "/$capsule";
  return $dir;
}

sub capsule_regex {
  return join("|", map { quotemeta domain_to_ascii $_ } @capsule_hosts) || host_regex();
}

sub capsule_name {
  my $stream = shift;
  my $fingerprint = $stream->handle->get_fingerprint();
  return unless $fingerprint;
  my $integer = hex(substr($fingerprint, 8, 8));
  srand($integer);
  my $digraphs = "..lexegezacebisousesarmaindire.aeratenberalavetiedorquanteisrion";
  my $max = length($digraphs);
  my $length = 4 + rand(7); # 4-8
  my $name = '';
  while (length($name) < $length) {
    $name .= substr($digraphs, 2*int(rand($max/2)), 2);
  }
  $name =~ s/\.//g;
  return $name;
}

sub mime_type {
  $_ = shift;
  return 'text/gemini' if /\.gmi$/i;
  return 'text/plain' if /\.te?xt$/i;
  return 'text/markdown' if /\.md$/i;
  return 'text/html' if /\.html?$/i;
  return 'image/png' if /\.png$/i;
  return 'image/jpeg' if /\.jpe?g$/i;
  return 'image/gif' if /\.gif$/i;
  return 'application/octet-stream';
}

unshift(@request_handlers, '^titan://(' . capsule_regex() . ')(?::\d+)?/' . $capsule_space . '/' => \&handle_titan);

# We need our own Titan handler because we want a different copy of is_upload; and once we we're here we can run our extension directly.
sub handle_titan {
  my $stream = shift;
  my $data = shift;
  # extra processing of the request if we didn't do that, yet
  $data->{upload} ||= is_upload($stream, $data->{request}) or return;
  my $size = $data->{upload}->{params}->{size};
  my $actual = length($data->{buffer});
  if ($actual == $size) {
    save_file($stream, $data->{request}, $data->{upload}, $data->{buffer}, $size);
    $stream->close_gracefully();
    return;
  } elsif ($actual > $size) {
    $log->debug("Received more than the promised $size bytes");
    result($stream, "59", "Received more than the promised $size bytes");
    $stream->close_gracefully();
    return;
  }
  $log->debug("Waiting for " . ($size - $actual) . " more bytes");
}

# We need our own is_upload because the regular expression is different.
sub is_upload {
  my $stream = shift;
  my $request = shift;
  $log->info("Looking at capsule $request");
  my $hosts = capsule_regex();
  my $port = port($stream);
  if ($request =~ m!^titan://($hosts)(?::$port)?/$capsule_space/([^/]+)/([^/;]+);([^?#]+)$!) {
    my $host = $1;
    my ($capsule, $id, %params) = map {decode_utf8(uri_unescape($_))} $2, $3, split(/[;=&]/, $4);
    if (valid_params($stream, $host, $capsule_space, $id, \%params)) {
      return {
	host => $host,
	space => $capsule_space,
	capsule => $capsule,
	id => $id,
	params => \%params,
      }
    }
  }
  return 0;
}

sub save_file {
  my ($stream, $url, $upload, $buffer, $size) = @_;
  my $name = capsule_name($stream);
  my $capsule = $upload->{capsule} || "";
  if (not $name) {
    $log->debug("Missing certificate for capsule upload");
    return result($stream, "60", "Uploading files requires a client certificate");
  } elsif ($name ne $capsule) {
    $log->debug("Wrong certificate for capsule upload: $name vs $capsule");
    return result($stream, "61", "This is not your space: your certificate authorizes you for $name");
  }
  return result($stream, "50", "Titan upload failed")
      unless defined $buffer and defined $size and $upload->{id}
      and $upload->{space} and $upload->{space} eq "capsule";
  my $host = $upload->{host};
  my $dir = capsule_dir($host, $capsule);
  my $id = $upload->{id};
  my $file = "$dir/$id";
  if ($size == 0) {
    return result($stream, "51", "This capsule does not exist") unless -d $dir;
    return result($stream, "51", "This file does not exist") unless -f $file;
    return result($stream, "40", "Cannot delete this file") unless unlink $file;
    $log->info("Deleted $file");
  } else {
    mkdir($dir) unless -d $dir;
    write_binary($file, $buffer);
    $log->info("Wrote $file");
    return result($stream, "30", to_url($stream, $host, $capsule_space, $capsule));
  }
}

1;
