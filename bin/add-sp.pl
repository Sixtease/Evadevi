#!/usr/bin/perl

# Adds sp (short pause) model to a HMM with sil (silence) model.
# Copies the sil transition matrix and reduces its five states to three,
# i.e. keeps only middle state of sil.
# Works in pipe mode.

use strict;
use warnings;
use utf8;

sub c($) { return $_ eq $_[0]."\n" }

my @transform = (
    sub {
        s/^~h "sil"/~h "sp"/;
    },
    sub {
        s/^<NUMSTATES> 5/<NUMSTATES> 3/
    },
    sub {   # discard state 2
        s/^<STATE> 3/<STATE> 2/ or $_ = '';
    },
    sub {   # capture state 3 renamed to 2
        s/^<STATE> 4.*//s;
    },
    sub {   # discard state 4
        s/^<TRANSP> 5/<TRANSP> 3/ or $_ = '';
    },
    sub {   # modify transition row 1: 0 1 0 0 0 => 0 1 0
        s/(\S+\s+\S+\s+)\S+\s+\S+\s+/$1/;
    },
    sub {   # discard transition row 2
        s/.*//s;
    },
    sub {   # modify transition row 3: 0 0 x y 0 => 0 x y
        s/\S+\s+(\S+\s+\S+\s+\S+).*/$1/;
    },
    sub {   # discard transition row 4
        s/.*//s;
    },
    sub {   # modify transition row 5: 0 0 0 0 0 => 0 0 0
        s/\S+\s+\S+\s+//;
    },
    sub { return 0 },
);
my $sp = '';

while (<>) {
    print;
    if (c('~h "sil"') .. c('<ENDHMM>')) {
        $transform[0]->() and shift @transform;
        $sp .= $_;
    }
}

print $sp;
