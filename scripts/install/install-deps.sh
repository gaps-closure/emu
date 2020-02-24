#!/bin/bash

install_nrl_core () {
    COREURL="https://github.com/coreemu/core/releases/download/release-5.5.2"
    COREDEB="core_python3_5.5.2_amd64.deb"

    echo "Installing NRL CORE ($COREDEB) on build server"
    rm -f requirements.txt $COREDEB
    wget $COREURL/requirements.txt
    wget $COREURL/$COREDEB
    sudo -H pip3 install -r requirements.txt 
    sudo dpkg -i $COREDEB
    rm -f requirements.txt $COREDEB
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
    sudo -H pip3 install pexpect
}

prep_build_machine
install_nrl_core

echo "GAPS-EMU: Remember to enable using sudo without password for VM building stages."
