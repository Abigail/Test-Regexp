package t::Common;

use strict;
use warnings;
no  warnings 'syntax';

use 5.010;

our $VERSION = "2009033101";

use Test::Builder ();
use Exporter ();

our @EXPORT    = qw [check];
our @EXPORT_OK = qw [$count $comment $failures $reason $line];
our @ISA       = qw [Exporter];

my  $result    = "";
our $count     = 0;
our $failures  = 0;
our $comment;
our $reason;
our $line;

END {
    Test::Builder::_my_exit ($failures > 254 ? 254 : $failures);
    no strict 'refs';
    no warnings 'redefine';
 *{"Test::Builder::_my_exit"} = sub {1;}
};
END {say "1..$count"}

{
    no strict 'refs';
    no warnings 'redefine';
    #
    # Intercept the 'ok' and 'not ok' prints, and remember the results.
    #
    *{"Test::Builder::_print"} = sub {
        my ($self, @msgs) = @_;
        my $mesg = join "" => @msgs;
        print "## $mesg";
        given ($mesg) {
            when (/^ok/)     {$result .= "P"}
            when (/^not ok/) {$result .= "F"}
        }
        if (!defined $comment && $mesg =~ /matched by "(.*)"/)   {
            $comment = $1;
        }
        if (!defined $reason  && $mesg =~ /\[Reason: (.*)\]/)    {
            $reason  = $1;
        }
        if (!defined $line    && $mesg =~ /\[([^]:]+:[0-9]+)\]/) {
            $line    = $1;
        }
    };
    #
    # Mark diagnostics.
    #
    *{"Test::Builder::_print_diag"} = sub {
        my ($self, @msgs)  = @_;
        my $mesg = join "" => @msgs;
        $mesg =~ s/^/   /mg;
        $mesg =~ s/^  /##/;
        print $mesg;
        1;
    }
}


sub check {
    my ($expected, $subject, $match_val, $pattern) = @_;
    my $tag      = "ok ";
    my $exp_pat  = $expected;
       $exp_pat  =~ s/S/P/g;
    my $pass     =  1;
    if ($result !~ /^$exp_pat$/) {
        say "# Got '$result'";
        say "# Expected '$expected'";
        $tag  = "not $tag";
        $pass =  0;
    }
    my $op = $match_val ? "=~" : "!~";
    say $tag, ++ $count, qq { "$subject" $op /$pattern/};
    $result = "";
    $failures ++ unless $pass;
    return $pass;
}


1;

__END__
