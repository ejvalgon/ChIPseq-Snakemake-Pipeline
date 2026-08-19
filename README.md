# ChIP-seq Snakemake Pipeline

A modular **ChIP-seq workflow implemented in Snakemake** for read processing, quality control, optional spike-in normalization, and peak calling on SLURM-based HPC systems.

The workflow supports paired-end and single-end sequencing, STAR or Bowtie2 alignment, configurable spike-in normalization, and optional MACS3 narrow and broad peak calling.

## Main features

- Paired-end and single-end sequencing support
- STAR or Bowtie2 alignment
- Optional spike-in normalization, with CPM-normalized coverage when disabled
- MACS3 narrow, broad, or combined peak calling
- Consensus and union peak generation across biological replicates and conditions
- FRiP, peak-level QC, union-peak read counting, and signal heatmaps
- BAM- and bigWig-level reproducibility analyses
- MultiQC reporting
- Rule-specific Conda environments
- SLURM execution through a Snakemake cluster profile

## Workflow overview

The workflow is organized into three main modules: read processing and alignment, quality control and signal normalization, and optional peak calling.

<p align="center">
  <img src="docs/chipseq_workflow.png" width="1100" alt="ChIP-seq Snakemake workflow">
</p>

## Repository structure

```text
.
├── README.md
├── Snakefile_ChipSeq
├── config/
│   └── config.example.yaml
├── docs/
│   ├── chipseq_workflow.png
│   └── chipseq_workflow.drawio
├── envs/
├── metadata/
│   └── samples.example.tsv
├── sbatch/
│   ├── controller.sh
│   └── star_index_generator.sh
├── scripts/
│   ├── generate_peak_metadata.py
│   └── spikein_scale_factors.R
├── slurm_config/
│   ├── config.yaml
│   ├── parseJobID.sh
│   └── slurm_jobscript.sh
└── workflow/
    ├── main_workflow.smk
    ├── main_qc.smk
    └── peak_calling.smk
```
## Requirements

The workflow is designed for execution on a **SLURM-based HPC system** and requires:

- Snakemake
- Conda or Miniconda
- access to a SLURM workload manager

Rule-specific software dependencies are defined in `envs/` and are installed automatically by Snakemake when the workflow is launched with `--use-conda`.

Reference genomes and aligner indices must be prepared in advance and specified in `config/config.yaml`.

## Configuration

Copy the example configuration before running the workflow:

```bash
cp config/config.example.yaml config/config.yaml
```

The main execution modes are controlled from `config/config.yaml`.

### Sequencing layout

```yaml
layout: "PAIRED"
```

Supported values:

- `PAIRED`
- `SINGLE`

For paired-end data, common naming conventions such as the following are supported:

```text
sample_R1_001.fastq.gz
sample_R2_001.fastq.gz
```

or:

```text
sample_R1.fastq.gz
sample_R2.fastq.gz
```

A subset of samples can optionally be selected through `select_samples`. If the field is left empty, all detected samples are processed.

## Alignment

The aligner is selected in the configuration file:

```yaml
aligner: "star"
```

Supported values:

```text
star
bowtie2
```

Reference paths for both aligners are defined inside the organism-specific section of the configuration file.

## Spike-in normalization

Spike-in normalization can be enabled or disabled directly from the configuration:

```yaml
spikeIN: "yes"
```

or:

```yaml
spikeIN: "no"
```

### Without spike-in normalization

When `spikeIN: "no"`:

- reads are aligned against the main-organism reference;
- the resulting BAM files are used directly for downstream analyses;
- coverage tracks are generated as **CPM-normalized bigWigs**.

### With spike-in normalization

When `spikeIN: "yes"`:

- reads are aligned against a **combined main-organism + spike-in reference**;
- the aligned BAM is split into main-organism and spike-in BAM files;
- spike-in reads are counted for each sample;
- normalization factors are calculated from spike-in read counts;
- spike-in-normalized bigWigs are generated for downstream signal analyses.

Two normalization factors are reported:

- a factor relative to the **median spike-in read count**;
- a **DESeq2-derived spike-in size factor**, converted to the scale factor required by `bamCoverage`.

The combined reference must use distinguishable chromosome or contig prefixes for the main and spike-in genomes. These prefixes are defined in the organism-specific configuration block:

```yaml
main_prefix: "hs_"
spikein_prefix: "sc_"
```

For example:

```text
hs_chr1
hs_chr2
...
sc_chrI
sc_chrII
...
```

A SLURM script for generating a STAR combined-genome index is provided in:

```text
sbatch/star_index_generator.sh
```

The reference FASTA, output directory, Conda module, and SLURM resources should be adapted to the local HPC environment.

## Peak calling

Peak calling is optional and controlled through:

```yaml
calling_peaks: "yes"
```

To skip the complete peak-calling module:

```yaml
calling_peaks: "no"
```

When enabled, the workflow uses **MACS3** and requires metadata defining IP samples, controls, experimental conditions, biological replicates, ChIP targets, and peak-calling mode.

The metadata path is defined in the configuration file:

```yaml
metadata: "metadata/samples.tsv"
```

An example is provided in:

```text
metadata/samples.example.tsv
```

### Metadata format

The metadata table contains the following columns:

| Column | Description |
|---|---|
| `sample` | Sample name matching the FASTQ prefix |
| `role` | `IP` or `INPUT` |
| `condition` | Experimental condition |
| `replicate` | Biological replicate |
| `mark` | ChIP target or histone mark |
| `control` | Input sample associated with the IP |
| `peak_type` | Peak-calling mode |

Example:

```text
sample                    role   condition   replicate   mark       control               peak_type
H3K27ac_control_rep1      IP     control     1           H3K27ac    Input_control_rep1    narrow
H3K27me3_control_rep1     IP     control     1           H3K27me3   Input_control_rep1    broad
RNAPII_control_rep1       IP     control     1           RNAPII     Input_control_rep1    both
Input_control_rep1        INPUT  control     1
```

A metadata template can also be generated automatically after defining the FASTQ directory and sample selection in `config/config.yaml`:

```bash
python scripts/generate_peak_metadata.py
```

The generated file can then be completed with the experimental information required for peak calling.

### Peak-calling modes

The `peak_type` field determines how MACS3 is run for each IP sample:

| `peak_type` | Behaviour |
|---|---|
| `narrow` | Generate narrow peaks |
| `broad` | Generate broad peaks |
| `both` | Run both narrow and broad peak calling |
| `none` | Do not call peaks for that sample |

MACS3 significance thresholds are configurable:

```yaml
macs3:
  narrow_cutoff: 0.05
  broad_cutoff: 0.1
```

This makes it possible to analyse different ChIP targets within the same project using the peak model most appropriate for each mark.

### Consensus and union peaks

Individual peak sets are combined across biological replicates to generate **condition-level consensus peaks**.

The minimum replicate support can be configured with:

```yaml
consensus_peaks:
  min_replicates: 2
```

Consensus peak sets are subsequently merged into **union peak sets**, which provide a common genomic reference for downstream comparisons.

These union sets are used for:

- read counting;
- FRiP calculation;
- peak-level QC;
- normalized signal heatmaps.

## Quality control

The workflow performs quality control at multiple stages, including:

- FastQC before and after trimming
- SAMtools alignment statistics
- Picard alignment and insert-size metrics
- blacklist read fraction
- strand cross-correlation with phantompeakqualtools
- deepTools fingerprint plots
- BAM-level correlation and PCA
- normalized bigWig correlation and PCA
- IP-only reproducibility analyses when peak calling is enabled
- MultiQC aggregation

## Conda environments

Rule-specific dependencies are defined under:

```text
envs/
```

Snakemake creates and uses these environments automatically when the workflow is launched with `--use-conda`.

The controller itself requires a Conda environment containing Snakemake.

## Running on SLURM

The repository includes a SLURM profile and controller script.

Before launching the workflow, adapt the cluster-specific settings in:

```text
sbatch/controller.sh
slurm_config/config.yaml
slurm_config/slurm_jobscript.sh
```

In particular, check:

- SLURM partition;
- controller log paths;
- Miniconda/Anaconda module;
- Snakemake environment name;
- pipeline installation directory;
- cluster job limits and resource syntax.

The workflow can then be submitted with:

```bash
sbatch sbatch/controller.sh
```

The controller builds the Snakemake DAG and submits individual workflow rules as SLURM jobs.

## Main outputs

Depending on the selected configuration, the workflow generates:

- trimmed FASTQ files;
- aligned and indexed BAM files;
- main-organism and spike-in BAMs;
- spike-in read-count and scale-factor tables;
- CPM- or spike-in-normalized bigWigs;
- QC metrics, PCA, and correlation plots;
- MultiQC reports;
- individual MACS3 peaks;
- consensus and union peak sets;
- FRiP and peak-QC tables;
- union-peak read count matrices;
- peak-centered signal heatmaps.

Main workflow outputs are written below:

```yaml
paths:
  out_root: "/path/to/results"
```

Rule-specific logs and benchmark files are written below:

```yaml
paths:
  log_root: "/path/to/logs"
```

## Notes

This workflow was developed for reproducible ChIP-seq processing on SLURM-based HPC systems. Scheduler settings and computational resources should be adapted to the local infrastructure and dataset size.
