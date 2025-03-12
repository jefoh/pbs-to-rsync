#!/bin/bash

#
# Copyright (c) 2025 jefoh
#
# This software is licensed under the terms of the GNU General Public License v3.0.
# See the LICENSE file for more details.
# 
#
# 
# This is a short simple script made with the intention of 
# syncing a local Proxmox Backup Server datastore to a 
# remote repository. 
#
# The local instance running Proxmox Backup Server must have the following packages installed:
# - proxmox-backup-manager
# - rsync
# - openssh-client
# - jq
# 
# The remote repository location must have the following packages installed:
# - rsync
# - openssh-server
#
config="config.json"

rhost=$(jq -r .remotehost "$config")
ruser=$(jq -r .remoteuser "$config")
rdir=$(jq -r .remotepath "$config")
logpath=$(jq -r .logpath "$config")
datastore=$(jq -r .datastore "$config")

# Get datastore filesystem path
ldir=$(proxmox-backup-manager datastore list | grep "$datastore" | awk '{print $4}')

# Set up logging
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>"${logpath}/$(date "+%Y-%m-%d").log" 2>&1

# Initial config checks
if [[ -z "$ldir" ]]; then
    echo "Datastore $datastore does not exist. Check datastore name and try again. Exiting..."
    exit 1
fi

# Wait for running tasks to complete before starting
runningtasks=$(proxmox-backup-manager task list)
while [ -n "$runningtasks" ]; do
    echo "$(date "+%H:%M:%S"): Other tasks are running. Waiting..."
    sleep 5m
    runningtasks=$(proxmox-backup-manager task list)
done

# Make datastore read-only to prevent changes during sync
echo "$(date "+%H:%M:%S"): Putting datastore $datastore in maintenance mode."
if ! proxmox-backup-manager datastore update "$datastore" --maintenance-mode read-only; then
    echo "$(date "+%H:%M:%S"): Failed to put datastore in maintenance mode. Backup cannot continue. Aborting..."
    exit 1
fi

# Start sync process
ecode=0
echo "$(date "+%H:%M:%S"): Starting rsync to remote server..."
if ! /usr/bin/rsync -av --progress -H --delete -e ssh "${ldir}" "${ruser}"@"${rhost}":"${rdir}"; then
    echo "$(date "+%H:%M:%S"): There were errors syncing files. Please review logs."
    ecode=2
fi

echo "$(date "+%H:%M:%S"): Turning off maintenance mode on datastore $datastore"
if ! proxmox-backup-manager datastore update "$datastore" --delete maintenance-mode; then
    echo "$(date "+%H:%M:%S"): Could not turn off maintenance mode on datastore. Check PBS UI for more information."
    ecode=3
fi

# Cleanup old log files
echo "$(date "+%H:%M:%S"): Cleaning up old log files..."
if ! find "$logpath" -type f -mtime +14 -exec rm -f {} \;; then
    echo "$(date "+%H:%M:%S"): There were errors cleaning up log directory."
    ecode=4
fi

echo "$(date "+%H:%M:%S"): $0 finished with an exit code of $ecode"
exit $ecode