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
DIR_IMGS=$(echo $SESSION_FILENAME | sed 's:emulator.*$:emulator/build_qemu_vm/build:')

################################################################################################
# COMMON ENCLAVE DEVICE CONFIGURATION
################################################################################################
GW_IP_PREFIX_BITW="10.0"
GW_IP_PREFIX_BKND="10.201"
GW_IP_POSTFIX=1

EXT_NIF_DEV=eth1
EXT_NIF_BR=br0
EXT_NIF_IP_POSTFIX=2

PTY_TAP_DEV=qemutap0
PTY_TAP_PORT="12345"
PTY_DEV_NAME_PREFIX="/dev/vcom"
PTY_LOG_FILE_PREFIX="/tmp/socat"

INT_TAP_DEV=qemutap1

MAN_TAP_DEV=qemutap2
MAN_TAP_IP="10.200.0.2"
MAN_TAP_NET="10.200.0.0/24"


################################################################################################
# UNIQUE ENCLAVE DEVICE CONFIGURATION
################################################################################################
ORANGE_NAME="orange"
ORANGE_SUBNET_IP=1
ORANGE_GW_PORT="12345"

PURPLE_NAME="purple"
PURPLE_SUBNET_IP=2
PURPLE_GW_PORT="12346"

echo "user=$USER_INITIALS creating bidirectional pipe on $HOSTNAME between $ORANGE_NAME & $PURPLE_NAME"

################################################################################################
# START QEMU on a CORE node
################################################################################################
function start_qemu {
    QEMU_ARCH="$1"
    
    echo "Starting QEMU=$QEMU_ARCH with interfaces: ${PTY_TAP_DEV} ${INT_TAP_DEV} ${MAN_TAP_DEV}"
    CURDT=`date -u --iso-8601=seconds | sed -e 's/ /T/'`
    case $QEMU_ARCH in
        x86_64)
            QEMU_IMG="$DIR_IMGS/ubuntu-19.10-amd64-closure-orange-enclave-gw.qcow2"
            AMD_LINUX="$DIR_IMGS/linux-kernel-amd64-eoan"
            echo "QEMU image=${QEMU_IMG}"
            sudo qemu-system-x86_64 -nographic -enable-kvm -m 1G -smp 1 \
              -drive file=${QEMU_IMG},format=qcow2 \
              -kernel $AMD_LINUX -append 'earlycon console=ttyS0 root=/dev/sda rw' \
              -net nic -net tap,ifname=${PTY_TAP_DEV},script=no,downscript=no \
              -net nic -net tap,ifname=${INT_TAP_DEV},script=no,downscript=no \
              -net nic -net tap,ifname=${MAN_TAP_DEV},script=no,downscript=no \
              -rtc base="$CURDT"
              # Had to comment user nic, strange behavior of TCP getting closed
              # replace this with tap instead of user network to support mgmt interface
              # was working in x86 only scenario yesterday with 2 enclaves
              # configure inside qemu to also use static IP for this interface
              #-net nic -net user,net=192.168.77.0/24,dhcpstart=192.168.77.9,hostfwd=tcp::10023-:22
            ;;
        aarch64)
            QEMU_IMG="$DIR_IMGS/ubuntu-19.10-arm64-closure-purple-enclave-gw.qcow2"
            ARM_LINUX="$DIR_IMGS/linux-kernel-arm64-xenial"
            sudo qemu-system-aarch64 -nographic -M virt -cpu cortex-a53 -m 1024 \
              -drive file=$QEMU_IMG,format=qcow2 \
              -kernel $ARM_LINUX -append 'earlycon root=/dev/vda rw' \
              -netdev tap,id=unet0,ifname=${PTY_TAP_DEV},script=no,downscript=no -device virtio-net-device,netdev=unet0 \
              -netdev tap,id=unet1,ifname=${INT_TAP_DEV},script=no,downscript=no -device virtio-net-device,netdev=unet1 \
              -netdev tap,id=unet2,ifname=${MAN_TAP_DEV},script=no,downscript=no -device virtio-net-device,netdev=unet2 \
              -rtc base="$CURDT"
              # -netdev user,id=unet2,net=192.168.78.0/24,dhcpstart=192.168.78.9,hostfwd=tcp::10022-:22 -device virtio-net-device,netdev=unet2
            ;;
    esac
}

################################################################################################
# CREATE PLUMBING INSIDE CORE ENCLAVE GATEWAT
################################################################################################
function create_socat_pty {
    ENCLAVE_NAME="$1"
    GW_IP="${2}.${3}.${GW_IP_POSTFIX}"
    GW_PORT="$4"
        
    DEV_PTY="${PTY_DEV_NAME_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}"
    LOG="${PTY_LOG_FILE_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}.log"
    
    echo "Creating socat link in $ENCLAVE_NAME from ${DEV_PTY} to ${GW_IP}:${GW_PORT} (log=$LOG)"

#    echo "socat -d -d -lf ${LOG} pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 tcp:${GW_IP}:${GW_PORT},ignoreeof &"
#    rm -f ${DEV_PTY}
    socat -d -d -lf ${LOG} \
      pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 \
      tcp:${GW_IP}:${GW_PORT},ignoreeof &
    sleep 1
    cat ${DEV_PTY}
}

function create_routable_tap {
    DEV="$1"
    IP="$2"
    NET="$3"
    
    echo "creating routable tap (${DEV}) with IP=${IP} NET=${NET}"
    tunctl -t ${DEV}
    ip link set ${DEV} up
    ip addr add ${IP} dev ${DEV}
    ip route add ${NET} dev ${DEV}
}

function create_pty_tap {
    echo "creating pty tap (${EXT_NIF_DEV})"
    ip addr del "${EXT_NIF_IP}/24" dev ${EXT_NIF_DEV}
    tunctl -t ${PTY_TAP_DEV}
    brctl addbr ${EXT_NIF_BR}
    brctl addif ${EXT_NIF_BR} ${PTY_TAP_DEV}
    brctl addif ${EXT_NIF_BR} ${EXT_NIF_DEV}
    ip link set ${PTY_TAP_DEV} up
    ip link set ${EXT_NIF_BR} up
}

function create_book_end_filter {
    ENCLAVE_NAME="$1"
    EXT_NIF_SUBNET_NUMBER="$2"
    EXT_NIF_IP="10.0.${EXT_NIF_SUBNET_NUMBER}.2"
    GW_IP="$3"
    GW_PORT="$4"
    FILTER_EGRESS_SPEC="e-spec"
    FILTER_INGRESS_SPEC="i-spec"
    
    PTY_TAP_IP="10.0.1.1"
    PTY_TAP_NET="10.0.1.0/24"
    
    echo "creating book-end filter in ${ENCLAVE_NAME} for ${MAN_TAP_DEV} and ${PTY_TAP_DEV}"
    
    create_routable_tap ${MAN_TAP_DEV} ${MAN_TAP_IP} ${MAN_TAP_NET}
    create_routable_tap ${PTY_TAP_DEV} ${PTY_TAP_IP} ${PTY_TAP_NET}

    ip addr del "${EXT_NIF_IP}/24" dev ${EXT_NIF_DEV}

    echo "creating book-end plumbing from ${PTY_TAP_DEV} (IP=${PTY_TAP_IP}:${PTY_TAP_PORT}) to ${EXT_NIF_DEV}"
    mkfifo fifo
    nc -4 -k -l ${PTY_TAP_IP} ${PTY_TAP_PORT} \
      < fifo \
      | python3 filterproc.py $FILTER_EGRESS_SPEC \
      > ${EXT_NIF_DEV} \
      | python3 filterproc.py $FILTER_INGRESS_SPEC  \
      > fifo &

    ls -l fifo*
    ps ax
}

function enclave_config {
    ENCLAVE_NAME="$1"
    EXT_NIF_IP="${2}.${3}.${EXT_NIF_IP_POSTFIX}"

    echo "Coniguring enclave $ENCLAVE_NAME (Gateway IP=$EXT_NIF_IP)"
    create_routable_tap ${MAN_TAP_DEV} ${MAN_TAP_IP} ${MAN_TAP_NET}
    create_pty_tap
    ip link | grep -e ${PTY_TAP_DEV} -e ${EXT_NIF_DEV} -e ${EXT_NIF_BR}
    brctl show
}

################################################################################################
# CREATE PLUMBING INSIDE GATEWAY
################################################################################################
function create_gw_pass {
    echo "Creating GW Pass-through between ${1}.${2}.${GW_IP_POSTFIX}:${3} and ${1}.${4}.${GW_IP_POSTFIX}:${5}"
    mkfifo fifo
    nc -4 -k -l "${1}.${2}.${GW_IP_POSTFIX}" ${3} \
      < fifo \
      | nc -4 -k -l "${1}.${4}.${GW_IP_POSTFIX}" ${5} \
      > fifo &
      
    ls -l fifo*
    ps ax
    tcpdump -nli any ip
}

function create_gw_filter {
    echo "Creating GW Filter between ${1}.${2}.${GW_IP_POSTFIX}:${3} and ${1}.${4}.${GW_IP_POSTFIX}:${5}"
    mkfifo fifo-left
    mkfifo fifo-right

    nc -4 -k -l "${1}.${2}.${GW_IP_POSTFIX}" ${3} \
      < fifo-left \
      | python3 filterproc.py left-ingress-spec   \
      | python3 filterproc.py right-egress-spec   \
      > fifo-right &
    nc -4 -k -l "${1}.${4}.${GW_IP_POSTFIX}" ${5} \
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

################################################################################################
# CONIGURATION OPTIONs
################################################################################################
function run {
  case $1 in
    g1)
        create_gw_pass ${GW_IP_PREFIX_BITW} ${ORANGE_SUBNET_IP} ${ORANGE_GW_PORT} ${PURPLE_SUBNET_IP} ${PURPLE_GW_PORT}
        ;;
    g2)
        create_gw_filter ${GW_IP_PREFIX_BITW} ${ORANGE_SUBNET_IP} ${ORANGE_GW_PORT} ${PURPLE_SUBNET_IP} ${PURPLE_GW_PORT}
        ;;
    g3)
        create_gw_filter ${GW_IP_PREFIX_BKND} ${ORANGE_SUBNET_IP} ${ORANGE_GW_PORT} ${PURPLE_SUBNET_IP} ${PURPLE_GW_PORT}
        ;;
    o1)
        create_socat_pty ${ORANGE_NAME} ${GW_IP_PREFIX_BITW} ${ORANGE_SUBNET_IP} ${ORANGE_GW_PORT}
        ;;
    o2)
        enclave_config ${ORANGE_NAME} ${GW_IP_PREFIX_BITW} ${ORANGE_SUBNET_IP}
        start_qemu "x86_64"
        ;;
    o3)
        create_book_end_filter ${ORANGE_NAME} ${ORANGE_SUBNET_IP} ${ORANGE_GW_IP} ${ORANGE_GW_PORT}
        start_qemu "x86_64"
        ;;
    p1)
        create_socat_pty ${PURPLE_NAME} ${PURPLE_SUBNET_IP} ${PURPLE_GW_PORT}
        ;;
    p2)
        enclave_config ${PURPLE_NAME} ${GW_IP_PREFIX_BITW} ${PURPLE_SUBNET_IP}
        start_qemu "aarch64"
        ;;
    p3)
        create_book_end_filter ${PURPLE_NAME} ${PURPLE_SUBNET_IP} ${PURPLE_GW_IP} ${PURPLE_GW_PORT}
        start_qemu "aarch64"
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

################################################################################################
# CONIGURE BASED ON NODE NAME
################################################################################################
function select_function {
    case $HOSTNAME in
        cross-domain-gw)
            if [ "$1" == "v1" ]; then
                run g1
            elif [ "$1" == "v2" ]; then
                run g2
            else
                run g3
            fi
            ;;
        orange-enclave-gw)
            if [ "$1" == "v1" ]; then
                run o1
            elif [ "$1" == "v2" ]; then
                run o2
            else
                run o3
            fi
            ;;
        purple-enclave-gw)
            if [ "$1" == "v1" ]; then
                run p1
            elif [ "$1" == "v2" ]; then
                run p2
            else
                run p3
            fi
            ;;
        *)
            echo "Unknown Host: $HOSTNAME"
            exit 1
            ;;
    esac
}

################################################################################################
# MAIN
################################################################################################
rm -f fifo*
pkill socat
pkill nc
pkill python3
select_function $1
