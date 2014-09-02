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
# Return: HASH:
#  SINCE_LAST_SEC     => Zeit seit der letzten Aktion der gleichen Gruppe
#  BETWEEN_2_LAST_SEC => Zeit zw. der letzten und der vorletzten Aktion der Gruppe
#  EQ_ACT_CNT         => Anzahl der Ereignisse der gleichen Gruppe UND Key
#  EQ_ACT_PP_CNT      => Anzahl der Ereignisse der gleichen Gruppe UND Key in letzten N Sekunden
#  EQ_ACT_1MIN_CNT    => Anzahl der Ereignisse der gleichen Gruppe UND Key in der letzten Minute
#  EQ_ACT_15MIN_CNT   => -/- 15
#  EQ_ACT_1HOUR_CNT
#  EQ_ACT_SAME_DAY_CNT=> Anzahl der Ereignisse an dem selben Tag (nicht 24 Stunden)
#
# alt: Return:    Array: [Zeit seit der letzten Aktion der gleichen Gruppe,
#                    Zeit zw. der letzten und der vorletzten Aktion der Gruppe,
#                    Anzahl der Ereignisse der gleichen Gruppe UND Key,
#                    Anzahl der Ereignisse der gleichen Gruppe UND Key in letzten N Sekunden]
###############################################################################
sub getGenericCtrlBlock($;$$) {
	my($group, $new_state, $last_time_diff)=@_;
	if(!defined($last_time_diff)) {$last_time_diff=60;}
	if(!defined($new_state)) {$new_state="X";} # Wenn State nicht definiert, irgendwas definiertes nehmen
	my $ctrl_gl_au = getCtrlData($group);
	# Format: [zustand on|off...],[datum/zeit decimal (sec)],[counter],[counter_last_min],[sekunden seit letzter aktion]
	my $ctrl_cnt=0;
	my $ctrl_state=undef;
	my $ctrl_dt = undef;
	my $ctrl_cnt_last_min = 0;
	my $ctrl_cnt_last_pp = 0;
	my $ctrl_sec_since = 0;
	
	my $ctrl_cnt_last_15min = 0;
	my $ctrl_cnt_last_hour = 0;
	my $ctrl_cnt_same_day = 0;
	
	if(defined($ctrl_gl_au)) {
		# Last used state, Date, Count (eq Key), Cnt last min, cnt between 2 last actions, cnt last N
		($ctrl_state, $ctrl_dt, $ctrl_cnt, $ctrl_cnt_last_min, $ctrl_sec_since, $ctrl_cnt_last_pp, $ctrl_cnt_last_15min, $ctrl_cnt_last_hour, $ctrl_cnt_same_day)  = split(/,/,$ctrl_gl_au);
	} else {
		$ctrl_cnt=0;
		$ctrl_cnt_last_min = 0;
		$ctrl_cnt_last_pp = 0;
		$ctrl_cnt_last_hour = 0;
		$ctrl_cnt_last_15min = 0;
		$ctrl_cnt_same_day = 0;
  	$ctrl_state=undef;
  	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	  $month+=1, $year+=1900;
	  $ctrl_dt = dateTime2dec($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
	}
	
	# Aktuelle Zeitangaben	
	my $c_date = CurrentDate();
	my $c_time = CurrentTime();
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	my ($lsec,$lmin,$lhour,$lmday,$lmonth,$lyear,$lwday,$lyday,$lisdst) = localtime($ctrl_dt);
	$month+=1, $year+=1900;
	my $dt_dec = dateTime2dec($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
	
	$ctrl_cnt_last_min=int($ctrl_cnt_last_min);
	$ctrl_cnt_last_pp = int($ctrl_cnt_last_pp);
	$ctrl_cnt_last_hour = int($ctrl_cnt_last_hour);
	$ctrl_cnt_same_day = int($ctrl_cnt_same_day);
	$ctrl_cnt_last_15min = int($ctrl_cnt_last_15min);
	$ctrl_sec_since=int($ctrl_sec_since);
	if($new_state ne $ctrl_state) {
	  $ctrl_cnt = 0;
	  $ctrl_cnt_last_min = 0;
	  $ctrl_cnt_last_pp = 0;
	  $ctrl_cnt_last_hour = 0;
	  $ctrl_cnt_last_15min = 0;
	  $ctrl_cnt_same_day = 0;
  } else {
  	# wenn gleicher Zustand: 
    if($dt_dec-$ctrl_dt <= 60) {
  	  # wenn innerhalb einer minute
	    $ctrl_cnt_last_min+= 1;
	  } else {
	  	$ctrl_cnt_last_min = 1;
	  }
	  if($dt_dec-$ctrl_dt <= $last_time_diff) {
  	  # wenn innerhalb definierter spanne
	    $ctrl_cnt_last_pp+= 1;
	  } else {
	  	$ctrl_cnt_last_pp = 1;
	  }
	  if($dt_dec-$ctrl_dt <= 900) {
  	  # wenn innerhalb von 15 minuten
	    $ctrl_cnt_last_15min+= 1;
	  } else {
	  	$ctrl_cnt_last_15min = 1;
	  }
	  if($dt_dec-$ctrl_dt <= 3600) {
  	  # wenn innerhalb von 60 minuten
	    $ctrl_cnt_last_hour+= 1;
	  } else {
	  	$ctrl_cnt_last_hour = 1;
	  }
	  if($mday==$lmday) {
  	  # wenn innerhalb am gleichen Tag
	    $ctrl_cnt_same_day+= 1;
	  } else {
	  	$ctrl_cnt_same_day = 1;
	  }
	  # Gesamtcounter
	  $ctrl_cnt+=1;	
  }
	
	putCtrlData($group, $new_state.",".$dt_dec.",".$ctrl_cnt.",".$ctrl_cnt_last_min.",".($dt_dec-$ctrl_dt).",".$ctrl_cnt_last_pp.",".$ctrl_cnt_last_15min.",".$ctrl_cnt_last_hour.",".$ctrl_cnt_same_day);
	
	my %ret;
	%ret->{SINCE_LAST_SEC}=$dt_dec-$ctrl_dt;
	%ret->{BETWEEN_2_LAST_SEC}=$ctrl_sec_since;
	%ret->{EQ_ACT_CNT}=$ctrl_cnt;
	%ret->{EQ_ACT_PP_CNT}=$ctrl_cnt_last_pp;
	%ret->{EQ_ACT_1MIN_CNT}=$ctrl_cnt_last_min;
	%ret->{EQ_ACT_15MIN_CNT}=$ctrl_cnt_last_15min;
	%ret->{EQ_ACT_1HOUR_CNT}=$ctrl_cnt_last_hour;
	%ret->{EQ_ACT_SAME_DAY_CNT}=$ctrl_cnt_same_day;
	
	return \%ret;
	
	# Rueckgabe: Sekunden seit der Letzten Abfrage, Sekunden zw. Abfragen davor, GesamtAnzahl gleiche Aktion, Anzahl letzte Minute (gleiche Aktion)
	#return (($dt_dec-$ctrl_dt), $ctrl_sec_since, $ctrl_cnt, $ctrl_cnt_last_min);
}

# Controlblock fuer HomeAutomatic-Schalter
# Parameter: Neuer Zustand
sub getHomeAutomaticCtrlBlock($) {
	my($key)=@_;
	#return getGenericCtrlBlock("ctrl_last_global_automatic_change", $key);
	my $ret = getGenericCtrlBlock("ctrl_last_global_automatic_change", $key);
	
	return ($ret->{SINCE_LAST_SEC}, $ret->{BETWEEN_2_LAST_SEC}, $ret->{EQ_ACT_CNT}, $ret->{EQ_ACT_PP_CNT});
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
