package HTKUtil::MkMkTriHed;

# Generates mktri.hed script for HTK. mktri.hed is a script for splitting
# models for monophones into triphones and biphones.
# Works in pipe mode, where on STDIN, monophones are expected.

use strict;
use utf8;
use Exporter qw(import);
use Evadevi::Util qw(get_filehandle);

our @EXPORT = qw(mkmktrihed);

my $tmpl = 'TI T_%1$s {(%1$s,*-%1$s,*-%1$s+*,%1$s+*).transP}';

sub expand {
    return sprintf $tmpl, @_;
}

sub mkmktrihed {
    my ($in, $out, $triphones_fn) = @_;
    my $in_fh  = get_filehandle($in);
    my $out_fh = get_filehandle($out, '>');

    print {$out_fh} "CL $triphones_fn\n";
    while (<$in_fh>) {
        chomp;
        next if $_ eq 'sil';
        print {$out_fh} expand($_), "\n";
    }
}

1

__END__
