#!/bin/sh

# ------------------------------------------------------------
#
# Watchdog - FHEM-Überwachung
# Prueft in regelmaessigen Abstaenden, ob noch Lebenszeichen
# von FHEM zu erkenen sind. 
# Startet bei Bedarf den FHEM-Prozess neu.
#
# Copyright (c) 2013 Alexander Schulz.  All right reserved.
#
# ------------------------------------------------------------

## --- Variablen ---------------------------

# Home-Verzeichnis
home=/opt/fhem
cd $home

# Log-Verzeichnis
#logDir=./log

# Logdatei für Watchdog-Script (Grundname)
#logName=watchdog

# Watchdog Script
wdproc=watchdogloop.sh;


## --- Methoden ----------------------------

## Methode schreibt Meldungen in die Logdatei
#log(){
#  currentTimeStr=$(date +"%Y-%m-%d_%H:%M:%S");
#  currentYear=$(date +"%Y");
#  currentMonth=$(date +"%m");
#  log=$logDir/$logName-$currentYear-$currentMonth.log
#  touch $log;
#  chmod 666 $log;
#  echo "$currentTimeStr fhem_server $1" >> $log;
#}

# Methode gibt Meldungen auf die COnsole aus.
#print(){
#  echo $1;
#}


## --- Start -------------------------------

# Start watchdog
# Pruefen, ob Haupt- oder Start-Script bereits aktiv sind
cnt=$(ps -ef | grep "watchdogloop" | grep -v grep | wc -l)
if [ "$cnt" -eq "0" ] ; then
  #cnt=$(ps -ef | grep "runwatchdog" | grep -v grep | wc -l)
  #if [ "$cnt" -eq "0" ] ; then
    echo "starting watchdog";
    ./$wdproc &
  #else
  #  echo "another watchdog instance starting. skipping"; 
  #  return 1;
  #fi
else
  echo "watchdog already running. skipping";
  return 1;
fi


## Prüfen, ob Watchdog bereits laeuft: PID suchen
#wpid=$(ps -ef | grep -v grep | grep $wdproc | cut -c10-14);
#
## Prüfen, ob leer
#if test $wpid 
#then
#  # PID gefunden, nichts zu tun
#  print "watchdog already running. skip";
#else 
#  # Kein Prozess gefunden, Watchdog starten
#  print "starting watchdog"; 
#  ./$wdproc &
#fi

# Fertig
#print "runwatchdog done";

return 0;
