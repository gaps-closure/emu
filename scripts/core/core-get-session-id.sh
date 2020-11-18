#!/bin/sh
USER=`whoami`
ls -lt /tmp | grep pycore | grep $USER | head -1 | tr -d '\n'
