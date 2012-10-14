#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use Evadevi::Util::MkMkTriHed;

mkmktrihed(*STDIN{IO}, *STDOUT{IO}, "$ENV{EV_workdir}data/phones/triphones");
