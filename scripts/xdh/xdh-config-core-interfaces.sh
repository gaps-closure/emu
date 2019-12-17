#!/bin/sh

for i in 0 1
do
    ip addr flush eth$i
    tunctl -t qemutap$i
    brctl addbr br$i
    brctl addif br$i qemutap$i
    brctl addif br$i eth$i
    ifconfig qemutap$i up
    ifconfig br$i up
done

tunctl -t qemutap2
ip link set qemutap2 up
ip addr add 10.200.0.2 dev qemutap2
ip route add 10.200.0.0/24 dev qemutap2
