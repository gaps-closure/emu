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

ssh -i /root/.ssh/id_closure_rsa closure@${MGMT_IP} 'mkdir -p tools'
scp -i /root/.ssh/id_closure_rsa ${TOOLS}/* closure@${MGMT_IP}:tools

python3 <<END
from pexpect import pxssh
import time
import sys

def spl_print(lines):
  l = lines.splitlines()
  for y in l[:-1]:
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))

s = pxssh.pxssh()
s.login(server='${MGMT_IP}', username='closure', ssh_key='/root/.ssh/id_closure_rsa')
s.sendline('rm -f fifo*')
s.prompt()
spl_print(s.before+s.after)
s.sendline('mkfifo fifo-left')
s.prompt()
spl_print(s.before+s.after)
s.sendline('mkfifo fifo-right')
s.prompt()
spl_print(s.before+s.after)
time.sleep(1)
cmd = 'nc -4 -k -l ${IP_LEFT} ${PORT_LEFT} < fifo-left  | python3 tools/filterproc.py ${ESPEC} > fifo-right &'
s.sendline(cmd)
s.prompt()
spl_print(s.before+s.after)
cmd = 'nc -4 ${IP_RIGHT} ${PORT_RIGHT} < fifo-right | python3 tools/filterproc.py ${ISPEC} > fifo-left  &'
s.sendline(cmd)
s.prompt()
spl_print(s.before+s.after)
s.logout()
END
echo "DONE"
