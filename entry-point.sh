#!/bin/sh
set -e

# The following environment variables already exist
# GITHUB_REPOSITORY
# GITHUB_SHA

# only log in if we have a password (assumes username without password doesn't do anything)
if [[ -n "${INPUT_DOCKER_REGISTRY_PASSWORD}" ]]; then
  echo ${INPUT_DOCKER_REGISTRY_PASSWORD} | docker login ${INPUT_DOCKER_REGISTRY} -u "${INPUT_DOCKER_REGISTRY_USERNAME}" --password-stdin
fi

if [[ -z "${INPUT_DOCKER_REGISTRY}" ]]; then
  # In the event there is no registry, then we'll assume its for the default docker hub registry,
  # in which case the format is username/container-name.
  # This is totally untested but a best guess at the moment...
  IMAGE_PREFIX="${INPUT_DOCKER_REGISTRY_USERNAME}"
else
  IMAGE_PREFIX="${INPUT_DOCKER_REGISTRY}"
fi

SHA=$(echo "${GITHUB_SHA}" | cut -c1-12)
IMAGE_TO_PULL="${IMAGE_PREFIX}/${INPUT_CONTAINER_NAME}"
IMAGE_TO_PUSH="${IMAGE_PREFIX}/${INPUT_CONTAINER_NAME}:${SHA}"
IMAGE_TO_PUSH_LATEST="${IMAGE_PREFIX}/${INPUT_CONTAINER_NAME}:latest"

# Add Arguments For Caching
BUILDPARAMS=""
# try to pull container if exists
if docker pull ${IMAGE_TO_PULL} 2>/dev/null; then
  echo "Attempting to use ${IMAGE_TO_PULL} as build cache."
  BUILDPARAMS=" --cache-from ${IMAGE_TO_PULL}"
fi

# This is really bad... Fix this. We don't have bash so this will do for the moment.
eval "$INPUT_COMMAND_TO_RUN"

docker tag "${INPUT_CONTAINER_NAME}" "${IMAGE_TO_PUSH}"
docker push "${IMAGE_TO_PUSH}"
docker tag "${INPUT_CONTAINER_NAME}" "${IMAGE_TO_PUSH_LATEST}"
docker push "${IMAGE_TO_PUSH_LATEST}"

echo "::set-output name=IMAGE_SHA::${SHA}"
echo "::set-output name=IMAGE_URL::${IMAGE_TO_PUSH}"