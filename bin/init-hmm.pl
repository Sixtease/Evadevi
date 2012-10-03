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

my $f = 0.01;
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

my $mfcc_glob = "$mfcc_dir/*";
my $scp_fn = "$workdir/mfcc.scp";

HTKUtil::generate_scp($scp_fn, $mfcc_glob);

my $error = system(qq(H HCompV -T 1 -A -D -C "$htk_config_fn" -f "$f" -m -S "$scp_fn" -M "$workdir" "$hmm_proto_fn"));
die "HCompV failed: $!" if $error;

makehmmdefs("$hmm_proto_fn", "$workdir/vFloors", $monophones_fn, $outdir);

link($monophones_fn, "$outdir/phones");

sub makehmmdefs {
    my ($proto_fn, $vFloors_fn, $monophones_fn, $outdir) = @_;
    
    open my $proto_fh,      '<', $proto_fn      or die "Couldn't open proto '$workdir/proto' for reading: $!";
    open my $vFloors_fh,    '<', $vFloors_fn    or die "Couldn't open vFloors '$workdir/vFloors' for reading: $!";
    open my $monophones_fh, '<', $monophones_fn or die "Couldn't open monophones: '$monophones_fn' for reading: $!";
    
    my @proto = <$proto_fh>;
    my @monophones = <$monophones_fh>;
    chomp @monophones;
    
    open my $macros_fh, '>', "$outdir/macros" or die "Couldn't open '$outdir/macros' for writing: $!";
    print {$macros_fh} @proto[0 .. 2];
    print {$macros_fh} <$vFloors_fh>;
    close $macros_fh;
    
    open my $hmmdefs_fh, '>', "$outdir/hmmdefs" or die "Couldn't open '$outdir/hmmdefs' for writing: $!";
    splice @proto, 0, 3;
    my $proto = join('', @proto);
    print {$hmmdefs_fh} "\n";
    for my $monophone (@monophones) {
        (my $hmmdef = $proto) =~ s/proto/$monophone/g;
        print {$hmmdefs_fh} $hmmdef;
    }
    close $hmmdefs_fh;
    
    close $proto_fh;
    close $vFloors_fh;
    close $monophones_fh;
}
