#!/usr/bin/perl

# HLEd produces phonetic transcription from normal transcription and phonetic
# wordlist. When an empty sentence occurs, the phonetic transcription is also
# empty. It is desirable, however, to transcribe it with silence.
# This script takes on STDIN a phonetic transcription (.mlf) and sends it back
# to STDOUT with 'sil' added where an empty sentence occurs.

use strict;
use warnings;
use utf8;

$/ = ".";

while (<>) {
    s/"\n\./"\nsil\n./;
    print;
}
