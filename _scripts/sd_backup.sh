#!/bin/bash
 
# Setting up directories
SUBDIR=sd_backups
DIR=/mnt/data/data/_bak/$SUBDIR

# should image be compressed (tar)? (1=Yes, 0=No)
COMPRESS_IMAGE=0
 
echo "Starting SD backup process!"
 
# First check if pv package is installed, if not, install it first
PACKAGESTATUS=`dpkg -s pv | grep Status`;
 
if [[ $PACKAGESTATUS == S* ]]
   then
      echo "Package 'pv' is installed."
   else
      echo "Package 'pv' is NOT installed."
      echo "Installing package 'pv'. Please wait..."
      sudo apt-get -y install pv
fi
 
# Check if backup directory exists
if [ ! -d "$DIR" ];
   then
      echo "Backup directory $DIR doesn't exist, creating it now!"
      sudo mkdir $DIR
fi
 
# Create a filename with datestamp for our current backup (without .img suffix)
OFILE="$DIR/backup_$(date +%Y%m%d_%H%M%S)"
 
# Create final filename, with suffix
OFILEFINAL=$OFILE.img
 
# First sync disks
sync; sync
 
# Shut down some services before starting backup process
echo "Stopping some services before backup."
sudo service cron stop
sudo service apache2 stop
sudo service mysql stop

# Begin the backup process, should take about 1 hour from 8Gb SD card to HDD
echo "Backing up SD card to USB HDD."
echo "This will take some time depending on your SD card size and read performance. Please wait..."
SDSIZE=`sudo blockdev --getsize64 /dev/mmcblk0`;
sudo pv -tpreb /dev/mmcblk0 -s $SDSIZE | sudo dd of=$OFILE bs=1M conv=sync,noerror iflag=fullblock
 
# Wait for DD to finish and catch result
RESULT=$?
echo "Result: $RESULT"

# Start services again that where shutdown before backup process
echo "Start the stopped services again."
sudo service mysql start
sudo service apache2 start
sudo service cron start
 
# If command has completed successfully, delete previous backups and exit
if [ $RESULT = 0 ];
   then
      # should image be compressed (tar)?
      if [ $COMPRESS_IMAGE = 1 ];
         # compress image
         then
            echo "Successful backup, previous backup files (tar.gz) will be deleted."
            rm -f $DIR/backup_*.tar.gz
            mv $OFILE $OFILEFINAL
            echo "Backup is being tarred. Please wait..."
            tar zcf $OFILEFINAL.tar.gz $OFILEFINAL
            rm -rf $OFILEFINAL
            echo "SD backup process completed! FILE: $OFILEFINAL.tar.gz"
            exit 0
         # Else remove old images
         else
            echo "Successful backup, previous backup files (img) will be deleted."
            rm -f $DIR/backup_*.img
            mv $OFILE $OFILEFINAL
            exit 0
         fi
# Else remove attempted backup file
   else
      echo "Backup failed! Previous backup files untouched."
      echo "Please check there is sufficient space on the HDD."
      rm -f $OFILE
      echo "SD backup process failed!"
      exit 1
fi
