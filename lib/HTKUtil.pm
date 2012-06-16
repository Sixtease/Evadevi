package HTKUtil;

use strict;
use utf8;
use Carp;
use Exporter qw/import/;

our @EXPORT = qw(generate_scp mlf2scp hmmiter);

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
    for $i (1 .. $iter-2) {
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

1

__END__
