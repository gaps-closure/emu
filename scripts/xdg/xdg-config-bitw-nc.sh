#!/bin/bash

# Script for setting up BITW netcat instances on an xdgateway
IP_LEFT=$1
PORT_LEFT=$2
IP_RIGHT=$3
PORT_RIGHT=$4
LISPEC=$5
RESPEC=$6
RISPEC=$7
LESPEC=$8

rm -f fifo*

TOOLS="${SESSION_DIR}/${NODE_NAME}.conf/tools"

mkfifo fifo-left
mkfifo fifo-right   # Can we get rid of the second fifo, but then get very long pipeline
nohup bash -c "nc -4 -k -l ${IP_LEFT} ${PORT_LEFT} \
   < fifo-left \
    | python3 ${TOOLS}/filterproc.py ${LISPEC}   \
    | python3 ${TOOLS}/filterproc.py ${RESPEC}   \
              > fifo-right &" &> /dev/null
nohup bash -c "nc -4 -k -l ${IP_RIGHT} ${PORT_RIGHT} \
   < fifo-right \
    | python3 ${TOOLS}/filterproc.py ${RISPEC}   \
    | python3 ${TOOLS}/filterproc.py ${LESPEC}   \
              > fifo-left &" &> /dev/null
