#!/usr/bin/perl

use strict;
use utf8;
use Exporter qw(import);
use HTKUtil qw(mlf2scp h);
use Evadevi::Util qw(stringify_options);

our @EXPORT_OK = qw(evaluate_hmm);

sub evaluate_hmm {
    my %opt = @_;
    my $LMf = $opt{LMf} || die 'Missing language model (LMf)';
    my $LMb = $opt{LMb} || die 'Need backward language model (LMb)';
    my $hmmdir = $opt{hmmdir} || die 'Missing directory with HMMs to test (hmmdir)';
    my $trans_fn = $opt{transcription} || die 'Missing transcription file (transcription)';
    my $wordlist_fn = $opt{wordlist} || die 'Missing wordlist file (wordlist)';
    my $mfccdir = $opt{mfccdir} || die 'Missing directory with testing MFCC files (mfccdir)';
    my $workdir = $opt{workdir} || $hmmdir;
    my $phones_fn = $opt{phones} || "$hmmdir/phones";
    my $align = $opt{align} || '-walign';
    my $unk = $opt{unk} || '!!UNK';
    
    my $hmm_fn;
    if (-e "$hmmdir/hmmmodel") {
        $hmm_fn = "$hmmdir/hmmmodel";
    }
    else {
        $hmm_fn = "$workdir/hmmmodel";
        my $error = system(qq(cat "$hmmdir/macros" "$hmmdir/hmmdefs" > "$hmm_fn"));
        die "Failed to concatenate '$hmmdir/macros' and '$hmmdir/hmmdefs' to '$hmm_fn'" if $error;
    }
    
    my $scp_fn = "$workdir/eval-mfc.scp";
    mlf2scp($trans_fn, $scp_fn, "$mfccdir/*.mfcc");
    
    my $recout_fn = julius_parallel({
        -nlr => $LMf,
        -nrl => $LMb,
        -h => $hmm_fn,
        -filelist => $scp_fn,
        -v => $wordlist_fn,
        -input => 'mfcfile',
        -hlist => "$phones_fn",
        -mapunk => $unk,
        $align => '',
    });
    
    my $mlf_out_fn = "$workdir/recout.mlf";
    open my $recout_fh, '<', $recout_fn or die "Couldn't open julius output file '$recout_fn': $!";
    open my $mlf_out_fh, '>', $mlf_out_fn or die "Couldn't open '$mlf_out_fn' for writing: $!";
    
    print {$mlf_out_fh} "#!MLF!#\n";
    my $in_walign = 0;
    while (<$recout_fh>) {
        /input MFCC file: (.*)/ and print {$mlf_out_fh} qq("$1"\n);
        m/=== begin forced alignment ===/ and $in_walign = 1;
        m/=== end forced alignment ===/ and (print {$mlf_out_fh} ".\n"), $in_walign = 0;
        if ($in_walign and my @m = /^\[\s*(\d+)\s+(\d+)\s*\]\s*([-\d.]+)\s+(\S+)/) {
            next if $m[3] =~ /^</;
            print {$mlf_out_fh} $m[0].'00000 '.$m[1]."00000 $m[3] $m[2]\n";
        }
    }
    close $recout_fh;
    close $mlf_out_fh;
    
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

    # save score next to hmmdefs
    my $opened = open my $score_fh, '>', "$hmmdir/score";
    if ($opened) {
        print {$score_fh} $raw;
        close $opened;
    }
    else {
        warn "Couldn't save score to '$hmmdir/score'";
    }

    return Score->new($1, $raw);
}

sub julius_parallel {
    my ($opt) = @_;
    h('julius ' . stringify_options(%$opt, '2>' => '/dev/null'), LANG => 'C');
}

1

__END__
