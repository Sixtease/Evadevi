#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";
use HTKUtil;
use JulLib qw(evaluate_hmm);
use Getopt::Long;

my $print_brief = 0;
my %options = (
    b => \$print_brief,
);
GetOptions(\%options, qw(
    b
    hmmdir=s
    scoredir=s
    workdir=s
    mfccdir=s
    conf=s
    LMf=s
    LMb=s
    wordlist=s
    phones=s
    transcription=s
    t=s
    p=s
    s=s
));

my $score = evaluate_hmm(%options);
if ($print_brief) {
    print "$score\n";
}
else {
    print "$score->{raw}\n$score\n";
}
