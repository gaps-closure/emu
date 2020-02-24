#!/bin/bash

IP="$1"
PORT="$2"

DEV_PTY="/dev/vcom"
LOG="/tmp/socat.out"

sudo socat -d -d -lf ${LOG} pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 tcp:${IP}:${PORT},ignoreeof &

sleep 1

for i in 1 2 3 4 5 6 7 8 9 10
do
    if [ -f ${DEV_PTY} ]
    then
	sleep 1
    else
	sudo chmod 666 ${DEV_PTY}
	echo "SUCCESS"
	exit
    fi
done

echo "ERROR: socat failed"


