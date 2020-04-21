#!/bin/bash

# Use nc to create a bidirection link between one IP address/port ${1}:${2} and another ${3}:${4}

IP_LEFT=$1
PORT_LEFT=$2
IP_RIGHT=$3
PORT_RIGHT=$4
ESPEC=$5
ISPEC=$6

rm -f fifo*
mkfifo fifo-left
mkfifo fifo-right

#nc -4 -k -l ${IP_LEFT} ${PORT_LEFT} < fifo-left  | python3 -u tools/filterproc.py ${ESPEC} > fifo-right &
nc -4 -k -l ${IP_LEFT} ${PORT_LEFT} < fifo-left | cat > fifo-right &
sleep 2
#nc -4 ${IP_RIGHT} ${PORT_RIGHT} < fifo-right | python3 -u tools/filterproc.py ${ISPEC} > fifo-left &
nc -4 ${IP_RIGHT} ${PORT_RIGHT} < fifo-right | cat > fifo-left &
sleep 2

N= `ps -ef | grep "nc -4 | grep -v grep | wc -l`
if [ $N -ne 2 ]
then
    echo "ERROR: 2 netcat processes should be started, only $N found"
else
    echo "SUCCESS"
fi
