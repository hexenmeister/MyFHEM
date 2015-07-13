##############################################
# $Id: 99_myUtils.pm 0000 2014-08-21 00:00:00Z hexenmeister$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;
#use List::Util qw[min max];

#use myCtrlHAL;
require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";

# --- Konstanten fuer die verwendeten ElementNamen ----------------------------
#use constant {
#  DEVICE_NAME_CTRL_ANWESENHEIT    => "T.DU_Ctrl.Anwesenheit",
#  DEVICE_NAME_GC_ANWESENHEIT      => "GC_Abwesend",
#  DEVICE_NAME_CTRL_ZIRK_PUMPE     => "T.DU_Ctrl.ZP_Mode",
#  DEVICE_NAME_CTRL_BESCHATTUNG    => "T.DU_Ctrl.Beschattung",
#  DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT => "T.DU_Ctrl.Rolladen" # reserved for future use
#};

# --- Konstanten für die Werte f. Auto, Enabled, Disabled
#use constant {
#  AUTOMATIC    => "Automatik",
#  ENABLED      => "Aktiviert",
#  DISABLED     => "Deaktiviert",
#  #ON          => "Ein",
#  #OFF         => "Aus",
#  PRESENT      => "Anwesend",
#  ABSENT       => "Abwesend",
#  FAR_AWAY     => "Verreist"
#};

sub struct2Array($$;@);

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
 $ctrlTable_Normal->{on}->{MIN_TIME_BEFORE_CHANGE_MINUTES} = 5;
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
# zum Testen: {_steuerungZirkulationspumpe_getCtrlTable()->{name};;}
sub
_steuerungZirkulationspumpe_getCtrlTable() {
	# zuerst den manuellen Schalter abfragen
	my $zpctrl = ReadingsVal(DEVICE_NAME_CTRL_ZIRK_PUMPE, "state",undef);
	if(defined($zpctrl)) {
		$zpctrl = lc($zpctrl);
		if($zpctrl eq "default" || $zpctrl eq "normal") {
			return  $ctrlTable_Normal;
		}
		if($zpctrl eq "reduced" || $zpctrl eq "reduziert") {
			return  $ctrlTable_Reduced;
		}
		if($zpctrl eq "night" || $zpctrl eq "nacht") {
			return  $ctrlTable_Night;
		}
		if($zpctrl eq "absent" || $zpctrl eq "abwesend") {
			return  $ctrlTable_Absent;
		}
	}
	# falls nicht definiert, oder Automatik, dann nach Tag/Zeit bestimmen
	
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
	return Value(DEVICE_NAME_GC_ANWESENHEIT);
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

# --- Refreshing AT commands --->
# Liest die Definition zu dem angegebenen Device-Namen. Löscht und redefiniert AT-Befehl.
# Es wird geprüft, ob es sich um ein AT Befehl handelt.
#
# Es gibt ganz bestimmt eine elegantere, schnellere und sicherere Methode (ohne globale Variablen wie $defs zu verwenden), 
# die Zeit für AT-Befeh neu zu berechnen. Leider ist diese mir (noch) nicht bekannt ;-)
sub
_refreshAtCmd($) {
	my ($name) = @_;
	# pruefen, ob FHEM-Device mit dem gegebenen Namen vorhanden ist
	if(defined($defs{$name})) {
  	my $type = $defs{$name}{TYPE};
  	Log 5, "refreshAtCmd: type: $type; name: $name"; 
  	if($type eq 'at') {
  	  my $def = $defs{$name}{DEF};
  	  if(length($def)>0) {
  	  	# Attribute speichern (Map)
  	    my $ap = $attr{$name};
  	    
        # Device loeschen
  	    my $cmd ='delete '.$name;
  	    fhem($cmd);
  	    
  	    # Device neu anlegen
  	    # Es ist wichtig, alle ;-Zeichen zu verdoppeln! Ansonsten wird ab ersten Semikolon der Befehl abgeschnitten!
  	    $def =~ s/;/;;/g; 
  	    $cmd ='define '.$name.' at '.$def;
  	    fhem($cmd);
  	    
  	    # Attribute (wieder) setzen (aus dem gespeicherten Map)
  	    foreach my $a (keys %{$ap}) {
          Log 5, "Attribute Setzen: ".$name." :  ".$a." = ".$ap->{$a};
          fhem('attr '.$name.' '.$a.' '.$ap->{$a});
        }
  	  } else {
    	  Log 3, "refreshAtCmd: no device found for $name"; 
      }
    } else {
    	Log 3, "refreshAtCmd: undefined or wrong type ($type) for $name"; 
    }
  }
}

# Makierte (Attribut 'my_autorefresh') AT-Befehle refreshen.
sub
refreshMyAtCmds() {
  # Alle FHEM-Devices durchgehen
	foreach my $d (keys %defs) {
    my $name = $defs{$d}{NAME};
    my $type = $defs{$d}{TYPE};
    # Nur Geraete aussuchen, die ein benutzerdefiniertes Attribut 'my_autorefresh' besitzen und vom Typ 'at' sind.
    if(AttrVal($name, 'my_autorefresh', '0') == 1 && $type eq 'at') {      
      #Log 5, "refreshMyAtCmds: name: $name";
      _refreshAtCmd($name);
    }
  }
}

sub
sendRLStatusRequest() {
	Log 5, "Zustandsanfrage an alle Rollos";
	# Alle FHEM-Devices durchgehen
	foreach my $d (keys %defs) {
	  my $name = $defs{$d}{NAME};
    my $type = $defs{$d}{TYPE};
    # Nur Geraete aussuchen, die ein  Attribut 'model' mit dem Wert 'HM-LC-Bl1PBU-FM' haben und vom Typ 'CUL_HM' sind.
    if(AttrVal($name, 'model', '-') eq 'HM-LC-Bl1PBU-FM' && $type eq 'CUL_HM') {      
      Log 5, "Zustandsanfrage an: $name";
      fhem("set $name statusRequest");
    }
	}
}

#sub
#myTest() {
#	Log 3, "---: Test";
#	# Alle FHEM-Devices durchgehen
#	foreach my $d (keys %defs) {
#    my $name = $defs{$d}{NAME};
#    my $type = $defs{$d}{TYPE};
#    # Nur Geraete aussuchen, die ein benutzerdefiniertes Attribut 'my_autorefresh' besitzen und vom Typ 'at' sind.
#    if(AttrVal($name, 'my_autorefresh', '0') == 1 && $type eq 'at') {
#      Log 3, "---: ".$name." : ".$type;
#      
#      my $ap = $attr{$name};
#      foreach my $a (keys %{$ap}) {
#        Log 3, "---: ".$a." = ".$ap->{$a};
#      }
#    }
#    
#    
#  }
#  
#  #foreach my $l (sort keys %attr) {
#  #    Log 3, "---: ".$attr{$l}{$name}."---";
#  #  }
#}

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
notGreaterThen($$;@) {
  my ($device, $desiredValue, @wndDeviceList) = @_;
  my @list = struct2Array($device,undef);
  foreach (@list) {
  	notGreaterThen_($_, $desiredValue, @wndDeviceList);
  }
}

sub
notGreaterThen_($$;@)
{
  my ($device, $desiredValue, @wndDeviceList) = @_;
  $desiredValue = _convertValueForDevice($device, $desiredValue);
  my $wndOpen = 0; # wird auf 1 gesetzt, wenn min 1 Fensterkontakt 'offen' meldet
  my $desiredValueWhenOpened = 90; # wenn offen, wird dieser Wert statt den gewünschten verwendet (bei 100 wäre keine Änderung duchgeführt)
  
  fhem "set $device statusRequest"; # TEST!
  
  foreach my $wndDevice (@wndDeviceList) {
  	fhem "set $wndDevice statusRequest"; # TEST!
  	my $wdValue = Value($wndDevice);
  	$wdValue = lc($wdValue);
    if($wdValue ne 'closed') { $wndOpen=1; }
  }
  #$wndOpen=checkWindowOpen(@wndDeviceList);
  # wenn offen, dann gewuenschten Wert redefinieren
  if($wndOpen>0) { $desiredValue = $desiredValueWhenOpened; }
  
  my $deviceCurrentValue = _getRolloLevel($device);#_getDeviceValueNumeric($device);
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
notLesserThen($$;@) {
  my ($device, $desiredValue, @wndDeviceList) = @_;
  my @list = struct2Array($device,undef);
  foreach (@list) {
  	notLesserThen_($_, $desiredValue, @wndDeviceList);
  }
}

sub
notLesserThen_($$;@)
{
  my ($device, $desiredValue, @wndDeviceList) = @_;
  $desiredValue = _convertValueForDevice($device, $desiredValue);
  my $wndOpen = 0; # wird auf 1 gesetzt, wenn min 1 Fensterkontakt 'offen' meldet
  my $desiredValueWhenOpened = 20; # wenn offen, wird dieser Wert statt den gewünschten verwendet (bei 0 wäre keine Änderung duchgeführt)
  
  fhem "set $device statusRequest"; # TEST!
  
  foreach my $wndDevice (@wndDeviceList) {
  	fhem "set $wndDevice statusRequest"; # TEST!
  	my $wdValue = Value($wndDevice);
  	$wdValue = lc($wdValue);
    if($wdValue ne 'closed') { $wndOpen=1; }
  }
  #$wndOpen=checkWindowOpen(@wndDeviceList);
  # wenn offen, dann gewuenschten Wert redefinieren
  if($wndOpen>0) { $desiredValue = $desiredValueWhenOpened; }
  
  my $deviceCurrentValue = _getRolloLevel($device);#_getDeviceValueNumeric($device);
  if($desiredValue > $deviceCurrentValue) 
  { 
    fhem "set $device $desiredValue";
    return 1;
  } else { return 0; };
  
  #$deviceCurrentValue = max($desiredValue, $deviceCurrentValue);
  #fhem "set $device $deviceCurrentValue";
  #return $deviceCurrentValue ;
}


sub
checkWindowOpen(@)
{
	my (@wndDeviceList) = @_;
	my $wndOpen = 0; # wird auf 1 gesetzt, wenn min 1 Fensterkontakt 'offen' meldet
	foreach my $wndDevice (@wndDeviceList) {
  	#fhem "set $wndDevice statusRequest"; # TEST!
  	my $wdValue = Value($wndDevice);
  	$wdValue = lc($wdValue);
  	Log 3, ">checkWindowOpen>".$wdValue;
    if($wdValue ne 'closed') { $wndOpen=1; }
  }
  
  return $wndOpen;
}

sub
_getRolloLevel($)
{
	my ($name) = @_;
	return int(ReadingsVal($name, "level", "100"));
}

###############################################################################
# Liest eventMap-Attribut aus und ersetzt ggf. die symbolischen 
# Werte durch entsprechenden Numerischen.
###############################################################################
sub
_convertValueForDevice($$)
{
	my ($name, $value) = @_;
	my $eventMap = AttrVal($name, 'eventMap', undef);
	
	if(defined($eventMap)) {
    my @list = split(/\s+/, trim($eventMap));
    foreach (@list) {
      my($nVal, $sVal) = split(/:/, $_);
      if($value eq $sVal) {
        $value = $nVal;
        if(lc($value) eq 'on') {$value = 100;}
	      if(lc($value) eq 'off') {$value = 0;}
        last;
      }
    }
	}
	
	return $value;
}

# Liefert den aktuelen numerisschen Wert eines Geraetezustandes. 
# Setzt bei Bedarf die symbolische Werte (up, down) in ihre 
# Zahlenwertrepresentationen um.
#sub
#_getDeviceValueNumeric($)
#{
#  return _convertSymParams(Value($_[0]));
#}

# Setzt Parameter-Werte fuer symbolische Werte in ihre Zahlenwerte um.
# up = 100, down = 0
#sub
#_convertSymParams($)
#{
#  my $value = $_[0];
#  # Endwerte beruecksichtigen, Gross-/Kleinschreibung ignorieren
#  $value = lc($value);
#  if($value eq "down" || $value eq "runter" || $value eq "off") { return 0; } 
#  elsif($value eq "up" || $value eq "hoch" || $value eq "on") { return 100; } 
#  elsif($value =~ /schatten.*/) { return 80; } 
#  elsif($value =~ /halb.*/ ) { return 60; } 
#  # Numerische Werte erwartet
#  my $ivalue = int($value);
#  if($ivalue < 0) { return 0; }
#  elsif($ivalue > 100) { return 100; }
#  elsif($ivalue > 0) { return $ivalue; }
#  # Pruefung, ob bei 0 da wirklich eine Nummer war 
#  if($value eq $ivalue or $value eq "0 %" or $value eq "0%") { return 0; }
#  # Default-Fall: Bei unbekannten Werten soll Rollo offen sein
#  return 100; 
#}

# --- server heartbeat / watchdog ---->
sub tickHeartbeat($)
{
	my ($device) = @_;
	my $v = int(Value($device));#_getDeviceValueNumeric($device);
	$v = $v+1; 
	if($v>=60) {$v=0;} 
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

#my @@fhts=devspec2array("TYPE=FHT");; 


######################################################
sub
SetTempList_Heizung($$$$$$$$)
{
	my($dev, $mo, $di, $mi, $do, $fr, $sa, $so) = @_;
	fhem ("set ".$dev." tempListMon prep ".$mo);
  fhem ("set ".$dev." tempListTue prep ".$di);
  fhem ("set ".$dev." tempListWed prep ".$mi);
  fhem ("set ".$dev." tempListThu prep ".$do);
  fhem ("set ".$dev." tempListFri prep ".$fr);
  fhem ("set ".$dev." tempListSat prep ".$sa);
  fhem ("set ".$dev." tempListSun exec ".$so);
}

######################################################
# Temperatur-Liste fürs Bad
# setzen per Aufruf von "{SetTempList_Heizung_OG_Bad}"
# Vorsicht, bei HM-CC-RT-DN (im Unterschied zum z.B. HM-CC-TC), ist 
# ein anderer Channel zu nehmen. Zudem wird mit prep|exec gearbeitet, 
# um nicht alle Zeilen als einzelnen Befehl zu senden, 
# sondern per "prep" erst alles zusammenzufassen 
# und dann per "exec" an das Thermostat zu senden.
# Also als ein einziger Befehl statt sieben. Vermeidet "NACKs"
######################################################
sub
SetTempList_Heizung_OG_Bad()
 {
    my($mo, $di, $mi, $do, $fr, $sa, $so);
 	  
 	  $mo = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $di = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $mi = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $do = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $fr = "02:00 20.0 05:00 19.5 09:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5";
 	  $sa = "02:00 20.0 06:30 19.5 10:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5";
 	  $so = "01:00 20.0 06:30 19.5 10:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5";
 	  
    SetTempList_Heizung("OG_BZ_TT01_Clima", $mo, $di, $mi, $do, $fr, $sa, $so);
    SetTempList_Heizung("OG_BZ_WT01_Climate", $mo, $di, $mi, $do, $fr, $sa, $so);

   #{ fhem ("set OG_BZ_WT01_Climate tempListMon prep 01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5")};
   #{ fhem ("set OG_BZ_WT01_Climate tempListTue prep 01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5")};
   #{ fhem ("set OG_BZ_WT01_Climate tempListWed prep 01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5")};
   #{ fhem ("set OG_BZ_WT01_Climate tempListThu prep 01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5")};
   #{ fhem ("set OG_BZ_WT01_Climate tempListFri prep 02:00 20.0 05:00 19.5 09:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5")};
   #{ fhem ("set OG_BZ_WT01_Climate tempListSat prep 02:00 20.0 06:30 19.5 10:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5")};
   #{ fhem ("set OG_BZ_WT01_Climate tempListSun exec 01:00 20.0 06:30 19.5 10:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5")};

}
# End SetTempList_Heizung_OG_Bad

######################################################
# Temperatur-Liste fürs Duschbad
# setzen per Aufruf von "{SetTempList_Heizung_OG_DBad}"
# Vorsicht, bei HM-CC-RT-DN (im Unterschied zum z.B. HM-CC-TC), ist 
# ein anderer Channel zu nehmen. Zudem wird mit prep|exec gearbeitet, 
# um nicht alle Zeilen als einzelnen Befehl zu senden, 
# sondern per "prep" erst alles zusammenzufassen 
# und dann per "exec" an das Thermostat zu senden.
# Also als ein einziger Befehl statt sieben. Vermeidet "NACKs"
######################################################
sub
SetTempList_Heizung_OG_DBad()
 {
    my($mo, $di, $mi, $do, $fr, $sa, $so);
 	  
 	  $mo = "01:00 20.0 05:00 20.5 09:00 22.0 16:00 21.0 18:00 21.5 24:00 22.5";
 	  $di = "01:00 20.0 05:00 20.5 09:00 22.0 16:00 21.0 18:00 21.5 24:00 22.5";
 	  $mi = "01:00 20.0 05:00 20.5 09:00 22.0 16:00 21.0 18:00 21.5 24:00 22.5";
 	  $do = "01:00 20.0 05:00 20.5 09:00 22.0 16:00 21.0 18:00 21.5 24:00 22.5";
 	  $fr = "02:00 20.0 05:00 20.5 09:00 22.0 15:00 21.0 18:00 21.5 24:00 22.5";
 	  $sa = "02:00 20.0 06:30 20.5 10:00 22.0 15:00 21.0 18:00 21.5 24:00 22.5";
 	  $so = "01:00 20.0 06:30 20.5 10:00 22.0 15:00 21.0 18:00 21.5 24:00 22.5";
 	  
    SetTempList_Heizung("OG_DZ_TT01_Clima", $mo, $di, $mi, $do, $fr, $sa, $so);
    SetTempList_Heizung("OG_DZ_WT01_Climate", $mo, $di, $mi, $do, $fr, $sa, $so);
}
# End SetTempList_Heizung_OG_Duschbad

# Temperatur-Liste fürs Wohnzimmer
sub
SetTempList_Heizung_OG_Wohnzimmer()
 {
 	  my($mo, $di, $mi, $do, $fr, $sa, $so);
 	   	  
 	  $mo = "01:00 20.0 06:30 19.0 10:00 21.5 15:00 21.0 22:00 21.5 24:00 21.0";
 	  $di = "01:00 20.0 06:30 19.0 10:00 21.5 15:00 21.0 22:00 21.5 24:00 21.0";
 	  $mi = "01:00 20.0 06:30 19.0 10:00 21.5 15:00 21.0 22:00 21.5 24:00 21.0";
 	  $do = "01:00 20.0 06:30 19.0 10:00 21.5 15:00 21.0 22:00 21.5 24:00 21.0";
 	  $fr = "01:00 20.0 06:30 19.0 10:00 21.5 15:00 21.0 22:00 21.5 24:00 21.0";
 	  $sa = "02:00 20.0 06:30 19.0 23:00 22.5 24:00 21.0";
 	  $so = "02:00 20.0 06:30 19.0 23:00 22.5 24:00 21.0";
 	  
    SetTempList_Heizung("EG_WZ_WT01_Climate", $mo, $di, $mi, $do, $fr, $sa, $so);
    SetTempList_Heizung("EG_WZ_TT01_Clima", $mo, $di, $mi, $do, $fr, $sa, $so);
    SetTempList_Heizung("EG_WZ_TT02_Clima", $mo, $di, $mi, $do, $fr, $sa, $so);
}
#---

# Temperatur-Liste fürs Schlafzimmer
sub
SetTempList_Heizung_OG_Schlafzimmer()
 {
 	  my($mo, $di, $mi, $do, $fr, $sa, $so);
 	   	  
 	  $mo = "04:00 18.0 10:00 20.0 19:00 19.0 22:00 18.0 24:00 17.0";
 	  $di = "04:00 18.0 10:00 20.0 19:00 19.0 22:00 18.0 24:00 17.0";
 	  $mi = "04:00 18.0 10:00 20.0 19:00 19.0 22:00 18.0 24:00 17.0";
 	  $do = "04:00 18.0 10:00 20.0 19:00 19.0 22:00 18.0 24:00 17.0";
 	  $fr = "04:00 18.0 10:00 20.0 19:00 19.0 22:00 18.0 24:00 17.0";
 	  $sa = "04:00 18.0 10:00 20.0 19:00 19.0 22:00 18.0 24:00 17.0";
 	  $so = "04:00 18.0 10:00 20.0 19:00 19.0 22:00 18.0 24:00 17.0";
 	  
    SetTempList_Heizung("OG_SZ_WT01_Climate", $mo, $di, $mi, $do, $fr, $sa, $so);
    SetTempList_Heizung("OG_SZ_TT01_Clima", $mo, $di, $mi, $do, $fr, $sa, $so);
}
#---


###############################################################################
my $debounce_map;
###############################################################################
# Eine Art Entprellung. 
# Es wird geprüft, ob der Schluessel in der angegebenen Zeit bereits 
# angefragt wurde. Dann wird liefert 1 (true), sonst 0 (false).
# Damit kann z.B. sichergestellt werden, dass nur ein Befehl 
# in der angegebenen Zeit ausgefuehrt. Nuetzlich bei notify-Befehlen.
#
# Parameter: Key - Schluessel; time - Zeit in Sekunden
###############################################################################
sub
debounce($$)
{
	my($key, $dtime) = @_;
  
  my $ctime = time();
  my $otime = $debounce_map->{$key};
  
  if(!defined($otime)) {
  	# neuer Key, Zeitstempel speichern
  	$debounce_map->{$key}=$ctime;
  	return 1;
  }
  
  # Zeitablauf pruefen
  my $delta = $otime+$dtime-$ctime;
  if($delta gt 0) {
  	# Zeitfenster noch nicht abgelaufen
  	return 0;
  }
  
  # Zeit abgelaufen, Zeitstempel redefinieren
  $debounce_map->{$key}=$ctime;
  return 1;
}

###############################################################################
# Für den relativen Luftdruck relDruck() werden drei Parameter benötigt: 
#   portvalue, Aussentemperatur am Messort, Höhe des Messortes über N.N.
# Meine Höhe: 49m
# Die Werte Temperatur und Höhe haben direkten Einfluß auf die Berechnung 
# des relativen Luftdrucks, der zu Vergleichszwecken immer auf Meereshöhe 
# bezogen und temperaturabhängig ist.
# Eigentlich spielt auch die Luftfeuchte noch eine Rolle, 
# aber der Einfluß ist so marginal, dass er sich lediglich 
# in Nachkommastellen auswirkt. 
# Deshalb wurde darauf verzichtet, diesen Parameter zu berücksichtigen.
#
# Die Umrechnung selbst erfolgt anhand der Empfehlung 
# des Deutschen Wetterdienste, die auch in Wikipedia gut erklärt ist.
###############################################################################
sub
relDruck($$$){
  # Messwerte
  my $Pa   = $_[0];
  my $Temp = $_[1];
  my $Alti = $_[2];

  # Konstanten
  my $g0 = 9.80665;
  my $R  = 287.05;
  my $T  = 273.15;
  my $Ch = 0.12;
  my $a  = 0.065;
  my $E  = 0;

  if($Temp < 9.1){
    $E = 5.6402*(-0.0916 + exp(0.06 * $Temp));
  } else {
    $E = 18.2194*(1.0463 - exp(-0.0666 * $Temp));
  }

  my $xp = $Alti * $g0 / ($R*($T+$Temp + $Ch*$E + $a*$Alti/2));
  my $Pr = $Pa*exp($xp);
  return int($Pr);
}

#sub
#teststruc($) {
#	my($name) = @_;
#	my @ret = struct2Array($name, 'CUL_HM');
#  #my @ret = struct2Array($name, undef);
#  Log 3, ">>---------------->".join(", ",@ret);
#  Log 3, ">>---------------->".@ret;
#  return @ret;
#}

###############################################################################
# Geht die angegebene Struktur rekursiv durch und liefert alle Elementen 
# eines angegebenen Types zurueck. 
# Parameter: 
#  Name:   Name der Struktur
#  Target: Typ der gesuchten Elemente (undef für alles, was nicht Struktur ist)
#  (ret - Parameter fuer die Rekursion, soll beim ersten Aufruf unterbleiben)
###############################################################################
sub
struct2Array($$;@) {
  my($name,$target,@ret) = @_;
  if(defined($name)) {
  	my $dev = $defs{$name};
  	my $type = $dev->{TYPE};
  	if($type eq 'structure') {
      #my @a = {DEF};
      # interne Struktur auslesen
      foreach my $kname (keys($dev->{CONTENT})) {
        @ret = struct2Array($kname,$target,@ret);
      }
    } else {
    	if(!defined($target) || $type eq $target) {
    		#Log 3, ">>>>>>>>>>>>>>>".$name;
    		push(@ret,$name);
    	} else {
    		# ignore
    		Log 5, "unexpected type: ".$name;
    	}
    }
  }
  return @ret;
}

# time2dec und dec2hms dienen dazu, Uhrzeiten als Dezimalwerte zu verwenden (und umgekehrt)
sub time2dec($){
  my ($h,$m,$s) = split(":", shift);
  $m = 0 if(!$m);
  $s = 0 if(!$s);
  my $t  = $m * 60;
     $t += $s;
     $t /= 3600;
     $t += $h;
  return ($t)
}

sub dec2hms($){
  my ($t) = @_;
  my $h = int($t);
  my $r = ($t - $h)*3600;
  my $m = int($r/60);
  my $s = $r - $m*60;
  return sprintf("%02d:%02d:%02d",$h,$m,$s);
}

# Ausrechnet aus der Zahl der Sekunden Anzeige in Stunden:Minuten:Sekunden.
sub sec2hms($){
  my ($t) = @_;
  my $h = int($t/3600);
  my $r = $t - ($h*3600);
  my $m = int($r/60);
  my $s = $r - $m*60;
  return sprintf("%02d:%02d:%02d",$h,$m,$s);
}

# Ausrechnet aus der Zahl der Sekunden Anzeige in Stunden:Minuten:Sekunden.
sub sec2Dauer($){
  my ($t) = @_;
  my $h = int($t/3600);
  my $r = $t - ($h*3600);
  my $m = int($r/60);
  my $s = $r - $m*60;
  return sprintf("%02d Std. %02d Min. %02d Sec.",$h,$m,$s);
}

#  2014-06-16 08:46:18
sub dateTime2dec($){
	my($date,$time) = split(" ", shift);
	my ($hour,$min,$sec) = split(":", $time);
  my ($year,$mon,$mday) = split("-", $date);
  
  #return "$year/$mon/$mday | $hour:$min:$sec";
  my $z = timelocal($sec,$min,$hour,$mday,$mon-1,$year);
  #my $z = mktime($s,$m,$h,$year,$mon,$day);
  
  return ($z)
}

sub checkOWTHERMTimeOut() {
	my @a = devspec2array("TYPE=OWTHERM");
	my $readingsName = "temperature";
	my $max = 300; # in Sekunden
	
	my $ar = checkDeviceReadingUpdateTimeOut($readingsName,$max,\@a);
	my $rText = "Dead OWTHERM devices: ";
	if($ar) {
		$rText.="\r\n";
	  foreach my $dName (sort(keys %{$ar})) {
	  	$rText.=$dName." : ".$ar->{$dName};
		  $rText.="\r\n";
	  }
  } else {
  	$rText.="none";
  	$rText.="\r\n";
  }
	
	return $rText;
}

sub checkDeviceReadingUpdateTimeOut($$$) {
	my($readingsName, $max, $devArray) = @_;
	#Log 3, "YYYYYXXXXXXXX:".$readingsName.":".$max.":".$devArray->[0];
	my $ret;
	foreach my $devName (@$devArray) {
		#Log 3, "CCCCCCCCCC:".$devName;
 	  my $readingsTime = ReadingsTimestamp($devName, $readingsName, undef);
 	  if(defined($readingsTime)) {
 	 	  my $rTimeNum = dateTime2dec($readingsTime);
 	 	  if(defined($rTimeNum)) {
 	 	    my $timeDiff = int(time()) - $rTimeNum;
 	 	    if($timeDiff>$max) {
 	 	    	#$ret->{$devName}="dead seit ".sec2Dauer($timeDiff);
 	 	    	#$ret->{$devName}="dead seit ".sec2hms($timeDiff);
 	 	    	$ret->{$devName}="dead seit ".$readingsTime;
 	 	    }
 	 	    #Log 3, "AAAAAAAAAAAAAAAA:".$timeDiff;
 	 	  } else {
 	 	  	$ret->{$devName}="dead / unbekannt";
 	 	  	#push(@ret,"$devName : unknown");
 	 	  }
 	  }
  }
  
  return $ret;
}

# --- Utils -------------------------------------------------------------------

###############################################################################
# Liefert Informationen zu dem angegebenen Device(s).
# Param: 
#   SuchString: folgt der devspec Logik
#   Datensatz (optional): gewuenschte internal Daternsatz, 
#                         fehlt dieser, wird  DEF ausgelesen.
# 
#   Rueckgabe: Array mit den Informationen zu den gesuchten Geraeten.
#   Beispiel: my @gplotFiles = defInfo('TYPE=SVG','GPLOTFILE');
#    Man erhält ein array, das die Namen aller in der 
#    aktuellen Konfiguration verwendeten gplot-Dateien enthält.
###############################################################################
# > Das Modul ist in 99_Utils aufgenommen <
#sub defInfo($;$) {
#  my ($search,$internal) = @_;
#  $internal = 'DEF' unless defined($internal);
#  my @ret;
#  my @etDev = devspec2array($search);
#  foreach my $d (@etDev) {
#    next unless $d;
#    push @ret, $defs{$d}{$internal};
#  }
#  return @ret;
#}

sub setValue($$) {
  my($devName, $val) = @_;
  fhem("set ".$devName." ".$val);
}

sub setReading($$$) {
  my($devName, $rName, $val) = @_;
  fhem("setreading ".$devName." ".$rName." ".$val);
}


# Rundet eine Zahl ohne Nachkommastellen
sub rundeZahl0($) {
	my($val)=@_;
	# Prüfen, ob numerisch
	#if(int($val)>0) {
		$val = int($val+0.5);
	#}
	return $val;
}

# Rundet eine Zahl mit 1-er Nachkommastelle
sub rundeZahl1($) {
	my($val)=@_;
	return undef unless defined($val);
	# Prüfen, ob numerisch
	#if(int($val)>0) {
		$val = int(10*$val+0.5)/10;
	#}
	return $val;
}

# Rundet eine Zahl mit 2 Nachkommastellen
sub rundeZahl2($) {
	my($val)=@_;
	# Prüfen, ob numerisch => Provlemen mit Zahlen < 1
	#if(int($val)>0) {
		$val = int(100*$val+0.5)/100;
	#}
	return $val;
}

###############################################################################
# Schnittmenge, Differenzmenge oder die Vereinigungsmenge 
# der Elemente zweier Listen erstellen
# Uebergabe der Parameter als Zeiger!!!
# Aufruf: 
#   @a=(...);@b=(...); arraysVergleich(\@a, \@b); #benannte Zeiger mit \
#   arraysVergleich(["six","seven", "eight"], [6,7,8,9]); #anonyme zeiger
# Rueckgabe: HASH mit Referenzen auf 3 Arrays und ein Hash:
#   Vereinigung, Schnittmenge, Different und Hash mit Elementen und deren Anzahl
# Beispiel: (arraysVergleich(["a","b", "c"], ["c","d","e","f"]))[0] liefert 
#   die Vereinigung, ...[1], die Schnittmenge etc.
# Beispiel fuer Zugriffe: ...[0][1]; bei Hash: ...[3]{c} liefert 2.
# Weil Hashes unsortiert sind, wird die Reihenfolge in den Ergebnisarrays beliebig sein!
###############################################################################
sub arraysVergleich($$) {
	#gewinnen der ganzen arrays:
  my @array1=@{$_[0]};
  my @array2=@{$_[1]};
	
	#TODO: Reihenfolge behalten (array1):
	# Union=(@array1, @array2);
	
	my (@union, @intersec, @diff, %count);
  $count{$_}++ for (@array1, @array2);
  for my $k (keys %count) {
    push @union, $k;
    #push @{ $count{int($k)} > 1 ? @intersec : @diff }, $k;
    if($count{$k} > 1) {push(@intersec, $k);} else {push(@diff, $k);}
  }
  
  return (\@union, \@intersec, \@diff, \%count);
}











###############################################################################
# Schnittmenge der Elemente zweier Listen
# Uebergabe der Parameter als Zeiger!!!
# Aufruf: 
#   @a=(...);@b=(...); arraysVergleich(\@a, \@b); #benannte Zeiger mit \
#   arraysVergleich(["six","seven", "eight"], [6,7,8,9]); #anonyme zeiger
# Rueckgabe: Array mit den Elementen, der Menge der Ueberschneidung.
###############################################################################
sub arraysIntersec2($$) {
	#gewinnen der ganzen arrays:
  my @array1=@{$_[0]};
  my @array2=@{$_[1]};
	
	#TODO: Reihenfolge behalten (array1):
	# Union=(@array1, @array2);
	
	my (@union, @intersec, @diff, %count);
  $count{$_}++ for (@array1, @array2);
  for my $k (keys %count) {
    push @union, $k;
    #push @{ $count{int($k)} > 1 ? @intersec : @diff }, $k;
    if($count{$k} > 1) {push(@intersec, $k);} else {push(@diff, $k);}
  }
  
  return \@intersec;
}

sub arraysIntesecTest() {
  my @a = ('a','b','c');
  my @b = ('b','c','d');
  
  my @c = arraysIntesec(\@a,\@b);
  
  Log 3,"+++++++++++++++++> a:".Dumper(@a);
  Log 3,"+++++++++++++++++> b:".Dumper(@b);
  Log 3,"+++++++++++++++++> c:".Dumper(@c);  
}

sub arraysIntesec($$) {
	my ($a1,$a2) = @_;
	
	my @array1 = @$a1; # erstes Array
  my @array2 = @$a2; # zweites Array
  my @final = ();  # Schnittmenge

  foreach my $el (@array1) {
    foreach my $el2 (@array2) {
      if (defined $el2 && $el eq $el2) {
        $final[$#final+1] = $el;
        undef $el2;
        last;
      }
    }
  }

  return @final;
}

# Convert between radians and degrees (2π radians equals 360 degrees).
use constant PI => 3.14159265358979;

sub deg2rad {
    my $degrees = shift;
    return ($degrees / 180) * PI;
}

sub rad2deg {
    my $radians = shift;
    return ($radians / PI) * 180;
}

#####Icon Download#####
sub
icondl
{
	my $dllink = shift;
	my $reticon = "";
	my $subicon = "";
	#$reticon .= qx(wget -T 5 -N --directory-prefix=/opt/fhem/www/images/weather/ --user-agent='Mozilla/5.0 Firefox/4.0.1' '$dllink');
	$subicon = substr $dllink,51,-4;
	return $subicon;
}

# alle Proplanta Icons laden
sub ppicondl {
	my $b="http://www.proplanta.de/wetterdaten/images/symbole/";
	foreach my $i (1..14) {
		icondl($b."t".$i.".gif");
	}
	foreach my $i (1..14) {
		icondl($b."n".$i.".gif");
	}
	foreach my $i (0..10) {
		icondl($b."w".$i.".gif");
	}
	foreach my $i (27..34) {
		icondl($b."w".$i.".gif");
	}
	fhem("set WEB rereadicons");
	fhem("set WEBout rereadicons");
	fhem("set WEBphone rereadicons");
	fhem("set WEBtablet rereadicons");
}

# Proplanta Vorhersage mit logProxy Hilfsroutine
sub logProxy_proplanta2Plot($$$$) {
	my ($device, $fcValue, $from, $to) = @_;
	my @rl;
	
	return undef if( !$device );

	if( defined($defs{$device}) ) {
		if( $defs{$device}{TYPE} eq "PROPLANTA" ) {
			@rl = sort( grep /^fc.*_${fcValue}..$/,keys %{$defs{$device}{READINGS}} );
			return undef if( !@rl );
		} else {
			Log3 undef, 2, "logProxy_proplanta2Plot: $device is not a PROPLANTA device";
			return undef;
		}
	}

	my $fromsec = SVG_time_to_sec($from);
	my $tosec   = SVG_time_to_sec($to);
	my $sec = $fromsec;
	my ($h,$fcDay,$mday,$mon,$year);
	my $timestamp;
    
	my $reading;
	my $value;
	my $prev_value;
	my $min = 999999;
	my $max = -999999;
	my $ret = "";

	# while not end of plot range reached
	while(($sec < $tosec) && @rl) {
		#remember previous value for start of plot range
		$prev_value = $value;

		$reading = shift @rl;
                $reading =~ m/^fc([\d]+)_${fcValue}([\d]+)$/;
                $fcDay = $1;
                $h = $2;
		$value = ReadingsVal($device,$reading,undef);
        
		($mday,$mon,$year) = split('\.',ReadingsVal($device,"fc".$fcDay."_date",undef));
		$timestamp = sprintf("%04d-%02d-%02d_%02d:%02d:%02d", $year, $mon, $mday, $h, 0, 0);
		$sec = SVG_time_to_sec($timestamp);
        
		# skip all values before start of plot range
		next if( SVG_time_to_sec($timestamp) < $fromsec );

		# add first value at start of plot range
		if( !$ret && $prev_value ) {
		$min = $prev_value if( $prev_value < $min );
		$max = $prev_value if( $prev_value > $max );
		$ret .= "$from $prev_value\n";
		}

		# done if after end of plot range
		last if( SVG_time_to_sec($timestamp) > $tosec );

		$min = $value if( $value < $min );
		$max = $value if( $value > $max );

		# add actual controll point
		$ret .= "$timestamp $value\n";
	}
	return ($ret,$min,$max,$prev_value);
}

# -----------------------------------------------------------------------------

sub temp2RGB {
   my ($min, $max, $float) = @_;
   my ($rot,$gruen,$blau);

   $float = $float - $min;
   my $faktor = 1020 / ($max - $min);
   my $farbe = round($faktor * $float, 0);

   if ($farbe < 1)
   { $farbe = 0; }

   if ($farbe > 1020)
   { $farbe = 1020; }

   if ($farbe <= 510)
   {
     $rot = 0;
     if ($farbe <= 255)
     {
       $gruen = 0 + $farbe;
       $blau = 255;
     }
     if ($farbe > 255)
     {
       $farbe = $farbe - 255;
       $blau = 255 - $farbe;
       $gruen = 255;
     }
     if ($farbe > 255)
     {
       $farbe = $farbe - 255;
       $blau = 255 - $farbe;
       $gruen = 255;
     }
   }

   if ($farbe > 510)
   {
     $farbe = $farbe - 510;
     $blau = 0;
     if ($farbe <= 255)
     {
       $rot = 0 + $farbe;
       $gruen = 255;
     }
     if ($farbe > 255)
     {
       $farbe = $farbe - 255;
       $gruen = 255 - $farbe;
       $rot = 255;
     }
   }
   return sprintf("%02X%02X%02X", $rot,$gruen,$blau);
}

sub pahColor {
   my ($starttemp,$midtemp2,$endtemp,$temp,$opacity) = @_;

   $opacity //= 255;

   my($uval,$rval,$rval1,$rval2,$rval3);
   my($gval,$gval1,$gval2,$gval3);
   my($bval,$bval1,$bval2,$bval3);

   my $startcolorR =   0;
   my $startcolorG = 255;
   my $startcolorB = 255;

   my $midcolor1R =  30;
   my $midcolor1G =  80;
   my $midcolor1B = 255;

   my $midcolor2R =  40;
   my $midcolor2G = 255;
   my $midcolor2B =  60;

   my $midcolor3R = 160;
   my $midcolor3G = 128;
   my $midcolor3B =  10;

   my $endcolorR = 255;
   my $endcolorG =  69;
   my $endcolorB =   0;

   return sprintf("%02X%02X%02X%02X",$startcolorR,$startcolorG,$startcolorB,$opacity) if ($temp <= $starttemp);
   return sprintf("%02X%02X%02X%02X",$endcolorR,$endcolorG,$endcolorB,$opacity)       if ($temp >  $endtemp);

   if ($temp <= $midtemp2) {
      $uval  = sprintf("%.5f",($temp - $starttemp) / ($midtemp2 - $starttemp));
      $rval1 = sprintf("%.5f",(1-$uval)**2 * $startcolorR);
      $rval2 = sprintf("%.5f",2*(1-$uval) * $uval * $midcolor1R);
      $rval3 = sprintf("%.5f",$uval**2 * $midcolor2R);
      $rval  = sprintf("%.0f",(100*($rval1 + $rval2 + $rval3)+0.5)/100);

      $gval1 = sprintf("%.5f",(1-$uval)**2 * $startcolorG);
      $gval2 = sprintf("%.5f",2*(1-$uval) * $uval * $midcolor1G);
      $gval3 = sprintf("%.5f",$uval**2 * $midcolor2G);
      $gval  = sprintf("%.0f",(100*($gval1 + $gval2 + $gval3)+0.5)/100);

      $bval1 = sprintf("%.5f",(1-$uval)**2 * $startcolorB);
      $bval2 = sprintf("%.5f",2*(1-$uval) * $uval * $midcolor1B);
      $bval3 = sprintf("%.5f",$uval**2 * $midcolor2B);
      $bval  = sprintf("%.0f",(100*($bval1 + $bval2 + $bval3)+0.5)/100);
      return sprintf("%02X%02X%02X%02X",$rval,$gval,$bval,$opacity);
   }

   if ($temp <= $endtemp) {
      $uval  = sprintf("%.5f",($temp - $midtemp2)/($endtemp - $midtemp2));
      $rval1 = sprintf("%.5f",(1-$uval)**2 * $midcolor2R);
      $rval2 = sprintf("%.5f",2 * (1-$uval) * $uval * $midcolor3R);
      $rval3 = sprintf("%.5f",$uval**2 * $endcolorR);
      $rval  = sprintf("%.0f",(100*($rval1+$rval2+$rval3)+0.5)/100);

      $gval1 = sprintf("%.5f",(1-$uval)**2 * $midcolor2G);
      $gval2 = sprintf("%.5f",2 * (1-$uval) * $uval * $midcolor3G);
      $gval3 = sprintf("%.5f",$uval**2 * $endcolorG);
      $gval  = sprintf("%.0f",(100*($gval1+$gval2+$gval3)+0.5)/100);

      $bval1 = sprintf("%.5f",(1-$uval)**2 * $midcolor2B);
      $bval2 = sprintf("%.5f",2*(1-$uval)*$uval*$midcolor3B);
      $bval3 = sprintf("%.5f",$uval**2 *$endcolorB);
      $bval  = sprintf("%.0f",(100*($bval1+$bval2+$bval3)+0.5)/100);
      return sprintf("%02X%02X%02X%02X",$rval,$gval,$bval,$opacity);
   }

}

# -----------------------------------------------------------------------------

# Definition des Devices listen (wie in der fhem.cfg)
sub cfgList($) {
 my ($dev) = shift;
 my $output = "define $dev $defs{$dev}{TYPE} $defs{$dev}{DEF}\n";
 while ( my ($key, $value) = each( $attr{$dev} ) ) {
  $output .= "attr $dev $key $value\n";
 }
 return $output;
}

sub moduleList() {
	my $dir = AttrVal("global" , "modpath",".")."/FHEM";
	my $string = "";
	my $ret = opendir(DIR, $dir) or return "error: ".$!;
	while (my $file = readdir(DIR)){
		next unless (-f "$dir/$file");
		next unless ($file =~ m/\d\d_.*\.pm$/);
		$string = $string."$file\n"
	}
	closedir(DIR);
	return $string;
}

# 52.479399,9.736270 => Kaltenweide
# Zeigt Google-Maps-Karte an.
# Parameter: Lat., Long., Zoom, Breite, Hoehe
sub ShowGoogleMapsCode($$;$$$) {
	my ($lat,$lng,$zoom,$width,$height) = @_;
	$zoom='12' unless $zoom;
	$width='400' unless $width;
	$height='400' unless $height;
	
  my $htmlcode = "";
  
  $htmlcode .= "<script src='https://maps.googleapis.com/maps/api/js?v=3.exp&signed_in=true'></script>";
  $htmlcode .= "<script>";
  $htmlcode .= "function initialize() {  ";
  $htmlcode .= "var myLatlng = new google.maps.LatLng(".$lat.",".$lng.");  ";
  $htmlcode .= "var mapOptions = {    ";
  $htmlcode .= "  zoom: ".$zoom.",    ";
  $htmlcode .= "  center: myLatlng  ";
  $htmlcode .= "};  ";
  $htmlcode .= "var map = new google.maps.Map(document.getElementById('map-canvas'), mapOptions);  ";
  $htmlcode .= "var trafficLayer = new google.maps.TrafficLayer();  ";
  $htmlcode .= "trafficLayer.setMap(map);";
  $htmlcode .= "}";
  $htmlcode .= "google.maps.event.addDomListener(window, 'load', initialize);    ";
  $htmlcode .= "</script>    ";
  $htmlcode .= "<div id='map-canvas' style='width:".$width."px;height:".$height."px;'></div>";
  
  return $htmlcode;
}

# Prueft, ob der angegebener Tag Wochenende oder Feiertag ist (optional)
# Params:
#   day: 0-heute, 1-morgen etc. Wenn nichts angegeben, wird heute angenommen.
#   Holiday-Device: (s. commandref) wird für die Feiertagspruefung verwendet.
#                   falls nicht angegeben, wird im Attribut holiday2we in global
#                   nachgesehen. Falls auch nicht angegeben, wird ignoriert. 
#
sub isWeOrHoliday(;$$) {
  my ($day, $hdev) = @_;
  $day = 0 unless $day;
  $hdev = $attr{global}{holiday2we} unless $hdev;
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
  
  my $twday = $wday+$day;
  $twday = $twday % 7;
  
  my $we = (($twday==0 || $twday==6) ? 1 : 0);
  
  if(!$we && $hdev && $defs{$hdev}) {
    my $v = fhem("get $hdev days $day");
    $we = 1 if($v ne "none");
  }
  
  return $we;
}

sub IstGewitter($)
{
  my $dev = @_;
  my $curTimestamp=time();
  if (  (ReadingsVal($dev,"Warn_0_Start","") le $curTimestamp) &&  (ReadingsVal($dev,"Warn_0_End","") ge $curTimestamp) && (ReadingsVal($dev,"Warn_0_Type","") eq 7)  ) {
    return 'on';
  } else {
    return 'off';
  }
}

sub plan($$) {
      my ($p, $n)= @_;
      my $departure= ReadingsVal($p,"plan_departure_$n","");
      my $arrival= ReadingsVal($p,"plan_arrival_$n","");
      my $ddelay_= ReadingsVal($p,"plan_departure_delay_$n","none");
      my $ddelay= ($ddelay_ eq "none" ? "" : "( $ddelay_)");
      my $adelay_= ReadingsVal($p,"plan_arrival_delay_$n","none");
      my $adelay= ($adelay_ eq "none" ? "" : "( $adelay_)");
      my $conn= ReadingsVal($p,"plan_connection_$n","");
      my $change= ReadingsVal($p,"plan_travel_change_$n",0);
      return sprintf("%s%s - %s%s   %s %sx", $departure, $ddelay, $arrival, $adelay, $conn, $change);
}

1;
