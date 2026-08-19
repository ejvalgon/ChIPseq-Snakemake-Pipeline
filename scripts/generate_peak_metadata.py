#!/usr/bin/env python3

import csv
import glob
import os
from pathlib import Path

import yaml


# ------------------------------------------------------------------------------
# Project paths
# ------------------------------------------------------------------------------

# This script is expected to be stored in:
# PROJECT_DIR/scripts/generate_peak_metadata.py
SCRIPT_FILE = Path(__file__).resolve()
PROJECT_DIR = SCRIPT_FILE.parent.parent
CONFIG_FILE = PROJECT_DIR / "config" / "config.yaml"


# ------------------------------------------------------------------------------
# Sample discovery
# ------------------------------------------------------------------------------

def get_samples(path, file_ext, layout):
    """
    Detect sample names from raw FASTQ files using the same naming logic as the
    ChIP-seq pipeline.

    Supported paired-end naming conventions:
      sample_R1_001.fastq.gz / sample_R2_001.fastq.gz
      sample_R1.fastq.gz     / sample_R2.fastq.gz

    For paired-end data, the read-pair suffix and configured extension are
    removed from each filename to obtain the sample name.

    For single-end data, only the configured extension is removed from the
    filename.

    This implementation is compatible with Python 3.6 and does not use
    str.removesuffix(), which was introduced in Python 3.9.
    """

    files = glob.glob(
        os.path.join(str(path), "**/*.{}".format(file_ext)),
        recursive=True
    )

    samples = set()

    if layout == "PAIRED":
        suffixes = [
            "_R1_001.{}".format(file_ext),
            "_R2_001.{}".format(file_ext),
            "_R1.{}".format(file_ext),
            "_R2.{}".format(file_ext),
        ]

        for file_path in files:
            basename = os.path.basename(file_path)

            for suffix in suffixes:
                if basename.endswith(suffix):
                    sample = basename[:-len(suffix)]
                    samples.add(sample)
                    break

    else:
        suffix = ".{}".format(file_ext)

        for file_path in files:
            basename = os.path.basename(file_path)

            if basename.endswith(suffix):
                sample = basename[:-len(suffix)]
                samples.add(sample)

    return samples


# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

def load_config(config_file):
    if not config_file.is_file():
        raise FileNotFoundError(
            f"ERROR: configuration file not found: {config_file}"
        )

    with config_file.open("r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle)

    if not isinstance(config, dict):
        raise ValueError(
            f"ERROR: invalid or empty configuration file: {config_file}"
        )

    return config


def resolve_project_path(path_value):
    """
    Resolve relative paths against the project root.
    Absolute paths are kept unchanged.
    """

    path = Path(str(path_value).strip()).expanduser()

    if not path.is_absolute():
        path = PROJECT_DIR / path

    return path.resolve()


# ------------------------------------------------------------------------------
# Sample selection
# ------------------------------------------------------------------------------

def select_samples(config, all_samples):
    selected_samples = config.get("select_samples", [])

    if selected_samples is None:
        selected_samples = []

    if not isinstance(selected_samples, list):
        raise ValueError(
            "ERROR: select_samples must be a YAML list."
        )

    selected_samples = [
        str(sample).strip()
        for sample in selected_samples
        if str(sample).strip() != ""
    ]

    if len(selected_samples) != len(set(selected_samples)):
        duplicated_samples = sorted({
            sample
            for sample in selected_samples
            if selected_samples.count(sample) > 1
        })

        raise ValueError(
            "ERROR: duplicated sample names found in select_samples: "
            f"{duplicated_samples}"
        )

    if len(selected_samples) == 0:
        return sorted(all_samples)

    missing_samples = sorted(
        set(selected_samples) - set(all_samples)
    )

    if missing_samples:
        raise ValueError(
            "ERROR: some selected samples were not found under "
            "RAW_FASTQ_DIR:\n"
            f"{missing_samples}\n"
            f"Available samples are:\n{sorted(all_samples)}"
        )

    return sorted(selected_samples)


# ------------------------------------------------------------------------------
# Metadata writing
# ------------------------------------------------------------------------------

def write_metadata_template(output_file, samples):
    if output_file.exists():
        raise FileExistsError(
            "ERROR: the metadata file already exists and will not be "
            "overwritten:\n"
            f"{output_file}\n"
            "Rename or remove it before generating a new template."
        )

    output_file.parent.mkdir(parents=True, exist_ok=True)

    columns = [
        "sample",
        "role",
        "condition",
        "replicate",
        "mark",
        "control",
        "peak_type"
    ]

    with output_file.open(
        "w",
        newline="",
        encoding="utf-8"
    ) as handle:

        writer = csv.DictWriter(
            handle,
            fieldnames=columns,
            delimiter="\t",
            lineterminator="\n"
        )

        writer.writeheader()

        for sample in samples:
            writer.writerow({
                "sample": sample,
                "role": "",
                "condition": "",
                "replicate": "",
                "mark": "",
                "control": "",
                "peak_type": ""
            })


# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

def main():
    config = load_config(CONFIG_FILE)

    layout = str(config["layout"]).strip().upper()

    if layout not in {"PAIRED", "SINGLE"}:
        raise ValueError(
            "ERROR: layout must be either 'PAIRED' or 'SINGLE'."
        )

    file_ext = str(config.get("ext", "fastq.gz")).strip()

    if file_ext == "":
        raise ValueError(
            "ERROR: ext cannot be empty."
        )

    if "paths" not in config or "raw_fastq" not in config["paths"]:
        raise KeyError(
            "ERROR: paths.raw_fastq is missing from config.yaml."
        )

    if "metadata" not in config:
        raise KeyError(
            "ERROR: metadata is missing from config.yaml."
        )

    raw_fastq_dir = resolve_project_path(
        config["paths"]["raw_fastq"]
    )

    metadata_file = resolve_project_path(
        config["metadata"]
    )

    if not raw_fastq_dir.is_dir():
        raise FileNotFoundError(
            f"ERROR: raw FASTQ directory not found: {raw_fastq_dir}"
        )

    all_samples = sorted(
        get_samples(
            path=raw_fastq_dir,
            file_ext=file_ext,
            layout=layout
        )
    )

    if len(all_samples) == 0:
        raise ValueError(
            "ERROR: no samples were detected under:\n"
            f"{raw_fastq_dir}\n"
            f"Using extension: {file_ext}\n"
            f"Using layout: {layout}"
        )

    samples = select_samples(
        config=config,
        all_samples=all_samples
    )

    if len(samples) == 0:
        raise ValueError(
            "ERROR: no samples are available for metadata generation."
        )

    write_metadata_template(
        output_file=metadata_file,
        samples=samples
    )

    print()
    print("Metadata template generated successfully.")
    print(f"Project directory: {PROJECT_DIR}")
    print(f"Configuration file: {CONFIG_FILE}")
    print(f"Raw FASTQ directory: {raw_fastq_dir}")
    print(f"Layout: {layout}")
    print(f"FASTQ extension: {file_ext}")
    print(f"Detected samples: {len(all_samples)}")
    print(f"Samples written: {len(samples)}")
    print(f"Metadata file: {metadata_file}")
    print()
    print("Samples written:")

    for sample in samples:
        print(f"  - {sample}")


if __name__ == "__main__":
    main()