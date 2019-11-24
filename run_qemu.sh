#!/bin/bash

# Start closure QEMU VM (and create if file does not exist)

# Example Usage:
#   Old image:                ./run_qemu old
#   Closure x86 image:        ./run_qemu x86
#   Closure ARM image:        ./run_qemu arm
#   Closure x86 orange node:  ./run_qemu.sh x86 orange-enclave-gw
#   Closure ARM purple node:  ./run_qemu.sh arm purple-enclave-gw

#####################################################################
# A) Define File name components
#####################################################################
GOLDEN_IMG_DIR="/IMAGES"
GOLDEN_NAME="goldencopy"
QEMU_DISK_TYPE="qcow2"
QEMU_OS_NAME="ubuntu-19.10"
PROJECT_NAME="closure"

QEMU_ARCH_NAME_X86="amd64"
QEMU_ARCH_NAME_ARM="arm64"
QEMU_BASE_NAME_ARM="linux-kernel-arm64-xenial"

#####################################################################
# B) QEMU RUN COMMANDS
#####################################################################
function run_x86 {
    #-M virt
    sudo qemu-system-x86_64 -nographic -enable-kvm -m 4G -smp 2 \
      -drive file=${IMG_2_RUN},format=qcow2
}

function run_arm {
    sudo qemu-system-aarch64 -nographic -M virt -cpu cortex-a53 -m 1024 \
      -drive file=${IMG_2_RUN},format=qcow2 \
      -kernel ${GOLDEN_IMG_DIR}/${QEMU_BASE_NAME_ARM} \
      -append 'earlycon root=/dev/vda rw' \
      -netdev user,id=unet \
      -device virtio-net-device,netdev=unet
}

#####################################################################
# C) QEMU DISK CREATION
#####################################################################
# Script cannot create golden image
function create_new_golden_qemu {
    if [ ! -f "$IMG_GOLDEN" ]; then
        echo "Golden file $IMG_GOLDEN does not exist"
        exit
    fi
}

# Create a new generic Closure QEMU image (if it does not exist)
function create_new_closure_qemu {
    if [ ! -f "$IMG_CLOSURE" ]; then
        create_new_golden_qemu
        echo "creating $IMG_CLOSURE from Golden copy $IMG_GOLDEN"
        qemu-img create -f qcow2 -b $IMG_GOLDEN $IMG_CLOSURE
    fi
}

# Create a new CORE-node specific Closure QEMU image (if it does not exist)
function create_new_core_qemu {
    if [ -n "$CORE_NODE_NAME" ] && [ ! -f "$IMG_CORE" ]; then
        create_new_closure_qemu
        echo "creating CORE image $IMG_CORE from $IMG_CLOSURE"
        cp $IMG_CLOSURE $IMG_CORE
    fi
}

#####################################################################
# D) SELECT WHICH IMAGE TO RUN
#####################################################################
# Select whether to run generic or CORE-speciic QEMU version
# (based on whether user defined the CORE_NODE_NAME)
function run_using_defined_images {
    create_new_core_qemu
    if [ -z "$CORE_NODE_NAME" ]; then
        IMG_2_RUN=${IMG_CLOSURE}
    else
        IMG_2_RUN=${IMG_CORE}
    fi
    echo "Starting $IMG_2_RUN"
    echo
    case $QEMU_TYPE in
        arm)
            run_arm
            ;;
        *)
            run_x86
            ;;
    esac
}


# Define images for this QEMU type
function qemu_run {
    case $QEMU_TYPE in
        arm)
            IMG_GOLDEN=$"${GOLDEN_IMG_DIR}/${QEMU_OS_NAME}-${QEMU_ARCH_NAME_ARM}-${GOLDEN_NAME}.${QEMU_DISK_TYPE}"
            IMG_CLOSURE="${QEMU_OS_NAME}-${QEMU_ARCH_NAME_ARM}-${PROJECT_NAME}.${QEMU_DISK_TYPE}"
            IMG_CORE="${QEMU_OS_NAME}-${QEMU_ARCH_NAME_ARM}-${PROJECT_NAME}-${CORE_NODE_NAME}.${QEMU_DISK_TYPE}"
            ;;
        old)
            sudo qemu-system-x86_64 -nographic -enable-kvm -m 4G -smp 2 \
              -drive "file=ubuntu-19.10-amd64-snapshot1.qcow2,format=qcow2"
            exit
            ;;
        *)
            IMG_GOLDEN="${GOLDEN_IMG_DIR}/${QEMU_OS_NAME}-${QEMU_ARCH_NAME_X86}-${GOLDEN_NAME}.${QEMU_DISK_TYPE}"
            IMG_CLOSURE="${QEMU_OS_NAME}-${QEMU_ARCH_NAME_X86}-${PROJECT_NAME}.${QEMU_DISK_TYPE}"
            IMG_CORE="${QEMU_OS_NAME}-${QEMU_ARCH_NAME_X86}-${PROJECT_NAME}-${CORE_NODE_NAME}.${QEMU_DISK_TYPE}"
            ;;
    esac
    run_using_defined_images
}

#####################################################################
# MAIN
#####################################################################
QEMU_TYPE=$1
CORE_NODE_NAME="$2"
cd imgs
qemu_run
cd -
