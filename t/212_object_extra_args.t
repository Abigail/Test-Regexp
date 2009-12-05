#!/usr/bin/perl

use strict;
use warnings;
no  warnings 'syntax';

use t::Common qw [check $count $comment $reason $line];

use 5.010;

use Test::Regexp tests  => 'no_plan',
                 import => [];

my $pattern = '\w+';

my $checker = Test::Regexp -> new -> init (
    pattern => $pattern,
    name    => "test",
);


my @fails = (["----"     => "dashes",],
             ["# foo"    => "comment"],
             ["foo\nbar" => "has a newline"]);

my $c = 0;
foreach my $fail (@fails) {
    my ($subject, $Reason) = @$fail;

    undef $reason;
    undef $comment;
    undef $line;

    my $r = $checker -> no_match ($subject, reason    => $Reason, 
                                            show_line => $c ++);
    print "not " unless $r;
    say "ok ", ++ $count, " no_match succeeded";

    unless (($reason // "") eq $Reason) {
        print "not ";
    }
    say "ok ", ++ $count, " correct reason found";
    unless (($comment // "") eq "test") {
        print "not ";
    }
    say "ok ", ++ $count, " correct comment found";

    if ($c == 1 && $line || $c > 1 && !$line) {
        print "not ";
    }
    say "ok ", ++ $count, " dealt with show_line correctly";
}

__END__
