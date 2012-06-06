#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";
use HTKUtil;
use Getopt::Long;

die "Usage: $0 --indir hmm0 --outdir hmm1 --conf htk/config1 --mlf trans.mlf --phones htk/monophones0 --mfcc 'train/*.mfcc' [--workdir /tmp] [--iter 9] [-t '250.0 150.0 1000.0']\n" if @ARGV == 0;

my %opt;

GetOptions(\%opt, qw(
    indir=s outdir=s workdir=s
    iter=i
    conf=s mlf=s phones=s
    mfcc=s
    t=s
));

hmmiter(%opt);
