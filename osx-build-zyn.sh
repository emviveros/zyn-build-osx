#!/bin/bash

# This script builds an OSX version of zynaddsubfx
# (http://zynaddsubfx.sourceforge.net)
# and all its build-dependencies from scratch.
#
# It requires a working c-compiler with C++11 support,
# bash, sed, curl, make and git
#
# It can be run by a 'normal user' (no sudo required).
#
# The script is suitable for headless (automatic) builds, but
# note that the last step: building the DMG requires
# a "Finder" process. The user needs to be graphically
# logged in (but can be an inactive user, switch-user)
#

#### some influential environment variables:

## we keep a copy of the sources here:
: ${SRCDIR=/var/tmp/src_cache}
## actual build location
: ${BUILDD=$HOME/src/zyn_build}
## target install dir (chroot-like)
: ${PREFIX=$HOME/src/zyn_stack}
## where the resulting .dmg ends up
: ${OUTDIR="/tmp/"}
## concurrency
: ${MAKEFLAGS="-j4"}
## if the NOSTACK environment var is not empty, skip re-building the stack if it has been built before
: ${NOSTACK="true"}
## semicolon separated list of fat-binary architectures, ppc;i386;x86_64
: ${ARCHITECTURES="i386;x86_64"}


pushd "`/usr/bin/dirname \"$0\"`" > /dev/null; this_script_dir="`pwd`"; popd > /dev/null

################################################################################
#### set compiler flags depending on build-host

case `sw_vers -productVersion | cut -d'.' -f1,2` in
	"10.11")
		echo "ElCapitan"
		GLOBAL_CPPFLAGS="-Wno-error=unused-command-line-argument"
		GLOBAL_CFLAGS="-O3 -Wno-error=unused-command-line-argument"
		GLOBAL_CXXFLAGS="-O3 -Wno-error=unused-command-line-argument"
		GLOBAL_LDFLAGS="-headerpad_max_install_names"
		ARCHITECTURES="x86_64"
		OSXARCH="-arch x86_64"
		;;
	"10.10")
		echo "Yosemite"
		GLOBAL_CPPFLAGS="-Wno-error=unused-command-line-argument"
		GLOBAL_CFLAGS="-O3 -Wno-error=unused-command-line-argument -mmacosx-version-min=10.9 -DMAC_OS_X_VERSION_MAX_ALLOWED=1090"
		GLOBAL_CXXFLAGS="-O3 -Wno-error=unused-command-line-argument -mmacosx-version-min=10.9 -DMAC_OS_X_VERSION_MAX_ALLOWED=1090"
		GLOBAL_LDFLAGS="-mmacosx-version-min=10.9 -DMAC_OS_X_VERSION_MAX_ALLOWED=1090 -headerpad_max_install_names"
		;;
	"10.6")
		ARCHITECTURES="x86_64"
		GLOBAL_CFLAGS="-O3"
		GLOBAL_CXXFLAGS="-O3"
		GLOBAL_LDFLAGS="-headerpad_max_install_names"
		;;
	*)
		echo "**UNTESTED OSX VERSION**"
		echo "if it works, please report back :)"
		ARCHITECTURES="i386;x86_64"
		OSXARCH="-arch i386 -arch x86_64"
		GLOBAL_CPPFLAGS="-mmacosx-version-min=10.5 -DMAC_OS_X_VERSION_MAX_ALLOWED=1090"
		GLOBAL_CFLAGS="-O3 -mmacosx-version-min=10.5 -DMAC_OS_X_VERSION_MAX_ALLOWED=1090"
		GLOBAL_CXXFLAGS="-O3 -mmacosx-version-min=10.5 -DMAC_OS_X_VERSION_MAX_ALLOWED=1090"
		GLOBAL_LDFLAGS="-mmacosx-version-min=10.5 -DMAC_OS_X_VERSION_MAX_ALLOWED=1090 -headerpad_max_install_names"
		;;
esac

if test -z "$OSXARCH"; then
	OLDIFS=$IFS
	IFS=';'
	for arch in $ARCHITECTURES; do
		OSXARCH="$OSXARCH -arch $arch"
	done
	echo "SET ARCH:  $OSXARCH"
	IFS=$OLDIFS
fi

#####
##### on 10.6 one time setup: install a C++11 compiler
##### (use with ccache path=/usr/local/gcc-7.2/bin/)
#####
## https://gmplib.org/download/gmp/gmp-6.1.2.tar.lz
## http://www.mpfr.org/mpfr-current/mpfr-4.0.0.tar.bz2
## ftp://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz
## ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2
## ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-7.2.0/gcc-7.2.0.tar.xz
##
## cd gmp-6.1.2
## mkdir build && cd build
## ../configure --prefix=/usr/local/gcc-7.2 --enable-cxx
## make -j 2
## sudo make install
## cd ../..
##
## cd mpfr-4.0.0
## mkdir build && cd build
## ../configure --prefix=/usr/local/gcc-7.2 --with-gmp=/usr/local/gcc-7.2
## make -j 2
## sudo make install
## cd ../..
##
## cd mpc-1.0.3
## sed -i '' s/mpfr_fmma/_mpfr_fmma/ src/mul.c
## mkdir build && cd build
## ./configure --prefix=/usr/local/gcc-7.2 --with-gmp=/usr/local/gcc-7.2 --with-mpfr=/usr/local/gcc-7.2
## make -j 2
## sudo make install
## cd ../..
##
## cd isl-0.18
## mkdir build && cd build
## ../configure --prefix=/usr/local/gcc-7.2 --with-gmp-prefix=/usr/local/gcc-7.2
## make -j 2
## sudo make install
## cd ../..
##
## cd gcc-7.2.0
## mkdir build && cd build
## ../configure --prefix=/usr/local/gcc-7.2 --enable-checking=release --with-gmp=/usr/local/gcc-7.2 --with-mpfr=/usr/local/gcc-7.2 -with-mpc=/usr/local/gcc-7.2  --with-isl=/usr/local/gcc-7.2 --enable-languages=c,c++,fortran,objc,obj-c++  #  --program-suffix=-7.2
## time make -j 2
## sudo make install


################################################################################
set -e

unset PKG_CONFIG_PATH
export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig
export PREFIX
export SRCDIR

export PATH=${PREFIX}/bin:${HOME}/bin:/usr/local/git/bin/:/usr/bin:/bin:/usr/sbin:/sbin

################################################################################

function autoconfconf {
set -e
echo "======= $(pwd) ======="
	CPPFLAGS="-I${PREFIX}/include${GLOBAL_CPPFLAGS:+ $GLOBAL_CPPFLAGS}" \
	CFLAGS="${OSXARCH}${GLOBAL_CFLAGS:+ $GLOBAL_CFLAGS}" \
	CXXFLAGS="${OSXARCH}${GLOBAL_CXXFLAGS:+ $GLOBAL_CXXFLAGS}" \
	LDFLAGS="${OSXARCH}${GLOBAL_LDFLAGS:+ $GLOBAL_LDFLAGS}" \
	./configure --disable-dependency-tracking --prefix=$PREFIX $@
}

function autoconfbuild {
set -e
	autoconfconf $@
	make $MAKEFLAGS
	make install
}

function download {
	echo "--- Downloading.. $2"
	test -f ${SRCDIR}/$1 || curl -L -o ${SRCDIR}/$1 $2
}

function src {
	download ${1}.${2} $3
	cd ${BUILDD}
	rm -rf $1
	tar xf ${SRCDIR}/${1}.${2}
	cd $1
}

################################################################################
###  COMPILE THE BUILD-DEPENDENCIES  -> NOSTACK
################################################################################

## if the NOSTACK environment is not empty, skip re-building the stack
## if it has been built before
if test ! -f "${PREFIX}/zyn_stack_complete" -o -z "$NOSTACK"; then


## Start with a clean slate
rm -rf ${BUILDD}
rm -rf ${PREFIX}

mkdir -p ${SRCDIR}
mkdir -p ${PREFIX}
mkdir -p ${BUILDD}

################################################################################

src m4-1.4.17 tar.gz http://ftp.gnu.org/gnu/m4/m4-1.4.17.tar.gz
./configure --prefix=$PREFIX
make && make install

src pkg-config-0.28 tar.gz http://pkgconfig.freedesktop.org/releases/pkg-config-0.28.tar.gz
./configure --prefix=$PREFIX --with-internal-glib
make $MAKEFLAGS
make install

src autoconf-2.69 tar.gz http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz
autoconfbuild
hash autoconf
hash autoreconf

src automake-1.14 tar.gz http://ftp.gnu.org/gnu/automake/automake-1.14.tar.gz
autoconfbuild
hash automake

src libtool-2.4 tar.gz http://ftp.gnu.org/gnu/libtool/libtool-2.4.tar.gz
autoconfbuild
hash libtoolize

src make-4.1 tar.gz http://ftp.gnu.org/gnu/make/make-4.1.tar.gz
autoconfbuild
hash make

src cmake-2.8.12.2 tar.gz http://www.cmake.org/files/v2.8/cmake-2.8.12.2.tar.gz
./bootstrap --prefix=$PREFIX
make $MAKEFLAGS
make install

################################################################################

src zlib-1.2.7 tar.gz ftp://ftp.simplesystems.org/pub/libpng/png/src/history/zlib/zlib-1.2.7.tar.gz
CFLAGS="${GLOBAL_CFLAGS}" \
LDFLAGS="${GLOBAL_LDFLAGS}" \
./configure --archs="$OSXARCH" --prefix=$PREFIX
make $MAKEFLAGS
make install


src liblo-0.28 tar.gz http://downloads.sourceforge.net/liblo/liblo-0.28.tar.gz
## clang/OSX is picky about abs()  -Werror,-Wabsolute-value
patch -p1 << EOF
--- a/src/message.c	2015-11-17 17:12:15.000000000 +0100
+++ b/src/message.c	2015-11-17 17:13:28.000000000 +0100
@@ -997,6 +997,6 @@
     if (d != end) {
         fprintf(stderr,
                 "liblo warning: type and data do not match (off by %d) in message %p\n",
-                abs((char *) d - (char *) end), m);
+                abs((int)((char *) d - (char *) end)), m);
     }
 }
@@ -1014,6 +1014,8 @@
     int size;
     int i;
 
+    val64.nl = 0;
+
     size = lo_arg_size(type, data);
     if (size == 4 || type == LO_BLOB) {
         if (bigendian) {
EOF

autoconfbuild --disable-shared --enable-static


src freetype-2.5.3 tar.gz http://download.savannah.gnu.org/releases/freetype/freetype-2.5.3.tar.gz
autoconfbuild --with-harfbuzz=no --with-png=no --with-bzip2=no


src fftw-3.3.4 tar.gz http://www.fftw.org/fftw-3.3.4.tar.gz
autoconfbuild --with-our-malloc --disable-mpi


src mxml-2.10 tar.gz https://github.com/michaelrsweet/mxml/releases/download/release-2.10/mxml-2.10.tar.gz
## DSOFLAGS ? which standard did they read?
DSOFLAGS="${OSXARCH}${GLOBAL_LDFLAGS:+ $GLOBAL_LDFLAGS}" \
autoconfconf --disable-shared --enable-static
## compiling the self-test & doc fails with multi-arch, so work around this
make libmxml.a
make -i install TARGETS=""


src libuv-v1.9.1 tar.gz http://dist.libuv.org/dist/v1.9.1/libuv-v1.9.1.tar.gz
LIBTOOLIZE=libtoolize ./autogen.sh
autoconfbuild

################################################################################

src ruby-2.3.6 tar.gz https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.6.tar.gz
CC=gcc CXX=g++ autoconfbuild

################################################################################

### NO AUDIO ###  plugin versions only
if false; then

####
## we only want jack headers - not the complete jack installation, sadly upsteam
## only provides a osx installer (which needs admin privileges and drops things
## to /usr/local/ --- this is a re-pack of the relevant files from there.

download jack_osx_dev.tar.gz http://robin.linuxaudio.org/jack_osx_dev.tar.gz
cd "$PREFIX"
tar xzf ${SRCDIR}/jack_osx_dev.tar.gz
"$PREFIX"/update_pc_prefix.sh

####
## does not build cleanly with multiarch (little/big endian),
## TODO build separate dylibs (one for every arch) then lipo combine them and
## ifdef the mixed header.
## it's optional for zynaddsubfx, since zyn needs C++11 and there's no
## easy way to build PPC binaries with a C++11 compiler we don't care..

src portaudio tgz http://portaudio.com/archives/pa_stable_v19_20140130.tgz
sed -i '' 's/-Werror//g' configure
autoconfbuild --enable-mac-universal=no --enable-static=no

####
## portmidi needs a bit of convincing..
download portmidi-src-217.zip http://sourceforge.net/projects/portmedia/files/portmidi/217/portmidi-src-217.zip/download
cd ${BUILDD}
rm -rf portmidi
unzip ${SRCDIR}/portmidi-src-217.zip
cd portmidi
## XXX pass this via cmake args somehow, yet the 'normal' way for cmake does not
## seem to apply...  whatever. sed to he rescue
# -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=10.5 -DCMAKE_OSX_ARCHITECTURES="i386;x86_64"
if ! echo "$OSXARCH" | grep -q "i386"; then
sed -i '' 's/ i386//g' CMakeLists.txt
fi
if ! echo "$OSXARCH" | grep -q "ppc"; then
sed -i '' 's/ ppc//g' CMakeLists.txt
fi
if ! echo "$OSXARCH" | grep -q "x86_64"; then
sed -i '' 's/ x86_64//g' CMakeLists.txt
fi
## Argh! portmidi FORCE hardcodes the sysroot to 10.5
sed -i '' 's/CMAKE_OSX_SYSROOT /CMAKE_XXX_SYSROOT /g' ./pm_common/CMakeLists.txt
CFLAGS="${OSXARCH} ${GLOBAL_CFLAGS}" \
CXXFLAGS="${OSXARCH} ${GLOBAL_CXXFLAGS}" \
LDFLAGS="${OSXARCH} ${GLOBAL_LDFLAGS}" \
make -f pm_mac/Makefile.osx configuration=Release PF=${PREFIX} CMAKE_OSX_SYSROOT="-g"
## cd Release; make install # is also broken without sudo and with custom prefix
## so just deploy manually..
cp Release/libportmidi.dylib ${PREFIX}/lib/
install_name_tool -id ${PREFIX}/lib/libportmidi.dylib ${PREFIX}/lib/libportmidi.dylib
cp pm_common/portmidi.h ${PREFIX}/include
cp porttime/porttime.h ${PREFIX}/include

fi ## END NO AUIO

################################################################################

## stack built complete
touch $PREFIX/zyn_stack_complete

################################################################################
fi  ## NOSTACK
################################################################################


################################################################################
## mruby-zest

cd ${BUILDD}
git clone --single-branch --depth=1 --recursive https://github.com/mruby-zest/mruby-zest-build || true
cd mruby-zest-build

ruby ./rebuild-fcache.rb

gcc ${GLOBAL_CPPFLAGS} ${GLOBAL_CFLAGS} ${OSXARCH} \
	-o deps/nanovg/src/nanovg.o \
	-c deps/nanovg/src/nanovg.c -fPIC
ar -rc deps/libnanovg.a deps/nanovg/src/*.o

( \
  cd deps/pugl && rm -rf build && \
  CC=gcc CFLAGS="${GLOBAL_CPPFLAGS} ${OSXARCH} ${GLOBAL_CFLAGS}" LINKFLAGS="${OSXARCH} $GLOBAL_LDFLAGS" \
  ./waf configure --no-cairo --static && \
  ./waf \
)

CFLAGS="-I${PREFIX}/include ${GLOBAL_CPPFLAGS} ${OSXARCH} ${GLOBAL_CFLAGS}" make -C src/osc-bridge lib

cp -v ${PREFIX}/lib/libuv.a deps/

( cd mruby && \
 CFLAGS="-I${PREFIX}/include ${GLOBAL_CPPFLAGS} ${OSXARCH} ${GLOBAL_CFLAGS}" \
 LDFLAGS="${OSXARCH} ${GLOBAL_LDFLAGS}" \
 OS=Mac MRUBY_CONFIG=../build_config.rb rake )

cd ${BUILDD}/mruby-zest-build

gcc ${GLOBAL_CPPFLAGS} ${GLOBAL_CFLAGS} ${OSXARCH} \
	-shared -pthread \
	-static-libgcc \
	-o libzest.dylib \
	`find mruby/build/host -type f -name "*.o" | grep -v bin` ./deps/libnanovg.a \
	${GLOBAL_LDFLAGS} \
	deps/libnanovg.a \
	src/osc-bridge/libosc-bridge.a \
	${PREFIX}/lib/libuv.a

file libzest.dylib
otool -L libzest.dylib

gcc ${GLOBAL_CPPFLAGS} ${GLOBAL_CFLAGS} ${OSXARCH} \
	-I deps/pugl \
	-std=gnu99 -static-libgcc \
	-o zyn-fusion \
	test-libversion.c \
	${GLOBAL_LDFLAGS} \
	deps/pugl/build/libpugl-0.a \
	-framework Cocoa -framework openGL

file zyn-fusion
otool -L zyn-fusion

################################################################################

cd ${BUILDD}
git clone --single-branch --recursive https://github.com/zynaddsubfx/zynaddsubfx || true
cd zynaddsubfx

## version string for bundle
VERSION=`git describe --tags | sed 's/-g[a-f0-9]*$//'`


## when using gcc-7.2 on macosx distro helpers re-define fmin(),fmax(),rint() and round()
if true; then
	sed -i '' 's/DISTRHO_OS_MAC/DISTRHOHOHOHO_OS_MAC/' DPF/distrho/DistrhoUtils.hpp
fi

##  Window.cpp needs to be compiled as obj-c++
cp DPF/dgl/src/Window.cpp DPF/dgl/src/Window.mm
sed -i '' 's/Window\.cpp/Window.mm/'  src/Plugin/ZynAddSubFX/CMakeLists.txt

#######################################################################################
## finally, configure and build zynaddsubfx

rm -rf build
mkdir -p build; cd build
cmake -DCMAKE_INSTALL_PREFIX=/ \
	-DGuiModule=zest -DDemoMode=release \
	-DCMAKE_BUILD_TYPE="None" \
	-DCMAKE_OSX_ARCHITECTURES="$ARCHITECTURES" \
	-DCMAKE_C_FLAGS="-I${PREFIX}/include $GLOBAL_CFLAGS -Wno-unused-parameter -static-libgcc" \
	-DCMAKE_CXX_FLAGS="-I${PREFIX}/include $GLOBAL_CXXFLAGS -Wno-unused-parameter -fpermissive -static-libstdc++" \
	-DCMAKE_EXE_LINKER_FLAGS="-L$PREFIX/lib $GLOBAL_LDFLAGS -static-libgcc -static-libstdc++" \
	-DCMAKE_SHARED_LINKER_FLAGS="-L$PREFIX/lib $GLOBAL_LDFLAGS -static-libgcc -static-libstdc++" \
	-DCMAKE_SKIP_BUILD_RPATH=ON \
	-DNoNeonPlease=ON \
	..
make

################################################################################
## Prepare application bundle dir (for make install)

PRODUCT_NAME="ZynAddSubFx"
RSRC_DIR="$this_script_dir"

export BUNDLEDIR=`mktemp -d -t bundle`
trap "rm -rf $BUNDLEDIR" EXIT

TARGET_CONTENTS="${BUNDLEDIR}/inst/"

DESTDIR=${TARGET_CONTENTS} make install

#######################################################################################
#######################################################################################

MRUBYZEST=${BUILDD}/mruby-zest-build/
ZYNLV2=${BUNDLEDIR}/LV2/ZynAddSubFX.lv2/
ZYNVST=${BUNDLEDIR}/VST/ZynAddSubFX.vst/
ZYNDAT=${ZYNVST}Contents/Resources/

mv -v ${TARGET_CONTENTS}lib/lv2                   ${BUNDLEDIR}/LV2

cp -v ${MRUBYZEST}libzest.dylib                   ${ZYNLV2}
cp -a ${TARGET_CONTENTS}share/zynaddsubfx/banks   ${ZYNLV2}
mkdir                                             ${ZYNLV2}font/
mkdir                                             ${ZYNLV2}schema/
mkdir                                             ${ZYNLV2}qml/
touch                                             ${ZYNLV2}qml/MainWindow.qml
cp -v ${MRUBYZEST}src/osc-bridge/schema/test.json ${ZYNLV2}schema/
cp -v ${MRUBYZEST}deps/nanovg/example/*.ttf       ${ZYNLV2}font/



mkdir -p ${ZYNVST}Contents/MacOS
mkdir -p ${ZYNDAT}
cp -v ${TARGET_CONTENTS}lib/vst/ZynAddSubFX.dylib ${ZYNVST}Contents/MacOS/
echo "BNDL????" > ${ZYNVST}Contents/PkgInfo

cp -v ${MRUBYZEST}libzest.dylib                   ${ZYNDAT}
cp -a ${TARGET_CONTENTS}share/zynaddsubfx/banks   ${ZYNDAT}
mkdir                                             ${ZYNDAT}font/
mkdir                                             ${ZYNDAT}schema/
mkdir                                             ${ZYNDAT}qml/
touch                                             ${ZYNDAT}qml/MainWindow.qml
cp -v ${MRUBYZEST}src/osc-bridge/schema/test.json ${ZYNDAT}schema/
cp -v ${MRUBYZEST}deps/nanovg/example/*.ttf       ${ZYNDAT}font/

cat >> ${ZYNVST}Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

<plist version="1.0">
  <dict>
    <key>CFBundleExecutable</key>
    <string>ZynAddSubFX</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ZynAddSubFx VST</string>
    <key>CFBundleIdentifier</key>
    <string>com.github.zynaddsubfx.vst</string>
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

##############################################################################
## all done. now roll a DMG

UC_DMG="${OUTDIR}${PRODUCT_NAME}-${VERSION}.dmg"

DMGBACKGROUND=${RSRC_DIR}/dmgbg.png
VOLNAME=$PRODUCT_NAME-${VERSION}
EXTRA_SPACE_MB=5

DMGMEGABYTES=$[ `du -sck "${BUNDLEDIR}" | tail -n 1 | cut -f 1` * 1024 / 1048576 + $EXTRA_SPACE_MB ]
echo "DMG MB = " $DMGMEGABYTES

MNTPATH=`mktemp -d -t mntpath`
TMPDMG=`mktemp -t tmpdmg`
ICNSTMP=`mktemp -t appicon`

trap "rm -rf $MNTPATH $TMPDMG ${TMPDMG}.dmg $ICNSTMP $BUNDLEDIR" EXIT

rm -f $UC_DMG "$TMPDMG" "${TMPDMG}.dmg" "$ICNSTMP ${ICNSTMP}.icns ${ICNSTMP}.rsrc"
rm -rf "$MNTPATH"
mkdir -p "$MNTPATH"

TMPDMG="${TMPDMG}.dmg"

hdiutil create -megabytes $DMGMEGABYTES "$TMPDMG"
DiskDevice=$(hdid -nomount "$TMPDMG" | grep Apple_HFS | cut -f 1 -d ' ')
newfs_hfs -v "${VOLNAME}" "${DiskDevice}"
mount -t hfs -o nobrowse "${DiskDevice}" "${MNTPATH}"

cp -a "${BUNDLEDIR}/LV2" "${MNTPATH}/"
cp -a "${BUNDLEDIR}/VST" "${MNTPATH}/"

mkdir "${MNTPATH}/.background"
cp -vi ${DMGBACKGROUND} "${MNTPATH}/.background/dmgbg.png"

echo "setting DMG background ..."

if test $(sw_vers -productVersion | cut -d '.' -f 2) -lt 9; then
	# OSX ..10.8.X
	DISKNAME=${VOLNAME}
else
	# OSX 10.9.X and later
	DISKNAME=`basename "${MNTPATH}"`
fi

echo '
   tell application "Finder"
     tell disk "'${DISKNAME}'"
	   open
	   delay 1
	   set current view of container window to icon view
	   set toolbar visible of container window to false
	   set statusbar visible of container window to false
	   set the bounds of container window to {400, 200, 800, 580}
	   set theViewOptions to the icon view options of container window
	   set arrangement of theViewOptions to not arranged
	   set icon size of theViewOptions to 64
	   set background picture of theViewOptions to file ".background:dmgbg.png"
	   make new alias file at container window to POSIX file "/Library/Audio/Plug-Ins/" with properties {name:"Plug-Ins"}
	   set position of item "Plug-Ins" of container window to {310, 100}
	   set position of item "LV2" of container window to {100, 260}
	   set position of item "VST" of container window to {310, 260}
	   close
	   open
	   update without registering applications
	   delay 5
	   eject
     end tell
   end tell
' | osascript || {
	echo "Failed to set background/arrange icons"
	umount "${DiskDevice}" || true
	hdiutil eject "${DiskDevice}"
	exit 1
}

set +e
chmod -Rf go-w "${MNTPATH}"
set -e
sync

echo "unmounting the disk image ..."
## Umount the image ('eject' above may already have done that)
umount "${DiskDevice}" || true
hdiutil eject "${DiskDevice}" || true

## Create a read-only version, use zlib compression
echo "compressing Image ..."
hdiutil convert -format UDZO "${TMPDMG}" -imagekey zlib-level=9 -o "${UC_DMG}"
## Delete the temporary files
rm "$TMPDMG"
rm -rf "$MNTPATH"

echo "setting file icon ..."

cp ${RSRC_DIR}/${PRODUCT_NAME}.icns ${ICNSTMP}.icns
sips -i ${ICNSTMP}.icns
DeRez -only icns ${ICNSTMP}.icns > ${ICNSTMP}.rsrc
Rez -append ${ICNSTMP}.rsrc -o "$UC_DMG"
SetFile -a C "$UC_DMG"

rm ${ICNSTMP}.icns ${ICNSTMP}.rsrc
rm -rf $BUNDLEDIR

echo
echo "packaging succeeded:"
ls -l "$UC_DMG"
echo "Done."
