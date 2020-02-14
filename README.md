# GAPS Emulator (EMU)
This repository hosts the open source components of the EMU for Multi-ISA cross-domain systems test and evaluation. The `master` branch contains the most recent public release software while `develop` contains bleeding-edge updates and work-in-progress features for use by beta testers and early adopters.

This repository is maintained by Perspecta Labs.

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

An example installation into `/IMAGES/` including AMD64 and ARM64 instances will look like the following:
```
/IMAGES/
/IMAGES/ubuntu-amd64-eoan-qemu.qcow2
/IMAGES/ubuntu-arm64-eoan-qemu.qcow2
/IMAGES/linux-kernel-arm64-xenial
/IMAGES/linux-kernel-amd64-eoan
```



