package HTKUtil::MkTreeHed;

# Creates a tree.hed script from a template, a list of questions
# and a list of monophones.
# This is used in tying triphone states.

use strict;
use warnings;
use utf8;
use Template;
use Exporter qw(import);
use Evadevi::Util qw(get_filehandle);

our @EXPORT = qw(mktreehed);

sub mktreehed {
    my %opt = @_;
    
    die 'no template for triphone tying tree'    if not $opt{tmpl_fn};
    die 'no questions for triphone tying tree'   if not $opt{qs};
    die 'no monophones for triphone tying tree'  if not $opt{monophones};
    die 'no >tiedlist for triphone tying tree'   if not $opt{tiedlist};
    die 'no >stats file for triphone tying tree' if not $opt{stats_fn};
    
    my @monophones;
    if (ref($opt{phones}) eq 'ARRAY') {
        @monophones = @{$opt{monophones}};
    }
    else {
        my $phones_fh = get_filehandle($opt{monophones});
        chomp(@monophones = <$phones_fh>);
    }
    
    my $tt = Template->new(ABSOLUTE => 1);
    
    $tt->process($opt{tmpl_fn}, {
        %ENV,
        qs         => $opt{qs},
        monophones => \@monophones,
        tiedlist   => $opt{tiedlist},
        stats      => $opt{stats_fn},
    }, $opt{out}) or die $tt->error;
}

1

__END__
