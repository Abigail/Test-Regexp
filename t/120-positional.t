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
    # A capture which isn't expected
    #
    {
        name  =>  "Unexpected capture",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '12(3)4',
        },
        exp   =>  "yy;y;n",
    },
    #
    # A capture which isn't expected, and an empty capture list
    #
    {
        name  =>  "Unexpected capture, with empty capture list",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '12(3)4',
            captures  =>  [],
        },
        exp   =>  "yy;y;n",
    },
    #
    # No captures, and an empty capture list
    #
    {
        name  =>  "Empty capture list",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '1234',
            captures  =>  [],
        },
        exp   =>  "yy;y;y",
    },
    #
    # Simple capture
    #
    {
        name  =>  "Empty capture list",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '12(3)4',
            captures  =>  ['3'],
        },
        exp   =>  "yy;y;yy",
    },
    #
    # Capture all
    #
    {
        name  =>  "Capture entire match",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '(1234)',
            captures  =>  ['1234'],
        },
        exp   =>  "yy;y;yy",
    },
    #
    # More than one capture
    #
    {
        name  =>  "Multiple captures",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '(1)23(4)',
            captures  =>  ['1', '4'],
        },
        exp   =>  "yy;y;yyy",
    },
    #
    # Nested captures
    #
    {
        name  =>  "Nested captures",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '1((2)3(4))',
            captures  =>  ['234', '2', '4'],
        },
        exp   =>  "yy;y;yyyy",
    },
    #
    # Wrong capture
    #
    {
        name  =>  "Wrong capture",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '12(3)4',
            captures  =>  ['2'],
        },
        exp   =>  "yy;y;yn",
    },
    #
    # Missing capture
    #
    {
        name  =>  "Missing expected capture",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '1(2)(3)(4)',
            captures  =>  ['2', '4'],
        },
        exp   =>  "yy;y;n",
    },
    #
    # Too many captures
    #
    {
        name  =>  "Too many expected captures",
        match =>  {
            subject   =>  '1234',
            pattern   =>  '1(2)3(4)',
            captures  =>  ['2', '3', '4'],
        },
        exp   =>  "yy;y;n",
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
