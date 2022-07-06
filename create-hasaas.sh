#!/bin/bash
# Auther : 			liuxiaoya
# Writing Time :	2021-07-29 15:57:57
# Remaek : 			
# 1,使用此脚本前你需要将高可用运管的配置目录放到变量DIR所指定的目录下面并改名为"awstack-deploy",
# 2,在数组IP里面添加三台高可用运管的ip地址并修改对应的掩码和网关地址,否则脚本将会直接退出.
# 3,需提前做好网桥,网桥名字已具体的/opt/awstack-deploy/VMs/saas.xml文件为准
# 4.qcow2镜像需要放在${VMDIR}变量定义的目录下面

# variable
DIR='/opt/awstack-deploy/'
VMDIR="${DIR}VMs/"
declare -a IP=(192.168.94.101 192.168.94.11 192.168.94.12 192.168.94.13)
MASK='255.255.255.0'
GTY='192.168.94.254'

SKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAAgQUti4k4e7x4n1AzuLCcvTAQ9g7ohgdvDo9tOLQLLFZiF9IeIZl/rHrZiYRpE2V1RissC2IRMLPYMADXqwPjGnnyKJ/X/o/v8RQw1uom0/O4nDwf1pUgqmDsJ4+PfgSrHRyG2REzMbMyp0A1bpFZrw45yzsa00a+eyZzWLFgB7Cv2Q== liuxiaoya'

# function
function log(){
	echo -e "\033[35m [ $(date +"%Y-%m-%d %H:%M:%S") ] ${@} \033[0m"
}

function run(){
	if [ $? == 0 ];then
		log "\033[32;1m ${@} successfully \033[0m"
	else
		log "\033[31;1m ${@} failed scripts exit \033[0m"
		exit 1
	fi
}

function TEST(){
	for i in ${DIR} ${VMDIR} ;do
		[ -d ${i} ];run "test whethr ${i}---------"
	done
	for i in ${IP[@]} ;do
		if [ ! ${#IP[@]} == 4 ];then
			log "---------请检查虚机ip地址是否填写正确,脚本退出---------"
			exit 1
		elif [[ ${i} =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-5][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-5][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-5][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-5][0-9]|25[0-5])$ ]];then
			log "---------ip ${i} format true---------"
		else
			log "---------ip ${i} format error,scipt exit---------"
			exit 1
		fi
	done
}

function CRKVM(){
	log "---------start to execute the ${0##*/} script---------"
	if [ -f ~/.ssh/id_rsa.pub ];then
		SKEY="$(cat ~/.ssh/id_rsa.pub)"
	else
		log "---------当前主机不存在密钥对,使用您的私有密钥对---------"
	fi
# 	sed -i -e '/ssh_authorized_keys/{n;d}' -e "/ssh_authorized_keys/a\  - ${SKEY}" ${VMDIR}user-data 
	sed -i "/ssh_authorized_keys/a\- ${SKEY}" ${VMDIR}user-data 
	run " inster keys"

	for i in {1..3};do
		[ -d ${VMDIR}saas${i} ] || mkdir ${VMDIR}saas${i}
		cp ${VMDIR}{meta-data,user-data,saas.xml} ${VMDIR}saas${i}/ 
		IMG=$(ls -t ${VMDIR}awstack-saas*.qcow2| head -1)
		cp ${IMG} ${VMDIR}saas${i}/saas.qcow2
		sed -i -e "s/saas1/saas${i}/g" -e "s/192.168.132.71/${IP[${i}]}/g" -e "s/255.255.240.0/${MASK}/g" -e "s/192.168.128.1/${GTY}/g" ${VMDIR}saas${i}/meta-data
		sed -i -e "s/saas1/saas${i}/g" -e "s#/home/saas/saas${i}/#${VMDIR}saas${i}/#g" ${VMDIR}saas${i}/saas.xml
		sed -i -e "s/172.16.9.10${i}/${IP[${i}]}/g" ${DIR}saasha_deploy/{group_vars,inventory}/all
		genisoimage -output ${VMDIR}saas${i}/saas_ci_iso -volid cidata -joliet -rock ${VMDIR}saas${i}/user-data ${VMDIR}saas${i}/meta-data
		virsh define ${VMDIR}saas${i}/saas.xml ; virsh start saas${i}
		run "Virtual machine saas${i} start -------" 
	done
	log "---------wait 120 seconds---------"
	sleep 120
	log "---------test virtual live---------"
	for i in {1..3};do
		ping -w5 -c1 ${IP[${i}]} -q &>/dev/null 
		run "${IP[${i}]} test ping ---"
	done
	log "---------KVM virtual create sucessfully---------"
}

function ASPLK(){
	log "---------start ansible-playbook---------"
	sed -i "s/172.16.9.100/${IP[0]}/" ${DIR}saasha_deploy/group_vars/all
	sed -i '/StrictHostKeyChecking ask/a\StrictHostKeyChecking no' /etc/ssh/ssh_config
	if [ -f ~/.ssh/id_rsa.pub ];then
		ansible-playbook -i ${DIR}saasha_deploy/inventory/all ${DIR}saasha_deploy/run.yml
	elif [ -f ${DIR}aliyun ];then
		ansible-playbook --key-file=${DIR}aliyun -i ${DIR}saasha_deploy/inventory/all ${DIR}saasha_deploy/run.yml
	else
		log "---------未在${DIR}目录下发现私有密钥的私钥,脚本退出,请手动执行ansible-playbook剧本---------"
	fi
}

function main(){
	TEST
	CRKVM
	ASPLK
}
main
log "---------end script exit---------"
exit 1
