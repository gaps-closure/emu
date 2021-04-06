#!/bin/bash

install_nrl_core () {
    echo "Installing NRL CORE on build server"
    wget "https://github.com/coreemu/core/releases/download/release-6.5.0/core_6.5.0_amd64.deb"
    sudo dpkg -i core_6.5.0_amd64.deb
    rm core_6.5.0_amd64.deb
    sudo cp -R /usr/local/lib/python3.6/dist-packages/core /usr/local/lib/python3.8/dist-packages/
    sudo -H pip3 install -r emu_requirements.txt
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
