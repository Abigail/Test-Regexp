#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp', import => [];
}


ok !defined &match,    "match () has not been exported ()";
ok !defined &no_match, "no_match () has not been exported ()";


__END__
