##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

use myCtrlHAL;
#require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";
require "$attr{global}{modpath}/FHEM/99_myCtrlBase.pm";
#require "$attr{global}{modpath}/FHEM/99_myCtrlVoice.pm";

sub
myCtrlAutomation_Initialize($)
{
  my ($hash) = @_;
  Log 2, "AutomationControlUser: initialized";
}

sub
myCtrlAutomation_Undef($$)
{
  Log 2, "AutomationControlUser: clean-up";
  return undef;
}

###############################################################################

# --- Notifier- und Actions-Fn ------------------------------------------------
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

# Methode für Benachrichtigung beim Klingeln an der Haustuer
sub actHaustuerKlingel() {
	#TODO: HAL
	sendMeJabberMessage("Tuerklingel am ".ReadingsTimestamp('KlingelIn','reading',''));
	voiceDoorbell();
}

# Benachrichtigungen von PIR vor der Eingangstuer.
sub actPIRVorgarten() {
	#Halloween Sonderschaltung
	if(!voiceHalloween(3)) {
	  #wenn die Halloween-Schaltung inaktiv
	  # anderen SOund abspielen
	  voiceBewegungVorgarten();
	}
}

# Benachrichtigungen von PIR im EG Flur.
sub actPIR_EGFlur() {
	getGenericCtrlBlock("ctrl_last_pir_eg_fl");
	voiceMorningGreeting();
}

# Benachrichtigungen von Fensterkontakten (open/closed/tilted)
# Params:
#   Device: Name des Ausloesers
#   Event: open/closed/tilted
# Moegliche Werte (HM): 
#   battery: ok / battery: low
#   open / closed /  tilted
#   contact: open (to ccu) / .. closed, tlted (to XXX)
#   alive: yes
#   cover: open / cover: closed
#   
sub actFenster($$) {
	my ($deviceName, $event) = @_;
	#Log 3, "Window event: $deviceName => $event";
	#TODO: Aenderung prüefen und nur dann die Methoden rufen, da bei jedem Event Statusinfos uebertragen werden. Auch ggf. mehrmals, also debounce (erste Meldung senden)
	my $le = lc($event);
	if($le=~/^(open|closed|tilted)$/) {
		# Doppelte Meldungen innerhalb kurzer Zeit (1s) unterdruecken.
		if(debounce("state-".$deviceName."-".$le,1)) {
		  actFensterStatus($deviceName, $le);
	  }
	} elsif($le=~/cover:\s+(\S+)/) {
		if(debounce("sabotage-".$deviceName."-".$le,1)) {
  		actFensterSabotageKontakt($deviceName, $1);
  	}
	}# elsif($le=~/battery:\s+(\S+)/) {
	#	actFensterBatteryMsg($deviceName, $1);
	#} #<-Batterienmeldungen besser alle zusammenfassen (ueber alle Geraete)
	
}

# Benachrichtigung ueber die Aenderung des Status eines Fensters
# Params:
#   Device: Name des Ausloesers
#   Event:  open/closed/tilted
#
sub actFensterStatus($$) {
	my ($deviceName, $event) = @_;
	Log 3, ">Fenster: $deviceName => $event";
	# TODO
  scheduleTask(1.5,"actFensterStatusLetzeKurzzeitAktion('$deviceName', '$event')",undef,"state-".$deviceName,2);
  #scheduleTask(1.5,"actFensterStatusLetzeKurzzeitAktion",\($deviceName, $event),"state-".$deviceName,2);
  # Stored muss nicht sein, da je nur sehr kurze Zeitspanne (nach einem Restart waere je abgelaufen)
  #scheduleStoredTask(1.5,"actFensterStatusLetzeKurzzeitAktion('$deviceName', '$event')","state-".$deviceName,2);
}

# Benachrichtigung ueber die Aenderung des Status eines Fensters
# Es werden ueber einen kurzen Zeitraim die Meldungen gesammelt 
# und hier landen nur die letzten innerhalb dieser Zeit
# (s. Methode actFensterStatus)
# Params:
#   Device: Name des Ausloesers
#   Event:  open/closed/tilted
#
sub actFensterStatusLetzeKurzzeitAktion($$) {
	my ($deviceName, $event) = @_;
	Log 3, "--->Fenster: $deviceName => $event";
	#Log 3, "--->Fenster: $deviceName->[0]::$deviceName->[1]";
	
	# Fenster-Status speichern (Zeitraum: Tag, auch Sequence (fuer alle Faelle) speichern, letzte 10?)
	getGenericCtrlBlock("ctrl_last_window_state_".$deviceName, $event, 86400, $event, 10);
	
}

# Benachrichtigung Sabotagekontakt eines Fensters 
# (Oeffnung/Schliessung des Batteriefaches)
# Params:
#   Device: Name des Ausloesers
#   Event:  open/closed/tilted
#
sub actFensterSabotageKontakt($$) {
	my ($deviceName, $event) = @_;
	Log 3, ">Fenster Sabotagekontakt: $deviceName => $event";
	# TODO

}

#sub actFensterBatteryMsg($$) {
#	my ($deviceName, $event) = @_;
#	Log 3, "Fenster Battery: $deviceName => $event";
#	# TODO  
#}

# Methode für den taster
# Schaltet globale Haus-Automatik ein 
# (setzt DEVICE_NAME_CTRL_BESCHATTUNG auf AUTOMATIC/NORMAL)
sub actHomeAutomaticOn() {
	
	# Bestaetigungston
	voiceActAutomatik(1);
	
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomatic();
	# Tag/Nacht-Steuerung moechte ich hier nicht haben...
	
	#TODO: Weiteres

}

# Methode für den taster
# Schaltet globale Haus-Automatik aus 
# (setzt DEVICE_NAME_CTRL_BESCHATTUNG auf DISABLED)
sub actHomeAutomaticOff() {
	
	# Bestaetigungston
	voiceActAutomatik(2);
	
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomaticOff(); # ?
	
	#TODO: Weiteres
	
  
}

# Methode für den taster
# Schaltet Presence
sub actHomePresenceShort() {
	setHomePresence_Present();
	
	#Halloween TEMP
	if(!voiceHalloween(1)) {
	  #wenn die Halloween-Schaltung inaktiv
	  # andere Aktionen
	  
	  # Hier (Sprach)Meldungen
	  voiceActGenericUserEvent();
	  
	}
}

# Methode für den taster
# Schaltet Presence
sub actHomePresenceLong() {
	setHomePresence_Absent();
	
	#Halloween TEMP
	if(!voiceHalloween(2)) {
	  #wenn die Halloween-Schaltung inaktiv
	  # andere Aktionen
	  
	  # Hier (Sprach)Meldungen
	  voiceActLeaveHome();
	}
}



# --- User Service Utils ------------------------------------------------------

# Diese Methode setzt nachts die SteuerungsControlls (Dummies) auf 
# Defaultwerte (AUTOMATIC). Sie soll jede Nacht zu einem Definierten Zeitpunkt
# aufgerufen werden. Damit wird erreicht, dass alle Uebersteuerungen irgendwann 
# in einen normalen Zustand uebergehen.
sub resetAutomatikControls() {
	setBeschattungAutomatic();
	setHomePresence_Automatic();
	#setHomePresence_Present();
	setDayNightRolloAutomaticOn();
	setValue(DEVICE_NAME_CTRL_ZIRK_PUMPE, AUTOMATIC);
}

# Diese Methode setzt bei Bedarf die SteuerungsControlls (Dummies) auf 
# Defaultwerte (AUTOMATIC). Sie soll beim FHEM-Start aufgerufen werden (global:INITIALIZED).
sub setAllAutomatikControlsDefaults() {
	# TODO: future: Pruefen, ob z.B. Status "Verreist" bereucksichtigt werden soll
	if(Value(DEVICE_NAME_CTRL_BESCHATTUNG) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_BESCHATTUNG,"state","???") eq "???") {
	  setValue(DEVICE_NAME_CTRL_BESCHATTUNG, NORMAL);
	}
	
	if(Value(DEVICE_NAME_CTRL_ANWESENHEIT) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_ANWESENHEIT,"state","???") eq "???") {
    setValue(DEVICE_NAME_CTRL_ANWESENHEIT, AUTOMATIC);
  }
	#setHomePresence_Present();
	
	if(Value(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT,"state","???") eq "???") {
    setValue(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT, AUTOMATIC);
  }
	
	if(Value(DEVICE_NAME_CTRL_ZIRK_PUMPE) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_ZIRK_PUMPE,"state","???") eq "???") {
    setValue(DEVICE_NAME_CTRL_ZIRK_PUMPE, AUTOMATIC);
  }
}

# Liefert aktuellen Modus der Beschattungsautomatik
sub getBeschattungMode() {
	return Value(DEVICE_NAME_CTRL_BESCHATTUNG);
}

# Schatet Beschattung-Automatik ein (setzt DEVICE_NAME_CTRL_BESCHATTUNG auf AUTOMATIC)
sub setBeschattungAutomatic() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	my $lastBMode=getCtrlData("ctrl_last_automatic_mode_beschattung");
	if(!defined($lastBMode)) {
    $lastBMode = NORMAL;
  }
	
	if(ReadingsVal(DEVICE_NAME_CTRL_BESCHATTUNG,"state","???") eq '???' || ReadingsVal(DEVICE_NAME_CTRL_BESCHATTUNG,"state","???") eq DISABLED) {
  	setValue(DEVICE_NAME_CTRL_BESCHATTUNG, $lastBMode);
  }
}

# Schatet Beschattung-Automatik aus (setzt DEVICE_NAME_CTRL_BESCHATTUNG auf DISABLED)
sub setBeschattungAutomaticOff() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	my $lastBMode=getBeschattungMode();
	if($lastBMode ne DISABLED) {
    putCtrlData("ctrl_last_automatic_mode_beschattung", $lastBMode);
  }
	setValue(DEVICE_NAME_CTRL_BESCHATTUNG, DISABLED);
}

# Setzt PRESENCE-Status auf automatic 
sub setHomePresence_Automatic() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(DEVICE_NAME_CTRL_ANWESENHEIT, AUTOMATIC);
}

# Setzt PRESENCE-Status auf anwesend (jemand ist zuhause)
sub setHomePresence_Present() {
	# Erstmal nur Wert setzen. ggf später eine Aktion ausloesen
	setValue(DEVICE_NAME_CTRL_ANWESENHEIT, PRESENT);
}

# Setzt PRESENCE-Status auf abwesend (niemand ist zuhause)
sub setHomePresence_Absent() {
	# Erstmal nur Wert setzen. ggf später eine Aktion ausloesen
  setValue(DEVICE_NAME_CTRL_ANWESENHEIT, ABSENT);
}

# Schatet Tag/Nacht-Rolladen-Automatik ein (setzt DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT auf AUTOMATIC)
sub setDayNightRolloAutomaticOn() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT, AUTOMATIC);
}

# Schatet Tag/Nacht-Rolladen-Automatic aus (setzt DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT auf DISABLED)
sub setDayNightRolloAutomaticOff() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT, DISABLED);
}

# --- Automatik und Steuerung -------------------------------------------------

# Controlblock fuer HomeAutomatic-Schalter
# Parameter: Neuer Zustand
sub getHomeAutomaticCtrlBlock($) {
	my($key)=@_;
	#return getGenericCtrlBlock("ctrl_last_global_automatic_change", $key);
	my $ret = getGenericCtrlBlock("ctrl_last_global_automatic_change", $key);
	
	return ($ret->{SINCE_LAST_SEC}, $ret->{BETWEEN_2_LAST_SEC}, $ret->{EQ_ACT_CNT}, $ret->{EQ_ACT_PP_CNT});
}

#my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst);
my $hms;
# wird regelmaessig (minuetlich) aufgerufen (AT)
sub automationHeartbeat() {
	# nach Bedarf (nachts) Automatik wieder aktivieren:
	#  - Wenn nicht 'Verrreist', dann Zirkulation, Beschattung, 
	#    Tag/Nachtsteuerung (Rolladen), Presence wieder auf Automatik setzen.
	#  - ...
	
	#Log 3, "AutomationControlBase: Heartbeat";
	
	#($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	
	$hms = CurrentTime();
	my $cDate = CurrentDate(); 
	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
	my $lDate = getCtrlData("ctrl_last_automatic_heartbeat_reset");
	# einmal am Tag zw. 2 und 5 Uhr
	if($cDate ne $lDate &&  $hms gt "02:00" and $hms lt "05:00") {
		if(Value(DEVICE_NAME_CTRL_ANWESENHEIT) ne FAR_AWAY) {
		  resetAutomatikControls();
    } else {
      # Verreist:
      #  - ZPumpe in Minimal-Modus
      setValue(DEVICE_NAME_CTRL_ZIRK_PUMPE, ABSENT);
    }
    putCtrlData("ctrl_last_automatic_heartbeat_reset", $cDate);
  }
  
  # TODO: Wenn sich der Wert der Anwesenheit auf Auto geaendert hat (nur bei einer Aenderung!), 
  #       dann auch ZPumpe anpassen. Auch fuer Aenderung auf Anwesend/Abwesend
  #
  	# Wenn PRESENCE Automatic, dann auch 
	  #if(Value(DEVICE_NAME_CTRL_ANWESENHEIT) ne FAR_AWAY) {
		  #setValue(DEVICE_NAME_CTRL_ZIRK_PUMPE, ABSENT);
	  #}

	
	# Wenn in WZ Licht laenger als 3 Minuten an ist 
	#   && Licht-Außen < 170? && Rolladen offen > 90 
	#  => dann WZ Rolladen auf 30 %. Bei Terrassentueren nur wenn sie beide zu sind 
	# TODO: HAL
	my $lName="EG_WZ_DA01_Licht_Rechts_Sw";
	my $llevel=ReadingsVal($lName,"level","0");
	my $lthr=170;
	my $ctrlBlockName="ctrl_last_RL_WZ_Light";
	# TODO
	
	#{
	#	my $lName="EG_WZ_DA01_Licht_Rechts_Sw";; my $llevel=ReadingsVal($lName,"level","0");; 
	#	my $lthr=$llevel>20?170:130;; my $self="NN_RL_CTRL_SZ_Dn";; 
	#	my $li = ReadingsVal("UM_VH_HMBL01.Eingang", "brightness", "180");; 
	#	if ($li < $lthr &&  $hms gt "17:00" and $hms lt "23:30") {notGreaterThen("sz_rollo", "30");;}
	# {notGreaterThen("wz_rollo_l", 0);;notGreaterThen("wz_rollo_r", 0, ('wz_fenster_l', 'wz_fenster_r'));;fhem("attr ".$self." my_control ".$dt);;}}
	#	} 
	
	# TODO
	
	# Ueberpruefen, ob Fenser zu lange offen sind etc.
	# TODO: Mehrere Fenster gleichzeitig ueberpruefen: 
	# z.B. wenn mehrere offen sind, soll nicht nacheinander mehrere Meldungen 
	# darueber ausgegeben werden, sonder zusammengefast
	# Idee: Alle offenen ermitteln, dann bewerten, welche davon genannt werden sollen
	my $wnds = getAllWindowNames();
	foreach my $wnd (@{$wnds}) {
		if($wnd ne "") {
      checkFensterZustand($wnd);
    }
	}
	
	# TODO: Terrassentueren
	
	# TODO: Eingangstuer
	
	# Beschattung:
	#TODO: Universelle Namen
	 my $bMode = getBeschattungMode();
	 checkFensterBeschattung("virtual_wz_fenster", "wz_rollo_l",$bMode);
	 checkFensterBeschattung("virtual_wz_terrassentuer", "wz_rollo_r",$bMode);
	 checkFensterBeschattung("virtual_ku_fenster", "ku_rollo",$bMode);
	 
	 checkFensterBeschattung("virtual_sz_fenster", "sz_rollo",$bMode);
	 checkFensterBeschattung("virtual_bz_fenster", "bz_rollo",$bMode);
	 checkFensterBeschattung("virtual_ka_fenster", "ka_rollo",$bMode);
	 checkFensterBeschattung("virtual_kb_fenster", "kb_rollo",$bMode);
	# TODO

}

# --- User Methods ------------------------------------------------------------

# TODO

# Prueft, ob Beschattung des gegebenen Fenster notwendig (und gewuenscht) ist
# Return: -1 -> Error, 0 -> keine Aenderung, 1 -> Beschattung aktiviert, 2 -> Beschattung aufgehoben
sub checkFensterBeschattung($$$) {
	my($sensorName, $rolloName, $mode) = @_;
	
	if($mode eq DISABLED) {
		#Log 3, "Automation: ($sensorName) checkFensterBeschattung: disabled";
		Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => disabled";
		return -9;
	}
	
	# Hack: Vorerst ueber die Zeit steuern, damit diese Funktion nicht der Nacht-Automatik in die Quere kommt.
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	if($hour < 10 || $hour >= 18) {
		#Log 3, "Automation: ($sensorName) checkFensterBeschattung: disabled (night mode)";
		Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => disabled by time interval (night mode)";
		return -99;
	}
	#Log 3, "Automation: checkFensterBeschattung: TEST";
	#return -99;
	
	if($mode eq CONSERVATIVE) {
  	my $prRec = HAL_getSensorValueRecord($sensorName,'presence');
	  if($prRec) {
		  if($prRec->{value}) {
		  	#Log 3, "Automation: ($sensorName) checkFensterBeschattung: disabled by presence (conservative mode)";
		  	Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => disabled by presence (conservative mode)";
		    return -8;
		  }
	  }
	}
	
	my $wstruct = previewGenericCtrlBlock("ctrl_last_window_beschattung_".$sensorName);
	
	my $dauer = $wstruct ->{SINCE_LAST_SEC};
  my $zustand = $wstruct ->{LAST_STATE};
  
  if(defined($zustand) && $dauer<900) { # nicht öffters als 15 Minuten aendern (der ersten Aufruf beruecksichtigen)
  	Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => disabled by interval (too short)";
  	return -7;
  }
	
	# Wenn Sonne ins Fenster scheint (> 1M? Einstellbar machen?)
	# Wenn draussen > 25 Grad ist
	# Wenn Aussenhelligkit > 40000 (?)
	# Dann Rollostand neu berechnen
	
	# TODO: Modi beruecksichtigen:
	#  Direkt: Sofortaenderung; 
	#  Konservativ: PIR auswerten, weniger Rolladenbewegungen, wenn Leute im Raum; Aus; 
	#  Normal: Sicherstellen, dass zw. Rollo-Aenderungen gewissen min. Zeit vergeht.;
	#Normal,Konservativ,Aggressiv,Deaktiviert
	
	# TODO: Manuelle Roll.Bewegung erkenen (Zeitstempel)
	
  # Sonneneinstrahlung
	my $srRec = HAL_getSensorValueRecord($sensorName,"sunny_room_range");
	my $sr=-1;
	if($srRec) {
		$sr=$srRec->{value};
  } else {
		#Error
		Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Error: reading sunny_room_range";
		return -1;
	}
	
	#luminosity
	my $lRec = HAL_getSensorValueRecord($sensorName,"outdoor_luminosity");
	my $lum=-1;
	if($lRec) {
		$lum=$lRec->{value};
	} else {
		# Error
		Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Error: reading luminosity";
		return -1;
	}
	
	#temperature
  my $tRec = HAL_getSensorValueRecord($sensorName,"outdoor_temperature");
  my $tem=-1;
	if($tRec) {
		$tem=$tRec->{value};
	} else {
		# Error
		Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Error: reading temperature";
		return -1;
	}
	
	# Rollostand abfragen
  my $rlRec = HAL_getSensorValueRecord($sensorName,"level");
  my $level = 100;
  if($rlRec) {
    $level = $rlRec->{value};
  } else {
  	# Warning
		Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Warning: reading level";
  }
  
  Log 3, "Automation: checkFensterBeschattung: Sensor: $sensorName, SunRange: $sr, Lum: $lum, Temp: $tem, Level: $level";
	
	# Grenzwerte: TODO: Ggf. ins SensorRecord packen
	my $limMaxLum = 17000; 
	my $limMinLum = $limMaxLum*0.7;
	my $limMaxTem = 20;
	my $limMinTem = $limMaxTem - 1;
	my $limMaxSR = 1;
	my $limMinSR = $limMaxSR - 0.1;
	
	my $doClose=0;
	# Pruefen: schliessen?
	if($sr > $limMaxSR) {
		if($lum > $limMaxLum) {
	  	if($tem > $limMaxTem) {
			  # Rollo: TODO Berechnen
			  if($level>30) { # TODO: ? Manuelle Eingriffe erkennen
			  	$doClose=1;
			  	Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Beschattung aktivieren";
			  	getGenericCtrlBlock("ctrl_last_window_beschattung_".$sensorName,"activate");
			    notGreaterThen($rolloName, 'schatten');
			    #notGreaterThen($rolloName, 45);
			  }
			} else {
				Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Temperatur (to low): ".$tem;
			}			
	  } else {
			Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Helligkeit (to low): ".$lum;
		}
	} else {
		Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Sonneneinstrahlung (to low): ".$sr;
	}
	
	my $doOpen=0;
	if(!$doClose) {
	  # Pruefen: oeffnen?
	  # Level
	  if($level<100) { # TODO: ? Manuelle Eingriffe erkennen
	 	  if($lum < $limMinLum || $tem < $limMinTem || $sr < $limMinSR) {
	 	  	$doOpen=1;
	 	  	# TODO: Rollo notwenigen Level berechnen
			  	Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => Beschattung aufheben";
			  	getGenericCtrlBlock("ctrl_last_window_beschattung_".$sensorName,"deactivate");
			    notLesserThen($rolloName, 'hoch');
	 	  } else {
	 	  	Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => keine Aufhebeung";
	 	  }
	  } else {
 	  	Log 3, "Automation: checkFensterBeschattung: Sensor: ".$sensorName." => keine Beschattung aktuell";
 	  }
	}
	
	return $doClose?1:$doOpen?2:0;
}

# Prueft, ob Fenster geoeffnet sind und ob diesbezueglich Warnungen ausgegeben werden sollen
sub checkFensterZustand($) {
	my($deviceName) = @_;
	my $wstruct = previewGenericCtrlBlock("ctrl_last_window_state_".$deviceName);
	
	my $dauer = $wstruct ->{SINCE_LAST_SEC};
  my $zustand = $wstruct ->{LAST_STATE};
  
  # TODO
  # Wenn Offen und laenger als X? und kalt draussen, dann Warnung
  my $wcb = previewGenericCtrlBlock("ctrl_last_window_state_".$deviceName."_msg","on");
	my $msgzeit = $wcb ->{SINCE_LAST_SEC};
	my $msgcnt = $wcb ->{EQ_ACT_CNT};
	my $msgMaxCnt;
	
	Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName.", Zustand: ".$zustand.", Dauer: ".$dauer.", LastMsgTime: ".$msgzeit.", MsgCnt: ".$msgcnt;
	
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	
	if($zustand ne STATE_NAME_WIN_CLOSED) { # Wenn nicht zu
		if($zustand eq STATE_NAME_WIN_TILTED) {
			# Wenn gekippt
			$msgMaxCnt = 1;
			if($msgcnt<$msgMaxCnt) { # wenn max Anzahl Meldungen noch nicht erreicht ist
			  if($msgcnt==0 || $msgzeit>600) { # wenn seit ueber 10 Min keine Meldung
      		# TODO je nach Aussentemperatur unterschiedliche Zeiten fuer die Warnung
          if($dauer>1800) { # einmalig nach 30 Minuten warnen
    	      # Meldung nur einmal augeben (bis zu 3 mal? bei 20,30, 60?)
      	    # Alarm wenn kalt im Zimmer?
    	      #TODO
    	      getGenericCtrlBlock("ctrl_last_window_state_".$deviceName."_msg","on");
    	      # Aber nicht nachts in Schlafzimmern/Bad : TODO
    	      if($hms lt "11:00" and $hms gt "06:00") {
    	        Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName." => ".$msgcnt.". Warnung. (Max: ".$msgMaxCnt." Meldungen)";
    	        voiceNotificationMsgWarn(0);
    	        speak("Fenster in ".getDeviceLocation($deviceName,"unbekannt")." ist seit ueber ".rundeZahl0($dauer/60)." Minuten gekippt!",0);
    	      }
          }
        } else {
          Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName." => ".$msgcnt."Warnung in ".(600-$msgzeit).". (Max: ".$msgMaxCnt." Meldungen)";
        }
      } else {
        Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName." Max. Anzahl Warnungen erreicht. (Max: ".$msgMaxCnt." Meldungen)";
      }
		} else {
		  $msgMaxCnt = 4;
		  $msgMaxCnt = 2 if($hour>22); # Nach 22:00 nur zweimal warnen
		  $msgMaxCnt = 1 if($hour>23); # Nach 23:00 nur einmal warnen
    	if($msgcnt<$msgMaxCnt) { # sein min. 10 Min keine Meldung, oder gar keine Meldung, aber nicht mehr als N Mal
    	  if($msgcnt==0 || $msgzeit>600) { # wenn seit ueber 10 Min keine Meldung
      		# TODO je nach Aussentemperatur unterschiedliche Zeiten fuer die Warnung
          if($dauer>1200) { # 20 Min
    	      # Meldung nur einmal augeben (bis zu 3 mal? bei 20,30, 60?)
      	    # Alarm wenn kalt im Zimmer?
    	      #TODO
    	      getGenericCtrlBlock("ctrl_last_window_state_".$deviceName."_msg","on");
    	      Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName." => ".$msgcnt.". Warnung. (Max: ".$msgMaxCnt." Meldungen)";
    	      voiceNotificationMsgWarn(0);
    	      speak("Achtung! Fenster in ".getDeviceLocation($deviceName,"unbekannt")." ist seit ueber ".rundeZahl0($dauer/60)." Minuten offen!",100);
          }
        } else {
          Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName." => ".$msgcnt."Warnung in ".(600-$msgzeit).". (Max: ".$msgMaxCnt." Meldungen)";
        }
      } else {
        Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName." Max. Anzahl Warnungen erreicht. (Max: ".$msgMaxCnt." Meldungen)";
      }
    }
  } else {
  	# Fenster zu, Meldungen-ControlBlock resetten
  	removeGenericCtrlBlock("ctrl_last_window_state_".$deviceName."_msg");
  	Log 3, "Automation: checkFensterZustand: Dev: ".$deviceName." => geschlossen, keine Warnungen.";
  	#getGenericCtrlBlock("ctrl_last_window_state_".$deviceName."_msg","off");
  }
}

###############################################################################
1;
