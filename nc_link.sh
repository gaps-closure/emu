#!/bin/bash

# Use nc to create a bidirection link between one IP address/port ${1}:${2} and another ${3}:${4}

rm -f fifo*
mkfifo fifo-left
mkfifo fifo-right
sleep 1
nc -4 -k -l ${1} ${2} < fifo-left  | python3 filterproc.py left-egress-spec  > fifo-right &
nc -4       ${3} ${4} < fifo-right | python3 filterproc.py left-ingress-spec > fifo-left  &
# ps ax | grep nc
