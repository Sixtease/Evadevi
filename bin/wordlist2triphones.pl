#!/usr/bin/perl

use strict;
use warnings;
use utf8;

my %phones = (
    sil => 0,
    sp => 0,
);

while (<>) {
    chomp;
    my ($word, $phone1, @phones) = split /\s+/;
    my $tail;
    $tail = pop @phones if {sp=>1,sil=>1}->{$phones[-1]};
    my @buffer = ('', '', $phone1);
    for (@phones, '') {
        shift @buffer;
        push @buffer, $_;
        
        my $phone = '';
        if ($buffer[0]) {
            $phone .= "$buffer[0]-";
        }
        $phone .= $buffer[1];
        if ($buffer[2]) {
            $phone .= "+$buffer[2]";
        }
        
        $phones{$phone}++;
    }
}

print "$_\n" for sort {$phones{$b} <=> $phones{$a}} keys %phones;
