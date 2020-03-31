#!/usr/bin/perl

# Splits a transcription in MLF format to several MLF files in desired ratio.
# The target files are passed as parameters immediately followed by an equal
# character and the ratio number. Any other parameters are interpreted as
# source MLF files that are to be concatenated and split.
# For example, to join all .mlf files in current directory and split them
# to train / test / heldout data in ratio 8:1:1, say:
# split-mlf.pl train.mlf=8 test.mlf=1 heldout.mlf=1 *.mlf

use strict;
use warnings;
use utf8;

my @targets;
my @argv;

ARG:
for (@ARGV) {
    my ($fn, $points) = m/(.+)=(\d+)/;
    if (not $fn) {
        push @argv, $_;
        next ARG
    }
    open my $fh, '>', $fn or die "Couldn't open target '$fn': $!";
    print {$fh} "#!MLF!#";
    push @targets, $fh for 1 .. $points;
}

if (not @targets) {
    die "Usage: $0 train.mlf=9 heldout.mlf=1 all.mlf\n"
}

my @had_newline = map 0, @targets;

@ARGV = @argv;

$/ = qq{\n"};

my $i = 0;
SENTENCE:
while (<>) {
    chomp;
    next SENTENCE if /#!MLF!#/;
    print {$targets[$i]} qq{\n"$_};

    my $chomped = $_;
    chomp $chomped;
    $had_newline[$i] = (length $_ == length $chomped);

    $i++;
    $i %= @targets;
}

print {$_} "\n" for map $targets[$_], grep !$had_newline[$_], 0 .. $#targets;
