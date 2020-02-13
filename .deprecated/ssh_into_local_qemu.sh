#!/bin/bash

# SSH into local QEMU VM using its management interace (10.200.0.1)
if [ "$USER" != "root" ]; then
    USER_INITIALS=${USER:0:2}   # Unique id (hopefully avoiding 'birthday paradox')
else
    USER_INITIALS=$(echo $SESSION_FILENAME | awk -F/ '{print $3}' | cut -c1-2 )
fi
DIR_QEMU=$(echo $SESSION_FILENAME | sed 's:emulator.*$:emulator/build_qemu_vm/build:')
ssh -i $DIR_QEMU/id_closure_rsa closure@10.200.0.1
