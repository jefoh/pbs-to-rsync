#!/bin/bash

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Script must be run as root user."
    exit 1
fi

# Read config file values
config="$1"
if [[ ! -f "$config" ]]; then
    echo "Configuration file: $config does not exist. Please check spelling and location of specified file." >&3
    exit 1
fi

rhost=$(jq -r .remotehost "$config")
ruser=$(jq -r .remoteuser "$config")
rpath=$(jq -r .remotepath "$config")
datastore=$(jq -r .datastore "$config")

# Get datastore filesystem path
ldir=$(proxmox-backup-manager datastore list | grep "$datastore" | awk '{print $4}')

# Initial config checks
if [[ -z "$ldir" ]]; then
    echo "Datastore $datastore does not exist. Check datastore name and try again."
    exit 1
fi

read -rp "***IMPORTANT! This will overwrite everything in datastore: ${datastore} with the contents of ${rhost}:${rpath}. Are you sure you want to continue? (Y/N)***: " proceed

while ! [[ "$proceed" == [Yy] || "$proceed" == [Nn] ]]; do
    read -rp "You must enter Y or N: " proceed
done

if [[ "$proceed" == [Nn] ]]; then
    echo "Exiting script. No changes have been made."
    exit 0
fi

ecode=0
echo "Starting restore process. Syncing contents of ${rhost}:${rpath} to PBS datastore: ${datastore}"
if ! /usr/bin/rsync -avh --progress -H --delete -e ssh "${ruser}"@"${rhost}":"${rpath}/${datastore}/" "${ldir}/"; then
    echo "Some errors were encountered during the file sync. You may need to try again or manually rsync the files."
    ecode=2
fi

echo "Changing ownership of datastore files to PBS system user: backup"
if ! chown backup:backup -R "${ldir}"; then
    echo "There were errors encountered while changing ownership of datastore files. Please check ownership information of datastore."
    ecode=3
fi

if [[ "$ecode" -eq 0 ]];then
    echo "Datastore: ${datastore} restored successfully."
else
    echo "Datastore: ${datastore} restored with errors. Please check datastore file structure and file ownership information."
fi

exit $ecode