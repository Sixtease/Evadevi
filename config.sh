#!/bin/bash

export EV_workdir=~/temp/evadevi/

# HMM training
export EV_train_mfcc='given/data/mfcc/train'
export EV_test_mfcc='given/data/mfcc/test'
export EV_wordlist_train_phonet='given/data/wordlist/wl-train-phonet'
export EV_wordlist_test_phonet='given/data/wordlist/wl-test-phonet'
export EV_train_transcription='given/data/transcription/train.mlf'
export EV_test_transcription='given/data/transcription/test.mlf'
export EV_LM='given/data/LM/bg.lat'

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
export EV_corpus='given/data/corpus'

. bin/source.sh
