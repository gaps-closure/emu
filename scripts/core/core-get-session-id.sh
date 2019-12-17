#!/bin/sh
USER=`whoami`
ls -lt /tmp | grep pycore | grep $USER | head -1 | cut -d'.' -f2 | tr -d '\n'
