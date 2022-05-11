#!/bin/bash
source /etc/kolla/openrc
declare -a A=($(ls /data/88_vm_bak))
for i in ${A[@]} ;do
    ${i}=$(cinder list | grep ${i} | awk -F'|' 'print{$2 $4}')
    echo ${i}

done

