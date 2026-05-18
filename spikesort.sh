#!/bin/bash
#SBATCH --job-name=preprocess
#SBATCH --output=logs/preprocess-%j.out
#SBATCH --error=logs/preprocess-%j.err
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=10
#SBATCH --mem=32G

