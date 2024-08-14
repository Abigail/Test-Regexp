#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp';
}


ok  defined &match,    "match () has been exported ()";
ok  defined &no_match, "no_match () has been exported ()";


__END__
