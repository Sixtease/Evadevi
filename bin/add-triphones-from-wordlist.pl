#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use File::Basename qw(dirname basename);

my ($physlist_fn, $addedlist_fn, $tiedlist_fn, $trees_fn, $hhed_fn, $fulllist_fn) = @ARGV;
$hhed_fn //= "tie.hed";
$fulllist_fn //= "fulllist";

my %fulllist;
{
    local @ARGV = $physlist_fn;
    while (<ARGV>) {
        chomp;
        $fulllist{$_} = 1;
    }
};

{
    local @ARGV = $addedlist_fn;
    while (<ARGV>) {
        chomp;
        $fulllist{$_} = 1;
    }
};

{
    open my $fulllist_fh, '>', $fulllist_fn or die "Cannot open '$fulllist_fn' for writing: $!";
    say {$fulllist_fh} for sort keys %fulllist;
}

open my $hhed_fh, '>', $hhed_fn or die "Cannot open '$hhed_fn' for writing: $!";
print {$hhed_fh} <<EOF;
LT "$trees_fn"
AU "$fulllist_fn"
CO "$tiedlist_fn"
EOF
close $hhed_fh;

system(qq(HHEd -A -D -T 1 "$hhed_fn" TODO HMMLIST));
