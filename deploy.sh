#!/bin/bash
function loginfo()
{
	msg=$1
	now=`date +%Y/%m/%d" "%X" "`
        echo -e ${now}${msg} >> deployCeph.log
}

function getConf()
{
	echo `cat nodeProfile.conf|grep $1|awk -F'=' '{printf $2}'`
}

function toHostname()
{
	serverIP=$1
	ipCD=`echo $serverIP |awk -F "." '{print $3"-"$4}'`
	echo $area-$mroom-$storage-$ipCD
}

echo "######################### Begin to DeployCeph Now! #########################" >> deployCeph.log
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


area=`getConf area`
mroom=`getConf mroom`
storage=`getConf storage`
loginfo "All arguments:\narea="$area"\nmroom="$mroom"\nstorage="$storage"\nnopurge="$nopurge"\ndiskprofile="$diskprofile"\nwithtranscodei="$withtranscode

if [[ $area == "bj" ]]
then
	sed -i "s/115.182.93.170/10.200.93.170/g" /root/.cephdeploy.conf
else
	sed -i "s/10.200.93.170/115.182.93.170/g" /root/.cephdeploy.conf
fi

## Add hostname to /etc/hosts
while read  serverIP
do
	echo $serverIP" "`toHostname $serverIP` >> /etc/hosts
done < ./osdhosts

## Create fabric.py 
cp fabfile.org.py fabfile.py.bak
sed -i "s/#diskprofile#/#diskprofile#\ndiskprofile = \"$diskprofile\"/g" ./fabfile.py.bak

rm monhostnames osdhostnames -rf

while read serverIP
do
        echo `toHostname $serverIP` >> monhostnames
done < ./monhosts

while read serverIP
do
        echo `toHostname $serverIP` >> osdhostnames
done < ./osdhosts

osdnames=`cat ./osdhostnames`
osdnamesArray=`echo $osdnames|sed "s/ /\",\"/g"|sed "s/^/env.hosts = \[\"/g"|sed "s/$/\"\]/g"`
sed -i "s/#osdhostnames#/#osdhostnames#\n$osdnamesArray/g" ./fabfile.py.bak

## Fill node profile ##
tf=`mktemp`
sed "s/\(.*\)=\(.*\)/\1 = \"\2\"/" ./nodeProfile.conf > $tf
sed -i "/#nodeProfile#/ r $tf" fabfile.py.bak


cp fabfile.py.bak fabfile.py

rm ./ceph.bootstrap-mds.keyring ./ceph.bootstrap-osd.keyring ./ceph.client.admin.keyring ./ceph.conf ceph.mon.keyring -rf

## Add ssh auth
fab push_key -P

## Test Connection
fab testecho 

## Change HostName
fab changeHostAndRepo -P

osdnamelist=`cat osdhostnames`
monsnamelist=`cat monhostnames`

## Clean OriginData
if [[ $nopurge == "false" ]]
then
	loginfo "Begin to PURGE!"
	fab PurgeCeph -P
fi
#ceph-deploy purge $osdnamelist
#ceph-deploy purgedata $osdnamelist        

## Create new Monitor Conf
ceph-deploy new $monsnamelist

## Create new OSD Conf
cat /letv/deployFile/ceph.conf.ex >> ./ceph.conf
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
sleep 3
## GatherKeys
ceph-deploy gatherkeys $monsnamelist

## Install OSD
fab prepareDisks -P
if [[ $withtranscode == "true" ]]
then 
	loginfo "Begin to deploy OSDs withTranscode!"
	fab DeployOSDsWithTranscode -P 
else
	loginfo "Begin to deploy OSDs !"
	fab DeployOSDs -P
fi
## Copy CephConf
fab CopyCephConf

## Install Ceph
fab InstallWuzei -P
fab CheckWuzei

loginfo "######################### DeployCeph Finish ! #########################"
