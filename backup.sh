#!/bin/bash
timestamp=$(date "+%Y-%m-%d")
rhost=""
pkeypath=""
ruser=""
rdir=""
ldir=$(proxmox-backup-manager datastore list | grep "$1" | awk '{print $4}')
logpath=""

# Set up logging
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>"${timestamp}.log" 2>&1

# Initial parameter checks
if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 <datastore>" >&3
    exit 1
elif [[ -n "$ldir" ]]; then
    echo "Datastore $1 does not exist. Check datastore name and try again." >&3
    exit 1
fi

# Wait for running tasks to complete before starting
runningtasks=$(proxmox-backup-manager task list)
while [ -n "$runningtasks" ]; do
    echo "$(date "+%H:%M:%S"): Other tasks are running. Waiting..."
    sleep 5m
    runningtasks=$(proxmox-backup-manager task list)
done

echo "$(date "+%H:%M:%S"): Putting datastore "$1" in maintenance mode."
# Make datastore read-only to prevent changes during sync
if ! proxmox-backup-manager datastore update "$1" --maintenance-mode read-only; then
    echo "$(date "+%H:%M:%S"): Failed to put datastore in maintenance mode. Backup cannot continue. Aborting..."
    exit 1
fi

echo "$(date "+%H:%M:%S"): Starting rsync to remote server..."
# Start sync process
ecode=0
if ! /usr/bin/rsync -av --progress -H --delete -e ssh "${ruser}"@"${rhost}":"${ldir}" "${rdir}"; then
    echo "$(date "+%H:%M:%S"): There were errors syncing files. Please review logs."
    ecode=2
fi

echo "$(date "+%H:%M:%S"): Turning off maintenance mode on datastore "$1""
if ! proxmox-backup-manager datastore update "$1" --delete maintenance-mode; then
    echo "$(date "+%H:%M:%S"): Could not turn off maintenance mode on datastore. Check PBS UI for more information."
    ecode=3
fi

# Cleanup old log files
echo "$(date "+%H:%M:%S"): Cleaning up old log files..."
if ! find "$logpath" -type f -mtime +14 -exec rm -f {}\; then
    echo "$(date "+%H:%M:%S"): There were errors cleaning up log directory."
    ecode=4
fi

echo "$(date "+%H:%M:%S"): Rsync finished with an exit code of "$ecode""
exit $ecode