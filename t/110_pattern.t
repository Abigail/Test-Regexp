#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [check $count $failures];

use 5.010;

our $VERSION = "2009033101";


use Test::Regexp tests => 'no_plan';


while (<DATA>) {
    chomp;
    m {^\h* (?|"(?<subject>[^"]*)"|(?<subject>\S+))
        \h+ (?|/(?<pattern>[^/]*)/|(?<pattern>\S+))
        \h+ (?<match>(?i:[ymn01]))
        \h+ (?<result>[PFS]+)
        \h* (?:$|\#)}x or next;
    my ($subject, $pattern, my ($match, $expected)) =
        @+ {qw [subject pattern match result]};

    my $match_val = $match =~ /[ym1]/i;
    my $r = match subject  =>  $subject,
                  pattern  =>  $pattern,
                  match    =>  $match_val;

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
Dagr          ....       y   PPP
Kvasir        Kvasir     y   PPP
Snotra        \w+        y   PPP
Sjofn         \w+        n   F     # It matches, so a no_match should fail
Borr          Bo         y   PFP   # Match is only partial
Magni         Sigyn      y   FSS   # Fail, then a skip
Andhrimnir    Delling    n   P     # Doesn't match, so a pass
Hlin          .(.)..     y   PPF   # Sets a capture, so should fail
Od            (?<l>.*)   y   PPF   # Sets a capture, so should fail
