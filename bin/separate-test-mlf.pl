#!/usr/bin/perl

# WIP and probably dead end

# Splits a transcription, separating test data as defined by env variables
# MAKONFM_TEST_TRACKS (list of test track stems),
# MAKONFM_TEST_START_POS (sentences starting sooner than this are not in test data)
# MAKONFM_TEXT_END_POS (sentences starting later than this neither)
# Train and test output files are given by env variables
# EV_train_transcription and
# EV_test_transcription
# Parameters are the input transcriptions to split

use strict;
use warnings;
use utf8;

my $train_fn = $ENV{EV_train_transcription};
my $test_fn = $ENV{EV_test_transcription};

my @targets = ($train_fn, $test_fn);

ARG:
for my $fn (@targets) {
    open my $fh, '>', $fn or die "Couldn't open target '$fn': $!";
    print {$fh} "#!MLF!#";
}

my %had_newline = (train => 0, test => 0);

$/ = qq{\n"};

my $i = 0;
SENTENCE:
while (<>) {
    chomp;
    next SENTENCE if /#!MLF!#/;
    print {$targets[$i]} qq{\n"$_};
    $had_newline[$i] = (substr($_, -1) eq '\n');
    $i++;
    $i %= @targets;
}

print {$_} "\n" for map $targets[$_], grep !$had_newline[$_], 0 .. $#targets;
