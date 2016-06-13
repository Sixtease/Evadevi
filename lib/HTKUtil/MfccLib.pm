package HTKUtil::MfccLib;

use 5.010;
use strict;
use warnings;
use utf8;

use Exporter qw(import);
our @EXPORT_OK = qw(mfcc_header);

sub mfcc_header {
    my ($mfcc_fn) = @_;
    open my $mfcc_fh, '<', $mfcc_fn or die "couldn't open '$mfcc_fn': $!";
    binmode $mfcc_fh, ':raw';

    my ($result, $buffer);
    $result = read $mfcc_fh, $buffer, 10;

    die "failed reading '$mfcc_fh': $!" if not defined $result;

    my ($samples_cnt, $sample_period_10ns, $sample_size) = unpack 'L>L>S>', $buffer;
    my $sample_period = $sample_period_10ns/1e7;

    return {
        samples_cnt      => $samples_cnt,
        sample_period    => $sample_period,
        sample_frequency => 1/$sample_period,
        length           => $samples_cnt * $sample_period,
    };
}
