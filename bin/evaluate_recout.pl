#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use utf8;
use File::Basename qw(dirname);
use Getopt::Long;

my $PATH;
BEGIN { $PATH = sub { dirname((caller)[1]) }->() }
use lib "$PATH/../lib";
use JulLib;

my $workdir = '.';
my $phones_fn;
my $label_transform = '';
GetOptions(
    'workdir=s' => \$workdir,
    'phones=s' => \$phones_fn,
    'label-transform=s' => \$label_transform,
);

my ($gold_mlf_fn, $recout_fn) = @ARGV;

die 'Missing --phones option' if not $phones_fn;
if ($label_transform) {
    $ENV{EV_label_transform} = $label_transform;
}

my $recout_mlf_fn = "$recout_fn.mlf";
if (-e $recout_mlf_fn) { } else {
    JulLib::recout_to_mlf(
        recout_fn => $recout_fn,
        mlf_out_fn => $recout_mlf_fn,
    );
}

my $score = JulLib::evaluate_recout(
    transcription => $gold_mlf_fn,
    workdir => $workdir,
    phones => $phones_fn,
    mlf_out_fn => $recout_mlf_fn,
);

print $score->{raw};
