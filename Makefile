reest_prereq=resources/htk-config $(EV_train_mfcc)
model_to_add_mixtures_to?=hmms/4-triphones
mixture_phones?=data/phones/triphones

train: hmms/5-mixtures/hmmdefs

test: hmms/5-mixtures/hmmdefs hmms/5-mixtures/macros hmms/5-mixtures/phones data/wordlist/WORDLIST-test-unk-phonet $(EV_LM) $(EV_test_transcription) $(EV_test_mfcc)
	mkdir -p temp/test
	hmmeval.pl --hmmdir hmms/5-mixtures --workdir temp/test --phones hmms/5-mixtures/phones --conf resources/htk-config --wordlist data/wordlist/WORDLIST-test-unk-phonet --LM "$(EV_LM)" --trans "$(EV_test_transcription)" --mfccdir "$(EV_test_mfcc)" -t '100.0'

clean:
	rm -R data hmms temp log

hmms/5-mixtures/hmmdefs hmms/5-mixtures/macros: $(model_to_add_mixtures_to)/hmmdefs $(model_to_add_mixtures_to)/macros $(mixture_phones) $(reest_prereq) data/transcription/train/aligned.mlf data/phones/monophones data/wordlist/WORDLIST-test-unk-phonet
	mkdir -p hmms/5-mixtures
	EV_HVite_s=5.0 EV_HVite_p=0.0 add-mixtures.pl -a $(mixture_opt)
	cat hmms/5-mixtures/winner/hmmdefs > hmms/5-mixtures/hmmdefs
	cat hmms/5-mixtures/winner/macros  > hmms/5-mixtures/macros
	cp "$(mixture_phones)" hmms/5-mixtures/phones

hmms/3-aligned/hmmdefs hmms/3-aligned/macros data/transcription/train/aligned.mlf: hmms/2-sp/hmmdefs hmms/2-sp/macros $(EV_train_transcription) $(reest_prereq) data/wordlist/WORDLIST-train-sil-phonet data/phones/monophones
	mkdir -p data/transcription/train temp hmms/3-aligned/iterations
	mlf2scp.pl "$(EV_train_mfcc)/*.mfcc" < "$(EV_train_transcription)" > temp/train-mfc.scp
	LANG=C H HVite -T 1 -A -D -l '*' -C resources/htk-config -t "$(EV_HVite_t)" -H hmms/2-sp/macros -H hmms/2-sp/hmmdefs -S temp/train-mfc.scp -i temp/trancription-aligned-with-empty.mlf -m -I "$(EV_train_transcription)" -y lab -a -o SWT -b silence data/wordlist/WORDLIST-train-sil-phonet data/phones/monophones
	remove-empty-sentences-from-mlf.pl < temp/trancription-aligned-with-empty.mlf > data/transcription/train/aligned.mlf
	hmmiter.pl --iter 3 --indir hmms/2-sp --outdir hmms/3-aligned --workdir hmms/3-aligned/iterations --mfccdir "$(EV_train_mfcc)" --conf resources/htk-config --mlf data/transcription/train/aligned.mlf --phones data/phones/monophones
	hmmeval.pl --hmmdir hmms/3-aligned --workdir temp/test --phones hmms/3-aligned/phones --conf resources/htk-config --wordlist data/wordlist/WORDLIST-test-unk-phonet --LM "$(EV_LM)" --trans "$(EV_heldout_transcription)" --mfccdir "$(EV_heldout_mfcc)"

hmms/2-sp/hmmdefs hmms/2-sp/macros: hmms/1-init/hmmdefs hmms/1-init/macros resources/sil.hed data/phones/monophones $(reest_prereq) data/transcription/train/phonetic-nosp.mlf data/wordlist/WORDLIST-test-unk-phonet $(EV_LM) $(EV_heldout_transcription) $(EV_heldout_mfcc)
	mkdir -p hmms/2-sp/iterations hmms/2-sp/base1-sp-added hmms/2-sp/base2-sp-sil-tied temp/test
	cp hmms/1-init/macros hmms/2-sp/base1-sp-added/
	add-sp.pl < hmms/1-init/hmmdefs > hmms/2-sp/base1-sp-added/hmmdefs
	H HHEd -T 1 -A -D -H hmms/2-sp/base1-sp-added/macros -H hmms/2-sp/base1-sp-added/hmmdefs -M hmms/2-sp/base2-sp-sil-tied resources/sil.hed data/phones/monophones
	hmmiter.pl --iter 3 --indir hmms/2-sp/base2-sp-sil-tied --outdir hmms/2-sp --workdir hmms/2-sp/iterations --conf resources/htk-config --mfccdir "$(EV_train_mfcc)" --mlf "data/transcription/train/phonetic-nosp.mlf" --phones data/phones/monophones
	hmmeval.pl --hmmdir hmms/2-sp --workdir temp/test --phones hmms/2-sp/phones --conf resources/htk-config --wordlist data/wordlist/WORDLIST-test-unk-phonet --LM "$(EV_LM)" --trans "$(EV_heldout_transcription)" --mfccdir "$(EV_heldout_mfcc)"

hmms/1-init/hmmdefs hmms/1-init/macros: resources/hmm/proto data/phones/monophones-nosp $(reest_prereq) data/transcription/train/phonetic-nosp.mlf data/wordlist/WORDLIST-test-unk-nosp-phonet $(EV_LM) $(EV_heldout_transcription) $(EV_heldout_mfcc)
	mkdir -p hmms/1-init/aux hmms/1-init/iterations hmms/1-init/base temp/test
	init-hmm.pl -t hmms/1-init/aux resources/hmm/proto resources/htk-config data/phones/monophones-nosp "$(EV_train_mfcc)" hmms/1-init/base
	hmmiter.pl --iter 3 --indir hmms/1-init/base --outdir hmms/1-init --workdir hmms/1-init/iterations --conf resources/htk-config --mfccdir "$(EV_train_mfcc)" --mlf "data/transcription/train/phonetic-nosp.mlf"
	hmmeval.pl --hmmdir hmms/1-init --workdir temp/test --phones hmms/1-init/phones --conf resources/htk-config --wordlist data/wordlist/WORDLIST-test-unk-nosp-phonet --LM "$(EV_LM)" --trans "$(EV_heldout_transcription)" --mfccdir "$(EV_heldout_mfcc)"

data/transcription/train/phonetic-nosp.mlf: $(EV_wordlist_train_phonet) resources/mkphones0.led $(EV_train_transcription)
	mkdir -p data/transcription/train temp
	LANG=C H HLEd -l '*' -d $(EV_wordlist_train_phonet) -i temp/phonetic-nosp-missing-sil.mlf resources/mkphones0.led $(EV_train_transcription)
	add-sil-to-empty-sentences.pl < temp/phonetic-nosp-missing-sil.mlf > data/transcription/train/phonetic-nosp.mlf

data/wordlist/WORDLIST-train-sil-phonet: $(EV_wordlist_train_phonet)
	mkdir -p data/wordlist
	echo 'silence sil' > data/wordlist/WORDLIST-train-sil-phonet
	cat < "$(EV_wordlist_train_phonet)" >> "data/wordlist/WORDLIST-train-sil-phonet"

data/phones/monophones-nosp: data/phones/monophones
	mkdir -p data/phones
	grep -wv 'sp' < data/phones/monophones > data/phones/monophones-nosp

data/phones/monophones: $(EV_wordlist_train_phonet)
	mkdir -p data/phones
	wordlist2phones.pl "$(EV_wordlist_train_phonet)" "$(EV_wordlist_test_phonet)" > data/phones/monophones

data/wordlist/WORDLIST-test-unk-nosp-phonet: data/wordlist/WORDLIST-test-unk-phonet
	perl -pe 's/\s*\bsp\b//' < data/wordlist/WORDLIST-test-unk-phonet > data/wordlist/WORDLIST-test-unk-nosp-phonet

data/wordlist/WORDLIST-test-unk-phonet: $(EV_wordlist_test_phonet)
	mkdir -p data/wordlist
	echo '!!UNK  sil' > data/wordlist/WORDLIST-test-unk-phonet
	perl -pe 's/^(\S+\s+)sp$$/$$1sil/m' < "$(EV_wordlist_test_phonet)" >> data/wordlist/WORDLIST-test-unk-phonet
