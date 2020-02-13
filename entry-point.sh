#!/bin/sh
set -e

# The following environment variables already exist
# GITHUB_REPOSITORY
# GITHUB_SHA

if [[ -z "$INPUT_CONTAINER_NAME" ]]; then
	echo "Missing container_name"
	exit 1
fi

if [[ -z "$INPUT_COMMAND_TO_RUN" ]]; then
	echo "Missing command_to_run"
	exit 1
fi

if [[ -z "$INPUT_DOCKER_REGISTRY_USERNAME" ]]; then
	echo "Missing docker_registry_username"
	exit 1
fi

if [[ -z "$INPUT_DOCKER_REGISTRY_PASSWORD" ]]; then
	echo "Missing docker_registry_password"
	exit 1
fi

echo ${INPUT_DOCKER_REGISTRY_PASSWORD} | docker login ${INPUT_DOCKER_REGISTRY} -u "${INPUT_DOCKER_REGISTRY_USERNAME}" --password-stdin

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

# Add Arguments For Caching
BUILDPARAMS=""
# try to pull container if exists
if docker pull ${IMAGE_TO_PULL} 2>/dev/null; then
  echo "Attempting to use ${IMAGE_TO_PULL} as build cache."
  BUILDPARAMS=" --cache-from ${IMAGE_TO_PULL}"
fi

# This is really bad... Fix this. We don't have bash so this will do for the moment.
eval "$INPUT_COMMAND_TO_RUN"

# Remove the existing image if it exists. Likely 100% chance that it doesn't be safe for future
docker rmi -f "${IMAGE_TO_PUSH}" || true
# Tag the built image to the remote version
docker tag "${INPUT_CONTAINER_NAME}" "${IMAGE_TO_PUSH}"
#  Push it!
docker push "${IMAGE_TO_PUSH}"

echo "::set-output name=IMAGE_SHA::${SHA}"
echo "::set-output name=IMAGE_URL::${IMAGE_TO_PUSH}"