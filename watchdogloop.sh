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

# Zu ueberwachende Log-Datei (erst als Dummy)
aliveLog=./log/undefined.log;

# Logdatei für Watchdog-Script
log=./log/watchdog.log

# Grenzwert (Sekunden der Inaktivitaet)
maxTime=270;
# Pruefintervall
pollTime = 125;

## --- Methoden ----------------------------

# Bestimmt den Namen der zu ueberwachenden Log-Datei (Datumsanhaengig)
getLogName() {
  currentYear=$(date +"%Y");
  currentMonth=$(date +"%m");
  aliveLog=./log/NN_TE_DMST01.Server_Alive-$currentYear-$currentMonth.log;
}

# Methode schreibt Meldungen in die Logdatei
log(){
  currentTimeStr=$(date +"%Y-%m-%d_%H:%M:%S");
  echo "$currentTimeStr fhem_server $1" >> $log;
}

# Methode gibt Meldungen auf die Console aus.
print(){
  echo $1;
}

# Methode testet, ob in der erwarteten Zeit eine Rueckmeldung des Servers erfolgt ist.
checkAlive(){
  # Aktuelle Zeit (Sekunden seit 1. Januar 1970 00:00)
  currentTime=$(date +%s);
  
  # Letzte Dateiaenderung der 'Alive'-Log (Sekunden seit 1. Januar 1970 00:00)
  getLogName;
  lastChangeTime=$(stat -c %Z $aliveLog);

  # Different in Sekunden (wie lange liegt die letzte 'Alive'-Meldung zuruech?)
  diff=$(($currentTime-$lastChangeTime));
  
  print "FHEM-Watchdog: Letzte 'Alive'-Meldung vor $diff Sekunden";
  
  if test $diff -gt $maxTime 
  then
   if test $diff -gt 1000000000
   then
    # Wert unplausibel
    log "V: $diff S: error MSG: value to big";
    #log "S: error";
    return 0;
   fi
   # Server (vermutlich) abgestürzt
   log "V: $diff S: dead MSG: no response from FHEM Server for $diff sekonds";
   #log "S: dead";
   return 1;
  else
   # Server am Leben
   log "V: $diff S: alive MSG: FHEM Server alive";
   #log "S: alive";
   return 0;
  fi
}

## --- Start -------------------------------
print "starting watchdog";
log "MSG: starting watchdog";

# Workaround
# Beim Start gibt FritzBox eine kurze Zeit lang ein falsches Datum an!
# Es wird so etwas wie '1970-01-01_01:01:12' geliefert
# Daher etwas abwarten, bis die Box ein gültiges Datum holt.
cYear=$(date +"%Y");
if test $cYear -eq '1970'
then
 sleep 300;
fi


# FHEM PID suchen
pid=$(ps -ef | grep -v grep | grep fhem.pl | cut -c10-14);
if test $pid 
then
 print "FHEM running";
 log "MSG: FHEM runing";
else
 print "FHEM not running. starting FHEM...";
 log "MSG: FHEM not runing. starting FHEM...";
 getLogName;
 touch $aliveLog;
 ./startfhem &
 sleep 60;
fi

# Vor dem ersten Start etwa warten, damit FHEM ggf. Zeit zum Starten hat 
# und Aktivity-Log aktualisieren kann.
# sleep 600;

# Endlosschleife
while : ; do

# Server-Status pruefen
#checkAlive;
#echo result: $?

if ( checkAlive )
then 
 print "Server alive";
else
 # TODO: Pruefen, ob FHEM gerade Update durchführt (dauert ca. 15 min. auf einer FB)
 print "Server dead";
 # FHEM PID suchen
 pid=$(ps -ef | grep -v grep | grep fhem.pl | cut -c10-14);
 print "killing FHEM. PID: $pid";
 log "MSG: killing FHEM PID: $pid";
 # Prozess beenden
 kill $pid;
 # Etwas warten
 sleep 3;
 # Wenn nicht beendet - hart terminieren
 kill -9 $pid;
 # FHEM neu starten
 print "restarting FHEM";
 ./startfhem &
fi

# Etwas Zeit vor dem naechsten Check verstreichen lassen.
sleep $pollTime;

done
