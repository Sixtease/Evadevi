#!/usr/bin/perl

# Iteratively adds mixtures to given HMM.
# with -a, splits all phonemes (states 2,3,4);
# with -i, splits individual phonemes and keeps
# the split that brought most score improvement.
# The score is checked after each split and reestimation
# series on heldout data (specified with options
# --heldout-trans for .mlf non-phonetic transcription and
# --heldout-dir for directory where corresponding MFCC files reside.
# The number of reestimation iterations after each split defaults
# to 9 and is given with the --reest-per-split option.
# The --trans and --train-dir options specify analogous transcription
# (this time phonetic) and MFCC-directory for reestimation.
# -m specifies that triphones should not be used and monophones only are
# used instead.
# See the GetOption call for a hint about other recognized options.

use strict;
use warnings;
use utf8;
use Getopt::Long;
use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";
use HTKUtil;
use File::RelativeSymlink qw(mksymlink);

my $dont_use_triphones = 0;
my $orig_transcription_fn = my $transcription_fn = 'data/transcription/train/aligned-triphones.mlf';
my $orig_phones_fn        = my $phones_fn        = 'data/phones/triphones';
my $orig_starting_hmm     = my $starting_hmm     = 'hmms/4-triphones';
my $lm_fn = $ENV{EV_LM};
my $conf_fn = 'resources/htk-config';
my $wordlist_fn = $ENV{EV_wordlist_test_phonet};
my $heldout_transcription_fn = $ENV{EV_heldout_transcription};
my $outdir = 'hmms/5-mixtures';
my $train_dir = $ENV{EV_train_mfcc};
my $heldout_dir = $ENV{EV_heldout_mfcc};
my $reest_per_split = 9;
my $init_mixture_count = 1;
my $split_all = 0;
my $split_individual = 0;

GetOptions(
    'all|a'             => \$split_all,
    'individual|i'      => \$split_individual,
    'monophones-only|m' => \$dont_use_triphones,
    'trans=s'           => \$transcription_fn,
    'heldout-trans=s'   => \$heldout_transcription_fn,
    'phones=s'          => \$phones_fn,
    'starthmm=s'        => \$starting_hmm,
    'lm=s'              => \$lm_fn,
    'outdir=s'          => \$outdir,
    'train-dir=s'       => \$train_dir,
    'heldout-dir=s'     => \$heldout_dir,
    'conf=s'            => \$conf_fn,
    'wordlist=s'        => \$wordlist_fn,
    'nummixt=i'         => \$init_mixture_count,
    'reest-per-split=i' => \$reest_per_split,
);

sub use_triphones() { return not $dont_use_triphones }

if ($dont_use_triphones) {
    $transcription_fn = 'data/transcription/train/aligned.mlf' unless $transcription_fn ne $orig_transcription_fn;
    $phones_fn        = $ENV{EV_monophones}                    unless $phones_fn        ne $orig_phones_fn;
    $starting_hmm     = 'hmms/3-aligned'                       unless $starting_hmm     ne $orig_starting_hmm;
}

my $heldout_scp_fn = "$outdir/heldout-mfc.scp";
mlf2scp($heldout_transcription_fn, $heldout_scp_fn, "$heldout_dir/*.mfcc");

mkdir $outdir;

my %MIXTURE_COUNT;

sub get_score {
    my ($hmmdir) = @_;
    unlink "$outdir/recout.mlf";
    my $err = system(qq(LANG=C H HVite -T 1 -A -D -l '*' -C "$conf_fn" -t 60.0 -H $hmmdir/macros -H $hmmdir/hmmdefs -S "$heldout_scp_fn" -i "$outdir/recout.mlf" -w "$lm_fn" -p 0.0 -s 5.0 "$wordlist_fn" "$phones_fn"));
    die "HVite failed with status $err" if $err;
    my $eval_command = qq(HResults -I "$heldout_transcription_fn" "$phones_fn" "$outdir/recout.mlf");
    open my $eval_command_fh, '-|', $eval_command or die "Couldn't start HResults: $!";
    my $line;
    my $raw = '';
    while (<$eval_command_fh>) {
        $raw .= $_;
        if (/Overall Results/ .. /WORD:/) {
            $line = $_;
        }
    }
    $line =~ /%Corr=(\S+?),/ or die "Unexpected results:\n$raw";
    return Score->new($1, $raw);
}

sub split_mixtures {
    my ($hmms, $new_cnt_mixtures, $indir, $outdir) = @_;
    system(qq(mkdir -p "$outdir/split"));
    {
        open my $hed_fh, '>', "$outdir/hed" or die "Couldn't open '$outdir/hed' for writing: $!";
        print {$hed_fh} qq(MU $new_cnt_mixtures {$hmms.state[2-4].mix});
    }
    my $err = system(qq(H HHEd -T 1 -A -D -H "$indir/macros" -H "$indir/hmmdefs" -M "$outdir/split" "$outdir/hed" "$phones_fn"));
    die "HHEd failed with status $err" if $err;
    my $prevdir = "$outdir/split";
    hmmiter(
        indir => $prevdir,
        workdir => $outdir,
        outdir => "$outdir/reestd",
        mfccdir => $train_dir,
        iter => $reest_per_split,
        conf => $conf_fn,
        mlf => $transcription_fn,
        phones => $phones_fn,
    );
    my $score;
    {
        $score = get_score("$outdir/reestd");
        $score->{phone} = $hmms;
        open my $score_fh, '>', "$outdir/score" or die "Couldn't open '$outdir/score' for writing";
        print {$score_fh} "$score\n\n$score->{raw}\n";
    }
    return $score
}

sub split_all {
    my $step = '000';
    my $indir = $starting_hmm;
    my $prev_score = get_score($indir);
    my $prevdir = $indir;
    $MIXTURE_COUNT{'*'} = $init_mixture_count;
    print "Start score: $prev_score\n";
    STEP:
    while(1) {
        $step++;
        print "Step $step ";
        my $stepdir = "$outdir/Astep$step";
        mkdir $stepdir;
        my $score = try_phone('*', $indir, $stepdir);
        print "$score\n";
        if ($score <= $prev_score) {
            print "Winner is $prev_score in $prev_score->{dir}\n";
            unlink "$outdir/winner";
            mksymlink($prevdir, "$outdir/winner");
            return $prevdir
        }
        else {
            $indir = "$score->{dir}/reestd";
            $prev_score = $score;
            $prevdir = "$prev_score->{dir}/reestd";
            $MIXTURE_COUNT{'*'}++;
        }
    }
}

sub find_best_splits {
    my @monophones = do {
        open my $phones_fh, '<', "$phones_fn" or die "Couldn't open '$phones_fn' $!";
        sort keys { map { s/.*-|\+.*//g; $_ => 1 } <$phones_fh> }
    };
    chomp @monophones;
#    @monophones = qw(sp e o t a i n sil s m l ii j v k p d r u aa b zh nj h sh z tj c x ee ch g f rsh rzh ow uu dj ng aw);
    
    my $step = '000';
    my $indir = $starting_hmm;
    my $prev_score = get_score($indir);
    $prev_score->{dir} = $indir;
    print "Start score: $prev_score\n";
    STEP:
    while (1) {
        $step++;
        print "Step $step\n";
        my %scores = (max => 0);
        my $stepdir = "$outdir/Sstep$step";
        mkdir $stepdir;
        for my $monophone (@monophones) {
            print "phone $monophone ";
            my $score = try_phone($monophone, $indir, $stepdir, \%scores);
            print "$score\n";
            if (use_triphones) {
                my $mask = "*-$monophone+*";
                print "mask $mask ";
                $score = try_phone($mask, $indir, $stepdir, \%scores);
                print "$score\n";
            }
        }
        my $max = $scores{max};
        my $winner = "$max->{dir}/reestd";
        mksymlink($winner, "$stepdir/winner");
        $indir = $winner;
        print "Winner: $winner with $scores{max}{precision}\n";
        
        if ($max > $prev_score) {
            $prev_score = $max;
            $MIXTURE_COUNT{ $max->{phone} }++;
        }
        else {
            print "Performance lowered; overall winner is $prev_score->{precision} in $prev_score->{dir}\n";
            unlink "$outdir/winner";
            mksymlink($prev_score->{dir}, "$outdir/winner");
            last STEP
        }
    }
}

sub try_phone {
    my ($phone, $indir, $stepdir, $scores) = @_;
    $scores = {max=>0} if not defined $scores;
    my $current_mixture_count = $MIXTURE_COUNT{$phone} || $init_mixture_count;
    $MIXTURE_COUNT{$phone} = $current_mixture_count;
    my $new_mixture_count = $current_mixture_count + 1;
    my $phone_str;
    if ($phone eq '*') {
        $phone_str = 'ALL';
    }
    else {
        ($phone_str = $phone) =~ tr/*//d;
    }
    my $outdir = "$stepdir/$phone_str$new_mixture_count";
    mkdir "$outdir";
    my $score = split_mixtures($phone, $new_mixture_count, $indir, $outdir);
    $score->{dir} = $outdir;
    $scores->{$phone} = $score;
    $scores->{max} = $score > $scores->{max} ? $score : $scores->{max};
    return $score
}

sub main {
    if (not $split_all and not $split_individual) {
        die "Nothing to split? Provide -a, -i or both to split all or individual phonemes, respectively";
    }
    if ($split_all) {
        my $all_winner = split_all();
        $starting_hmm = $all_winner;
        $init_mixture_count = $MIXTURE_COUNT{'*'};
    }
    if ($split_individual) {
        find_best_splits();
    }
}

main();

package Score;
use overload (
    '""' => sub {
        my ($self) = @_;
        return $self->{precision}
    },
    '0+' => sub {
        my ($self) = @_;
        return $self->{precision}
    },
    '<=>' => sub {
        my ($self, $other) = @_;
        return ("$self" <=> "$other")
    },
);
sub new {
    my ($class, $precision, $raw) = @_;
    return bless {
        precision => $precision,
        raw => $raw,
    }, $class
}
