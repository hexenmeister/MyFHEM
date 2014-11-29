##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

#use myCtrlHAL;
require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";
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
	#Halloween TEMP
	voiceHalloween(3);
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

sub actFensterStatus($$) {
	my ($deviceName, $event) = @_;
	Log 3, ">Fenster: $deviceName => $event";
	# TODO
  scheduleTask(1.5,"actFensterStatusLetzeKurzzeitAktion('$deviceName', '$event')",undef,"state-".$deviceName,2);
  #my @a= [$deviceName, $event];
  #scheduleTask(1.5,"actFensterStatusLetzeKurzzeitAktion",@a,"state-".$deviceName,2);
}

sub actFensterStatusLetzeKurzzeitAktion($$) {
	my ($deviceName, $event) = @_;
	Log 3, "--->Fenster: $deviceName => $event";
	
}

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
# Schatet globale Haus-Automatik ein 
# (setzt DEVICE_NAME_CTRL_BESCHATTUNG aud AUTOMATIC)
sub actHomeAutomaticOn() {
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomaticOn();
	# Tag/Nacht-Steuerung moechte ich hier nicht haben...
	
	# Hier (Sprach)Meldungen
	voiceActGenericUserEvent();

}

# Methode für den taster
# Schatet globale Haus-Automatik aus 
# (setzt DEVICE_NAME_CTRL_BESCHATTUNG aud DISABLED)
sub actHomeAutomaticOff() {
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomaticOff(); # ?
	
	# Hier (Sprach)Meldungen
	voiceActLeaveHome();
  
}


# --- User Service Utils ------------------------------------------------------

# Diese Methode setzt nachts die SteuerungsControlls (Dummies) auf 
# Defaultwerte (AUTOMATIC). Sie soll jede Nacht zu einem Definierten Zeitpunkt
# aufgerufen werden. Damit wird erreicht, dass alle Uebersteuerungen irgendwann 
# in einen normalen Zustand uebergehen.
sub resetAutomatikControls() {
	setBeschattungAutomaticOn();
	setHomePresence_Automatic();
	#setHomePresence_Present();
	setDayNightRolloAutomaticOn();
	setValue(DEVICE_NAME_CTRL_ZIRK_PUMPE, AUTOMATIC);
}

# Diese Methode setzt bei Bedarf die SteuerungsControlls (Dummies) auf 
# Defaultwerte (AUTOMATIC). Sie soll beim FHEM-Start aufgerufen werden (global:INITIALIZED).
sub setAllAutomatikControlsDefaults() {
	# TODO: future: Pruefen, ob z.B. Status "Verreist" bereucksichtigt werden soll
	if(Value(DEVICE_NAME_CTRL_BESCHATTUNG) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_BESCHATTUNG,"STATE","???") eq "???") {
	  setValue(DEVICE_NAME_CTRL_BESCHATTUNG, AUTOMATIC);
	}
	
	if(Value(DEVICE_NAME_CTRL_ANWESENHEIT) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_ANWESENHEIT,"STATE","???") eq "???") {
    setValue(DEVICE_NAME_CTRL_ANWESENHEIT, AUTOMATIC);
  }
	#setHomePresence_Present();
	
	if(Value(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT,"STATE","???") eq "???") {
    setValue(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT, AUTOMATIC);
  }
	
	if(Value(DEVICE_NAME_CTRL_ZIRK_PUMPE) eq "???" ||  ReadingsVal(DEVICE_NAME_CTRL_ZIRK_PUMPE,"STATE","???") eq "???") {
    setValue(DEVICE_NAME_CTRL_ZIRK_PUMPE, AUTOMATIC);
  }
}

# Schatet Beschattung-Automatik ein (setzt DEVICE_NAME_CTRL_BESCHATTUNG aud AUTOMATIC)
sub setBeschattungAutomaticOn() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(DEVICE_NAME_CTRL_BESCHATTUNG, AUTOMATIC);
}

# Schatet Beschattung-Automatik aus (setzt DEVICE_NAME_CTRL_BESCHATTUNG aud DISABLED)
sub setBeschattungAutomaticOff() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
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
	#Halloween TEMP
	voiceHalloween(1);
}

# Setzt PRESENCE-Status auf abwesend (niemand ist zuhause)
sub setHomePresence_Absent() {
	# Erstmal nur Wert setzen. ggf später eine Aktion ausloesen
  setValue(DEVICE_NAME_CTRL_ANWESENHEIT, ABSENT);
  #Halloween TEMP
	voiceHalloween(2);
}

# Schatet Tag/Nacht-Rolladen-Automatik ein (setzt DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT aud AUTOMATIC)
sub setDayNightRolloAutomaticOn() {
	# Erstmal nur Wert ssetzen. ggf später eine Aktion ausloesen
	setValue(DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT, AUTOMATIC);
}

# Schatet Tag/Nacht-Rolladen-Automatic aus (setzt DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT aud DISABLED)
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

# wird regelmaessig (minuetlich) aufgerufen (AT)
sub automationHeartbeat() {
	# nach Bedarf (nachts) Automatik wieder aktivieren:
	#  - Wenn nicht 'Verrreist', dann Zirkulation, Beschattung, 
	#    Tag/Nachtsteuerung (Rolladen), Presence wieder auf Automatik setzen.
	#  - ...
	
	#Log 3, "AutomationControlBase: Heartbeat";
	
	my $hms = CurrentTime();
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
}

# --- User Methods ------------------------------------------------------------

# TODO


###############################################################################
1;
