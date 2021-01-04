#!/bin/bash

install_nrl_core () {
    echo "Installing NRL CORE on build server"
    git clone https://github.com/coreemu/core
    cd core
    sudo ./install.sh
    cd ..
#    sudo rm -rf core
}

prep_build_machine() {
    echo "Installing pre-requisites to build server"
    sudo apt update
    # sudo apt -y upgrade # XXX: maybe control with an arg?
    sudo apt install -y wget \
      bash bridge-utils ebtables iproute2 xterm mgen traceroute ethtool \
      build-essential libssl-dev libffi-dev \
      python3 python3-pip python3-dev libev-dev python3-venv \
      tcl tcl8.6 tk tk8.6 libtk-img quagga uml-utilities net-tools \
      ubuntu-dev-tools qemu qemu-efi qemu-user-static qemu-system-arm qemu-system-x86 qemu-user
    sudo -H pip3 install --upgrade pip
    sudo -H pip3 install pexpect libconf
}

prep_build_machine
install_nrl_core

echo "GAPS-EMU: Remember to enable using sudo without password for VM building stages."
