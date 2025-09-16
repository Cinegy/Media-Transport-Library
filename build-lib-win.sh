#!/bin/bash

set -e

function usage() {
	echo "Usage: $0 [debug/debugoptimized/plain/release]"
	exit 0
}

buildtype=release
enable_asan=false
enable_tap=false
enable_usdt=false

if [ -n "$1" ]; then
	case $1 in
	"debug")
		buildtype=debug
		;;
	"debugoptimized")
		buildtype=debugoptimized
		;;
	"plain")
		buildtype=plain
		;;
	"release")
		buildtype=release
		;;
	*)
		usage
		;;
	esac
fi

WORKSPACE=$PWD
LIB_BUILD_DIR=${WORKSPACE}/build

# build lib
meson setup "${LIB_BUILD_DIR}" -Dbuildtype="$buildtype" -Denable_asan="$enable_asan" -Denable_tap="$enable_tap" -Denable_usdt="$enable_usdt"
ninja -C "${LIB_BUILD_DIR}"
