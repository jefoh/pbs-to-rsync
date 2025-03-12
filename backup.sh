#!/bin/bash
timestamp=$(date "+%Y-%m-%d")

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>${timestamp}.log 2>&1

if [[ "$#" -ne 1 ]];
then
    echo "Usage: $0 <datastore>"
    exit 1
fi

runningtasks=$(proxmox-backup-manager task list)

# Wait for running tasks to complete before starting
while [ ! -z "$runningtasks" ];
do
    sleep 5m
    runningtasks=$(proxmox-backup-manager task list)
done
