#!/bin/bash
PYTHON=python3.7
SCEN=$1

PWD=`pwd`
sed -i -e "s;<NOT SET>;$PWD;g" config/${SCEN}/settings.json
xhost + local:root

clear
echo "========================== STARTING EMULATOR ============================"
${PYTHON} src/scenspec.py -s config/${SCEN}/settings.json -f config/${SCEN}/enclaves.json -l config/${SCEN}/layout.json -o ${SCEN}.imn
echo "========================== EMULATOR RUNNING  ============================"
read -p "Stop CORE and press Enter to terminate."
