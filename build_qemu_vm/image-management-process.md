First create a virgin image for each architecture for the supported distro (currently eoan):

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
./build_qemu_vm_images.sh -a arm64 -d eoan -k xenial -s 20G -u
```

You should find the golden copy (e.g., ubuntu-amd64-eoan-qemu.qcow2) created.  This image and the associated kernel should be saved to a common location (e.g., /IMAGES) and the files should be made read-only.  Any use of this for the emulator will first involve snapshotting and further configuration.

Optionally, take a test snapshot, boot into it, and login as closure user.

```
qemu-img create -f qcow2 -b ubuntu-amd64-eoan-qemu.qcow2 test-snapshot.qcow2
sudo qemu-system-x86_64 -nographic -enable-kvm -m 4G -smp 2 -drive file=test-snapshot.qcow2,format=qcow2 -net nic -net user -kernel linux-kernel-amd64-eoan -append "earlycon console=ttyS0 root=/dev/sda rw"
```

XXX: Move golden images to correct place and make read-only

XXX: Create snapshots as needed for emulation

XXX: Do gaps emulator specific common configuration (e.g., software load/build for particular architecture)

XXX: Make copies of snapshot for each node in emulation, and perform node-specific configuration on the copies

XXX: Use the copies within emulation, throw away copies on exiting emulation

