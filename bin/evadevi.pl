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

$ENV{EV_homedir} = $opt{homedir} if $opt{homedir};
if (not $ENV{EV_homedir}) {
    use File::Basename;
    my $PATH = sub { dirname( (caller)[1] ) }->();
    $ENV{EV_homedir} = "$PATH/../";
}
my $homedir = $ENV{EV_homedir};
die "--homedir option must specify the directory where Evadevi (Makefile, config.sh and resources) resides"
    if not -d $homedir or not -e "$homedir/Makefile" or not -e "$homedir/config.sh" or not -d "$homedir/resources";

$ENV{EV_outdir}  = $opt{outdir}  if $opt{outdir};
$ENV{EV_workdir} = $opt{workdir} if $opt{workdir};

s{/?$}{/} for grep $_, @ENV{qw(EV_homedir EV_outdir EV_workdir)};

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

=head1 DESCRIPTION

Evadevi trains a HMM from transcribed data. It currently operates only with
MFCC-encoded audio files and only trains monophone models.

The model is trained in five steps:

=over 4

=item 1. Initialization

The model is initialized from global data variance

=item 2. Short pause

The short pause (C<sp>) model is added based on the model for silence.

=item 3. Alignment

The training data are force-aligned to the current model with a pruning treshold
and the sentences that fail to be force-aligned are removed from the training
dataset.

=item 4. Triphones

The models are split to contextual.

=item 5. Mixtures

The models get an extra mixture and performance is evaluated on heldout data.
This is repeated until the performance stops growing.

=back

=head2 Options

Options can be passed directly to evadevi.pl or as environment variables. Some
options can only be set as env vars.

=over 4

=item --train-mfcc

=item EV_train_mfcc

Path to directory with training MFCC files (preferably one sentence per file).
The files B<must> end with C<.mfcc> (not C<.mfc>).

=item --train-transcription

=item EV_train_transcription

Path to transcription of the training audio files in MLF format (see HTK Book
for its description).

=item --train-wordlist

=item EV_wordlist_train_phonet

Path to phonetic dictionary covering the training data.

=item --test-wordlist

=item EV_wordlist_test_phonet

Path to phonetic dictionary for recognition. This and the language model are
necessary for finding the optimal count of mixtures as well as for evaluating
the trained models.

=item --lm

=item EV_LM

Path to language model in HTK lattice format.

=item --m

=item EV_use_triphones

Specifying the C<-m> option or setting the C<EV_use_triphones> environment
variable to an B<empty string> switches off training a triphone model.

=item --homedie

=item EV_homedir

The directory where Evadevi resides. Precisely, the directory where the
Makefile, config.sh and resources/ reside.

The environment variable B<must> have a trailing slash. When specifying the
option directly, the slash is automatically appended.

Evadevi needs to know its homedir to operate; however, in most cases, it can
figure it out itself. For this to work, it is important to run the binary
directly and not via a symlink. (Adding evadevi.pl to PATH is OK.) If you want
to run evadevi.pl from a link, then you have to specify the homedir.

=item --outdir

=item EV_outdir

The directory where the final models are to be stored.

=item --workdir

=item EV_workdir

The directory where the intermediate files are stored. Removing this directory
after running has the effect of a C<make clean>.

=item EV_min_mixures

If this variable is set, the final HMM is guaranteed to have at least this many
mixtures per phone. The rationale for this option is that sometimes, a local
maximum at a lower mixture count would prevent a higher maximum to be found.

Try a high value (~20) and see how the model precision changes with each split.

=item EV_HVite_s

The C<s> option to HVite (LM weight).

=item EV_HVite_p

The C<p> option to HVite (word insertion penalty).

=item EV_HVite_t

The C<t> option to HVite (pruning threshold).

=item EV_iterN

How many reestimations are performed after each step. C<EV_iter> controls all
iterations, C<EV_iter1> controls the iterations after step 1 etc. All default
to 2, except for C<EV_iter5> which defaults to 9 (9 reestimations after each
split).

=item --heldout-ratio

=item EV_heldout_ratio

Evadevi lays a part of the training data aside to test its models. These data
are called I<heldout>. This option specifies, one of how many training sentences
are held out. The default is 20, which means 5% of the training data are held
out.

=item EV_phones_count_file

The set of monophones is extracted from the training dictionary. If this option
is set, the count of the phones are written down to the file, whose path the
option designates.

=item EV_test_mfcc

=item EV_test_transcription

Testing MFCC directory and transcription file (like for training). Needed when
you want to evaluate the HMM via C<make test>.

=back
