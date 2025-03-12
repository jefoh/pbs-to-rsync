#!/bin/bash
rhost=""
pkeypath=""
ruser=""
rdir=""
ldir=$(proxmox-backup-manager datastore list | grep $1 | awk '{print $4}')

timestamp=$(date "+%Y-%m-%d")

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 <datastore>"
    exit 1
elif [[ ! -z "$ldir" ]]; then
    echo "Datastore $1 does not exist. Check datastore name and try again."
    exit 1
fi

# Wait for running tasks to complete before starting
runningtasks=$(proxmox-backup-manager task list)
while [ ! -z "$runningtasks" ]; do
    echo "Other tasks are running. Waiting..."
    sleep 5m
    runningtasks=$(proxmox-backup-manager task list)
done

# Make datastore read-only to prevent changes during sync
proxmox-backup-manager datastore update $1 --maintenance-mode read-only
if [[ "$?" -ne 0 ]]; then
    echo "Failed to put datastore in maintenance mode. Backup cannot continue. Aborting..."
    exit 1
fi

ecode=0
/usr/bin/rsync -av --progress -H --delete -e ssh ${ruser}@${rhost}:${ldir} ${rdir} 
if [[ "$?" -ne 0 ]]; then
    echo "There were errors syncing files. Please review logs."
    ecode=2
fi

proxmox-backup-manager datastore update $1 --delete maintenance-mode
if [[ "$?" -ne 0 ]]; then
    echo "Could not turn off maintenance mode on datastore. Check PBS UI."
    ecode=3
fi

exit $ecode