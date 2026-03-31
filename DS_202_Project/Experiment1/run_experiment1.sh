#!/bin/bash

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate scgnnEnv

ROOT="/gpfs/data/user/shreyags/scGNN_project"
SCRIPT="$ROOT/scGNN.py"
DATA_DIR="$ROOT/DS_202_Project/Experiment1/data"
RESULTS_DIR="$ROOT/DS_202_Project/Experiment1/results"
LOGS_DIR="$RESULTS_DIR/logs"
SUMMARY="$RESULTS_DIR/scgnn_metrics.csv"

mkdir -p "$RESULTS_DIR"/{baron_human,baron_mouse} "$LOGS_DIR"

echo "dataset,n_cells,n_genes,wall_time,cpu_percent,max_memory_kb,avg_memory_kb,disk_used_mb,exit_code" > "$SUMMARY"

get_dims() {
    local FILE="$1"
    local ROWS=$(( $(wc -l < "$FILE") - 1 ))
    local COLS=$(( $(head -1 "$FILE" | tr ',' '\n' | wc -l) - 1 ))
    echo "$ROWS $COLS"
}

run_scgnn() {
    local DATA_PATH="$1"
    local NAME="$2"

    local DATASET_DIR=$(dirname "$DATA_PATH")
    local DATASET_NAME="$NAME"
    local LTMG_DIR="$DATASET_DIR/LTMG"

    local OUTDIR="$RESULTS_DIR/$NAME"
    local LOGFILE="$LOGS_DIR/scgnn_${NAME}.log"

    mkdir -p "$OUTDIR"

    echo "════════════════════════════════════════"
    echo "Running: $NAME"
    echo "DatasetDir : $DATASET_DIR"
    echo "LTMGDir    : $LTMG_DIR"
    echo "════════════════════════════════════════"

    read N_CELLS N_GENES <<< $(get_dims "$DATA_PATH")

    srun --ntasks=1 --cpus-per-task=$SLURM_CPUS_PER_TASK \
        --cpu-bind=cores \
        command time -v python3 "$SCRIPT" \
            --datasetName    "$DATASET_NAME" \
            --datasetDir     "$DATASET_DIR/" \
            --LTMGDir        "$LTMG_DIR/" \
            --outputDir      "$OUTDIR/" \
            --EM-iteration   10 \
            --coresUsage     $SLURM_CPUS_PER_TASK \
            --Regu-epochs    50 \
            --EM-epochs      20 \
            --nonsparseMode \
            --saveinternal \
        > "$LOGFILE" 2>&1

    local EXIT_CODE=$?

    WALL_TIME=$(grep "Elapsed (wall clock) time" "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")
    MAX_MEM=$(grep "Maximum resident set size" "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")

    echo "$NAME,$N_CELLS,$N_GENES,$WALL_TIME,$MAX_MEM,$EXIT_CODE" >> "$SUMMARY"

    if [[ $EXIT_CODE -ne 0 ]]; then
        echo "ERROR: $NAME failed"
    else
        echo "Finished: $NAME"
    fi
}

baron_human="$DATA_DIR/baron_human/baron_human.csv"
baron_mouse="$DATA_DIR/baron_mouse/baron_mouse.csv"

run_scgnn "$baron_human" "baron_human"
run_scgnn "$baron_mouse" "baron_mouse"

echo "Done"