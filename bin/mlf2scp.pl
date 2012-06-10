#!/usr/bin/perl

# Generates a list of wav and mfcc files for HCopy to use as master script.
# On stdin, a mlf (master label file) with transcription is expected.
# Arguments specify wildcard-like templates for the files in resulting list.
# An asterisk denotes the filestem. For example, to generate a list of lines
# like "audio/chunk0.wav mfcc/chunk0.mfcc", invoke the script like this:
# mlf2scp "audio/*.wav" "mfcc/*.mfcc" < trans.mlf
# Resulting list is printed to stdout.

use strict;
use warnings;
use utf8;
use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";
use HTKUtil;

die 'Directories of files for SCP list required' if @ARGV == 0;

{
    local $/ = '/';
    chomp @ARGV;
}

my $scp = '';
mlf2scp(*STDIN{IO}, \$scp, @ARGV);
print $scp;
