#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

use lib ".";

use Test::Regexp::Test_Runner;

my @tests = (
    {
        name  =>  "Simple",
        match =>  {subject   =>  'Dagr',
                   pattern   =>  '....'},
        exp   =>  "yy;y;y",
    },
    {
        name  =>  "Positional",
        match =>  {subject   =>  "Hello",
                   pattern   =>  '(..)(.)(..)',
                   captures  => ['He', 'l', 'lo']},
        exp   =>  "yy;y;yyyy",
    },
    {
        name  =>  "Named",
        match =>  {subject   =>  'Kvasir',
                   pattern   =>  '(?<foo>..)(?<bar>..)(?<foo>..)',
                   captures  =>  [[foo => 'Kv'], [bar => 'as'], [foo => 'ir']]},
        exp   =>  "yy;yyyyyy;yyyy",
    },
);

my $do_this = qr /Named/;

foreach my $test (@tests) {
    next unless $$test {name} =~ $do_this;
    my $test_name  = $$test {name};
    my $match_args = $$test {match};
    my $output     = run_code sub {Test::Regexp::match (%$match_args)};
  # my $output_oo  = run_code sub {Test::Regexp::match::
  #                                -> new
  #                                -> init (pattern => $$match_args {pattern})
  #                                -> match ($$match_args {subject})};
    $$test {output}    = $output;
  # $$test {output_oo} = $output_oo;
    say "OUT: $_" for @$output;
    say "------";
}

require Test::Regexp::Test_Checker;
Test::Regexp::Test_Checker:: -> import ();
foreach my $test (@tests) {
    next unless $$test {name} =~ $do_this;
    run_tests (%$test);
}


__END__


while (<DATA>) {
    chomp;
    m {^\h* (?|"(?<subject>[^"]*)"|(?<subject>\S+))
        \h+ (?|/(?<pattern>[^/]*)/|(?<pattern>\S+))
        \h+ (?<match>(?i:[ymn01]))
        \h+ (?<result>[PFS]+)
        \h* (?:$|\#)}x or next;
    my ($subject, $pattern, $match, $expected) =
        @+ {qw [subject pattern match result]};

    my $match_val = $match =~ /[ym1]/i;

    my $match_res;
    
    $match_res = match subject  =>  $subject,
                       pattern  =>  $pattern,
                       match    =>  $match_val;
}


#
# Names in the __DATA__ section come from 'meta norse_mythology'.
#

__DATA__
Dagr          ....       y   PPPP
Kvasir        Kvasir     y   PPPP
Snotra        \w+        y   PPPP
Sjofn         \w+        n   F     # It matches, so a no_match should fail
Borr          Bo         y   PFSS  # Match is only partial
Magni         Sigyn      y   FSSS  # Fail, then a skip
Andhrimnir    Delling    n   P     # Doesn't match, so a pass
Hlin          .(.)..     y   PPFP  # Sets a capture, so should fail
Od            (?<l>.*)   y   PPFF  # Sets a capture, so should fail
