#!/bin/bash

# Script for setting up BITW netcat instances on an xdgateway
IP_LEFT=$1
PORT_LEFT=$2
IP_RIGHT=$3
PORT_RIGHT=$4

rm -f fifo*

mkfifo fifo
nohup bash -c "nc -4 -k -l "${IP_LEFT}" ${PORT_LEFT} \
      < fifo \
      | nc -4 -k -l "${IP_RIGHT}" ${PORT_RIGHT} \
	   > fifo &" &> /dev/null
