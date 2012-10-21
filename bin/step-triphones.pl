#!/usr/bin/perl

# Convert to triphones

use strict;
use warnings;
use utf8;
use Getopt::Long;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil;
use HTKUtil::MkMkTriHed;
use HTKUtil::MkTreeHed;
use Evadevi::Util qw(stringify_options);

my %opt = (
    iter => $ENV{EV_iter_triphones} || $ENV{EV_iter} || 2,
);

GetOptions( \%opt, qw(
    monophones=s
    triphones=s
    tiedlist=s
    indir=s
    outdir=s
    mfccdir=s
    conf=s
    tree-hed-tmpl=s
    triphone-tree=s
    iter=i
    mlf=s
));

print STDERR (' ' x 8), "preparing...\n";
{
    mkmktrihed(
        $opt{monophones},
        "$opt{outdir}/0-nontied/base/mktri.hed",
        $opt{triphones},
    );
    
    mktreehed(
        tmpl_fn    => $opt{'tree-hed-tmpl'},
        qs         => $opt{'triphone-tree'},
        monophones => $opt{monophones},
        tiedlist   => "$opt{tiedlist}",
        stats_fn   => "$opt{outdir}/stats",
        out        => "$opt{outdir}/1-tied/base/tree.hed",
    );
    
    my @hhed_options = (
        ''   => 'HHEd',
        '-A' => '', '-D' => '', '-T' => 1,
        '-H' => [ "$opt{indir}/macros", "$opt{indir}/hmmdefs" ],
        '-M' => "$opt{outdir}/0-nontied/base",
        ''   => [ "$opt{outdir}/0-nontied/base/mktri.hed", $opt{monophones} ],
    );
    h(stringify_options(@hhed_options), LANG => 'C');
}

print STDERR (' ' x 8), "training nontied...\n";
{
    hmmiter(
        ( map {$_ => $opt{$_}} qw(iter mfccdir conf mlf) ),
        indir => "$opt{outdir}/0-nontied/base",
        outdir => "$opt{outdir}/0-nontied/reestd",
        workdir => "$opt{outdir}/0-nontied/iterations",
        phones => $opt{triphones},
    );
    
    my @herest_options = (
        ''   => 'HERest',
        '-A' => '', '-D' => '', '-T' => 1,
        '-C' => $opt{conf},
        '-I' => $opt{mlf},
        '-t' => {
            val => $ENV{EV_HERest_t},
            no_quotes => 1,
        },
        '-s' => "$opt{outdir}/stats",
        '-S' => "$opt{outdir}/0-nontied/iterations/mfcc.scp",
        '-H' => [ "$opt{outdir}/0-nontied/reestd/macros", "$opt{outdir}/0-nontied/reestd/hmmdefs" ],
        '-M' => "$opt{outdir}/0-nontied",
        '' => $opt{triphones},
    );
    h(stringify_options(@herest_options));
}

print STDERR (' ' x 8 ), "tying...\n";
{
    my @hhed_options = (
        ''   => 'HHEd',
        '-A' => '', '-D' => '', '-T' => 1,
        '-H' => [ "$opt{outdir}/0-nontied/macros", "$opt{outdir}/0-nontied/hmmdefs" ],
        '-M' => "$opt{outdir}/1-tied/base",
        ''   => [ "$opt{outdir}/1-tied/base/tree.hed", $opt{triphones} ],
    );
    h(stringify_options(@hhed_options), LANG => 'C');
}

print STDERR (' ' x 8 ), "training tied...\n";
{
    hmmiter(
        ( map {$_ => $opt{$_}} qw(iter mfccdir conf mlf) ),
        indir => "$opt{outdir}/1-tied/base",
        outdir => $opt{outdir},
        workdir => "$opt{outdir}/1-tied/iterations",
        phones => $opt{tiedlist},
    );
}

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
