#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

our $VERSION = 1.000;

my $failures = 0;

#
# This end block should preceed the use of Test::Regexp.
#
END {
    Test::Builder::_my_exit ($failures > 254 ? 254 : $failures)
};

use Test::Regexp;
Test::Regexp -> builder -> plan ('no_plan');

my $result = "";
my $count  = 0;

END {say "1..$count"}

BEGIN {
    no strict 'refs';
    no warnings 'redefine';
    #
    # Intercept the 'ok' and 'not ok' prints, and remember the results.
    #
    *{"Test::Builder::_print"} = sub {
        my ($self, @msgs) = @_;
        my $mesg = join "" => @msgs;
        given ($mesg) {
            when (/^ok/)     {$result .= "P"}
            when (/^not ok/) {$result .= "F"}
        }
    };
    #
    # Don't want to see diagnostics.
    #
    *{"Test::Builder::_print_diag"} = sub {1;}
}

my ($subject, $pattern, $match_val);
sub check {
    my $expected = shift;
    my $tag      = "ok ";
    my $exp_pat  = $expected;
       $exp_pat  =~ s/S/P/g;
    if ($result !~ /^$exp_pat$/) {
        say "# Got '$result'";
        say "# Expected '$expected'";
        $tag = "not $tag";
        $failures ++;
    }
    my $op = $match_val ? "=~" : "!~";
    say $tag, ++ $count, qq { "$subject" $op /$pattern/};

    my $passes = $expected =~ y/P//;
    my $fails  = $expected =~ y/F//;
    my $skips  = $expected =~ y/S//;
    $tag = "ok ";
    unless ($passes == $Test::Regexp::TESTS_PASS &&
            $fails  == $Test::Regexp::TESTS_FAIL &&
            $skips  == $Test::Regexp::TESTS_SKIP) {
        $tag = "not ok ";
        printf "# Got '%d' passes, expected '%d'\n"   .
               "# Got '%d' failures, expected '%d'\n" .
               "# Got '%d' skips, expected '%d'\n"    =>
            $Test::Regexp::TESTS_PASS, $passes,
            $Test::Regexp::TESTS_FAIL, $fails,
            $Test::Regexp::TESTS_SKIP, $skips;
        $failures ++;
    }
    say $tag, ++ $count, qq { TESTS_PASS and TESTS_FAIL};

    $result = "";
}

while (<DATA>) {
    chomp;
    m {^\h* (?|"(?<subject>[^"]*)"|(?<subject>\S+))
        \h+ (?|/(?<pattern>[^/]*)/|(?<pattern>\S+))
        \h+ (?<match>(?i:[ymn01]))
        \h+ (?<result>[PFS]+)
        \h* (?:$|\#)}x or next;
    ($subject, $pattern, my ($match, $result)) =
        @+ {qw [subject pattern match result]};

    $match_val = $match =~ /[ym1]/i;
    match subject  =>  $subject,
          pattern  =>  $pattern,
          match    =>  $match_val;
    check $result;
}


#
# Names in the __DATA__ section come from 'meta norse_mythology'.
#

__DATA__
Dagr          ....       y   PPP
Kvasir        Kvasir     y   PPP
Snotra        \w+        y   PPP
Sjofn         \w+        n   F     # It matches, so a no_match should fail
Borr          Bo         y   PFP   # Match is only partial
Magni         Sigyn      y   FSS   # Fail, then a skip
Andhrimnir    Delling    n   P     # Doesn't match, so a pass
Hlin          .(.)..     y   PPF   # Sets a capture, so should fail
Od            (?<l>.*)   y   PPF   # Sets a capture, so should fail
