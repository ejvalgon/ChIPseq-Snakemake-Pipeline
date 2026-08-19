#!/bin/bash

# ==============================================================================
# ChIP-seq Snakemake workflow controller for SLURM
#
# This script launches the main Snakemake process. Snakemake then submits each
# workflow rule as an independent SLURM job using the profile located in:
#
#   slurm_config/
#
# Before submitting this script, adapt the cluster-specific settings below:
#
#   1. SLURM partition name.
#   2. Maximum runtime and memory for the controller job.
#   3. Output and error log paths.
#   4. Miniconda/Anaconda module name and version.
#   5. Name of the Conda environment containing Snakemake.
#   6. Absolute path to the pipeline directory.
#
# Submit the workflow with:
#
#   sbatch sbatch/controller.sh
#
# Monitor the controller and rule-specific jobs with:
#
#   squeue -u "$USER"
#
# The controller itself performs little computation. Its main function is to
# build the workflow DAG, submit rule-specific jobs and monitor their execution.
# ==============================================================================


# ------------------------------------------------------------------------------
# SLURM resources for the Snakemake controller
# ------------------------------------------------------------------------------

# Name shown in the SLURM queue.
#SBATCH --job-name=chip_controller

# Cluster partition or queue.
# Change "standard" to the appropriate partition name on your cluster.
#SBATCH --partition=standard

# Maximum runtime for the controller process.
# This must be long enough for the complete workflow because the controller
# remains active while individual jobs are submitted and monitored.
#SBATCH --time=72:00:00

# The controller itself normally requires only one CPU.
#SBATCH --cpus-per-task=1

# The controller requires little memory because computationally intensive steps
# are executed as separate SLURM jobs.
#SBATCH --mem=2G

# Standard output and error files for the controller.
#
# IMPORTANT:
#   - Replace these paths with valid paths on your system.
#   - The parent directory must already exist before submitting the job.
#   - %j is automatically replaced by the SLURM job ID.
#SBATCH --output=/path/to/ChIPseq_pipeline/logs/slurm/controller_CHIPseq.%j.out
#SBATCH --error=/path/to/ChIPseq_pipeline/logs/slurm/controller_CHIPseq.%j.err

# Stop immediately if a command fails, an undefined variable is used, or a
# command inside a pipeline returns an error.
set -euo pipefail


# ------------------------------------------------------------------------------
# Cluster-specific software environment
# ------------------------------------------------------------------------------

# Load the Conda module available on the cluster.
# The module name and version will differ between HPC systems.
module load Miniconda3/24.5.0

# Initialize Conda commands in the current non-interactive shell.
eval "$(conda shell.bash hook)"

# Activate the environment containing Snakemake.
# This environment must contain a compatible Snakemake installation.
conda activate snakemake


# ------------------------------------------------------------------------------
# Pipeline location
# ------------------------------------------------------------------------------

# Absolute path to the pipeline root directory.
# This directory must contain:
#
#   Snakefile_ChipSeq
#   config/
#   envs/
#   workflow/
#   scripts/
#   slurm_config/
#
# Change this path when installing the pipeline on another system.
PIPELINE_DIR="/path/to/ChIPseq_pipeline"
cd "${PIPELINE_DIR}"


# ------------------------------------------------------------------------------
# Launch Snakemake
# ------------------------------------------------------------------------------

snakemake \
  --snakefile Snakefile_ChipSeq \
  --profile slurm_config \
  --use-conda \
  --conda-frontend conda \
  --jobscript slurm_config/slurm_jobscript.sh \
  --rerun-incomplete \
  --keep-going \
  --latency-wait 60
