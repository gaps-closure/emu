#!/bin/bash

MGMT_IP="$1"
DISP=$2
TM=$3

# set environment variables in the CORE container
if [[ x$DISPLAY == "x" ]]; then
    echo "export DISPLAY=$DISP" > /root/bashrc
fi
if [[ x$TERM == "xdumb" ]]; then
    echo "export TERM=$TM" >> /root/bashrc
fi
echo "ssh -X vm" >> /root/bashrc

# set environment variables in the QEMU Instance
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

profile_script = """
export LD_LIBRARY_PATH=/home/closure/apps
if [ "\$(echo \$PATH | grep closure/apps | wc -l)" == "0" ]
then
  export PATH=\$PATH:/home/closure/apps
fi
""".split("\n")

try:
  p = pexpect.spawn('ssh -i /root/.ssh/id_closure_rsa closure@${MGMT_IP}')
  p.expect(prompt, timeout=300)
  
  p.sendline('sudo mkdir -p /etc/profile.d')
  p.expect(prompt)
  
  p.sendline('rm -f /tmp/closure_env.sh')
  p.expect(prompt)
  
  for ln in profile_script:
    ln = ln.replace(r'"',r'\"')
    ln = ln.replace(r'\$',r'\\$')
    p.sendline('echo "%s" >> %s'%(ln,"/tmp/closure_env.sh"))
    p.expect(prompt)
    
  p.sendline('sudo mv /tmp/closure_env.sh /etc/profile.d/closure_env.sh')
  p.expect(prompt)
  p.sendline('sudo chown root:root /etc/profile.d/closure_env.sh')
  p.expect(prompt)
except Exception as e:
  print('ERROR: ' + str(e))
  exit()
print('SUCCESS')
END
