#!/bin/bash

GIMG=""
KRNL=""
QARCH="arm64"
OFIL="snap.qcow2"
NPLAN=""
BDIR="build"

usage_exit() {
  [[ -n "$1" ]] && echo $1
  echo "Usage: $0 [ -h ] \\"
  echo "          [ -g GIMG ] [ -k KRNL ] [-o OFIL ] [-a QARCH] -n [NPLAN] -b [BDIR]" 
  echo "-h        Help"
  echo "-g GIMG   Full path to golden image, required"
  echo "-k KRNL   Full path to kernel, required"
  echo "-o OFIL   Name of output snapshot, required"
  echo "-a QARCH  Architecture [arm64(default), amd64]"
  echo "-n NPLAN  Netplan file, required"
  echo "-b BDIR   Directory for building snapshots, build(default)"
  
  exit 1
}

handle_opts() {
  local OPTIND
  while getopts "a:g:k:o:n:hb:" options; do
    case "${options}" in
      a) QARCH=${OPTARG}  ;;
      g) GIMG=${OPTARG}   ;;
      k) KRNL=${OPTARG}   ;;
      o) OFIL=${OPTARG}   ;;
      n) NPLAN=${OPTARG}  ;;
      b) BDIR=${OPTARG}   ;;
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

make_snapshot() {
  echo "Taking snapshot $OFIL of golden image $GIMG for updating"
  qemu-img create -f qcow2 -b ${GIMG} ${OFIL}
}

configure_snapshot() {
  start_qemu_initshell
  echo $QEMUCMD
  if [ ! -f id_closure_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N "" -f id_closure_rsa 
  fi
  PUBKEY=`cat id_closure_rsa.pub`
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
do_cmd(p, 'date')

print('\nDisabling auto apt checks and updates')
do_cmd(p,'sudo systemctl disable --now apt-daily{,-upgrade}.{timer,service}')
print('\nUpdating packages')
do_cmd(p, 'sudo apt update')
print('\nInstalling haveged for randomness')
do_cmd(p, 'sudo apt install -y haveged')

#print('\nUpgrading ssh')
#do_cmd(p, 'sudo apt install ssh')
#print('\nReconfiguring ssh')
#do_cmd(p, 'sudo dpkg-reconfigure openssh-server')

# Add ssh key for remote access and configure .ssh directory perms
do_cmd(p, 'mkdir -p ~/.ssh && chmod 700 ~/.ssh')
do_cmd(p, 'echo "$PUBKEY" >> ~/.ssh/authorized_keys')
do_cmd(p, 'chmod 600 ~/.ssh/authorized_keys')

# Disable DNS lookup in sshd (effort to get sshd to work more reliably)
# do_cmd(p, 'sudo chmod 777 /etc/ssh/sshd_config')
# do_cmd(p, 'echo "UsePAM yes" >> /etc/ssh/sshd_config')
# do_cmd(p, 'echo "UseDNS no" >> /etc/ssh/sshd_config')
# do_cmd(p, 'sudo chmod 644 /etc/ssh/sshd_config')

# Apply scenario-node specific netplan to copy to /etc/netplan
do_cmd(p, 'sudo mkdir -p /etc/netplan')
do_cmd(p, 'sudo rm -f /etc/netplan/config.yaml')
with open('$NPLAN', 'r') as nplnf:
  for line in nplnf:
   do_cmd(p, "echo '" + line.rstrip('\n') + "' | sudo tee -a /etc/netplan/config.yaml")
do_cmd(p, 'cat /etc/netplan/config.yaml')
do_cmd(p, 'sudo netplan generate')

do_cmd(p, '# Additional commands here')
do_cmd(p, 'sync;sync')
print('\nCompleted configuration')
END
}

handle_opts "$@"
mkdir -p $BDIR
cd $BDIR
make_snapshot
configure_snapshot

