#!/bin/bash

KEYDIR="$1"

mkdir -p /root/.ssh
echo "Host *" > /root/.ssh/config
echo "    StrictHostKeyChecking no" >> /root/.ssh/config

echo "Host vm" >> /root/.ssh/config
echo "    Port 22" >> /root/.ssh/config
echo "    User closure" >> /root/.ssh/config
echo "    IdentityFile /root/.ssh/id_closure_rsa" >> /root/.ssh/config
echo "    StrictHostKeyChecking no" >> /root/.ssh/config
echo "    HostName 10.200.0.1" >> /root/.ssh/config
echo "    HostKeyAlias vm.local" >> /root/.ssh/config

chmod 400 /root/.ssh/config

cp ${KEYDIR}/id_closure* /root/.ssh
chmod 700 /root/.ssh/id_closure*
