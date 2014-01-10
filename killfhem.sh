#!/bin/sh

## --- Variablen ggf. anpassen! ------------------------------

# Home-Verzeichnis
home=/opt/fhem

# FHEM-Port
port=7072

# Spalten in der Ausgabe des Befehls ps -ef , die PID enthalten (von-bis)
pidCols="10-14"

# Stop fhem

cd $home

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
  for pid in $(ps -ef | grep -v grep | grep fhem.pl | cut -c$pidCols)
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
