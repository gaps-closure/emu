#!/bin/bash

GIMG=""
KRNL=""
QARCH="arm64"
OFIL="snap.qcow2"

# XXX: create argument to pass netplan
usage_exit() {
  [[ -n "$1" ]] && echo $1
  echo "Usage: $0 [ -h ] \\"
  echo "          [ -g GIMG ] [ -k KRNL ] [-o OFIL ] [-a QARCH]" 
  echo "-h        Help"
  echo "-g GIMG   Full path to golden image, required"
  echo "-k KRNL   Full path to kernel, required"
  echo "-o OFIL   Name of output snapshot, required"
  echo "-a QARCH  Architecture [arm64(default), amd64]"
  exit 1
}

handle_opts() {
  local OPTIND
  while getopts "a:g:k:o:h" options; do
    case "${options}" in
      a) QARCH=${OPTARG}  ;;
      g) GIMG=${OPTARG}  ;;
      k) KRNL=${OPTARG}  ;;
      o) OFIL=${OPTARG}  ;;
      h) usage_exit       ;;
      :) usage_exit "Error: -${OPTARG} requires an argument." ;;
      *) usage_exit       ;;
    esac
  done
  shift "$((OPTIND-1))"
  case $QARCH in
    amd64) ;;
    arm64) ;;
    *)     usage_exit "Unsupported architecture $QARCH" ;;
  esac
}


start_qemu_initshell() {
  case $QARCH in
    amd64)
      QEMUCMD="sudo qemu-system-x86_64 -nographic -enable-kvm -m 4G -smp 2 -drive file=$OFIL,format=qcow2 -net nic -net user -kernel linux-kernel-amd64-eoan -append \"earlycon console=ttyS0 root=/dev/sda rw\""
      ;;
    arm64)
      QEMUCMD="sudo qemu-system-aarch64  -nographic -M virt -cpu cortex-a53 -m 1024 -drive file=$OFIL,format=qcow2 -kernel linux-kernel-arm64-xenial -append \"earlycon console=ttyAMA0 root=/dev/vda rw\" -netdev user,id=unet -device virtio-net-device,netdev=unet"
      ;;
    *)
      echo "No support for $QARCH"
      exit 1
      ;;
  esac
}

make_snapshot() {
  echo "Taking snapshot $OFIL of golden image $GIMG for updating"
  qemu-img create -f qcow2 -b ${GIMG} ${OFIL}
}

configure_snapshot() {
  start_qemu_initshell "file=$OFIL,format=qcow2"
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
  p.expect(prompt,timeout=1800)
  spl_print(p.before+p.after)

prompt = 'closure@.* '

# Boot and login
print('\nAbout to boot')
p = pexpect.spawn('$QEMUCMD')
i=1
while i!=0:
  i = p.expect(['login: ','\n\['])
  spl_print(p.before+p.after)
p.sendline('closure')   # XXX: username, should be an argument to script
p.expect('Password:.*')
spl_print(p.before+p.after)
p.sendline('closure')   # XXX: password, should be an argument to script
p.expect(prompt)
spl_print(p.before+p.after)

print('\nLogged in, configuring snapshot')

# Fix date setting?
# Add ssh key for remote access and configure .ssh directory perms
# Install additional software including zmqcat
# Apply scenario-node specific netplan to copy 
# XXX: netplan for each node must come from scenario

do_cmd(p, '# Additional commands here')
print('\nCompleted configuration')
END
}

handle_opts "$@"
mkdir -p ./build
cd ./build
make_snapshot
configure_snapshot

