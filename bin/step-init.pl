#!/usr/bin/perl

# 

use strict;
use warnings;
use utf8;
use Getopt::Long;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil;

my $workdir;
my %opt = (
    workdir => \$workdir,
);

GetOptions( \%opt, qw(
    workdir=s
    init-proto=s
    conf=s
    phones=s
    mfccdir=s
    iter=i
    train-mlf=s
    eval-workdir=s
    wordlist=s
    LM=s
    heldout-mlf=s
));

print STDERR (' ' x 8 ), "initializing...\n";
HTKUtil::init_hmm(
    ( map {; $_ => $opt{$_} } qw(f conf phones mfccdir) ),
    workdir   => "$workdir/aux",
    hmm_proto => $opt{'init-proto'},
    outdir    => "$workdir/base",
);

print STDERR (' ' x 8 ), "training...\n";
HTKUtil::hmmiter(
    ( map {; $_ => $opt{$_} } qw(iter conf mfccdir) ),
    mlf     => $opt{'train-mlf'},
    indir   => "$workdir/base",
    outdir  => $workdir,
    workdir => "$workdir/iterations",
);

print STDERR (' ' x 8 ), "evaluating...\n";
my $score = HTKUtil::evaluate_hmm(
    ( map {; $_ => $opt{$_} } qw(conf mfccdir LM wordlist) ),
    hmmdir        => $workdir,
    workdir       => $opt{'eval-workdir'},
    transcription => $opt{'heldout-mlf'},
);
print "$score->{raw}\n$score\n";
