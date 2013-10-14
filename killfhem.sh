#!/bin/sh

home=/opt/fhem

cd $home

port=7072

# Stop fhem

echo Stop fhem

perl fhem.pl $port "shutdown" &
RETVAL=$?
 
# Etwas Zeit geben
sleep 10;

# FHEM PID suchen
pid=$(ps -ef | grep -v grep | grep fhem.pl | cut -c10-14);
if test $pid 
then
  echo "killing FHEM. PID: $pid";
  # Prozess beenden
  kill $pid;
  # Etwas warten
  sleep 3;
  # Wenn nicht beendet - hart terminieren
  kill -9 $pid;
  RETVAL=0
fi

#exit $RETVAL

return $RETVAL
