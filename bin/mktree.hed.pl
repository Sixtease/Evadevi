#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Template;

if (@ARGV != 3) {
    die "usage: $0 resources/tree.hed.tt tree_QS data/phones/monophones\n"
}

my $tmpl_fn = shift;
my $qs = shift;

die "no triphone tree" if not $qs;

chomp (my @phones = <ARGV>);

my $tt = Template->new(ABSOLUTE => 1);

$tt->process($tmpl_fn, {
	%ENV,
	qs => $qs,
    phones => \@phones,
}) or die $tt->error;
