#!/usr/bin/perl

use strict;
use warnings;
use utf8;

chomp(my @phones = do {
    local @ARGV = shift;
    <ARGV>;
});
my %phones = map {$_ => 1} @phones;

while (<>) {
    chomp;
    my ($word, $phone1, @phones) = split /\s+/;
    print $word, '      ';
    my @buffer = ('', 'sp', $phone1);
    for (@phones, '') {
        print ' ';
        shift @buffer;
        push @buffer, $_;
        
        my $triphone = "$buffer[0]-$buffer[1]+$buffer[2]";
        my $lbiphone = "$buffer[0]-$buffer[1]";
        my $rbiphone = "$buffer[1]+$buffer[2]";
        my $monophone = $buffer[1];
        
        if ($phones{$triphone}) {
            print $triphone;
        }
        elsif ($phones{$lbiphone}) {
            print $lbiphone;
        }
        elsif ($phones{$rbiphone}) {
            print $rbiphone;
        }
        else {
            print $monophone;
        }
    }
    print "\n";
}
