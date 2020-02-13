# GAPS Emulator (EMU)
This repository hosts the open source components of the EMU for cross-domain systems test and evaluation. The `master` branch contains the most recent public release software while `develop` contains bleeding-edge updates and work-in-progress features for use by beta testers and early adopters.

This repository is maintained by Perspecta Labs.

## Installing External Dependencies
EMU has been developed, deployed, and tested using Ubuntu 19.10 Linux. We recommend using this distribution to simplify installation of external dependencies. Upon cloning the EMU repository, follow these steps to install required packages:
```
cd scripts/qemu
sudo ./qemu-build-vm-images.sh -p -c
```
Key dependencies include NRL CORE (nrl.navy.mil/itd/ncs/products/core), QEMU, and Linux bridge utilities.
