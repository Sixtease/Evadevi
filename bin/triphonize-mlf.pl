#!/usr/bin/perl

# Converts a monophone-based phonetic transcription in MLF format to a
# triphone-based one. The first argument must be a file with a list of
# triphonemes. Works in pipe mode.
# If a triphoneme is encountered that is not present in the list of phones,
# then a left-context biphone is printed instead. If neither that is present,
# a right-context biphone is tried and as a last resort, the bare monophone
# is printed out.

use strict;
use warnings;
use utf8;

my $phones_fn = shift @ARGV;

my %phones;
open my $phones_fh, '<', $phones_fn or die "Couldn't open phones file '$phones_fn': $!";
while (<$phones_fh>) {
    chomp;
    $phones{$_}++;
}
close $phones_fh;

my @buffer = ('', '', scalar(<>));
chomp @buffer;

while (<>) {
    chomp;
    shift @buffer;
    push @buffer, $_;
    
    my $triphone = "$buffer[0]-$buffer[1]+$buffer[2]";
    my $lbiphone = "$buffer[0]-$buffer[1]";
    my $rbiphone = "$buffer[1]+$buffer[2]";
    my $monophone = $buffer[1];
    
    if ($phones{$triphone}) {
        print $triphone, "\n";
    }
    elsif ($phones{$lbiphone}) {
        print $lbiphone, "\n";
    }
    elsif ($phones{$rbiphone}) {
        print $rbiphone, "\n";
    }
    else {
        print $monophone, "\n";
    }
}

print $buffer[-1], "\n";
