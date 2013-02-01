#!/usr/bin/perl

# Initialize HMM from data.
# - compute variance and flat-start the HMMs;
# - do a series of training iterations;
# - evaluate the result;
# (normally) first step in acoustic model training

use strict;
use warnings;
use utf8;
use Getopt::Long;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil;
use HTKUtil::InitHmm;
use JulLib qw(evaluate_hmm);

my $workdir;
my %opt = (
    workdir => \$workdir,
    iter => $ENV{EV_iter_init} || $ENV{EV_iter} || 2,
);

GetOptions( \%opt, qw(
    workdir=s
    init-proto=s
    conf=s
    phones=s
    mfccdir=s
    iter=i
    train-mlf=s
));

print STDERR (' ' x 8 ), "initializing...\n";
HTKUtil::InitHmm::init_hmm(
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
my $score = evaluate_hmm(
    ( map {; $_ => $opt{$_} } qw(conf mfccdir) ),
    hmmdir        => $workdir,
    workdir       => $ENV{EV_eval_workdir},
    transcription => $ENV{EV_heldout_mlf},
    LMf           => $ENV{EV_LMf},
    LMb           => $ENV{EV_LMb},
    wordlist      => "$ENV{EV_workdir}/test-unk-nosp-phonet",
);
print "$score->{raw}\n$score\n";
