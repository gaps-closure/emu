#!/bin/sh

QEMU_ARCH="$1"
SNAPSHOT="$2"  #full path to snapshot
KERNEL="$3"    #full path to kernel
USER_INITIALS="$4"

CURDT=`date -u --iso-8601=seconds | sed -e 's/ /T/'`
echo "Starting QEMU=$QEMU_ARCH with interfaces: at $CURDT"
case $QEMU_ARCH in
    amd64)
        qemu-system-x86_64 -nographic -enable-kvm -m 1G -smp 1 \
             -drive file=${SNAPSHOT},format=qcow2 \
             -kernel ${KERNEL} -append 'earlycon console=ttyS0 root=/dev/sda rw' \
             -net nic -net tap,ifname=qemutap0,script=no,downscript=no \
             -net nic -net tap,ifname=qemutap1,script=no,downscript=no \
             -net nic -net tap,ifname=qemutap2,script=no,downscript=no \
             -rtc base="${CURDT}" \
             1> /tmp/qemu_${QEMU_ARCH}_${USER_INITIALS}.log &
        ;;
    arm64)
        qemu-system-aarch64 -nographic -M virt -cpu cortex-a53 -m 1024 \
             -drive file=${SNAPSHOT},format=qcow2 \
             -kernel ${KERNEL} -append 'earlycon root=/dev/vda rw' \
             -netdev tap,id=unet0,ifname=qemutap1,script=no,downscript=no -device virtio-net-device,netdev=unet0 \
             -netdev tap,id=unet1,ifname=qemutap0,script=no,downscript=no -device virtio-net-device,netdev=unet1 \
             -netdev tap,id=unet2,ifname=qemutap2,script=no,downscript=no -device virtio-net-device,netdev=unet2 \
             -rtc base="$CURDT" \
             1> /tmp/qemu_${QEMU_ARCH}_${USER_INITIALS}.log &
        ;;
    *)
        echo "Unknown image type: $QEMU_ARCH"
        exit
        ;;
esac
