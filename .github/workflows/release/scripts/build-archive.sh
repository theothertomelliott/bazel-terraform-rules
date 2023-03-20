#!/bin/bash

SOURCE_DIR=$1
ARCHIVE_PATH=$2

pushd $SOURCE_DIR
tar -czvf $ARCHIVE_PATH .
popd