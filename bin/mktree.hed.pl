#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil::MkTreeHed;

if (@ARGV != 3) {
    die "usage: $0 resources/tree.hed.tt tree_QS data/phones/monophones\n"
}

mktreehed(@ARGV);
