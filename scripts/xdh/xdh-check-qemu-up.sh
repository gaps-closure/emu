#!/bin/bash

   python3 <<END
import time
import sys
import pexpect

GIVEUP=300
success = False
start = time.time()
while (not success and (time.time() - start) < GIVEUP):
  try:
    prompt = 'closure@.* '
    p = pexpect.spawn('ssh -i /root/.ssh/id_closure_rsa closure@10.200.0.1 -o ConnectTimeout=10')
    p.expect(prompt, timeout=10)
    success = True
  except:
    time.sleep(1)
if not success:
  print('ERROR: ssh through management interface failed, tried for %ds' % (GIVEUP))
else:
  print('SUCCESS')
END

