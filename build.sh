#!/usr/bin/env bash

### bash best practices ###
# exit on error code
set -o errexit
# exit on unset variable
set -o nounset
# return error of last failed command in pipe
set -o pipefail
# expand aliases
shopt -s expand_aliases
# print trace
set -o xtrace

export BUILDDIR="$(dirname "$(realpath "$0")")"
pushd "${BUILDDIR}"

### logfile ###
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
logfile="logfile_${timestamp}.txt"
echo "${0} ${@}" > "${logfile}"
if [ -z "${CONTINUOUS_INTEGRATION:-}" ]; then
  # save stdout to logfile
  exec 1> >(tee -a "${logfile}")
  # redirect errors to stdout
  exec 2> >(tee -a "${logfile}" >&2)
else
  exec 1> "${logfile}"
  exec 2> >(tee -a "${logfile}" >&2)
fi

### environment setup ###
#export NAME="$(basename "${BUILDDIR}")"
#export DEST="${BUILD_DEST:-/mnt/DroboFS/Shares/DroboApps/${NAME}}"
export DEPS="${BUILDDIR}/target/install"
alias make="make -j8 V=1 VERBOSE=1"

_wget() {
  if [ -z "${CONTINUOUS_INTEGRATION:-}" ]; then
    wget "$@"
  else
    wget --no-check-certificate "$@"
  fi
}

### support functions ###
# Download a TAR file and unpack it, removing old files.
# $1: file
# $2: url
# $3: folder
_download_tar() {
  [[ ! -d "download" ]]      && mkdir -p "download"
  [[ ! -d "target" ]]        && mkdir -p "target"
  [[ ! -f "download/${1}" ]] && _wget -O "download/${1}" "${2}"
  [[   -d "target/${3}" ]]   && rm -fr "target/${3}"
  [[ ! -d "target/${3}" ]]   && tar -xf "download/${1}" -C target
  return 0
}

# Download a TGZ file and unpack it, removing old files.
# $1: file
# $2: url
# $3: folder
_download_tgz() {
  [[ ! -d "download" ]]      && mkdir -p "download"
  [[ ! -d "target" ]]        && mkdir -p "target"
  [[ ! -f "download/${1}" ]] && _wget -O "download/${1}" "${2}"
  [[   -d "target/${3}" ]]   && rm -fr "target/${3}"
  [[ ! -d "target/${3}" ]]   && tar -zxf "download/${1}" -C target
  return 0
}

# Download a BZ2 file and unpack it, removing old files.
# $1: file
# $2: url
# $3: folder
_download_bz2() {
  [[ ! -d "download" ]]      && mkdir -p "download"
  [[ ! -d "target" ]]        && mkdir -p "target"
  [[ ! -f "download/${1}" ]] && _wget -O "download/${1}" "${2}"
  [[   -d "target/${3}" ]]   && rm -fr "target/${3}"
  [[ ! -d "target/${3}" ]]   && tar -jxf "download/${1}" -C target
  return 0
}

# Download a XZ file and unpack it, removing old files.
# $1: file
# $2: url
# $3: folder
_download_xz() {
  [[ ! -d "download" ]]      && mkdir -p "download"
  [[ ! -d "target" ]]        && mkdir -p "target"
  [[ ! -f "download/${1}" ]] && _wget -O "download/${1}" "${2}"
  [[   -d "target/${3}" ]]   && rm -fr "target/${3}"
  [[ ! -d "target/${3}" ]]   && tar -Jxf "download/${1}" -C target
  return 0
}

# Download a ZIP file and unpack it, removing old files.
# $1: file
# $2: url
# $3: folder
_download_zip() {
  [[ ! -d "download" ]]      && mkdir -p "download"
  [[ ! -d "target" ]]        && mkdir -p "target"
  [[ ! -f "download/${1}" ]] && _wget -O "download/${1}" "${2}"
  [[   -d "target/${3}" ]]   && rm -fr "target/${3}"
  [[ ! -d "target/${3}" ]]   && unzip -od "target" "download/${1}"
  return 0
}

# Download a DroboApp and unpack it, removing old files.
# $1: file
# $2: url
# $3: folder
_download_app() {
  [[ ! -d "download" ]]      && mkdir -p "download"
  [[ ! -d "target" ]]        && mkdir -p "target"
  [[ ! -f "download/${1}" ]] && _wget -O "download/${1}" "${2}"
  [[   -d "target/${3}" ]]   && rm -fr "target/${3}"
  mkdir -p "target/${3}"
  tar -zxf "download/${1}" -C "target/${3}"
  return 0
}

# Clone last commit of a single branch from git, removing old files.
# $1: branch
# $2: folder
# $3: url
_download_git() {
  [[ ! -d "target" ]]        && mkdir -p "target"
  [[   -d "target/${2}" ]]   && rm -fr "target/${2}"
  [[ ! -d "target/${2}" ]]   && git clone --branch "${1}" --single-branch --depth 1 "${3}" "target/${2}"
  return 0
}

# Download a file, overwriting existing.
# $1: file
# $2: url
_download_file() {
  [[ ! -d "download" ]]      && mkdir -p "download"
  [[ ! -f "download/${1}" ]] && _wget -O "download/${1}" "${2}"
  return 0
}

# Download a file in a specific folder, overwriting existing.
# $1: file
# $2: url
# $3: folder
_download_file_in_folder() {
  [[ ! -d "download/${3}" ]]      && mkdir -p "download/${3}"
  [[ ! -f "download/${3}/${1}" ]] && _wget -O "download/${3}/${1}" "${2}"
  return 0
}

# Create a tar.gz package.
_create_tgz() {
  local FILE="${BUILDDIR}/${TARGET}.tar.gz"

  if [[ -f "${FILE}" ]]; then
    rm -v "${FILE}"
  fi

  pushd "${DEST}"
  tar --verbose --create --numeric-owner --owner=0 --group=0 --gzip --file "${FILE}" *
  popd
}

# Create a tar.xz package.
_create_txz() {
  local FILE="${BUILDDIR}/${TARGET}.tar.xz"

  if [[ -f "${FILE}" ]]; then
    rm -v "${FILE}"
  fi

  pushd "${DEST}"
  tar --verbose --create --numeric-owner --owner=0 --group=0 --xz --file "${FILE}" *
  popd
}

# Package the toolchain
_package() {
  mkdir -p "${DEST}"
  [[ -d "src/dest" ]] && cp -afR "src/dest"/* "${DEST}"/
  find "${DEST}" -name "._*" -print -delete
  #_create_tgz
  _create_txz
}

# Remove all compiled files.
_clean() {
  rm -fr "${DEPS}"
  rm -fr "${DEST}"
  rm -fr target/*
}

# Removes all files created during the build.
_dist_clean() {
  _clean
  rm -f logfile*
  rm -fr download/*
}

### application-specific functions ###
. app.sh

if [ -n "${1:-}" ]; then
  while [ -n "${1:-}" ]; do
    case "${1}" in
      clean)     _clean ;;
      distclean) _dist_clean ;;
      all)       _build ;;
      package)   _package ;;
      *)         _build_${1} ;;
    esac
    shift
  done
else
  _build
fi
popd
