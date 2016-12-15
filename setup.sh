#!/usr/bin/env bash

echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf

apt install -y software-properties-common
add-apt-repository cloud-archive:newton -y
apt-get update && apt dist-upgrade
apt install -y python-openstackclient
apt install -y mariadb-server python-pymsql
apt install -y keystone
#apt-get install -y mariadb-server python-pymysql git python-pip libffi-dev libssl-dev python-dev
#pip install pytz
