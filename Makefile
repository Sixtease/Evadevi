reest_prereq=bin/hmmiter.pl resources/htk-config $(EV_train_mfcc)
model_to_add_mixtures_to?=hmms/4-triphones
mixture_phones?=data/phones/triphones

train: hmms/5-mixtures/hmmdefs

test: hmms/5-mixtures/hmmdefs hmms/5-mixtures/macros hmms/5-mixtures/phones $(EV_LM) $(EV_wordlist_test_phonet) $(EV_test_transcription) $(EV_test_mfcc)
	bin/hmmeval.pl --hmmdir hmms/5-mixtures --phones hmms/5-mixtures/phones --conf resources/htk-config --LM "$(EV_LM)" --wordlist "$(EV_wordlist_test_phonet)" --trans "$(EV_test_transcription)" --mfccdir "$(EV_test_mfcc)"

clean:
	rm -R data hmms temp log

hmms/5-mixtures/hmmdefs hmms/5-mixtures/macros: $(model_to_add_mixtures_to)/hmmdefs $(model_to_add_mixtures_to)/macros $(mixture_phones) $(reest_prereq) data/transcription/train/aligned.mlf $(EV_monophones)
	mkdir -p hmms/5-mixtures
	bin/add-mixtures.pl -a $(mixture_opt)
	cat hmms/5-mixtures/winner/hmmdefs > hmms/5-mixtures/hmmdefs
	cat hmms/5-mixtures/winner/macros  > hmms/5-mixtures/macros
	cp "$(mixture_phones)" hmms/5-mixtures/phones

hmms/3-aligned/hmmdefs hmms/3-aligned/macros data/transcription/train/aligned.mlf: hmms/2-sp/hmmdefs hmms/2-sp/macros $(EV_train_transcription) $(reest_prereq) bin/generate-scp.pl data/wordlist/WORDLIST-train-sil-phonet bin/remove-empty-sentences-from-mlf.pl $(EV_monophones)
	mkdir -p data/transcription/train temp hmms/3-aligned/iterations
	bin/mlf2scp.pl "$(EV_train_mfcc)/*.mfcc" < "$(EV_train_transcription)" > temp/train-mfc.scp
	LANG=C H HVite -T 1 -A -D -l '*' -C resources/htk-config -t 250.0 -H hmms/2-sp/macros -H hmms/2-sp/hmmdefs -S temp/train-mfc.scp -i temp/trancription-aligned-with-empty.mlf -m -I "$(EV_train_transcription)" -y lab -a -o SWT -b silence data/wordlist/WORDLIST-train-sil-phonet "$(EV_monophones)"
	bin/remove-empty-sentences-from-mlf.pl < temp/trancription-aligned-with-empty.mlf > data/transcription/train/aligned.mlf
	bin/hmmiter.pl --iter 9 --indir hmms/2-sp --outdir hmms/3-aligned --workdir hmms/3-aligned/iterations --mfccdir "$(EV_train_mfcc)" --conf resources/htk-config --mlf data/transcription/train/aligned.mlf --phones "$(EV_monophones)"

hmms/2-sp/hmmdefs hmms/2-sp/macros: bin/add-sp.pl hmms/1-init/hmmdefs hmms/1-init/macros resources/sil.hed $(EV_monophones) $(reest_prereq) data/transcription/train/phonetic-nosp.mlf
	mkdir -p hmms/2-sp/iterations hmms/2-sp/base1-sp-added hmms/2-sp/base2-sp-sil-tied
	cp hmms/1-init/macros hmms/2-sp/base1-sp-added/
	bin/add-sp.pl < hmms/1-init/hmmdefs > hmms/2-sp/base1-sp-added/hmmdefs
	H HHEd -T 1 -A -D -H hmms/2-sp/base1-sp-added/macros -H hmms/2-sp/base1-sp-added/hmmdefs -M hmms/2-sp/base2-sp-sil-tied resources/sil.hed "$(EV_monophones)"
	bin/hmmiter.pl --iter 5 --indir hmms/2-sp/base2-sp-sil-tied --outdir hmms/2-sp --workdir hmms/2-sp/iterations --conf resources/htk-config --mfccdir "$(EV_train_mfcc)" --mlf "data/transcription/train/phonetic-nosp.mlf" --phones "$(EV_monophones)"

hmms/1-init/hmmdefs hmms/1-init/macros: bin/init-hmm.pl resources/hmm/proto data/phones/monophones-nosp $(reest_prereq) data/transcription/train/phonetic-nosp.mlf
	mkdir -p hmms/1-init/aux hmms/1-init/iterations hmms/1-init/base
	bin/init-hmm.pl -t hmms/1-init/aux resources/hmm/proto resources/htk-config data/phones/monophones-nosp "$(EV_train_mfcc)" hmms/1-init/base
	bin/hmmiter.pl --iter 3 --indir hmms/1-init/base --outdir hmms/1-init --workdir hmms/1-init/iterations --conf resources/htk-config --mfccdir "$(EV_train_mfcc)" --mlf "data/transcription/train/phonetic-nosp.mlf"

data/transcription/train/phonetic-nosp.mlf: $(EV_wordlist_train_phonet) resources/mkphones0.led $(EV_train_transcription) bin/add-sil-to-empty-sentences.pl
	mkdir -p data/transcription/train temp
	LANG=C H HLEd -l '*' -d $(EV_wordlist_train_phonet) -i temp/phonetic-nosp-missing-sil.mlf resources/mkphones0.led $(EV_train_transcription)
	bin/add-sil-to-empty-sentences.pl < temp/phonetic-nosp-missing-sil.mlf > data/transcription/train/phonetic-nosp.mlf

data/wordlist/WORDLIST-train-sil-phonet: $(EV_wordlist_train_phonet)
	mkdir -p data/wordlist
	echo 'silence sil' > data/wordlist/WORDLIST-train-sil-phonet
	cat < "$(EV_wordlist_train_phonet)" >> "data/wordlist/WORDLIST-train-sil-phonet"

data/phones/monophones-nosp: $(EV_monophones)
	mkdir -p data/phones
	grep -wv 'sp' < "$(EV_monophones)" > data/phones/monophones-nosp
