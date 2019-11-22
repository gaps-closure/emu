#!/bin/bash

QARCH="arm64"
UDIST="eoan"
SIZE="20G"
FILE="ubuntu-${ARCH}-${UDIST}-qemu.qcow2"
#KDIST=$UDIST   # ARM64 breaks on kernels after xenial on workhorse
KDIST="xenial" 

handle_opts() {
  local OPTIND
  while getopts ":a:d:s:f:" options; do
    case "${options}" in
      a)
        QARCH=${OPTARG}
        ;;
      d)
        UDIST=${OPTARG}
        ;;
      s)
        SIZE=${OPTARG}
        ;;
      f)
        FILE=${OPTARG}
        ;;
      :)
        echo "Error: -${OPTARG} requires an argument." 
        echo "Usage: $0 [ -a QARCH ] [ -d UDIST ] [-s SIZE] [-f FILE]" 
        exit 1
        ;;
      *)
        echo "Usage: $0 [ -a QARCH ] [ -d UDIST ] [-s SIZE] [-f FILE]" 
        exit 1
        ;;
    esac
    shift $((OPTIND-1))
  done
  case $UDIST in
    eoan)
      ;;
    *)
      echo "Unsupported Ubuntu distribution $UDIST" 
      exit 1
      ;;
  esac
  case $QARCH in
    amd64)
      ;;
    arm64)
      ;;
    *)
      echo "Unsupported architecture $QARCH" 
      exit 1
      ;;
  esac
}


install_nrl_core () {
  COREURL="https://github.com/coreemu/core/releases/download/release-5.5.2"
  COREDEB="core_python3_5.5.2_amd64.deb"
  case $1 in
    yes)
      #
      wget $COREURL/requirements.txt
      sudo -H pip3 install -r requirements.txt 
      wget $COREURL/$COREDEB
      sudo dpkg -i $COREDEB
      ;;
    *)
      ;;
  esac
}

prep_build_machine() {
  case $1 in
    yes)
      sudo apt update
      # sudo apt -y upgrade # XXX: maybe control with an arg?
      sudo apt install wget
      sudo apt install bash bridge-utils ebtables iproute xterm mgen traceroute
      sudo apt install build-essential libssl-dev libffi-dev 
      sudo apt install python3 python3-pip python3-dev libev-dev python3-venv
      sudo apt install tcl8.5 tk8.5 libtk-img 
      sudo apt install ethtool
      sudo apt install ubuntu-dev-tools
      sudo apt install qemu qemu-efi
      sudo apt install quagga
      sudo -H pip3 install --upgrade pip
      sudo -H pip3 install pexpect
      ;;
    *)
      ;;
  esac
}

setup_sbuild() {
  cat <<END > ~/.sbuildrc
$mailto = 'closure@groups.perspectalabs.com';
$build_dir='./build';
$log_dir="./build/logs";
1;
END
  mk-sbuild --arch $QARCH $UDIST
}

fetch_kernel() {
  KRNL="http://ports.ubuntu.com/ubuntu-ports/dists/${KDIST}/main/installer-${QARCH}/current/images/netboot/ubuntu-installer/${QARCH}/linux"
  wget $KRNL
}

build_vm_image() {
  echo "Building QEMU VM Image: $QARCH $UDIST $FILE $SIZE"
  mkdir -p ./build
  setup_sbuild
  cd ./build
  fetch_kernel
}

debootstrap_first_stage() {
  INCLUDES=""
  EXCLUDES=""
  sudo debootstrap \
    --verbose --foreign --arch=$QARCH \
    --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
    $UDIST rootfs
}

handle_opts "$@"
prep_build_machine no  # optional, can change to yes
install_nrl_core no    # optional, can change to yes
build_vm_image 

#python3 - <<END
#import pexpect
#END
