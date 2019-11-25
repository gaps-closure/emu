# Configure Closure QEMU VMs  (Nov 24, 2019) 

*********************************************************
1) Start a VM
*********************************************************
# x86:
amcauley@workhorse:~/gaps/top-level/emulator$ ./run_qemu.sh
# ARM:
amcauley@workhorse:~/gaps/top-level/emulator$ ./run_qemu.sh arm

*********************************************************
2) Become su in VM (without having to type password) 
*********************************************************
sudo bash
visudo
# Add line below at the end of the '/etc/sudoers' file
closure ALL=(ALL) NOPASSWD: ALL


*********************************************************
3) Set date and name if on ARM in VM
*********************************************************
echo "ubuntu-arm" > hostname
vi /etc/hosts
#add line after localhost
127.0.1.1	ubuntu-arm

date --set "24 Nov 2019 11:13:00"

*********************************************************
4) Load Packages (copy and paste apt commands below)
*********************************************************
apt update
apt upgrade
apt install -y build-essential

# ARM also add universe (for libzmq3-dev)
apt install -y software-properties-common
add-apt-repository universe
apt update

apt install -y libzmq3-dev
apt install -y socat
apt install -y zip unzip
apt install -y ssh
apt install -y net-tools
apt install -y tshark

*********************************************************
5) Other 
*********************************************************
# zc
cd /tmp
wget https://github.com/hdhaussy/zc/archive/master.zip
unzip master.zip
cd zc-master
makeorange-netcfg.yamlcp zc /usr/local/bin/
cd /tmp
rm -rf zc-master master.zip

# Interface IP addressing 
amcauley@workhorse:~/gaps/top-level/emulator$ cat config/qemu_config_netplan_orange.txt
cd /home/closure
mkdir -p netplans
cp /etc/netplan/* netplans/
echo "PASTE" > orange-netcfg.yaml
cat orange-netcfg.yaml | sed 's:1\.:2\.:' | sed 's:ens3:eth0:' | sed 's:ens4:eth1:' | sed 's:ens5:eth2:' > purple-netcfg.yaml

# ssh public key
amcauley@workhorse:~/gaps/top-level/emulator/conifg$ ssh-keygen -f id_rsa -C ""
amcauley@workhorse:~/gaps/top-level/emulator/conifg$ cat id_rsa.pub 
cd /home/closure
mkdir -p .ssh
echo "PASTE" >> .ssh/authorized_keys

*********************************************************
6) Close VM
*********************************************************
shutdown -h 0


*********************************************************
10) CREATE VM per CORE node (with right IP addresses)
*********************************************************
amcauley@workhorse:~/gaps/top-level/emulator$ ./run_qemu.sh x86 orange-enclave-gw
  closure@ubuntu-x86:~$ cd
  closure@ubuntu-x86:~$ sudo bash
  root@ubuntu-x86:/home/closure# rm /etc/netplan/* 
  root@ubuntu-x86:/home/closure# cp netplans/orange-netcfg.yaml /etc/netplan/

amcauley@workhorse:~/gaps/top-level/emulator$ ./run_qemu.sh arm purple-enclave-gw
  closure@ubuntu-arm:~$ sudo bash
  root@ubuntu-arm:/home/closure# rm /etc/netplan/*
  root@ubuntu-arm:/home/closure# cp netplans/purple-netcfg.yaml /etc/netplan/


