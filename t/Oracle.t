# Copyright (C) 2021  Alex Schroeder <alex@gnu.org>
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
use utf8;

our @use = qw(Oracle);

require './t/test.pl';

# variables set by test.pl
our $base;
our $host;
our $port;
our $dir;

my $page = query_gemini("$base/oracle");
like($page, qr/^# Oracle/m, "Title");
like($page, qr/^=> \/oracle\/ask Ask a question/m, "Link to ask a question");

$page = query_gemini("$base/oracle/ask", undef, 0);
like($page, qr/^60/, "Client certificate required");

$page = query_gemini("$base/oracle/ask");
like($page, qr/^10/, "Ask a question");

$page = query_gemini("$base/oracle/ask?2+%2b+2");
like($page, qr/^# The oracle accepts/m, "Oracle accepts the question");
$page =~ /^=> \/oracle\/question\/(\d+) Show question/m;
my $n = $1;
ok($n > 0, "Question number");

$page = query_gemini("$base/oracle/question/$n");
like($page, qr/^# Question #$n/m, "Question title");
like($page, qr/^2 \+ 2/m, "Question text");
like($page, qr/^=> \/oracle\/question\/$n\/delete Delete this question/m, "Link to delete this question");
unlike($page, qr/answer/, "Question asker does not get to answer");

$page = query_gemini("$base/oracle/question/$n", undef, 0);
unlike($page, qr/delete/, "Unidentified visitor does not get to delete the question");
unlike($page, qr/answer/, "Unidentified visitor does not get to answer the question");

$page = query_gemini("$base/oracle/question/$n", undef, 2);
unlike($page, qr/delete/, "Somebody else does not get to delete the question");
like($page, qr/^=> \/oracle\/question\/$n\/answer Submit an answer/m, "Somebody else may answer");

$page = query_gemini("$base/oracle/question/$n/answer", undef, 0);
like($page, qr/^60/, "Unidentified visitor does not get a prompt for an answer");
$page = query_gemini("$base/oracle/question/$n/answer");
like($page, qr/^40/, "Question asker does not get to answer");
$page = query_gemini("$base/oracle/question/$n/answer", undef, 2);
like($page, qr/^10/, "Prompt for an answer");
$page = query_gemini("$base/oracle/question/" . ($n+1) . "/answer", undef, 2);
like($page, qr/deleted/, "Attempt to answer an unknown question");

$page = query_gemini("$base/oracle/question/$n/answer?4", undef, 2);
like($page, qr/^30/, "Answer given");

$page = query_gemini("$base/oracle/question/$n");
like($page, qr/^## Answer #1/m, "Answer title");
like($page, qr/^4/m, "Answer text");
like($page, qr/^=> \/oracle\/question\/$n\/1\/delete Delete this answer/m, "Link to delete this answer");

$page = query_gemini("$base/oracle/question/$n", undef, 0);
unlike($page, qr/^4/, "Unidentified visitor does not get to see the answer");

$page = query_gemini("$base/oracle/question/$n", undef, 2);
like($page, qr/^## Your answer/m, "Your answer title");
like($page, qr/^4/m, "Your answer text");
like($page, qr/^=> \/oracle\/question\/$n\/1\/delete Delete this answer/m, "Link to delete your answer");
unlike($page, qr/^=> \/oracle\/question\/$n\/answer Submit an answer/m, "You no longer may answer");

$page = query_gemini("$base/oracle/question/$n/answer?4", undef, 2);
like($page, qr/already answered/, "Do not answer twice");

done_testing;
