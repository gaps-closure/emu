#!/bin/bash

   python3 <<END
import time
import sys
from pexpect import pxssh

i = 0
success = False
while (i < 300 and not success):
  try:
    s = pxssh.pxssh()	
    s.login(server='10.200.0.1', username='closure', ssh_key='/root/.ssh/id_closure_rsa')
    s.logout()
    success = True
  except:
    i += 1
    time.sleep(1)
if not success:
  print('ERROR: ssh through management interface failed')
else:
  print('SUCCESS')
END

