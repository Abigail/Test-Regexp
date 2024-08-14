#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp', import => [qw [no_match]];
}


ok !defined &match,    "match () has not been exported ()";
ok  defined &no_match, "no_match () has been exported ()";


__END__
