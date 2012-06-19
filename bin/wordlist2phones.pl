#!/usr/bin/perl

# Gathers a set of phones from a phonetic dictionary.
# Works in pipe mode.
# If the EV_phones_count_file environment variable is set,
# then its content is interpreted as a filename to which
# counts of the phones are to be printed.

use strict;
use warnings;
use utf8;

my %phones = (sp => 0, sil => 0);

while (<>) {
    chomp;
    (undef, my @phones) = split /\s+/;
    $phones{$_}++ for @phones;
}

$\ = "\n";

print for sort keys %phones;

if ($ENV{EV_phones_count_file}) {{
    open my $phones_count_fh, '>', $ENV{EV_phones_count_file} or last;
    print {$phones_count_fh} "$_ $phones{$_}" for sort {$phones{$b} <=> $phones{$a}} keys %phones;
}}
