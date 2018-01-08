#!/bin/bash

# This script can run as normal user (no sudo required)
# It depends on a C++11 compatible compiler that can
# statically link libgcc libstdc++ (see 00_gcc7.sh)

set -e

while [ $# -gt 0 ] ; do
	case $1 in
		--demo)
			export DEMOMODE=demo
			export PRODUCT_NAME="ZynAddSubFx Demo"
			shift
			;;
		*)
			shift
			;;
	esac
done


# build in $HOME/src/zyn_build_<ARCH>
# and keep dependencies in in $HOME/src/zyn_stack_<ARCH>
ARCHITECTURE=x86_64 ./01_compile.sh
ARCHITECTURE=i386 ./01_compile.sh

export BUNDLEDIR=`mktemp -d -t bundle`
trap "rm -rf $BUNDLEDIR" EXIT

# take files from $HOME/src/zyn_build_<ARCH> and deploy to $BUNDLEDIR
./02_deploy.sh

# create a .pkg and .dmg from $BUNDLEDIR
# .pkg creation depends on /Developer/usr/bin/packagemaker
# (available by default on OSX 10.6)
./03_package.sh
