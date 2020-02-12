#!/bin/sh
set -e

# The following environment variables already exist
# GITHUB_REPOSITORY
# GITHUB_SHA

if [[ -z "$CONTAINER_NAME" ]]; then
	echo "Missing CONTAINER_NAME"
	exit 1
fi

if [[ -z "$COMMAND_TO_RUN" ]]; then
	echo "Missing COMMAND_TO_RUN"
	exit 1
fi

if [[ -z "$DOCKER_REGISTRY_USERNAME" ]]; then
	echo "Missing DOCKER_REGISTRY_USERNAME"
	exit 1
fi

if [[ -z "$DOCKER_REGISTRY_PASSWORD" ]]; then
	echo "Missing DOCKER_REGISTRY_PASSWORD"
	exit 1
fi

echo ${DOCKER_REGISTRY_PASSWORD} | docker login ${DOCKER_REGISTRY} -u "${DOCKER_REGISTRY_USERNAME}" --password-stdin

if [[ -z "$DOCKER_REGISTRY" ]]; then
  # In the event there is no registry, then we'll assume its for the default docker hub registry,
  # in which case the format is username/container-name.
  # This is totally untested but a best guess at the moment...
  IMAGE_PREFIX="${DOCKER_REGISTRY_USERNAME}"
else
  IMAGE_PREFIX="$DOCKER_REGISTRY"
fi

SHA=$(echo "${GITHUB_SHA}" | cut -c1-12)
IMAGE_TO_PULL="${IMAGE_PREFIX}/${CONTAINER_NAME}"
IMAGE_TO_PUSH="${IMAGE_PREFIX}/${CONTAINER_NAME}:${SHA}"

# Add Arguments For Caching
BUILDPARAMS=""
# try to pull container if exists
if docker pull ${IMAGE_TO_PULL} 2>/dev/null; then
  echo "Attempting to use ${IMAGE_TO_PULL} as build cache."
  BUILDPARAMS=" --cache-from ${IMAGE_TO_PULL}"
fi

# Our build commands always create an image called simply whatever ${CONTAINER_NAME} is
# (cd ${CONTAINERS_DIRECTORY} && .bin/build.sh ${CONTAINER_NAME});

"${COMMAND_TO_RUN[@]}"

# Remove the existing image if it exists. Likely 100% chance that it doesn't be safe for future
docker rmi -f "${IMAGE_TO_PUSH}" || true
# Tag the built image to the remote version
docker tag "${CONTAINER_NAME}" "${IMAGE_TO_PUSH}"
#  Push it!
docker push "${IMAGE_TO_PUSH}"

echo "::set-output name=IMAGE_SHA::${SHA}"
echo "::set-output name=IMAGE_URL::${IMAGE_TO_PUSH}"