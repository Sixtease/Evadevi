reest_prereq=bin/hmmiter.pl resources/htk-config $(EV_train_mfcc) $(EV_train_phonetic_transcription)

clean:
	rm -R data hmms

hmms/2-sp/hmmdefs hmms/2-sp/macros: bin/add-sp.pl hmms/1-init/hmmdefs hmms/1-init/macros resources/sil.hed $(EV_monophones) $(reest_prereq)
	mkdir -p hmms/2-sp/iterations hmms/2-sp/base1-sp-added hmms/2-sp/base2-sp-sil-tied
	cp hmms/1-init/macros hmms/2-sp/base1-sp-added/
	bin/add-sp.pl < hmms/1-init/hmmdefs > hmms/2-sp/base1-sp-added/hmmdefs
	HHEd -T 1 -A -D -H hmms/2-sp/base1-sp-added/macros -H hmms/2-sp/base1-sp-added/hmmdefs -M hmms/2-sp/base2-sp-sil-tied resources/sil.hed "$(EV_monophones)"
	bin/hmmiter.pl --iter 5 --indir hmms/2-sp/base2-sp-sil-tied --outdir hmms/2-sp --workdir hmms/2-sp/iterations --conf resources/htk-config --mfcc "$(EV_train_mfcc)" --mlf "$(EV_train_phonetic_transcription)" --phones "$(EV_monophones)"

hmms/1-init/hmmdefs hmms/1-init/macros: bin/init-hmm.pl resources/hmm/proto data/phones/monophones-nosp $(reest_prereq)
	mkdir -p hmms/1-init/aux hmms/1-init/iterations hmms/1-init/base
	bin/init-hmm.pl -t hmms/1-init/aux resources/hmm/proto resources/htk-config data/phones/monophones-nosp "$(EV_train_mfcc)" hmms/1-init/base
	bin/hmmiter.pl --iter 3 --indir hmms/1-init/base --outdir hmms/1-init --workdir hmms/1-init/iterations --conf resources/htk-config --mfcc "$(EV_train_mfcc)" --mlf "$(EV_train_phonetic_transcription)"

data/phones/monophones-nosp: $(EV_monophones)
	mkdir -p data/phones
	grep -wv 'sp' < "$(EV_monophones)" > data/phones/monophones-nosp
