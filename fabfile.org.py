from fabric.api import *
from fabric.contrib.files import append
import time
import os

#diskprofile#

#nodeProfile#

#monhostnames#

#osdhostnames#

def push_key(key_file='/root/.ssh/id_rsa.pub'):
    key_text = read_key_file(key_file)
    run('chattr -i /root/.ssh/authorized_keys')
    append('/root/.ssh/authorized_keys', key_text);

def read_key_file(key_file):
    key_file = os.path.expanduser(key_file)
    if not key_file.endswith('pub'):
        raise RuntimeWarning('Trying to push non-public part of key pair')
    with open(key_file) as f:
        return f.read()

def tempInstall():
    run('yum -y install ceph ceph-radosgw')

def tempOS7handler():
    run('rm /etc/yum.repos.d/*')
    put('./deployFile/CentOS-Base.repo','/etc/yum.repos.d/CentOS-Base.repo')
    put('./deployFile/resolv.conf','/etc/resolv.conf')

def changeHostname(area,mroom,storage):
    put('./deployFile/changeNetwork.sh','/tmp/changeNetwork.sh')
    run('chmod +x /tmp/changeNetwork.sh')
    run('/tmp/changeNetwork.sh %s %s %s' % (area, mroom, storage))

def updateRepoAddress():
    put("./deployFile/ceph.repo","/etc/yum.repos.d/ceph.repo")

def testecho():
    run('rpm -qa|grep redhat-lsb-core || yum install redhat-lsb-core -y')
    run('echo hello')

def changeHostAndRepo():
    ##Change Hostname
    changeHostname(area,mroom,storage)
    updateRepoAddress()

def PurgeCeph():
    local('ceph-deploy purge %s' % env.host)
    local('ceph-deploy purgedata %s' % env.host)
    run('yum remove ceph ceph-common ceph-devel librados2 libcephfs1 python-ceph librbd1 ceph-test  libcephfs_jni1 libcephfs_jni1 libradosstriper1  librbd1 ceph-radosgw  ceph-libs-compat cephfs-java  libcephfs1 rbd-fuse rbd-fuse rest-bench -y')

def InstallCeph():
    local('ceph-deploy install %s' % env.host)
    #run('yum install -y ceph striprados')

def DeployOSDsWithTranscode():
    if diskprofile == "raid0":    
        local('ceph-deploy osd create --zap-disk %s:/dev/sdc %s:/dev/sdd %s:/dev/sde %s:/dev/sdf %s:/dev/sdg' % (env.host,env.host,env.host,env.host,env.host))
    else:
        local('ceph-deploy osd create --no-partition %s:/dev/vg/lv2 %s:/dev/vg/lv3 %s:/dev/vg/lv4 %s:/dev/vg/lv5 %s:/dev/vg/lv6' % (env.host,env.host,env.host,env.host,env.host))
        local('ceph-deploy osd activate %s:/dev/vg/lv2 %s:/dev/vg/lv3 %s:/dev/vg/lv4 %s:/dev/vg/lv5 %s:/dev/vg/lv6' % (env.host,env.host,env.host,env.host,env.host))

def DeployOSDs():
    if diskprofile == "raid0":
        local('ceph-deploy osd create --zap-disk %s:/dev/sdb %s:/dev/sdc %s:/dev/sdd %s:/dev/sde %s:/dev/sdf %s:/dev/sdg' % (env.host,env.host,env.host,env.host,env.host,env.host))
    else:
        local('ceph-deploy osd create --no-partition %s:/dev/vg/lv1 %s:/dev/vg/lv2 %s:/dev/vg/lv3 %s:/dev/vg/lv4 %s:/dev/vg/lv5 %s:/dev/vg/lv6' % (env.host,env.host,env.host,env.host,env.host,env.host))
        local('ceph-deploy osd activate %s:/dev/vg/lv1 %s:/dev/vg/lv2 %s:/dev/vg/lv3 %s:/dev/vg/lv4 %s:/dev/vg/lv5 %s:/dev/vg/lv6' % (env.host,env.host,env.host,env.host,env.host,env.host))

def prepareDisks():
    if diskprofile == "raid0":
        run('umount /dev/sd{b,b1,c,c1,d,d1,e,e1,f,f1,g,g1}')
    elif diskprofile == "noraid":
        run('yum install -y lvm2')
        run('umount /dev/sd{b,c,d,e,f,g,h,i,j,k,l,m}')
        run('pvcreate /dev/sd{b,c,d,e,f,g,h,i,j,k,l,m}')
        run('vgcreate vg /dev/sd{b,c,d,e,f,g,h,i,j,k,l,m}')
        run('lvcreate -l200%PVS -n lv1 vg /dev/sdb /dev/sdc')
        run('lvcreate -l200%PVS -n lv2 vg /dev/sdd /dev/sde')
        run('lvcreate -l200%PVS -n lv3 vg /dev/sdf /dev/sdg')
        run('lvcreate -l200%PVS -n lv4 vg /dev/sdh /dev/sdi')
        run('lvcreate -l200%PVS -n lv5 vg /dev/sdj /dev/sdk')
        run('lvcreate -l200%PVS -n lv6 vg /dev/sdl /dev/sdm')
        run('/sbin/mkfs.xfs -i size=2048 -f /dev/vg/lv1')
        run('/sbin/mkfs.xfs -i size=2048 -f /dev/vg/lv2')
        run('/sbin/mkfs.xfs -i size=2048 -f /dev/vg/lv3')
        run('/sbin/mkfs.xfs -i size=2048 -f /dev/vg/lv4')
        run('/sbin/mkfs.xfs -i size=2048 -f /dev/vg/lv5')
        run('/sbin/mkfs.xfs -i size=2048 -f /dev/vg/lv6')

def CopyCephConf():
    put('./ceph.client.admin.keyring','/etc/ceph/ceph.client.admin.keyring')

def InstallWuzei():
    run('yum install wuzei -y --disablerepo=* --enablerepo=wuzei')
    run(r'''sed -i s/\\"ListenPort\\":3000/\\"ListenPort\\":8080/ /etc/wuzei/wuzei.json''')
    run('/etc/init.d/wuzei start')

def RestartRW():
    run('/etc/init.d/wuzei restart')
    run('/letv/resin/bin/resin.sh restart')

def CheckWuzei():
    run('curl http://127.0.0.1:8080/whoareyou')
