* **{check_status.sh,node_check.sh}配合使用,负责检查企业版云平台(大规模部署在控制节点上执行)底层的环境及使用,执行check_status.sh即可**


* **{exceph_set.sh,exceph.sh}配合使用,作用于企业版底层,分布式导出平台所有的虚机,执行exceph_set.sh即可**

* **{update_yum_source_guonei.sh,update_yum_source_guowai.sh}两个脚本作用于同步国内外的源.**

* **{create-hasaas.sh},用于快速创建高可用云管,执行后会在同一个节点上创建三台高可用云管的虚机,需要根据实际情况修改脚本内容**

* **{test-4CMDN.sh},用于服务器四项功能测试,集成到<centos7.6-min-liu>虚机里面,若需单独使用,需要将{unixbench,stream}安装到/root/test/目录下**

