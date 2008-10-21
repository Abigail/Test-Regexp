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
    my @caller = caller (0);
    my $line   = $caller [2];
    my $tag    = "ok ";
    if ($expected !~ /^$result$/) {
        say "# Got '$result'";
        say "# Expected '$expected'";
        $tag = "not $tag";
    }
    say $tag, ++ $count, " Line $line";
    $result = "";
}

while (<DATA>) {
    chomp;
    my ($subject, $pattern, $r) = split /\s+-\s+/;
    if ($r =~ /p/) {
        match subject  =>  $subject,
              pattern  =>  $pattern,
        ;
        check "PP";
    }
    else {
        match subject  =>  $subject,
              pattern  =>  $pattern,
        ;
        check "PF";
    }
}


__DATA__
foo    -   ...   -  p
bar    -   ..    -  f
