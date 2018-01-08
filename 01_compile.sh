#!/bin/bash

#### some influential environment variables:
## we keep a copy of the sources here:
: ${SRCDIR=/var/tmp/src_cache}
## the architecture to build i386 or x86_64
: ${ARCHITECTURE="x86_64"}
## if the NOSTACK environment var is not empty, skip re-building the stack if it has been built before
: ${NOSTACK="true"}
## concurrency
: ${MAKEFLAGS="-j4"}
# demo or release
: ${DEMOMODE="release"}

## actual build location
: ${BUILDD=$HOME/src/zyn_build_$ARCHITECTURE}
## target install dir (chroot-like)
: ${PREFIX=$HOME/src/zyn_stack_$ARCHITECTURE}

################################################################################
set -e

GLOBAL_CFLAGS="-O3"
GLOBAL_CXXFLAGS="-O3"
GLOBAL_LDFLAGS="-headerpad_max_install_names"
OSXARCH="-arch $ARCHITECTURE"

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
## indirect build-dependencies; build-system

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

src ruby-2.3.6 tar.gz https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.6.tar.gz
CC=gcc CXX=g++ autoconfbuild

################################################################################

src zlib-1.2.7 tar.gz ftp://ftp.simplesystems.org/pub/libpng/png/src/history/zlib/zlib-1.2.7.tar.gz
CFLAGS="${GLOBAL_CFLAGS}" \
LDFLAGS="${GLOBAL_LDFLAGS}" \
./configure --archs="$OSXARCH" --prefix=$PREFIX
make $MAKEFLAGS
make install

################################################################################
## actual dependencies of zyn, hide visibility.

GLOBAL_CFLAGS="$GLOBAL_CFLAGS -fvisibility=hidden -fdata-sections -ffunction-sections"
GLOBAL_CXXFLAGS="$GLOBAL_CXXFLAGS -fvisibility=hidden -fvisibility-inlines-hidden -fdata-sections -ffunction-sections"
GLOBAL_LDFLAGS="$GLOBAL_LDFLAGS -Bsymbolic -fvisibility=hidden -fdata-sections -ffunction-sections"

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


src fftw-3.3.5 tar.gz http://www.fftw.org/fftw-3.3.5.tar.gz
autoconfbuild --with-our-malloc --disable-mpi


src mxml-2.10 tar.gz https://github.com/michaelrsweet/mxml/releases/download/release-2.10/mxml-2.10.tar.gz
## DSOFLAGS ? which standard did they read?
DSOFLAGS="${OSXARCH}${GLOBAL_LDFLAGS:+ $GLOBAL_LDFLAGS}" \
autoconfconf --disable-shared --enable-static
## compiling the self-test & doc fails with multi-arch, so work around this
make libmxml.a
make -i install TARGETS=""


src libuv-v1.9.1 tar.gz http://dist.libuv.org/dist/v1.9.1/libuv-v1.9.1.tar.gz
sed -i '' 's/__attribute__((visibility("default")))//' ./include/uv.h
LIBTOOLIZE=libtoolize ./autogen.sh
autoconfbuild --disable-shared --enable-static

################################################################################

## stack built complete
touch $PREFIX/zyn_stack_complete

################################################################################

else

GLOBAL_CFLAGS="$GLOBAL_CFLAGS -fvisibility=hidden -fdata-sections -ffunction-sections"
GLOBAL_CXXFLAGS="$GLOBAL_CXXFLAGS -fvisibility=hidden -fvisibility-inlines-hidden -fdata-sections -ffunction-sections"
GLOBAL_LDFLAGS="$GLOBAL_LDFLAGS -Bsymbolic -fvisibility=hidden -fdata-sections -ffunction-sections"

fi  ## NOSTACK
################################################################################
################################################################################



################################################################################
## mruby-zest

cd ${BUILDD}
git clone --single-branch --depth=1 --recursive https://github.com/mruby-zest/mruby-zest-build || true
cd mruby-zest-build
git reset --hard
git pull
git submodule update --recursive

ruby ./rebuild-fcache.rb

gcc ${GLOBAL_CPPFLAGS} ${GLOBAL_CFLAGS} ${OSXARCH} \
	-D STBTT_STATIC \
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
 BUILD_MODE=$DEMOMODE OS=Mac MRUBY_CONFIG=../build_config.rb rake clean all)

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

gcc ${GLOBAL_CPPFLAGS} ${GLOBAL_CFLAGS} ${OSXARCH} \
	-I deps/pugl \
	-std=gnu99 -static-libgcc \
	-o zyn-fusion \
	test-libversion.c \
	${GLOBAL_LDFLAGS} \
	deps/pugl/build/libpugl-0.a \
	-framework Cocoa -framework openGL


################################################################################
## and finally zyn itself

cd ${BUILDD}
git clone --single-branch --recursive https://github.com/zynaddsubfx/zynaddsubfx || true
cd zynaddsubfx
git reset --hard
git pull
git submodule update --recursive

## when using gcc-7.2 on macosx distro helpers re-define fmin(),fmax(),rint() and round()
if true; then
	sed -i '' 's/DISTRHO_OS_MAC/DISTRHOHOHOHO_OS_MAC/' DPF/distrho/DistrhoUtils.hpp
fi

##  Window.cpp needs to be compiled as obj-c++
cp DPF/dgl/src/Window.cpp DPF/dgl/src/Window.mm
sed -i '' 's/Window\.cpp/Window.mm/'  src/Plugin/ZynAddSubFX/CMakeLists.txt

#######################################################################################
## finally, configure and build zynaddsubfx

GLOBAL_LDFLAGS="$GLOBAL_LDFLAGS -Wl,-dead_strip"

rm -rf build
mkdir -p build; cd build
cmake -DCMAKE_INSTALL_PREFIX=/ \
	-DGuiModule=zest -DDemoMode=$DEMOMODE \
	-DCMAKE_BUILD_TYPE="None" \
	-DCMAKE_OSX_ARCHITECTURES="$ARCHITECTURE" \
	-DCMAKE_C_FLAGS="-I${PREFIX}/include $GLOBAL_CFLAGS -Wno-unused-parameter" \
	-DCMAKE_CXX_FLAGS="-I${PREFIX}/include $GLOBAL_CXXFLAGS -Wno-unused-parameter -fpermissive" \
	-DCMAKE_EXE_LINKER_FLAGS="-L$PREFIX/lib $GLOBAL_LDFLAGS -static-libgcc -static-libstdc++" \
	-DCMAKE_SHARED_LINKER_FLAGS="-L$PREFIX/lib $GLOBAL_LDFLAGS -static-libgcc -static-libstdc++" \
	-DCMAKE_SKIP_BUILD_RPATH=ON \
	-DNoNeonPlease=ON \
	..
make
