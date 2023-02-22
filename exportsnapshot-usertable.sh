
#!/bin/bash
set -o nounset

display_usage() {
    echo "
Usage:
    $(basename "$0") [--help or -h] <hbase_data_dir>
Description:
    Launches a CDP Azure environment
Arguments:
    hbase_data_dir:                Hbase Storage location of COD
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
  echo "The first script argument must be a directory containing HBase storage file location"; exit
fi

echo "Ensure Storage access key is configured to ADLS blob account :https://docs.cloudera.com/HDPDocuments/HDP2/HDP-2.6.5/bk_cloud-data-access/content/authentication-wasb.html"

if [ ! -d "$1" ]; then
  echo "The first script argument must be a directory containing HBase COD Location"; exit
fi

#take a snapshot and export the snapshot
for ((i=1;i<=10;i++)); do
  snapshotname=snap_ycsbtable$i
  echo "snapshot 'ycsbtable$i', '$snapshotname'" | hbase shell -n
  sleep 10
  hbase org.apache.hadoop.hbase.snapshot.ExportSnapshot -Dsnapshot.export.skip.tmp=true -snapshot $snapshotname -copy-to $1
  sleep 5
  echo $i
done
