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
use JulLib qw(evaluate_hmm);

my %opt = (
    iter => $ENV{EV_iter_triphones} || $ENV{EV_iter} || 2,
    'triphone-trees' => $ENV{EV_triphone_trees},
);

GetOptions( \%opt, qw(
    monophones=s
    triphones=s
    tiedlist=s
    fulllist=s
    indir=s
    outdir=s
    mfccdir=s
    conf=s
    tree-hed-tmpl=s
    triphone-questions=s
    triphone-trees=s
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
        qs         => $opt{'triphone-questions'},
        monophones => $opt{monophones},
        tiedlist   => $opt{tiedlist},
        fulllist   => $opt{fulllist},
        stats_fn   => "$opt{outdir}/stats",
        trees_fn   => $opt{'triphone-trees'},
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

    HTKUtil::iterate(
        ( map {$_ => $opt{$_}} qw(conf mlf) ),
        from =>"$opt{outdir}/0-nontied/reestd",
        to => "$opt{outdir}/0-nontied",
        scp_fn => "$opt{outdir}/0-nontied/iterations/mfcc.scp",
        t => $ENV{EV_HERest_t},
        extra_herest_options => {
            '-s' => "$opt{outdir}/stats",
        },
        parallel_cnt => $ENV{EV_HERest_p},
        thread_cnt => $ENV{EV_thread_cnt} || 1,
        workdir => "$opt{outdir}/0-nontied/iterations",
        phones => $opt{triphones},
    );
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
    last unless $ENV{EV_evaluate_steps};

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
