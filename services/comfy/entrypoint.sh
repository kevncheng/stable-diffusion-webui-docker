#!/bin/bash

set -Eeuo pipefail

mkdir -vp /app/data/config/comfy/custom_nodes

declare -A MOUNTS

MOUNTS["/root/.cache"]="/app/data/.cache"
MOUNTS["${ROOT}/input"]="/app/data/config/comfy/input"
MOUNTS["${ROOT}/output"]="/output/comfy"

# echo "Downloading, this might take a while..."
# # Check if the directory already exists
# if [ ! -d "/app/stablediffusion-pvc/models" ]; then
#     # Create the directory if it doesn't exist
#     mkdir -p "/app/stablediffusion-pvc/models"
# fi

# The target directory where the repository will be cloned or updated
target_dir="/app/data/config/comfy"

# Custom nodes
if [ ! -d "$target_dir/custom_nodes/ComfyUI_UltimateSDUpscale" ]; then
  echo "Adding ultimate sd upscale..."
  git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale --recursive "$target_dir/custom_nodes/ComfyUI_UltimateSDUpscale"
  # Install requirements from requirements.txt in the cloned directory
  echo "Installing requirements from the cloned directory..."
  # pip install -r "$target_dir/custom_nodes/ComfyUI_UltimateSDUpscale/requirements.txt"
fi

if [ ! -d "$target_dir/custom_nodes/comfyui_segment_anything" ]; then
  echo "Adding comyfyui segment anything..."
  git clone https://github.com/storyicon/comfyui_segment_anything "$target_dir/custom_nodes/comfyui_segment_anything"
  # Install requirements from requirements.txt in the cloned directory
  echo "Installing requirements from the cloned directory..."
  pip install -r "$target_dir/custom_nodes/comfyui_segment_anything/requirements.txt"
fi

if [ ! -d "$target_dir/custom_nodes/was-node-suite-comfyui" ]; then
  echo "Adding was-node-suite-comfyui..."
  git clone https://github.com/WASasquatch/was-node-suite-comfyui.git "$target_dir/custom_nodes/was-node-suite-comfyui"
  # Install requirements from requirements.txt in the cloned directory
  echo "Installing requirements from the cloned directory..."
  pip install -r "$target_dir/custom_nodes/was-node-suite-comfyui/requirements.txt"
fi

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

exec "$@"
