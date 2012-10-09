package HTKUtil;

use strict;
use utf8;
use Carp;
use Exporter qw/import/;
use File::Basename qw(basename);
use Evadevi::Util qw(run_parallel stringify_options);

our @EXPORT = qw(generate_scp mlf2scp hmmiter evaluate_hmm h);

sub h {
    my ($cmd, %opt) = @_;
    die "EV_workdir env var must be set" if not $ENV{EV_workdir};
    
    my ($prg) = split /\s+/, $cmd, 2;
    
    my $log_dir = "$ENV{EV_workdir}log/htk";
    system(qq(mkdir -p "$log_dir")) if not -d $log_dir;
    my $log_fn = sprintf "$log_dir/" . time() . "-$$-$prg";
    $cmd .= qq( > "$log_fn");
    
    local $ENV{LANG} = $opt{LANG} if $opt{LANG};
    
    if ($opt{exec}) {
        exec $cmd;
    }
    my $error = system $cmd;
    die "'$prg > $log_fn' failed with status $error" if $error;
}
sub hsub {
    my @args = @_;
    return sub { h(@args) }
}

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
    my $iter    = $opt{iter} || 9;
    my $config_fn        = $opt{conf} or die '"conf" - path to HTK config not specified';
    my $transcription_fn = $opt{mlf}  or die '"mlf" - path to transcription file not specified';
    my $phones_fn        = $opt{phones}   || "$indir/phones";
    my $t            = $opt{t}            || $ENV{EV_HERest_t} or die '"t" param or "EV_HERest_t" must be set for hmmiter';
    my $parallel_cnt = $opt{parallel_cnt} || $ENV{EV_HERest_p};
    my $thread_cnt   = $opt{thread_cnt}   || $ENV{EV_thread_cnt} || 1;
    
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
        my %herest_options = (
            '-A' => '', '-D' => '', '-T' => 1,
            '-C' => $config_fn,
            '-I' => $transcription_fn,
            '-t' => { val => $t, no_quotes => 1 },
            '-S' => $scp_fn,
            '-H' => ["$from/macros", "$from/hmmdefs"],
            '-M' => $to,
        );
        if (not $parallel_cnt) {
            h('HERest ' . stringify_options(%herest_options) . " $phones_fn");
        }
        else {
            # run parallel
            my $thread = 0;
            my $split = 0;
            my @scp_part_fns = split_scp($parallel_cnt, $scp_fn, $workdir);
            my @batch;
            while ($split < $parallel_cnt) {
                $herest_options{'-p'} = $split + 1;
                $herest_options{'-S'} = $scp_part_fns[$split];
                push @batch, hsub('HERest ' . stringify_options(%herest_options) . " $phones_fn", exec => 1);
                
                $thread = ($thread+1) % $thread_cnt;
                if ($thread == 0) {
                    run_parallel(\@batch);
                    @batch = ();
                }
            } continue {
                $split++;
            }
            if (@batch) {
                run_parallel(\@batch);
            }
            unlink @scp_part_fns;
            
            # synthesize
            my @accumulators = glob "$to/HER*.acc";
            my $accumulators_fn = "$workdir/accumulators.scp";
            open my $accumulators_fh, '>', $accumulators_fn or die "Couldn't open '$accumulators_fn': $!";
            print {$accumulators_fh} "$_\n" for @accumulators;
            
            $herest_options{'-p'} = 0;
            $herest_options{'-S'} = $accumulators_fn;
            
            h('HERest ' . stringify_options(%herest_options) . " $phones_fn");
            unlink @accumulators, $accumulators_fn;
        }
    }
}

sub split_scp {
    my ($count, $scp_fn, $workdir) = @_;
    return $scp_fn if $count == 1;
    my $scp_bn = basename $scp_fn;
    my @rv = map "$workdir/split-$_-$scp_bn", 1 .. $count;
    my @fhs = map {
        open my $fh, '>', $_ or die "Couldn't open '$_' for writing: $!";
        $fh;
    } @rv;
    {
        local @ARGV = $scp_fn;
        while (<ARGV>) {
            print {$fhs[$. % @fhs]} $_;
        }
    }
    return(@rv)
}

sub evaluate_hmm {
    return print STDERR "Evaluating switched off" if $ENV{EV_no_eval};
    
    my %opt = @_;
    my $hmmdir      = $opt{hmmdir}        or croak "Missing directory with HMMs to test (hmmdir)";
    my $workdir     = $opt{workdir} || '/tmp';
    my $mfccdir     = $opt{mfccdir}       or croak "Missing directory with testing MFCC files (mfccdir)";
    my $conf_fn     = $opt{conf}          or croak "Missing HTK config file (conf)";
    my $lm_fn       = $opt{LM}            or croak "Missing language model .lat file (LM)";
    my $wordlist_fn = $opt{wordlist}      or croak "Missing wordlist file (wordlist)";
    my $trans_fn    = $opt{transcription} or croak "Missing transcription file (transcription)";
    my $phones_fn   = $opt{phones}  || "$hmmdir/phones";
    my $t           = $opt{t} // $ENV{EV_HVite_t} // '100.0';
    my $p           = $opt{p} // $ENV{EV_HVite_p} // '0.0';
    my $s           = $opt{s} // $ENV{EV_HVite_s} // '5.0';
    my $thread_cnt  = $opt{thread_cnt} || $ENV{EV_thread_cnt} || 1;
    
    my $scp_fn = "$workdir/eval-mfc.scp";
    mlf2scp($trans_fn, $scp_fn, "$mfccdir/*.mfcc");
    
    my $recout_raw_fn = "$workdir/recout-raw.mlf";
    unlink $recout_raw_fn;
    
    my @hvite_opt = (
        '-T' => 1, '-A' => '', '-D' => '',
        '-l' => '*',
        '-C' => $conf_fn,
        '-t' => $t,
        '-H' => ["$hmmdir/macros", "$hmmdir/hmmdefs"],
        '-w' => $lm_fn, '-p' => $p, '-s' => $s,
    );
    my @scp_part_fns = split_scp($thread_cnt, $scp_fn, $workdir);
    my @commands = map {;
        hsub(
            'HVite ' . stringify_options(@hvite_opt, '-S' => $_, '-i' => "$_.recout", '' => [$wordlist_fn, $phones_fn]),
            LANG=>'C', 'exec' => 1,
        );
    } @scp_part_fns;
    
    run_parallel(\@commands);
    
    my @recout_fns = map "$_.recout", @scp_part_fns;
    merge_mlfs(\@recout_fns, $recout_raw_fn, $scp_fn);
    unlink @recout_fns;
    
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

sub merge_mlfs {
    my ($mlf_fns, $out_fn, $scp_fn) = @_;
    open my $scp_fh, '<', $scp_fn or die "Couldn't open '$scp_fn': $!";
    my @mlf_fhs = map {
        open my $fh, '<', $_ or die "Couldn't open '$_': $!";
        $fh
    } @$mlf_fns;
    open my $out_fh, '>', $out_fn or die "Couldn't open '$out_fn': $!";
    
    # mlf header
    my $header;
    $header = <$_> for @mlf_fhs;
    print {$out_fh} $header;
    
    my @top_sents = map {
        local $/ = "\n.\n";
        { sent => scalar(<$_>), fh => $_ }
    } @mlf_fhs;
    
    my $sent_id;
    SENT:
    while (defined($sent_id = <$scp_fh>)) {
        chomp $sent_id;
        my $sent_stem = basename($sent_id);
        $sent_stem =~ s/\.\w+$//;
        SOURCE:
        for my $sent (@top_sents) {
            # the sentence ID is on the first line of the MLF record (before first newline)
            my $sent_id_pos = index($sent->{sent}, $sent_stem);
            my $newline_pos = index($sent->{sent}, "\n");
            if ($sent_id_pos >= 0 and $sent_id_pos < $newline_pos) {
                print {$out_fh} $sent->{sent};
                {
                    local $/ = "\n.\n";
                    $sent->{sent} = readline($sent->{fh});
                }
                next SENT
            }
        }
        #warn "Sentence '$sent_stem' not found in @$mlf_fns";
    }
}

sub init_hmm {
	my (%opt) = @_;
	my $f       = $opt{f}       // '0.01';
	my $workdir = $opt{workdir} || '/tmp';
	my $hmm_proto_fn  = $opt{hmm_proto} or die "Need hmm proto";
	my $htk_config_fn = $opt{conf}      or die "Need htk conf";
	my $monophones_fn = $opt{phones}    or die "Need monophones";
	my $mfcc_dir      = $opt{mfccdir}   or die "Need mfcc dir";
	my $outdir        = $opt{outdir}    or die "Need outdir";
	my $mfcc_glob = "$mfcc_dir/*";
	my $scp_fn = "$workdir/mfcc.scp";
	
	HTKUtil::generate_scp($scp_fn, $mfcc_glob);
	
	h(qq(HCompV -T 1 -A -D -C "$htk_config_fn" -f "$f" -m -S "$scp_fn" -M "$workdir" "$hmm_proto_fn"));
	
	makehmmdefs("$workdir/proto", "$workdir/vFloors", $monophones_fn, $outdir);
	
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
