#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";
use HTKUtil;
use Getopt::Long;

my %options;
GetOptions(\%options, qw(
    hmmdir=s
    workdir=s
    mfccdir=s
    conf=s
    LM=s
    wordlist=s
    phones=s
    transcription=s
));

my $score = evaluate_hmm(%options);
print "$score->{raw}\n$score\n";
