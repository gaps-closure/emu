#!/bin/bash
SZ=$1
SCEN=${SZ}enclave

python3 source/scenspec.py -s config/${SCEN}/${SCEN}_settings.json -f config/${SCEN}/${SCEN}_config.json -l config/${SCEN}/${SCEN}_imnlayout.json -o ${SCEN}.imn
