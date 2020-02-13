#!/bin/bash
SZ=$1
SCEN=${SZ}enclave


if [ $SZ -ne 2 ] && [ $SZ -ne 3 ] && [ $SZ -ne 4 ]
then
    echo "Usage: start.sh [enclaves] (start.sh supports 2-4 enclaves)"
    exit
fi

PWD=`pwd`
sed -i -e "s;<NOT SET>;$PWD;g" config/${SCEN}/settings.json

clear
echo "========================== STARTING EMULATOR ============================"
python3 src/scenspec.py -s config/${SCEN}/settings.json -f config/${SCEN}/enclaves.json -l config/${SCEN}/layout.json -o ${SCEN}.imn
echo "========================== EMULATOR RUNNING  ============================"
read -p "Stop CORE and press Enter to terminate."

