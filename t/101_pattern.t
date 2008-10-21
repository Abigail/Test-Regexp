#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

our $VERSION = 1.000;

use Test::More 'no_plan';
use Test::Regexp;

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

sub check {
    my $expected = shift;
    my $tag    = "ok ";
    if ($expected !~ /^$result$/) {
        say "# Got '$result'";
        say "# Expected '$expected'";
        $tag = "not $tag";
    }
    say $tag, ++ $count, " DATA line $.";
    $result = "";
}

while (<DATA>) {
    chomp;
    m {^\h* (?|"(?<subject>[^"]*)"|(?<subject>\S+))
        \h+ (?|/(?<pattern>[^/]*)/|(?<pattern>\S+))
        \h+ (?<match>(?i:[ymn01]))
        \h+ (?<result>[PF]+)
        \h* (?:$|\#)}x or next;
    my ($subject, $pattern, $match, $result) =
        @+ {qw [subject pattern match result]};

    my $match_val = $match =~ /[ym1]/i;
    match subject  =>  $subject,
          pattern  =>  $pattern,
          match    =>  $match_val;
    check $result;
}

#
# Names in the __DATA__ section come from 'meta norse_mythology'.
#

__DATA__
Dagr     ....     y   PP
Kvasir   Kvasir   y   PP
Snotra   \w+      y   PP
Sjofn    \w+      n   F    # It matches, so a no match should fail
Borr     Bo       y   PF   # Match is only partial
Magni    Sigyn    y   FP   # Fail, then a skip
