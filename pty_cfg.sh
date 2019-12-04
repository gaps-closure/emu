#!/bin/bash

if [ "$USER" != "root" ]; then
    USER_INITIALS=${USER:0:2}   # Unique id (hopefully avoiding 'birthday paradox')
else
    USER_INITIALS=$(echo $SESSION_FILENAME | awk -F/ '{print $3}' | cut -c1-2 )
fi
#SSHPRIVKEY="/home/amcauley/gaps/top-level/emulator/config/id_rsa"
SSHPRIVKEY="/home/amcauley/gaps/top-level/emulator/build_qemu_vm/build/id_closure_rsa"

################################################################################################
# COMMON ENCLAVE DEVICE CONFIGURATION
################################################################################################
DEV_PTY_PREFIX="/dev/vcom"
LOG_FILE_PREFIX="/tmp/socat"

################################################################################################
# UNIQUE ENCLAVE DEVICE CONFIGURATION
################################################################################################
ORANGE_NAME="orange"
ORANGE_SUBNET_IP=1
ORANGE_GW_PORT="12345"

PURPLE_NAME="purple"
PURPLE_SUBNET_IP=2
PURPLE_GW_PORT="12346"


# Main
echo "Starting socat on $HOSTNAME"

ENCLAVE_NAME=$ORANGE_NAME
GW_IP="10.0.${ORANGE_SUBNET_IP}.1"
##TESTIBG
#GW_IP="10.201.${ORANGE_SUBNET_IP}.1"
GW_PORT="$ORANGE_GW_PORT"

if [[ $HOSTNAME == *"$PURPLE_NAME"* ]]; then
  ENCLAVE_NAME="$PURPLE_NAME"
  GW_IP="10.0.${PURPLE_SUBNET_IP}.1"
  GW_PORT="$PURPLE_GW_PORT"
fi

DEV_PTY="${DEV_PTY_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}"
LOG="${LOG_FILE_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}.log"
MAN_NIF_IP="10.200.0.1"


echo "e=$ENCLAVE_NAME i=$GW_IP p=$GW_PORT d=$DEV_PTY l=$LOG"
echo "ssh -i $SSHPRIVKEY closure@10.200.0.1 sudo socat -d -d -lf ${LOG} pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 tcp:${GW_IP}:${GW_PORT},ignoreeof &"

ssh -i $SSHPRIVKEY closure@${MAN_NIF_IP} ls
ssh -i $SSHPRIVKEY closure@${MAN_NIF_IP} \
  sudo socat -d -d -lf ${LOG} \
  pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 \
  tcp:${GW_IP}:${GW_PORT},ignoreeof &
sleep 1
ssh -i $SSHPRIVKEY closure@${MAN_NIF_IP} \
  sudo chmod 666 ${DEV_PTY}
