#!  /bin/sh

set -e  # Fail on any command with non-zero exit
DOCKER_FILE='Dockerfile.ngtf-bridge-ci'

# The docker image ID is currently just the git SHA of this cloned repo
# IMAGE_ID="$(git rev-parse HEAD)"
#
IMAGE_NAME='ngtf_bridge_ci'
IMAGE_ID="${1}"
if [ -z "${IMAGE_ID}" ] ; then
    echo 'Please provide an image version as the only argument'
    exit 1
fi

set -u  # No unset variables after this point

# Context is the maint-jenkins directory, to avoid including all of
# ngraph-tensorflow-1.3 in the context.
docker build  --rm=true \
       --build-arg http_proxy=http://proxy-fm.intel.com:911 \
       --build-arg https_proxy=http://proxy-fm.intel.com:912 \
       -f="${DOCKER_FILE}"  -t="ngtf_bridge_ci:${IMAGE_ID}"   .
