#!/bin/bash

set -e

user=$(whoami)

function usage() {
	echo "Usage: $0 [debug/debugoptimized/release]"
	exit 0
}

BUILD_TYPE=Release

if [ -n "$1" ]; then
	case $1 in
	"debug" | "debugonly")
		BUILD_TYPE=Debug
		;;
	"debugoptimized")
		BUILD_TYPE=RelWithDebInfo
		;;
	"release")
		BUILD_TYPE=Release
		;;
	*)
		usage
		;;
	esac
fi


WORKSPACE=$PWD
BUILD_DIR=${WORKSPACE}/build/static
CMAKE_DIR=${WORKSPACE}/static

cmake -S ${CMAKE_DIR} -B ${BUILD_DIR} -G Ninja -DCMAKE_BUILD_TYPE=${BUILD_TYPE}
cmake --build ${BUILD_DIR}
sudo cmake --install ${BUILD_DIR}