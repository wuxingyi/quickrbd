#!/bin/bash
function loginfo()
{
	msg=$1
	now=`date +%Y/%m/%d" "%X" "`
        echo -e ${now}${msg} >> deployCeph.log
}

function getConf()
{
	echo `cat ./conf/nodeProfile.conf|grep $1|awk -F'=' '{printf $2}'`
}

function toHostname()
{
	serverIP=$1
	ipCD=`echo $serverIP |awk -F "." '{print $3"-"$4}'`
	echo $area-$mroom-$storage-$ipCD
}

loginfo "######################### Begin to DeployCeph Now! #########################" 
TEMP=`getopt -o NWD: --long no-purge,withtranscode,diskprofile: -- "$@"`
echo $TEMP
eval set -- "$TEMP"
diskprofile=""
nopurge="false"
withtranscode="false"
while true
do
        case "$1" in
                -N|--no-purge)
                        nopurge="true"
                        shift ;;
                -W|--withtranscode)
                        withtranscode="true"
                        shift ;;
                -D|--diskprofile)
                        if [ $2 != "raid0" ] && [ $2 != "noraid" ]
                        then
                                echo "Error diskprofile arg! Arg of diskprofile should be [raid0|noraid] !"
				loginfo "Error diskprofile arg! Arg of diskprofile should be [raid0|noraid] !"
				loginfo "Deploy Error! Exit!"
                                exit 1;
                        fi
                        diskprofile=$2
                        shift 2 ;;

                --)shift;break;;
                ?) 
			echo "Args ERROR!"
		        loginfo "Args ERROR!\nDeploy Error! Exit!"
			exit 1;;
        esac
done
if [[ $diskprofile == "" ]]
then
        echo "You should assign -D or --diskprofile ! Arg of diskprofile should be [raid0|noraid] !"
	loginfo "You should assign -D or --diskprofile ! Arg of diskprofile should be [raid0|noraid] !"
        loginfo "Deploy Error! Exit!"
        exit 1;
fi

rm -rf ceph.*

area=`getConf area`
mroom=`getConf mroom`
storage=`getConf storage`
centosversion=`getConf centosversion`
loginfo "All arguments:\narea="$area"\nmroom="$mroom"\nstorage="$storage"\nnopurge="$nopurge"\ndiskprofile="$diskprofile"\nwithtranscodei="$withtranscode"\ncentosversion="$centosversion

## Change ceph repo ##
if [[ $centosversion == 7 ]]
then
	sed -i "s/el6/el7/g" ./deployFile/ceph.repo
elif [[ $centosversion == 6 ]]
then
	sed -i "s/el7/el6/g" ./deployFile/ceph.repo
fi

## Add hostname to /etc/hosts
while read  serverIP
do
	echo $serverIP" "`toHostname $serverIP` >> /etc/hosts
done < ./conf/osdhosts

## Create fabric.py 
cp fabfile.org.py fabfile.py.bak
sed -i "s/#diskprofile#/#diskprofile#\ndiskprofile = \"$diskprofile\"/g" ./fabfile.py.bak

rm monhostnames osdhostnames -rf

while read serverIP
do
        echo `toHostname $serverIP` >> monhostnames
done < ./conf/monhosts

while read serverIP
do
        echo `toHostname $serverIP` >> osdhostnames
done < ./conf/osdhosts

osdnames=`cat ./osdhostnames`
osdnamesArray=`echo $osdnames|sed "s/ /\",\"/g"|sed "s/^/env.hosts = \[\"/g"|sed "s/$/\"\]/g"`
sed -i "s/#osdhostnames#/#osdhostnames#\n$osdnamesArray/g" ./fabfile.py.bak

## Fill node profile ##
tf=`mktemp`
sed "s/\(.*\)=\(.*\)/\1 = \"\2\"/" ./conf/nodeProfile.conf > $tf
sed -i "/#nodeProfile#/ r $tf" fabfile.py.bak


cp fabfile.py.bak fabfile.py

rm ./ceph.bootstrap-mds.keyring ./ceph.bootstrap-osd.keyring ./ceph.client.admin.keyring ./ceph.conf ceph.mon.keyring -rf

## Add ssh auth
fab push_key -P

## Remove StrictHostKeyChecking
grep "StrictHostKeyChecking no" /etc/ssh/ssh_config
if [[ `echo $?` != 0 ]]
then echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
fi

## Test Connection
fab testecho 
if [[ $centosversion == 7 ]]
then
        fab tempOS7handler -P
fi

## Change HostName
fab changeHostAndRepo -P
osdnamelist=`cat osdhostnames`
monsnamelist=`cat monhostnames`

## Clean OriginData
if [[ $nopurge == "false" ]]
then
	loginfo "Begin to PURGE!"
	fab PurgeCeph -P
        echo "Purging End"
	sleep 5
fi
#ceph-deploy purge $osdnamelist
#ceph-deploy purgedata $osdnamelist        

## Create new Monitor Conf
ceph-deploy new $monsnamelist

## Create new OSD Conf
cat ./deployFile/ceph.conf.ex >> ./ceph.conf
if [[ $diskprofile == "raid0" ]]
then
	loginfo "Add RAID attr to ceph.conf!"
	echo 'osd_mkfs_options_xfs = "-i size=2048 -d su=64k -d sw=2"' >> ./ceph.conf
fi

## Install ceph rpm 
#ceph-deploy install $osdnamelist
fab InstallCeph -P

## Install mon
ceph-deploy mon create
echo "Mon Created,wait..."
sleep 10

cat /etc/ceph/ceph.client.admin.keyring
if [[ `echo $?` != 0 ]]
then
	cat /etc/ceph/ceph.client.admin.keyring
	sleep 10
fi
## GatherKeys
ceph-deploy gatherkeys $monsnamelist

## Install OSD
fab prepareDisks -P -w
if [[ $withtranscode == "true" ]]
then 
	loginfo "Begin to deploy OSDs withTranscode!"
	fab DeployOSDsWithTranscode -P 
else
	loginfo "Begin to deploy OSDs !"
	fab DeployOSDs -P
fi
## Copy CephConf
fab CopyCephConf -P

## Install Ceph
fab InstallWuzei -P
fab CheckWuzei

loginfo "######################### DeployCeph Finish ! #########################"
