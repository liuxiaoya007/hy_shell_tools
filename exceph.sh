#!/bin/bash
# Auther    :liuxiaoya
# Writing Time  :2021-07-19 17:20:12


# variables
SNAME="${0##*/}"
LOG="/tmp/${SNAME%.*}.log"
OPENRC='/etc/kolla/openrc'
CN=${1}
DIR='/var/admin/kvm/' ; [ -d ${DIR} ] || mkdir -p ${DIR}
declare -a SF=($(ls /tmp/split_file*))

# function
function log(){
	for I in ${LOG[@]} ;do
		echo -e "\033[35m [$(date +"%Y-%m-%d %H:%M:%S")] $@ \033[0m " &>>${I}
	done
}

function run(){
	if [ $? == 0 ] ;then
		log "\033[32;1m ${@} successfully \033[0m" 
	else 
		log "\033[31;1m ${@} failed continue \033[0m" 
		continue
	fi
}




function export_ceph(){
	log "Start export rbd-------------------------------------------------------"
	source ${OPENRC}
	for g in ${SF[@]} ;do
		for i in $(cat ${g}| awk '{print $1}') ;do
		    declare -a A=($(nova show ${i} | grep volumes | awk -F '"' '{for(i=0;i<NF;i++)if($i ~ /id/){print $(i+2)}}'| grep -Ev '^id$'| tr '\n' ' '))
		    FN=$(awk '/'${i}'/{print $2}' ${g}| awk '!a[$1]++') ;a=1
		    if [ -n "${A[@]}" ];then
		        for j in ${A[@]} ;do
		        	rbd ls ${CN}| grep -q ${j} ;run "quire ${j}"
		            if [ ${a} == 1 ] ;then
		            	qemu-img convert -c -f raw -O qcow2 -p rbd:${CN}/volumes-${j} ${DIR}${FN}.qcow2 &>>${LOG} ; run "${DIR}${FN}.qcow2 rbdID=${j}"
		            else
		            	qemu-img convert -c -f raw -O qcow2 -p rbd:${CN}/volumes-${j} ${DIR}${FN}-data-${a}.qcow2 &>>${LOG} ; run "${DIR}${FN}-data-${a}.qcow2 rbdID=${j}"
		            fi
		            ((a++))
		        done
		    fi
		done
	done
	log "rbd export end-------------------------------------------------------"
	rm -rf ${SF[*]}
	exit 0
}
function main(){
	export_ceph
}
main
