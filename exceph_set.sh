#!/bin/bash
# Auther    :liuxiaoya
# Writing Time  :2021-07-19 17:20:12


# variables
SNAME="${0##*/}"
LOG="/tmp/${SNAME%.*}.log"
RDOC="/tmp/${SNAME%.*}.txt"
OPENRC='/etc/kolla/openrc'
if [ -z ${1} ];then
        read -e -t 60 -p "input ceph_pool_name(press enter default：volumes）:" line
fi
line=${1}
CN=${line:="volumes"}
AN_FILE='/usr/share/kolla/ansible/inventory/consul_io.py'
declare -a AN_HOST=($(ansible all -i ${AN_FILE} -m ping | grep 'SUCCESS' | awk '{print $1}' ))

# function
function log(){
        for I in ${LOG[@]} ;do
                echo -e "\033[35m [$(date +"%Y-%m-%d %H:%M:%S")] $@ \033[0m " &>>${I}
        done
}



# Code

function set_file(){
        log "start scripts ------------------------------------------------------"
        source ${OPENRC}
        nova list --all-t | awk -F '|' 'NR>2{print $2,$3}' >>${RDOC}
        split -l $(($(wc -l ${RDOC}| awk '{print $1}')/${#AN_HOST[@]}+1)) ${RDOC} -d split_file
        declare -a SFILE=($(ls split_file*))
        for i in $(seq 0 ${#AN_HOST[@]}) ;do
                if [[ $(hostname) != ${AN_HOST[${i}]} ]] ;then
                        scp ./${SFILE[${i}]} ${AN_HOST[${i}]}:/tmp/ 
                        rm -rf ${SFILE[${i}]}
                fi
        done
        rm -rf ${RDOC}
        log "分配任务完成开始在所有可以ping通节点执行导出脚本,具体日志请查看各个节点的/tmp/exceph.log-----------------------"
        ansible all -i ${AN_FILE} -f ${#AN_HOST[@]} -m script -a"./exceph.sh ${CN}" &>>${LOG} &
}

function main(){
        set_file  
}
main
