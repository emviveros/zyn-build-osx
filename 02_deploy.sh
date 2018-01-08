#!/bin/bash
set -e

test -n $BUNDLEDIR
test -d $BUNDLEDIR
test -d $HOME/src/zyn_build_x86_64/zynaddsubfx/build
test -d $HOME/src/zyn_build_i386/zynaddsubfx/build

################################################################################

cd $HOME/src/zyn_build_x86_64/zynaddsubfx/build
DESTDIR=${BUNDLEDIR}/64 make install
VERSION=`git describe --tags | sed 's/-g[a-f0-9]*$//'`

cd $HOME/src/zyn_build_i386/zynaddsubfx/build
DESTDIR=${BUNDLEDIR}/32 make install

#######################################################################################

function macvst {
	mkdir -p $1/Contents/MacOS

	echo "BNDL????" > $1/Contents/PkgInfo

	cat >> $1/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
  <dict>
    <key>CFBundleExecutable</key>
    <string>${2}.dylib</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ZynAddSubFx VST</string>
    <key>CFBundleIdentifier</key>
    <string>com.github.zynaddsubfx.vst.$2</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CSResourcesFileMapped</key>
    <true/>
    <key>CFBundleSignature</key>
    <string>????</string>
  </dict>
</plist>
EOF
}

function zynresources {
	# $1: dest $2: zyn-install $3: mruby-zest
	mkdir ${1}/font/
	mkdir ${1}/schema/
	mkdir ${1}/qml/
	touch ${1}/qml/MainWindow.qml
	cp -a ${2}/share/zynaddsubfx/banks         ${1}/
	cp -v ${3}/src/osc-bridge/schema/test.json ${1}/schema/
	cp -v ${3}/deps/nanovg/example/*.ttf       ${1}/font/
}

#######################################################################################

MRUBYZEST32=$HOME/src/zyn_build_i386/mruby-zest-build
MRUBYZEST64=$HOME/src/zyn_build_x86_64/mruby-zest-build

ZYNLV2=${BUNDLEDIR}/inst/LV2/ZynAddSubFX.lv2
ZYNVST=${BUNDLEDIR}/inst/VST/ZynAddSubFX.vst

ZYNVSTRES=${ZYNVST}/Contents/Resources

mkdir -p ${ZYNLV2}
mkdir -p ${ZYNVSTRES}

cp -a ${BUNDLEDIR}/64/lib/lv2/ZynAddSubFX.lv2presets ${BUNDLEDIR}/inst/LV2/

zynresources "${ZYNLV2}" "${BUNDLEDIR}/64" "${MRUBYZEST64}"
zynresources "${ZYNVSTRES}" "${BUNDLEDIR}/64" "${MRUBYZEST64}"

cp -a ${BUNDLEDIR}/64/lib/lv2/ZynAddSubFX.lv2/* ${ZYNLV2}

lipo -create \
	${BUNDLEDIR}/64/lib/lv2/ZynAddSubFX.lv2/ZynAddSubFX.dylib \
	${BUNDLEDIR}/32/lib/lv2/ZynAddSubFX.lv2/ZynAddSubFX.dylib \
	-output ${ZYNLV2}/ZynAddSubFX.dylib
strip -x -X ${ZYNLV2}/ZynAddSubFX.dylib

lipo -create \
	${BUNDLEDIR}/64/lib/lv2/ZynAddSubFX.lv2/ZynAddSubFX_ui.dylib \
	${BUNDLEDIR}/32/lib/lv2/ZynAddSubFX.lv2/ZynAddSubFX_ui.dylib \
	-output ${ZYNLV2}/ZynAddSubFX_ui.dylib
strip -x -X ${ZYNLV2}/ZynAddSubFX_ui.dylib

lipo -create \
	${MRUBYZEST32}/libzest.dylib \
	${MRUBYZEST64}/libzest.dylib \
	-output ${ZYNLV2}/libzest.dylib
strip -x -X ${ZYNLV2}/libzest.dylib

macvst "${ZYNVST}" "ZynAddSubFX"
cp -v ${ZYNLV2}/libzest.dylib $ZYNVSTRES

lipo -create \
	${BUNDLEDIR}/64/lib/vst/ZynAddSubFX.dylib \
	${BUNDLEDIR}/32/lib/vst/ZynAddSubFX.dylib \
	-output ${ZYNVST}/Contents/MacOS/ZynAddSubFX.dylib
strip -x -X ${ZYNVST}/Contents/MacOS/ZynAddSubFX.dylib
