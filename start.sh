#!/bin/bash
PYTHON=python3.8
SCEN=$1

PWD=`pwd`
sed -i -e "s;<NOT SET>;$PWD;g" config/${SCEN}/settings.json
xhost + local:root

start_core() {
    if [[ x`pgrep core-daemon` == x ]]; then
	sudo /etc/init.d/core-daemon start
	sleep 5
    fi
    if [[ x`pgrep core-daemon` == x ]]; then
	echo -e "\nError: Unable to start core-daemon"
	exit 1
    fi
}

echo "========================== STARTING EMULATOR ============================"
start_core
${PYTHON} src/scenspec.py -s config/${SCEN}/settings.json -f config/${SCEN}/enclaves.json -l config/${SCEN}/layout.json -o ${SCEN}.imn
echo "========================== EMULATOR RUNNING  ============================"
read -p "Stop CORE and press Enter to terminate."
