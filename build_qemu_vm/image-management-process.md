
Ensure sudo group is allowed to work without passwords, otherwise expect scripting will fail on sudo.

First create a virgin image for each architecture for the supported distro (currently eoan):

```
# AMD64, use -p option for first time to ensure prerequisites are installed
# XXX: update iproute, tcl, and tk package names in script 
./build_qemu_vm_images.sh -p -a amd64 -d eoan -k eoan -s 20G
# ARM64
./build_qemu_vm_images.sh -a arm64 -d eoan -k xenial -s 20G
```

This will fetch the kernel (e.g., linux-kernel-amd64-eoan), initrd (linux-initrd-amd64-eoan.gz), and build the virgin qemu vm image (e.g., ubuntu-amd64-eoan-qemu.qcow2.virgin) using debootstrap.

Now configure the virgin image to make it usable generally with user networking support (allows host-based NAT-ted access to Internet):

```
# AMD64
./build_qemu_vm_images.sh -a amd64 -d eoan -k eoan -s 20G -u
./build_qemu_vm_images.sh -a arm64 -d eoan -k xenial -s 20G -u
```

You should find the golden copy (e.g., ubuntu-amd64-eoan-qemu.qcow2) created.  This image and the associated kernel should be saved to a common location (e.g., /IMAGES) and the files should be made read-only.  Any use of this for the emulator will first involve snapshotting and further configuration.

Optionally, take a test snapshot, boot into it, and login as closure user.

```
cd ./build
qemu-img create -f qcow2 -b ubuntu-amd64-eoan-qemu.qcow2 test-snapshot.qcow2
sudo qemu-system-x86_64 -nographic -enable-kvm -m 4G -smp 2 -drive file=test-snapshot.qcow2,format=qcow2 -net nic -net user -kernel linux-kernel-amd64-eoan -append "earlycon console=ttyS0 root=/dev/sda rw"
```

From the build Move golden images to correct place and make read-only
```
cd ./build
sudo cp linux-kernel-amd64-eoan /IMAGES
sudo cp linux-kernel-arm64-xenial /IMAGES
sudo ubuntu-amd64-eoan-qemu.qcow2 /IMAGES
sudo ubuntu-arm64-eoan-qemu.qcow2 /IMAGES
sudo chmod ugo-wx /IMAGES/linux-kernel-*
sudo chmod ugo-wx /IMAGES/ubuntu-*.qcow2
```

Finally create a snapshot for each node in the scenario with corresponding architecture, netplan, and CLOSURE software.

```
./emulator_customize.sh -h
# Usage: ./emulator_customize.sh [ -h ] \
#           [ -g GIMG ] [ -k KRNL ] [-o OFIL ] [-a QARCH]
# -h        Help
# -g GIMG   Full path to golden image, required
# -k KRNL   Full path to kernel, required
# -o OFIL   Name of output snapshot, required
# -a QARCH  Architecture [arm64(default), amd64]

# XXX: will take additional arguments for netplan file and software to be loaded

```

The `emulator_customize.sh` script is only partially done. It needs to be extended to add ssh-key, apply a netplan, and install zmqcat and other CLOSURE software as needed.