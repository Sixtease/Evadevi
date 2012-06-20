#!/bin/bash

export EV_homedir=~/git/Evadevi/
export EV_workdir=~/temp/evadevi/

# HMM training
export EV_train_mfcc="${EV_homedir}given/data/mfcc/train"
export EV_test_mfcc="${EV_homedir}given/data/mfcc/test"
export EV_wordlist_train_phonet="${EV_homedir}given/data/wordlist/wl-train-phonet"
export EV_wordlist_test_phonet="${EV_homedir}given/data/wordlist/wl-test-phonet"
export EV_train_transcription="${EV_homedir}given/data/transcription/train.mlf"
export EV_test_transcription="${EV_homedir}given/data/transcription/test.mlf"
export EV_LM="${EV_homedir}given/data/LM/bg.lat"

export EV_use_triphones=''
export EV_heldout_ratio=20
export EV_min_mixtures=8

export EV_HVite_p='8.0'
export EV_HVite_s='6.0'
export EV_HVite_t='150.0'

if [ -z "$EV_use_triphones" ]; then
    export model_to_add_mixtures_to="${EV_workdir}hmms/3-aligned"
    export mixture_opt='-m'
    export mixture_phones="${EV_workdir}data/phones/monophones"
fi
export train_heldout_ratio=$((EV_heldout_ratio - 1))


# Corpus2LM specific
export EV_corpus="${EV_homedir}given/data/corpus"

. bin/source.sh
