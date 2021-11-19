# -*- mode: perl -*-
# Copyright (C) 2021  Alex Schroeder <alex@gnu.org>

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

App::Phoebe::Oracle - an anonymous question asking game

=head1 DESCRIPTION

By default, Phoebe creates a wiki editable by all. With this extension, the
C</oracle> space turns into a special site: if you have a client certificate,
you can pose questions and get answers.

Simply add it to your F<config> file. If you are virtual hosting, name the host
or hosts for your capsules.

    package App::Phoebe::Oracle;
    use Modern::Perl;
    our @oracle_hosts = qw(transjovian.org);
    use App::Phoebe::Oracle;

=cut

package App::Phoebe::Oracle;
use App::Phoebe qw($server $log @extensions host_regex port success result print_link wiki_dir with_lock to_url);
use File::Slurper qw(read_binary write_binary);
use Mojo::JSON qw(decode_json encode_json);
use Net::IDN::Encode qw(domain_to_ascii);
use List::Util qw(first any none);
use Encode qw(decode_utf8);
use Modern::Perl;
use URI::Escape;

push(@extensions, \&oracle);

our $oracle_space = "oracle";
our @oracle_hosts;
our $max_answers = 3;

sub oracle {
  my $stream = shift;
  my $url = shift;
  my $hosts = oracle_regex();
  my $port = port($stream);
  my ($host, $question, $answer, $number, @numbers);
  if (($host) = $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/?$!) {
    return serve_main_menu($stream, $host);
  } elsif (($host) = $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/questions$!) {
    return serve_questions($stream, $host);
  } elsif (($host, $question) = $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/ask(?:\?([^#]+))?$!) {
    return ask_question($stream, $host, decode_query($question));
  } elsif (($host, $number) = $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/question/(\d+)$!) {
    return serve_question($stream, $host, $number);
  } elsif (($host, $number, $answer) =
	   $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/question/(\d+)/answer(?:\?([^#]+))?$!) {
    return answer_question($stream, $host, $number, decode_query($answer));
  } elsif (($host, $number) = $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/question/(\d+)/publish$!) {
    return publish_question($stream, $host, $number);
  } elsif (($host, $number) = $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/question/(\d+)/delete$!) {
    return delete_question($stream, $host, $number);
  } elsif (($host, @numbers) = $url =~ m!^gemini://($hosts)(?::$port)?/$oracle_space/question/(\d+)/(\d+)/delete$!) {
    return delete_answer($stream, $host, @numbers);
  }
  return;
}

sub oracle_regex {
  return join("|", map { quotemeta domain_to_ascii $_ } @oracle_hosts) || host_regex();
}

sub load_data {
  my $host = shift;
  my $dir = wiki_dir($host, $oracle_space);
  return [] unless -f "$dir/oracle.json";
  return decode_json read_binary("$dir/oracle.json");
}

sub new_number {
  my $data = shift;
  while (1) {
    my $n = int(rand(10000));
    return $n unless any { $n eq $_->{number} } @$data;
  }
}

sub save_data {
  my ($stream, $host, $data) = @_;
  my $dir = wiki_dir($host, $oracle_space);
  my $bytes = encode_json $data;
  $log->info("Saving " . length($bytes) . " bytes");
  with_lock($stream, $host, $oracle_space, sub {
    write_binary("$dir/oracle.json", $bytes)});
}

sub decode_query {
  my $text = shift;
  return '' unless $text;
  $text =~ s/\+/ /g;
  return decode_utf8(uri_unescape($text));
}

sub serve_main_menu {
  my ($stream, $host) = @_;
  my $data = load_data($host);
  my $fingerprint = $stream->handle->get_fingerprint();
  success($stream);
  $log->info("Serving oracles");
  $stream->write("# Oracle\n");
  $stream->write("=> /$oracle_space/ask Ask a question\n");
  my @questions = grep {
    $_->{status} ne 'answered'
	or $_->{fingerprint} eq $fingerprint
  } @$data;
  for my $question (@questions) {
    $stream->write("\n\n");
    $stream->write("## Question #$question->{number}\n");
    $stream->write($question->{text});
    $stream->write("\n");
    if ($question->{status} eq 'asked') {
      $stream->write("=> /$oracle_space/question/$question->{number} Answer\n");
    } elsif ($question->{status} eq 'answered') {
      $stream->write("=> /$oracle_space/question/$question->{number} Manage\n");
    } elsif ($question->{status} eq 'published') {
      $stream->write("=> /$oracle_space/question/$question->{number} Show\n");
    }
  }
  return 1;
}

sub serve_questions {
  my ($stream, $host) = @_;
  my $data = load_data($host);
  my $fingerprint = $stream->handle->get_fingerprint();
  return result($stream, "60", "You need a client certificate to list your questions") unless $fingerprint;
  success($stream);
  $log->info("Serving own questions");
  $stream->write("# Oracle\n");
  $stream->write("=> /$oracle_space/ask Ask a question\n");
  my @questions = grep { $_->{fingerprint} eq $fingerprint } @$data;
  for my $question (@questions) {
    $stream->write("\n\n");
    if ($question->{status} eq 'asked') {
      $stream->write("## Asked question #$question->{number}\n");
    } elsif ($question->{status} eq 'answered') {
      $stream->write("## Answered question #$question->{number}\n");
    } elsif ($question->{status} eq 'published') {
      $stream->write("## Published question #$question->{number}\n");
    }
    $stream->write($question->{text});
    $stream->write("\n");
    $stream->write("=> /$oracle_space/question/$question->{number} Show answers\n");
  }
  return 1;
}

sub serve_question {
  my ($stream, $host, $number) = @_;
  my $data = load_data($host);
  my $question = first { $_->{number} eq $number } @$data;
  if (not $question) {
    $log->info("Question $number not found");
    return result($stream, "30", to_url($stream, $host, $oracle_space, ""));
  }
  success($stream);
  my $fingerprint = $stream->handle->get_fingerprint();
  if ($question->{status} eq 'answered'
      and (not $fingerprint
	   or $fingerprint ne $question->{fingerprint})) {
    $log->info("Not the owner requesting question $number");
    $stream->write("# Question #$question->{number}\n");
    $stream->write("This question has been answered and it has not been published.\n");
    $stream->write("You are not the owner of this question, which is why you cannot do anything about it.\n");
    $stream->write("Switch identity or pick a different client certificate if you think you are the owner of this question\n");
    $stream->write("=> /$oracle_space Back to the oracle\n");
    return;
  }
  $log->info("Serving oracle $question->{number}");
  $stream->write("# Question #$question->{number}\n");
  $stream->write("=> /$oracle_space Back to the oracle\n");
  if ($fingerprint) {
    if ($fingerprint eq $question->{fingerprint}) {
      $stream->write("=> /$oracle_space/question/$number/delete Delete this question\n");
      if ($question->{status} eq 'answered') {
	$stream->write("=> /$oracle_space/question/$number/publish Publish this question\n");
      }
    } else {
      my $n = grep { $_->{text} } @{$question->{answers}};
      if ($n < $max_answers
	  and none { $fingerprint eq $_->{fingerprint} } @{$question->{answers}}) {
	# only allow answers if the undeleted answers is below the maximum, and
	# you haven't answered before (even if it was subsequently deleted
	$stream->write("=> /$oracle_space/question/$number/answer Answer this question\n");
      }
    }
  }
  if ($question->{status} eq 'asked'
      and (not $fingerprint
	   or $fingerprint ne $question->{fingerprint})) {
    # if the question is being asked and you're not the question asker, list the
    # question but not the answers
    $stream->write("\n");
    $stream->write($question->{text});
    $stream->write("\n");
    # if you haven't answered the question, you may answer it; if you have
    # answered it, you may delete your answer
    if ($fingerprint) {
      my $n = 0;
      my $found = 0;
      my $answered = 0;
      for my $answer (@{$question->{answers}}) {
	$n++;
	next unless $answer->{text};
	next unless $answer->{fingerprint} eq $fingerprint;
	$answered = 1;
	$stream->write("\n");
	$stream->write("## Your answer\n");
	$stream->write($answer->{text});
	$stream->write("\n");
	$stream->write("=> /$oracle_space/question/$question->{number}/$n/delete Delete this answer\n");
	last;
      }
      if (not $answered) {
	$stream->write("=> /$oracle_space/question/$question->{number}/answer Submit an answer to the oracle\n");
      }
    }
  } else {
    $stream->write("\n");
    $stream->write($question->{text});
    $stream->write("\n");
    my $n = 0;
    for my $answer (@{$question->{answers}}) {
      $n++;
      next unless $answer->{text};
      $stream->write("\n");
      $stream->write("## Answer #$n\n");
      $stream->write($answer->{text});
      $stream->write("\n");
      if ($fingerprint
	  and ($fingerprint eq $question->{fingerprint}
	       or $fingerprint eq $answer->{fingerprint})) {
	$stream->write("=> /$oracle_space/question/$question->{number}/$n/delete Delete this answer\n");
      }
    }
  }
  return 1;
}

sub ask_question {
  my ($stream, $host, $text) = @_;
  my $fingerprint = $stream->handle->get_fingerprint();
  return result($stream, "60", "You need a client certificate to ask a question") unless $fingerprint;
  my $data = load_data($host);
  my $question = first { $_->{fingerprint} eq $fingerprint } @$data;
  if ($question) {
    $log->info("Asking the oracle a question but there already is one asked question");
    success($stream);
    $stream->write("# Ask the oracle a question\n");
    $stream->write("You already have an unanswered question.\n");
    $stream->write("=> /$oracle_space/question/$question->{number} Show question\n");
  } elsif (not $text) {
    $log->info("Asking the oracle a question");
    result($stream, "10", "Your question for the oracle");
  } else {
    $log->info("Saving a new question for the oracle");
    $question = {
      number => new_number($data),
      text => $text,
      fingerprint => $fingerprint,
      status => 'asked',
      answers => [],
    };
    unshift(@$data, $question);
    save_data($stream, $host, $data);
    success($stream);
    $stream->write("# The oracle accepts!\n");
    $stream->write("You question was submitted to the oracle.\n");
    $stream->write("=> /$oracle_space/question/$question->{number} Show question\n");
  }
  return 1;
}

sub answer_question {
  my ($stream, $host, $number, $text) = @_;
  my $fingerprint = $stream->handle->get_fingerprint();
  if (not $fingerprint) {
    $log->info("Answering a question requires a certificate");
    result($stream, "60", "You need a client certificate to answer a question");
    return 1;
  }
  my $data = load_data($host);
  my $question = first { $_->{number} eq $number } @$data;
  if (not $question) {
    $log->info("Answering a deleted question");
    success($stream);
    $stream->write("# Answer a question\n");
    $stream->write("The question you wanted to answer has been deleted.\n");
    $stream->write("=> /$oracle_space Back to the oracle\n");
    return 1;
  } elsif ($fingerprint eq $question->{fingerprint}) {
    $log->info("The question asker may not answer");
    result($stream, "40", "You may not answer your own question");
    return 1;
  }
  my $answer = first { $_->{fingerprint} eq $fingerprint } @{$question->{answers}};
  if ($answer) {
    $log->info("Answering a question again");
    success($stream);
    $stream->write("# Answer a question\n");
    $stream->write("You already answered this question.\n");
    $stream->write("=> /$oracle_space/question/$question->{number} Show\n");
  } elsif ($question->{status} ne 'asked') {
    $log->info("Answering an answered question");
    success($stream);
    $stream->write("# Answer a question\n");
    $stream->write("This question no longer takes answers.\n");
    $stream->write("=> /$oracle_space/question/$question->{number} Show\n");
  } elsif (not $text) {
    $log->info("Answering a question");
    result($stream, "10", "Your answer for the oracle");
  } else {
    $log->info("Saving a new answer for the oracle");
    $answer = {
      text => $text,
      fingerprint => $fingerprint,
    };
    push(@{$question->{answers}}, $answer);
    my $n = grep { $_->{text} } @{$question->{answers}};
    $question->{status} = 'answered' if $n >= $max_answers;
    save_data($stream, $host, $data);
    result($stream, "30", to_url($stream, $host, $oracle_space, "question/$question->{number}"));
  }
  return 1;
}

1;
