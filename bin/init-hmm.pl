#!/usr/bin/perl

# Bootstraps a HMM from a HMM prototype.
#
# Parameter 1 is path to the HMM prototype.
# Parameter 2 is path to HTK config.
# Parameter 3 is path to monophones list (without 'sp').
# Parameter 4 is a wildcard that expands to the list of training MFCC files.
# Parameter 5 is the output directory.
#
# Recognized options:
# -h: display usage and exit;
# -f: The -f option to HCompV; see HTK manual for details; defaults to 0.01;
# -t: Temp directory, where intermediate files will be stored;
#
# Expects HTK commands to be in $PATH.

use strict;
use warnings;
use utf8;
use Getopt::Long;
use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";
use HTKUtil;

my $usage = "USAGE: $0 [-h] [-f 0.01] [-t /tmp] hmms/proto HTK/config1 data/monophones0 data/train/*.mfcc output_dir\n";

die $usage if @ARGV == 0;

my $f;
my $help;
my $workdir = '/tmp';

GetOptions(
    'f=f' => \$f,
    h => \$help,
    't=s' => \$workdir,
);

my ($hmm_proto_fn, $htk_config_fn, $monophones_fn, $mfcc_dir, $outdir) = @ARGV;

if ($help) {
    print $usage;
    exit(0)
}

HTKUtil::init_hmm(
	f         => $f,
	workdir   => $workdir,
	hmm_proto => $hmm_proto_fn,
	conf      => $htk_config_fn,
	phones    => $monophones_fn,
	mfccdir   => $mfcc_dir,
	outdir 	  => $outdir,
);
