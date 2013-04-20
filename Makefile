eh=$(EV_homedir)
wd=$(EV_workdir)
reest_prereq=$(eh)resources/htk-config $(EV_train_mfcc)

EV_outdir?=recognizer/
train: $(wd)hmms/6-mixtures/hmmdefs $(wd)hmms/6-mixtures/macros $(wd)hmms/6-mixtures/phones
	mkdir -p "$(EV_outdir)"
	cp "$(eh)resources/htk-config" "$(wd)hmms/6-mixtures/hmmdefs" "$(wd)hmms/6-mixtures/macros" "$(wd)hmms/6-mixtures/phones" "$(EV_outdir)"
	cat "$(wd)hmms/6-mixtures/macros" "$(wd)hmms/6-mixtures/hmmdefs" > "$(EV_outdir)hmmmodels"

test: $(EV_outdir)hmmdefs $(EV_outdir)macros $(EV_outdir)phones $(wd)data/wordlist/test-unk-phonet $(EV_test_transcription) $(EV_test_mfcc)
	mkdir -p "$(wd)temp/test"
	hmmeval.pl --hmmdir "$(EV_outdir)" --workdir "$(wd)temp/test" --phones "$(EV_outdir)phones" --conf "$(eh)resources/htk-config" --wordlist "$(wd)data/wordlist/test-unk-phonet" --LMf "$(EV_LMf)" --LMb "$(EV_LMb)" --trans "$(EV_test_transcription)" --mfccdir "$(EV_test_mfcc)" -t '100.0'

clean:
	rm -R "$(wd)data" "$(wd)hmms" "$(wd)temp" "$(wd)log"

model_to_add_mixtures_to?=$(wd)hmms/5-triphones
mixture_wordlist?=$(wd)data/wordlist/test-unk-phonet
mixture_transcription?=$(wd)data/transcription/train/triphones.mlf
$(wd)hmms/6-mixtures/hmmdefs $(wd)hmms/6-mixtures/macros: $(model_to_add_mixtures_to)/hmmdefs $(model_to_add_mixtures_to)/macros $(model_to_add_mixtures_to)/phones $(reest_prereq) $(mixture_wordlist) $(mixture_transcription) $(wd)data/phones/monophones
	mkdir -p "$(wd)hmms/6-mixtures"
	step-mixtures.pl \
                --indir="$(model_to_add_mixtures_to)" \
                --outdir="$(wd)hmms/6-mixtures" \
                --mfccdir="$(EV_train_mfcc)" \
                --wordlist="$(wd)data/wordlist/test-unk-phonet" \
                --conf="$(eh)resources/htk-config"

$(wd)hmms/5-triphones/hmmdefs $(wd)hmms/5-triphones/macros $(wd)data/phones/tiedlist: $(wd)hmms/4-var/hmmdefs $(wd)hmms/4-var/macros $(wd)data/transcription/train/triphones.mlf $(wd)data/phones/monophones $(wd)data/phones/triphones $(wd)data/phones/fulllist $(EV_triphone_tree) $(EV_wordlist_train_phonet)
	mkdir -p "$(wd)hmms/5-triphones/0-nontied/base" "$(wd)hmms/5-triphones/0-nontied/iterations" "$(wd)hmms/5-triphones/0-nontied/reestd" "$(wd)hmms/5-triphones/1-tied/base" "$(wd)hmms/5-triphones/1-tied/iterations"
	step-triphones.pl \
                --monophones="$(wd)data/phones/monophones" \
                --triphones="$(wd)data/phones/triphones" \
                --tiedlist="$(wd)data/phones/tiedlist" \
                --fulllist="$(wd)data/phones/fulllist" \
                --indir="$(wd)hmms/4-var" \
                --outdir="$(wd)hmms/5-triphones" \
                --mfccdir="$(EV_train_mfcc)" \
                --conf="$(eh)resources/htk-config" \
                --tree-hed-tmpl="$(eh)resources/tree.hed.tt" \
                --triphone-tree="$(EV_triphone_tree)" \
                --mlf="$(wd)data/transcription/train/triphones.mlf"

$(wd)hmms/4-var/hmmdefs $(wd)hmms/4-var/macros: $(wd)hmms/3-aligned/hmmdefs $(wd)hmms/3-aligned/macros $(wd)data/transcription/train/aligned.mlf
	mkdir -p "$(wd)hmms/4-var/aux" "$(wd)hmms/4-var/iterations" "$(wd)hmms/4-var/base" "$(wd)hmms/4-var/var"
	step-recalculate-variance.pl \
                --conf="$(eh)resources/htk-config" \
                --indir="$(wd)hmms/3-aligned" \
                --outdir="$(wd)hmms/4-var" \
                --mfccdir="$(EV_train_mfcc)" \
                --mlf="$(wd)data/transcription/train/aligned.mlf" \
                --proto="$(eh)resources/hmm/proto"

EV_HVite_t?=250.0
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

$(wd)hmms/2-sp/hmmdefs $(wd)hmms/2-sp/macros: $(wd)hmms/1-init/hmmdefs $(wd)hmms/1-init/macros $(eh)resources/sil.hed $(wd)data/phones/monophones $(reest_prereq) $(wd)data/transcription/train/phonetic.mlf $(wd)data/wordlist/test-unk-phonet $(wd)data/transcription/heldout.mlf $(EV_train_mfcc)
	mkdir -p "$(wd)hmms/2-sp/iterations" "$(wd)hmms/2-sp/base1-sp-added" "$(wd)hmms/2-sp/base2-sp-sil-tied" "$(wd)temp/test"
	cp "$(wd)hmms/1-init/macros" "$(wd)hmms/2-sp/base1-sp-added/"
	step-sp.pl \
                --outdir="$(wd)hmms/2-sp" \
                --indir="$(wd)hmms/1-init" \
                --phones="$(wd)data/phones/monophones" \
                --conf="$(eh)resources/htk-config" \
                --mfccdir="$(EV_train_mfcc)" \
                --train-mlf="$(wd)data/transcription/train/phonetic.mlf"

$(wd)hmms/1-init/hmmdefs $(wd)hmms/1-init/macros: $(eh)resources/hmm/proto $(wd)data/phones/monophones-nosp $(reest_prereq) $(wd)data/transcription/train/phonetic-nosp.mlf $(wd)data/wordlist/test-unk-nosp-phonet $(wd)data/transcription/heldout.mlf $(EV_train_mfcc)
	mkdir -p "$(wd)hmms/1-init/aux" "$(wd)hmms/1-init/iterations" "$(wd)hmms/1-init/base" "$(wd)temp/test"
	step-init.pl \
                --workdir="$(wd)hmms/1-init" \
                --init-proto="$(eh)resources/hmm/proto" \
                --conf="$(eh)resources/htk-config" \
                --phones="$(wd)data/phones/monophones-nosp" \
                --mfccdir="$(EV_train_mfcc)" \
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

$(wd)data/phones/fulllist: $(EV_wordlist_test_phonet) $(wd)data/phones/triphones
	wordlist2triphones.pl "$(EV_wordlist_test_phonet)" | cat - "$(wd)data/phones/triphones" | sort -u > "$(wd)data/phones/fulllist"

$(wd)data/phones/triphones: $(wd)data/transcription/train/aligned.mlf
	mkdir -p "$(wd)data/phones"
	count-triphones.pl < "$(wd)data/transcription/train/aligned.mlf" > "$(wd)data/phones/triphones"

$(wd)data/phones/monophones-nosp: $(wd)data/phones/monophones
	mkdir -p "$(wd)data/phones"
	grep -wv 'sp' < "$(wd)data/phones/monophones" > "$(wd)data/phones/monophones-nosp"

$(wd)data/phones/monophones: $(EV_wordlist_train_phonet) $(EV_wordlist_test_phones)
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
