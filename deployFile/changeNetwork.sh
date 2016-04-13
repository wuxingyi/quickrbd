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

hostname=`cat /etc/sysconfig/network|grep HOSTNAME|awk -F"=" {'print $2'}`
ip=`ifconfig |grep Bcast|grep Mask|awk {'print $2'}|awk -F':' {'print $2'}`
ipc=`echo $ip |awk -F'.' {'print $3'}`
ipd=`echo $ip |awk -F'.' {'print $4'}`
real_hostname=${area}"-"${mroom}"-"${storage}"-"${ipc}"-"${ipd}
echo $real_hostname

sed -i "s/${hostname}/${real_hostname}/g" /etc/sysconfig/network
hostname $real_hostname 

echo ${ip}"    "${real_hostname} >> /etc/hosts
