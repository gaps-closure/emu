#!/bin/bash

echo "Creating bidirectional pipe between enclaves on: $HOSTNAME"

DEV_ORANGE="/dev/vcom_am_orange"
SOCAT_ORANGE_LOGS="/tmp/socat_am_orange.log"
GW_ORANGE_IP="10.0.1.1"
GW_ORANGE_PORT="12345"

DEV_PURPLE="/dev/vcom_am_purple"
SOCAT_PURPLE_LOGS="/tmp/socat_am_purple.log"
GW_PURPLE_IP="10.0.2.1"
GW_PURPLE_PORT="12346"


function run {
  case $1 in
    f)
        mkfifo fifo-left
        mkfifo fifo-right

        nc -4 -k -l ${GW_ORANGE_IP} ${GW_ORANGE_PORT} \
          < fifo-left \
          | python3 filterproc.py left-ingress-spec   \
          | python3 filterproc.py right-egress-spec   \
          > fifo-right &
        nc -4 -k -l ${GW_PURPLE_IP} ${GW_PURPLE_PORT} \
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
        ;;
    g)
        mkfifo fifo
        nc -4 -k -l ${GW_ORANGE_IP} ${GW_ORANGE_PORT} \
          < fifo \
          | nc -4 -k -l ${GW_PURPLE_IP} ${GW_PURPLE_PORT} \
          > fifo &
        ls -l fifo*
        ps ax
        tcpdump -nli any ip
        ;;
    o)
#        rm -f ${DEV_ORANGE}
        socat -d -d -lf ${SOCAT_ORANGE_LOGS} \
          pty,link=${DEV_ORANGE},raw,ignoreeof,unlink-close=0,echo=0 \
          tcp:${GW_ORANGE_IP}:${GW_ORANGE_PORT},ignoreeof &
        sleep 1
        cat ${DEV_ORANGE}
        ;;
    p)
#        rm -f ${DEV_PURPLE}
        socat -d -d -lf ${SOCAT_PURPLE_LOGS} \
          pty,link=${DEV_PURPLE},raw,ignoreeof,unlink-close=0,echo=0 \
          tcp:${GW_PURPLE_IP}:${GW_PURPLE_PORT},ignoreeof &
        sleep 1
        cat ${DEV_PURPLE}
        ;;
    *)
        echo "Invalid option: $0 $1"
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
            if [ -z "$1" ]; then
                run f
            else
                run g
            fi
            ;;
        orange-enclave-gw)
            run o
            ;;
        purple-enclave-gw)
            run p
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