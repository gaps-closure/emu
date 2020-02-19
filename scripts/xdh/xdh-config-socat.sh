#!/bin/bash

XDH_SCRIPTS="${SESSION_DIR}/${NODE_NAME}.conf/scripts/xdh/"

MGMT_IP="$1"
IP="$2"
PORT="$3"

python3 <<END
import pexpect
import sys
import time

def spl_print(lines): 
  l = lines.splitlines() 
  for y in l[:-1]: 
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))

prompt ='closure@.* '

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
  scp = pexpect.spawn('scp -i /root/.ssh/id_closure_rsa ${XDH_SCRIPTS}/start_socat.sh closure@${MGMT_IP}:')
  scp.expect(pexpect.EOF)
  s.sendline('./start_socat.sh ${IP} ${PORT}')
  s.expect(prompt)
  spl_print(s.before+s.after)
  s.close()
  print('SUCCESS')
except Exception as e:
  print('ERROR: ' + str(e))
  exit()
END
