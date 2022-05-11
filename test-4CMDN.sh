#!/bin/bash

# var
DIR='/root/test/'
LOG=${DIR}${0##*/}.log
JG='------'
BS=(4k 256k)
RW=(read write randread randwrite readwrite randrw)
declare -a SIZE=(1G 10G)

# function
function log(){
    for i in ${LOG[@]} ;do
        echo -e "\033[35m [ $(date +"%F %T") ] $@ \033[0m" >>${i}
        echo -e "\033[35m [ $(date +"%F %T") ] $@ \033[0m"
    done
}

function run(){
  if [[ $? == 0 ]];then
    log  "\033[32;1m ${1} successfully \033[0m"
  else
    log "\033[31;1m ${1} failed \033[0m"
  fi
}
    
# CPU
function CPU(){
    local a=$(grep processor /proc/cpuinfo | wc -l)
    sed -ri "s/'maxCopies' => ([2-9]|[0-9]{2,10})/'maxCopies' => ${a}/g" ${DIR}UnixBench/Run 2>/dev/null
    log "${JG}开始cpu测试,测试线程数为当前配置(${a}),耗时较长${JG}"
    cd ${DIR}UnixBench/
    ./Run &>>/tmp/unixbench
    awk '/Benchmarks Index Score|running [0-9]+ parallel/{print }' /tmp/unixbench &>>${LOG}
    run "${JG}cpu测试${JG}"
}

# Memory
function MEM(){
    local b=$(awk '/core id/{a[$0]=$0}END{print length(a)}'  /proc/cpuinfo)
    local a=$(lscpu | awk '/L3 cache:/{sub(/K/,"") ;printf"%.f\n",$3*1024*4.1*'${b}'/8}')
    gcc -O3 -fopenmp -DSTREAM_ARRAY_SIZE=${a} -DNTIMES=10 ${DIR}stream.c -o ${DIR}stream
    log "${JG}编译完成,开始进行mem测试${JG}"
    ${DIR}stream &>>${LOG}
    run "${JG}内存测试${JG}"
}

# Disk
function DISK(){
    local B=$(awk '/processor/{m=$NF}END{print m+1}'  /proc/cpuinfo)
    local A=($(lsblk -b | grep -E 'part'| sort -k4 -rn | awk '/sd|vd|nvme/{if(NR==1){printf"%.f %s\n",$4/1024/1024*.1/'${B}',$7}}'))
    if $(echo ${A[1]} | grep -q '/$') ;then
        [ -d ${A[1]}test ] || mkdir ${A[1]}test ; TDIR="${A[1]}test"
    else
        [ -d ${A[1]}/test ] || mkdir ${A[1]}/test ; TDIR="${A[1]}/test"
    fi
    log "${JG}开始进行io进行测试--使用${B}线程,每块文件为${A[0]}M,预计需要:$[${#BS[@]}*${#RW[@]}]m"
    for k in ${BS[@]} ;do 
        for j in ${RW[@]} ;do
            if [[ ${j} == "randrw" ]] || [[ ${j} == "readwrite" ]] ;then
                # fio -directory=${TDIR} -direct=1 -thread -ioengine=libaio -rwmixread=70 -rw=${j}  -bs=${k} -size=${A[0]}M -numjobs=${B}  -name=${k}_${j} &>>${LOG}
                fio -directory=${TDIR} -direct=1 -thread -ioengine=libaio -rwmixread=70 -rw=${j}  -bs=${k} -runtime=60 -size=${A[0]}M -numjobs=${B} -name=${k} | grep -A4 'Run status group' | grep -v '^$' &>>${LOG}
                run "${JG}${k}--${j}--使用${B}线程进行测试"
            else
                # fio -directory=${TDIR} -direct=1 -thread -ioengine=libaio -rw=${j}  -bs=${k} -size=${A[0]}M -numjobs=${B}  -name=${k}_${j} &>>${LOG}
                fio -directory=${TDIR} -direct=1 -thread -ioengine=libaio -rw=${j}  -bs=${k} -runtime=60 -size=${A[0]}M -numjobs=${B}  -name=${k} | grep -A4 'Run status group' | grep -v '^$' &>>${LOG}
                run "${JG}${k}--${j}--使用${B}线程进行测试"
            fi
        done
        [ ! -d ${TDIR} ] || rm -rf ${TDIR}/*
    done
}

# Network
function TETIP(){
    # while true ;do
    #     local A=${RANDOM}
    #     if [ ${A} -ge 10000 -a ${A} -le 65535 ] ;then
    #         if ! $(netstat -ntulp | grep -q "${A}") ;then
    #             break
    #         fi
    #     fi
    # done
    for k in ${SIZE[@]} ;do
        if ! $(ping -q -i.01 -w2 -c4 ${IP} &>/dev/null ); then
            log "连通性测试失败请检查${IP}地址及状态是否正确"
            break
        # fi
        # if $(netstat -ntulp | grep -q ${PORT}) ;then
        #     log "${JG}${PORT}被占用,请更换端口号重试${JG}"
        #     break
        else
            log "${JG}server${IP}:${PORT}-${k}-TCP吞吐开始测试"
            iperf3 -c ${IP} -n${k} -p ${PORT} -4 |grep -A3 '\- \- \-' &>>${LOG}
            log "${JG}server${IP}:${PORT}-${k}-UDP吞吐开始测试"
            iperf3 -u -c ${IP} -n${k} -p ${PORT} -4 -b 0 |grep -A3 '\- \- \-' &>>${LOG}
        fi
    done
}

function var(){
    log "本次测试配置为$(awk '/processor/{m=$NF}END{print m+1}'  /proc/cpuinfo)C$(free -h | awk '/Mem:/{print $2}')"
    log "执行脚本前需要修改其中的变量IP,PORT,并确保你已经启动了iperf的server端,修改为server节点的ip地址,用于测试."
    declare -a A=$(ifconfig | awk '/inet /{if($2!="127.0.0.1"){print $2}}'|awk -F. '{printf"%s.%s.%s.%s\n",$1,$2,$3,$4+1}')
    read -t 30 -p "30秒内输入iperf-server端的ip地址,默认(本机ip+1(${A[0]}):" IP
    read -t 10 -p "10秒内输入iperf-server端的端口号,默认(1314):" PORT 
    if [ -z ${IP} ] ;then
        IP=${A[0]}
    fi
    if [ -z ${PORT} ] ;then
        PORT=1314
    fi
}

function main(){
    rm -rf ${LOG}
    var
    MEM
    DISK
    CPU
    TETIP
}

log "${JG}开始执行测试脚本${JG}"
read -t 15 -p "请在15秒钟内输入:all执行四项功能测试,输入:net单独执行网络测试(默认all):" j 
case ${j:=all} in 
    all )
    read -t 60 -p "一分钟内输入想要追加的fio测试块大小,默认4k,256k,输入格式(输入以空格分隔,示例4k 256k):" -a arr1  ;declare -a BS=(${BS[@]} ${arr1[@]})
    main
        ;;
    net )
    var
    TETIP
        ;;
    * )
        echo "输入错误,请重新执行脚本"
        ;;
esac
log "${JG}测试结果请下载${LOG},测试脚本执行结束${JG}"