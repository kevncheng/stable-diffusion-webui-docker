#!/bin/bash

set -Eeuo pipefail

# TODO: maybe just use the .gitignore file to create all of these
mkdir -vp /data/.cache \
  /data/embeddings \
  /data/config/ \
  /data/models/ \
  /data/models/Stable-diffusion \
  /data/models/GFPGAN \
  /data/models/RealESRGAN \
  /data/models/LDSR \
  /data/models/VAE

echo "Downloading, this might take a while..."
# Check if the directory already exists
if [ ! -d "/app/stablediffusion-pvc/models" ]; then
    # Create the directory if it doesn't exist
    mkdir -p "/app/stablediffusion-pvc/models"
fi

# aria2c -x 10 --disable-ipv6 --input-file /docker/links.txt --dir /app/models --continue
# Download models, check if file already exist
# If does not exist then download file
aria2c -x 10 --disable-ipv6 --input-file /docker/links.txt --dir /app/stablediffusion-pvc --auto-file-renaming=false --continue

# The target directory where the repository will be cloned or updated
target_dir="/data/config/auto/extensions"

if [ ! -d "$target_dir/depthmap2mask" ]; then
  echo "Adding depthmap2mask script..."
   git clone https://github.com/Extraltodeus/depthmap2mask.git "$target_dir/depthmap2mask"
fi

if [ ! -d "$target_dir/stable-diffusion-webui-rembg" ]; then
  echo "Adding rembg extension..."
  git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui-rembg.git "$target_dir/stable-diffusion-webui-rembg"
fi

if [ ! -d "$target_dir/PBRemTools" ]; then
  echo "Adding PBRemTools extension..."
  git clone https://github.com/mattyamonaca/PBRemTools.git "$target_dir/PBRemTools"
fi

if [ ! -d "$target_dir/sd-webui-controlnet" ]; then
  echo "Adding sd-webui-controlnet extension..."
  git clone https://github.com/Mikubill/sd-webui-controlnet.git "$target_dir/sd-webui-controlnet"
 
  # git clone https://huggingface.co/lllyasviel/ControlNet-v1-1 --force "$target_dir/sd-webui-controlnet/models"
fi

echo "Adding extension models..."
aria2c -x 10 --disable-ipv6 --input-file /docker/extension_links.txt --dir $target_dir --auto-file-renaming=false --continue

# TODO: move all mkdir -p ?
mkdir -p /data/config/auto/scripts/
# mount scripts individually
find "${ROOT}/scripts/" -maxdepth 1 -type l -delete
cp -vrfTs /data/config/auto/scripts/ "${ROOT}/scripts/"

# Set up config file
python3 /docker/config.py /data/config/auto/config.json

if [ ! -f /data/config/auto/ui-config.json ]; then
  echo '{}' >/data/config/auto/ui-config.json
fi

if [ ! -f /data/config/auto/styles.csv ]; then
  touch /data/config/auto/styles.csv
fi

# copy models from original models folder
mkdir -p /data/models/VAE-approx/ /data/models/karlo/

rsync -a --info=NAME ${ROOT}/models/VAE-approx/ /data/models/VAE-approx/
rsync -a --info=NAME ${ROOT}/models/karlo/ /data/models/karlo/

declare -A MOUNTS

MOUNTS["/root/.cache"]="/data/.cache"
# MOUNTS["${ROOT}/models"]="/data/models"

# ln -s "${ROOT}/models" /app/Stable-diffusion/models
# Mount models to pvc
# MOUNTS["/app/models"]="/data/models"
# Create the symlink if the target directory exists
if [ -d "/app/stablediffusion-pvc" ]; then
    # ln -s /stable-diffusion/models ~/app/stablediffusion-pvc/models

    # Grant administrative permissions to the directory
    chmod -R 777 "/app/stablediffusion-pvc"
else
    echo "Error: Failed to create directory /app/stablediffusion-pvc"
fi

MOUNTS["${ROOT}/embeddings"]="/data/embeddings"
MOUNTS["${ROOT}/config.json"]="/data/config/auto/config.json"
MOUNTS["${ROOT}/ui-config.json"]="/data/config/auto/ui-config.json"
MOUNTS["${ROOT}/styles.csv"]="/data/config/auto/styles.csv"
MOUNTS["${ROOT}/extensions"]="/data/config/auto/extensions"
MOUNTS["${ROOT}/config_states"]="/data/config/auto/config_states"

# extra hacks
MOUNTS["${ROOT}/repositories/CodeFormer/weights/facelib"]="/data/.cache"

for to_path in "${!MOUNTS[@]}"; do
  set -Eeuo pipefail
  from_path="${MOUNTS[${to_path}]}"
  rm -rf "${to_path}"
  if [ ! -f "$from_path" ]; then
    mkdir -vp "$from_path"
  fi
  mkdir -vp "$(dirname "${to_path}")"
  ln -sT "${from_path}" "${to_path}"
  echo Mounted $(basename "${from_path}")
done

echo "Installing extension dependencies (if any)"

# because we build our container as root:
chown -R root ~/.cache/
chmod 766 ~/.cache/

shopt -s nullglob
# For install.py, please refer to https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Developing-extensions#installpy
list=(./extensions/*/install.py)
for installscript in "${list[@]}"; do
  PYTHONPATH=${ROOT} python3 "$installscript"
done

if [ -f "/data/config/auto/startup.sh" ]; then
  pushd ${ROOT}
  echo "Running startup script"
  . /data/config/auto/startup.sh
  popd
fi

exec "$@"
