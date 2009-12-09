#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [check $count $failures];

use 5.010;

use Test::Regexp tests  => 'no_plan',
                 import => [];

my $pattern = '(\w+)\s+(\w+)';

my $checker = Test::Regexp -> new -> init (
    keep_pattern => $pattern,
    pattern      => '\w+\s+\w+',
);

my @data = (
    ['PPPPPPPPPP',   [qw [Gerald Ford]]],
    ['PPPPPPPPPP',   [qw [Jimmy Carter]]],
    ['PPPPPPPPPP',   [qw [Ronald Reagan]]],
    ['PFPPPFPPPFFF', [qw [George W H Bush]]],
    ['PPPPPPPPPP',   [qw [William Clinton]]],
);

foreach my $data (@data) {
    my $expected = shift @$data;
    my $captures = shift @$data;
    my $subject  = join ' ' => @$captures;

    my $r = $checker -> match ($subject, $captures);
    unless ($r && $expected !~ /[^P]/ ||
           !$r && $expected =~ /[^P]/) {
        print "not ";
        $failures ++;
    }
    say "ok ", ++ $count, " match() return value";

    check ($expected, $subject, 1, $pattern);
}

__END__
