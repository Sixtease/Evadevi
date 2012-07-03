#!/usr/bin/perl

# From a phonetic transcription, counts the occurring triphones, biphones and
# monophones. Outputs a list of phones. Works in pipe mode.
# By default, only outputs phones that occur at least 3 times, but anyways
# always prints all monophones. The minimum count can be overriden by setting
# the EV_min_phone_count environment variable or by passing the --min-count
# option.
# If the EV_phones_count_file environment variable is set to a filename, then
# the phoneme counts are appended to that file.

use strict;
use warnings;
use utf8;
use Getopt::Long;

my $GRAM_LENGTH = 3; # not really configurable, see (1)
my $MIN_COUNT = $ENV{EV_min_phone_count} || 3;

GetOptions(
    'min-count=s' => \$MIN_COUNT,
);

my @buff;
my %phones;

sub restart { @buff = (); }

scalar <>;

while (<>) {
    chomp;
    restart, next if /^"/ or { sil=>1, '.'=>1 }->{$_};
    $phones{$_}++;
    if (@buff) {
        $phones{"$buff[-1]-$_"}++;
        $phones{"$buff[-1]+$_"}++;
    }
    if (@buff > 1) {
        $phones{"$buff[-2]-$buff[-1]+$_"}++;
        # (1) here would come saving of tetraphonemes etc.
    }
    if (@buff >= $GRAM_LENGTH) { shift @buff; }
    push @buff, $_;
}

if ($ENV{EV_phones_count_file}) {
    open my $fh, '>>', $ENV{EV_phones_count_file};
    print {$fh} "Triphone count:\n";
    print {$fh} "$_ $phones{$_}\n" for sort {$phones{$b} <=> $phones{$a}} keys %phones;
}

# Delete context-based sp's
for my $ngram (keys %phones) {
    if ($ngram =~ /-sp\b|\bsp\+/) {
        delete $phones{$ngram};
    }
}

# Subtract biphoneme counts for corresponding surviving triphonemes.
# Thing is we don't want to keep a biphoneme if containing triphonemes
# are so frequent that we'll seldom fall back to that biphoneme.
for my $ngram (keys %phones) {
    next if (my $count = $phones{$ngram}) <= $MIN_COUNT;
    my ($l,$c,$r) = $ngram =~ /(.*)-(.*)\+(.*)/ or next;
    $phones{"$l-$c"} -= $count;
    $phones{"$c+$r"} -= $count;
}

print "$_\n" for qw(sil), sort {
    $phones{$b} <=> $phones{$a}
} grep {;
    !/[-+]/ or
    $phones{$_} >= $MIN_COUNT
} keys %phones;
