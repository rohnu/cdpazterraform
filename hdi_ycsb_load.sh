#!/bin/bash
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <hbase_conf_dir>
Description:
    Launches a CDP Azure environment
Arguments:
    hbase_conf_dir:                Hbase Configuration folder by default /etc/hbase/conf in HDP 2.6.5
    --help or -h:   displays this help"

}

if [[ ( ${1:-x} == "--help") ||  ${1:-x} == "-h" ]]
then
    display_usage
    exit 0
fi


# Check the numbers of arguments
if [  $# -lt 1 ]
then
    echo "Not enough arguments!" >&2
    display_usage
    exit 1
fi

if [  $# -gt 1 ]
then
    echo "Too many arguments!" >&2
    display_usage
    exit 1
fi

if [ ! -d "$1" ]; then
  echo "The first script argument must be a directory containing HBase confguration files"; exit
fi
#Download YCSB to load 10 usertable data for migration
wget https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-hbase12-binding-0.17.0.tar.gz

#extract YCSB
tar -xvf ycsb-hbase12-binding-0.17.0.tar.gz
sleep 5

DIR=ycsb-hbase12-binding-0.17.0
cd $DIR

#Creating 10 ycsbtable1 ......ycsbtable10 and loading 1000 record each table

for ((i=1;i<=10;i++)); do
  echo "create 'ycsbtable$i', 'f'" | hbase shell -n
  sleep 5
  bin/ycsb load hbase12 -P workloads/workloada -cp $1 -p table=ycsbtable$i -p columnfamily=f 2>/dev/null;
  sleep 5
  echo $i
done
