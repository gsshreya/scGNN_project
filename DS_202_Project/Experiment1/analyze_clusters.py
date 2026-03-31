import os
import sys
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import adjusted_rand_score, normalized_mutual_info_score

# ======== USAGE CHECK ========
if len(sys.argv) != 2:
    print("Usage: python analyze_clusters.py <dataset_name>")
    print("Example: python analyze_clusters.py baron_human")
    sys.exit(1)

dataset = sys.argv[1]

# ======== PATHS ========
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

TRUE_FILE = os.path.join(BASE_DIR, f"data/{dataset}/{dataset}.csv")
PRED_FILE = os.path.join(BASE_DIR, f"results/{dataset}/labels.csv")
OUTDIR = os.path.join(BASE_DIR, f"results/analysis/{dataset}")

# ======== CREATE OUTPUT DIR ========
os.makedirs(OUTDIR, exist_ok=True)

print("\n===== PATHS =====")
print("TRUE:", TRUE_FILE)
print("PRED:", PRED_FILE)
print("OUT :", OUTDIR)

# ======== LOAD DATA ========
true = pd.read_csv(TRUE_FILE, header=None)
pred = pd.read_csv(PRED_FILE, header=None)

true.columns = ["cell_id", "true"]
pred.columns = ["cell_id", "pred"]

# ======== MERGE ========
df = pd.merge(true, pred, on="cell_id")

print("\n===== BASIC INFO =====")
print("Merged cells:", len(df))
print("Unique true cell types:", df["true"].nunique())
print("Unique predicted clusters:", df["pred"].nunique())

# ======== SAVE MERGED ========
df.to_csv(f"{OUTDIR}/merged_labels.csv", index=False)

# ======== METRICS ========
ari = adjusted_rand_score(df["true"], df["pred"])
nmi = normalized_mutual_info_score(df["true"], df["pred"])

with open(f"{OUTDIR}/metrics.txt", "w") as f:
    f.write(f"Dataset: {dataset}\n")
    f.write(f"Cells: {len(df)}\n")
    f.write(f"True types: {df['true'].nunique()}\n")
    f.write(f"Clusters: {df['pred'].nunique()}\n")
    f.write(f"ARI: {ari}\n")
    f.write(f"NMI: {nmi}\n")

print("\n===== METRICS =====")
print("ARI:", ari)
print("NMI:", nmi)

# ======== CONFUSION MATRIX ========
ct = pd.crosstab(df["true"], df["pred"])
ct.to_csv(f"{OUTDIR}/confusion_matrix.csv")

# ======== HEATMAP ========
plt.figure(figsize=(10, 8))
sns.heatmap(ct, cmap="viridis")
plt.title(f"{dataset} - Confusion Matrix")
plt.xlabel("Predicted Cluster")
plt.ylabel("True Cell Type")
plt.tight_layout()
plt.savefig(f"{OUTDIR}/confusion_heatmap.png")
plt.close()

# ======== CLUSTER SIZE ========
plt.figure()
df["pred"].value_counts().sort_index().plot(kind="bar")
plt.title(f"{dataset} - Cluster Sizes")
plt.xlabel("Cluster")
plt.ylabel("Cells")
plt.tight_layout()
plt.savefig(f"{OUTDIR}/cluster_sizes.png")
plt.close()

# ======== TRUE DISTRIBUTION ========
plt.figure()
df["true"].value_counts().plot(kind="bar")
plt.title(f"{dataset} - True Cell Type Distribution")
plt.xlabel("Cell Type")
plt.ylabel("Cells")
plt.tight_layout()
plt.savefig(f"{OUTDIR}/true_cell_types.png")
plt.close()

print("\n===== FILES GENERATED =====")
print(f"{OUTDIR}/merged_labels.csv")
print(f"{OUTDIR}/confusion_matrix.csv")
print(f"{OUTDIR}/confusion_heatmap.png")
print(f"{OUTDIR}/cluster_sizes.png")
print(f"{OUTDIR}/true_cell_types.png")
print(f"{OUTDIR}/metrics.txt")

