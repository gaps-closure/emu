#!/bin/bash
SZ=$1
SCEN=${SZ}enclave

ME=`whoami`
sed -i -e "s/<user>/${ME}/" config/${SCEN}/${SCEN}_settings.json

clear
echo "========================== STARTING EMULATOR ============================"
python3 source/scenspec.py -s config/${SCEN}/${SCEN}_settings.json -f config/${SCEN}/${SCEN}_config.json -l config/${SCEN}/${SCEN}_imnlayout.json -o ${SCEN}.imn
echo "========================== EMULATOR RUNNING  ============================"
read -p "Stop CORE and press Enter to terminate."

