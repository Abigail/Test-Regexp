#!/usr/bin/perl

use strict;
use warnings;

use Test::More 0.88;
use Test::Regexp;

my $README  = "README";
my $CHANGES = "Changes";


foreach my $file ($README, $CHANGES) {
    open my $fh, "<", $file or do {
        plan skip_all => "Cannot open $file: $!";
        exit;
    };

    my $first_line = <$fh>;

    my ($version) = $first_line =~ /\b([0-9]{10})\b/;

    ok $version, "Got version from $file";
    is $version, $Test::Regexp::VERSION, "$file version matches library";
}

done_testing;

__END__
