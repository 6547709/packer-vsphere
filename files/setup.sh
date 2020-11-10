#!/bin/bash

# Bootstrap script

set -euo pipefail

if [ -e /usr/local/customization/ran_customization ]; then
    exit
else
    DEBUG_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.debug")
    DEBUG=$(echo "${DEBUG_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    LOG_FILE=/var/log/bootstrap.log
    if [ ${DEBUG} == "True" ]; then
        LOG_FILE=/var/log/centos-customization-debug.log
        set -x
        exec 2> ${LOG_FILE}
        echo
        echo "### WARNING -- DEBUG LOG CONTAINS ALL EXECUTED COMMANDS WHICH INCLUDES CREDENTIALS -- WARNING ###"
        echo "### WARNING --             PLEASE REMOVE CREDENTIALS BEFORE SHARING LOG            -- WARNING ###"
        echo
    fi

    HOSTNAME_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.hostname")
    IP_ADDRESS_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ipaddress")
    NETMASK_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.netmask")
    GATEWAY_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.gateway")
    DNS_SERVER_1_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.dns1")
    DNS_SERVER_2_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.dns2")
    DNS_DOMAIN_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.domain")
    ADD_DISK1_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.adddisk1")
    DATA_DIR_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.datadir")
    NTP_SERVER_1_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ntp1")
    NTP_SERVER_2_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.ntp2")
    ROOT_PASSWORD_PROPERTY=$(vmtoolsd --cmd "info-get guestinfo.ovfEnv" | grep "guestinfo.root_password")

    ##################################
    ### No User Input, assume DHCP ###
    ##################################
    if [ -z "${IP_ADDRESS_PROPERTY}" ]; then
        cat > /etc/sysconfig/network-scripts/ifcfg-eth0  << __CUSTOMIZE_CENTOS__
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth0
DEVICE=eth0
ONBOOT=yes
__CUSTOMIZE_CENTOS__
    #########################
    ### Static IP Address ###
    #########################
    else
        HOSTNAME=$(echo "${HOSTNAME_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        IP_ADDRESS=$(echo "${IP_ADDRESS_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        NETMASK=$(echo "${NETMASK_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        GATEWAY=$(echo "${GATEWAY_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        DNS_SERVER_1=$(echo "${DNS_SERVER_1_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        DNS_SERVER_2=$(echo "${DNS_SERVER_2_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
        DNS_DOMAIN=$(echo "${DNS_DOMAIN_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')

        echo -e "\e[92mConfiguring Static IP Address ..." > /dev/console
        cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << __CUSTOMIZE_CENTOS__
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=no
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=${IP_ADDRESS}
NETMASK=${NETMASK}
GATEWAY=${GATEWAY}
DNS1=${DNS_SERVER_1}
DNS2=${DNS_SERVER_2}
DOMAIN=${DNS_DOMAIN}
__CUSTOMIZE_CENTOS__

    echo -e "\e[92mConfiguring hostname ..." > /dev/console
    hostnamectl set-hostname ${HOSTNAME}
    echo "${IP_ADDRESS} ${HOSTNAME}" >> /etc/hosts
    echo -e "\e[92mRestarting Network ..." > /dev/console
    systemctl restart NetworkManager
    fi

    echo -e "\e[92mConfiguring root password ..." > /dev/console
    ROOT_PASSWORD=$(echo "${ROOT_PASSWORD_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    echo "root:${ROOT_PASSWORD}" | /usr/sbin/chpasswd
    # Mount Data Disk
    ADD_DISK=$(echo "${ADD_DISK1_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    DATA_DIR=$(echo "${DATA_DIR_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    partprobe /dev/sdb
    if [ ${ADD_DISK} = "True" ]; then
      echo -e "o\nn\np\n1\n\n\nw" | fdisk /dev/sdb
      sleep 5
      pvcreate /dev/sdb1 -y
      vgcreate data_vg /dev/sdb1  -y
      lvcreate -l 100%VG -n data_lv data_vg  -y
      mkfs.xfs /dev/data_vg/data_lv
      mkdir -p ${DATA_DIR}
      mount /dev/mapper/data_vg-data_lv ${DATA_DIR}
      echo ""/dev/mapper/data_vg-data_lv"     ${DATA_DIR}         xfs defaults 0 0" >> /etc/fstab    
    fi
    # Config NTP Server
    NTP1=$(echo "${NTP_SERVER_1_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    NTP2=$(echo "${NTP_SERVER_2_PROPERTY}" | awk -F 'oe:value="' '{print $2}' | awk -F '"' '{print $1}')
    if [ "${NTP1}" != "" ]; then
       sed -i '/^server /d' /etc/chrony.conf
       echo "server ${NTP1}" >> /etc/chrony.conf
       if [ "${NTP2}" != "" ]; then
          echo "server ${NTP2}" >> /etc/chrony.conf
       fi   
       systemctl restart chronyd
    else
       sed -i '/^server /d' /etc/chrony.conf
       echo "server ntp.aliyun.com" >> /etc/chrony.conf
       echo "server ntp1.aliyun.com" >> /etc/chrony.conf
    fi
    # Clean kickstart file
    rm -rf /root/*.cfg /root/*.log 
    # Ensure we don't run customization again
    mkdir -p /usr/local/customization
    touch /usr/local/customization/ran_customization
fi

