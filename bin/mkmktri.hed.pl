#!/usr/bin/perl

# Generates mktri.hed script for HTK. mktri.hed is a script for splitting
# models for monophones into triphones and biphones.
# Works in pipe mode, where on STDIN, monophones are expected.

use strict;
use warnings;
use utf8;

my $tmpl = 'TI T_%1$s {(*-%1$s,*-%1$s+*,%1$s+*).transP}';

sub expand {
    return sprintf $tmpl, @_;
}

print "CL $ENV{EV_workdir}data/phones/triphones\n";
while (<>) {
    chomp;
    next if $_ eq 'sil' or $_ eq 'sp';
    print expand($_), "\n";
}
