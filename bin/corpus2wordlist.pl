#!/usr/bin/perl

# Prints the list of words in sorted by occurrences and alphabetically.
# The env var EV_word_blacklist specified a filename with a list of words
# that will be penalized and sorted at the end.

use strict;
use warnings;
use utf8;

my %w;

while (<>) {
    for (split /\s+/) {
        $w{$_}++;
    }
}

my %blacklist;
if (-e $ENV{EV_word_blacklist}) {
    local @ARGV = $ENV{EV_word_blacklist};
    for (<ARGV>) {
        chomp;
        $blacklist{$_} = 1;
    }
}

print "$_\n" for sort {
    ($blacklist{$a}||0) <=> ($blacklist{$b}||0)
    or $w{$b} <=> $w{$a}
    or $a cmp $b
} keys %w;
