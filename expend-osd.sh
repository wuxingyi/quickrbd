#!/bin/bash
function loginfo()
{       
        msg=$1
        now=`date +%Y/%m/%d" "%X" "`
        echo -e ${now}${msg} >> extend-osd.log
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

function checkIP()
{
	ip=$1
	echo "$ip"|grep -Eo "$regex_ip" > /dev/null 2>&1
	echo $?	
}

loginfo "######################### Begin to ExtendOsd Now! #########################"
osdserver=""
confserver=""
diskprofile=""
nopurge="false"

area=`getConf area`
mroom=`getConf mroom`
storage=`getConf storage`

confservername=""
withtranscode="false"
regex_ip="^(2[0-4][0-9]|25[0-5]|1[0-9][0-9]|[1-9][0-9]|[1-9])(\.(2[0-4][0-9]|25[0-5]|1[0-9][0-9]|[1-9][0-9]|[1-9])){3}$"
TEMP=`getopt -o NWD:c:s:H: --long hostname:,no-purge,withtranscode,confserver:,osdserver:,diskprofile: -- "$@"`
eval set -- "$TEMP"
while true
do
        case "$1" in
		-H|--hostname)
			confservername=$2
			shift 2;;
		-N|--no-purge)
                        nopurge="true"
                        shift ;;
                -W|--withtranscode)
                        withtranscode="true"
                        shift ;;
                -c|--confserver)
			if [[ `checkIP $2` -eq  1 ]]
			then
				echo "confServerIP "$2" is invalid! EXIT!"
				loginfo "IP "$2" is invalid! EXIT!"
				exit 1;
			fi
                        confserver=$2
                        shift 2 ;;
                -s|--osdserver)
			if [[ `checkIP $2` -eq  1 ]]
                        then
				echo "osdServerIP "$2" is invalid! EXIT!"
                                loginfo "IP "$2" is invalid!"
                                exit 1;
                        fi
                        osdserver=$2
                        shift 2 ;;
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
if [[ $osdserver == "" ]] || [[ $confserver == "" ]] || [[ $diskprofile == "" ]]
then
	loginfo "Lack of Arguments ! EXIT !"
	echo -e "Lack of Arguments !\nUsage: sh expend-osd.sh -c CONFSERVER -s OSDSERVER -D [raid0|noraid] [-N|--no-purge] [-W|--withtrancode] [-H|--hostname MONHOSTNAME]"
	exit 1
fi
echo "confServerIP: "$confserver" osdServerIP: "$osdserver
loginfo "confServerIP: "$confServerIP" osdServerIP: "$osdServerIP
loginfo "All arguments:\narea="$area"\nmroom="$mroom"\nstorage="$storage"\nnopurge="$nopurge"\ndiskprofile="$diskprofile"\nwithtranscodei="$withtranscode
osdservername=`toHostname $osdserver`
if [[ $confservername == "" ]]
then
	confservername=`toHostname $osdserver`
fi

if [[ $area == "bj" ]]
then
        sed -i "s/115.182.93.170/10.200.93.170/g" /root/.cephdeploy.conf
else
        sed -i "s/10.200.93.170/115.182.93.170/g" /root/.cephdeploy.conf
fi

## Add hostname to /etc/hosts
echo $osdserver" "$osdservername >> /etc/hosts
echo $confserver" "$confservername >> /etc/hosts

## Create fabric.py 
cp fabfile.org.py fabfile.py.bak
sed -i "s/#diskprofile#/#diskprofile#\ndiskprofile = \"$diskprofile\"/g" ./fabfile.py.bak

## Fill node profile ##
tf=`mktemp`
sed "s/\(.*\)=\(.*\)/\1 = \"\2\"/" ./conf/nodeProfile.conf > $tf
sed -i "/#nodeProfile#/ r $tf" fabfile.py.bak

cp fabfile.py.bak fabfile.py

## Change HostName
fab changeHostAndRepo -P -H $osdserver

## Add ssh auth
fab push_key -P -H $osdservername

##Clean OriginData
if [[ $nopurge == "false" ]]
then
        loginfo "Begin to PURGE!"
        fab PurgeCeph -P -H $osdservername
fi

## Install ceph rpm
fab InstallCeph -P -H $osdservername

## GatherKeys
ceph-deploy gatherkeys $confservername

scp root@$confservername:/etc/ceph/ceph.conf ./

## Install OSD
fab prepareDisks -P -H $osdservername
if [[ $withtranscode == "true" ]]
then
        loginfo "Begin to deploy OSDs withTranscode!"
        fab DeployOSDsWithTranscode -P -H $osdservername
else
        loginfo "Begin to deploy OSDs !"
        fab DeployOSDs -P -H $osdservername
fi

## Copy CephConf
fab CopyCephConf -P -H $osdservername

## Install Ceph
fab InstallWuzei -P -H $osdservername
fab CheckWuzei -P -H $osdservername



