#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [check $count $failures];

use 5.010;

our $VERSION = "2009033101";

use Test::Regexp tests  => 'no_plan',
                 import => [];

my $pattern2 = '(\w+)\s+(\w+)';
my $pattern3 = '(\w+)\s+(\w+)\s+(\w+)';

my $checker2 = Test::Regexp -> new -> init (
    keep_pattern => $pattern2,
);
my $checker3 = Test::Regexp -> new -> init (
    keep_pattern => $pattern3,
);

my @data = (
    ['PFPPPFF',  'PPPPPPP',  [qw [tripoline a punta]]],
    ['PPPPPP',   'FPPP',     [qw [cannarozzi rigati]]],
    ['PPPPPP',   'FPPP',     [qw [lumache grandi]]],
    ['PFPPPFFF', 'PFPPPPFF', [qw [lasagne festonate a nidi]]],
    ['PFPPPFF',  'PPPPPPP',  [qw [corni di bue]]],
);

foreach my $data (@data) {
    my $expected2 = shift @$data;
    my $expected3 = shift @$data;
    my $captures  = shift @$data;
    my $subject   = join ' ' => @$captures;

    my $r2 = $checker2 -> match ($subject, $captures);
    unless ($r2 && $expected2 !~ /[^P]/ ||
           !$r2 && $expected2 =~ /[^P]/) {
        print "not ";
        $failures ++;
    }
    say "ok ", ++ $count, " match() return value";
    check ($expected2, $subject, 1, $pattern2);

    my $r3 = $checker3 -> match ($subject, $captures);
    unless ($r3 && $expected3 !~ /[^P]/ ||
           !$r3 && $expected3 =~ /[^P]/) {
        print "not ";
        $failures ++;
    }
    say "ok ", ++ $count, " match() return value";

    check ($expected3, $subject, 1, $pattern3);
}


__END__
