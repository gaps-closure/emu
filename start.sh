#!/bin/bash
SZ=$1
SCEN=${SZ}enclave

PWD=`pwd`
sed -i -e "s;<NOT SET>;$PWD;g" config/${SCEN}/settings.json

clear
echo "========================== STARTING EMULATOR ============================"
python3 source/scenspec.py -s config/${SCEN}/settings.json -f config/${SCEN}/enclaves.json -l config/${SCEN}/layout.json -o ${SCEN}.imn
echo "========================== EMULATOR RUNNING  ============================"
read -p "Stop CORE and press Enter to terminate."

