#!/usr/bin/env bash

# set -Eeuo pipefail

mkdir -vp /app/data/.cache \
  /app/data/embeddings \
  /app/data/config/ \
  /app/data/models/ \
  /app/data/models/Stable-diffusion \
  /app/data/models/GFPGAN \
  /app/data/models/RealESRGAN \
  /app/data/models/LDSR \
  /app/data/models/VAE

echo "Downloading, this might take a while..."

aria2c -x 10 --disable-ipv6 --input-file /docker/links.txt --dir /app/data/models --continue
