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

# Logdatei für Watchdog-Script
log=./log/watchdog.log
touch $log;
chmod 777 $log;

# Watchdog Script
wdproc=watchdogloop.sh;


## --- Methoden ----------------------------

# Methode schreibt Meldungen in die Logdatei
log(){
  currentTimeStr=$(date +"%Y-%m-%d_%H:%M:%S");
  echo "$currentTimeStr $1" >> $log;
}

# Methode gibt Meldungen auf die COnsole aus.
print(){
  echo $1;
}


## --- Start -------------------------------

# Prüfen, ob Watchdog bereits laeuft: PID suchen
wpid=$(ps -ef | grep -v grep | grep $wdproc | cut -c10-14);

# Prüfen, ob leer
if test $wpid 
then
  # PID gefunden, nichts zu tun
  print "watchdog already running. skip";
else 
  # Kein Prozess gefunden, Watchdog starten
  print "starting watchdog"; 
  ./$wdproc &
fi

# Fertig
print "startwatchdog done";
