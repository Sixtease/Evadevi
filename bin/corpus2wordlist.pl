#!/usr/bin/perl

# Prints the list of words in sorted by occurrences and alphabetically.

use strict;
use warnings;
use utf8;

my %w;

while (<>) {
    for (split /\s+/) {
        $w{$_}++;
    }
}

print "$_\n" for sort {$w{$b} <=> $w{$a} or $a cmp $b} keys %w;
