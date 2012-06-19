package HTKUtil;

use strict;
use utf8;
use Carp;
use Exporter qw/import/;

our @EXPORT = qw(generate_scp mlf2scp hmmiter evaluate_hmm);

sub generate_scp {
    my ($scp_fn, @filelists) = @_;
    
    if (@filelists == 0) {
        croak 'arrays of filenames expected'
    }
    for (@filelists) {
        if ($_ =~ /[*?]/) {
            $_ = [ glob $_ ];
        }
        croak 'arrays of filenames expected' if ref $_ ne 'ARRAY';
        croak 'filenames arrays must be of equal length' if @$_ != @{$filelists[0]};
    }
    
    open my $scp_fh, '>', $scp_fn or die "Couldn't open '$scp_fn' for writing: $!";
    for my $i (0 .. $#{$filelists[0]}) {
        my $line = join(' ', map $_->[$i], @filelists);
        print {$scp_fh} $line, "\n";
    }
    close $scp_fh;
}

sub mlf2scp {
    my ($in_file, $scp_fn, @tmpls) = @_;
    my @lists = map [], @tmpls;
    
    sub expand {
        my ($tmpl, $fn) = @_;
        $tmpl =~ s/\*/$fn/;
        return $tmpl
    }
    
    my $in_fh;
    if (ref($in_file) !~ /GLOB|IO/ and -e $in_file) {
        open $in_fh, '<', $in_file or die "Failed to open transcription file '$in_file': $!";
    }
    else {
        $in_fh = $in_file;
    }
    
    while (<$in_fh>) {
        m{^"\*/(.*)\.lab"$} or next;
        push @{$lists[$_]}, expand($tmpls[$_], $1) for 0 .. $#tmpls;
    }
    
    generate_scp($scp_fn, @lists);
}

sub hmmiter {
    my (%opt) = @_;
    my $indir   = $opt{indir}  or die '"indir" - directory with starting HMMs not specified';
    my $outdir  = $opt{outdir} or die '"outdir" - output directory not specified';
    my $workdir = $opt{workdir} || '/tmp';
    my $mfccdir = $opt{mfccdir} or die '"mfccdir" - directory with training parametrized audio files not specified';
    my $iter = $opt{iter} || 9;
    my $config_fn = $opt{conf} or die '"conf" - path to HTK config not specified';
    my $transcription_fn = $opt{mlf} or die '"mlf" - path to transcription file not specified';
    my $phones_fn = $opt{phones} || "$indir/phones";
    my $t = $opt{t} || '250.0 150.0 1000.0';
    
    my $scp_fn = "$workdir/mfcc.scp";
    {
        open my $mlf_fh, '<', $transcription_fn or die "Couldn't open transcription file '$transcription_fn' for reading: $!";
        mlf2scp($mlf_fh, $scp_fn, "$mfccdir/*.mfcc");
    }
    
    iterate(from => $indir, to => "$workdir/iter1");
    my $i;
    for my $_i (1 .. $iter-2) {
        $i = $_i;
        my $i1 = $i+1;
        iterate(from => "$workdir/iter$i", to => "$workdir/iter$i1");
    }
    $i++;
    iterate(from => "$workdir/iter$i", to => $outdir);
    link($phones_fn, "$outdir/phones");
    
    sub iterate {
        my %opt = @_;
        my $from = $opt{from};
        my $to = $opt{to};
        mkdir $to;
        local $ENV{LANG} = 'C';
        my $error = system(qq(H HERest -A -D -T 1 -C "$config_fn" -I "$transcription_fn" -t $t -S "$scp_fn" -H "$from/macros" -H "$from/hmmdefs" -M "$to" "$phones_fn"));
        die "HERest ended with error status $error" if $error;
    }
}

sub evaluate_hmm {
    my %opt = @_;
    my $hmmdir      = $opt{hmmdir}        or croak "Missing directory with HMMs to test (hmmdir)";
    my $workdir     = $opt{workdir} || '/tmp';
    my $mfccdir     = $opt{mfccdir}       or croak "Missing directory with testing MFCC files (mfccdir)";
    my $conf_fn     = $opt{conf}          or croak "Missing HTK config file (conf)";
    my $lm_fn       = $opt{LM}            or croak "Missing language model .lat file (LM)";
    my $wordlist_fn = $opt{wordlist}      or croak "Missing wordlist file (wordlist)";
    my $phones_fn   = $opt{phones}        or croak "Missing phones file (phones)";
    my $trans_fn    = $opt{transcription} or croak "Missing transcription file (transcription)";
    my $t           = $opt{t} || $ENV{EV_HVite_t} || '100.0';
    my $p           = $opt{p} || $ENV{EV_HVite_p} || '0.0';
    my $s           = $opt{s} || $ENV{EV_HVite_s} || '5.0';
    
    my $scp_fn = "$workdir/eval-mfc.scp";
    mlf2scp($trans_fn, $scp_fn, "$mfccdir/*.mfcc");
    
    my $recout_raw_fn = "$workdir/recout-raw.mlf";
    unlink $recout_raw_fn;
    my $err = system(qq(LANG=C H HVite -T 1 -A -D -l '*' -C "$conf_fn" -t "$t" -H $hmmdir/macros -H $hmmdir/hmmdefs -S "$scp_fn" -i "$recout_raw_fn" -w "$lm_fn" -p "$p" -s "$s" "$wordlist_fn" "$phones_fn"));
    die "HVite failed with status $err" if $err;
    
    open my $recout_raw_fh, '<', $recout_raw_fn or die "Couldn't open '$recout_raw_fn': $!";
    my $recout_fn = "$workdir/recout.mlf";
    open my $recout_fh, '>', $recout_fn or die "Couldn't open '$recout_fn' for writing: $!";
    while (<$recout_raw_fh>) {
        next if /<s>/;
        print {$recout_fh} $_;
    }
    close $recout_fh;
    close $recout_raw_fh;
    
    my $eval_command = qq(HResults -z '</s>' -I "$trans_fn" "$phones_fn" "$recout_fn");
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
        if (ref $other eq 'Score') {
            $other = $other->{precision};
        }
        return ($self->{precision} <=> $other)
    },
    '*' => sub {
        my ($self, $other) = @_;
        if (ref $other eq 'Score') {
            $other = $other->{precision}
        }
        return $self->{precision} * $other
    },
);
sub new {
    my ($class, $precision, $raw) = @_;
    return bless {
        precision => $precision,
        raw => $raw,
    }, $class
}

1

__END__
