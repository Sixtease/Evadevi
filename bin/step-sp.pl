#!/usr/bin/perl

# Add the sp (short pause) model to HMMs.
# - derive the sp model from sil (duplicate)
# - tie some of their states
# (normally) second step in acoustic model training.

use strict;
use warnings;
use utf8;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil;
use Getopt::Long;
use JulLib qw(evaluate_hmm);

my $eh = $ENV{EV_homedir};
die "EV_homedir env var must be set" if not $eh;

my %opt = (
    iter => $ENV{EV_iter_sp} || $ENV{EV_iter} || 2,
);

GetOptions( \%opt, qw(
    indir=s
    outdir=s
    phones=s
    train-mlf=s
    conf=s
    iter=i
    mfccdir=s
));

{
    print STDERR (' ' x 8), "creating sp...\n";
    
    my $indir  = $opt{indir};
    my $outdir = "$opt{outdir}/base1-sp-added";
    
    local @ARGV = ("$indir/hmmdefs");
    my $stdout_fn = "$outdir/hmmdefs";
    local *STDOUT;
    open STDOUT, '>', $stdout_fn or die "Couldn't open '$stdout_fn' as STDOUT: $!";
    
    undef $!;
    undef $@;
    my $did = do "$PATH/DuplicateSilence.pl";
    
    die "DuplicateSilence failed: $@" if $@;
    die "DuplicateSilence failed: $!" if not defined $did;
}

{
    print STDERR (' ' x 8), "tying...\n";
    
    my $indir  = "$opt{outdir}/base1-sp-added";
    my $outdir = "$opt{outdir}/base2-sp-sil-tied";
    
    h(qq(HHEd -T 1 -A -D -H "$indir/macros" -H "$indir/hmmdefs" -M "$outdir" "${eh}resources/sil.hed" "$opt{phones}"));
}

{
    print STDERR (' ' x 8 ), "training...\n";
    
    my $indir   = "$opt{outdir}/base2-sp-sil-tied";
    my $outdir  = $opt{outdir};
    my $workdir = "$opt{outdir}/iterations";
    
    HTKUtil::hmmiter(
        ( map {; $_ => $opt{$_} } qw(iter conf mfccdir phones) ),
        mlf     => $opt{'train-mlf'},
        indir   => $indir,
        outdir  => $outdir,
        workdir => $workdir,
    );
}

{
    print STDERR (' ' x 8 ), "evaluating...\n";
    
    my $score = evaluate_hmm(
        ( map {; $_ => $opt{$_} } qw(conf mfccdir) ),
        hmmdir        => $opt{outdir},
        workdir       => $ENV{EV_eval_workdir},
        transcription => $ENV{EV_heldout_mlf},
        LMf           => $ENV{EV_LMf},
        LMb           => $ENV{EV_LMb},
        wordlist      => $ENV{EV_default_wordlist},
    );
    print "$score->{raw}\n$score\n";
}
