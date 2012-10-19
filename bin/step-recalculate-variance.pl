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
);
GetOptions(\%opt, qw(
    conf=s
    f=f
    indir=s
    workdir=s
    outdir=s
    mfccdir=s
    mlf=s
    proto=s
));

my $scp_fn = "$opt{workdir}/mfcc.scp";
mlf2scp($opt{mlf}, $scp_fn, "$opt{mfccdir}/*.mfcc");

calculate_variance(
    '-C' => $opt{conf},
    '-f' => $opt{f},
    '-S' => $scp_fn,
    '-M' => $opt{workdir},
    '-I' => $opt{mlf},
    ''   => $opt{proto},
);

init_macros($opt{proto}, "$opt{workdir}/vFloors", "$opt{outdir}/macros");
cp("$opt{indir}/hmmdefs", "$opt{outdir}/hmmdefs");

__END__
