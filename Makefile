eh=$(EV_homedir)
wd=$(EV_workdir)
reest_prereq=$(eh)resources/htk-config $(EV_train_mfcc)

EV_outdir?=recognizer/
train: $(wd)hmms/5-mixtures/hmmdefs $(wd)hmms/5-mixtures/macros $(wd)hmms/5-mixtures/phones
	mkdir -p "$(EV_outdir)"
	cp "$(eh)resources/htk-config" "$(wd)hmms/5-mixtures/hmmdefs" "$(wd)hmms/5-mixtures/macros" "$(wd)hmms/5-mixtures/phones" "$(EV_outdir)"

test: $(EV_outdir)hmmdefs $(EV_outdir)macros $(EV_outdir)phones $(wd)data/wordlist/test-unk-phonet $(EV_LM) $(EV_test_transcription) $(EV_test_mfcc)
	mkdir -p "$(wd)temp/test"
	hmmeval.pl --hmmdir "$(EV_outdir)" --workdir "$(wd)temp/test" --phones "$(EV_outdir)phones" --conf "$(eh)resources/htk-config" --wordlist "$(wd)data/wordlist/test-unk-phonet" --LM "$(EV_LM)" --trans "$(EV_test_transcription)" --mfccdir "$(EV_test_mfcc)" -t '100.0'

clean:
	rm -R "$(wd)data" "$(wd)hmms" "$(wd)temp" "$(wd)log"

model_to_add_mixtures_to?=$(wd)hmms/4-triphones
mixture_phones=$(model_to_add_mixtures_to)/phones
mixture_wordlist?=$(wd)data/wordlist/test-unk-triphonet
mixture_transcription?=$(wd)data/transcription/train/triphones.mlf
$(wd)hmms/5-mixtures/hmmdefs $(wd)hmms/5-mixtures/macros: $(model_to_add_mixtures_to)/hmmdefs $(model_to_add_mixtures_to)/macros $(mixture_phones) $(reest_prereq) $(mixture_wordlist) $(mixture_transcription) $(wd)data/phones/monophones
	mkdir -p "$(wd)hmms/5-mixtures"
	EV_HVite_s=5.0 EV_HVite_p=0.0 add-mixtures.pl -a $(mixture_opt)
	cat "$(wd)hmms/5-mixtures/winner/hmmdefs" > "$(wd)hmms/5-mixtures/hmmdefs"
	cat "$(wd)hmms/5-mixtures/winner/macros"  > "$(wd)hmms/5-mixtures/macros"
	cp "$(mixture_phones)" "$(wd)hmms/5-mixtures/phones"
	hmmeval.pl --hmmdir "$(wd)hmms/5-mixtures" --workdir "$(wd)temp/test" --phones "$(wd)hmms/5-mixtures/phones" --conf "$(eh)resources/htk-config" --wordlist "$(mixture_wordlist)" --LM "$(EV_LM)" --trans "$(wd)data/transcription/heldout.mlf" --mfccdir "$(EV_train_mfcc)"

EV_iter4?=$(EV_iter)
EV_iter4?=5
$(wd)hmms/4-triphones/hmmdefs $(wd)hmms/4-triphones/macros: $(wd)hmms/3-aligned/hmmdefs $(wd)hmms/3-aligned/macros $(wd)data/transcription/train/triphones.mlf $(wd)data/phones/monophones $(wd)data/phones/triphones $(EV_triphone_tree) $(wd)data/wordlist/test-unk-triphonet $(EV_wordlist_train_phonet)
	mkdir -p "$(wd)hmms/4-triphones/0-nontied/base" "$(wd)hmms/4-triphones/0-nontied/iterations" "$(wd)hmms/4-triphones/0-nontied/reestd" "$(wd)hmms/4-triphones/1-tied/base" "$(wd)hmms/4-triphones/1-tied/iterations"
	
	mkmktri.hed.pl < "$(wd)data/phones/monophones" > "$(wd)hmms/4-triphones/0-nontied/base/mktri.hed"
	mktree.hed.pl "$(eh)resources/tree.hed.tt" "$(EV_triphone_tree)" "$(wd)data/phones/monophones" > "$(wd)hmms/4-triphones/1-tied/base/tree.hed"
	
	LANG=C H HHEd -A -D -T 1 -H "$(wd)hmms/3-aligned/macros" -H "$(wd)hmms/3-aligned/hmmdefs" -M "$(wd)hmms/4-triphones/0-nontied/base" "$(wd)hmms/4-triphones/0-nontied/base/mktri.hed" "$(wd)data/phones/monophones"
	hmmiter.pl --iter "$(EV_iter4)" --indir "$(wd)hmms/4-triphones/0-nontied/base" --outdir "$(wd)hmms/4-triphones/0-nontied/reestd" --workdir "$(wd)hmms/4-triphones/0-nontied/iterations" --mfccdir "$(EV_train_mfcc)" --conf "$(eh)resources/htk-config" --mlf "$(wd)data/transcription/train/triphones.mlf" --phones "$(wd)data/phones/triphones"
	H HERest -A -D -T 1 -C "$(eh)resources/htk-config" -I "$(wd)data/transcription/train/triphones.mlf" -t $(EV_HERest_t) -s "$(wd)hmms/4-triphones/stats" -S "$(wd)hmms/4-triphones/0-nontied/iterations/mfcc.scp" -H "$(wd)hmms/4-triphones/0-nontied/reestd/macros" -H "$(wd)hmms/4-triphones/0-nontied/reestd/hmmdefs" -M "$(wd)hmms/4-triphones/0-nontied" "$(wd)data/phones/triphones"
	
	LANG=C H HHEd -H "$(wd)hmms/4-triphones/0-nontied/macros" -H "$(wd)hmms/4-triphones/0-nontied/hmmdefs" -M "$(wd)hmms/4-triphones/1-tied/base" "$(wd)hmms/4-triphones/1-tied/base/tree.hed" "$(wd)data/phones/triphones"
	hmmiter.pl --iter "$(EV_iter4)" --indir "$(wd)hmms/4-triphones/1-tied/base" --outdir "$(wd)hmms/4-triphones" --workdir "$(wd)hmms/4-triphones/1-tied/iterations" --mfccdir "$(EV_train_mfcc)" --conf "$(eh)resources/htk-config" --mlf "$(wd)data/transcription/train/triphones.mlf" --phones "$(wd)data/phones/tiedlist"
	
	hmmeval.pl --hmmdir "$(wd)hmms/4-triphones" --workdir "$(wd)temp/test" --phones "$(wd)hmms/4-triphones/phones" --conf "$(eh)resources/htk-config" --wordlist "$(wd)data/wordlist/test-unk-triphonet" --LM "$(EV_LM)" --trans "$(wd)data/transcription/heldout.mlf" --mfccdir "$(EV_train_mfcc)"

EV_HVite_t?=250.0
EV_iter3?=$(EV_iter)
EV_iter3?=2
$(wd)hmms/3-aligned/hmmdefs $(wd)hmms/3-aligned/macros $(wd)data/transcription/train/aligned.mlf: $(wd)hmms/2-sp/hmmdefs $(wd)hmms/2-sp/macros $(wd)data/transcription/train/trans.mlf $(reest_prereq) $(wd)data/wordlist/train-sp-sil-phonet $(wd)data/phones/monophones
	mkdir -p "$(wd)data/transcription/train" "$(wd)temp" "$(wd)hmms/3-aligned/iterations"
	step-align.pl \
                --indir="$(wd)hmms/2-sp" \
                --outdir="$(wd)hmms/3-aligned" \
                --tempdir="$(wd)temp" \
                --mfccdir="$(EV_train_mfcc)" \
                --conf="$(eh)resources/htk-config" \
                --train-mlf="$(wd)data/transcription/train/trans.mlf" \
                --out-mlf="$(wd)data/transcription/train/aligned.mlf" \
                --align-workdir="$(wd)temp" \
                --align-wordlist="$(wd)data/wordlist/train-sp-sil-phonet" \
                --phones="$(wd)data/phones/monophones" \
                --iter="$(EV_iter3)"

EV_iter2?=$(EV_iter)
EV_iter2?=2
$(wd)hmms/2-sp/hmmdefs $(wd)hmms/2-sp/macros: $(wd)hmms/1-init/hmmdefs $(wd)hmms/1-init/macros $(eh)resources/sil.hed $(wd)data/phones/monophones $(reest_prereq) $(wd)data/transcription/train/phonetic.mlf $(wd)data/wordlist/test-unk-phonet $(EV_LM) $(wd)data/transcription/heldout.mlf $(EV_train_mfcc)
	mkdir -p "$(wd)hmms/2-sp/iterations" "$(wd)hmms/2-sp/base1-sp-added" "$(wd)hmms/2-sp/base2-sp-sil-tied" "$(wd)temp/test"
	cp "$(wd)hmms/1-init/macros" "$(wd)hmms/2-sp/base1-sp-added/"
	step-sp.pl \
                --outdir="$(wd)hmms/2-sp" \
                --indir="$(wd)hmms/1-init" \
                --phones="$(wd)data/phones/monophones" \
                --iter="$(EV_iter2)" \
                --conf="$(eh)resources/htk-config" \
                --mfccdir="$(EV_train_mfcc)" \
                --train-mlf="$(wd)data/transcription/train/phonetic.mlf"

EV_iter1?=$(EV_iter)
EV_iter1?=2
$(wd)hmms/1-init/hmmdefs $(wd)hmms/1-init/macros: $(eh)resources/hmm/proto $(wd)data/phones/monophones-nosp $(reest_prereq) $(wd)data/transcription/train/phonetic-nosp.mlf $(wd)data/wordlist/test-unk-nosp-phonet $(EV_LM) $(wd)data/transcription/heldout.mlf $(EV_train_mfcc)
	mkdir -p "$(wd)hmms/1-init/aux" "$(wd)hmms/1-init/iterations" "$(wd)hmms/1-init/base" "$(wd)temp/test"
	step-init.pl \
                --workdir="$(wd)hmms/1-init" \
                --init-proto="$(eh)resources/hmm/proto" \
                --conf="$(eh)resources/htk-config" \
                --phones="$(wd)data/phones/monophones-nosp" \
                --mfccdir="$(EV_train_mfcc)" \
                --iter="$(EV_iter1)" \
                --train-mlf="$(wd)data/transcription/train/phonetic-nosp.mlf"

$(wd)data/wordlist/test-unk-triphonet: $(wd)data/phones/triphones $(wd)data/wordlist/test-unk-phonet
	triphonize-wordlist.pl "$(wd)data/phones/triphones" "$(wd)data/wordlist/test-unk-phonet" > "$(wd)data/wordlist/test-unk-triphonet"

$(wd)data/transcription/train/triphones.mlf: $(wd)data/phones/triphones $(wd)data/transcription/train/aligned.mlf
	triphonize-mlf.pl "$(wd)data/phones/triphones" < "$(wd)data/transcription/train/aligned.mlf" > "$(wd)data/transcription/train/triphones.mlf"

$(wd)data/transcription/train/phonetic.mlf: $(EV_wordlist_train_phonet) $(eh)resources/mkphones1.led $(wd)data/transcription/train/trans.mlf
	mkdir -p "$(wd)data/transcription/train" "$(wd)temp"
	LANG=C H HLEd -l '*' -d $(EV_wordlist_train_phonet) -i "$(wd)temp/phonetic-missing-sil.mlf" "$(eh)resources/mkphones1.led" "$(wd)data/transcription/train/trans.mlf"
	add-sil-to-empty-sentences.pl < "$(wd)temp/phonetic-missing-sil.mlf" > "$(wd)data/transcription/train/phonetic.mlf"

$(wd)data/transcription/train/phonetic-nosp.mlf: $(EV_wordlist_train_phonet) $(eh)resources/mkphones0.led $(wd)data/transcription/train/trans.mlf
	mkdir -p "$(wd)data/transcription/train" "$(wd)temp"
	LANG=C H HLEd -l '*' -d $(EV_wordlist_train_phonet) -i "$(wd)temp/phonetic-nosp-missing-sil.mlf" "$(eh)resources/mkphones0.led" "$(wd)data/transcription/train/trans.mlf"
	add-sil-to-empty-sentences.pl < "$(wd)temp/phonetic-nosp-missing-sil.mlf" > "$(wd)data/transcription/train/phonetic-nosp.mlf"

$(wd)data/wordlist/train-sp-sil-phonet: $(wd)data/wordlist/train-sil-phonet
	add-sil-variant.pl < "$(wd)data/wordlist/train-sil-phonet" > "$(wd)data/wordlist/train-sp-sil-phonet"

$(wd)data/wordlist/train-sil-phonet: $(EV_wordlist_train_phonet)
	mkdir -p "$(wd)data/wordlist"
	echo 'silence sil' > "$(wd)data/wordlist/train-sil-phonet"
	cat < "$(EV_wordlist_train_phonet)" >> "$(wd)data/wordlist/train-sil-phonet"

$(wd)data/phones/triphones: $(wd)data/transcription/train/aligned.mlf
	mkdir -p "$(wd)data/phones"
	count-triphones.pl < "$(wd)data/transcription/train/aligned.mlf" > "$(wd)data/phones/triphones"

$(wd)data/phones/monophones-nosp: $(wd)data/phones/monophones
	mkdir -p "$(wd)data/phones"
	grep -wv 'sp' < "$(wd)data/phones/monophones" > "$(wd)data/phones/monophones-nosp"

$(wd)data/phones/monophones: $(EV_wordlist_train_phonet)
	mkdir -p "$(wd)data/phones"
	wordlist2phones.pl "$(EV_wordlist_train_phonet)" "$(EV_wordlist_test_phonet)" > "$(wd)data/phones/monophones"

$(wd)data/wordlist/test-unk-nosp-phonet: $(wd)data/wordlist/test-unk-phonet
	perl -pe 's/\s*\bsp\b//' < "$(wd)data/wordlist/test-unk-phonet" > "$(wd)data/wordlist/test-unk-nosp-phonet"

$(wd)data/wordlist/test-unk-phonet: $(EV_wordlist_test_phonet)
	mkdir -p "$(wd)data/wordlist"
	echo '!!UNK  sil' > "$(wd)data/wordlist/test-unk-phonet"
	perl -pe 's/^(\S+\s+)sp$$/$$1sil/m' < "$(EV_wordlist_test_phonet)" >> "$(wd)data/wordlist/test-unk-phonet"

train_heldout_ratio?=19
$(wd)data/transcription/heldout.mlf $(wd)data/transcription/train/trans.mlf: $(EV_train_transcription)
	mkdir -p "$(wd)data/transcription/train"
	split-mlf.pl "$(EV_train_transcription)" "$(wd)data/transcription/train/trans.mlf=$(train_heldout_ratio)" "$(wd)data/transcription/heldout.mlf=1"
