# Ceph-Seed

![](ceph-seed.jpg)


Ceph-Seed 包含以下两点功能：

1. 快速部署Ceph集群
2. 快速扩展OSD

## 注意事项
- 提前配置ceph.repo，安装fabric和ceph-deploy。
**ceph.repo**:
```
[ceph]
gpgcheck=0
enabled=1
name=Letv ceph
priority=2
baseurl=http://s3s.lecloud.com/el7/ceph/update/
```

- 之后执行：
```
yum install fabric ceph-deploy -y
git pull git@git.letv.cn:cuixiaotian/ceph-seed.git
```
- 修改当前用户目录下 .cephdeploy.conf 文件
```
[ceph]
name=Letv ceph
#baseurl=http://s3s.lecloud.com/ceph/el6/update
baseurl=http://s3s.lecloud.com/el7/ceph/update
enabled=1
default = True
priority=1
```

## 利用 Ceph-Seed 快速部署Ceph集群
1. 填写conf目录下的area，mroom和env.password。 `注意：等于号之间不要有空格，文件尾部不要有空行`
2. 填写conf目录下的monhosts，osdhosts。 `注意：一行一个IP，文件尾部不要有空行`
3. 执行：
```
sh deploy.sh [-D|--diskprofile] [raid0|noraid] [-N|--no-purge] [-W|--withtranscode]
```

### 参数说明
- -D|--diskprofile	
	- `必填参数`。如果磁盘做了RAID0，则参数为raid0;否则参数为noraid，磁盘会去做lvm。
- -N|--no-purge 	
	- 如果是干净环境，加上此参数，可不做purge data的操作
- -W|--withtranscode	
	- 如果需要腾出一块硬盘用于部署转码，加上此参数。（此参数不会去mount /dev/sdb 或 /dev/vg/lv1）


## 利用 Ceph-Seed 快速扩展OSD
1. 填写conf目录下的area，mroom和env.password。 `注意：等于号之间不要有空格，文件尾部不要有空行`
2. 执行:
```
sh expend-osd.sh [-c|--confserver] CONFSERVER [-s|--osdserver] OSDSERVER [-D|--diskprofile] [raid0|noraid] [-N|--no-purge] [-W|--withtrancode] [-H|--hostname MONHOSTNAME]
```

### 参数说明
- -c|--confserver CONFSERVER
	- `必填参数`。已有集群monitor服务器的ip。
- -s|--osdserver OSDSERVER
	- `必填参数`。要安装osd服务器的ip。
- -D|--diskprofile [raid0|noraid]
	- `必填参数`。如果磁盘做了RAID0，则参数为raid0;否则参数为noraid，磁盘会去做lvm。
- -N|--no-purge         
	- 如果是干净环境，加上此参数，可不做purge data的操作
- -W|--withtranscode    
	- 如果需要腾出一块硬盘用于部署转码，加上此参数。（此参数不会去mount /dev/sdb 或 /dev/vg/lv1）
- -H|--hostname MONHOSTNAME
	- 如果已有集群monitor服务器另有hostname，需添加此参数


