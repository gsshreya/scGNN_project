#!/bin/bash

# Refer to the readme file in the github repository to create the scgnnEnv conda environment

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate scgnnEnv

# preprocessing : note LTMG was NOT used due to issues with the LTMG R package and conda, not strictly required but use the LTMG flag for better results
# LTMG Directory is a required argument regardless of if LTMG was used or not

python3 PreprocessingscGNN.py \
  --datasetName ZhengSort20K.csv \
  --datasetDir /scratch/zhengsort \
  --LTMGDir /scratch/zhengsort/LTMG \ 
  --filetype CSV \
  --geneSelectnum 20000

python3 PreprocessingscGNN.py \
  --datasetName sc_celseq2.count.csv \
  --datasetDir /scratch/sc_celseq2/ \
  --LTMGDir /scratch/sc_celseq2/LTMG/ \
  --filetype CSV \
  --geneSelectnum 20000

echo "Done"