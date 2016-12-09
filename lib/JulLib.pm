package JulLib;

use strict;
use utf8;
use Exporter qw(import);
use HTKUtil qw(mlf2scp h);  # Score
use Evadevi::Util qw(stringify_options);

our @EXPORT_OK = qw(evaluate_hmm);

sub evaluate_hmm {
    my %opt = @_;
    my $hmmdir = $opt{hmmdir} || die 'Missing directory with HMMs to test (hmmdir)';
    my $trans_fn = $opt{transcription} || die 'Missing transcription file (transcription)';
    my $workdir = $opt{workdir} || $hmmdir;
    my $phones_fn = $opt{phones} || "$hmmdir/phones";
    my $scoredir = $opt{scoredir} || $hmmdir;
    
    my $recout_fn = recognize(%opt);
    
    my $mlf_out_fn = "$workdir/recout.mlf";
    recout_to_mlf(
        recout_fn => $recout_fn,
        mlf_out_fn => $mlf_out_fn,
    );
    
    my $score = evaluate_recout(%opt,
        mlf_out_fn => $mlf_out_fn,
        workdir => $workdir,
        phones => $phones_fn,
    );
    
    # save score next to hmmdefs
    my $opened = open my $score_fh, '>', "$scoredir/score";
    if ($opened) {
        print {$score_fh} $score->{raw};
        close $opened;
    }
    else {
        warn "Couldn't save score to '$scoredir/score'";
    }
    
    return $score;
}

sub evaluate_recout {
    my %opt = @_;
    my $trans_fn = $opt{transcription} || die 'Missing transcription file (transcription)';
    my $workdir = $opt{workdir} || die 'Missing workdir';
    my $phones_fn = $opt{phones} || die 'Missing phones';
    my $mlf_out_fn = $opt{mlf_out_fn} || die 'Missing mlf_out_fn (MLF recout to evaluate)';
    
    my $results_fn = h(stringify_options(
        ''   => 'HResults',
        '-A' => '', '-D' => '', '-T' => 1,
        '-z' => '</s>',
        '-I' => $trans_fn,
        ''   => [$phones_fn, $mlf_out_fn],
    ), LANG => 'C', return_output  => 1);
    my $line = '';
    my $raw = '';
    {
        local @ARGV = $results_fn;
        while (<ARGV>) {
            $raw .= $_;
            if (/Overall Results/ .. /WORD:/) {
                $line = $_;
            }
        }
    }
    $line =~ /%Corr=(\S+?),/ or die "Unexpected results:\n$raw";
    
    return Score->new($1, $raw);
}

sub recout_to_mlf {
    my %opt = @_;
    
    my $recout_fn = $opt{recout_fn};
    my $mlf_out_fn = $opt{mlf_out_fn};
    
    open my $recout_fh, '<', $recout_fn or die "Couldn't open julius output file '$recout_fn': $!";
    open my $mlf_out_fh, '>', $mlf_out_fn or die "Couldn't open '$mlf_out_fn' for writing: $!";
    
    print {$mlf_out_fh} "#!MLF!#\n";
    my $in_walign = 0;
    while (<$recout_fh>) {
        if (my ($label) = /input MFCC file: (.+)/) {
            if ($ENV{EV_label_transform}) {
                for ($label) {
                    eval $ENV{EV_label_transform};
                }
            }
            print {$mlf_out_fh} qq("$label"\n);
        }
        m/-- word alignment --/ and $in_walign = 1;
        m/=== end forced alignment ===/ and $in_walign and (print {$mlf_out_fh} ".\n"), $in_walign = 0;
        if ($in_walign and my @m = /^\[\s*(\d+)\s+(\d+)\s*\]\s*([-\d.]+)\s+(\S+)/) {
            next if $m[3] =~ /^</;
            print {$mlf_out_fh} $m[0].'00000 '.$m[1]."00000 $m[3] $m[2]\n";
        }
    }
    close $recout_fh;
    close $mlf_out_fh;
}

sub recognize {
    my %opt = @_;
    my $LMf = $opt{LMf} || die 'Missing language model (LMf)';
    my $LMb = $opt{LMb};
    my $hmmdir = $opt{hmmdir} || die 'Missing directory with HMMs to test (hmmdir)';
    my $trans_fn = $opt{transcription} || die 'Missing transcription file (transcription)';
    my $wordlist_fn = $opt{wordlist} || die 'Missing wordlist file (wordlist)';
    my $mfccdir = $opt{mfccdir} || die 'Missing directory with testing MFCC files (mfccdir)';
    my $workdir = $opt{workdir} || $hmmdir;
    my $phones_fn = $opt{phones} || "$hmmdir/phones";
    my $align = $opt{align} || '-walign -palign';
    my $unk = $opt{unk} || '!!UNK';
    
    my $hmm_fn;
    if (-e "$hmmdir/hmmmodel") {
        $hmm_fn = "$hmmdir/hmmmodel";
        if ((stat $hmm_fn)[9] < (stat "$hmmdir/hmmdefs")[9]) {
            my $err = system(qq(cat "$hmmdir/macros" "$hmmdir/hmmdefs" > $hmm_fn));
            if ($err) {
                die "$hmm_fn outdated by $hmmdir/hmmdefs and failed to regenerate (status $err): $!"
            }
        }
    }
    else {
        $hmm_fn = "$workdir/hmmmodel";
        my $error = system(qq(cat "$hmmdir/macros" "$hmmdir/hmmdefs" > "$hmm_fn"));
        die "Failed to concatenate '$hmmdir/macros' and '$hmmdir/hmmdefs' to '$hmm_fn'" if $error;
    }
    
    my $scp_fn = "$workdir/eval-mfc.scp";
    mlf2scp($trans_fn, $scp_fn, "$mfccdir/*.mfcc");
    
    my @lmb_opt = ();
    @lmb_opt = (-nrl => $LMb) if $LMb;
    my $recout_fn = julius_parallel({
        -nlr => $LMf,
        @lmb_opt,
        -h => $hmm_fn,
        -filelist => $scp_fn,
        -v => $wordlist_fn,
        -input => 'mfcfile',
        -hlist => "$phones_fn",
        -mapunk => $unk,
        $align => '',
        -lmp2 => {
            no_quotes => 1,
            val => '8.0 -4.0',
        },
        -fallback1pass => '',
    });
    
    return $recout_fn;
}

sub julius_parallel {
    my ($opt) = @_;
    h('julius ' . stringify_options(%$opt, '2>' => '/tmp/julius-err'), LANG => 'C', log_cmd => 1);
}

sub recout_to_utterance_timespans {
    my ($recout_fn, $splits_fn) = @_;
    my @splits;
    {
        open my $splits_fh, '<', $splits_fn or die "Couldn't open splits file: '$splits_fn': $!";
        while (<$splits_fh>) {
            my ($sent_id, $stem, $start_ts, $end_ts) = /^(\S+)\s+(\S+)\s+([\d.]+)\s*\.\.\s*([\d\.]+)$/;
            push @splits, {
                sent_id  => $sent_id,
                start_ts => $start_ts,
            };
        }
    }
    open my $recout_fh, '<', $recout_fn or die "Couldn't open recout file '$recout_fn': $!";
    my $offset = 0;
    my $in_pa = 0;  # phoneme alignment
    my $inside_word = 0;
    my $prev_end;
    RECOUTLINE:
    while (<$recout_fh>) {
        if (/input MFCC file:/) {
            my $split = shift @splits;
            my $expected_sent_id = $split->{sent_id};
            if (index($_, $expected_sent_id) < 0) {
                die "mismatching sentence ID $expected_sent_id X $_";
            }
            $offset = $split->{start_ts};
        }
        if (/-- phoneme alignment --/) {
            $in_pa = 1;
        }
        if (/=== end forced alignment ===/) {
            $in_pa = 0;
        }
        if ($in_pa) {
            my $rec = parse_pa($_);
            next RECOUTLINE if not $rec;
            if (is_sil($rec->{phone})) {
                if ($inside_word) {
                    $inside_word = 0;
                    print $prev_end, "\n";
                }
                else {
                    # silence outside word, ignore
                }
            }
            else {
                ($prev_end) = $offset + $rec->{end}/100;
                if ($inside_word) {
                    # utterance inside word, save end and skip
                }
                else {
                    print $offset + $rec->{start}/100, ' .. ';
                    $inside_word = 1;
                }
            }
        }
    }
}

sub parse_pa {
    my ($line) = @_;
    my ($start, $end, $score, $phone) = $line =~ /\[\s*(\d+)\s+(\d+)\s*\]\s*(-?[\d\.]+)\s+(\S+)/;
    return if not $start;
    $phone =~ s/\[.*//;
    $phone =~ s/\+.*//;
    $phone =~ s/.*-//;
    return {
        start => $start,
        end   => $end,
        score => $score,
        phone => $phone,
    };
}

sub is_sil {
    my ($phone) = @_;
    return {sil => 1, sp => 1}->{$phone};
}

1

__END__
