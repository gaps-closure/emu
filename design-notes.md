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

## Bookend Model

![Emulator Architecture for Bookend-style Cross-Domain Devices](emulator-bookend.png)

In bookends model, socat sends virtual device to a local address/port; TA1 guard functions reads that port and write to eth0 (and vice versa). Only the QEMU isnide the CORE node is shown, but the rest of the scenario is the same as in the BITW case, except the cross-domain CORE router is a simple pass through in the Bookends case.

# Installation Notes
## Install Prerequisites

The process is manual now, but we may wrap this in a convenient install-all script in the future.

```
# Assumes Ubuntu Linux (preferably 19.10) with python3 and PIP 
# Install CORE emulator, QEMU, and other prerequsitie Ubuntu packages

sudo apt install ethtool
sudo apt install qemu
sudo apt-get install bash bridge-utils ebtables iproute libev-dev python tcl8.5 tk8.5 libtk-img xterm mgen traceroute
sudo apt install quagga

wget https://github.com/coreemu/core/releases/download/release-5.5.2/requirements.txt
sudo python3 -m pip install --upgrade
sudo -H pip3 install -r requirements.txt 
wget https://github.com/coreemu/core/releases/download/release-5.5.2/core_python3_5.5.2_amd64.deb
dpkg -i core_python3_5.5.2_amd64.deb 

# Download ISO live-server images for Ubuntu 19.10 for both amd64 and arm64
# XXX: would be good to have wget for this
# https://ubuntu.com/download/server
# https://ubuntu.com/download/server/arm

# Create COW virtual disks and qemu images for both arch from ISO
# https://linux-tips.com/t/booting-from-an-iso-image-using-qemu/136
# https://www.unixmen.com/qemu-kvm-using-copy-write-mode/
# XXX: To be expanded

```

## GAPS Emulator installation
To be added.

