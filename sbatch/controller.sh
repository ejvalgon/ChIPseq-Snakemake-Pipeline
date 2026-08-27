#!/bin/bash

#SBATCH --job-name=chip_controller
#SBATCH --partition=standard
#SBATCH --time=72:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --output=/path/to/ChIPseq_pipeline/logs/slurm/controller_CHIPseq.%j.out
#SBATCH --error=/path/to/ChIPseq_pipeline/logs/slurm/controller_CHIPseq.%j.err

set -euo pipefail

# Cluster-specific settings: adapt the Conda module and environment name
# to the software configuration available on your HPC system.
module load Miniconda3/24.5.0
eval "$(conda shell.bash hook)"
conda activate snakemake

# Set the absolute path to the pipeline installation directory.
PIPELINE_DIR="/path/to/ChIPseq_pipeline"
cd "${PIPELINE_DIR}"

# The controller requires little CPU and memory because it only builds the DAG,
# submits rule-specific SLURM jobs and monitors them. Runtime should be long
# enough to cover the complete workflow execution.
snakemake \
  --snakefile Snakefile_ChipSeq \
  --profile slurm_config \
  --use-conda \
  --conda-frontend conda \
  --jobscript slurm_config/slurm_jobscript.sh \
  --rerun-incomplete \
  --keep-going \
  --latency-wait 60
