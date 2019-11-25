#!/bin/bash

if [ "$USER" != "root" ]; then
    USER_INITIALS=${USER:0:2}   # Unique id (hopefully avoiding 'birthday paradox')
else
    USER_INITIALS=$(echo $SESSION_FILENAME | awk -F/ '{print $3}' | cut -c1-2 )
fi
DIR_IMGS=$(echo $SESSION_FILENAME | sed 's:emulator.*$:emulator/imgs:')
DEV_PTY_PREFIX="/dev/vcom"
LOG_FILE_PREFIX="/tmp/socat"

ORANGE_NAME="orange"
ORANGE_SUBNET_IP=1
PURPLE_NAME="purple"
PURPLE_SUBNET_IP=2


# Main
echo "Starting socat on $HOSTNAME"

ENCLAVE_NAME=$ORANGE_NAME
GW_IP="10.0.${ORANGE_SUBNET_IP}.1"
GW_PORT="12345"
if [[ $HOSTNAME == *"$PURPLE_NAME"* ]]; then
  ENCLAVE_NAME="$PURPLE_NAME"
  GW_IP="10.0.${PURPLE_SUBNET_IP}.1"
  GW_PORT="12346"
fi
DEV_PTY="${DEV_PTY_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}"
LOG="${LOG_FILE_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}.log"

echo "e=$ENCLAVE_NAME i=$GW_IP p=$GW_PORT d=$DEV_PTY l=$LOG"
echo "ssh -i /home/amcauley/gaps/top-level/emulator/config/id_rsa closure@10.200.0.1 sudo socat -d -d -lf ${LOG} pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 tcp:${GW_IP}:${GW_PORT},ignoreeof &"

ssh -i /home/amcauley/gaps/top-level/emulator/config/id_rsa closure@10.200.0.1 ls
ssh -i /home/amcauley/gaps/top-level/emulator/config/id_rsa closure@10.200.0.1 \
  sudo socat -d -d -lf ${LOG} \
  pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 \
  tcp:${GW_IP}:${GW_PORT},ignoreeof &
sleep 1
ssh -i /home/amcauley/gaps/top-level/emulator/config/id_rsa closure@10.200.0.1 \
  sudo chmod 666 ${DEV_PTY}
