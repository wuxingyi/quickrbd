#!/bin/bash
if [ ! $1 ] || [ ! $2 ] || [ ! $3 ]
then
	echo "Less args!"
	exit
fi

area=$1
mroom=$2
storage=$3

rpm -qa|grep "net-tools"||yum install -y net-tools

ip=`ifconfig |grep broadcast | grep netmask | awk {'print $2'}`
ipc=`echo $ip |awk -F'.' {'print $3'}`
ipd=`echo $ip |awk -F'.' {'print $4'}`
real_hostname=${area}"-"${mroom}"-"${storage}"-"${ipc}"-"${ipd}
hostnamectl set-hostname $real_hostname
