#!/bin/bash

# ==============================================================================
# SLURM job wrapper used by Snakemake
#
# Snakemake uses this script as a template for every rule submitted to SLURM.
# The placeholder {exec_job} is automatically replaced by the command required
# to execute the corresponding Snakemake rule.
#
# Cluster-specific settings that may need to be adapted:
#
#   1. Miniconda/Anaconda module name and version.
#   2. Conda environment containing Snakemake.
#   3. Any additional modules or environment variables required by the cluster.
#
# This file is referenced from:
#
#   sbatch/controller.sh
#
# through:
#
#   --jobscript slurm_config/slurm_jobscript.sh
#
# Do not remove or modify the {exec_job} placeholder.
# ==============================================================================

set -euo pipefail

# Load the Conda module available on the cluster.
# Replace this module name and version if your HPC system uses a different one.
module load Miniconda3/24.5.0

# Initialize Conda in this non-interactive SLURM shell.
eval "$(conda shell.bash hook)"

# Activate the environment containing Snakemake.
# Change the environment name if necessary.
conda activate snakemake

# Snakemake replaces this placeholder with the command for the submitted rule.
{exec_job}
