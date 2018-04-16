#!/bin/bash

## one time setup: install a C++11 compiler that also allows static linking.
## (compilation may take 1-3 hours and about 5GB of disk-space)
## make sure to compile with default compiler (system-wide /usr/bin/gcc)

MAKEFLAGS=-j2

mkdir /tmp/gccbuild/
cd /tmp/gccbuild/

curl -4 -O http://ftp.gnu.org/gnu/gmp/gmp-6.1.2.tar.bz2
curl -4 -O http://ftp.gnu.org/gnu/mpc/mpc-1.0.3.tar.gz
curl -O http://www.mpfr.org/mpfr-4.0.0/mpfr-4.0.0.tar.bz2
curl -O http://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2
curl -O ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/gcc-7.2.0/gcc-7.2.0.tar.gz

tar xf gmp-6.1.2.tar.bz2
tar xf mpc-1.0.3.tar.gz
tar xf mpfr-4.0.0.tar.bz2
tar xf isl-0.18.tar.bz2
tar xf gcc-7.2.0.tar.gz

cd gmp-6.1.2
mkdir build && cd build
../configure --prefix=/usr/local/gcc-7.2 --enable-cxx
make $MAKEFLAGS
sudo make install
cd ../..

cd mpfr-4.0.0
mkdir build && cd build
../configure --prefix=/usr/local/gcc-7.2 --with-gmp=/usr/local/gcc-7.2
make $MAKEFLAGS
sudo make install
cd ../..

cd mpc-1.0.3
sed -i '' s/mpfr_fmma/_mpfr_fmma/ src/mul.c
mkdir build && cd build
../configure --prefix=/usr/local/gcc-7.2 --with-gmp=/usr/local/gcc-7.2 --with-mpfr=/usr/local/gcc-7.2
make $MAKEFLAGS
sudo make install
cd ../..

cd isl-0.18
mkdir build && cd build
../configure --prefix=/usr/local/gcc-7.2 --with-gmp-prefix=/usr/local/gcc-7.2
make $MAKEFLAGS
sudo make install
cd ../..

cd gcc-7.2.0
mkdir build && cd build
../configure --prefix=/usr/local/gcc-7.2 --enable-checking=release --with-gmp=/usr/local/gcc-7.2 --with-mpfr=/usr/local/gcc-7.2 -with-mpc=/usr/local/gcc-7.2  --with-isl=/usr/local/gcc-7.2 --enable-languages=c,c++,objc,obj-c++  #  --program-suffix=-7.2
time make $MAKEFLAGS
sudo make install

echo " ---- DONE ---- "
echo "# set PATH to include /usr/local/gcc-7.2/bin"
echo "# ideally use via ccache.conf path=/usr/local/gcc-7.2/bin/"
