package t::Common;

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

use Test::More;
use Exporter ();

our @EXPORT    = qw [check];
our @EXPORT_OK = qw [$count $comment $failures $reason $test $line];
our @ISA       = qw [Exporter];

my  $result    = "";
our $count     = 0;
our $failures  = 0;
our $comment;
our $reason;
our $test;
our $line;



sub check {
    my %arg = @_;

    my $results   = $arg {results};
    my $premature = $arg {premature};
    my $match_exp = $arg {match_exp} || 0;
    my $match_res = $arg {match_res} || 0;
    my $pattern   = $arg {pattern};
    my $expected  = $arg {expected};
    my $subject   = $arg {subject};
    my $comment   = $arg {comment}   // "";
    my $keep      = $arg {keep};
    
    my $op        = $match_exp ? "=~" : "!~";
    my $name      = qq {"$subject" $op /$pattern/};

    $expected = [split // => $expected] unless ref $expected;

    ok !$premature, "No preceeding garbage";

    #
    # Number of tests?
    #
    ok @$results == @$expected, "$name: number of tests";

    #
    # Correct return value from match?
    #
    ok +( $match_res && !grep {$_ eq 'F'} @$expected) ||
        (!$match_res &&  grep {$_ eq 'F'} @$expected), "$name: (no)match value";

    for (my $i = 0; $i < @$results; $i ++) {
        my $result  =  $$results  [$i];
        my $exp     =  $$expected [$i];
        my $ok      =  $$result {ok};
        my $comment =  $$result {name};
           $comment =~ s/^\s+//;
           $comment =  "Skipped" if $$result {type} eq 'skip';

        ok $ok && $exp =~ /[PS]/ ||
          !$ok && $exp =~ /[FS]/, "$name: sub-test ($comment)";
    }
    #
    # Check the name of the first test
    #
    my $test_name    = $$results [0] {name} // "";
    my $neg          = $match_exp ? "" : "not ";
    my $exp_comment  = qq {qq {$subject} ${neg}matched by "$comment"};
       $exp_comment .= " (with -Keep)" if $keep;

    is $test_name, $exp_comment, "Test name";
}
    
END {done_testing}


1;


__END__
