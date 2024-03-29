#!/usr/bin/bash
set -e

model_root_dir=checkpoints

# set task
#task=iwslt-de2en
task=wmt-en2de

# set tag
model_dir_tag=base20-reg6_qk+1

# set device
gpu=5
cpu=

# data set
who=test
#who=valid

if [ $task == "iwslt-de2en" ]; then
        data_dir=iwslt14.tokenized.de-en
        ensemble=5
        batch_size=128
        beam=8
        length_penalty=1.6
        src_lang=de
        tgt_lang=en
        sacrebleu_set=
elif [ $task == "wmt-en2de" ]; then
        data_dir=google
        ensemble=5
        batch_size=64
        beam=4
        length_penalty=0.6
        src_lang=en
        tgt_lang=de
        sacrebleu_set=wmt14/full
elif [ $task == "wmt19_en2zh" ]; then
        data_dir=wmt19_en2zh
        ensemble=5
        batch_size=32
        beam=6
        length_penalty=1.3
        src_lang=en
        tgt_lang=zh
        sacrebleu_set=wmt14/full
elif [ $task == "ldc" ]; then
        data_dir=LDC_180W
        ensemble=5
        batch_size=64
        beam=6
        length_penalty=1.0
        src_lang=zh
        tgt_lang=en
        sacrebleu_set=

else
        echo "unknown task=$task"
        exit
fi

model_dir=$model_root_dir/$task/$model_dir_tag

checkpoint=checkpoint_best.pt

if [ -n "$ensemble" ]; then
        if [ ! -e "$model_dir/last$ensemble.ensemble.pt" ]; then
                PYTHONPATH=`pwd` python3 scripts/average_checkpoints.py --inputs $model_dir --output $model_dir/last$ensemble.ensemble.pt --num-epoch-checkpoints $ensemble
        fi
        checkpoint=last$ensemble.ensemble.pt
fi

output=$model_dir/translation.log

if [ -n "$cpu" ]; then
        use_cpu=--cpu
fi

export CUDA_VISIBLE_DEVICES=$gpu

python3 generate.py \
data-bin/$data_dir \
--path $model_dir/$checkpoint \
--gen-subset $who \
--batch-size $batch_size \
--beam $beam \
--lenpen $length_penalty \
--output $model_dir/hypo.txt \
--quiet \
--remove-bpe $use_cpu | tee $output
#python3 parse_translation_log.py -i $output --tgt_lang $tgt_lang --detoken
python3 rerank.py $model_dir/hypo.txt $model_dir/hypo.sorted
#sh $get_ende_bleu $model_dir/hypo.sorted
#perl $detokenizer -l de < $model_dir/hypo.sorted > $model_dir/hypo.dtk
if [ $data_dir == "google" ]; then
        sh $get_ende_bleu $model_dir/hypo.sorted
        perl $detokenizer -l de < $model_dir/hypo.sorted > $model_dir/hypo.dtk
fi

if [ $sacrebleu_set == "wmt14/full" ]; then

        echo -e "\n>> BLEU-13a"
        cat $model_dir/hypo.dtk | sacrebleu ../en-de.de -tok 13a

        echo -e "\n>> BLEU-intl"
        cat $model_dir/hypo.dtk | sacrebleu ../en-de.de -tok intl
fi
if [ $sacrebleu_set == "wmt14/full" ]; then

        echo -e "\n>> BLEU-13a"
        cat $model_dir/hypo.dtk | sacrebleu ../en-de.de -tok 13a

        echo -e "\n>> BLEU-intl"
        cat $model_dir/hypo.dtk | sacrebleu ../en-de.de -tok intl
fi

if [ $data_dir == "LDC_180W" ] && [ $who == "valid" ]; then
        perl $multi_bleu -lc ../mt06/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "LDC_180W" ] && [ $who == "test" ]; then
        perl $multi_bleu -lc ../mt08/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "LDC_180W" ] && [ $who == "test1" ]; then
        perl $multi_bleu -lc ../mt04/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "LDC_180W" ] && [ $who == "test2" ]; then
        perl $multi_bleu -lc ../mt05/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "NIST_12" ] && [ $who == "test" ]; then
        perl $multi_bleu -lc ../mt12/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "conv" ] && [ $who == "test" ]; then
        perl $multi_bleu -lc ../mt08/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "conv" ] && [ $who == "test1" ]; then
        perl $multi_bleu -lc ../mt04/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "conv" ] && [ $who == "test2" ]; then
        perl $multi_bleu -lc ../mt05/ref* < $model_dir/hypo.sorted
elif [ $data_dir == "conv" ] && [ $who == "valid" ]; then
        perl $multi_bleu -lc ../mt06/ref* < $model_dir/hypo.sorted
fi

                                                                
