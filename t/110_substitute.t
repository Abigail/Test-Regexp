#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 1.000;

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp';
}


match subject      => "%[lorem;id=foo]",
      name         => "Example",
      comment      => "Whatever",
      keep_pattern => qr /(?<one>.*)/,
      captures     => {
          one  =>  "%[foo]",
      },
      substitute   => 1,
      runs         => 2,
;
