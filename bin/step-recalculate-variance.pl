#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use Evadevi::Util qw(cp);
use HTKUtil;
use HTKUtil::InitHmm qw(calculate_variance init_macros);

my %opt = (
    f => $ENV{EV_HCompV_f},
    iter => $ENV{EV_iter_var} || $ENV{EV_iter} || 2,
);
GetOptions(\%opt, qw(
    conf=s
    f=f
    indir=s
    outdir=s
    mfccdir=s
    mlf=s
    proto=s
    iter=i
));

my $scp_fn = "$opt{outdir}/aux/mfcc.scp";
mlf2scp($opt{mlf}, $scp_fn, "$opt{mfccdir}/*.mfcc");

print STDERR (' ' x 8), "calculating variance...\n";
calculate_variance(
    '-C' => $opt{conf},
    '-f' => $opt{f},
    '-S' => $scp_fn,
    '-M' => "$opt{outdir}/var",
    '-I' => $opt{mlf},
    ''   => $opt{proto},
);

init_macros("$opt{outdir}/var/proto", "$opt{outdir}/var/vFloors", "$opt{outdir}/base/macros");
cp("$opt{indir}/hmmdefs", "$opt{outdir}/base/hmmdefs");

print STDERR (' ' x 8), "training...\n";
hmmiter(
    ( map {;$_ => $opt{$_}} qw(iter outdir mfccdir conf mlf) ),
    indir => "$opt{outdir}/base",
    workdir => "$opt{outdir}/iterations",
    phones => "$opt{indir}/phones",
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

__END__
