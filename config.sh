#!/bin/bash

if [ -z "$EV_use_triphones" ]; then
    export model_to_add_mixtures_to="${EV_workdir}hmms/3-aligned"
    export mixture_opt='-m'
	export mixture_wordlist="${EV_workdir}data/wordlist/test-unk-phonet"
	export mixture_transcription="${EV_workdir}data/transcription/train/aligned.mlf"
fi
if [ -z "$EV_heldout_ratio" ]; then
    export train_heldout_ratio=19
else
    export train_heldout_ratio=$((EV_heldout_ratio - 1))
fi

if [ -x hmmiter.pl ]; then : ; else
    export PATH="${EV_homedir}bin:$PATH"
fi
