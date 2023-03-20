#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

REPO_TAR=$1
SHA=$2
REPO_URL="file://$(realpath $REPO_TAR)"

echo $REPO_URL

INSTALLATION_CODE=$($SCRIPT_DIR/installation-code.sh $REPO_URL $SHA)

PREAMBLE=$'workspace(name = "tf_modules_example")\n\n'

echo "$PREAMBLE$INSTALLATION_CODE" > $SCRIPT_DIR/../test/WORKSPACE

pushd $SCRIPT_DIR/../test
bazel build //...
popd