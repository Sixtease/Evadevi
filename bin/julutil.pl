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

package RecoutAggr;

use Encode qw(decode encode_utf8);
my $enc = $ENV{EV_encoding};

sub aggregate {
    my $part_length_seconds = shift;
    my $last_file = '';
    my $offset = -$part_length_seconds;
    while (<>) {
        if ($ARGV ne $last_file) {
            $offset += $part_length_seconds;
            $last_file = $ARGV;
        }
        next if not /-- word alignment --/ .. /=== end forced alignment ===/;
        my $str = decode $enc, $_;

        # cs as in centiseconds
        my ($start_cs, $end_cs, $word_uc) = $str =~ /\[\s*(\d+)\s+(\d+)\s*\]\s+\S+\s+(\S+)/ or next;
        my $start = $offset + $start_cs / 100;
        my $end = $offset + $end_cs / 100;
        my $word = lc $word_uc;

        next if $word =~ /</;

        say encode_utf8 "$start $end $word";
    }
}

package main;
my $command = shift;
if ($command eq 'sort_lm') {
    LmSort::sort_lm();
}
elsif ($command eq 'aggregate-julout') {
    my $part_length_seconds = shift;
    RecoutAggr::aggregate($part_length_seconds);
}
else {
    die "unknown command '$command'";
}
