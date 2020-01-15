./qemu-emulator-customize.sh -g /IMAGES/ubuntu-amd64-eoan-qemu.qcow2 \
                        -k /IMAGES/linux-kernel-amd64-eoan \
                        -a amd64 \
                        -o ubuntu-19.10-amd64-closure-orange-enclave-gw.qcow2 \
                        -n $HOME/gaps/top-level/emulator/config/qemu_config_netplan_core_x86.txt 
                        
./qemu-emulator-customize.sh -g /IMAGES/ubuntu-arm64-eoan-qemu.qcow2 \
                        -k /IMAGES/linux-kernel-arm64-xenial \
                        -a arm64 \
                        -o ubuntu-19.10-arm64-closure-purple-enclave-gw.qcow2 \
                        -n $HOME/gaps/top-level/emulator/config/qemu_config_netplan_core_arm.txt 

