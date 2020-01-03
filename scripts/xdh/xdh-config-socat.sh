#!/bin/bash

MGMT_IP="$1"
IP="$2"
PORT="$3"

DEV_PTY="/dev/vcom"
LOG="/tmp/socat.out"

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

try:
  p = pexpect.spawn('ssh -i /root/.ssh/id_closure_rsa closure@${MGMT_IP}')
  p.expect(prompt, timeout=300)
  p.sendline('sudo socat -d -d -lf ${LOG} pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 tcp:${IP}:${PORT},ignoreeof &')
  p.expect(prompt)
  spl_print(p.before+p.after)
  status=False
  for i in range(0, 10):
    p.sendline('ls -l ${DEV_PTY}')
    p.expect(prompt)
    if 'No such file' in (p.before).decode('utf-8'):
      time.sleep(1)
    else:
      p.sendline('sudo chmod 666 ${DEV_PTY}')
      p.expect(prompt)
      spl_print(p.before+p.after)
      status=True
      break
  if not status:
    print('ERROR: unable to create socat\n')
  else:
    print('SUCCESS')
except Exception as e:
  print('ERROR: ' + str(e))
  exit()
END
