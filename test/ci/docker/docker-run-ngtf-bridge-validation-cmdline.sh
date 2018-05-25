#!  /bin/bash

# Script command line parameters:
#
# $1 ImageID    Required: ID of the ngtf_bridge_ci docker image to use
# $2 Command    Required: Command to use to run the model
#                         (single-quoted, so the whole command is one string)
#
# Script environment variable parameters:
#
# TF_NG_DATASET  Required: Dataset to prepare for run
# TF_NG_LOG_ID   Optional: String to included in name of log


set -e  # Fail on any command with non-zero exit

IMAGE_ID="${1}"
if [ -z "${IMAGE_ID}" ] ; then  # Required ImageID command-line parameter
    ( >&2 echo 'Please provide an image version as the first argument' )
    exit 1
fi

CMDLINE="${2}"
if [ -z "${CMDLINE}" ] ; then  # Required Command command-line parameter
    ( >&2 echo "Second parameter must be a single-quoted command to run in the docker container")
    exit 1
fi

if [ -z "${TF_NG_DATASET}" ] ; then  # Required TF_NG_DATASET env var parameter
    ( >&2 echo "Second parameter must be an ID, which will be used to generate the log file")
    exit 1
fi

if [ -z "${TF_NG_LOG_ID}" ] ; then  # Optional TF_NG_LOG_ID env var parameter
    TF_NG_LOG_ID=''  # Make sure this is set, for use below
fi

export PYTHON_VERSION_NUMBER='2'  # Build for Python 2 by default

# Note that the docker image must have been previously built using the
# make-docker-tf-ngraph-base.sh script (in the same directory as this script).
#
IMAGE_CLASS='ngtf_bridge_ci'
# IMAGE_ID set from 1st parameter, above

dataset_dir='/dataset'

docker_dataset='/dataset'

# Find the top-level bridge directory, so we can mount it into the docker
# container
bridge_dir="$(realpath ../../..)"

bridge_mountpoint='/home/dockuser/bridge'

RUNASUSER_SCRIPT="${bridge_mountpoint}/test/ci/docker/docker-scripts/run-as-user.sh"
BUILD_SCRIPT="${bridge_mountpoint}/test/ci/docker/docker-scripts/run-ngtf-bridge-validation-cmdline.sh"

docker run --rm \
       --env RUN_UID="$(id -u)" \
       --env RUN_CMD="${BUILD_SCRIPT}" \
       --env HOST_HOSTNAME="${HOSTNAME}" \
       --env CMDLINE="${CMDLINE}" \
       --env TF_NG_DATASET="${TF_NG_DATASET}" \
       --env TF_NG_LOG_ID="${TF_NG_LOG_ID}" \
       --env http_proxy=http://proxy-fm.intel.com:911 \
       --env https_proxy=http://proxy-fm.intel.com:912 \
       -v "${dataset_dir}:${docker_dataset}" \
       -v "${bridge_dir}:${bridge_mountpoint}" \
       "${IMAGE_CLASS}:${IMAGE_ID}" "${RUNASUSER_SCRIPT}"

