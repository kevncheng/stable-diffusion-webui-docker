#!/usr/bin/env bash

set -Eeuo pipefail

mkdir -vp /app/data/.cache \
  /app/data/embeddings \
  /app/data/config/ \
  /app/data/models/ \
  /app/data/models/Stable-diffusion \
  /app/data/models/GFPGAN \
  /app/data/models/RealESRGAN \
  /app/data/models/LDSR \
  /app/data/models/VAE \
  /app/data/models/sams \
  /app/data/models/grounding-dino \
  /app/data/models/clip_vision 

echo "Downloading, this might take a while..."

aria2c -x 10 --disable-ipv6 --input-file /docker/links.txt --dir /app/data --continue

echo "Checking SHAs..."

parallel --will-cite -a /docker/checksums.sha256 "echo -n {} | sha256sum -c"

cat <<EOF
By using this software, you agree to the following licenses:
https://github.com/AbdBarho/stable-diffusion-webui-docker/blob/master/LICENSE
https://github.com/CompVis/stable-diffusion/blob/main/LICENSE
https://github.com/AUTOMATIC1111/stable-diffusion-webui/blob/master/LICENSE.txt
https://github.com/invoke-ai/InvokeAI/blob/main/LICENSE
And licenses of all UIs, third party libraries, and extensions.
EOF
