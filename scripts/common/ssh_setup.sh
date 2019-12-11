#!/bin/bash

KEYDIR="$1"

mkdir -p /root/.ssh
echo "Host *" > /root/.ssh/config
echo "    StrictHostKeyChecking no" >> /root/.ssh/config
chmod 400 /root/.ssh/config

cp ${KEYDIR}/id_closure* /root/.ssh

