#!/bin/bash
# Author: liuxioaya
# WriteTime: 2021-12-23

####### System Version #########
echo "$HOSTNAME system_version: `cat /etc/centos-release`"

####### Kernel Version #########
echo "$HOSTNAME kernel_version: `uname -r`"

####### NTP Status #########
NTP_status=`chronyc -n -4 sources | awk '/\*/ {print $2}'`
if [ -n $NTP_status ]; then
    echo "$HOSTNAME NTP_status: $NTP_status"
else
    echo "$HOSTNAME NTP_status: None"
fi

####### CPU Usage Status #########
echo "$HOSTNAME Cpu_status: `mpstat 1 5 | tail -1 | awk '{printf("%0.2f\n"),100-$12}'`%"

####### MEM Surplus Status #######
echo "$HOSTNAME Mem_status: `free -h | awk '/Mem/ {print $NF}'`"

####### DISK Usage Status #######
Disk_status=`df -h | awk -F' ' '/^\/dev/ {print $5,$NF}' | grep -E "^[8-9][0-9]%" | xargs -n 100`
if [ -z "$Disk_status" ]; then
    echo "$HOSTNAME Disk_use_status: normal"
else
    echo "$HOSTNAME Disk_use_status: $Disk_status"
fi

####### TCP Connect Status #######
echo "$HOSTNAME Tcp_status: `ss -s|awk '/^TCP:/ {print $2}'`"

####### NF Conntrack Status #########
echo "$HOSTNAME nf_conntrack_num: `cat /proc/sys/net/netfilter/nf_conntrack_count`"

####### Load Average ###########
echo "$HOSTNAME Load_average: `uptime |awk '{print $(NF-2) $(NF-1) $NF}'`"

####### System Progress Numbers #########
echo "$HOSTNAME Progress_numbers: `ps -ef|wc -l`"

if $(ipmitool sel list &>/dev/null) ;then
    #######  传感器 Status #########
    Sdr_status=`ipmitool sdr list | grep -v "[Not|no] [reading|Readable]"  | grep -v ok`
    if [ -z "$Sdr_status" ]; then
        echo "$HOSTNAME sdr_status: $Sdr_status" | xargs -n 1000
    else
        echo "$HOSTNAME sdr_status: normal"
    fi

    #######  SEL log Status #########
    Year=`date +%Y`
    Event_echo=`ipmitool sel list | grep $Year | grep -v "log area reset/cleared"  | xargs -n 10000`
    if [ -z "$Event_echo" ]; then
        echo "$HOSTNAME System_Event_log : normal"
    else
        echo "$HOSTNAME System_Event_log : $Event_echo"
    fi
else 
    echo "$HOSTNAME status : Does Not Support ipmi management"
fi
