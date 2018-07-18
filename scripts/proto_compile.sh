#!/bin/bash

set -eu

COMPILER_VERSION="3.6.0"
PLUGIN_VERSION="0.4.3"
PROTO_VERSION="0.2.3"

VENDOR_DIR="./vendor"
OUTPUT_DIR="./PlasmaSwift"

COMPILER_ZIP_URL="https://github.com/google/protobuf/releases/download/v${COMPILER_VERSION}/protoc-${COMPILER_VERSION}-osx-x86_64.zip"
COMPILER_ZIP="${VENDOR_DIR}/$(basename $COMPILER_ZIP_URL)"

PLUGIN_REPO_GIT="https://github.com/grpc/grpc-swift.git"
PLUGIN_REPO_DIR="${VENDOR_DIR}/grpc-swift"
PLUGIN_DIR="${PLUGIN_REPO_DIR}/.build/debug"

PROTO_REPO_GIT="https://github.com/openfresh/plasma.git"
PROTO_REPO_DIR="${VENDOR_DIR}/plasma"
PROTO_DIR="${PROTO_REPO_DIR}/protobuf"

COMPILER="${VENDOR_DIR}/bin/protoc"
BUILD_LOG="${VENDOR_DIR}/plugins_build.log"
PROTOC_GEN_SWIFT="${PLUGIN_DIR}/protoc-gen-swift"
PROTOC_GEN_SWIFT_GRPC="${PLUGIN_DIR}/protoc-gen-swiftgrpc"
PROTO="${PROTO_DIR}/stream.proto"

if [[ `uname` != "Darwin" ]]; then
     echo "Unsupported OS (`uname`)"
     exit 1
fi

mkdir -p $VENDOR_DIR

if [ ! -e $COMPILER ]; then
    echo "Download protoc from '$COMPILER_ZIP_URL'"
    echo -n "....."

    curl -L -o $COMPILER_ZIP $COMPILER_ZIP_URL 2>/dev/null
    unzip -oq -d $VENDOR_DIR $COMPILER_ZIP

    echo -e "Done\n"
fi

if [[ ! -e $PROTOC_GEN_SWIFT || ! -e $PROTOC_GEN_SWIFT_GRPC ]]; then
    echo "Clone plugins from '$PLUGIN_REPO_GIT'"
    echo -n "....."

    git clone --depth 1 -b $PLUGIN_VERSION $PLUGIN_REPO_GIT $PLUGIN_REPO_DIR 2>/dev/null && :

    echo -e "Done\n"

    echo "Build plugins"
    echo "Build log output to '$(cd $(dirname $BUILD_LOG); pwd)/$(basename $BUILD_LOG)''"
    echo -n "....."

    swift build -Xcc -ISources/BoringSSL/include -Xlinker -lz --package-path $PLUGIN_REPO_DIR > $BUILD_LOG

    echo -e "Done\n"
fi

if [ ! -e $PROTO ]; then
    echo "Clone proto from '$PROTO_REPO_GIT'"
    echo -n "....."

    git clone --depth 1 -b $PROTO_VERSION $PROTO_REPO_GIT $PROTO_REPO_DIR 2>/dev/null && :

    echo -e "Done\n"
fi

echo "Compile proto"
echo -n "....."

PATH=$PLUGIN_DIR $COMPILER $PROTO \
  -I $PROTO_DIR \
  --swift_out=$OUTPUT_DIR \
  --swiftgrpc_out=Server=false:$OUTPUT_DIR

echo "Done"
