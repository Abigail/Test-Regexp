#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

#
# Test some matches without captures
#

use Test::Regexp::Test_Runner;

my @tests = (
    #
    # The most simple test, when the subject and pattern are the same,
    # and do not contain special characters.
    #
    {
        name  =>  "Exact match",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '1234',
        },
        exp   =>  "yy;y;y",
    },
    #
    # A pattern with special characters.
    #
    {
        name  =>  "Dot star",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '.*',
        },
        exp   =>  "yy;y;y",
    },
    #
    # A pattern which doesn't match at all.
    #
    {
        name  =>  "Does not match",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '4321',
        },
        exp   =>  "n",
    },
    #
    # The pattern matches, but not completely.
    #
    {
        name  =>  "Partial match",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '123',
        },
        exp   =>  "yn",
    },
    #
    # A pattern which would match if anchored, but will not
    # without an anchor.
    #
    {
        name  =>  "No anchor",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '12[0-9]+?',
        },
        exp   =>  "yn",
    },
    #
    # A pattern which matches due to its anchor
    #
    {
        name  =>  "End anchor",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '12[0-9]+?$',
        },
        exp   =>  "yy;y;y",
    },
    #
    # A lead anchor should not confuse the test
    #
    {
        name  =>  "Start anchor",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '^.*4',
        },
        exp   =>  "yy;y;y",
    },
);


foreach my $test (@tests) {
    my $test_name  = $$test {name};
    my $match_args = $$test {match};
    my $output     = run_code sub {Test::Regexp::match (%$match_args)};
    my $output_oo  = run_code sub {Test::Regexp::match::
                                   -> new
                                   -> init (pattern => $$match_args {pattern})
                                   -> match ($$match_args {subject})};
    $$test {output}    = $output;
    $$test {output_oo} = $output_oo;
}

require Test::Regexp::Test_Checker;
Test::Regexp::Test_Checker:: -> import ();
foreach my $test (@tests) {
    run_tests (%$test);
}


__END__
