#!/bin/bash

KRNL=""
QARCH="arm64"
OFIL="snap.qcow2"
BDIR="build"
DEBS=""
PIPS=""

usage_exit() {
  [[ -n "$1" ]] && echo $1
  echo "Usage: $0 [ -h ] \\"
  echo "          [ -k KRNL ] [-o OFIL ] [-a QARCH ] [ -b BDIR ] [ -d DEBS ] [ -p PIPS ]" 
  echo "-h        Help"
  echo "-k KRNL   Full path to kernel, required"
  echo "-o OFIL   Name of output snapshot, required"
  echo "-a QARCH  Architecture [arm64(default), amd64]"
  echo "-b BDIR   Directory for building snapshots, build(default)"
  echo "-d DEBS   list of debian packages to install"
  echo "-p PIPS   list of python3 pips to install"
  exit 1
}

handle_opts() {
  local OPTIND
  while getopts "a:k:o:d:p:hb:" options; do
    case "${options}" in
      a) QARCH=${OPTARG}  ;;
      k) KRNL=${OPTARG}   ;;
      o) OFIL=${OPTARG}   ;;
      b) BDIR=${OPTARG}   ;;
      d) DEBS=${OPTARG}   ;;
      p) PIPS=${OPTARG}   ;;
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
  CURDT=`date -u --iso-8601=seconds | sed -e 's/\+.*//'`
  case $QARCH in
    amd64)
      QEMUCMD="sudo qemu-system-x86_64 -nographic -enable-kvm -m 4G -smp 2 -drive file=$OFIL,format=qcow2 -net nic -net user -kernel $KRNL -append \"earlycon console=ttyS0 root=/dev/sda rw\" -rtc base=$CURDT"
      ;;
    arm64)
      QEMUCMD="sudo qemu-system-aarch64  -nographic -M virt -cpu cortex-a53 -m 1024 -drive file=$OFIL,format=qcow2 -kernel $KRNL -append \"earlycon console=ttyAMA0 root=/dev/vda rw\" -netdev user,id=unet -device virtio-net-device,netdev=unet -rtc base=$CURDT"
      ;;
    *)
      echo "No support for $QARCH"
      exit 1
      ;;
  esac
}

configure_snapshot() {
  start_qemu_initshell
  echo $QEMUCMD
  PUBKEY=`cat id_closure_rsa.pub`
  python3 - <<END
import os
import sys
import pexpect
import time

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
p.expect('Password:.*', timeout=300)
spl_print(p.before+p.after)
p.sendline('closure')   # XXX: password, should be an argument to script
p.expect(prompt, timeout=300)
spl_print(p.before+p.after)

print('\nLogged in, configuring snapshot')
do_cmd(p, 'date')

if '$QARCH' == "amd64":
  print('\nSetting IP on ens3')
  do_cmd(p, 'sudo dhclient ens3')
elif '$QARCH' == "arm64":
  print('\nSetting IP on eth0')
  do_cmd(p, 'sudo dhclient eth0')

if os.path.exists('$DEBS'):
  print('\nInstall debian packages...')
  do_cmd(p, 'sudo dpkg --configure -a')
  debs = open('$DEBS', 'r').readlines()
  debs = (''.join(debs)).replace('\n', ' ')
  do_cmd(p, 'sudo apt install -y %s' % (debs))
  do_cmd(p, 'echo RC=\$?')

  if "RC=0" not in str(p.before):
    exit(1)

if os.path.exists('$PIPS'):
  print('\nInstall pip3 packages...')
  pips = open('$PIPS', 'r').readlines()
  pips = (''.join(pips)).replace('\n', ' ')
  do_cmd(p, 'sudo -H pip3 install %s' % (pips))
  do_cmd(p, 'echo RC=\$?')

  if "RC=0" not in str(p.before):
    exit(1)

END
RC=$?
}

handle_opts "$@"
mkdir -p $BDIR
cd $BDIR
configure_snapshot
exit $RC
