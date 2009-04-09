#!/usr/bin/perl

use 5.010;

use strict;
use warnings;
no  warnings 'syntax';

use ExtUtils::MakeMaker;

my %args = (
    NAME                 => 'Test::Regexp',
    VERSION_FROM         => 'lib/Test/Regexp.pm',
    ABSTRACT_FROM        => 'lib/Test/Regexp.pm',
    PREREQ_PM            => { },
    MIN_PERL_VERSION     =>  5.010,
    AUTHOR               => 'Abigail <test-regexp@abigail.be>',
    LICENSE              => 'mit',
    META_MERGE           => {
        resources        => {
            repository   => 'git://github.com/Abigail/test--regexp.git',
        },
        keywords         => [qw [ ]],
    },
);

my %filter = (
    MIN_PERL_VERSION     => '6.48',
    META_MERGE           => '6.46',
    AUTHOR               => '6.07',
    ABSTRACT_FROM        => '6.07',
    LICENSE              => '6.07',
);

delete $args {$_} for grep {defined $filter {$_} &&
                            $ExtUtils::MakeMaker::VERSION lt $filter {$_}}
                            keys %args;


WriteMakefile %args;

__END__
