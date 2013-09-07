##############################################
# $Id: 99_myUtils.pm 0001 2013-09-07 13:21:15Z a_schulz $
package main;

use strict;
use warnings;
use POSIX;
#use List::Util qw[min max];


sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}

# --- Steuerung ---->

my $_steuerungZirkulationspumpe_lastActorChangeTime = time();

sub
steuerungZirkulationspumpe($$$$$) {
# Parameter: Temp_Warmwasserspeicher, Temp_WarmwasserRohr, Temp_ZirkulationspumpeRohr, Aktor_Zirkulationspumpe
 my ($nSpeicherTemp, $nEntnahmeTemp, $nRueckflussTemp, $aktor, $msg) = @_;

 my $CHECK_MIN_TEMP = 0;
 
 # Grenzwerte
 # - MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS: Max Unnterschied zw. Speicher und Rueckflus. Bei Ueberschreitung -> Pumpe an
 # - MIN_TEMP_REUCKFLUSS:                Min Temo. Ruecfluss. Bei Unterschreitung -> Pumpe an
 # - MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS: Max. Unterschied zw. Zu- und Rueckfluss. Bei Ueberschreitung -> Pumpe an
 
 #my %ctrlValues = ('MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS' => 15, 
 #                  'MIN_TEMP_REUCKFLUSS' => 35,                
 #                  'MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS' => 10
 #                  );

 # Steuertabelle: Wochentag
 #my $ctrlValues_off;
 #$ctrlValues_off->{name} = 'Wochentag'; 
 #$ctrlValues_off->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 20;
 #$ctrlValues_off->{MIN_TEMP_REUCKFLUSS} = 35;
 #$ctrlValues_off->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 14;
 #
 #my $ctrlValues_on;
 #$ctrlValues_on->{name} = 'Wochentag'; 
 #$ctrlValues_on->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 10;
 #$ctrlValues_on->{MIN_TEMP_REUCKFLUSS} = 35;
 #$ctrlValues_on->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 3;
 my $ctrlTab = _steuerungZirkulationspumpe_getCtrlTable();
 
 my $tSpeicher = ReadingsVal($nSpeicherTemp, "temperature", "-1")+0;
 my $tEntnahme = ReadingsVal($nEntnahmeTemp, "temperature", "-1")+0;
 my $tRueckfluss = ReadingsVal($nRueckflussTemp, "temperature", "-1")+0;
 
 # TODO: Max/Min Laufzeiten für die Pumpe.
 # TODO: Bereiche: Verschiedene Grenzwerte je nach dem ob die Pumpe ein- oder ausgeschaltet werden soll.
 
 # Aktueller Zustand
 fhem("set $aktor statusRequest");
 my $actor_current_value =  Value($aktor);
 
 # Gewünschten Aktor-Zustand: zunaechst aus.
 my $actor_desired_value = 'off';
 
 # Plausibilitaetspruefungen
 # - Korrekte Werte
 if(($tSpeicher > $CHECK_MIN_TEMP) && ($tEntnahme > $CHECK_MIN_TEMP) && ($tRueckfluss > $CHECK_MIN_TEMP)) {
 	# - Verhaeltnis zueinander. Toleranz von 0.7 Grad. Da z.B. Entmahmestelle höher liegt als Speichersensor, ist eine gewisse Differenz möglich
 	# - Durch die Schichtung in Speicher kann auch Entnahme wesentlich wärmer sein, als von Speiherfühler gemeldet. Folgende Werte waren schon gemessen: [25.625, 54.75, 52.5] 
 	if(($tSpeicher > $tEntnahme-35.0) && ($tEntnahme >= ($tRueckfluss-0.7))) {
 		
 		# Steuerungsdaten je nach Aktor-Zustand
 		my $ctrlTabPart;
 		if($actor_current_value eq 'off') {
	 		$ctrlTabPart = $ctrlTab->{off};
	 	} else {
	 		$ctrlTabPart = $ctrlTab->{on};
	 	}
	 	
 		# Zeit seit der letzten Aenderung
		my $timeDiff = time() - $_steuerungZirkulationspumpe_lastActorChangeTime;
		my $timeDiffMinutes = $timeDiff/60;
		# Daten (Name, Zeit, Dauer) fuer die Anzeige
		my $tabName = $ctrlTab->{name};
		my $Sekunden = $timeDiff;
		my $Stunden=int($Sekunden/3600);
		my $Minuten=int(($Sekunden-$Stunden*3600)/60);
		$Sekunden=$Sekunden-$Stunden*3600-$Minuten*60;
		
		# Pruefen, ob MaxTime ueberschritten ist
		if($timeDiffMinutes > ($ctrlTabPart->{MAX_TIME_BEFORE_CHANGE_MINUTES})) {
			Log 3, "steuerungZirkulationspumpe: Aktor-Aenderung-Wunsch wegen max. Zeitdauer (".int($timeDiffMinutes)." von ".$ctrlTabPart->{MAX_TIME_BEFORE_CHANGE_MINUTES}." min, aktuell: $actor_current_value, Steuertabelle: ".$ctrlTab->{name}.")";
			# gewuenschten Aktor-Zustand umkehren
			if($actor_current_value eq 'off') {
		 		$actor_desired_value = 'on';
		 	} else {
		 		$actor_desired_value = 'off';
		 	}
		} else {
		 	# Grenzwerte fuer Temperaturen pruefen
		 	if(_steuerungZirkulationspumpe_GrenzPruefungen($ctrlTabPart, $tSpeicher, $tEntnahme, $tRueckfluss)) {
		 			$actor_desired_value = 'on';
		 	}
	  }
 		
		#Nur setzen, wenn abweichen 
 		if($actor_current_value ne $actor_desired_value) {
 			  # Nur wenn MinTime um ist
	 			if($timeDiffMinutes > ($ctrlTabPart->{MIN_TIME_BEFORE_CHANGE_MINUTES})) {
	 				# Zeit der letzten Aenderung speichern
	 				$_steuerungZirkulationspumpe_lastActorChangeTime = time();
	 				
		 			Log 3, "steuerungZirkulationspumpe: Aktor-Aenderung (neuer Wert: $actor_desired_value, ".$ctrlTab->{name}.")";
		 			fhem("set $aktor $actor_desired_value");
		 			
		 			my $time = CurrentTime();
		 			fhem("set $msg <div align=\"left\">Steuertabelle: $tabName<br/>Zustand $actor_desired_value seit $time<br/>Vergangener Abschnitt: $Stunden"."h, $Minuten"."m, $Sekunden"."s</div>");
		 			return 1;
		 		} else {
		 			Log 3, "steuerungZirkulationspumpe: keine Aktor-Aenderung zulaessig: min. Zeitdauer (".int($timeDiffMinutes)." von ".$ctrlTabPart->{MIN_TIME_BEFORE_CHANGE_MINUTES}." min, aktuell: $actor_current_value, Steuertabelle: ".$ctrlTab->{name}.")";
		 			return 0;
		 		}
 	  } else {
 	  	Log 3, "steuerungZirkulationspumpe: keine Aktor-Aenderung notwendig (aktuell: $actor_current_value, Steuertabelle: ".$ctrlTab->{name}.")";
 	  	return 0;
 	  }	 		
  } else {
  	my $time = CurrentTime();
  	fhem("set $msg um $time: Temperaturwerte nicht plausibel [$tSpeicher, $tEntnahme, $tRueckfluss]"); 
  	Log 1, "steuerungZirkulationspumpe: Temperaturwerte nicht plausibel (Verhaeltnis zueinander. Sensoren defekt?) [$tSpeicher, $tEntnahme, $tRueckfluss] (Steuertabelle: ".$ctrlTab->{name}.")"; return -1 
  }
 } else { 
 	my $time = CurrentTime();
 	fhem("set $msg um $time: Temperaturwerte nicht plausibel "); 
 	Log 1, "steuerungZirkulationspumpe: Temperaturwerte nicht plausibel (nicht bekannt oder unwahrscheinlich gering) [$tSpeicher, $tEntnahme, $tRueckfluss] (Steuertabelle: ".$ctrlTab->{name}.")"; return -1 
 }
 return -1;
}

sub
_steuerungZirkulationspumpe_GrenzPruefungen($$$$) {
	my ($hash, $tSpeicher, $tEntnahme, $tRueckfluss) = @_;
	
  my $MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS = $hash->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS};
	my $MIN_TEMP_REUCKFLUSS = $hash->{MIN_TEMP_REUCKFLUSS};
	my $MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS = $hash->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS};
	
	my $delta_Speicher_Rueckfluss = $tSpeicher-$tRueckfluss;
	my $delta_Entnahme_Rueckfluss = $tEntnahme-$tRueckfluss;
	
	Log 3, "steuerungZirkulationspumpe: Temperatur: Speicher: $tSpeicher, Entnahme: $tEntnahme, Rueckfluss: $tRueckfluss";
	Log 3, "steuerungZirkulationspumpe: Werte(Grenzwerte): delta_Speicher_Rueckfluss: $delta_Speicher_Rueckfluss ($MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS), delta_Entnahme_Rueckfluss: $delta_Entnahme_Rueckfluss ($MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS)";
	
	if(($delta_Speicher_Rueckfluss>$MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS) 
	   || ($tRueckfluss<$MIN_TEMP_REUCKFLUSS && $tSpeicher >= $MIN_TEMP_REUCKFLUSS) 
	   || ($delta_Entnahme_Rueckfluss>$MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS)) 
	{ 
		return 1;
  } else {
		return 0;
  }
}
 
# Steuertabellen
my $ctrlTable_Normal;
 $ctrlTable_Normal->{name} = 'Normal';  
 $ctrlTable_Normal->{off}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 20;
 $ctrlTable_Normal->{off}->{MIN_TEMP_REUCKFLUSS} = 35;
 $ctrlTable_Normal->{off}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 14;
 $ctrlTable_Normal->{off}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 45; 
 $ctrlTable_Normal->{off}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 300; 
 $ctrlTable_Normal->{on}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 10;
 $ctrlTable_Normal->{on}->{MIN_TEMP_REUCKFLUSS} = 35;
 $ctrlTable_Normal->{on}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 3;
 $ctrlTable_Normal->{on}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 7;
 $ctrlTable_Normal->{on}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 20;
 
my $ctrlTable_Reduced;
 $ctrlTable_Reduced->{name} = 'Reduziert';  
 $ctrlTable_Reduced->{off}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 20;
 $ctrlTable_Reduced->{off}->{MIN_TEMP_REUCKFLUSS} = 35;
 $ctrlTable_Reduced->{off}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 22;
 $ctrlTable_Reduced->{off}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 60; 
 $ctrlTable_Reduced->{off}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 300;
 $ctrlTable_Reduced->{on}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 15;
 $ctrlTable_Reduced->{on}->{MIN_TEMP_REUCKFLUSS} = 35;
 $ctrlTable_Reduced->{on}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 7;
 $ctrlTable_Reduced->{on}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 5;
 $ctrlTable_Reduced->{on}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 10;
 
my $ctrlTable_Night;
 $ctrlTable_Night->{name} = 'Nacht';  
 $ctrlTable_Night->{off}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 20;
 $ctrlTable_Night->{off}->{MIN_TEMP_REUCKFLUSS} = 35;
 $ctrlTable_Night->{off}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 25;
 $ctrlTable_Night->{off}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 240; 
 $ctrlTable_Night->{off}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 720; 
 $ctrlTable_Night->{on}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 15;
 $ctrlTable_Night->{on}->{MIN_TEMP_REUCKFLUSS} = 35;
 $ctrlTable_Night->{on}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 7;
 $ctrlTable_Night->{on}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 0;
 $ctrlTable_Night->{on}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 10;

my $ctrlTable_Absent;
 $ctrlTable_Absent->{name} = 'Abwesend';  
 $ctrlTable_Absent->{off}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 20;
 $ctrlTable_Absent->{off}->{MIN_TEMP_REUCKFLUSS} = 30;
 $ctrlTable_Absent->{off}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 30;
 $ctrlTable_Absent->{off}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 720; 
 $ctrlTable_Absent->{off}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 900; 
 $ctrlTable_Absent->{on}->{MAX_TEMP_DELTA_SPEICHER_RUECKFLUSS} = 15;
 $ctrlTable_Absent->{on}->{MIN_TEMP_REUCKFLUSS} = 30;
 $ctrlTable_Absent->{on}->{MAX_TEMP_DELTA_ENTNAHME_RUECKFLUSS} = 10;
 $ctrlTable_Absent->{on}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 10;
 $ctrlTable_Absent->{on}->{MAX_TIME_BEFORE_CHANGE_MINUTES} = 20;
  
# Liefert aktuell aktive Steuertabelle für die Zirkulationspumpe.
sub
_steuerungZirkulationspumpe_getCtrlTable() {
	# Steuertabelle bestimmen
  
  # gegen Google Calender pruefen
  if(isAbwesend()) {
  	return $ctrlTable_Absent;
  }
  
  my $we = _isWe();
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
  
  # Tagesablaeufe für Wochenende und Arbeitstag
  if($we) {
		if($hour < 1) {
		  return  $ctrlTable_Reduced;
		} elsif($hour < 6) {
			return  $ctrlTable_Night;
		} elsif($hour < 23) {
			return  $ctrlTable_Normal;
		} elsif($hour >= 23) {
			return  $ctrlTable_Reduced;
		}
  } else {
    if($hour < 5) {
			return  $ctrlTable_Night;
		} elsif($hour < 8) {
			return  $ctrlTable_Normal;
		} elsif($hour < 10) {
			return  $ctrlTable_Reduced;
		} elsif($hour < 14) {
			return  $ctrlTable_Absent;
		} elsif($hour < 16) {
			return  $ctrlTable_Reduced;
		} elsif($hour < 22) {
			return  $ctrlTable_Normal;
		} elsif($hour >= 22) {
			return  $ctrlTable_Reduced;
		}
  } 
}

# Prueft, ob aktuell Wochenende ist.
sub
_isWe() {
 my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
 # Samstag = 0, Sonntag = 6
 if($wday == 0 || $wday == 6) {
 	return 1;
 }
 return 0;
}

# Prueft, on Kennzeichen für 'Abwesend' gesetzt ist.
# Der Wert kommt aus dem Google-Klaender 'FHEM'. Der Eintrag muss 'Abwesend' heißen.
# Achtung: hier ist ein Name festverdrahted!
sub
isAbwesend() {
	return Value("GC_Abwesend");
}

# Führt ein update (reload) für den Calendar 'GC'.
# Achtung: hier ist ein Name festverdrahted!
sub
updateGCCal() {
	updateCal("GC");
}

# Fuehrt fuer den gegebnen Calenar ein update (reload) durch
sub
updateCal($) {
	my ($cal) = @_;
  fhem("set $cal update");
}

# Liest zu dem gegebenen Calendar die UID des gewünschten Readings und liest dazu die Summary (Titel) aus.
# Der Abgleich von dem Titel mit dem ebenfalls angegebenen Vergleichswert ergibt den Rueckgabewert.
sub
checkCalSummary($$$) {
 # Name des in FHEM definierten Calendar-Modul, Readings-Eintrag, Vergleichswert
 my ($cal, $mode, $comparison) = @_;
 my $uidstr = ReadingsVal($cal, $mode, "");
 
 my @uida = split(/;/,$uidstr);
 foreach (@uida) {
 	 my $summary = readCalValue($cal, $_, "summary");
	 if($summary eq $comparison) {
	   return 1;	
	 }	
 }
 
 return 0;
}

# Liest zu dem gegebenen Calendar und UID den Wert des angegebenen Feldes aus.
sub
readCalValue($$$) {
	my ($gc, $uid, $field) = @_;
	my $ret = fhem("get $gc $field $uid");
	Log 5, "readCalValue for $gc: $field for UID $uid is $ret.";
	return $ret;
}


# --- obsolet --->
sub
checkOWX() {
	if(!OWX_Search_SER($defs{OWio1},"verify")){
		Log 1, "cOWX: Verify failed. removing OWio1"; 
		fhem("delete OWio1");
	} elsif(_checkOWXInterval("OWX_28_D7EA91040000", "9999")) {
	  Log 1, "cOWX: wrong interval. removing OWio1"; 
		fhem("delete OWio1");
	}
	
	if(!_checkOWX("OWio1", "/dev/ttyUSB0")) {
		if(!_checkOWX("OWio1", "/dev/ttyUSB1")) {
			return "check OWX: failed";
		}
	}
	return "check OWX: ok";
}

sub _checkOWXInterval($$) {
	my ($name, $def) = @_;
	my $t = $defs{$name}->{INTERVAL};
	if($t eq $def) {
		return 1;
	}
  return 0;
}

sub
_checkOWX($$) {
	my ($name, $dev) = @_;
	if(Value($name) eq "Active") { return 1;}
	Log 1, "cOWX: Adapter $name not found. Trying to redefine on $dev.";
	fhem("define $name OWX $dev");
	sleep(1);
	if(Value($name) ne "Active") { Log 1, "cOWX: Redefine failed."; return 0;}
	Log 3, "cOWX: Redefine successfull.";
	fhem("attr $name room OWX");
	fhem("get $name devices"); 
	return 1;
}

# <-----------

# Stelt sicher, dass der aktuelle Geraete-Wert nicht groesser ist als gewuenscht.
# Bei Bedarf wird der Wert niedriger gesetzt, jedoch nicht erhoeht.
# Damit soll sichergestellt werden, dass die beabsichtigte Rollo-Teilschliessung
# nicht zu einer Oeffnung fuehrt, wenn die Rolllaeden bereits manuell noch weiter 
# heruntergefahren worden sind.
# Es kann eine optionale Liste der Namen der Fensterkontakte mitgegeben werden. 
# Diese würden ggf. eine vollständige Schliessung verhindern können (wenn nicht geschlossen).
# In diesem Fall definiert Variable 'desiredValueWhenOpened' den Ergebnis-Wert.
# Wenn ein Fensterkontakt nicht verfügbar ist (Battery leer, name falsch geschrieben) 
# wird das wie ein offenes Fenster behandelt.
sub
notGreaterThen($$;@)
{
  my ($device, $desiredValue, @wndDeviceList) = @_;
  my $wndOpen = 0; # wird auf 1 gesetzt, wenn min 1 Fensterkontakt 'offen' meldet
  my $desiredValueWhenOpened = 90; # wenn offen, wird dieser Wert statt den gewünschten verwendet (bei 100 wäre keine Änderung duchgeführt)
  
  foreach my $wndDevice (@wndDeviceList) {
  	my $wdValue = Value($wndDevice);
  	$wdValue = lc($wdValue);
    if($wdValue ne 'closed') { $wndOpen=1; }
  }
  # wenn offen, dann gewuenschten Wert redefinieren
  if($wndOpen>0) { $desiredValue = $desiredValueWhenOpened; }
  
  my $deviceCurrentValue = _getDeviceValueNumeric($device);
  if($desiredValue < $deviceCurrentValue) 
  { 
    fhem "set $device $desiredValue";
    return 1;
  } else { return 0; };

  #$deviceCurrentValue = min($desiredValue, $deviceCurrentValue);
  #fhem "set $device $deviceCurrentValue";
  #return $deviceCurrentValue ;
}

# Stelt sicher, dass der aktuelle Geraete-Wert nicht kleiner ist als gewuenscht.
# Bei Bedarf wird der Wert hoeher gesetzt, jedoch nicht verkleiner.
# Damit soll sichergestellt werden, dass die beabsichtigte Rollo-Teiloefnung
# nicht zu einer Schliessung fuehrt, wenn die Rollladen bereits
# manuell noch weiter hochgefahren worden sind.
# Es kann eine optionale Liste der Namen der Fensterkontakte mitgegeben werden. 
# Diese würden ggf. eine vollständige Öffnung verhindern können (wenn nicht geschlossen).
# In diesem Fall definiert Variable 'desiredValueWhenOpened' den Ergebnis-Wert.
# Wenn ein Fensterkontakt nicht verfügbar ist (Battery leer, name falsch geschrieben) 
# wird das wie ein offenes Fenster behandelt.
sub
notLesserThen($$;@)
{
  my ($device, $desiredValue, @wndDeviceList) = @_;
  my $wndOpen = 0; # wird auf 1 gesetzt, wenn min 1 Fensterkontakt 'offen' meldet
  my $desiredValueWhenOpened = 20; # wenn offen, wird dieser Wert statt den gewünschten verwendet (bei 0 wäre keine Änderung duchgeführt)
  
  foreach my $wndDevice (@wndDeviceList) {
  	my $wdValue = Value($wndDevice);
  	$wdValue = lc($wdValue);
    if($wdValue ne 'closed') { $wndOpen=1; }
  }
  # wenn offen, dann gewuenschten Wert redefinieren
  if($wndOpen>0) { $desiredValue = $desiredValueWhenOpened; }
  
  my $deviceCurrentValue = _getDeviceValueNumeric($device);
  if($desiredValue > $deviceCurrentValue) 
  { 
    fhem "set $device $desiredValue";
    return 1;
  } else { return 0; };
  
  #$deviceCurrentValue = max($desiredValue, $deviceCurrentValue);
  #fhem "set $device $deviceCurrentValue";
  #return $deviceCurrentValue ;
}

# Liefert den aktuelen numerisschen Wert eines Ger�tezustandes. 
# Setzt bei Bedarf die symbolische Werte (up, down) in ihre 
# Zahlenwertrepresentationen um.
sub
_getDeviceValueNumeric($)
{
  return _convertSymParams(Value($_[0]));
}

# Setzt Parameter-Werte fuer symbolische Werte in ihre Zahlenwerte um.
# up = 100, down = 0
sub
_convertSymParams($)
{
  my $value = $_[0];
  # Endwerte ber�cksichtigen, Gro�-/Kleinschreibung ignorieren
  $value = lc($value);
  if($value eq "down" || $value eq "runter" || $value eq "off") { return 0; } 
  elsif($value eq "up" || $value eq "hoch" || $value eq "on") { return 100; } 
  elsif($value =~ /schatten.*/) { return 80; } 
  elsif($value =~ /halb.*/ ) { return 60; } 
  # Numerische Werte erwartet
  my $ivalue = int($value);
  if($ivalue < 0) { return 0; }
  elsif($ivalue > 100) { return 100; }
  elsif($ivalue > 0) { return $ivalue; }
  # Pr�fung, ob bei 0 da wirklich eine Nummer war 
  if($value eq $ivalue or $value eq "0 %" or $value eq "0%") { return 0; }
  # Default-Fall: Bei unbekannten Werten soll Rollo offen sein
  return 100; 
}

# --- tick alive / watchdog ---->
sub tickAlive($)
{
	my ($device) = @_;
	my $v = _getDeviceValueNumeric($device);
	$v = $v+1; 
	if($v>=15) {$v=0;} 
	fhem("set $device $v");
}

# --- utils ---->

# Liefert aktueller Zeitstempel
sub
CurrentTime()
{
	#my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	#my $ReturnText = sprintf("%02d:%02d:%02d", $hour, $min, $sec);
	return strftime("%H:%M:%S", localtime());
}

sub
CurrentDate()
{
	#my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	#my $ReturnText = sprintf("%02d:%02d:%04d", $mday, $month+1, $year+1900);
	return strftime("%d.%m.%Y", localtime());
}

# Vergleicht zwei Zeit-Strings in Form HH:MM:SS und liefert den kleineren Wert.
sub
minTime($$)
{
	my ($t1, $t2) = @_;
	
	my $i1 = _timeStr2Sec($t1);
	my $i2 = _timeStr2Sec($t2);
	
	if($i1 < $i2) { return $t1; }
	return $t2;
}

# Vergleicht zwei Zeit-Strings in Form HH:MM:SS und liefert den groesseren Wert.
sub
maxTime($$)
{
	my ($t1, $t2) = @_;
	
	my $i1 = _timeStr2Sec($t1);
	
my $i2 = _timeStr2Sec($t2);
	
	if($i1 > $i2) { return $t1; }
	return $t2;
}

# Rechnet Zeit in Form HH:MM:SS in eine Int-Zahl um .
# (Perl-Zeit, als fehlende Angaben (Jahr etc.) werden aktuelle Datumswerte verwendet
sub
_timeStr2Sec($)
{
	my $PtimeOrg = shift;
	
	$PtimeOrg = "" unless(defined($PtimeOrg));
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;

  if ($PtimeOrg !~ /[0-2][0-9]:[0-5][0-9]/ or substr($PtimeOrg,0,2) >= 24)
  {$PtimeOrg = $hour.":".$min.":".$sec;}
  
  #return substr($PtimeOrg,0,2)."--".substr($PtimeOrg,3,2)."--".substr($PtimeOrg,6,2)."#";
  my $TimeP = mktime(substr($PtimeOrg,6,2),substr($PtimeOrg,3,2),
     substr($PtimeOrg,0,2),$mday,$month,$year,$wday,$yday,$isdst);
  
  return $TimeP;
}

# Berechnet Verschiebeung (2. Argument) zu dem Zeitpunkt (1. Argument)
# Uebernommen irgendwo aus http://forum.fhem.de
sub 
TimeOffset($;$)
{
  my $PtimeOrg = shift;
  my $Poffset = shift;

  $PtimeOrg = "" unless(defined($PtimeOrg));
  $Poffset = 0 unless(defined($Poffset));
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;

  if ($PtimeOrg !~ /[0-2][0-9]:[0-5][0-9]/ or substr($PtimeOrg,0,2) >= 24)
  {$PtimeOrg = $hour.":".$min;}

  my $TimeP = mktime(0,substr($PtimeOrg,3,2),
     substr($PtimeOrg,0,2),$mday,$month,$year,$wday,$yday,$isdst);
  my $TimePM = $TimeP + $Poffset * 60;
  my ($Psec,$Pmin,$Phour,$Pmday,$Pmonth,$Pyear,
     $Pwday,$Pyday,$Pisdst) = localtime($TimePM);
  my $ReturnText = sprintf("%02d:%02d:%02d", $Phour, $Pmin, $Psec);
}

sub right{
    my ($string,$nr) = @_;
    return substr $string, -$nr, $nr;
}

sub left{
    my ($string,$nr) = @_;
    return substr $string, 0, $nr;
}


1;
