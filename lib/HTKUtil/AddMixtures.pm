package HTKUtil::AddMixtures;

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
use utf8;
use Getopt::Long qw(GetOptionsFromArray GetOptionsFromString);
use File::Basename;
use HTKUtil;
use JulLib qw(evaluate_hmm);
use File::RelativeSymlink qw(mksymlink);

my $wd = $ENV{EV_workdir} || '';
my $eh = $ENV{EV_homedir} || '';

my $dont_use_triphones = 0;
my $orig_transcription_fn = my $transcription_fn = "${wd}data/transcription/train/triphones.mlf";
my $wordlist_fn = "${wd}data/wordlist/test-unk-phonet";
my $starting_hmm;
my $phones_fn;
my $lmf_fn = $ENV{EV_LMf};
my $lmb_fn = $ENV{EV_LMb};
my $conf_fn = "${eh}resources/htk-config";
my $heldout_transcription_fn = "${wd}data/transcription/heldout.mlf";
my $outdir;
my $train_dir = $ENV{EV_train_mfcc};
my $heldout_dir = $ENV{EV_train_mfcc};
my $reest_per_split = $ENV{EV_iter_mixtures} || $ENV{EV_iter} || 9;
my $init_mixture_count = 1;
my $split_all = 0;
my $split_individual = 0;
my $min_mixtures = $ENV{EV_min_mixtures} || 0;
my $allowed_decrease = $ENV{EV_mixtures_allowed_decrease} || 0.3;
my $max_consecutive_decreases = $ENV{EV_mixtures_max_consecutive_decreases} || 3;

sub use_triphones() { return not $dont_use_triphones }

sub init {
    my @options_options = (
        'all|a'             => \$split_all,
        'individual|i'      => \$split_individual,
        'monophones-only|m' => \$dont_use_triphones,
        'trans=s'           => \$transcription_fn,
        'heldout-trans=s'   => \$heldout_transcription_fn,
        'phones=s'          => \$phones_fn,
        'starthmm=s'        => \$starting_hmm,
        'lmf=s'             => \$lmf_fn,
        'lmb=s'             => \$lmb_fn,
        'outdir=s'          => \$outdir,
        'train-dir=s'       => \$train_dir,
        'heldout-dir=s'     => \$heldout_dir,
        'conf=s'            => \$conf_fn,
        'wordlist=s'        => \$wordlist_fn,
        'nummixt=i'         => \$init_mixture_count,
        'reest-per-split=i' => \$reest_per_split,
        'min-mixtures=i'    => \$min_mixtures,
    );
    if (@_ == 1) {
        GetOptionsFromString($_[0], @options_options);
    }
    else {
        GetOptionsFromArray(\@_, @options_options);
    }
    
    die 'starting hmm dir not specified' if not $starting_hmm;
    die 'outdir not specified' if not $outdir;
    
    if ($dont_use_triphones) {
        $transcription_fn = "${wd}data/transcription/train/aligned.mlf" if $transcription_fn eq $orig_transcription_fn;
    }
    $phones_fn = "$starting_hmm/phones" if not defined $phones_fn;
    
    mkdir $outdir;
}

my %MIXTURE_COUNT;

sub split_mixtures {
    my ($hmms, $new_cnt_mixtures, $indir, $outdir) = @_;
    system(qq(mkdir -p "$outdir/split"));
    {
        open my $hed_fh, '>', "$outdir/hed" or die "Couldn't open '$outdir/hed' for writing: $!";
        print {$hed_fh} qq(MU $new_cnt_mixtures {$hmms.state[2-4].mix});
    }
    h(qq(HHEd -T 1 -A -D -H "$indir/macros" -H "$indir/hmmdefs" -M "$outdir/split" "$outdir/hed" "$phones_fn"));
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
        $score = evaluate_hmm(
            hmmdir => "$outdir/reestd",
            workdir => $outdir,
            mfccdir => $heldout_dir,
            conf => $conf_fn,
            LMf => $lmf_fn,
            LMb => $lmb_fn,
            wordlist => $wordlist_fn,
            phones => $phones_fn,
            transcription => $heldout_transcription_fn,
            t => '60.0',
        );
        $score->{phone} = $hmms;
        open my $score_fh, '>', "$outdir/score" or die "Couldn't open '$outdir/score' for writing";
        print {$score_fh} "$score\n\n$score->{raw}\n";
    }
    return $score;
}

sub split_all {
    my $step = '000';
    my $indir = $starting_hmm;
    my $prev_score = evaluate_hmm(
        hmmdir => $indir,
        workdir => $outdir,
        mfccdir => $heldout_dir,
        conf => $conf_fn,
        LMf => $lmf_fn,
        LMb => $lmb_fn,
        wordlist => $wordlist_fn,
        phones => $phones_fn,
        transcription => $heldout_transcription_fn,
        t => '60.0',
    );
    my $prevdir = $indir;
    $MIXTURE_COUNT{'*'} = $init_mixture_count;
    my $max_score = $prev_score;
    my $windir = $indir;
    my $consecutive_decreases = 0;
    print "Start score: $prev_score\n";
    STEP:
    while (1) {
        $step++;
        print "Step $step ";
        my $stepdir = "$outdir/Astep$step";
        mkdir $stepdir;
        my $score = try_phone('*', $indir, $stepdir);
        print "$score\n";

        if ($score <= $max_score) {
            $consecutive_decreases++;
        }
        elsif ($score > $max_score) {
            $consecutive_decreases = 0;
        }

        if ( $consecutive_decreases >= $max_consecutive_decreases
            or $score <= $max_score - $allowed_decrease
        ) {
            print "Winner is $max_score in $windir\n";
            unlink "$outdir/winner";
            mksymlink($windir, "$outdir/winner");
            $starting_hmm = $windir;
            return $windir;
        }
        else {
            if ($score > $max_score) {
                $max_score = $score;
                $windir = "$score->{dir}/reestd";
            }
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
        sort keys %{ { map { s/.*-|\+.*//g; $_ => 1 } grep !/ /, <$phones_fh> } }
    };
    chomp @monophones;
#    @monophones = qw(sp e o t a i n sil s m l ii j v k p d r u aa b zh nj h sh z tj c x ee ch g f rsh rzh ow uu dj ng aw);
    
    my $step = '000';
    my $indir = $starting_hmm;
    my $prev_score = evaluate_hmm(
        hmmdir => $indir,
        workdir => $outdir,
        mfccdir => $heldout_dir,
        conf => $conf_fn,
        LMf => $lmf_fn,
        LMb => $lmb_fn,
        wordlist => $wordlist_fn,
        phones => $phones_fn,
        transcription => $heldout_transcription_fn,
        t => '60.0',
    );
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
    return $score;
}

sub main {
    if (not $split_all and not $split_individual) {
        die "Nothing to split? Provide -a, -i or both to split all or individual phonemes, respectively";
    }
    if ($split_all) {
        split_all();
        $init_mixture_count = $MIXTURE_COUNT{'*'};
    }
    if ($split_individual) {
        find_best_splits();
    }
}

1

__END__
