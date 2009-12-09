#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [check $count $failures $comment];

use 5.010;

use Test::Regexp tests  => 'no_plan',
                 import => [];

my $pattern = '(\w+)\s+(\w+)';

my @checkers = (
    Test::Regexp -> new -> init (
        keep_pattern => $pattern,
        pattern      => '\w+\s+\w+',
        name         => 'US president',
    ),
    Test::Regexp -> new -> init (
        keep_pattern => $pattern,
        pattern      => '\w+\s+\w+',
        comment      => 'US president',
    ),
);

my @data = (
    ['PPPPPPPPPP',   [qw [Gerald Ford]]],
    ['PPPPPPPPPP',   [qw [Jimmy Carter]]],
);

foreach my $data (@data) {
    my $expected = shift @$data;
    my $captures = shift @$data;
    my $subject  = join ' ' => @$captures;

    undef $comment;

    foreach my $checker (@checkers) {
        my $r = $checker -> match ($subject, $captures);
        unless ($r && $expected !~ /[^P]/ ||
               !$r && $expected =~ /[^P]/) {
            print "not ";
            $failures ++;
        }
        say "ok ", ++ $count, " match() return value";

        check ($expected, $subject, 1, $pattern);

        unless (defined $comment && $comment eq 'US president') {
            print "not ";
            $failures ++;
        }
        say "ok ", ++ $count, " comment";
    }
}

__END__
