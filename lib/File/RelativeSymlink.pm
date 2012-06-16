package File::RelativeSymlink;

use strict;
use utf8;
use Exporter qw(import);
use File::Spec;

our $VERSION = '0.01';
our @EXPORT_OK = qw/mksymlink/;

sub _firstdir {
    my ($path) = @_;
    my $slashpos = index "$path/", '/';
    return substr $path, 0, $slashpos
}

sub mksymlink {
    my ($old, $new) = @_;
    if (File::Spec->file_name_is_absolute($old)) {
        return symlink($old, $new)
    }
    if (File::Spec->file_name_is_absolute($new)) {
        return symlink("$ENV{PWD}/$old", $new)
    }
    my $orig_new = $new;
    while (_firstdir($old) eq (my $fd = _firstdir($new))) {
        die if length($old) * length($new) == 0;
        substr($_, 0, length($fd)+1, '') for $old, $new;
    }
    my ($volume, $dirname, $basename) = File::Spec->splitpath($new);
    my $dirs = 0;
    my @dirs = File::Spec->splitdir($dirname);
    for (@dirs) {
        next if {'.'=>1,''=>1}->{$_};
        if ($_ eq '..') {
            $dirs--;
        }
        else {
            $dirs++;
        }
    }
    if ($dirs < 0) {
        ...
    }
    elsif ($dirs == 0) {
        return symlink($old, $orig_new);
    }
    else {
        return symlink(join('/', (('..') x $dirs), $old), $orig_new);
    }
}

__END__

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Jan Oldřich Krůza.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
