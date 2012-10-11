#!/usr/bin/perl

# do forced alignment on the current models with a threshold
# to achieve two results:
# 1) filter out weird training sentences (the forced alignment will fail on them),
# 2) select the best pronunciation variant for each transcribed word

use strict;
use warnings;
use utf8;
use Getopt::Long;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil;
use Evadevi::Util qw(stringify_options);

my %opt;

GetOptions( \%opt, qw(
    indir=s
    outdir=s
    mfccdir=s
    train-mlf=s
    out-mlf=s
    tempdir=s
    conf=s
    align-workdir=s
    align-wordlist=s
    phones=s
    iter=i
));

print STDERR (' ' x 8), "aligning...\n";
{
    my $workdir = $opt{'align-workdir'};
    mlf2scp(
        $opt{'train-mlf'}, 
        "$opt{tempdir}/train-mfc.scp",
        "$opt{mfccdir}/*.mfcc",
    );
    my %hvite_opt = (
        '-T' => 1, '-A' => '', '-D' => '', '-l' => '*',
        '-m' => '', '-a' => '', '-o' => 'SWT', '-b' => 'silence',
        '-C' => $opt{conf},
        '-t' => $ENV{EV_HVite_t}, '-y' => 'lab',
        '-H' => ["$opt{indir}/macros", "$opt{indir}/hmmdefs"],
        '-S' => "$workdir/train-mfc.scp",
        '-i' => "$workdir/trancription-aligned-with-empty.mlf",
        '-I' => $opt{'train-mlf'},
    );
    my @hvite_arg = ($opt{'align-wordlist'}, $opt{phones});
    HTKUtil::hvite_parallel(
        \%hvite_opt, \@hvite_arg,
        workdir => $workdir,
    );
    
    HTKUtil::remove_empty_sentences_from_mlf(
        "$workdir/trancription-aligned-with-empty.mlf",
        "$workdir/trancription-aligned-without-empty.mlf",
    );

    my @hled_options = (
        '' => 'HLEd',
        '-A' => '',
        '-D' => '',
        '-T' => 1,
        '-l' => '*',
        '-i' => $opt{'out-mlf'},
        '' => "$ENV{EV_homedir}resources/squeeze-sil.led",
        '' => "$workdir/trancription-aligned-without-empty.mlf",
    );
    h(stringify_options(@hled_options));
}

print STDERR (' ' x 8), "training...\n";
hmmiter(
    ( map {;$_ => $opt{$_}} qw(iter indir outdir mfccdir conf phones) ),
    workdir => "$opt{outdir}/iterations",
    mlf => $opt{'out-mlf'},
);

print STDERR (' ' x 8 ), "evaluating...\n";
{
    my $score = HTKUtil::evaluate_hmm(
        ( map {; $_ => $opt{$_} } qw(conf mfccdir) ),
        hmmdir        => $opt{outdir},
        workdir       => $ENV{EV_eval_workdir},
        transcription => $ENV{EV_heldout_mlf},
        LM            => $ENV{EV_LM},
        wordlist      => $ENV{EV_default_wordlist},
    );
    print "$score->{raw}\n$score\n";
}
