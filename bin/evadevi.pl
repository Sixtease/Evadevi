#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;

my %opt;
GetOptions( \%opt, qw(
    train-mfcc=s
    train-wordlist=s
    train-transcription=s
    test-wordlist=s
    lm=s
    monophones-only|m
    homedir=s
    workdir=s
    outdir=s
    heldout-ratio=i
    min-mixtures=i
));

$ENV{EV_train_mfcc}            = $opt{'train-mfcc'}          if $opt{'train-mfcc'};
$ENV{EV_wordlist_train_phonet} = $opt{'train-wordlist'}      if $opt{'train-wordlist'};
$ENV{EV_train_transcription}   = $opt{'train-transcription'} if $opt{'train-transcription'};
$ENV{EV_wordlist_test_phonet}  = $opt{'test-wordlist'}       if $opt{'test-wordlist'};
$ENV{EV_LM}                    = $opt{lm}                    if $opt{lm};

die '--train-mfcc option must specify a directory with training audio data in MFCC format; the files must end with .mfcc'
    if not -d $ENV{'EV_train_mfcc'};
die '--train-wordlist option must specify a file with phonetic training dictionary' if not -e $ENV{'EV_wordlist_train_phonet'};
die '--train-transcription option must specify a file with training transcription in HTK MLF format'
    if not -e $ENV{'EV_train_transcription'};
die '--test-wordlist option must specify a file with phonetic dictionary for testing' if not -e $ENV{'EV_wordlist_test_phonet'};
die '--lm option must specify a file with language model in HTK lattice format' if not -e $ENV{EV_LM};

$ENV{EV_heldout_ratio}         = $opt{'heldout-ratio'}       if $opt{'heldout-ratio'};
$ENV{EV_min_mixtures}          = $opt{'min-mixtures'}        if $opt{'min-mixtures'};

if ($opt{'monophones-only'}) {
    $ENV{EV_use_triphones} = '';
}
elsif (not defined $ENV{EV_use_triphones}) {
    $ENV{EV_use_triphones} = '1';
}

$ENV{EV_homedir} ||= $opt{homedir};
if (not $ENV{EV_homedir}) {
    use File::Basename;
    my $PATH = sub { dirname( (caller)[1] ) }->();
    $ENV{EV_homedir} = "$PATH/../";
}
my $homedir = $ENV{EV_homedir};
die "--homedir option must specify the directory where Evadevi (Makefile, config.sh and resources) resides"
    if not -d $homedir or not -e "$homedir/Makefile" or not -e "$homedir/config.sh" or not -d "$homedir/resources";

$ENV{EV_outdir}  ||= $opt{outdir};
$ENV{EV_workdir} ||= $opt{workdir};

s{/?$}{/} for grep $_, @ENV{qw(homedir outdir workdir)};

system(qq(. "$homedir/config.sh"; make -f "$homedir/Makefile" train));

__END__

=head1 NAME

Evadevi -- a chain of scripts to train HTK acoustic models from transcribed speech

=head1 SYNOPSIS

    evadevi.pl [-m] --train-mfcc data/mfcc/train/ \
    --train-wordlist data/wordlist/train-phonet \
    --train-transcription data/transcription/train.mlf \
    --test-wordlist data/wordlist/test-phones \
    --lm data/language-model/bigram.lat \
    --homedir ~/Evadevi/ [--outdir hmms/] [--workdir temp/]
