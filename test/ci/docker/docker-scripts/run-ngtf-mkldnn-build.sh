#!  /bin/bash

# This script is designed to be called from within a docker container.
# It is installed into a docker image.  It will not run outside the container.

set -e  # Make sure we exit on any command that returns non-zero
set -u  # No unset variables
set -o pipefail # Make sure cmds in pipe that are non-zero also fail immediately


if [ -z "${PYTHON_VERSION_NUMBER:-}" ] ; then
    ( >&2 echo "Env. variable PYTHON_VERSION_NUMBER has not been set" )
    exit 1
fi

export PYTHON_BIN_PATH="/usr/bin/python$PYTHON_VERSION_NUMBER"

# Set up some important known directories
bridge_dir='/home/dockuser/bridge'
ngtf_dir='/home/dockuser/ngtf'
ci_dir="${bridge_dir}/test/ci/docker"
venv_dir="/tmp/venv_python${PYTHON_VERSION_NUMBER}"

tf_orig_whl="tensorflow-1.6.0-cp27-cp27mu-linux_x86_64.whl"
tf_mkldnn_whl="tensorflow-mkldnn-1.6.0-cp27-cp27mu-linux_x86_64.whl"

# HOME is expected to be /home/dockuser.  See script run-as-user.sh, which
# sets this up.

# Set up a directory to build the wheel in, so we know where to grab
# the wheel from later.  If the directory already exists, remove it.
export WHEEL_BUILD_DIR="${ngtf_dir}/BUILD_WHEEL"

echo "In $(basename ${0}):"
echo ''
echo "  bridge_dir=${bridge_dir}"
echo "  ngtf_dir=${ngtf_dir}"
echo "  ci_dir=${ci_dir}"
echo "  venv_dir=${venv_dir}"
echo ''
echo "  HOME=${HOME}"
echo "  PYTHON_VERSION_NUMBER=${PYTHON_VERSION_NUMBER}"
echo "  PYTHON_BIN_PATH=${PYTHON_BIN_PATH}"
echo "  WHEEL_BUILD_DIR=${WHEEL_BUILD_DIR}  (Used by maint/build-install-tf.sh)"

# Do some up-front checks, to make sure necessary directories are in-place and
# build directories are not-in-place

if [ -d "${WHEEL_BUILD_DIR}" ] ; then
    ( >&2 echo '***** Error: *****' )
    ( >&2 echo "Wheel build directory already exists -- please remove it before calling this script: ${WHEEL_BUILD_DIR}" )
    exit 1
fi

if [ -d "${venv_dir}" ] ; then
    ( >&2 echo '***** Error: *****' )
    ( >&2 echo "Virtual-env build directory already exists -- please remove it before calling this script: ${venv_dir}" )
    exit 1
fi

# Make sure the Bazel cache is in /tmp, as docker images have too little space
# in the root filesystem, where /home (and $HOME/.cache) is.  Even though we
# may not be using the Bazel cache in the builds (in docker), we do this anyway
# in case we decide to turn the Bazel cache back on.
echo "Adjusting bazel cache to be located in /tmp/bazel-cache"
rm -fr "$HOME/.cache"
mkdir /tmp/bazel-cache
ln -s /tmp/bazel-cache "$HOME/.cache"

xtime="$(date)"
echo  ' '
echo  "===== Configuring Tensorflow-MKLDNN Build at ${xtime} ====="
echo  ' '

export CC_OPT_FLAGS="-march=native"
export USE_DEFAULT_PYTHON_LIB_PATH=1
export TF_ENABLE_XLA=1

export TF_NEED_MKL=1
export TF_DOWNLOAD_MKL=1

export TF_NEED_JEMALLOC=1
export TF_NEED_GCP=0
export TF_NEED_HDFS=0
export TF_NEED_VERBS=0
export TF_NEED_OPENCL=0
export TF_NEED_CUDA=0
export TF_NEED_MPI=0

cd "${ngtf_dir}"
./configure

xtime="$(date)"
echo  ' '
echo  "===== Starting Tensorflow-MKLDNN Binaries Build at ${xtime} ====="
echo  ' '

cd "${ngtf_dir}"

bazel build --verbose_failures --config=mkl ${BAZEL_BUILD_EXTRA_FLAGS:-} //tensorflow/tools/pip_package:build_pip_package

xtime="$(date)"
echo  ' '
echo  "===== Starting Tensorflow MKLDNN Wheel Build at ${xtime} ====="
echo  ' '

bazel-bin/tensorflow/tools/pip_package/build_pip_package "${WHEEL_BUILD_DIR}"

# Rename wheel file to indicate that it is a special ngraph-tensorflow
# mkldnn build
if [ -f "${WHEEL_BUILD_DIR}/${tf_orig_whl}" ] ; then
    set -x
    mv "${WHEEL_BUILD_DIR}/${tf_orig_whl}" "${WHEEL_BUILD_DIR}/${tf_mkldnn_whl}"
    set +x
else
    ( >&2 echo '***** Error: *****' )
    ( >&2 echo "Expected TF wheel does not appear to have been built: ${WHEEL_BUILD_DIR}/${tf_orig_whl}" )
    ( >&2 echo "Contents of wheel build directory ${WHEEL_BUILD_DIR}:")
    ( >&2 ls -l "${WHEEL_BUILD_DIR}")
    exit 1
fi

xtime="$(date)"
echo  ' '
echo  "===== Setting Up Virtual Environment for Tensorflow-MKLDNN Wheel at ${xtime} ====="
echo  ' '

cd "${ngtf_dir}"

# Make sure the bash shell prompt variables are set, as virtualenv crashes
# if PS2 is not set.
PS1='prompt> '
PS2='prompt-more> '
virtualenv --system-site-packages -p "${PYTHON_BIN_PATH}" "${venv_dir}"
source "${venv_dir}/bin/activate"

xtime="$(date)"
echo  ' '
echo  "===== Installing Tensorflow Wheel at ${xtime} ====="
echo  ' '

set -x
echo ' '
echo 'Proxy settings in exports:'
export | grep -i proxy
echo ' '
echo 'Building the wheel:'
cd "${ngtf_dir}"
declare WHEEL_FILE="${WHEEL_BUILD_DIR}/${tf_mkldnn_whl}"
# If installing into the OS, use:
# sudo --preserve-env --set-home pip install --ignore-installed ${PIP_INSTALL_EXTRA_ARGS:-} "${WHEEL_FILE}"
# Here we are installing into a virtual environment, so DO NOT USE SUDO!!!
pip install --ignore-installed ${PIP_INSTALL_EXTRA_ARGS:-} "${WHEEL_FILE}"
set +x

xtime="$(date)"
echo  ' '
echo  "===== Run Sanity Check for TF-MKLDNN at ${xtime} ====="
echo  ' '

# One cannot import tensorflow when in the top-level of the tensorflow source
# directory, so let's use /tmp
cd /tmp
python -c 'import tensorflow as tf;  hello = tf.constant("Hello world!"); sess = tf.Session(); print(sess.run(hello))'

xtime="$(date)"
echo  ' '
echo  "===== Deactivating the Virtual Environment at ${xtime} ====="
echo  ' '

deactivate

xtime="$(date)"
echo ' '
echo "===== Completed Tensorflow-MKLDNN Build at ${xtime} ====="
echo ' '
