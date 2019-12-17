#!/bin/bash

# Create serial devices, links and filters inside CORE emulation of CLOSURE scenario
# (Hardcoded for a speciic scenario: core-gui -s sample-infrastructure-template.imn)

# Example uses:
#     ./go.sh -q 1 -f 0     Runs device on QEMU inside enclave-gw nodes,    no filter
#     ./go.sh -q 1 -f 1     Runs device on QEMU inside enclave-gw nodes,    gateway BITW filter
#     ./go.sh -q 1 -f 2     Runs device on QEMU inside enclave-gw nodes,    QEMU BOOKEND filter
# For testing, also supports:
#     ./go.sh -q 0 -f 0     Runs device on CORE enclave-gw nodes (no qemu), no filter
#     ./go.sh -q 0 -f 1     Runs device on CORE enclave-gw nodes (no qemu), gateway BITW filter
#     ./go.sh -q 0 -f 2     **** NOT SUPPORT (ffor filters running directly on enclave-gw CORE nodes)

# Run script (./go.sh), with same options, inside cross-domain-gw, orange-enclave-gw and purple-enclave-gw
#   - Flows start and ends on (bidrectional) serial devices created by 'socat'
#   - Serial device (e.g., /dev/vcom_am_orange) are created in the QEMU VM inside
#     the CORE enclave-gw (or on the CORE enclave-gw nodes themselves, for testing)
#   - Filters are either in the Gateway Router between the enclaves (BITW model)
#     or in the enclave-gw QEMU VM (BOOKEND model)


# After configuration, can test using 'echo' and 'cat' inside QEMU (or CORE) node. E.g.,:
#   root@orange-enclave-gw:/tmp/pycore.38969/orange-enclave-gw.conf# ./ssh_into_local_qemu.sh
#   closure@ubuntu-amd64:~$ cat /dev/vcom_am_orange
#   Purple sxys hi bxck xt you
#
#   root@purple-enclave-gw:/tmp/pycore.38969/purple-enclave-gw.conf# ./ssh_into_local_qemu.sh
#   closure@ubuntu-arm64:~$ cat /dev/vcom_am_purple
#   Orxnge sxys hi to Purple
#
#   root@orange-enclave-gw:/tmp/pycore.38969/orange-enclave-gw.conf# ./ssh_into_local_qemu.sh
#   closure@ubuntu-amd64:~$ echo "Orange says hi to Purple" > /dev/vcom_am_orange
#
#   root@purple-enclave-gw:/tmp/pycore.38969/purple-enclave-gw.conf# ./ssh_into_local_qemu.sh
#   closure@ubuntu-arm64:~$ echo "Purple says hi back at you" > /dev/vcom_am_purple


################################################################################################
# GET USER INFORMATION
################################################################################################
if [ "$USER" != "root" ]; then
    USER_INITIALS=${USER:0:2}   # Unique id (hopefully avoiding 'birthday paradox')
else
    USER_INITIALS=$(echo $SESSION_FILENAME | awk -F/ '{print $3}' | cut -c1-2 )
fi
DIR_EMUL=$(echo $SESSION_FILENAME | sed 's:emulator.*$:emulator:')
DIR_QEMU=${DIR_EMUL}/build_qemu_vm/build

################################################################################################
# COMMON CONFIGURATION
################################################################################################
GW_IP_PREFIX="10.0"
GW_IP_POSTFIX=1

EXT_NIF_DEV=eth1
EXT_NIF_BR=br0
EXT_NIF_IP_POSTFIX=2

PTY_TAP_DEV=qemutap0
PTY_DEV_NAME_PREFIX="/dev/vcom"
PTY_LOG_FILE_PREFIX="/tmp/socat"

INT_TAP_DEV=qemutap1
INT_SUBNET_OFFSET=100

MAN_TAP_DEV=qemutap2
MAN_SUBNET_PREFIX="10.200.0"

LOCAL_IP="127.0.0.1"
LOCAL_PORT="54321"

################################################################################################
# ENCLAVE SPECIIC CONFIGURATIONS
################################################################################################
ORANGE_NAME="orange"
ORANGE_SUB_IP_NUMBER=1
ORANGE_GW_PORT="12345"
ORANGE_SLEEP_TIME=30

PURPLE_NAME="purple"
PURPLE_SUB_IP_NUMBER=2
PURPLE_GW_PORT="12346"
PURPLE_SLEEP_TIME=240

echo "user=$USER_INITIALS creating bidirectional pipe on $HOSTNAME between $ORANGE_NAME & $PURPLE_NAME"

################################################################################################
# START QEMU on a CORE node (in background, so need to use ssh to get into QEMU)
################################################################################################
function start_qemu {
    QEMU_ARCH="$1"
    
    CURDT=`date -u --iso-8601=seconds | sed -e 's/ /T/'`
    echo "Starting QEMU=$QEMU_ARCH with interfaces: ${PTY_TAP_DEV} ${INT_TAP_DEV} ${MAN_TAP_DEV} at $CURDT"
    case $QEMU_ARCH in
        x86_64)
            QEMU_IMG="$DIR_QEMU/ubuntu-19.10-amd64-closure-orange-enclave-gw.qcow2"
            AMD_LINUX="$DIR_QEMU/linux-kernel-amd64-eoan"
            sudo qemu-system-x86_64 -nographic -enable-kvm -m 1G -smp 1 \
              -drive file=${QEMU_IMG},format=qcow2 \
              -kernel ${AMD_LINUX} -append 'earlycon console=ttyS0 root=/dev/sda rw' \
              -net nic -net tap,ifname=${PTY_TAP_DEV},script=no,downscript=no \
              -net nic -net tap,ifname=${INT_TAP_DEV},script=no,downscript=no \
              -net nic -net tap,ifname=${MAN_TAP_DEV},script=no,downscript=no \
              -rtc base="${CURDT}" \
              1> /tmp/qemu_${QEMU_ARCH}_${USER_INITIALS}.log &
            ;;
        aarch64)
            QEMU_IMG="$DIR_QEMU/ubuntu-19.10-arm64-closure-purple-enclave-gw.qcow2"
            ARM_LINUX="$DIR_QEMU/linux-kernel-arm64-xenial"
            sudo qemu-system-aarch64 -nographic -M virt -cpu cortex-a53 -m 1024 \
              -drive file=$QEMU_IMG,format=qcow2 \
              -kernel $ARM_LINUX -append 'earlycon root=/dev/vda rw' \
              -netdev tap,id=unet0,ifname=${PTY_TAP_DEV},script=no,downscript=no -device virtio-net-device,netdev=unet0 \
              -netdev tap,id=unet1,ifname=${INT_TAP_DEV},script=no,downscript=no -device virtio-net-device,netdev=unet1 \
              -netdev tap,id=unet2,ifname=${MAN_TAP_DEV},script=no,downscript=no -device virtio-net-device,netdev=unet2 \
              -rtc base="$CURDT" \
              1> /tmp/qemu_${QEMU_ARCH}_${USER_INITIALS}.log &
            ;;
        *)
            echo "Unknown image type: $QEMU_ARCH"
            exit
            ;;
    esac
}

################################################################################################
# CREATE PLUMBING
################################################################################################
# Create tap device ($1) on CORE node that will link with QEMU VM network interface
# using the specified IP address/network $2
function create_routable_tap {
    DEV="$1"
    IP="${2}.2"
    NET="${2}.0/24"
    
    echo "creating tap ${DEV} with routable IP=${IP} NET=${NET}"
    tunctl -t ${DEV}
    ip link set ${DEV} up
    ip addr add ${IP} dev ${DEV}
    ip route add ${NET} dev ${DEV}
}

# Create tap device $3 on CORE node that will link with QEMU VM network interface
# and bridge ($1) to extermal interface ($2)
function create_bridged_tap {
    BRIDGE="$1"
    DEV_EX="$2"
    DEV_TAP="$3"
    IP="$4"

    echo "creating tap ${DEV_TAP} with layer 2 bridge to ${DEV_EX}"
    ip addr del "${IP}/24" dev ${DEV_EX}
    tunctl -t ${DEV_TAP}
    brctl addbr ${BRIDGE}
    brctl addif ${BRIDGE} ${DEV_TAP}
    brctl addif ${BRIDGE} ${DEV_EX}
    ip link set ${DEV_TAP} up
    ip link set ${BRIDGE} up
}

# Plumb CORE enclave-gateway node using Layer-2 bridge, tap & interface names
# (all nodes use same names), then display conigured link info
function enclave_config {
    echo "Plumbing CORE enclave-gateway node"
    create_routable_tap ${MAN_TAP_DEV} ${MAN_SUBNET_PREFIX}
    create_bridged_tap ${EXT_NIF_BR} ${EXT_NIF_DEV} ${PTY_TAP_DEV} "${1}"
    ip link | grep -e ${PTY_TAP_DEV} -e ${EXT_NIF_DEV} -e ${EXT_NIF_BR}
    brctl show
}

################################################################################################
# Create Linked NETCATs (with and without filters)
################################################################################################
function link_netcats_pass_through {
    echo "Creating Pass-through between ${1}:${2} and ${3}:${4}"
    mkfifo fifo
    nc -4 -k -l "${1}" ${2} \
      < fifo \
      | nc -4 -k -l "${3}" ${4} \
      > fifo &
      
    ls -l fifo*
    ps ax
}

function link_netcats_with_filters {
    IP_LEFT=${1}
    PORT_LEFT=${2}
    IP_RIGHT=${3}
    PORT_RIGHT=${4}
    echo "Adding Filter between ${IP_LEFT}:${PORT_LEFT} and ${IP_RIGHT}:${PORT_RIGHT}"

    case $FILTER_MODE in
        2)
            echo "Linking netcats inside QEMU VM (BOOKEND Model)"
            ssh -i $DIR_QEMU/id_closure_rsa closure@${MAN_SUBNET_PREFIX}.1 echo "h=$HOSTNAME"
            scp -i $DIR_QEMU/id_closure_rsa filterproc.py closure@${MAN_SUBNET_PREFIX}.1:~
            scp -i $DIR_QEMU/id_closure_rsa ${DIR_EMUL}/nc_link.sh closure@${MAN_SUBNET_PREFIX}.1:~
            ssh -i $DIR_QEMU/id_closure_rsa closure@${MAN_SUBNET_PREFIX}.1 bash nc_link.sh ${IP_LEFT} ${PORT_LEFT} ${IP_RIGHT} ${PORT_RIGHT} &
            sleep 2
            ;;
        *)
            rm -f fifo*
            echo "Linking netcats directly on CORE node (BITW Model)"
            mkfifo fifo-left
            mkfifo fifo-right   # Can we get rid of the second fifo, but then get very long pipeline
            nc -4 -k -l ${IP_LEFT} ${PORT_LEFT} \
                < fifo-left \
                | python3 filterproc.py left-ingress-spec   \
                | python3 filterproc.py right-egress-spec   \
                > fifo-right &
            nc -4 -k -l ${IP_RIGHT} ${PORT_RIGHT} \
                < fifo-right \
                | python3 filterproc.py right-ingress-spec  \
                | python3 filterproc.py left-egress-spec    \
                > fifo-left &
            ls -l fifo*
            ps ax
            ;;
    esac
}

################################################################################################
# Add SOCAT PTY device in enclave-gw ($1) connected to specified IP address ($2) / port ($3)
################################################################################################
function create_socat_pty {
    ENCLAVE_NAME="$1"
    IP="$2"
    PORT="$3"
    DEV_PTY="${PTY_DEV_NAME_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}"
    LOG="${PTY_LOG_FILE_PREFIX}_${USER_INITIALS}_${ENCLAVE_NAME}.log"
    echo "Creating socat link in $ENCLAVE_NAME from ${DEV_PTY} to ${IP}:${PORT} (log=$LOG)"

    case $QEMU_MODE in
        0)   # Add directly on CORE node
            socat -d -d -lf ${LOG} \
              pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 \
              tcp:${IP}:${PORT},ignoreeof &
            sleep 1
            cat ${DEV_PTY}
            ;;
        *)   # Add inside QEMU running on CORE node
            ssh -i $DIR_QEMU/id_closure_rsa closure@${MAN_SUBNET_PREFIX}.1 \
                sudo socat -d -d -lf ${LOG} \
                  pty,link=${DEV_PTY},raw,ignoreeof,unlink-close=0,echo=0 \
                  tcp:${IP}:${PORT},ignoreeof &
            sleep 1
            ssh -i $DIR_QEMU/id_closure_rsa closure@${MAN_SUBNET_PREFIX}.1 \
                sudo chmod 666 ${DEV_PTY}
            ssh -i $DIR_QEMU/id_closure_rsa closure@${MAN_SUBNET_PREFIX}.1  ps ax | grep -e nc -e socat
            ;;
    esac
}

################################################################################################
# CONIGURATION of: g) Gateway, o) Orange enclave-GW, p) Purple enclave-GW
################################################################################################
function config_node_type {
  case $1 in
    g)
        case $FILTER_MODE in
            1) link_netcats_with_filters ${GW_IP_PREFIX}.${ORANGE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${ORANGE_GW_PORT} ${GW_IP_PREFIX}.${PURPLE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${PURPLE_GW_PORT} ;;
            *) link_netcats_pass_through ${GW_IP_PREFIX}.${ORANGE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${ORANGE_GW_PORT} ${GW_IP_PREFIX}.${PURPLE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${PURPLE_GW_PORT} ;;
        esac
        tcpdump -nli any ip
        ;;
    o)
        case $QEMU_MODE in
            0)  create_socat_pty ${ORANGE_NAME} ${GW_IP_PREFIX}.${ORANGE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${ORANGE_GW_PORT} ;;
            *)  enclave_config ${GW_IP_PREFIX}.${ORANGE_SUB_IP_NUMBER}.${EXT_NIF_IP_POSTFIX}
                start_qemu "x86_64"
                echo -e "\nWaiting $ORANGE_SLEEP_TIME seconds for QEMU to boot...\n"; sleep $ORANGE_SLEEP_TIME
                case $FILTER_MODE in
                    2)  link_netcats_with_filters ${LOCAL_IP} ${LOCAL_PORT} ${GW_IP_PREFIX}.${ORANGE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${ORANGE_GW_PORT}
                        create_socat_pty ${ORANGE_NAME} ${LOCAL_IP} ${LOCAL_PORT} ;;
                    *)  create_socat_pty ${ORANGE_NAME} ${GW_IP_PREFIX}.${ORANGE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${ORANGE_GW_PORT} ;;
                esac ;;
        esac ;;
    p)
        case $QEMU_MODE in
            0)  create_socat_pty ${PURPLE_NAME} ${GW_IP_PREFIX}.${PURPLE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${PURPLE_GW_PORT} ;;
            *)  enclave_config ${GW_IP_PREFIX}.${PURPLE_SUB_IP_NUMBER}.${EXT_NIF_IP_POSTFIX}
                start_qemu "aarch64"
                echo -e "\nWaiting $PURPLE_SLEEP_TIME seconds for QEMU to boot (and SSHd to settle) ...\n"; sleep $PURPLE_SLEEP_TIME
                case $FILTER_MODE in
                    2)  link_netcats_with_filters ${LOCAL_IP} ${LOCAL_PORT} ${GW_IP_PREFIX}.${PURPLE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${PURPLE_GW_PORT}
                        create_socat_pty ${PURPLE_NAME} ${LOCAL_IP} ${LOCAL_PORT} ;;
                    *)  create_socat_pty ${PURPLE_NAME} ${GW_IP_PREFIX}.${PURPLE_SUB_IP_NUMBER}.${GW_IP_POSTFIX} ${PURPLE_GW_PORT} ;;
                esac ;;
        esac ;;
    *)
        echo "Invalid 'config_node_type function' option: $1"
        echo "usage:"
        echo "   $0 g  Add netcat link on GW"
        echo "   $0 o  Add /dev/vcom_xx_orange inside Orange-GW Node with link to GW"
        echo "   $0 p  Add /dev/vcom_xx_purple inside Purple-GW Node with link to GW"
        exit 1
        ;;
  esac
}

# CONIGURE BASED ON NODE NAME
function config_local_node {
    case $HOSTNAME in
        cross-domain-gw)    config_node_type g ;;
        orange-enclave-gw)  config_node_type o ;;
        purple-enclave-gw)  config_node_type p ;;
        *)                  echo "Unknown CORE node: $HOSTNAME"; exit 1 ;;
    esac
}

################################################################################################
# GET USER CONFIGURATION INPUT
################################################################################################
# Define default mode:
QEMU_MODE=1
FILTER_MODE=2

usage_exit() {
    [[ -n $1 ]] && echo $1
    echo "Usage: $0 [ -h ]         Print this help"
    echo "               [ -f MODE ] Filter MODE: 0=none, 1=BITW, 2=BOOKEND"
    echo "               [ -q MODE ] QEMU MODE:   0=none, 1=EnclaveGateways"
    exit
}

get_args() {
    while getopts "f:q:h" options; do
        case "${options}" in
            f) FILTER_MODE=${OPTARG} ;;
            q) QEMU_MODE=${OPTARG}   ;;
            h) usage_exit            ;;
            :) usage_exit ":Error: -${OPTARG} requires and arguement" ;;
            *) usage_exit            ;;
        esac
    done
    echo "Modes: f=$FILTER_MODE q=$QEMU_MODE"
    # Check that option is supported
    if    [ ${FILTER_MODE} -lt 0 ] || [ ${FILTER_MODE} -gt 2 ] \
       || [ ${QEMU_MODE}   -lt 0 ] || [ ${QEMU_MODE}   -gt 1 ] \
       || ([ ${QEMU_MODE}  -eq 0 ] && [ ${FILTER_MODE} -eq 2 ]); then
        usage_exit
    fi
}

################################################################################################
# MAIN
################################################################################################
get_args "$@"
pkill socat
pkill nc
pkill python3
cp ${DIR_EMUL}/ssh_into_local_qemu.sh .
config_local_node
