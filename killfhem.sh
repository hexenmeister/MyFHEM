#!/bin/sh

home=/opt/fhem

cd $home

port=7072

# Stop fhem

echo Stop fhem

RETVAL=0

cnt=$(ps -ef | grep "fhem.pl" | grep -v grep | wc -l)
if [ "$cnt" -ge "0" ] ; then
  perl fhem.pl $port "shutdown" &
  RETVAL=$?

  # Etwas Zeit geben
  sleep 10;
  
  # FHEM PID suchen / beenden
  #pid=$(ps -ef | grep -v grep | grep fhem.pl | cut -c10-14);
  #if test $pid 
  #then
  
  # Alle uebriggebliebenen Prozesse beenden
  for pid in $(ps -ef | grep -v grep | grep fhem.pl | cut -c10-14)
  do
    echo "killing FHEM. PID: $pid";
    # Prozess beenden
    kill $pid &
    # Etwas warten
    sleep 3;
    # Wenn nicht beendet - hart terminieren
    kill -9 $pid
    RETVAL=0
  done
  #fi

fi

return $RETVAL
