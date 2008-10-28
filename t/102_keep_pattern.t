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

sub init_data;

my $result = "";
my $count  = 0;
my @data   = init_data;

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
        print "## $mesg";
        given ($mesg) {
            when (/^ok/)     {$result .= "P"}
            when (/^not ok/) {$result .= "F"}
        }
    };
    #
    # Don't want to see diagnostics.
    #
    *{"Test::Builder::_print_diag"} = sub {
        my ($self, @msgs) = @_;
        my $mesg = join "" => @msgs;
        print "## $mesg";
        1;
    }
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
    say $tag, ++ $count, qq { TESTS_PASS, TESTS_FAIL and TESTS_SKIP};

    $result = "";
}

foreach my $data (@data) {
    ($subject, $pattern, my ($match, $result, $captures)) = @$data;

    $match_val = $match =~ /[ym1]/i;
    match subject       =>  $subject,
          keep_pattern  =>  $pattern,
          match         =>  $match_val,
          captures      =>  $captures;
    check $result;
}

#
# Data taken from 'meta state_flowers'
#

sub init_data {(
    # Match without captures.
    ['Rose',              qr {\w+},                   'y', 'PPPP', []],

    # Match with just numbered captures.
    ['Black Eyed Susan',  qr {(\w+)\s+(\w+)\s+(\w+)}, 'y', 'PPPPPPP',
      [qw [Black Eyed Susan]]],

    # Match with just named captures.
    ['Sego Lily',         qr {(?<a>\w+)\s+(?<b>\w+)}, 'y', 'PPPPPPPPPP',
      [[a => 'Sego'], [b => 'Lily']]],
)}


__END__
