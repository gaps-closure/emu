#!/bin/bash

MGMT_IP="$1"
IP="$2"
PORT="$3"

DEV_PTY="/dev/vcom"
LOG="/tmp/socat.out"

python3 <<END
from pexpect import pxssh
import sys
import time

def spl_print(lines): 
  l = lines.splitlines() 
  for y in l[:-1]: 
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))

s = pxssh.pxssh()
s.login(server='${MGMT_IP}', username='closure', ssh_key='/root/.ssh/id_closure_rsa', original_prompt='closure@.* ')
s.sendline('sudo socat -d -d -lf ${LOG} pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 tcp:${IP}:${PORT},ignoreeof &')
s.prompt()
spl_print(s.before+s.after)
status=False
for i in range(0, 10):
  s.sendline('ls -l ${DEV_PTY}')
  s.prompt()
#  spl_print(s.before+s.after)
  if 'No such file' in (s.before).decode('utf-8'):
    time.sleep(1)
  else:
    s.sendline('sudo chmod 666 ${DEV_PTY}')
    s.prompt()
    spl_print(s.before+s.after)
    status=True
    break
s.logout()
if not status:
  print('ERROR: unable to create socat\n')  
END
