#!/usr/bin/perl

# Filters out sentences that are empty or contain silence only
# from a transcription in MLF format.
# Works in pipe mode

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);

my %phones_to_ignore = (
    sil => 1,
    sp => 1,
);

print scalar(<>);  # pass header through
{
    local $/ = "\n.\n";
    while (<>) {
        my ($header, @lines) = split /\n/;
        if (grep {/\w/ and not $phones_to_ignore{$_}} @lines) {
            print;
        }
    }
}
