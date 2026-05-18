#!/bin/bash
#SBATCH --job-name=spikesort
#SBATCH --output=logs/spikesort-%j.out
#SBATCH --error=logs/spikesort-%j.err
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=10
#SBATCH --mem=64G

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: sbatch spikesort.sh SUBJECT EMU_ID"
  echo "Example:"
  echo "  sbatch spikesort.sh YFB 44"
  exit 1
fi

SUBJECT="$1"
EMU_ID="$2"
if ! [[ "${EMU_ID}" =~ ^[0-9]+$ ]]; then
  echo "Error: EMU_ID must be numeric, got: ${EMU_ID}" >&2
  exit 1
fi

EMU_ID_PADDED="$(printf "%04d" "${EMU_ID}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STITCHED_ROOT="${STITCHED_ROOT:-/mnt/stitched/EMU-18112}"
SPIKESORTING_DIR="${SPIKESORTING_DIR:-${SCRATCH_DIR}/spikesorting}"
MATLAB_CODE_DIR="${MATLAB_CODE_DIR:-${SCRATCH_DIR}/matlab}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${SCRIPT_DIR}/output}"
JOB_OUTPUT_DIR="${OUTPUT_ROOT}/${SUBJECT}-${EMU_ID}"
SUBJECT_ROOT="${STITCHED_ROOT}/${SUBJECT}"

mkdir -p "${OUTPUT_ROOT}"

if [ ! -d "${SPIKESORTING_DIR}" ]; then
  echo "Error: spikesorting directory not found: ${SPIKESORTING_DIR}" >&2
  exit 1
fi

if [ ! -d "${MATLAB_CODE_DIR}" ]; then
  echo "Error: MATLAB code directory not found: ${MATLAB_CODE_DIR}" >&2
  exit 1
fi

if [ ! -d "${SUBJECT_ROOT}" ]; then
  echo "Error: stitched subject directory not found: ${SUBJECT_ROOT}" >&2
  exit 1
fi

shopt -s nullglob
matches=( "${SUBJECT_ROOT}/EMU-${EMU_ID_PADDED}-"* )
shopt -u nullglob

if [ "${#matches[@]}" -eq 0 ]; then
  echo "Error: no stitched folder found for subject ${SUBJECT} and EMU ${EMU_ID} under ${SUBJECT_ROOT}" >&2
  echo "Expected a folder like: ${SUBJECT_ROOT}/EMU-${EMU_ID_PADDED}-*" >&2
  exit 1
fi

if [ "${#matches[@]}" -gt 1 ]; then
  echo "Error: multiple stitched folders found for subject ${SUBJECT} and EMU ${EMU_ID}:" >&2
  printf '  %s\n' "${matches[@]}" >&2
  exit 1
fi

STITCHED_FOLDER="${matches[0]}"
NS5_FILE="$(find "${STITCHED_FOLDER}" -maxdepth 1 -type f -name '*NSP-2.ns5' -print -quit)"

if [ -z "${NS5_FILE}" ]; then
  echo "Error: no file ending with NSP-2.ns5 found in ${STITCHED_FOLDER}" >&2
  exit 1
fi

mkdir -p "${JOB_OUTPUT_DIR}"
cp -f "${NS5_FILE}" "${JOB_OUTPUT_DIR}/"

export SUBJECT EMU_ID STITCHED_ROOT SPIKESORTING_DIR MATLAB_CODE_DIR JOB_OUTPUT_DIR STITCHED_FOLDER NS5_FILE

echo "Starting spike sorting job"
echo "Subject: ${SUBJECT}"
echo "EMU ID: ${EMU_ID}"
echo "EMU ID padded: ${EMU_ID_PADDED}"
echo "Stitched root: ${STITCHED_ROOT}"
echo "Stitched folder: ${STITCHED_FOLDER}"
echo "NS5 file: ${NS5_FILE}"
echo "Spikesorting dir: ${SPIKESORTING_DIR}"
echo "MATLAB code dir: ${MATLAB_CODE_DIR}"
echo "Output dir: ${JOB_OUTPUT_DIR}"
echo "Host: $(hostname)"
echo "Job ID: ${SLURM_JOB_ID:-interactive}"
echo "Working directory: $(pwd)"

if ! command -v matlab >/dev/null 2>&1; then
  if [ -f /etc/profile.d/modules.sh ]; then
    # shellcheck disable=SC1091
    source /etc/profile.d/modules.sh
  fi

  if command -v module >/dev/null 2>&1; then
    module load matlab || true
  fi
fi

if ! command -v matlab >/dev/null 2>&1; then
  echo "Error: matlab command not found. Load the MATLAB module or update the script for your cluster." >&2
  exit 1
fi

matlab -batch "\
addpath(genpath(getenv('SPIKESORTING_DIR'))); \
addpath(genpath(getenv('MATLAB_CODE_DIR'))); \
cd(getenv('JOB_OUTPUT_DIR')); \
runSpikeSort(getenv('JOB_OUTPUT_DIR'));"
