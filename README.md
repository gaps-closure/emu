# GAPS Emulator (EMU)
This repository hosts the open source components of the EMU for Multi-ISA cross-domain systems test and evaluation. The `master` branch contains the most recent public release software while `develop` contains bleeding-edge updates and work-in-progress features for use by beta testers and early adopters.

This repository is maintained by Perspecta Labs.
## Contents
- [Installing External Dependencies](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#installing-external-dependencies)
- [Provisioning QEMU VM Disk Images](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#provisioning-qemu-vm-disk-images)
- [Configuration](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#configuration)
  * [Selecting ISA/OS](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#selecting-the-isa-for-enclave-gatewayscross-domain-hosts-xdhost)
  * [Selecting SDH Model](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#selecting-the-sdh-model-for-cross-domain-links-xdlink)
- [Preparing Applications](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#preparing-applications)
- [Running the Emulator](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#running-the-emulator)
- [Accessing the QEMU Instance](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#accessing-the-qemu-instance)
- [Utilizing the Emulated SDH Device](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#utilizing-the-emulated-sdh-device)
- [Planned Enhancements](https://github.com/gaps-closure/gaps-emulator/blob/develop/README.md#planned-enhancements)
## Installing External Dependencies
EMU has been developed, deployed, and tested using Ubuntu 19.10 x86_64 Linux. We recommend this distribution to simplify installation of external dependencies. Upon cloning the EMU repository, follow these steps to install required packages (assumes sudo permissions enabled for calling `apt`):
```
cd scripts/qemu
./qemu-build-vm-images.sh -p -c
```
Key dependencies include [NRL CORE](http://nrl.navy.mil/itd/ncs/products/core), [QEMU](http://qemu.org), and Linux bridge utilities.
## Provisioning QEMU VM Disk Images
EMU uses QEMU instances to represent enclave gateways, the nodes designated for cross-domain transactions via a character device to the SDH. This allows us to model multi-domain, multi-ISA environments on which the partitioned software will execute. As a prerequisite to executing the emulator, it is necessary to build clean VM instances (referred to as the "golden images") from which EMU will generate runtime snapshots per experiment. The snapshots allow EMU to quickly spawn clean VM instances for each experiment as well as support multiple experiments in parallel without interfering among users.

VM images can be automatically built using `build_qemu_vm_images.sh`. The script fetches the kernel, builds and minimally configures the VM disk images, and saves a golden copy of the kernels and images. 

```
cd scripts/qemu
./build_qemu_vm_images.sh -h
# Usage: ./build_qemu_vm_images.sh [ -h ] [ -p ] [ -c ] \
#           [ -a QARCH ] [ -d UDIST ] [-s SIZE ] [-k KDIST ]
# -h        Help
# -p        Install pre-requisites on build server
# -c        Intall NRL CORE on build server
# -a QARCH  Architecture [arm64(default), amd64]
# -d UDIST  Ubuntu distro [eoan(default)]
# -s SIZE   Image size [20G(default),<any>]
# -k KDIST  Ubuntu distro for kernel [xenial(default),<any>]
```
Ensure sudo group is allowed to work without passwords, otherwise expect scripting to fail on sudo attempts. First create a virgin image for each architecture for the supported distro (currently eoan):
```
# AMD64
./build_qemu_vm_images.sh -a amd64 -d eoan -k eoan -s 20G
# ARM64
./build_qemu_vm_images.sh -a arm64 -d eoan -k xenial -s 20G
```
This will fetch the kernel (e.g., linux-kernel-amd64-eoan), initrd (linux-initrd-amd64-eoan.gz), and build the virgin qemu vm image (e.g., ubuntu-amd64-eoan-qemu.qcow2.virgin) using debootstrap.

Now configure the virgin image to make it usable generally with user networking support (allows host-based NAT-ted access to Internet):
```
# AMD64
./build_qemu_vm_images.sh -a amd64 -d eoan -k eoan -s 20G -u
# ARM64
./build_qemu_vm_images.sh -a arm64 -d eoan -k xenial -s 20G -u
```
You should find the golden copy (e.g., ubuntu-amd64-eoan-qemu.qcow2) created in `scripts/qemu/build`. This image and the associated kernel should be saved to a common location (e.g., `/IMAGES`) and the files should be made read-only. 

An example installation into `/IMAGES` including AMD64 and ARM64 instances will look like the following:
```
ls -l /IMAGES
-r--r--r-- 1 root root   11391736 Dec  3 21:05 linux-kernel-amd64-eoan
-r--r--r-- 1 root root   14678016 Dec  3 21:05 linux-kernel-arm64-xenial
-r--r--r-- 1 root root 2016935936 Dec  3 21:05 ubuntu-amd64-eoan-qemu.qcow2
-r--r--r-- 1 root root 1001259008 Dec  3 21:05 ubuntu-arm64-eoan-qemu.qcow2
```
## Configuration
EMU comes prepackaged with configuration for 2, 3, and 4 enclaves (GAPS Phase 1, Phase 2, and Phase 3 topologies respectively). The configuration files are JSON formatted and will eventually be generated automatically by CLOSURE tools from the target application's requirements and security policies. Until then, these files are manually built and maintained. The  files include:
```
enclaves.json   # GAPS cross-domain topology description
layout.json     # controls visual layout of nodes
settings.json   # miscellaneous settings
```
Configuration files are located in the subdirectory `config/[N]enclave` where [N] is the number of enclaves. Users will need to modify `enclaves.json` to adjust the ISA and OS for the cross-domain hosts. Layout and Settings JSON files should not require modification.
### Selecting the ISA for Enclave Gateways/Cross-Domain Hosts (xdhost)
Consider the following snippet from `config/2enclave/enclave.json`:
```json
"hostname": "orange-enclave-gw-P",
"hwconf":{"arch": "amd64"},
"swconf":{"os": "ubuntu", "distro": "eoan", "kernel": "eoan",
```
To change orange-enclave-gw-P to use ARM64, modify the configuration as follows:
```json
"hostname": "orange-enclave-gw-P",
"hwconf":{"arch": "arm64"},
"swconf":{"os": "ubuntu", "distro": "eoan", "kernel": "xenial",
```
EMU has been tested using AMD64(eoan) and ARM64(xenial) images. Other architecture/OS instances can be built by following the above provisioning steps, but has not been tested.
### Selecting the SDH Model for Cross-Domain Links (xdlink)
EMU supports Bookends (BKND) and Bump-In-The-Wire (BITW) SDH deployments. Selection of the model is specified in the `xdlink` section of enclaves.json:
```json
"xdlink": 
  [
    { "model":  "BITW",
      "left":   {"f": "orange-enclave-gw-P", "t":"orange-purple-xd-gw",
                 "egress":   {"filterspec": "left-egress-spec", "bandwidth":"100000000", "delay": 0},
                 "ingress":  {"filterspec": "left-ingress-spec", "bandwidth":"100000000", "delay": 0}},
      "right":  {"f": "orange-purple-xd-gw", "t":"purple-enclave-gw-O",
                 "egress":   {"filterspec": "right-egress-spec", "bandwidth":"100000000", "delay": 0},
                 "ingress":   {"filterspec": "right-ingress-spec", "bandwidth":"100000000", "delay": 0}}
    }
  ]
```
The above specifies a BITW model. Simply change to the following to use BKND:
```json
"model": "BKND"
```
For detailed description of the BITW/BKND Emulator design, see [Design Notes](doc/design-notes.md)
## Preparing Applications  
In the Emulator root directory (i.e. gaps-emulator/), create a subdirctory .apps:
```
gaps-emulator$ mkdir .apps
cd .apps
```
Within this directory, place files of the form [hostname].tar where [hostname] corresponds to the hostname of the target node (e.g. orange-enclave-gw-P.tar). The tar file should include an executable binary and any auxillary files required to run. The tarball will be unpacked to the `/home/closure/apps` on the QEMU instance (app installation is only supported for enclave gateways).
## Running the Emulator
A quick-start script is provided to launch the emulator (complete above steps first).
```
gaps-emulator$ ./start.sh [N] # [N] = number of enclaves (2,3, or 4)
```
The start script will retrieve the appropriate configuration files and launch the EMU GUI. 
## Accessing the QEMU instance
Double click an enclave-gateway node to open a terminal to the respective node. Note that this terminal is to that of the CORE node, not the QEMU instance running inside of that node. To enter the QEMU instance:
```
ssh -i /root/.ssh/id_closure_rsa closure@10.200.0.1
```
## Utilizing the Emulated SDH Device
The QEMU instance at an enclave gateway will instantiate a character device (`/dev/vcom`) to which a GAPS application can read/write to exchange data. A proof-of-concept test of the device can be conducted as follows:
1. Open terminals to the QEMU instances of a cross-domain pair (e.g. orange-enclave-gw-P and purple-enclave-gw-O)
2. On one enclave, run `cat /dev/vcom`. On the other enclave run `echo "hello world!" > /dev/vcom`. If the emulator is running correctly, `"hello world!"` will appear on the terminal of the enclave running `cat`.
In practice applications will read and write binary data to the character device.
## Planned Enhancements
The GAPS Emulator is under active development. Features planned for upcoming releases include:
* Hardware Abstraction Layer (HAL) to provide a standard API for GAPS-applications and on-wire formats compatible with vendor solutions
* SDH filter rules based on vendor code and/or specifications
* Multiple character devices per QEMU instance for peering with multiple enclaves
* Integration with vendor code for high-fidelity SDH models
