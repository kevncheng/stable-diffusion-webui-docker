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

aria2c -x 10 --disable-ipv6 --input-file /docker/links.txt --dir /data/models --continue

# The target directory where the repository will be cloned or updated
target_dir="/data/config/auto/extensions"

# # Check if the target directory exists
# if [ -d "$target_dir" ]; then
#   # If it exists, remove the existing repository
#   echo "Removing existing repository..."
#   rm -rf "$target_dir"
# fi

# # Clone the repository from GitHub
# echo "Cloning repository..."
# # cd "$target_dir/depthmap2mask" && git checkout --hard 377e9224
# # Check if the target directory exists
# if [! -d "$target_dir/depthmap2mask" ]; then
#   # If it exists, remove the existing repository
#   # echo "Removing existing repository..."
#   # rm -rf "$target_dir"
#   git clone https://github.com/Extraltodeus/depthmap2mask.git "$target_dir"
# fi

if [ ! -d "$target_dir/stable-diffusion-webui-rembg" ]; then
  # If it exists, remove the existing repository
  # echo "Removing existing repository..."
  # rm -rf "$target_dir"
  # Clone the repository from GitHub
  echo "Cloning repository..."
  git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui-rembg.git "$target_dir/stable-diffusion-webui-rembg"
  # cd "$target_dir/depthmap2mask" && git checkout --hard 3d9eedbb
fi

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
MOUNTS["${ROOT}/models"]="/data/models"

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
