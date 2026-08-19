#!/bin/bash

# ==============================================================================
# STAR combined-genome index generator
#
# This SLURM script generates a STAR genome index from a combined reference
# FASTA file. It is intended for workflows using spike-in normalization, where
# reads from the main organism and the spike-in organism are aligned against the
# same combined reference genome.
#
# Before running this script, adapt the following cluster-specific settings:
#
#   1. SLURM partition.
#   2. CPU, memory and runtime requirements.
#   3. Output and error log paths.
#   4. Miniconda/Anaconda module name and version.
#   5. Conda environment containing STAR.
#   6. Path to the combined reference FASTA.
#   7. Output directory for the STAR index.
#
# IMPORTANT:
# The combined FASTA should use unique chromosome/contig prefixes for each
# organism so that reads can later be separated by genome.
#
# Example:
#   Main organism: hs_chr1, hs_chr2, ...
#   Spike-in:      sc_chrI, sc_chrII, ...
#
# Submit with:
#
#   sbatch sbatch/star_index_generator.sh
#
# ==============================================================================


# ------------------------------------------------------------------------------
# SLURM resources
# ------------------------------------------------------------------------------

# Name shown in the SLURM queue.
#SBATCH --job-name=STAR_combined_index

# Cluster partition or queue.
# Change this value according to your HPC system.
#SBATCH --partition=standard

# Number of CPU threads used by STAR during genome index generation.
#SBATCH --cpus-per-task=16

# Memory requested for index generation.
# Large mammalian or combined genomes may require substantial RAM.
#SBATCH --mem=128G

# Maximum runtime for the job.
#SBATCH --time=12:00:00

# Standard output and error files.
#
# IMPORTANT:
# Replace these paths with valid paths on your system.
# The parent directory must already exist before submitting the job.
# %j is automatically replaced by SLURM with the job ID.
#SBATCH --output=/path/to/logs/star_index_generator/STAR_combined_index.%j.out
#SBATCH --error=/path/to/logs/star_index_generator/STAR_combined_index.%j.err


# Stop immediately if a command fails, an undefined variable is used, or a
# command inside a pipeline returns an error.
set -euo pipefail


# ------------------------------------------------------------------------------
# Software environment
# ------------------------------------------------------------------------------

# Load the Conda module available on the cluster.
# Change the module name and version if necessary.
module load Miniconda3/24.5.0

# Initialize Conda in the current non-interactive shell.
eval "$(conda shell.bash hook)"

# Activate the Conda environment containing STAR.
# Change the environment name if necessary.
conda activate star_index


# ------------------------------------------------------------------------------
# Reference paths
# ------------------------------------------------------------------------------

# Combined FASTA containing the main organism and the spike-in genome.
#
# Chromosome/contig names should include organism-specific prefixes so that
# downstream BAM splitting can distinguish both genomes.
GENOME_FASTA="/path/to/references/combined_genome.fa"

# Directory where the STAR index will be generated.
STAR_INDEX="/path/to/references/star_combined_genome_index"

# Create the output directory if it does not already exist.
mkdir -p "${STAR_INDEX}"


# ------------------------------------------------------------------------------
# Generate STAR genome index
# ------------------------------------------------------------------------------

STAR \
  --runMode genomeGenerate \
  --runThreadN "${SLURM_CPUS_PER_TASK}" \
  --genomeDir "${STAR_INDEX}" \
  --genomeFastaFiles "${GENOME_FASTA}"
