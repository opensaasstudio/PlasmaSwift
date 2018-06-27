#!/bin/bash

set -eu

PROTOC_VERSION="3.6.0"
PLUGIN_VERSION="0.4.3"

PROTO=${1:?"set the path to proto as the first arg"}

VENDOR_DIR="./vendor"
OUTPUT_DIR="./PlasmaSwift"
BUILD_LOG_DIR="${VENDOR_DIR}/plugins_build.log"

PROTOC_ZIP_NAME="protoc-${PROTOC_VERSION}-osx-x86_64.zip"
PROTOC_BIN_ZIP_URL="https://github.com/google/protobuf/releases/download/v${PROTOC_VERSION}/${PROTOC_ZIP_NAME}"
PROTOC_ZIP="${VENDOR_DIR}/${PROTOC_ZIP_NAME}"

PLUGIN_REPO="https://github.com/grpc/grpc-swift.git"
PLUGIN_DIR="${VENDOR_DIR}/grpc-swift"
PLUGIN_BUILD_DIR="${PLUGIN_DIR}/.build/debug"

PROTOC="${VENDOR_DIR}/bin/protoc"
PROTOC_GEN_SWIFT="${PLUGIN_BUILD_DIR}/protoc-gen-swift"
PROTOC_GEN_SWIFT_GRPC="${PLUGIN_BUILD_DIR}/protoc-gen-swiftgrpc"

if [[ `uname` != "Darwin" ]]; then
     echo "unsupported OS (`uname`)"
     exit 1
fi

if [ ! -e $PROTO ]; then
    echo "proto file is missing..."
    exit 1
fi

if [ ! -e $PROTOC ]; then

    echo -n "download protoc..."

    wget -nc -P $VENDOR_DIR $PROTOC_BIN_ZIP_URL 2>/dev/null
    unzip -oq -d ${VENDOR_DIR} $PROTOC_ZIP

    echo "done"

fi

if [[ ! -e $PROTOC_GEN_SWIFT || ! -e $PROTOC_GEN_SWIFT_GRPC ]]; then

    echo -n "clone plugins..."

    git clone --depth 1 -b $PLUGIN_VERSION $PLUGIN_REPO $PLUGIN_DIR 2>/dev/null && :

    echo "done"
    echo -n "build plugins...build log output to '$(cd $(dirname $0); pwd)'..."

    swift build -Xcc -ISources/BoringSSL/include -Xlinker -lz --package-path $PLUGIN_DIR > $BUILD_LOG_DIR

    echo "done"

fi

echo -n "compile proto..."

PATH=$PLUGIN_BUILD_DIR $PROTOC $PROTO \
  -I $(dirname $PROTO) \
  --swift_opt=Visibility=Public \
  --swift_out=$OUTPUT_DIR \
  --swiftgrpc_out=Server=false:$OUTPUT_DIR

echo "done"