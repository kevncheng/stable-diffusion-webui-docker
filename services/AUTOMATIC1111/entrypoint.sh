#!/bin/bash

set -Eeuo pipefail

# TODO: move all mkdir -p ?
mkdir -p /data/config/auto/scripts/
# mount scripts individually

echo $ROOT
ls -lha $ROOT

find "${ROOT}/scripts/" -maxdepth 1 -type l -delete
cp -vrfTs /data/config/auto/scripts/ "${ROOT}/scripts/"

# Set up config file
python /docker/config.py /data/config/auto/config.json

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

if [ ! -d "$target_dir/sd-webui-controlnet" ]; then
  echo "Adding sd-webui-controlnet extension..."
  git clone https://github.com/Mikubill/sd-webui-controlnet.git "$target_dir/sd-webui-controlnet"
fi

if [ ! -d "$target_dir/ultimate-upscale-for-automatic1111" ]; then
  echo "Adding ultimate sd upscale..."
  git clone https://github.com/Coyote-A/ultimate-upscale-for-automatic1111.git "$target_dir/ultimate-upscale-for-automatic1111"
fi

echo "Adding extension models..."
aria2c -x 10 --disable-ipv6 --input-file /docker/extension_links.txt --dir $target_dir --auto-file-renaming=false --continue

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
if [ -d "/app/data" ]; then
    # ln -s /stable-diffusion/models /app/stablediffusion-pvc/models

    # Grant administrative permissions to the directory
    chmod -R 777 "/app/data"
else
    echo "Error: Failed to create directory /app/data"
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
  EXTNAME=$(echo $installscript | cut -d '/' -f 3)
  # Skip installing dependencies if extension is disabled in config
  if $(jq -e ".disabled_extensions|any(. == \"$EXTNAME\")" config.json); then
    echo "Skipping disabled extension ($EXTNAME)"
    continue
  fi
  PYTHONPATH=${ROOT} python "$installscript"
done

if [ -f "/data/config/auto/startup.sh" ]; then
  pushd ${ROOT}
  echo "Running startup script"
  . /data/config/auto/startup.sh
  popd
fi

exec "$@"
