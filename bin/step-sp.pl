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

my $eh = $ENV{EV_homedir};
die "EV_homedir env var must be set" if not $eh;

my %opt;

GetOptions( \%opt, qw(
    indir=s
    outdir=s
    phones=s
    train-mlf=s
    conf=s
    iter=i
    mfccdir=s
    eval-workdir=s
    heldout-mlf=s
    wordlist=s
    LM=s
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
    
    my $hmmdir  = $opt{outdir};
    my $workdir = $opt{'eval-workdir'};
    
    my $score = HTKUtil::evaluate_hmm(
        ( map {; $_ => $opt{$_} } qw(conf mfccdir LM wordlist) ),
        hmmdir        => $hmmdir,
        workdir       => $workdir,
        transcription => $opt{'heldout-mlf'},
    );
    print "$score->{raw}\n$score\n";
}
