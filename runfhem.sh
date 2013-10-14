#!/bin/sh

home=/opt/fhem

cd $home

#if test $1 
#then

  cnt=$(ps -ef | grep "fhem.pl" | grep -v grep | wc -l)
  if [ "$cnt" -eq "0" ] ; then
    echo "Starting fhem..."
    #sudo -u fhem perl fhem.pl fhem.cfg
    perl fhem.pl fhem.cfg
    RETVAL=$?
  else
    echo "fhem is allready running. skipping"
    RETVAL=1
  fi

#else
#  echo "usage: runfhem.sh <fhem-config>";
#  RETVAL=1
#fi

return $RETVAL
