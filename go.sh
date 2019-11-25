#!/bin/bash

# Create a serial link between enclaves for CLOSURE project
#
# Link starts and ends on serial devices created by 'socat' on the
# ORANGE and PURPLE enclaves, with the option of filters on the:
#    a) Gateway (GW) between the end nodes (BITW model)
#    b) Two end nodes (BOOKEND model)

if [ "$USER" != "root" ]; then
    USER_INITIALS=${USER:0:2}   # Unique id (hopefully avoiding 'birthday paradox')
else
    USER_INITIALS=$(echo $SESSION_FILENAME | awk -F/ '{print $3}' | cut -c1-2 )
fi

DIR_IMGS=$(echo $SESSION_FILENAME | sed 's:emulator.*$:emulator/imgs:')

DEV_PTY_PREFIX="/dev/vcom"
LOG_FILE_PREFIX="/tmp/socat"
ARM_LINUX="$DIR_IMGS/linux-kernel-arm64-xenial"

ORANGE_NAME="orange"
ORANGE_SUBNET_IP=1
#ORANGE_QEMU="$DIR_IMGS/ubuntu-19.10-amd64-snapshot1.qcow2"
ORANGE_QEMU="$DIR_IMGS/ubuntu-19.10-amd64-closure-orange-enclave-gw.qcow2"
ORANGE_GW_IP="10.0.${ORANGE_SUBNET_IP}.1"
ORANGE_GW_PORT="12345"

PURPLE_NAME="purple"
PURPLE_SUBNET_IP=2
#PURPLE_QEMU="$DIR_IMGS/ubuntu-19.10-amd64-snapshot2.qcow2"
PURPLE_QEMU="$DIR_IMGS/ubuntu-19.10-arm64-closure-purple-enclave-gw.qcow2"
PURPLE_GW_IP="10.0.${PURPLE_SUBNET_IP}.1"
PURPLE_GW_PORT="12346"

echo "user=$USER_INITIALS creating bidirectional pipe on $HOSTNAME between $ORANGE_NAME & $PURPLE_NAME"

function create_socat_pty {
    ENCLAVE_NAME="$1"
    GW_IP="$2"
    GW_PORT="$3"
    
    DEV_PTY="${DEV_PTY_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}"
    LOG="${LOG_FILE_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}.log"
#    echo "socat -d -d -lf ${LOG} pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 tcp:${GW_IP}:${GW_PORT},ignoreeof &"
#    rm -f ${DEV_PTY}
    socat -d -d -lf ${LOG} \
      pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 \
      tcp:${GW_IP}:${GW_PORT},ignoreeof &
    sleep 1
    cat ${DEV_PTY}
}

function plumb_enclave {
    tunctl -t ${DEV_MG_TAP}
    ip link set ${DEV_MG_TAP} up
    ip addr add 10.200.0.2 dev ${DEV_MG_TAP}
    ip route add 10.200.0.0/24 dev ${DEV_MG_TAP}

    ip addr del "${EN_GW_IP}/24" dev ${DEV_GW_IF}
    tunctl -t ${DEV_GW_TAP}
    brctl addbr ${DEV_GW_BR}
    brctl addif ${DEV_GW_BR} ${DEV_GW_TAP}
    brctl addif ${DEV_GW_BR} ${DEV_GW_IF}
    ip link set ${DEV_GW_TAP} up
    ip link set ${DEV_GW_BR} up
#    ifconfig ${DEV_GW_BR} up

    ip link | grep -e ${DEV_GW_TAP} -e ${DEV_GW_IF} -e ${DEV_GW_BR}
    brctl show
}

function start_qemu {
    case $QEMU_ARCH in
        x86_64)
            sudo qemu-system-x86_64 -nographic -enable-kvm -m 1G -smp 1 \
              -drive file=${QEMU_IMG},format=qcow2 \
              -net nic -net tap,ifname=${DEV_GW_TAP},script=no,downscript=no \
              -net nic -net tap,ifname=${DEV_IN_TAP},script=no,downscript=no \
              -net nic -net tap,ifname=${DEV_MG_TAP},script=no,downscript=no
              # Had to comment user nic, strange behavior of TCP getting closed
              # replace this with tap instead of user network to support mgmt interface
              # was working in x86 only scenario yesterday with 2 enclaves
              # configure inside qemu to also use static IP for this interface
              #-net nic -net user,net=192.168.77.0/24,dhcpstart=192.168.77.9,hostfwd=tcp::10023-:22
            ;;
        aarch64)
            # XXX: Fix args correctly, needs to come from outside
            sudo qemu-system-aarch64 -nographic -M virt -cpu cortex-a53 -m 1024 \
              -drive file=$PURPLE_QEMU,format=qcow2 \
              -kernel $ARM_LINUX -append 'earlycon root=/dev/vda rw' \
              -netdev tap,id=unet0,ifname=qemutap0,script=no,downscript=no -device virtio-net-device,netdev=unet0 \
              -netdev tap,id=unet1,ifname=qemutap1,script=no,downscript=no -device virtio-net-device,netdev=unet1 \
              -netdev tap,id=unet2,ifname=qemutap2,script=no,downscript=no -device virtio-net-device,netdev=unet2

              # -netdev user,id=unet2,net=192.168.78.0/24,dhcpstart=192.168.78.9,hostfwd=tcp::10022-:22 -device virtio-net-device,netdev=unet2
            ;;
    esac
}


function enclave_config {
    ENCLAVE_NAME="$1"
    SUBNET_IP_GW="$2"
    QEMU_IMG="$3"
    QEMU_ARCH="$4"
 
    EN_GW_IP="10.0.${SUBNET_IP_GW}.2"
    DEV_GW_TAP=qemutap0
    DEV_GW_BR=br0
    DEV_GW_IF=eth1
    DEV_IN_TAP=qemutap1
    DEV_MG_TAP=qemutap2
#    echo "$ENCLAVE_NAME $SUBNET_IP_GW QEMU=$QEMU_IMG IP=$EN_GW_IP tap=$DEV_GW_TAP BR=$DEV_GW_BR IF=$DEV_GW_IF (tap=$DEV_IN_TAP)"

    plumb_enclave
    start_qemu
      
}

function create_gw_pass {
    mkfifo fifo
    nc -4 -k -l ${ORANGE_GW_IP} ${ORANGE_GW_PORT} \
      < fifo \
      | nc -4 -k -l ${PURPLE_GW_IP} ${PURPLE_GW_PORT} \
      > fifo &
      
    ls -l fifo*
    ps ax
    tcpdump -nli any ip
}

function create_gw_filter {
    mkfifo fifo-left
    mkfifo fifo-right

# echo "nc -4 -k -l ${PURPLE_GW_IP} ${PURPLE_GW_PORT} < fifo-right | python3 filterproc.py right-ingress-spec | python3 filterproc.py left-egress-spec > fifo-left &"

    nc -4 -k -l ${ORANGE_GW_IP} ${ORANGE_GW_PORT} \
      < fifo-left \
      | python3 filterproc.py left-ingress-spec   \
      | python3 filterproc.py right-egress-spec   \
      > fifo-right &
    nc -4 -k -l ${PURPLE_GW_IP} ${PURPLE_GW_PORT} \
      < fifo-right \
      | python3 filterproc.py right-ingress-spec  \
      | python3 filterproc.py left-egress-spec    \
      > fifo-left &

    # XXX: can we get rid of the second fifo
    #nc -4 -k -l -v 10.0.2.1 12345 < fifo-into-nc1 \
    #  | python3 filterproc.py left-ingress-spec   \
    #  | python3 filterproc.py right-egress-spec   \
    #  | nc -4 -k -l -v 10.0.3.1 12346             \
    #  | python3 filterproc.py right-ingress-spec  \
    #  | python3 filterproc.py left-egress-spec    \
    #  > fifo-into-nc1

    ls -l fifo*
    ps ax
    tcpdump -nli any ip
}

function run {
  case $1 in
    f)
        create_gw_filter
        ;;
    g)
        create_gw_pass
        ;;
    o)
        create_socat_pty ${ORANGE_NAME} ${ORANGE_GW_IP} ${ORANGE_GW_PORT}
        ;;
    o2)
        enclave_config ${ORANGE_NAME} ${ORANGE_SUBNET_IP} ${ORANGE_QEMU} "x86_64"
        ;;
    p)
        create_socat_pty ${PURPLE_NAME} ${PURPLE_GW_IP} ${PURPLE_GW_PORT}
        ;;
    p2)
        enclave_config ${PURPLE_NAME} ${PURPLE_SUBNET_IP} ${PURPLE_QEMU} "aarch64"
        ;;
    *)
        echo "Invalid option: $1"
        echo "usage:"
        echo "   $0 f  Add bidirectional link with filter on GW"
        echo "   $0 g  Add bidirectional link pass-through on GW"
        echo "   $0 o  Add /dev/vcom0 on Orange Node with link to GW"
        echo "   $0 p  Add /dev/vcom1 on Purple Node with link to GW"
        exit 1
        ;;
  esac
}

function select_function {
    case $HOSTNAME in
        cross-domain-gw)
            if [ -n "$1" ]; then
                run f
            else
                run g
            fi
            ;;
        orange-enclave-gw)
            if [ -n "$1" ]; then
                run o
            else
                run o2
            fi
            ;;
        purple-enclave-gw)
            if [ -n "$1" ]; then
                run p
            else
                run p2
            fi
            ;;
        *)
            echo "Unknown Host: $HOSTNAME"
            exit 1
            ;;
    esac
}

#MAIN
rm -f fifo*
pkill socat
pkill nc
pkill python3
select_function $1
