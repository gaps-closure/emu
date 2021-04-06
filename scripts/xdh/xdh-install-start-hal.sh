#!/bin/bash

XDH_SCRIPTS="${SESSION_DIR}/${NODE_NAME}.conf/scripts/xdh/"

CFG=$1
HAL="${SESSION_DIR}/${NODE_NAME}.conf/hal"

SSH="ssh vm"

$SSH "mkdir -p hal"
scp $CFG vm:hal/$(basename $CFG)
scp $HAL/hal vm:hal/hal
scp $XDH_SCRIPTS/start_hal.sh vm:start_hal.sh

CFGFILE=$(basename $CFG)

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
    s = pexpect.spawn('ssh vm')
    s.expect(prompt, timeout=30)
    break
  except:
    time.sleep(1)
if (time.time() - start >= GIVEUP):
  print('ERROR: ssh failed')
  exit()
try:
  s.sendline('./start_hal.sh ${CFGFILE}')
  s.expect(prompt)
  spl_print(s.before+s.after)
  s.close()
  print('SUCCESS')
except Exception as e:
  print('ERROR: ' + str(e))
  exit()
END
