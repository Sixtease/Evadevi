clean:
	rm -R data hmms

hmms/1-init/hmmdefs hmms/1-init/macros: bin/init-hmm.pl resources/hmm/proto resources/htk-config data/phones/monophones-nosp $(EV_train_mfcc) bin/hmmiter.pl $(EV_train_phonetic_transcription) 
	mkdir -p hmms/1-init/aux hmms/1-init/iterations hmms/1-init/base
	bin/init-hmm.pl -t hmms/1-init/aux resources/hmm/proto resources/htk-config data/phones/monophones-nosp "$(EV_train_mfcc)" hmms/1-init/base
	bin/hmmiter.pl --iter 3 --indir hmms/1-init/base --outdir hmms/1-init --workdir hmms/1-init/iterations --conf resources/htk-config --mfcc "$(EV_train_mfcc)" --mlf "$(EV_train_phonetic_transcription)"

data/phones/monophones-nosp: $(EV_monophones)
	mkdir -p data/phones
	grep -wv 'sp' < "$(EV_monophones)" > data/phones/monophones-nosp
