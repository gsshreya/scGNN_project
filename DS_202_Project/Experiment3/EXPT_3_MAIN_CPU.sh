#!/bin/bash

# Conda environment same as used for preprocessing

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate scgnnEnv

# System Specifications : Program was run in CPU mode, on a HPC system using 128 compute cores, using the SLURM job scheduler

ROOT="/scratch/scGNN_project"

SCRIPT="$ROOT/scGNN.py"
DATA_DIR="$ROOT/Experiment3"
RESULTS_DIR="$DATA_DIR/results_cpu"

# Datasets (FULL PATHS TO CSV)
sc_celseq="$DATA_DIR/sc_celseq2/LTMG/Use_expression.csv"
zheng="$DATA_DIR/zhengsort/LTMG/Use_expression.csv"

mkdir -p "$RESULTS_DIR"

# Record raw difference in memory and time usage, per subtask

SUMMARY="$RESULTS_DIR/summary_metrics.csv"
echo "dataset,wall_time,max_memory_kb" > "$SUMMARY"

# Function to run scgnn sequentially on Zheng20k (7500~ cells after filtering) and selseq2 (274 cells)

run_scgnn () {
    local DATA_PATH="$1"
    local NAME="$2"

    echo "Running: $NAME"

    # Validate input
    validate_dataset "$DATA_PATH"

    # Extract correct structure for scGNN
    local DATASET_DIR
    local DATASET_NAME

    DATASET_DIR=$(dirname "$(dirname "$DATA_PATH")")   # up to dataset folder
    DATASET_NAME=$(basename "$(dirname "$DATA_PATH")") # LTMG

    echo "DatasetDir  : $DATASET_DIR"
    echo "DatasetName : $DATASET_NAME"

    OUTDIR="$RESULTS_DIR/$NAME"
    mkdir -p "$OUTDIR"

    LOGFILE="$OUTDIR/run.log"

    # Run
    srun --ntasks=1 --cpu-bind=cores /usr/bin/time -v python3 "$SCRIPT" \
        --datasetName "$DATASET_NAME" \
        --datasetDir "$DATASET_DIR/" \
        --outputDir "$OUTDIR/" \
        --EM-iteration 2 \
        --coresUsage $SLURM_CPUS_PER_TASK \
        --Regu-epochs 50 \
        --EM-epochs 20 \
        --quickmode \
        --nonsparseMode \
        > "$LOGFILE" 2>&1

    WALL_TIME=$(grep "Elapsed (wall clock) time" "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")
    MAX_MEM=$(grep "Maximum resident set size" "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")

    echo "$NAME,$WALL_TIME,$MAX_MEM" >> "$SUMMARY"

    echo "Finished: $NAME"
}

# runs programs sequentially 

run_scgnn "$sc_celseq" "celseq2"
run_scgnn "$zheng" "zheng"

echo "Done"