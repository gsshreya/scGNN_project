#!/bin/bash

source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate scgnnEnv

export NUMBA_DISABLE_JIT=1

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

validate_dataset() {
    local PATH="$1"
    local NAME="$2"
    if [[ ! -f "$PATH" ]]; then
        echo "ERROR: Input file not found for $NAME: $PATH"
        exit 1
    fi
}

run_scgnn() {
    local DATA_PATH="$1"
    local NAME="$2"

    validate_dataset "$DATA_PATH" "$NAME"

    # KEEP THIS (required by scGNN structure)
    local DATASET_DIR=$(dirname "$(dirname "$DATA_PATH"))
    local DATASET_NAME=$(basename "$(dirname "$DATA_PATH"))

    local OUTDIR="$RESULTS_DIR/$NAME"
    local LOGFILE="$LOGS_DIR/scgnn_${NAME}.log"

    mkdir -p "$OUTDIR"

    echo "════════════════════════════════════════"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting scGNN: $NAME"
    echo "════════════════════════════════════════"

    read N_CELLS N_GENES <<< $(get_dims "$DATA_PATH")
    echo "  Cells        : $N_CELLS"
    echo "  Genes        : $N_GENES"

    local DISK_BEFORE=$(df -BM "$ROOT" | awk 'NR==2 {print $3}' | tr -d 'M')

    srun --ntasks=1 --cpus-per-task=$SLURM_CPUS_PER_TASK \
        --cpu-bind=cores \
        command time -v python3 "$SCRIPT" \
            --datasetName    "$DATASET_NAME" \
            --datasetDir     "$DATASET_DIR/" \
            --outputDir      "$OUTDIR/" \
            --EM-iteration   10 \
            --coresUsage     $SLURM_CPUS_PER_TASK \
            --Regu-epochs    50 \
            --EM-epochs      20 \
            --nonsparseMode \
            --saveinternal \
        > "$LOGFILE" 2>&1

    local EXIT_CODE=$?

    local DISK_AFTER=$(df -BM "$ROOT" | awk 'NR==2 {print $3}' | tr -d 'M')
    local DISK_USED=$(( DISK_AFTER - DISK_BEFORE ))

    local WALL_TIME MAX_MEM AVG_MEM CPU_PCT
    WALL_TIME=$(grep "Elapsed (wall clock) time"  "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")
    MAX_MEM=$(grep "Maximum resident set size"     "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")
    AVG_MEM=$(grep "Average resident set size"     "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")
    CPU_PCT=$(grep "Percent of CPU this job got"   "$LOGFILE" | awk -F': ' '{print $2}' || echo "NA")

    local FINAL_LOSS N_CLUSTERS
    FINAL_LOSS=$(grep -i "loss" "$LOGFILE" | tail -1 || echo "NA")
    N_CLUSTERS=$(grep -i "Total Cluster Number" "$LOGFILE" | tail -1 || echo "NA")

    echo ""
    echo "  [METRICS: $NAME]"
    echo "  Wall time      : $WALL_TIME"
    echo "  CPU usage      : $CPU_PCT"
    echo "  Peak memory    : ${MAX_MEM} kb"
    echo "  Avg memory     : ${AVG_MEM} kb"
    echo "  Disk used      : ${DISK_USED} MB"
    echo "  Final loss     : $FINAL_LOSS"
    echo "  Clusters found : $N_CLUSTERS"
    echo "  Exit code      : $EXIT_CODE"
    echo ""

    echo "$NAME,$N_CELLS,$N_GENES,$WALL_TIME,$CPU_PCT,$MAX_MEM,$AVG_MEM,$DISK_USED,$EXIT_CODE" >> "$SUMMARY"

    if [[ $EXIT_CODE -ne 0 ]]; then
        echo "  ERROR: $NAME failed! Check: $LOGFILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished: $NAME"
    fi
}

baron_human="$DATA_DIR/baron_human/LTMG/Use_expression.csv"
baron_mouse="$DATA_DIR/baron_mouse/LTMG/Use_expression.csv"

run_scgnn "$baron_human" "baron_human"
run_scgnn "$baron_mouse" "baron_mouse"

echo ""
echo "════════════════════════════════════════"
echo " Experiment complete"
echo " Summary  : $SUMMARY"
echo "════════════════════════════════════════"

cat "$SUMMARY"