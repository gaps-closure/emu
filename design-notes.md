# Design Notes

The purpose of the GAPS emulator is test and evaluation of cross-domain systems built using GAPS software toolchains within emulated distributed environments with heterogeneous instruction set architectures and/or application binary architectures, multiple enclaves running with different information security requirements, interconnected by cross-domain guard hardware. The emulator will be built using NRL CORE (supporting distributed/networked scenarios and a convenient GUI) and QEMU (for emulating different processor architectures). 

Although the emulator will use virtual ethernets/802.11 for interconnection, real devices may use other (possibly proprietary) on-wire protocols; if needed, the actual framing/protocol employed can be emulated in software on top of the underlying virtual Ethernet.

In the following description, "TA1" denotes various kinds of cross-domain guard hardware, which may be implemented either using a bump-in-the-wire model or a bookends (a card on a host on either side).

## Bump-In-The-Wire Model

![Emulator Architecture for BITW-style Cross-Domain Devices](emulator-bitw-arch.png)

1. If x86, QEMU and bridges can be dropped optionally; cross-domain application program, gpsd, and TA1 char dev will run directly on CORE node
2. Guard functions can be implemented using iptables initially that port forwards from 10.0.1.2:8080 to 10.1.1.2:8080; later, it could be implemented as a process that reads 10.0.1.2:8080 and 10.1.1.2:8080 and applies guard functions before transmitting. If vendor support is available, QEMU emulations of the device can be considered as well. Our architecture supports all these possibilities.
3. Cross domain program could directly open /dev/virtualcom0 and read/write cross-domain data to it; however it is desirable that a messaging middleware (e.g., based on zmq) is employed to allow multiplexing traffic from multiple applications over the same cross-domain interconnection.
4. Cross-domain program may communicate to gpsd and other processed on the host; it may communicate (e.g., via eth1) to services on other nodes in the enclave 
5. Note the use of L2 bridges, we envision that only the QEMU side has an IP address
6. Although one cross-domain connection is shown, the architecture will support cross-domain devices/connections to multiple peer enclaves

The recipe for creating a virtual serial device using `socat` is as follows:
```
# On terminal 1  (notionally TA1 hardware side):
$ nc -4 -k -t -l localhost 12345

# On terminal 2 (notionally host side):
$ sudo bash
$ socat pty,link=/dev/virtualcom0,raw tcp:localhost:12345 & 
$ yes 'Hello, World!' > /dev/virtualcom0

# You should now see on terminal 1:
Hello, World!
Hello, World!
...

```

## Bookend Model

![Emulator Architecture for Bookend-style Cross-Domain Devices](emulator-bookend.png)

In bookends model, socat sends virtual device to a local address/port; TA1 guard functions reads that port and write to eth0 (and vice versa). Only the QEMU isnide the CORE node is shown, but the rest of the scenario is the same as in the BITW case, except the cross-domain CORE router is a simple pass through in the Bookends case.

# Installation Notes
## Install Prerequisites

The process is manual now, but we may wrap this in a convenient install-all script in the future.

```
# Assumes Ubuntu Linux (preferably 19.10)
# Install CORE emulator, QEMU, and other prerequsitie Ubuntu packages
sudo apt update
sudo apt -y upgrade
sudo apt install python3 python3-pip
sudo apt install build-essential libssl-dev libffi-dev python3-dev
sudo apt install python3-venv
sudo apt install bash bridge-utils ebtables iproute libev-dev python tcl8.5 tk8.5 libtk-img xterm mgen traceroute
sudo apt install ethtool
sudo apt install qemu
sudo apt install quagga
sudo apt install socat
wget https://github.com/coreemu/core/releases/download/release-5.5.2/requirements.txt
sudo python3 -m pip install --upgrade
sudo -H pip3 install -r requirements.txt 
wget https://github.com/coreemu/core/releases/download/release-5.5.2/core_python3_5.5.2_amd64.deb
dpkg -i core_python3_5.5.2_amd64.deb 

# Download ISO live-server images for Ubuntu 19.10 for both amd64 and arm64
# from https://ubuntu.com/download/server and https://ubuntu.com/download/server/arm
wget http://cdimage.ubuntu.com/releases/19.10/release/ubuntu-19.10-server-amd64.iso
wget http://cdimage.ubuntu.com/releases/19.10/release/ubuntu-19.10-server-arm64.iso

# Create COW virtual disks and qemu images for both arch from ISO
# XXX: following commands untested

qemu-img create -f qcow2 ubuntu-19.10-amd64.qcow2 20G
qemu-system-x86_64 -m 4G -smp 2 -cdrom ubuntu-19.10-server-amd64.iso -drive "file=ubuntu-19.10-amd64.qcow2,format=qcow2"
qemu-img create -f qcow2 -b ubuntu-19.10-amd64.qcow2 ubuntu-19.10-amd64-snapshot.qcow2 

qemu-img create -f qcow2 ubuntu-19.10-arm64.qcow2 20G
qemu-system-aarch64 -m 4G -smp 2 -cdrom ubuntu-19.10-server-arm64.iso -drive "file=ubuntu-19.10-arm64.qcow2,format=qcow2"
qemu-img create -f qcow2 -b ubuntu-19.10-arm64.qcow2 ubuntu-19.10-arm64-snapshot.qcow2 

```

## GAPS Emulator installation
To be added.

# Todo
1. Prepare a sample partitioned program: 
    * Include install script (e.g., deb package)
    * Include systemd scripts that will start application on boot and respawn on failure
    * Include a toy library for cross-domain messaging (should work on serial with framing TBD as well as Ethernet+IP)
2. Prepare QEMU images for x86 and ARM 
3. Create a JSON configuration file containing:
    * Hardware topology for all enclaves and cross-domain devices; must specify number of cores, architecture etc. for the hosts 
    * TA1 device capabilities and type, e.g.,
    * ID (pass-through)
    * BITW style
    * Bookends style
    * Specific guard functions supported on device
    * Software topology and mappings – names of executables and which node they will run on
4. Basic GUI for the JSON config?
    * Can we hack CORE-GUI and the IMN file to include this info? 
5. Create a template IMN file using CORE GUI if needed
    * Use special names to mark enclave nodes where GAPS will run and for any cross-domain routers, and whether BITW or nodes
6. Implement sample TA1 device emulators (pass,BITW,BKEND)
    * Reuse BKEND impl. to create BITW
    * Include stats and wire-shark support
7. Transform IMN template to GAPS scenario
    * Read in JSON file
    * Instantiate CORE nodes, do the necessary internal plumbing (for either BITW or Bookends style), and deploy application
    * Instantiate QEMU nodes and do needed plumbing
    * Manage GAPS components (application, gpsd, TA1 device emulation)
    * Configure TA1 device (control API)
    * Preferably, write the above functionality as a Python library (not a monolithic script)

