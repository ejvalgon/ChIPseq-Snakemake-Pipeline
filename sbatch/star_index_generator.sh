#!/bin/bash

# ==============================================================================
# STAR genome index generator
#
# Generates a STAR genome index from a reference FASTA file.
# The reference can contain either a single genome or a combined genome.
#
# For combined organism + spike-in references, chromosome/contig names should
# use distinct prefixes so reads can later be assigned to each genome.
#
# Example:
#   Main organism: hs_chr1, hs_chr2, ...
#   Spike-in:      sc_chrI, sc_chrII, ...
#
# Adapt the SLURM resources, Conda environment and reference paths to your HPC.
# ==============================================================================

#SBATCH --job-name=STAR_index
#SBATCH --partition=standard
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=12:00:00
#SBATCH --output=/path/to/logs/star_index_generator/STAR_index.%j.out
#SBATCH --error=/path/to/logs/star_index_generator/STAR_index.%j.err

set -euo pipefail

# Adapt the Conda module and STAR environment to your HPC system.
module load Miniconda3/24.5.0
eval "$(conda shell.bash hook)"
conda activate star_index

# Reference FASTA and output directory.
GENOME_FASTA="/path/to/references/genome.fa"
STAR_INDEX="/path/to/references/star_index"

mkdir -p "${STAR_INDEX}"

STAR \
  --runMode genomeGenerate \
  --runThreadN "${SLURM_CPUS_PER_TASK}" \
  --genomeDir "${STAR_INDEX}" \
  --genomeFastaFiles "${GENOME_FASTA}"
