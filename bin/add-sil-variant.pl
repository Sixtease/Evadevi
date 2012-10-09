#!/usr/bin/perl

# To a phonetic dictionary, where words are terminated with 'sp',
# adds a variant where 'sil' is the terminator instead of 'sp'.
# Works in pipe mode.

use strict;
use warnings;
use utf8;

while (<>) {
    print;
    s/ sp$/ sil/ and print;
}
