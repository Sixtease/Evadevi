eh=$(EV_homedir)
wd=$(EV_workdir)
reest_prereq=$(eh)resources/htk-config $(EV_train_mfcc)
model_to_add_mixtures_to?=$(wd)hmms/4-triphones
mixture_phones?=$(wd)data/phones/triphones

EV_outdir?=recognizer/
train: $(wd)hmms/5-mixtures/hmmdefs $(wd)hmms/5-mixtures/macros $(wd)hmms/5-mixtures/phones
	mkdir -p "$(EV_outdir)"
	cp "$(wd)hmms/5-mixtures/hmmdefs" "$(wd)hmms/5-mixtures/macros" "$(wd)hmms/5-mixtures/phones" "$(EV_outdir)"

test: $(wd)hmms/5-mixtures/hmmdefs $(wd)hmms/5-mixtures/macros $(wd)hmms/5-mixtures/phones $(wd)data/wordlist/WORDLIST-test-unk-phonet $(EV_LM) $(EV_test_transcription) $(EV_test_mfcc)
	mkdir -p "$(wd)temp/test"
	hmmeval.pl --hmmdir "$(wd)hmms/5-mixtures" --workdir "$(wd)temp/test" --phones "$(wd)hmms/5-mixtures/phones" --conf "$(eh)resources/htk-config" --wordlist "$(wd)data/wordlist/WORDLIST-test-unk-phonet" --LM "$(EV_LM)" --trans "$(EV_test_transcription)" --mfccdir "$(EV_test_mfcc)" -t '100.0'

clean:
	rm -R "$(wd)data" "$(wd)hmms" "$(wd)temp" "$(wd)log"

$(wd)hmms/5-mixtures/hmmdefs $(wd)hmms/5-mixtures/macros: $(model_to_add_mixtures_to)/hmmdefs $(model_to_add_mixtures_to)/macros $(mixture_phones) $(reest_prereq) $(wd)data/transcription/train/aligned.mlf $(wd)data/phones/monophones $(wd)data/wordlist/WORDLIST-test-unk-phonet
	mkdir -p "$(wd)hmms/5-mixtures"
	EV_HVite_s=5.0 EV_HVite_p=0.0 add-mixtures.pl -a $(mixture_opt)
	cat "$(wd)hmms/5-mixtures/winner/hmmdefs" > "$(wd)hmms/5-mixtures/hmmdefs"
	cat "$(wd)hmms/5-mixtures/winner/macros"  > "$(wd)hmms/5-mixtures/macros"
	cp "$(mixture_phones)" "$(wd)hmms/5-mixtures/phones"

$(wd)hmms/3-aligned/hmmdefs $(wd)hmms/3-aligned/macros $(wd)data/transcription/train/aligned.mlf: $(wd)hmms/2-sp/hmmdefs $(wd)hmms/2-sp/macros $(wd)data/transcription/train/trans.mlf $(reest_prereq) $(wd)data/wordlist/WORDLIST-train-sil-phonet $(wd)data/phones/monophones
	mkdir -p "$(wd)data/transcription/train" "$(wd)temp" "$(wd)hmms/3-aligned/iterations"
	mlf2scp.pl "$(EV_train_mfcc)/*.mfcc" < "$(wd)data/transcription/train/trans.mlf" > "$(wd)temp/train-mfc.scp"
	LANG=C H HVite -T 1 -A -D -l '*' -C "$(eh)resources/htk-config" -t "$(EV_HVite_t)" -H "$(wd)hmms/2-sp/macros" -H "$(wd)hmms/2-sp/hmmdefs" -S "$(wd)temp/train-mfc.scp" -i "$(wd)temp/trancription-aligned-with-empty.mlf" -m -I "$(wd)data/transcription/train/trans.mlf" -y lab -a -o SWT -b silence "$(wd)data/wordlist/WORDLIST-train-sil-phonet" "$(wd)data/phones/monophones"
	remove-empty-sentences-from-mlf.pl < "$(wd)temp/trancription-aligned-with-empty.mlf" > "$(wd)data/transcription/train/aligned.mlf"
	hmmiter.pl --iter 7 --indir "$(wd)hmms/2-sp" --outdir "$(wd)hmms/3-aligned" --workdir "$(wd)hmms/3-aligned/iterations" --mfccdir "$(EV_train_mfcc)" --conf "$(eh)resources/htk-config" --mlf "$(wd)data/transcription/train/aligned.mlf" --phones "$(wd)data/phones/monophones"
	hmmeval.pl --hmmdir "$(wd)hmms/3-aligned" --workdir "$(wd)temp/test" --phones "$(wd)hmms/3-aligned/phones" --conf "$(eh)resources/htk-config" --wordlist "$(wd)data/wordlist/WORDLIST-test-unk-phonet" --LM "$(EV_LM)" --trans "$(wd)data/transcription/heldout.mlf" --mfccdir "$(EV_train_mfcc)"

$(wd)hmms/2-sp/hmmdefs $(wd)hmms/2-sp/macros: $(wd)hmms/1-init/hmmdefs $(wd)hmms/1-init/macros $(eh)resources/sil.hed $(wd)data/phones/monophones $(reest_prereq) $(wd)data/transcription/train/phonetic-nosp.mlf $(wd)data/wordlist/WORDLIST-test-unk-phonet $(EV_LM) $(wd)data/transcription/heldout.mlf $(EV_train_mfcc)
	mkdir -p "$(wd)hmms/2-sp/iterations" "$(wd)hmms/2-sp/base1-sp-added" "$(wd)hmms/2-sp/base2-sp-sil-tied" "$(wd)temp/test"
	cp "$(wd)hmms/1-init/macros" "$(wd)hmms/2-sp/base1-sp-added/"
	add-sp.pl < "$(wd)hmms/1-init/hmmdefs" > "$(wd)hmms/2-sp/base1-sp-added/hmmdefs"
	H HHEd -T 1 -A -D -H "$(wd)hmms/2-sp/base1-sp-added/macros" -H "$(wd)hmms/2-sp/base1-sp-added/hmmdefs" -M "$(wd)hmms/2-sp/base2-sp-sil-tied" "$(eh)resources/sil.hed" "$(wd)data/phones/monophones"
	hmmiter.pl --iter 5 --indir "$(wd)hmms/2-sp/base2-sp-sil-tied" --outdir "$(wd)hmms/2-sp" --workdir "$(wd)hmms/2-sp/iterations" --conf "$(eh)resources/htk-config" --mfccdir "$(EV_train_mfcc)" --mlf "$(wd)data/transcription/train/phonetic-nosp.mlf" --phones "$(wd)data/phones/monophones"
	hmmeval.pl --hmmdir "$(wd)hmms/2-sp" --workdir "$(wd)temp/test" --phones "$(wd)hmms/2-sp/phones" --conf "$(eh)resources/htk-config" --wordlist "$(wd)data/wordlist/WORDLIST-test-unk-phonet" --LM "$(EV_LM)" --trans "$(wd)data/transcription/heldout.mlf" --mfccdir "$(EV_train_mfcc)"

$(wd)hmms/1-init/hmmdefs $(wd)hmms/1-init/macros: $(eh)resources/hmm/proto $(wd)data/phones/monophones-nosp $(reest_prereq) $(wd)data/transcription/train/phonetic-nosp.mlf $(wd)data/wordlist/WORDLIST-test-unk-nosp-phonet $(EV_LM) $(wd)data/transcription/heldout.mlf $(EV_train_mfcc)
	mkdir -p "$(wd)hmms/1-init/aux" "$(wd)hmms/1-init/iterations" "$(wd)hmms/1-init/base" "$(wd)temp/test"
	init-hmm.pl -t "$(wd)hmms/1-init/aux" "$(eh)resources/hmm/proto" "$(eh)resources/htk-config" "$(wd)data/phones/monophones-nosp" "$(EV_train_mfcc)" "$(wd)hmms/1-init/base"
	hmmiter.pl --iter 3 --indir "$(wd)hmms/1-init/base" --outdir "$(wd)hmms/1-init" --workdir "$(wd)hmms/1-init/iterations" --conf "$(eh)resources/htk-config" --mfccdir "$(EV_train_mfcc)" --mlf "$(wd)data/transcription/train/phonetic-nosp.mlf"
	hmmeval.pl --hmmdir "$(wd)hmms/1-init" --workdir "$(wd)temp/test" --phones "$(wd)hmms/1-init/phones" --conf "$(eh)resources/htk-config" --wordlist "$(wd)data/wordlist/WORDLIST-test-unk-nosp-phonet" --LM "$(EV_LM)" --trans "$(wd)data/transcription/heldout.mlf" --mfccdir "$(EV_train_mfcc)"

$(wd)data/transcription/train/phonetic-nosp.mlf: $(EV_wordlist_train_phonet) $(eh)resources/mkphones0.led $(wd)data/transcription/train/trans.mlf
	mkdir -p "$(wd)data/transcription/train" "$(wd)temp"
	LANG=C H HLEd -l '*' -d $(EV_wordlist_train_phonet) -i "$(wd)temp/phonetic-nosp-missing-sil.mlf" "$(eh)resources/mkphones0.led" "$(wd)data/transcription/train/trans.mlf"
	add-sil-to-empty-sentences.pl < "$(wd)temp/phonetic-nosp-missing-sil.mlf" > "$(wd)data/transcription/train/phonetic-nosp.mlf"

$(wd)data/wordlist/WORDLIST-train-sil-phonet: $(EV_wordlist_train_phonet)
	mkdir -p "$(wd)data/wordlist"
	echo 'silence sil' > "$(wd)data/wordlist/WORDLIST-train-sil-phonet"
	cat < "$(EV_wordlist_train_phonet)" >> "$(wd)data/wordlist/WORDLIST-train-sil-phonet"

$(wd)data/phones/monophones-nosp: $(wd)data/phones/monophones
	mkdir -p "$(wd)data/phones"
	grep -wv 'sp' < "$(wd)data/phones/monophones" > "$(wd)data/phones/monophones-nosp"

$(wd)data/phones/monophones: $(EV_wordlist_train_phonet)
	mkdir -p "$(wd)data/phones"
	wordlist2phones.pl "$(EV_wordlist_train_phonet)" "$(EV_wordlist_test_phonet)" > "$(wd)data/phones/monophones"

$(wd)data/wordlist/WORDLIST-test-unk-nosp-phonet: $(wd)data/wordlist/WORDLIST-test-unk-phonet
	perl -pe 's/\s*\bsp\b//' < "$(wd)data/wordlist/WORDLIST-test-unk-phonet" > "$(wd)data/wordlist/WORDLIST-test-unk-nosp-phonet"

$(wd)data/wordlist/WORDLIST-test-unk-phonet: $(EV_wordlist_test_phonet)
	mkdir -p "$(wd)data/wordlist"
	echo '!!UNK  sil' > "$(wd)data/wordlist/WORDLIST-test-unk-phonet"
	perl -pe 's/^(\S+\s+)sp$$/$$1sil/m' < "$(EV_wordlist_test_phonet)" >> "$(wd)data/wordlist/WORDLIST-test-unk-phonet"

train_heldout_ratio?=19
$(wd)data/transcription/heldout.mlf $(wd)data/transcription/train/trans.mlf: $(EV_train_transcription)
	mkdir -p "$(wd)data/transcription/train"
	split-mlf.pl "$(EV_train_transcription)" "$(wd)data/transcription/train/trans.mlf=$(train_heldout_ratio)" "$(wd)data/transcription/heldout.mlf=1"
