#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;
use Text::ParseWords qw(shellwords);

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil::AddMixtures;
use Evadevi::Util qw(cp);
use JulLib qw(evaluate_hmm);

my %opt;
GetOptions(\%opt, qw(
    indir=s
    outdir=s
    conf=s
    mfccdir=s
    wordlist=s
));

my @mixture_opt = shellwords($ENV{mixture_opt});

print STDERR (' ' x 8 ), "splitting...\n";
HTKUtil::AddMixtures::init(
    "--starthmm=$opt{indir}",
    "--outdir=$opt{outdir}",
    "--conf=$opt{conf}",
    '-a',
    @mixture_opt,
);
HTKUtil::AddMixtures::main();

cp("$opt{outdir}/winner/hmmdefs", "$opt{outdir}/hmmdefs");
cp("$opt{outdir}/winner/macros",  "$opt{outdir}/macros" );
cp("$opt{indir}/phones",          "$opt{outdir}/phones" );

print STDERR (' ' x 8 ), "evaluating...\n";
{
    my $score = JulLib::evaluate_hmm(
        ( map {; $_ => $opt{$_} } qw(conf mfccdir wordlist) ),
        hmmdir        => $opt{outdir},
        workdir       => $ENV{EV_eval_workdir},
        transcription => $ENV{EV_heldout_mlf},
        LMf           => $ENV{EV_LMf},
        LMb           => $ENV{EV_LMb},
    );
    print "$score->{raw}\n$score\n";
}
