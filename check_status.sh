#! /bin/bash
# Author        :liuxiaoya
# Write Time    :2021-12-23

# variable

node_num=$(ansible -i /usr/share/kolla/ansible/inventory/consul_io.py all --list | grep node | wc -l )
declare -a LOG=(${0##*/}.log)


# function 

function log(){
        for i in ${LOG[@]} ;do
                echo -e "\033[35m [ $(date +"%F %T") ] $@ \033[0m" >>${i}
                echo -e "\033[35m [ $(date +"%F %T") ] $@ \033[0m"
        done
}

function run(){
        if [[ -n ${1} ]] && [[ -n ${4} ]];then
                if [ ${1} ${2} ${3} ];then
                        log "\033[32;1m ${4} 服务正常 \033[0m"
                else
                        log "\033[31;1m ${4} 服务异常 \033[0m"
                fi
        else
                log "\033[31;1m ${@} 服务异常 \033[0m"

        fi
}

function node_check(){
        log '\033[36;1m ********* Host check *********'
        log '\033[33;1m ###### Host ping ######'
        ansible all -i /usr/share/kolla/ansible/inventory/consul_io.py -m ping | awk '/=> {/ {print $1,$3}' &>>${LOG}
        ansible all -i /usr/share/kolla/ansible/inventory/consul_io.py -m script -a"./node_check.sh"  | egrep -v 'stdout' >node_status.txt
        declare -a arr=(system_version kernel_version NTP_status Cpu_status Mem_status Disk_use_status Tcp_status nf_conntrack_num Load_average Progress_numbers sdr_status System_Event_Log)
        for i in ${arr[@]} ;do 
                while read line ;do 
                        log "\033[33;1m ${line}"| grep ${i}
                done <node_status.txt
        done
        rm -rf node_status.txt
}

function CEPH(){
        log '********* 开始检查ceph集群状态 ********'
        log '###### Ceph Cluster Status ######'
        ceph health detail

        log "\033[33;1m ceph总容量为:$(ceph df | awk '/TOTAL/ {print $2,$3}'),已使用:$(ceph df | awk '/TOTAL/ {printf"%s%%\n",$NF}')"

        log '###### Ceph Mon Status ######'
        run $(ceph mon stat |awk '{print $2}') -eq 3 cphe_mon

        log '###### Ceph OSD Status ######'
        ceph_osd="`ceph osd tree|grep down|awk '{print $4}'`"
        if [[ "$ceph_osd" == "" ]];then
                log "Ceph OSD Status is OK"
        else
                log "$ceph_osd is DOWN!!!!"
        fi

}



function ostack(){
        log '\033[36;1m ********** 开始检查openstack组件 ********* \033[0m'
        log '###### keystone 服务状态######'
        run $(nomad status keystone-service|awk '/^keystone/ {print $4}') -eq $(grep count  /etc/kolla/nomad/keystone-service.hcl | awk '{print $3}') keystone
        
        log '###### Nova Status ######'
        run $(nomad status nova-controllers|awk '/^nova-api/ {print $4}') -eq $(grep -hA2 'nova-api' /etc/kolla/nomad/nova-controllers.hcl | awk '/count/ {print $3}') nova_nova-api
        declare -a nvarr=(nova-consoleauth nova-scheduler nova-conductor)
        for j in ${nvarr[@]} ;do 
                run $(nova service-list | grep ${j} | grep up | wc -l) -eq $(grep -hA2 'nova-api' /etc/kolla/nomad/nova-*.hcl | awk '/count/ {print $3}') ${j}
        done
        run $(nova service-list |grep nova-compute|grep up|wc -l) -eq ${node_num} nova-compute

        log '###### Neutron 服务状态 ######'
        run $(nomad status neutron-server | awk '/^neutron-server/ {print $4}') -eq $(grep -hA2 'neutron-server' /etc/kolla/nomad/neutron-server.hcl | awk '/count/ {print $3}' ) neutron-server
        run $(nomad status neutron-agents | awk '/^neutron-dhcp/ {print $4}') -eq $(grep -hA2 'neutron-dhcp' /etc/kolla/nomad/neutron-agents.hcl | awk '/count/ {print $3}' ) neutron-dhcp
        declare -a neuarr=(vSwitch L3 Metadata)
        for j in ${neuarr[@]} ;do
                run $(neutron agent-list |grep -i "${j}"|grep ":-)"|wc -l) -eq ${node_num} ${j}-agent
        done
        
        log '###### Glance 服务状态 ######'
        declare -a glcarr=(glance-api glance-registry)
        for j in ${glcarr[@]} ;do
                run $(nomad status glance-service |awk  '/^'${j}'/ {print $4}') -eq $(grep -hA2 "${j}" /etc/kolla/nomad/glance-service.hcl | awk '/count/ {print $3}') ${j}
        done

        log '###### Cinder 服务状态 ######'
        declare -a cdrarr=(cinder-api cinder-scheduler)
        for j in ${cdrarr[@]} ;do
                run $(nomad status cinder-service |awk  '/^'${j}'/ {print $4}') -eq $(grep -hA2 "${j}" /etc/kolla/nomad/cinder-*.hcl | awk '/count/ {print $3}') ${j}
        done
        run $(nomad status cinder-volume|awk '/^cinder-volume/ {print $4}') -eq $(grep -hA2 "cinder-volume" /etc/kolla/nomad/cinder-*.hcl | awk '/count/ {print $3}') cinder-volume

}

function ostack-son(){
        log '\033[36;1m ********* 开始检查rabbitmq状态 *********'
        if [ ${node_num} -ge 10 ];then 
                declare -a rbqarr=(rabbitmq-nova rabbitmq-cinder rabbitmq-common rabbitmq-neutron)
        else
                declare -a rbqarr=(rabbitmq-nova)
        fi
        for j in ${rbqarr[@]} ;do
                run $(nomad status rabbitmq-service |awk  '/^'${j}'/ {print $4}') -eq $(grep -hA2 "${j}" /etc/kolla/nomad/rabbitmq-service.hcl | awk '/count/ {print $3}') ${j}
        done
        for j in ${rbqarr[@]} ;do
                local ${j#*-}=$(ssh ${j}.service.consul docker ps 2>/dev/null|awk '/'${j}'/ {print $1}' | xargs -i ssh ${j}.service.consul docker exec {} bash rabbitmqctl list_queues 2>/dev/null |grep -Ev "0|List|versioned"|head -1|awk '{print $1}')
                log "###### ${j#*-} rabbitmq堆积情况 ######"
                # eval run ${j#*-} -eq 0 status-${j#*-}
                if [[ -n "$(eval echo '$'${j#*-})" ]];then
                        log "\033[31;1m ${j#*-} rabbitmq 队列异常"
                else
                        log "\033[32;1m ${j#*-} 队列正常"
                fi
        done

        log '###### consul 节点的状态######'
        run $(consul members|grep node|grep alive|wc -l) -eq ${node_num} consul

        log '\033[36;1m ********* 开始检查mysql状态 ********* '
        mnode=$(consul-cli kv read galera_master) ;run $(ssh ${mnode} sh /usr/bin/clustercheck 2>/dev/null |tail -1|sed s/[[:space:]]//g) == 'Galeraclusternodeissynced.' MYSQL
        log " \033[33;1m MYSQL 的数据量为:$(ssh ${mnode} du -sh /var/lib/mysql/ 2>/dev/null |awk '{print $1}')"
        mpass=$(consul-cli kv read settings/cluster/database_password) ;log "\033[33;1m MySQL 数据库连接数为:$(ssh ${mnode} mysqladmin -uroot -p${mpass} status 2>/dev/null |awk '{print $4}')"
        
        log '\033[36;1m ********* 开始检查监控组件状态 ********* '
        declare -a monitrarr=(influxdb memcached telegraf)
        for j in ${monitrarr[@]} ;do
                run $(nomad status ${j} |awk  '/^'${j}'/ {print $4}') -eq $(grep -hA2 "${j}" /etc/kolla/nomad/${j}*.hcl | awk '/count/ {print $3}') ${j}
                if [[ ${j} == influxdb ]];then
                       influxdb_node=$(nomad node-status | grep -E $(nomad status influxdb |grep ' influxdb-relay ' | awk -v ORS='|' '/running/ {print $3}' | sed 's/|$//') |awk '{print $3}')
                       log "\033[33;1m influxdb 数据量为:$(ssh ${influxdb_node}  du -sh /var/lib/influxdb 2>/dev/null|awk '{print $1}') "
                fi
        done
}

function saas(){
        ha_my_ip=$(awk -F: '/cloud_url/ {print $2}'  /etc/awstack.conf | sed 's#//##')
        run $(mysql -h${ha_my_ip} -uroot -pCloudOS_2017 -e"show status like 'wsrep%'" 2>/dev/null | awk '/wsrep_cluster_size/ {print $2}') -eq 3 saas_mysql_cluster
        log "\033[33;1m 云管 mysql 的数据量为:$(sshpass -p CloudOS_2017 ssh admin@${ha_my_ip} -p 65522 2>/dev/null sudo  du -sh /var/lib/mysql/|awk '{print $1}') "
        log "\033[33;1m 云管 MySQL 数据库连接数为:$(mysqladmin -h${ha_my_ip} -uroot -pCloudOS_2017 status 2>/dev/null |awk '{print $4}') "
}

# echo '###### Nomad task状态 ######'
# nomad_status=`nomad status |grep -Ev "running|mysqlbackup|ceph-osd-deep-scrub|keystone-token-cleanup"|wc -l`
# if [[ $nomad_status -eq 1 ]];then
# 	echo "Nomad task 正常"
# else
# 	echo "Nomad task 异常"
# fi
function main(){
        log "\033[36;1m ********* 开始进行云平台巡检 *********" ;source /etc/kolla/openrc
        if [[ $(awk '/^code/ {print $3}'  /etc/awstack.conf) != FFFFF ]];then
                log '\033[33;1m 当前平台为高可用云管架构开始检查云管状态'
                saas
        else
                log '\033[33;1m 当前平台非高可用云管架构跳过云管检查'
        fi
        node_check
        CEPH
        ostack
        ostack-son
        log "\033[36;1m ********* 云平台巡检结束 *********" 
}
main