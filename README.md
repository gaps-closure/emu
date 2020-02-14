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
EMU uses QEMU instances to represent enclave gateways, the nodes designated for cross-domain transactions via a character device to the SDH. This allows us to model Multi-ISA architectures in which the partitioned software will execute in heterogenous environments across enclaves and/or domains. As a prerequisite to executing the emulator, it is necessary to build clean VM instances (referred to as the "golden images") from which EMU will generate snapshots for use at runtime. The snapshots allow EMU to quickly spawn clean VM instances for each experiment as well as support multiple experiments in parallel with out interfering with other test setups.

