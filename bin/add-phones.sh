#!/bin/bash

# add logical phones from wordlist ($2) to tiedlist ($1)

if [ "$#" != 2 ]; then
    echo "USAGE: $0 tiedlist wordlist"
    exit 1
fi

tiedlist=$1
shift
wordlist=$1
shift
fulllist="$wordlist.triphones"
wordlist2triphones.pl "$wordlist" > "$fulllist"
perl -I"$EV_homedir"lib -MHTKUtil -E "HTKUtil::add_phones(from => q{$fulllist}, to => q{$tiedlist})"
