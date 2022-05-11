#!/bin/bash
A=`cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l`
S=`cat /proc/cpuinfo| grep "cpu cores"| uniq | awk '{print $4}'`
D=`cat /proc/cpuinfo| grep "processor"| wc -l`
F=`cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c`
G=$(($A*$S))
H=$(($D / $S / $A))
K=`free -h |grep "Mem"| awk '{print $2}'`
L=`free -h |grep "Swap"| awk '{print $2}'`
Q=`lsblk | grep "^sd[a-z]" | wc -l`
W=`lsblk | grep "^sd[a-z]"|awk '{printf("(%s %s)" , $1,$4)}'`
E=`dmidecode -t memory|grep "Size" |wc -l`
R=`dmidecode -t memory|grep "Size" |grep -v "No Module Installed" |wc -l`
T=`dmidecode -t memory|grep "Size" |grep -v "No Module Installed"|awk '{print $2,$3}' | uniq`

if [ `grep -c Linux /etc/issue` -ne 0 ];
then 
	J=`cat /etc/issue`
elif [ `grep -c Linux /etc/centos-release` -ne 0 ];
then 
	J=`cat /etc/centos-release`
else 
	echo -e "\033[31;5m 脚本没有查看当前系统可用的变量 \033[0m "
fi

echo -e "\033[36m
   ++++++++++++++++++系统性能详情++++++++++++++++++
VERSION:
  当前的系统发行版本为:${J}   			   
CPU:
  当前系统CPU型号为:${F}       			  
  有${A}个物理cpu              			  
  其中每个物理CPU的核数为:${S} 			  
  总核数为:${G}                			  
  每核超线程:${H}              			  
  逻辑CPU总共有${D}个          			  
MEM:
  主板内存插口共有${E}口       			  
  已加载${R}条内存条           			  
  每条内存:${T}                			  
  当前可用内存共有:${K}        			  
  当前可用SWAP共有:${L}        			  
DISK:
  当前系统工有${Q}块磁盘       			  
  每块磁盘容量:${W}            			  
  \n ++++++++++++++++++++++++++++++++++++++++++++++++ \033[0m"
