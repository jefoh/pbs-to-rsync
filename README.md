# pbs-to-rsync
An unofficial simple shell script to push a local Proxmox Backup Server datastore to a remote rsync location.

# Intro
I wrote this script to automate offsite backups from a Proxmox Backup Server. The current version of PBS 3.0 has 
the option to sync to a "remote" which is another PBS at an off-site location. I simply want to sync the datastore
to an offsite server that cannot have PBS installed. 

# Configuration File
This JSON file has all the information you will need to provide so the script can send the data to the correct place. For multiple datastores, create a new config file for each and use it as the script parameter.

**remotehost**     : The remote server you would like to send data to. <br>
**remoteuser**     : The SSH user on the remote server. <br>
**remotepath**     : The filesystem path on the remote server that you would like to store the backups in. <br>
**logpath**        : The path on your local server that you would like to store the script's logs in. Do not include a trailing slash. <br>
**datastore**      : The case sensitive name of the PBS datastore you are backing up. <br>
**emailrecipient** : The email address that the script should send success or failure emails to. This uses the ```mail``` command and assumes that you have email configured in PBS. <br>

# Setup and Usage
You will need SSH keys set up between the client and server.

Make script executable
```chmod u+x backup.sh```

Fill in config file details

Run script
```./backup.sh config.json```

For automated backups, you can add it to your crontab.