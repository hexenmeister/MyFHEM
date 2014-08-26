##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

sub
myCtrlBase_Initialize($$)
{
  my ($hash) = @_;
}

# --- Automatik und Steuerung -------------------------------------------------
# wird beim Start von FHEM aufgerufen (notify global:INITIALIZED)
sub notifierFn_FHEM_Start() {
	sendMeJabberMessage('Service Message: FHEM gestartet');
	setAllAutomatikControlsDefaults();
	# ggf. Weiteres...
}

# wird beim Shutdown aufgrufen (notify global:SHUTDOWN)
sub notifierFn_FHEM_Shutdown() {
	sendMeJabberMessage('Service Message: FHEM faehrt herunter');
	# ggf. Weiteres...
}

# speichert (Restart-sicher) ein Key/Value-Paar (fuer Steuerungszwecke)
sub putCtrlData($$) {
	my($key, $val) = @_;
  # Ein Dummy als Container verwenden (ein nicht in Frontent sichtbares Reading speichern)
	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
	setReading(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT, $key, $val);
}

# liefert ein zum einem Key gespeichertes Wert (fuer Steuerungszwecke)
sub getCtrlData($) {
	my($key) = @_;
	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
	my $val = ReadingsVal(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT, $key, undef);
	return $val;
}

# wird regelmaessig (minuetlich) aufgerufen (AT)
sub automationHeartbeat() {
	# nach Bedarf (nachts) Automatik wieder aktivieren:
	#  - Wenn nicht 'Verrreist', dann Zirkulation, Beschattung, 
	#    Tag/Nachtsteuerung (Rolladen), Presence wieder auf Automatik setzen.
	#  - ...
	
	my $hms = CurrentTime();
	my $cDate = CurrentDate(); 
	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
	my $lDate = getCtrlData("ctrl_last_automatic_heartbeat_reset");
	# einmal am Tag zw. 2 und 5 Uhr
	if($cDate ne $lDate &&  $hms gt "02:00" and $hms lt "05:00") {
		if(Value(ELEMENT_NAME_CTRL_ANWESENHEIT) ne FAR_AWAY) {
		  resetAutomatikControls();
    } else {
      # Verreist:
      #  - ZPumpe in Minimal-Modus
      setValue(ELEMENT_NAME_CTRL_ZIRK_PUMPE, ABSENT);
    }
    putCtrlData("ctrl_last_automatic_heartbeat_reset", $cDate);
  }
  
  # TODO: Wenn sich der Wert der Anwesenheit auf Auto geaendert hat (nur bei einer Aenderung!), 
  #       dann auch ZPumpe anpassen. Auch fuer Aenderung auf Anwesend/Abwesend
  #
  	# Wenn PRESENCE Automatic, dann auch 
	  #if(Value(ELEMENT_NAME_CTRL_ANWESENHEIT) ne FAR_AWAY) {
		  #setValue(ELEMENT_NAME_CTRL_ZIRK_PUMPE, ABSENT);
	  #}

	
	# TODO
	
}

# Diese Methode setzt bei Bedarf die SteuerungsControlls (Dummies) auf 
# Defaultwerte (AUTOMATIC). Sie soll beim FHEM-Start aufgerufen werden (global:INITIALIZED).
sub setAllAutomatikControlsDefaults() {
	# TODO: future: Pruefen, ob z.B. Status "Verreist" bereucksichtigt werden soll
	if(Value(ELEMENT_NAME_CTRL_BESCHATTUNG) eq "???" ||  ReadingsVal(ELEMENT_NAME_CTRL_BESCHATTUNG,"STATE","???") eq "???") {
	  setValue(ELEMENT_NAME_CTRL_BESCHATTUNG, AUTOMATIC);
	}
	
	if(Value(ELEMENT_NAME_CTRL_ANWESENHEIT) eq "???" ||  ReadingsVal(ELEMENT_NAME_CTRL_ANWESENHEIT,"STATE","???") eq "???") {
    setValue(ELEMENT_NAME_CTRL_ANWESENHEIT, AUTOMATIC);
  }
	#setHomePresence_Present();
	
	if(Value(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT) eq "???" ||  ReadingsVal(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT,"STATE","???") eq "???") {
    setValue(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT, AUTOMATIC);
  }
	
	if(Value(ELEMENT_NAME_CTRL_ZIRK_PUMPE) eq "???" ||  ReadingsVal(ELEMENT_NAME_CTRL_ZIRK_PUMPE,"STATE","???") eq "???") {
    setValue(ELEMENT_NAME_CTRL_ZIRK_PUMPE, AUTOMATIC);
  }
}

# Diese Methode setzt nachts die SteuerungsControlls (Dummies) auf 
# Defaultwerte (AUTOMATIC). Sie soll jede Nacht zu einem Definierten Zeitpunkt
# aufgerufen werden. Damit wird erreicht, dass alle Uebersteuerungen irgendwann 
# in einen normalen Zustand uebergehen.
sub resetAutomatikControls() {
	setBeschattungAutomaticOn();
	setHomePresence_Automatic();
	#setHomePresence_Present();
	setDayNightRolloAutomaticOn();
	setValue(ELEMENT_NAME_CTRL_ZIRK_PUMPE, AUTOMATIC);
}

###############################################################################
# Controlblock: Liefert zu dem Group/Key die Daten der letzten Aufrufe
# Parameter: Group: Gruppe, die Keys der glichen Gruppe werden zusammengefast.
#            Key: Neuer Zustand.
#            Zeitangabe in Sekunden: Fuer diese Zeit wird die Anzahl der Aktionen
#                   der gleichen Gruppe/Key berechnet. Default = 60 (1 Min).
# Return:    Array: [Zeit seit der letzten Aktion der gleichen Gruppe,
#                    Zeit zw. der letzten und der vorletzten Aktion der Gruppe,
#                    Anzahl der Ereignisse der gleichen Gruppe UND Key,
#                    Anzahl der Ereignisse der gleichen Gruppe UND Key in letzten N Sekunden]
###############################################################################
sub getGenericCtrlBlock($$;$) {
	my($group, $new_state, $last_time_diff)=@_;
	if(!defined($last_time_diff)) {$last_time_diff=60;}
	my $ctrl_gl_au = getCtrlData($group);
	# Format: [zustand on|off...],[datum/zeit decimal (sec)],[counter],[counter_last_min],[sekunden seit letzter aktion]
	my $ctrl_cnt=0;
	my $ctrl_state=undef;
	my $ctrl_dt = undef;
	my $ctrl_cnt_last_min = 0;
	my $ctrl_sec_since = 0;
	if(defined($ctrl_gl_au)) {
		($ctrl_state, $ctrl_dt, $ctrl_cnt, $ctrl_cnt_last_min, $ctrl_sec_since)  = split(/,/,$ctrl_gl_au);
	} else {
		$ctrl_cnt=0;
		$ctrl_cnt_last_min = 0;
  	$ctrl_state=undef;
  	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	  $month+=1, $year+=1900;
	  $ctrl_dt = dateTime2dec($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
	}
	
	# Aktuelle Zeitangaben	
	my $c_date = CurrentDate();
	my $c_time = CurrentTime();
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	$month+=1, $year+=1900;
	my $dt_dec = dateTime2dec($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
	
	$ctrl_cnt_last_min=int($ctrl_cnt_last_min);
	$ctrl_sec_since=int($ctrl_sec_since);
	if($new_state ne $ctrl_state) {
	  $ctrl_cnt = 0;
	  $ctrl_cnt_last_min = 0;
  } else {
  	# wenn gleicher Zustand: 
    if($dt_dec-$ctrl_dt <= 60) {
  	  # wenn innerhalb einer minute
	    $ctrl_cnt_last_min+= 1;
	  } else {
	  	$ctrl_cnt_last_min = 1;
	  }
	  $ctrl_cnt+=1;	
  }
	
	putCtrlData($group, $new_state.",".$dt_dec.",".$ctrl_cnt.",".$ctrl_cnt_last_min.",".($dt_dec-$ctrl_dt));
	
	# Rueckgabe: Sekunden seit der Letzten Abfrage, Sekunden zw. Abfragen davor, GesamtAnzahl gleiche Aktion, Anzahl letzte Minute (gleiche Aktion)
	return (($dt_dec-$ctrl_dt), $ctrl_sec_since, $ctrl_cnt, $ctrl_cnt_last_min);
}

# Controlblock fuer HomeAutomatic-Schalter
# Parameter: Neuer Zustand
sub getHomeAutomaticCtrlBlock($) {
	my($key)=@_;
	return getGenericCtrlBlock("ctrl_last_global_automatic_change", $key);
}

# Methode für Benachrichtigung beim Klingeln an der Haustuer
sub actHaustuerKlingel() {
	#TODO: HAL
	sendMeJabberMessage("Tuerklingel am ".ReadingsTimestamp('KlingelIn','reading',''));
	voiceDoorbell();
}

# Methode für den taster
# Schatet globale Haus-Automatik ein 
# (setzt ELEMENT_NAME_CTRL_BESCHATTUNG aud AUTOMATIC)
sub actHomeAutomaticOn() {
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomaticOn();
	# Tag/Nacht-Steuerung moechte ich hier nicht haben...
	
	# Hier (Sprach)Meldungen
	voiceActAutomaticOn();

}

# Methode für den taster
# Schatet globale Haus-Automatik aus 
# (setzt ELEMENT_NAME_CTRL_BESCHATTUNG aud DISABLED)
sub actHomeAutomaticOff() {
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomaticOff(); # ?
	
	# Hier (Sprach)Meldungen
	voiceActAutomaticOff();
  
}

# Schatet Beschattung-Automatik ein (setzt ELEMENT_NAME_CTRL_BESCHATTUNG aud AUTOMATIC)
sub setBeschattungAutomaticOn() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(ELEMENT_NAME_CTRL_BESCHATTUNG, AUTOMATIC);
}

# Schatet Beschattung-Automatik aus (setzt ELEMENT_NAME_CTRL_BESCHATTUNG aud DISABLED)
sub setBeschattungAutomaticOff() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(ELEMENT_NAME_CTRL_BESCHATTUNG, DISABLED);
}

# Setzt PRESENCE-Status auf automatic 
sub setHomePresence_Automatic() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(ELEMENT_NAME_CTRL_ANWESENHEIT, AUTOMATIC);
}

# Setzt PRESENCE-Status auf anwesend (jemand ist zuhause)
sub setHomePresence_Present() {
	# Erstmal nur Wert setzen. ggf später eine Aktion ausloesen
	setValue(ELEMENT_NAME_CTRL_ANWESENHEIT, PRESENT);
}

# Setzt PRESENCE-Status auf abwesend (niemand ist zuhause)
sub setHomePresence_Absent() {
	# Erstmal nur Wert setzen. ggf später eine Aktion ausloesen
  setValue(ELEMENT_NAME_CTRL_ANWESENHEIT, ABSENT);
}

# Schatet Tag/Nacht-Rolladen-Automatik ein (setzt ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT aud AUTOMATIC)
sub setDayNightRolloAutomaticOn() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT, AUTOMATIC);
}

# Schatet Tag/Nacht-Rolladen-Automatic aus (setzt ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT aud DISABLED)
sub setDayNightRolloAutomaticOff() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT, DISABLED);
}

# TODO: 


1;
