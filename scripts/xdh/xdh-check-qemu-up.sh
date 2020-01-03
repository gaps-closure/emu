#!/bin/bash

   python3 <<END
import time
import sys
import pexpect

i = 0
success = False
while (i < 300 and not success):
  try:
    prompt = 'closure@.* '
    p = pexpect.spawn('ssh -i /root/.ssh/id_closure_rsa closure@10.200.0.1 -o ConnectTimeout=2')
    p.expect(prompt, timeout=1)
    success = True
  except:
    i += 1
if not success:
  print('ERROR: ssh through management interface failed')
else:
  print('SUCCESS')
END

