#!/bin/bash

QEMUCMD="echo"
PREPSRV="no"
NRLCORE="no"
UPDATEONLY="no"
QARCH="arm64"
UDIST="eoan"
SIZE="20G"
KDIST="xenial" # ARM64 breaks on kernels after xenial on workhorse

usage_exit() {
  [[ -n "$1" ]] && echo $1
  echo "Usage: $0 [ -cpuh ] \\"
  echo "          [ -a QARCH ] [ -d UDIST ] [-s SIZE ] [-k KDIST ]" 
  echo "-h        Help"
  echo "-p        Install pre-requisites on build server"
  echo "-c        Intall NRL CORE on build server"
  echo "-u        Only perform post-build configuration and updating"
  echo "-a QARCH  Architecture [arm64(default), amd64]"
  echo "-d UDIST  Ubuntu distro [eoan(default)]"
  echo "-s SIZE   Image size [20G(default),<any>]"
  echo "-k KDIST  Ubuntu distro for kernel [xenial(default),<any>]"
  exit 1
}

handle_opts() {
  local OPTIND
  while getopts "a:d:s:k:pcuh" options; do
    case "${options}" in
      k) KDIST=${OPTARG}  ;;
      a) QARCH=${OPTARG}  ;;
      d) UDIST=${OPTARG}  ;;
      s) SIZE=${OPTARG}   ;;
      p) PREPSRV="yes"    ;;
      c) NRLCORE="yes"    ;;
      u) UPDATEONLY="yes" ;;
      h) usage_exit       ;;
      :) usage_exit "Error: -${OPTARG} requires an argument." ;;
      *) usage_exit       ;;
    esac
  done
  shift "$((OPTIND-1))"
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
      bash bridge-utils ebtables iproute2 xterm mgen traceroute ethtool \
      build-essential libssl-dev libffi-dev \
      python3 python3-pip python3-dev libev-dev python3-venv \
      tcl8.6 tk8.6 libtk-img quagga \
      ubuntu-dev-tools qemu qemu-efi qemu-user-static
    sudo -H pip3 install --upgrade pip
    sudo -H pip3 install pexpect
    if [ $NRLCORE == "yes" ]; then
      install_nrl_core
    fi
    echo "Ensure sudo group can login without password, not doing this automatically"
  fi
}

fetch_kernel() {
  KRNL="dists/${KDIST}/main/installer-${QARCH}/current/images/netboot/ubuntu-installer/${QARCH}/linux"
  INRD="dists/${KDIST}/main/installer-${QARCH}/current/images/netboot/ubuntu-installer/${QARCH}/initrd.gz"
  case $QARCH in
    amd64) KURL="http://archive.ubuntu.com/ubuntu" ;;
    arm64) KURL="http://ports.ubuntu.com/ubuntu-ports" ;;
    *) usage_exit "No support for $QARCH" ;;
  esac
  echo "Fetching boot kernel"
  rm -f linux initrd.gz
  wget $KURL/$KRNL
  wget $KURL/$INRD
  mv linux linux-kernel-$QARCH-$KDIST
  mv initrd.gz linux-initrd-$QARCH-$KDIST.gz
}

debootstrap_first_stage() {
  echo "Commencing debootstrap first stage"
  case $QARCH in
    amd64) 
      INCLUDES="socat zip unzip ssh net-tools tshark libzmq3-dev build-essential linux-image-generic grub2-common grub-pc"
      ;;
    arm64)
      INCLUDES="socat zip unzip ssh net-tools tshark libzmq3-dev build-essential"
      ;;
    *) 
      usage_exit "No support for $QARCH" 
      ;;
  esac
  echo "Fetching boot kernel"
  sudo debootstrap \
    --verbose --foreign --arch=$QARCH \
    --components=main,universe \
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

start_qemu_initshell() {
  ROOTDRIVE="$1"
  case $QARCH in
    amd64)
      QEMUCMD="sudo qemu-system-x86_64 -nographic -enable-kvm -m 4G -smp 2 -drive $ROOTDRIVE -net nic -net user -kernel linux-kernel-${QARCH}-${KDIST} -append \"earlycon console=ttyS0 root=/dev/sda init=/bin/sh rw\""
      ;;
    arm64)
      QEMUCMD="qemu-system-aarch64 -nographic -M virt -cpu cortex-a53 -m 1024 -drive $ROOTDRIVE -netdev user,id=unet -device virtio-net-device,netdev=unet -kernel linux-kernel-${QARCH}-${KDIST} -append \"earlycon root=/dev/vda init=/bin/sh rw\""
      ;;
    *)
      echo "No support for $QARCH"
      exit 1
      ;;
  esac
}

debootstrap_second_stage() {
  start_qemu_initshell "file=rootfs.img,format=raw"
  python3 - <<END
import os
import sys
import pexpect
def spl_print(lines): 
  l = lines.splitlines() 
  for y in l[:-1]: 
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))
p = pexpect.spawn('$QEMUCMD')
p.expect('\n# ',timeout=1800)
spl_print(p.before+p.after)
print('\nBooted, invoking debootstrap')
p.sendline('/debootstrap/debootstrap --second-stage')
i=1
while i!=0:
  i = p.expect(['\n# ','I: Unpacking ','I: Configuring'],timeout=1800)
  spl_print(p.before+p.after)
print('\nCompleted, second stage')
END
}

make_golden_cow() {
  QFILE="ubuntu-${QARCH}-${UDIST}-qemu.qcow2.virgin"
  qemu-img convert -f raw -O qcow2 rootfs.img rootfs.qcow2
  rm -f rootfs.img
  mv rootfs.qcow2 $QFILE
  echo "Saved $QFILE"
}

configure_golden_cow() {
  QFILE="ubuntu-${QARCH}-${UDIST}-qemu.qcow2"
  HNAME="ubuntu-${QARCH}"
  echo "Making copy $QFILE of virgin image for updating"
  cp ${QFILE}.virgin ${QFILE} 
  start_qemu_initshell "file=$QFILE,format=qcow2"
  python3 - <<END
import os
import sys
import pexpect

def spl_print(lines): 
  l = lines.splitlines() 
  for y in l[:-1]: 
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))

def do_cmd(p,cmd=None):
  if cmd is not None: p.sendline(cmd)
  p.expect('\n# ',timeout=1800)
  spl_print(p.before+p.after)

p = pexpect.spawn('$QEMUCMD')
do_cmd(p)
print('\nBooted, configuring system')

if "$QARCH" == 'amd64':
  do_cmd(p, 'echo "/dev/sda / ext4 relatime,errors=remount-ro 0 1" >> /etc/fstab')
  do_cmd(p, 'cat > /etc/netplan/config.yaml <<YAMEND\nnetwork:\n  version: 2\n  renderer: networkd\n  ethernets:\n    ens3:\n      dhcp4: true\nYAMEND\n')
  do_cmd(p, 'netplan generate')
elif "$QARCH" == 'arm64':
  do_cmd(p, 'echo "/dev/vda / ext4 relatime,errors=remount-ro 0 1" >> /etc/fstab')
  do_cmd(p, 'cat > /etc/netplan/config.yaml <<YAMEND\nnetwork:\n  version: 2\n  renderer: networkd\n  ethernets:\n    eth0:\n      dhcp4: true\nYAMEND\n')
  do_cmd(p, 'netplan generate')
else:
  raise Exception('Unsupported architecture')

do_cmd(p, 'echo $HNAME > /etc/hostname')
do_cmd(p, 'echo "127.0.1.1 $HNAME" > /etc/hosts')
do_cmd(p, 'adduser closure --gecos "" --disabled-password')
do_cmd(p, 'echo "closure:closure" | chpasswd')
do_cmd(p, 'addgroup closure sudo')
do_cmd(p, 'echo "closure ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers')
do_cmd(p, 'sync;sync')

do_cmd(p, '# Additional commands here, maybe make image bootable?')
print('\nCompleted configuration')
END
}

build_vm_image() {
  mkdir -p ./build
  cd ./build
  if [ $UPDATEONLY != "yes" ]; then
    echo "Building QEMU VM Image: $QARCH $UDIST (kern $KDIST) $SIZE"
    fetch_kernel
    debootstrap_first_stage
    debootstrap_second_stage
    make_golden_cow
  else
    echo "Configuring QEMU VM Image: $QARCH $UDIST (kern $KDIST) $SIZE"
    configure_golden_cow
  fi
}

handle_opts "$@"
echo "Options PREPSRV=$PREPSRV NRLCORE=$NRLCORE QARCH=$QARCH UDIST=$UDIST KDIST=$KDIST UPDATEONLY=$UPDATEONLY SIZE=$SIZE"
prep_build_machine 
build_vm_image 

