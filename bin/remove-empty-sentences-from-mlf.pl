#!/usr/bin/perl

# Filters out sentences that are empty or contain silence only
# from a transcription in MLF format.
# Works in pipe mode

use strict;
use warnings;
use utf8;

use File::Basename;
my $PATH;
BEGIN { $PATH = sub { dirname( (caller)[1] ) }->() }
use lib "$PATH/../lib";

use HTKUtil;

HTKUtil::remove_empty_sentences_from_mlf(*STDIN{IO}, *STDOUT{IO});
