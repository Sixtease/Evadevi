package HTKUtil;

use strict;
use utf8;
use Carp;
use Exporter qw/import/;
use File::Basename qw(basename);
use Evadevi::Util qw(run_parallel stringify_options get_filehandle);

our @EXPORT = qw(generate_scp mlf2scp hmmiter h);

sub h {
    my ($cmd, %opt) = @_;
    die "EV_workdir env var must be set" if not $ENV{EV_workdir};
    
    my ($prg) = split /\s+/, $cmd, 2;
    $prg =~ s/^["']|['"]$//g;
    
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
    
    return $log_fn
}
sub hsub {
    my @args = @_;
    return sub { h(@args) }
}
sub hvite_parallel {
    my ($hvite_options, $hvite_args, %opt) = @_;
    my %hvite_opt = %$hvite_options;
    my $scp_fn = $hvite_opt{'-S'};
    my $recout_fn = $hvite_opt{'-i'};
    my $workdir = $opt{workdir} || '/tmp';
    my $thread_cnt = $opt{thread_cnt} || $ENV{EV_thread_cnt};
    
    my @scp_part_fns = split_scp($thread_cnt, $scp_fn, $workdir);
    my @commands = map {;
        $hvite_opt{'-S'} = $_;
        $hvite_opt{'-i'} = "$_.recout";
        hsub(
            'HVite ' . stringify_options(%hvite_opt, '' => $hvite_args),
            LANG=>'C', 'exec' => 1,
        );
    } @scp_part_fns;

    run_parallel(\@commands);
    
    my @recout_fns = map "$_.recout", @scp_part_fns;
    merge_mlfs(\@recout_fns, $recout_fn, $scp_fn);
    unlink @recout_fns;
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
    
    my $in_fh = get_filehandle($in_file);
    
    while (<$in_fh>) {
        m{^"\*/(.*)\.lab"$} or next;
        push @{$lists[$_]}, expand($tmpls[$_], $1) for 0 .. $#tmpls;
    }
    
    generate_scp($scp_fn, @lists);
}

sub hmmiter {
    my %opt = @_;
    $opt{indir}  or die '"indir" - directory with starting HMMs not specified';
    $opt{outdir} or die '"outdir" - output directory not specified';
    $opt{workdir} ||= '/tmp';
    $opt{mfccdir} or die '"mfccdir" - directory with training parametrized audio files not specified';
    $opt{iter} || 9;
    $opt{conf} or die '"conf" - path to HTK config not specified';
    $opt{mlf}  or die '"mlf" - path to transcription file not specified';
    $opt{phones}       ||= "$opt{indir}/phones";
    $opt{t}            ||= $ENV{EV_HERest_t} or die '"t" param or "EV_HERest_t" must be set for hmmiter';
    $opt{parallel_cnt} ||= $ENV{EV_HERest_p};
    $opt{thread_cnt}   ||= $ENV{EV_thread_cnt} || 1;
    
    $opt{scp_fn} = "$opt{workdir}/mfcc.scp";
    {
        open my $mlf_fh, '<', $opt{mlf} or die "Couldn't open transcription file '$opt{mlf}' for reading: $!";
        mlf2scp($mlf_fh, $opt{scp_fn}, "$opt{mfccdir}/*.mfcc");
    }
    
    iterate(from => $opt{indir}, to => "$opt{workdir}/iter1", %opt);
    my $i;
    for my $_i (1 .. $opt{iter}-2) {
        $i = $_i;
        my $i1 = $i+1;
        iterate(from => "$opt{workdir}/iter$i", to => "$opt{workdir}/iter$i1", %opt);
    }
    $i++;
    iterate(from => "$opt{workdir}/iter$i", to => $opt{outdir}, %opt);
    link($opt{phones}, "$opt{outdir}/phones");
}

sub iterate {
    my %opt = @_;
    my $from = $opt{from};
    my $to = $opt{to};
    mkdir $to;
    my %herest_options = (
        '-A' => '', '-D' => '', '-T' => 1,
        '-C' => $opt{conf},
        '-I' => $opt{mlf},
        '-t' => { val => $opt{t}, no_quotes => 1 },
        '-S' => $opt{scp_fn},
        '-H' => ["$from/macros", "$from/hmmdefs"],
        '-M' => $to,
    );
    $herest_options{'-w'} = $opt{w} if defined $opt{w};
    if (not $opt{parallel_cnt}) {
        h('HERest ' . stringify_options(%herest_options) . " $opt{phones}", LANG => 'C');
    }
    else {
        # run parallel
        my $thread = 0;
        my $split = 0;
        my @scp_part_fns = split_scp($opt{parallel_cnt}, $opt{scp_fn}, $opt{workdir});
        my @batch;
        while ($split < $opt{parallel_cnt}) {
            $herest_options{'-p'} = $split + 1;
            $herest_options{'-S'} = $scp_part_fns[$split];
            push @batch, hsub('HERest ' . stringify_options(%herest_options) . " $opt{phones}", exec => 1, LANG => 'C');
            
            $thread = ($thread+1) % $opt{thread_cnt};
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
        my $accumulators_fn = "$opt{workdir}/accumulators.scp";
        open my $accumulators_fh, '>', $accumulators_fn or die "Couldn't open '$accumulators_fn': $!";
        print {$accumulators_fh} "$_\n" for @accumulators;
        
        $herest_options{'-p'} = 0;
        $herest_options{'-S'} = $accumulators_fn;
        
        h('HERest ' . stringify_options(%herest_options) . " $opt{phones}", LANG => 'C');
        unlink @accumulators, $accumulators_fn;
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
    
    my %hvite_opt = (
        '-T' => 1, '-A' => '', '-D' => '',
        '-l' => '*',
        '-C' => $conf_fn,
        '-t' => $t,
        '-H' => ["$hmmdir/macros", "$hmmdir/hmmdefs"],
        '-w' => $lm_fn, '-p' => $p, '-s' => $s,
        '-S' => $scp_fn,
        '-i' => $recout_raw_fn,
    );
    my @hvite_arg = ($wordlist_fn, $phones_fn);
    hvite_parallel(\%hvite_opt, \@hvite_arg, workdir => $workdir, thread_cnt => $thread_cnt);
    
    open my $recout_raw_fh, '<', $recout_raw_fn or die "Couldn't open '$recout_raw_fn': $!";
    my $recout_fn = "$workdir/recout.mlf";
    open my $recout_fh, '>', $recout_fn or die "Couldn't open '$recout_fn' for writing: $!";
    while (<$recout_raw_fh>) {
        next if /<s>/;
        print {$recout_fh} $_;
    }
    close $recout_fh;
    close $recout_raw_fh;
    
    my $results_fn = h(stringify_options(
        ''   => 'HResults',
        '-A' => '', '-D' => '', '-T' => 1,
        '-z' => '</s>',
        '-I' => $trans_fn,
        ''   => [$phones_fn, $recout_fn],
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

sub remove_empty_sentences_from_mlf {
    my ($in, $out) = @_;
    
    my $in_fh  = get_filehandle($in);
    my $out_fh = get_filehandle($out, '>');
    
    my %phones_to_ignore = (
        sil => 1,
        sp => 1,
    );
    
    print {$out_fh} scalar <$in_fh>; # pass header through
    {
        local $/ = "\n.\n";
        while (<$in_fh>) {
            my ($header, @lines) = split /\n/;
            if (grep {/\w/ and not $phones_to_ignore{$_}} @lines) {
                print {$out_fh} $_;
            }
        }
    }
}

sub add_phones {
    my %opt = @_;
    my $from = $opt{from} or die "None from what to add phones";
    my $to   = $opt{to}   or die "None to what to add phones";
    my %phones;
    {
        local @ARGV = ($to);
        while (<>) {
            chomp;
            my @phones = split /\s+/;
            $phones{$_} = $phones[-1] for @phones;
        }
    }
    open my $fh, '>>', $to or die "Cannot open '$to' for appending: $!";
    {
        local @ARGV = ($from);
        while (<>) {
            chomp;
            next if exists $phones{$_};
            my ($l, $p, $r) = "-$_+" =~ /(\w*)-(\w+)\+(\w*)/ or die "misformatted phone: $_";
            my $m;
            if ($phones{"$l-$p+$r"}) {
                # triphone doch da
            }
            elsif ($m = $phones{"$l-$p"}) {
                print {$fh} "$_ $m\n";
            }
            elsif ($m = $phones{"$p+$r"}) {
                print {$fh} "$_ $m\n";
            }
            elsif ($m = $phones{$p}) {
                print {$fh} "$_ $m\n";
            }
            else {
                die "Couldn't find phone '$_'";
            }
        }
    }
    close $fh;
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
