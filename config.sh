#!/bin/bash

# HMM training
export EV_train_mfcc='given/data/mfcc/train'
export EV_heldout_mfcc='given/data/mfcc/heldout'
export EV_wordlist_train_phonet='given/data/wordlist/wl-train-phonet'
export EV_wordlist_test_phonet='given/data/wordlist/wl-test-phonet'
export EV_train_transcription='given/data/transcription/train.mlf'
export EV_heldout_transcription='given/data/transcription/heldout.mlf'
export EV_monophones='given/data/phones/monophones'
export EV_LM='given/data/LM/bg.lat'
export EV_use_triphones=''

if [ -z "$EV_use_triphones" ]; then
    export model_to_add_mixtures_to='hmms/3-aligned'
    export mixture_opt='-m'
    export mixture_phones="$EV_monophones"
fi


# Corpus2LM specific
export EV_corpus='given/data/corpus'

. bin/source.sh
