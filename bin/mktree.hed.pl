#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil::MkTreeHed;

# FIXME: delete or add GetOptions!

mktreehed(@ARGV);
