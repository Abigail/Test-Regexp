#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 1.000;

use Test::More 'no_plan';

BEGIN {
    use_ok 'Test::Regexp';
}


match subject      => "1234",
      name         => "Example",
      comment      => "Whatever",
      pattern      => qr /[1-4]+/,
      keep_pattern => qr /(?<one>12)(?<two>34)/,
      captures     => {
          one  =>  '12',
          two  =>  '34',
      },
;
