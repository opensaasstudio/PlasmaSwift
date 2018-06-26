#!/bin/bash

set -e

PROTOC_VERSION="3.6.0"
PLUGIN_VERSION="0.4.3"

VENDOR_DIR="./vendor"
PROTO_DIR="./proto"
OUTPUT_DIR="./PlasmaSwift"

PROTOC_ZIP_NAME="protoc-${PROTOC_VERSION}-osx-x86_64.zip"
PROTOC_BIN_ZIP_URL="https://github.com/google/protobuf/releases/download/v${PROTOC_VERSION}/${PROTOC_ZIP_NAME}"
PROTOC_DOWNLOADED_ZIP="${VENDOR_DIR}/${PROTOC_ZIP_NAME}"

PLUGIN_REPO="https://github.com/grpc/grpc-swift.git"
PLUGIN_DIR="${VENDOR_DIR}/grpc-swift"
PLUGIN_BUILD_DIR="${PLUGIN_DIR}/.build/debug"

PROTOC="${VENDOR_DIR}/bin/protoc"
PROTOC_GEN_SWIFT="${PLUGIN_BUILD_DIR}/protoc-gen-swift"
PROTOC_GEN_SWIFT_GRPC="${PLUGIN_BUILD_DIR}/protoc-gen-swiftgrpc"

if [[ `uname` != "Darwin" ]]; then
     echo "Unsupported OS (`uname`)"
     exit 1
fi

if [ ! -e $PROTOC ]; then

    echo -n "Download protoc..."

    wget -nc -P $VENDOR_DIR $PROTOC_BIN_ZIP_URL 2>/dev/null
    unzip -oq -d ${VENDOR_DIR} $PROTOC_DOWNLOADED_ZIP

echo "Done"

fi

if [[ ! -e $PROTOC_GEN_SWIFT || ! -e $PROTOC_GEN_SWIFT_GRPC ]]; then

    echo -n "Build plugins..."

    git clone --depth 1 -b $PLUGIN_VERSION $PLUGIN_REPO $PLUGIN_DIR 2>/dev/null && :
    swift build -Xcc -ISources/BoringSSL/include -Xlinker -lz --package-path $PLUGIN_DIR

    echo "Done"

fi

echo -n "Compile proto..."

PATH=$PLUGIN_BUILD_DIR $PROTOC "${PROTO_DIR}/stream.proto" \
  -I $PROTO_DIR \
  --swift_opt=Visibility=Public \
  --swift_out=$OUTPUT_DIR \
  --swiftgrpc_out=Visibility=Public,Client=true,Server=false:$OUTPUT_DIR

echo "Done"