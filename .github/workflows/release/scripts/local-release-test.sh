#!/bin/bash

# Test for verifying the release scripts without GitHub Actions.
# Builds an archive and configures a workspace to use it.

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

$SCRIPT_DIR/build-archive.sh $SCRIPT_DIR/../../../../ /tmp/example.tar.gz
$SCRIPT_DIR/test-asset.sh /tmp/example.tar.gz $(sha256sum /tmp/example.tar.gz | cut -d " " -f 1)