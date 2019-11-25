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

