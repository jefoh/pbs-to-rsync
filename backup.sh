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

# Set up logging
logfile="${logpath}/$(date "+%Y-%m-%d").log"
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>"$logfile" 2>&1

# Read config file values
config="$1"
if [[ ! -f "$config" ]]; then
    echo "Configuration file: $config does not exist. Please check spelling and location of specified file." >&3
    exit 1
fi

rhost=$(jq -r .remotehost "$config")
ruser=$(jq -r .remoteuser "$config")
rpath=$(jq -r .remotepath "$config")
logpath=$(jq -r .logpath "$config")
datastore=$(jq -r .datastore "$config")
erecipient=$(jq -r .emailrecipient "$config")

#Creates log entry
log(){
	echo -e "$(date "+%m%d%Y_%H%M%S"): $1"	
}

#Sends an email alert
email(){
	tail -n 5 "$logfile" | mail -s "$1" "$erecipient"
}

# Get datastore filesystem path
ldir=$(proxmox-backup-manager datastore list | grep "$datastore" | awk '{print $4}')

# Initial config checks
if [[ -z "$ldir" ]]; then
    echo "Datastore $datastore does not exist. Check datastore name and try again. Exiting..."
    email "PBS to Rsync Failed on host $(hostname)"
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
log "Putting datastore $datastore in maintenance mode."
if ! proxmox-backup-manager datastore update "$datastore" --maintenance-mode read-only; then
    log "Failed to put datastore in maintenance mode. Backup cannot continue. Aborting..."
    email "PBS to Rsync Failed on host $(hostname)"
    exit 1
fi

# Start sync process
ecode=0
log "Starting rsync to remote server..."
if ! /usr/bin/rsync -av --progress -H --delete -e ssh "${ldir}" "${ruser}"@"${rhost}":"${rpath}"; then
    log "There were errors syncing files. Please review logs."
    ecode=2
fi

log "Turning off maintenance mode on datastore $datastore"
if ! proxmox-backup-manager datastore update "$datastore" --delete maintenance-mode; then
    log "Could not turn off maintenance mode on datastore. Check PBS UI for more information."
    ecode=3
fi

# Cleanup old log files
log "Cleaning up old log files..."
if ! find "$logpath" -type f -mtime +14 -exec rm -f {} \;; then
    log "There were errors cleaning up log directory."
    ecode=4
fi

log "$0 finished with an exit code of $ecode"
if [[ "$ecode" -ne 0 ]]; then
    email "PBStoRsync of datastore: $datastore Completed with Errors on host: $(hostname)"
else
    email "PBStoRsync of datastore: $datastore Completed Successfully on host: $(hostname)"
    
exit $ecode