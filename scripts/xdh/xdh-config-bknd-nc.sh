#!/bin/bash

# Use nc to create a bidirection link between one IP address/port ${1}:${2} and another ${3}:${4}

IP_LEFT=$1
PORT_LEFT=$2
IP_RIGHT=$3
PORT_RIGHT=$4
MGMT_IP=$5
ESPEC=$6
ISPEC=$7

TOOLS="${SESSION_DIR}/${NODE_NAME}.conf/tools"
XDH_SCRIPTS="${SESSION_DIR}/${NODE_NAME}.conf/scripts/xdh/"

python3 <<END
import pexpect
import time
import sys

def spl_print(lines):
  l = lines.splitlines()
  for y in l[:-1]:
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))

prompt = 'closure@.* '

s = None
GIVEUP=300
start = time.time()
while(time.time() - start < GIVEUP):
  try:
    s = pexpect.spawn('ssh -i /root/.ssh/id_closure_rsa closure@${MGMT_IP}')
    s.expect(prompt, timeout=30)
    break
  except:
    time.sleep(1)
if (time.time() - start >= GIVEUP):
  print('ERROR: ssh failed')
  exit()
try:
  s.sendline('mkdir -p tools')
  s.expect(prompt)
  spl_print(s.before+s.after)
  scp = pexpect.spawn('scp -i /root/.ssh/id_closure_rsa ${TOOLS}/filterproc.py closure@${MGMT_IP}:tools')
  scp.expect(pexpect.EOF)
  scp = pexpect.spawn('scp -i /root/.ssh/id_closure_rsa ${XDH_SCRIPTS}/start_netcat.sh closure@${MGMT_IP}:')
  scp.expect(pexpect.EOF)
  s.sendline('./start_netcat.sh ${IP_LEFT} ${PORT_LEFT} ${IP_RIGHT} ${PORT_RIGHT} ${ESPEC} ${ISPEC}')
  s.expect(prompt)
  spl_print(s.before+s.after)
  s.close()
except Exception as e:
  print('ERROR: failure during nc setup (%s)' % (e))
  exit()
print('SUCCESS')
END
