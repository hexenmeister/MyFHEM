#!/bin/sh

## --- Variablen ---------------------------

# Home-Verzeichnis
home=/var/InternerSpeicher/fhem
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
wpid=$(ps | grep -v grep | grep $wdproc | cut -c1-5);

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
