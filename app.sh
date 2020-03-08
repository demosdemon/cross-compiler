# 4.11 is the current stable, but we run 3.2.58 on older devices
export KERNEL_HEADERS="3.2.96"
export KERNEL_VERSION="3.2.58"
export GCC_VERSION="6.4.0"
export GMP_VERSION="6.1.2"
export MPFR_VERSION="3.1.6"
export MPC_VERSION="1.0.3"
export ISL_VERSION="0.18"
export CLOOG_VERSION="0.18.4"
export GLIBC_VERSION="2.25"

export HOST="${MACHTYPE}"
export TARGET="arm-drobo_$(uname -m)-linux-gnueabi"
export LC_ALL=POSIX
export DEST="${HOME}/xtools/toolchain/5n"

### BINUTILS ###
# https://www.gnu.org/software/binutils/
_build_binutils() {
local VERSION="2.28"
local FOLDER="binutils-${VERSION}"
local FILE="${FOLDER}.tar.bz2"
local URL="http://ftp.gnu.org/gnu/binutils/${FILE}"

_download_bz2 "${FILE}" "${URL}" "${FOLDER}"
rm -fr "target/${FOLDER}-build"
mkdir -p "target/${FOLDER}-build"
pushd "target/${FOLDER}-build"
AR=ar AS=as \
  "../${FOLDER}/configure" --prefix="${DEST}" \
    --target="${TARGET}" \
    --disable-multilib \
    --disable-werror
make
make install
popd
}

### KERNEL HEADERS ###
# https://www.kernel.org/category/releases.html
_build_kernel_headers() {
local VERSION="${KERNEL_HEADERS}"
local FOLDER="linux-${VERSION}"
local FILE="${FOLDER}.tar.xz"
local URL="https://cdn.kernel.org/pub/linux/kernel/v3.x/${FILE}"

_download_xz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
make headers_install ARCH=arm INSTALL_HDR_PATH="${DEST}/${TARGET}/usr"
popd
}

### GCC ###
# https://gcc.gnu.org/
# https://gmplib.org/
# http://www.mpfr.org/
# http://www.multiprecision.org/index.php?prog=mpc
# http://isl.gforge.inria.fr/
# http://www.cloog.org/
_build_gcc() {
local VERSION="${GCC_VERSION}"
local FOLDER="gcc-${VERSION}"
local FILE="${FOLDER}.tar.xz"
local URL="ftp://ftp.fu-berlin.de/unix/languages/gcc/releases/${FOLDER}/${FILE}"

_download_xz "${FILE}" "${URL}" "${FOLDER}"

### GMP ###
local GMP_FOLDER="gmp-${GMP_VERSION}"
local GMP_FILE="${GMP_FOLDER}.tar.xz"
local GMP_URL="https://gmplib.org/download/gmp/${GMP_FILE}"

_download_xz "${GMP_FILE}" "${GMP_URL}" "${GMP_FOLDER}"
rm -fr "target/${FOLDER}/gmp"
mv "target/${GMP_FOLDER}" "target/${FOLDER}/gmp"

### MPFR ###
local MPFR_FOLDER="mpfr-${MPFR_VERSION}"
local MPFR_FILE="${MPFR_FOLDER}.tar.xz"
local MPFR_URL="http://mpfr.loria.fr/${MPFR_FOLDER}/${MPFR_FILE}"

_download_xz "${MPFR_FILE}" "${MPFR_URL}" "${MPFR_FOLDER}"
rm -fr "target/${FOLDER}/mpfr"
mv "target/${MPFR_FOLDER}" "target/${FOLDER}/mpfr"

### MPC ###
local MPC_FOLDER="mpc-${MPC_VERSION}"
local MPC_FILE="${MPC_FOLDER}.tar.gz"
local MPC_URL="ftp://ftp.gnu.org/gnu/mpc/${MPC_FILE}"

_download_tgz "${MPC_FILE}" "${MPC_URL}" "${MPC_FOLDER}"
rm -fr "target/${FOLDER}/mpc"
mv "target/${MPC_FOLDER}" "target/${FOLDER}/mpc"

### ISL ###
local ISL_FOLDER="isl-${ISL_VERSION}"
local ISL_FILE="${ISL_FOLDER}.tar.xz"
local ISL_URL="http://isl.gforge.inria.fr/${ISL_FILE}"

_download_xz "${ISL_FILE}" "${ISL_URL}" "${ISL_FOLDER}"
rm -fr "target/${FOLDER}/isl"
mv "target/${ISL_FOLDER}" "target/${FOLDER}/isl"

### CLOOG ###
local CLOOG_FOLDER="cloog-${CLOOG_VERSION}"
local CLOOG_FILE="${CLOOG_FOLDER}.tar.gz"
local CLOOG_URL="http://www.bastoul.net/cloog/pages/download/${CLOOG_FILE}"

_download_tgz "${CLOOG_FILE}" "${CLOOG_URL}" "${CLOOG_FOLDER}"
rm -fr "target/${FOLDER}/cloog"
mv "target/${CLOOG_FOLDER}" "target/${FOLDER}/cloog"

rm -fr "target/${FOLDER}-build"
mkdir -p "target/${FOLDER}-build"
pushd "target/${FOLDER}-build"
"../${FOLDER}/configure" --prefix="${DEST}" \
  --target="${TARGET}" \
  --enable-languages=c,c++ --enable-lto \
  --disable-multilib \
  --with-sysroot="${DEST}/${TARGET}" \
  --with-build-sysroot="${DEST}/${TARGET}"
make all-gcc
make install-gcc
popd
}

### GLIBC ###
# https://www.gnu.org/software/libc/
_build_glibc_headers() {
# sudo apt-get install gawk
local VERSION="${GLIBC_VERSION}"
local FOLDER="glibc-${VERSION}"
local FILE="${FOLDER}.tar.xz"
local URL="http://ftp.gnu.org/gnu/glibc/${FILE}"

# use the cross-compiler
PATH="${DEST}/bin:${PATH}"

_download_xz "${FILE}" "${URL}" "${FOLDER}"
rm -fr "target/${FOLDER}-build"
mkdir -p "target/${FOLDER}-build"
pushd "target/${FOLDER}-build"
"../${FOLDER}/configure" --prefix="" \
  --build="${HOST}" --host="${TARGET}" --target="${TARGET}" \
  --with-headers="${DEST}/${TARGET}/usr/include" \
  --enable-kernel="${KERNEL_VERSION}" \
  --enable-addons \
  --enable-obsolete-rpc \
  --disable-multilib \
  libc_cv_forced_unwind=yes \
  libc_cv_c_cleanup=yes \
  CFLAGS="-march=armv7-a -mcpu=marvell-pj4 -mfpu=vfpv3-d16 -mfloat-abi=softfp -O2"
make install-bootstrap-headers=yes install-headers DESTDIR="${DEST}/${TARGET}"
make csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o "${DEST}/${TARGET}/lib"
"${DEST}/bin/${TARGET}-gcc" -nostdlib -nostartfiles -shared -x c /dev/null -o "${DEST}/${TARGET}/lib/libc.so"
touch "${DEST}/${TARGET}/include/gnu/stubs.h"
popd
}

### LIBGCC ###
# Requires gcc and glibc_headers
_build_libgcc() {
local VERSION="${GCC_VERSION}"
local FOLDER="gcc-${VERSION}"

pushd "target/${FOLDER}-build"
make all-target-libgcc
make install-target-libgcc
popd
}

### GLIBC ###
# Requires glibc_headers and libgcc
_build_glibc() {
local VERSION="${GLIBC_VERSION}"
local FOLDER="glibc-${VERSION}"

# use the cross-compiler
PATH="${DEST}/bin:${PATH}"

pushd "target/${FOLDER}-build"
make
make install DESTDIR="${DEST}/${TARGET}"
popd
}

### LIBSTD++ ###
# Requires glibc
_build_libstd() {
local VERSION="${GCC_VERSION}"
local FOLDER="gcc-${VERSION}"

pushd "target/${FOLDER}-build"
make
make install
popd
}

### YASM ###
# http://yasm.tortall.net/
_build_yasm() {
local VERSION="1.3.0"
local FOLDER="yasm-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="http://www.tortall.net/projects/yasm/releases/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --prefix="${DEST}" \
  --host="${HOST}" --build="${TARGET}" --program-prefix="${TARGET}-" \
  --disable-python --disable-python-bindings
make
make install
popd
}

### Additional file and folder fixes to make the toolchain work ###
_build_fixes() {
  rmdir "${DEST}/include"
  ln -fs "${TARGET}/include" "${DEST}/include"
  mv "${DEST}/lib/gcc/${TARGET}/${GCC_VERSION}/include-fixed/limits.h"{,.orig}
  cp "${BUILDDIR}/src/limits.h" "${DEST}/lib/gcc/${TARGET}/${GCC_VERSION}/include-fixed/limits.h"
}

### BUILD ###
_build() {
  _build_binutils
  _build_kernel_headers
  _build_gcc
  _build_glibc_headers
  _build_libgcc
  _build_glibc
  _build_libstd
  _build_fixes
  _package
}
