#!/bin/bash
SZ=$1
SCEN=${SZ}enclave

ME=`whoami`
sed -i -e "s/<user>/${ME}/" config/${SCEN}/${SCEN}_settings.json

python3 source/scenspec.py -s config/${SCEN}/${SCEN}_settings.json -f config/${SCEN}/${SCEN}_config.json -l config/${SCEN}/${SCEN}_imnlayout.json -o ${SCEN}.imn
