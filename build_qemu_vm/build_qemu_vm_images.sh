#!/bin/bash

PREPSRV="no"
NRLCORE="no"
QARCH="arm64"
UDIST="eoan"
SIZE="20G"
KDIST="xenial" # ARM64 breaks on kernels after xenial on workhorse

usage_exit() {
  [[ -n "$1" ]] && echo $1
  echo "Usage: $0 [ -h ] [ -p ] [ -c ] \\"
  echo "          [ -a QARCH ] [ -d UDIST ] [-s SIZE ] [-k KDIST ]" 
  echo "-h        Help"
  echo "-p        Install pre-requisites on build server"
  echo "-c        Intall NRL CORE on build server"
  echo "-a QARCH  Architecture [arm64(default), amd64]"
  echo "-d UDIST  Ubuntu distro [eoan(default)]"
  echo "-s SIZE   Image size [20G(default),<any>]"
  echo "-k KDIST  Ubuntu distro for kernel [xenial(default),<any>]"
  exit 1
}

handle_opts() {
  local OPTIND
  while getopts ":cpha:d:s:k:" options; do
    case "${options}" in
      a) QARCH=${OPTARG} ;;
      d) UDIST=${OPTARG} ;;
      s) SIZE=${OPTARG}  ;;
      k) KDIST=${OPTARG} ;;
      p) PREPSRV="yes"   ;;
      c) NRLCORE="yes"   ;;
      h) usage_exit      ;;
      :) usage_exit "Error: -${OPTARG} requires an argument." ;;
      *) usage_exit; exit 1 ;;
    esac
    shift $((OPTIND-1))
  done
  case $UDIST in
    eoan)   ;;
    *)      usage_exit "Unsupported Ubuntu distribution $UDIST" ;;
  esac
  case $QARCH in
    amd64) ;;
    arm64) ;;
    *)     usage_exit "Unsupported architecture $QARCH" ;;
  esac
  if [ $NRLCORE == "yes" ]; then
    if [ $PREPSRV != "yes" ]; then
      usage_exit "-c option requires -p option to be also specified"
    fi
  fi
}

install_nrl_core () {
  COREURL="https://github.com/coreemu/core/releases/download/release-5.5.2"
  COREDEB="core_python3_5.5.2_amd64.deb"
  if [ $NRLCORE == "yes" ]; then
    echo "Installing NRL CORE ($COREDEB) on build server"
    rm -f requirements.txt $COREDEB
    wget $COREURL/requirements.txt
    wget $COREURL/$COREDEB
    sudo -H pip3 install -r requirements.txt 
    sudo dpkg -i $COREDEB
    rm -f requirements.txt $COREDEB
  fi
}

prep_build_machine() {
  if [ $PREPSRV == "yes" ]; then
    echo "Installing pre-requisites to build server"
    sudo apt update
    # sudo apt -y upgrade # XXX: maybe control with an arg?
    sudo apt install -y wget \
      bash bridge-utils ebtables iproute xterm mgen traceroute ethtool \
      build-essential libssl-dev libffi-dev \
      python3 python3-pip python3-dev libev-dev python3-venv \
      tcl8.5 tk8.5 libtk-img quagga \
      ubuntu-dev-tools qemu qemu-efi qemu-user-static
    sudo -H pip3 install --upgrade pip
    sudo -H pip3 install pexpect
    if [ $NRLCORE == "yes" ]; then
      install_nrl_core
    fi
  fi
}

fetch_kernel() {
  KRNL="dists/${KDIST}/main/installer-${QARCH}/current/images/netboot/ubuntu-installer/${QARCH}/linux"
  case $QARCH in
    amd64) KURL="http://archive.ubuntu.com/ubuntu" ;;
    arm64) KURL="http://ports.ubuntu.com/ubuntu-ports" ;;
    *) usage_exit "No support for $QARCH" ;;
  esac
  echo "Fetching boot kernel"
  rm -f linux
  wget $KURL/$KRNL
  mv linux linux-kernel-$QARCH-$KDIST
}

debootstrap_first_stage() {
  echo "Commencing debootstrap first stage"
  INCLUDES="socat zip unzip ssh"
  sudo debootstrap \
    --verbose --foreign --arch=$QARCH \
    --keyring=/usr/share/keyrings/ubuntu-archive-keyring.gpg \
    --include="$INCLUDES" \
    $UDIST rootfs
  dd if=/dev/zero of=rootfs.img bs=1 count=0 seek=20G
  mkfs.ext4 -b 4096 -F rootfs.img
  mkdir -p mnt
  sudo mount -o loop rootfs.img mnt
  sudo cp -a rootfs/. mnt
  sudo umount mnt
  sudo rm -rf rootfs mnt
  echo "First stage rootfs image built"
}

debootstrap_second_stage() {
  QEMUCMD="echo"
  case $QARCH in
    amd64)
      echo "Coming soon"
      exit 1
      QEMUCMD="qemu-system-x86_64 ..."
      ;;
    arm64)
      QEMUCMD="qemu-system-aarch64 -nographic -M virt -cpu cortex-a53 -m 1024 -drive file=rootfs.img,format=raw -netdev user,id=unet -device virtio-net-device,netdev=unet -kernel linux-kernel-${QARCH}-${KDIST} -append \"earlycon root=/dev/vda init=/bin/sh rw\""
      ;;
    *)
      echo "No support for $QARCH"
      exit 1
      ;;
  esac
  python3 - <<END
import os
import sys
import pexpect
def spl_print(lines): 
  l = lines.splitlines() 
  for y in l[:-1]: 
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))
child = pexpect.spawn('$QEMUCMD')
child.expect('\n# ',timeout=1800)
spl_print(child.before+child.after)
print('\nBooted, invoking debootstrap')
child.sendline('/debootstrap/debootstrap --second-stage')
i=1
while i!=0:
  i = child.expect(['\n# ','I: Unpacking ','I: Configuring'],timeout=1800)
  spl_print(child.before+child.after)
print('\nCompleted, second stage')
END
}

configure_system() {
  echo ""
}

make_golden_cow() {
  QFILE="ubuntu-${QARCH}-${UDIST}-qemu.qcow2"
  qemu-img convert -f raw -O qcow2 rootfs.img rootfs.qcow2
  rm -f rootfs.img
  mv rootfs.qcow2 $QFILE
  echo "Saved $QFILE"
}

build_vm_image() {
  echo "Building QEMU VM Image: $QARCH $UDIST (kern $KDIST) $SIZE"
  mkdir -p ./build
  cd ./build
  fetch_kernel
  debootstrap_first_stage
  cp rootfs.img rootfs.img-first
  #cp rootfs.img-first rootfs.img
  debootstrap_second_stage
  cp rootfs.img rootfs.img-second
  configure_system
  cp rootfs.img rootfs.img-configured
  make_golden_cow
}

handle_opts "$@"
prep_build_machine 
build_vm_image 
