package Test::Regexp::Test_Runner;

#
# A bunch of subroutines to help testing Test::Regexp
#

use 5.038;

use strict;
use warnings;
no  warnings 'syntax';

use Exporter ();
our @ISA    = qw [Exporter];
our @EXPORT = qw [run_code];

#
# Run a given piece of code in a child process. We'll be using 
# Test::More and Test::Regexp before running the code, and call
# done_testing () afterwards. We will return the output/errors.
#
# To get the errors, in the child, we close STDERR, then dub STDOUT
# as STDERR.
#
use POSIX qw [dup2];
sub run_code ($code) {
    my $pid = open (my $kid, "-|") // die "Failed to fork: $!";
    if (!$pid) {
        #
        # We're in the child.
        #

        #
        # Merge errors into standard output.
        #
        dup2 (fileno (STDOUT), fileno (STDERR)) // die "dup2 failed: $!";

        my $r = eval <<~ '--';
            use Test::More;
            use Test::Regexp;
            $code -> ();
            done_testing ();
            1;
        --
        die $@ unless $r;
        exit;
    }
    #
    # Read output
    #
    my $output = [<$kid>];
    chomp @$output;

    #
    # All children must be reaped, lest they become zombies.
    #
    waitpid $pid, 0;

    return $output;
}

__END__
