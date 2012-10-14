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
    my ($tmpl_fn, $qs, $phones, $out) = @_;
    
    die 'no template for triphone tying tree'   if not $tmpl_fn;
    die 'no questions for triphone tying tree'  if not $qs;
    die 'no monophones for triphone tying tree' if not $phones;
    
    my @phones;
    if (ref($phones) eq 'ARRAY') {
        @phones = @$phones;
    }
    else {
        my $phones_fh = get_filehandle($phones);
        chomp(@phones = <$phones_fh>);
    }
    
    my $tt = Template->new(ABSOLUTE => 1);
    
    $tt->process($tmpl_fn, {
        %ENV,
        qs => $qs,
        phones => \@phones,
    }, $out) or die $tt->error;
}

1

__END__
