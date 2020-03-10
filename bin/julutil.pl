#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use 5.010;

# KenLM orders tokens by latest which confuses julius
package LmSort;
sub sort_lm {
    while (<>) {
        print;
        ngrams() if /-grams:/
    }
}
sub ngrams {
    my @grams;
    while (<>) {
        last if /^$/;
        # score1 \t token1 \t token2 \t score2 => token1 \t token2 \t score2 \t score1
        chomp;
        push @grams, join(';;;', (split /\t/, $_, 2)[1, 0]);
    }
    my $sep = $_;
    say join("\t", (split /;;;/)[1, 0]) for sort @grams;
    print $sep;
}

package main;
my $command = shift;
if ($command eq 'sort_lm') {
    LmSort::sort_lm();
}
else {
    die "unknown command '$command'";
}
