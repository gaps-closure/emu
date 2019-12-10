#!/bin/bash
mkdir -p /root/.ssh
echo "Host *" > /root/.ssh/config
echo "\tStrictHostKeyChecking no" >> /root/.ssh/config
chmod 400 /root/.ssh/config
