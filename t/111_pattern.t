#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [check $count $failures];

use 5.010;

use Test::Regexp tests => 'no_plan';


while (<DATA>) {
    chomp;
    m {^\h* (?|"(?<subject>[^"]*)"|(?<subject>\S+))
        \h+ (?|/(?<pattern>[^/]*)/|(?<pattern>\S+))
        \h+ (?<number>[0-9]+)
        \h+ (?<name>[0-9]+)
        \h+ (?<match>(?i:[ymn01]))
        \h+ (?<result>[PFS]+)
        \h* (?:$|\#)}x or next;
    my ($subject, $pattern, $match, $expected, $nums, $names) =
        @+ {qw [subject pattern match result number name]};

    my $match_val = $match =~ /[ym1]/i;
    my $r = match subject              =>  $subject,
                  pattern              =>  $pattern,
                  match                =>  $match_val,
                  ghost_num_captures   =>  $nums,
                  ghost_name_captures  =>  $names,
    ;

    unless ($r && $expected !~ /[^P]/ ||
           !$r && $expected =~ /[^P]/) {
        print "not ";
        $failures ++;
    }
    say "ok ", ++ $count, " match() return value";

    check ($expected, $subject, $match_val, $pattern);
}


#
# Names in the __DATA__ section come from 'meta norse_mythology'.
#

__DATA__
Hodr          .+             0 0 y PPPP
Magni         .(.)...        1 0 y PPPP    #  Ghost capture.
Frigg         .(.).(.).+     2 0 y PPPP    #  Double capture.
Heimdall      .((.)).+       2 0 y PPPP    #  Nested capture.
Ran           .(?<l>.).      0 1 y PPPP    #  Ghost named capture.
Elli          .(.)(?<l>.).   1 1 y PPPP    #  Both numbered and named capture.
