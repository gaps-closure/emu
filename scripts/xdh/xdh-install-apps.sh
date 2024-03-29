#!/bin/bash

MGMT_IP="$1"
APPS="${SESSION_DIR}/${NODE_NAME}.conf/apps"

python3 <<END
import pexpect
import sys
import time
import os

def spl_print(lines): 
  l = lines.splitlines() 
  for y in l[:-1]: 
    if y!=b'': print(y.decode('utf-8'))
  sys.stdout.write(l[-1].decode('utf-8'))

prompt ='closure@.* '

try:
  p = pexpect.spawn('ssh -i /root/.ssh/id_closure_rsa closure@${MGMT_IP}')
  p.expect(prompt, timeout=300)
#  p.sendline('rm -rf apps && mkdir -p apps')
  p.sendline('mkdir -p apps')
  p.expect(prompt)
  spl_print(p.before+p.after)
  for f in os.listdir("${APPS}"):
    cmd = "scp -i /root/.ssh/id_closure_rsa ${APPS}/%s closure@${MGMT_IP}:apps" % (f)
    scp = pexpect.spawn(cmd)
    scp.expect(pexpect.EOF)
  p.sendline('cd apps && tar -xvf *.tar && rm *.tar')
  p.expect(prompt)
  DEPDIR='/home/closure/apps/.dependencies'
  p.sendline('mkdir -p %s/debs' % (DEPDIR))
  p.expect(prompt,timeout=300)
  p.sendline('mkdir -p %s/pips' % (DEPDIR))
  p.expect(prompt,timeout=300)
  p.sendline('cd %s/debs && sudo dpkg -E -i * &> %s/install.log' % (DEPDIR, DEPDIR))
  p.expect(prompt,timeout=300)
  spl_print(p.before+p.after)
  p.sendline('cd %s/pips && sudo -H pip3 install --no-index --find-links . * &>> %s/install.log' % (DEPDIR, DEPDIR))
  p.expect(prompt,timeout=300)
  spl_print(p.before+p.after)
except Exception as e:
  print('ERROR: ' + str(e))
  exit()
print('SUCCESS')
END
