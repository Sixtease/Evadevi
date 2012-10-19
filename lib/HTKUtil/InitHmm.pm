package HTKUtil::InitHmm;

use strict;
use utf8;
use Exporter qw(import);
use HTKUtil;
use Evadevi::Util qw(get_filehandle stringify_options);

our @EXPORT_OK = qw(init_hmm init_macros calculate_variance);

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
	
    calculate_variance(
        '-C' => $htk_config_fn,
        '-f' => $f,
        '-S' => $scp_fn,
        '-M' => $workdir,
        ''   => $hmm_proto_fn,
    );
	
	makehmmdefs("$workdir/proto", "$workdir/vFloors", $monophones_fn, $outdir);
	
	link($monophones_fn, "$outdir/phones");
    
    sub makehmmdefs {
        my ($proto_fn, $vFloors_fn, $monophones_fn, $outdir) = @_;
        
        open my $proto_fh,      '<', $proto_fn      or die "Couldn't open proto '$workdir/proto' for reading: $!";
        open my $monophones_fh, '<', $monophones_fn or die "Couldn't open monophones: '$monophones_fn' for reading: $!";
        
        my @monophones = <$monophones_fh>;
        close $monophones_fh;
        chomp @monophones;
        
        init_macros($proto_fh, $vFloors_fn, "$outdir/macros");
        my @proto_tail = <$proto_fh>;
        close $proto_fh;
        
        open my $hmmdefs_fh, '>', "$outdir/hmmdefs" or die "Couldn't open '$outdir/hmmdefs' for writing: $!";
        my $proto = join('', @proto_tail);
        print {$hmmdefs_fh} "\n";
        for my $monophone (@monophones) {
            (my $hmmdef = $proto) =~ s/proto/$monophone/g;
            print {$hmmdefs_fh} $hmmdef;
        }
        close $hmmdefs_fh;
    }
}

sub init_macros {
    my ($proto_file, $vFloors_file, $macros_file) = @_;
    my $proto_fh   = get_filehandle($proto_file);
    my $vFloors_fh = get_filehandle($vFloors_file);
    my $macros_fh = get_filehandle($macros_file, '>');
    
    print {$macros_fh} (
        (map scalar(<$proto_fh>), 0 .. 2),
        (<$vFloors_fh>),
    );
}

sub calculate_variance {
    my $hcompv_cmd = 'HCompV ' . stringify_options(
        '-A' => '',
        '-D' => '',
        '-T' => 1,
        '-m' => '',
        @_,
    );
	h($hcompv_cmd);
}

1

__END__
