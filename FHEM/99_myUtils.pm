##############################################
# $Id: 99_myUtils.pm 0000 2014-08-21 00:00:00Z hexenmeister$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;
#use List::Util qw[min max];

# --- Konstanten fuer die verwendeten ElementNamen ----------------------------
use constant {
  ELEMENT_NAME_CTRL_ANWESENHEIT    => "T.DU_Ctrl.Anwesenheit",
  ELEMENT_NAME_GC_ANWESENHEIT      => "GC_Abwesend",
  ELEMENT_NAME_CTRL_ZIRK_PUMPE     => "T.DU_Ctrl.ZP_Mode",
  ELEMENT_NAME_CTRL_BESCHATTUNG    => "T.DU_Ctrl.Beschattung",
  ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT => "T.DU_Ctrl.Rolladen" # reserved for future use
};

# --- Konstanten für die Werte f. Auto, Enabled, Disabled
use constant {
  AUTOMATIC    => "Automatik",
  ENABLED      => "Aktiviert",
  DISABLED     => "Deaktiviert",
  #ON          => "Ein",
  #OFF         => "Aus",
  PRESENT      => "Anwesend",
  ABSENT       => "Abwesend",
  FAR_AWAY     => "Verreist"
};


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
# zum Testen: {_steuerungZirkulationspumpe_getCtrlTable()->{name};;}
sub
_steuerungZirkulationspumpe_getCtrlTable() {
	# zuerst den manuellen Schalter abfragen
	my $zpctrl = ReadingsVal(ELEMENT_NAME_CTRL_ZIRK_PUMPE, "state",undef);
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
	return Value(ELEMENT_NAME_GC_ANWESENHEIT);
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
 	  
 	  $mo = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $di = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $mi = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $do = "01:00 20.0 05:00 19.5 09:00 21.5 16:00 20.0 18:00 20.5 24:00 21.5";
 	  $fr = "02:00 20.0 05:00 19.5 09:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5";
 	  $sa = "02:00 20.0 06:30 19.5 10:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5";
 	  $so = "01:00 20.0 06:30 19.5 10:00 21.5 15:00 20.0 18:00 20.5 24:00 21.5";
 	  
    SetTempList_Heizung("OG_DZ_TT01_Clima", $mo, $di, $mi, $do, $fr, $sa, $so);
    SetTempList_Heizung("OG_DZ_WT01_Climate", $mo, $di, $mi, $do, $fr, $sa, $so);
}
# End SetTempList_Heizung_OG_Duschbad

# Temperatur-Liste fürs Wohnzimmer
sub
SetTempList_Heizung_OG_Wohnzimmer()
 {
 	  my($mo, $di, $mi, $do, $fr, $sa, $so);
 	   	  
 	  $mo = "01:00 20.0 06:30 18.0 10:00 21.0 15:00 20.0 22:00 21.5 24:00 21.0";
 	  $di = "01:00 20.0 06:30 18.0 10:00 21.0 15:00 20.0 22:00 21.5 24:00 21.0";
 	  $mi = "01:00 20.0 06:30 18.0 10:00 21.0 15:00 20.0 22:00 21.5 24:00 21.0";
 	  $do = "01:00 20.0 06:30 18.0 10:00 21.0 15:00 20.0 22:00 21.5 24:00 21.0";
 	  $fr = "01:00 20.0 06:30 18.0 10:00 21.0 15:00 20.0 22:00 21.5 24:00 21.0";
 	  $sa = "02:00 20.0 06:30 18.0 22:00 21.5 24:00 21.0";
 	  $so = "02:00 20.0 06:30 18.0 22:00 21.5 24:00 21.0";
 	  
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
 	   	  
 	  $mo = "04:00 18.0 05:00 19.0 22:00 18.0 24:00 17.0";
 	  $di = "04:00 18.0 05:00 19.0 22:00 18.0 24:00 17.0";
 	  $mi = "04:00 18.0 05:00 19.0 22:00 18.0 24:00 17.0";
 	  $do = "04:00 18.0 05:00 19.0 22:00 18.0 24:00 17.0";
 	  $fr = "04:00 18.0 05:00 19.0 22:00 18.0 24:00 17.0";
 	  $sa = "04:00 18.0 05:00 19.0 22:00 18.0 24:00 17.0";
 	  $so = "04:00 18.0 05:00 19.0 22:00 18.0 24:00 17.0";
 	  
    SetTempList_Heizung("OG_SZ_WT01_Climate", $mo, $di, $mi, $do, $fr, $sa, $so);
    SetTempList_Heizung("OG_SZ_TT01_Clima", $mo, $di, $mi, $do, $fr, $sa, $so);
}
#---

######################################################
# Sprachausgabe ueber Text2Speak Modul
#  Parameter:
#   - text: Auszugebender Text
#   - volume (optional) - Lautstaerke
#     (wenn nicht vorhaneden: wird aktuell gesetzte 
#      Lautstaerke benutzt,
#      wenn 1 oder groesser: dieser Wert wird benutzt,
#      wenn 0: adaptiv gesetzt je nach Fageszeit 
#              (also Nachts wesentlich leiser)
#       (ggf. spaeter adaptiv durch ermitteln der Zimmerlautstaerke)
######################################################
sub speak($;$) {
	my($text,$volume)=@_;
	if(defined ($volume)) {
		if(int($volume) >=1) {
      fhem("set tts volume ".$volume);
    } else {
    	if(int($volume) == 0) {
    	# Adaptiv 
    	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
    	# 5 - sehr leise
    	# 10 - ok
    	# 50 - gut hoerbar
    	# 110 - default / gut laut
    	#
    	# 20:00 - 22:00 => 10
    	# 22:00 - 05:00 =>  5
    	# 05:00 - 07:00 => 10
    	# 07:00 - 08:00 => 50
    	# 08:00 - 20:00 => 100
    	if ($hour>=20 && $hour<22) {$volume=10}
    	if ($hour>=22 || $hour<5)  {$volume=5}
    	if ($hour>=5  && $hour<7)  {$volume=10}
    	if ($hour>=7  && $hour<8)  {$volume=50}
    	if ($hour>=8  && $hour<20)  {$volume=100}
    	
    	fhem("set tts volume ".$volume);
      }
    }
  }
	fhem("set tts tts ".$text);
}

######################################################
# Meldung per Jabber senden
######################################################
sub
sendJabberMessage($$)
{
	my($rcp, $msg) = @_;
  fhem("set jabber msg $rcp $msg");
}

######################################################
# Meldung an mein Handy per Jabber senden
######################################################
sub
sendMeJabberMessage($)
{
	my($msg) = @_;
	sendJabberMessage('hexenmeister@jabber.de', $msg);
}

######################################################
# Statusdaten an mein Handy per Jabber senden
######################################################
sub
sendMeStatusMsg()
{
	#my($msg) = @_;
	my $msg = "Status: Umwelt";
	$msg=$msg."\n  Ost: ";
	$msg=$msg."T: ".ReadingsVal("UM_VH_OWTS01.Luft", "temperature", "---")." C";
	#$msg=$msg."\n  : ".$defs{"GSD_1.4"}{STATE};
	$msg=$msg."\n  West: ";
	$msg=$msg."T: ".ReadingsVal("GSD_1.4", "temperature", "---")." C,"; 
	$msg=$msg." H: ".ReadingsVal("GSD_1.4", "humidity", "---")." %,";  
	$msg=$msg." Bat: ".ReadingsVal("GSD_1.4", "power_main", "---")." V";
	
	sendMeJabberMessage($msg);
}

######################################################
# Kleines Jabber-Cmd-Interface
######################################################
sub
sendJabberAnswer()
{
	my $lastsender=ReadingsVal("jabber","LastSenderJID","0");
  my $lastmsg=ReadingsVal("jabber","LastMessage","0");
  my @cmd_list = split(/\s+/, trim($lastmsg));
  my $cmd = lc($cmd_list[0]);
  # erstes Element entfernen
  shift(@cmd_list);
  #Log 3, "Jabber: ".$lastsender." - ".$lastmsg;
  
  my $newmsg;
  if($cmd eq "status") {
  	#Log 3, "Jabber: CMD: Status";
  	$newmsg.= "Status: \r\n";
  	my $owtStatus = checkOWTHERMTimeOut();
  	$newmsg.= $owtStatus;
  }
  
  if($cmd eq "umwelt") {
  	#Log 3, "Jabber: CMD: Umwelt";
    $newmsg.= "Umwelt";
	  $newmsg.="\n  Ost: ";
	  $newmsg.="T: ".ReadingsVal("UM_VH_OWTS01.Luft", "temperature", "---")." C, ";
	  $newmsg.="B: ".ReadingsVal("UM_VH_HMBL01.Eingang", "brightness", "---").", ";
	  $newmsg.="Bat: ".ReadingsVal("UM_VH_HMBL01.Eingang", "battery", "---")." ";
	  #$newmsg.="\n  : ".$defs{"GSD_1.4"}{STATE};
	  $newmsg.="\n  West: ";
	  $newmsg.="T: ".ReadingsVal("GSD_1.4", "temperature", "---")." C,"; 
	  $newmsg.=" H: ".ReadingsVal("GSD_1.4", "humidity", "---")." %,";  
	  $newmsg.=" Bat: ".ReadingsVal("GSD_1.4", "power_main", "---")." V";
  }

  if($cmd eq "system") {
  	#Log 3, "Jabber: CMD: System";
  	$newmsg.= "CPU Temp: ".ReadingsVal("sysmon", "cpu_temp_avg", "---")." C\n";
  	$newmsg.= "loadavg: ".ReadingsVal("sysmon", "loadavg", "---")."\n";
  	$newmsg.= "Auslastung: ".ReadingsVal("sysmon", "stat_cpu_text", "---")."\n";
  	$newmsg.= "RAM: ".ReadingsVal("sysmon", "ram", "---")."\n";
  	$newmsg.= "Uptime: ".ReadingsVal("sysmon", "uptime_text", "---")."\n";
  	$newmsg.= "Idle: ".ReadingsVal("sysmon", "idletime_text", "---")."\n";
  	$newmsg.= "FHEM uptime: ".ReadingsVal("sysmon", "fhemuptime_text", "---")."\n";
  	$newmsg.= "FS Root: ".ReadingsVal("sysmon", "fs_root", "---")."\n";
  	$newmsg.= "FS USB: ".ReadingsVal("sysmon", "fs_usb1", "---")."\n";
  	$newmsg.= "Updates: ".ReadingsVal("sysmon", "sys_updates", "---")."\n";
  }

  # ggf. weitere Befehle
  
  if($cmd eq "help" || $cmd eq "hilfe" || $cmd eq "?") {
  	$newmsg.= "Befehle: Help (Hilfe), Status, System, Umwelt";
  }
  
  if($cmd eq "fhem") {
    my $cmd_tail = join(" ",@cmd_list);
    $newmsg.=fhem($cmd_tail);
  }
  
  if($cmd eq "perl") {
    my $cmd_tail = join(" ",@cmd_list);
    $newmsg.=eval($cmd_tail);
  }
  #Log 3, "Jabber: response: >".$newmsg."<";
  
  if($cmd eq "say" || $cmd eq "sprich") {
  	my $cmd_tail = join(" ",@cmd_list);
  	#fhem("set tts tts ".$cmd_tail);
  	speak($cmd_tail,0);
  	$newmsg.="ok";
  }
  
  if(defined($newmsg)) {
    fhem("set jabber msg ". $lastsender . " ".$newmsg);
  } else {
  	fhem("set jabber msg ". $lastsender . " Unbekanter Befehl: ".$lastmsg);
  }
}

######################################################
# Test
######################################################
sub
sendJabberEcho()
{
	my $lastsender=ReadingsVal("jabber","LastSenderJID","0");
  my $lastmsg=ReadingsVal("jabber","LastMessage","0");
  fhem("set jabber msg ". $lastsender . " Echo: ".$lastmsg);
}




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

sub setValue($$) {
  my($devName, $val) = @_;
  fhem("set ".$devName." ".$val);
}

sub setReading($$$) {
  my($devName, $rName, $val) = @_;
  fhem("setreading ".$devName." ".$rName." ".$val);
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
	if(Value(ELEMENT_NAME_CTRL_BESCHATTUNG) eq "???" ||  {ReadingsVal(ELEMENT_NAME_CTRL_BESCHATTUNG,"STATE","???")}) {
	  setValue(ELEMENT_NAME_CTRL_BESCHATTUNG, AUTOMATIC);
	}
	
	if(Value(ELEMENT_NAME_CTRL_ANWESENHEIT) eq "???" ||  {ReadingsVal(ELEMENT_NAME_CTRL_ANWESENHEIT,"STATE","???")}) {
    setValue(ELEMENT_NAME_CTRL_ANWESENHEIT, AUTOMATIC);
  }
	#setHomePresence_Present();
	
	if(Value(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT) eq "???" ||  {ReadingsVal(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT,"STATE","???")}) {
    setValue(ELEMENT_NAME_CTRL_ROLLADEN_DAY_NIGHT, AUTOMATIC);
  }
	
	if(Value(ELEMENT_NAME_CTRL_ZIRK_PUMPE) eq "???" ||  {ReadingsVal(ELEMENT_NAME_CTRL_ZIRK_PUMPE,"STATE","???")}) {
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

###############################################################################
# Bereitet Texte zur Ansage auf.
# Ersetzt Umlaute (ä=ae etc.)
###############################################################################
sub prepareTextToSpeak($) {
	my($text) = @_;
	# TODO
	return $text;
}

###############################################################################
# Bereitet Zahlen zur Ansage auf.
# Ersetzt Kommas und Punkte durch das Wort 'Komma'.
###############################################################################
sub prepareNumToSpeak($) {
	my($text) = @_;
	$text =~ s/\./Komma/g;
  $text =~ s/,/Komma/g;
	return $text;
}

# Rundet eine Zahl ohne Nachkommastellen
sub rundeZahl0($) {
	my($val)=@_;
	# Prüfen, ob numerisch
	if(int($val)>0) {
		$val = int($val+0.5);
	}
	return $val;
}

# Rundet eine Zahl mit 1-er Nachkommastelle
sub rundeZahl1($) {
	my($val)=@_;
	# Prüfen, ob numerisch
	if(int($val)>0) {
		$val = int(10*$val+0.5)/10;
	}
	return $val;
}

# Ausrechnet aus der Zahl der Sekunden Ansage in Stunden und Minuten
sub sec2DauerSprache($){
  my ($t) = @_;
  my $d = int($t/86400); # Tage
  my $h = int(($t - ($d*86400))/3600); #int($t/3600);
  my $r = $t - ($h*3600);
  my $m = int($r/60);
  my $s = $r - $m*60;
  my $text="";
  if($d==1) {
  	$text.="Ein Tag ";
    #return sprintf("Ein Tag, %d Stunden und %d Minuten",$d,$h,$m);
  }
  if($d>1) {
  	$text.=$d." Tage ";
    #return sprintf("%d Tage, %d Stunden und %d Minuten",$d,$h,$m);
  }
  if($h==1) {
  	$text.="eine Stunde ";
  }
  if($h>1) {
  	$text.=$h." Stunden ";
  }
  if($m==1) {
    $text.="eine Minute ";
  } 
  if($m>1) {
    $text.=$m." Minuten ";
  }
  if($d==0 && $h==0 && $m==0) {
  	$text=$s." Sekunden";
  }
  return $text;
}

###############################################################################
# Sagt Wetterdaten an
#  Param: Art: Variante der Aussage:
#         0: Kurzansage, 1: Normal
###############################################################################
sub speakWetterDaten(;$) {
	my($art)=@_;
	if(!defined($art)){$art=1;}
	# TODO: Sauber / Abstraktionslayer erstellen
	my $temp = prepareNumToSpeak(rundeZahl1(ReadingsVal("GSD_1.4","temperature","unbekannt")));
	my $humi = prepareNumToSpeak(rundeZahl0(ReadingsVal("GSD_1.4","humidity","unbekannt")));
	if($art==0) {
    speak("Aussentemperatur ".$temp." Grad. Feuchtigkeit ".$humi." Prozent.");
  }
  if($art==1) {
    speak("Die Aussentemperatur betraegt ".$temp." Grad. Die Luftfeuchtigkeit liegt bei ".$humi." Prozent.");
  }
}

###############################################################################
# Sagt Wettervorhersage an.
#  Parameter: Tag: Zahl 1-5 (1-heute, 2-morgen,...) Defaul=2
###############################################################################
sub speakWetterVorhersage(;$) {
	my ($day) = @_;
	if(!defined($day)) {$day=2;}
	
	# TODO: Sauber / Abstraktionslayer erstellen
	my $t1= ReadingsVal("Wetter","fc".$day."_condition",undef);
	my $t2= ReadingsVal("Wetter","fc".$day."_low_c",undef);
	my $t3= ReadingsVal("Wetter","fc".$day."_high_c",undef);
	
	my $text = "";
	if($day==1) {
		$text = "Heute ist es ";
	}
	if($day==2) {
		$text = "Morgen wird es ";
	}
	if($day==3) {
		$text = "Uebermorgen wird es ";
	}
	if($day>3) {
		$text = "Es wird ";
	}	
	if(defined($t1) && defined($t2) && defined($t3)) {
	  $text.=$t1.". ";
	  $text.="Temperatur von ".$t2." bis ".$t3." Grad.";
	  if($day==1) {
	  	# gefuehlte Temperatur
	  	my $tg= ReadingsVal("Wetter","wind_chill",undef);
	  	$text.="Gefuehlte Temperatur aktuell ".$tg." Grad.";
	  	my $tw= ReadingsVal("Wetter","wind_speed",undef);
	  	$text.="Windgeschwindigkeit ".$tw." Kilometer pro Stunde.";
	  }
	} else {
		$text="Leider keine Vorhersage verfuegbar.";
	}
	
	speak(prepareTextToSpeak($text));
}

# Methode für Benachrichtigung beim Klingeln an der Haustuer
sub actHaustuerKlingel() {
	my($since_last, $sinse_l2, $cnt, $cnt_1min)=getGenericCtrlBlock("ctrl_last_haustuer_klingel", "on", 30);
	sendMeJabberMessage("Tuerklingel am ".ReadingsTimestamp('KlingelIn','reading',''));
	
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	# nut am Tage
  if($hour>=6&&$hour<23) {
  	# 0: ---
  	# 1: ---
  	# 2: ? Hundegebell ?
  	# 3: 
  	# 4: 
  	# Wer klingelt da Sturm?
  	if($cnt_1min==0) {
			# NOP
    }
  	if($cnt_1min==1) {
			# NOP
    }
    if($cnt_1min==2) {
      speak(":hund1.mp3:",150);
    }
    if($cnt_1min==3) {
      speak(":hund2.mp3:",130);
    }  
    if($cnt_1min==4) {
      speak(":hund7.mp3:",150);
    }   
  }
}

# Methode für den taster
# Schatet globale Haus-Automatik ein 
# (setzt ELEMENT_NAME_CTRL_BESCHATTUNG aud AUTOMATIC)
sub actHomeAutomaticOn() {
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomaticOn();
	# Tag/Nacht-Steuerung moechte ich hier nicht haben...
	
	# Hier (Sprach)Meldungen:
	# Konzept: ein "Knopf-Bedienung": 
	#   Auswertung: vorheriger Zustand.
	#    Wenn Zustand unverändert: Tageszeitabhängige Meldungen
	#    Auswertung: Wann war dieser Knopf zuletzt gedrueckt? Wie oft?
	my($since_last, $sinse_l2, $cnt, $cnt_1min)=getHomeAutomaticCtrlBlock("on");
	
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	#$hour=5; # XXX Test
	#TODO: Alle Ausgaben umbauen / auslagern / sauber implmentieren
	#TODO: Spezielle Ansage Texte wenn Zustand geaendert ist: 'Nach Hause mommen'
	
	# Nachtansage
	if($hour>=23||$hour<3) {
		# 0: 
		# 1: GuteNachtWunsch, ZirkPumpe
		# 2: Wetter
		# 3: Wetterprognose für den nächsten Tag (Uhrzeit beanchten: vor/ nach 24:00)
		# 
		if($cnt_1min==0) {
		  # Begrüßung nur, wenn laenger als 10 Min.
			if($since_last>=600) {
        speak("Willkommen zurueck!");
      }
      # Dauer nur ansagen, wenn laenger als 30 Min.
      if($since_last>=1800) {
        speak("Abwesenheitsdauer: ".sec2DauerSprache($since_last));
      }
		}
		if($cnt_1min==1) {
			# Nicht zu oft wiederholen
      speak("Gute Nacht!");
      
	    # ZirkPumpe kurz anwerfen	
	    # TODO: Sauber / Abstraktionslayer
      fhem("set EG_HA_SA01.Zirkulationspumpe on-for-timer 120");
    } 
    if($cnt_1min==2) {
      speakWetterDaten();
    }
    if($cnt_1min==3) {
    	if($hour<=23) {
    		# fuer morgen
        speakWetterVorhersage(2);
      } else {
      	# fuer jetzt
        speakWetterVorhersage(1);
      }
    }
    
	}
	
	# Morgensansage
	if($hour>=3&&$hour<10) {
		# 0: Begrüßung
		# 1: Begrüßung, Wetterdaten
		# 2: Wetterprognose
		# 3: Wiederholen: Wetter und Prognose
		if($cnt_1min==0) {
			# Begrüßung nur, wenn laenger als 10 Min.
			if($since_last>=600) {
        speak("Willkommen!");
      }
      # Dauer nur ansagen, wenn laenger als 30 Min.
      if($since_last>=1800) {
        speak("Abwesenheitsdauer: ".sec2DauerSprache($since_last));
      }
    }
		if($cnt_1min==1) {
			# Nicht zu oft wiederholen
      speak("Guten Morgen!");
      speakWetterDaten();
    } 
    if($cnt_1min==2) {
      speakWetterVorhersage(1);
    }
    if($cnt_1min==3) {
      speak("Ok, nochmal!.");
      speakWetterDaten(0);
      speakWetterVorhersage(1);
    }    
  }
  
  # Tagesansage
  if($hour>=10&&$hour<23) {
  	# 0: Begruessung
  	# 1: Begrüßung, Wetter
  	# 2: Wetterprognose (nur bis 14 Uhr?), sonst Aktuelles Wetter
  	# 3: Wiederholen: Wetter und Prognose
  	if($cnt_1min==0) {
			# Begrüßung nur, wenn laenger als 10 Min.
			if($since_last>=600) {
        speak("Willkommen!");
      }
      # Dauer nur ansagen, wenn laenger als 30 Min.
      if($since_last>=1800) {
        speak("Abwesenheitsdauer: ".sec2DauerSprache($since_last));
      }
    }
  	if($cnt_1min==1) {
			# Nicht zu oft wiederholen
      speak("Hallo!");
      speakWetterDaten();
    }
    if($cnt_1min==2) {
    	if($hour<15) {
    		# fuer jetzt
        speakWetterVorhersage(1);
      } else {
      	# fuer morgen
        speakWetterVorhersage(2);
      }
    }
    if($cnt_1min==3) {
      speak("Ok, nochmal!.");
      speakWetterDaten(0);
      if($hour<15) {
    		# fuer jetzt
        speakWetterVorhersage(1);
      } else {
      	# fuer morgen
        speakWetterVorhersage(2);
      }
    }    
  }
  
  # Allgemein 
  if($cnt_1min==4) {
    # TODO: Meldungen und Systemmeldungen
  }
  # 5: Vorstellung
  if($cnt_1min==6) {
    speak("Hi! Ich bin Lea. Ich bin für die Ueberwachung und Steuerung zustaendig.");
    # TODO Versionsangaben
  }
  # 6: schweigen
  # 7/8: Kleiner Scherz ;)
  if($cnt_1min==8) {
    speak("Lass doch den Knopf endlich in Ruhe!");
  }
  if($cnt_1min==9) {
    speak("Mit dir spreche ich nicht mehr!");
  }
  
	if($cnt>0) {
		# wiederholte Aktion (by Aenderung waere cnt=0).
		# Die gleich nacheinander folgende Aufrufe sind bereit oben verarbeitet.
		# Hier koennen davon unabhaengende Sacher erledigt werden.
		# Z.B. ZirkPumpe etc.
		# TODO
	}
	# TODO
}

# Methode für den taster
# Schatet globale Haus-Automatik aus 
# (setzt ELEMENT_NAME_CTRL_BESCHATTUNG aud DISABLED)
sub actHomeAutomaticOff() {
	# Derzeit keine globale Automatik, daher delegieren
	setBeschattungAutomaticOff(); # ?
	
  # Hier (Sprach)Meldungen:
	# Konzept: ein "Knopf-Bedienung": 
	#   Auswertung: vorheriger Zustand.
	#    Wenn Zustand unverändert: Tageszeitabhängige Meldungen
	#    Auswertung: Wann war dieser Knopf zuletzt gedrueckt? Wie oft?
	my($since_last, $sinse_l2, $cnt, $cnt_1min)=getHomeAutomaticCtrlBlock("off");
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
  
  # Nachtansage
	if($hour>=23||$hour<3) {
	  if($cnt_1min==0) {
	  # Begrüßung nur, wenn laenger als 10 Min.
      if($since_last>=300) {
    	  speakWetterDaten(0);
        speak("Viel Spass. Bis spaeter!");
      }
	  }
	}
	
	# Morgensansage
	if($hour>=3&&$hour<10) {
		if($cnt_1min==0) {
	  # Begrüßung nur, wenn laenger als 10 Min.
      if($since_last>=300) {
    	  speakWetterDaten();
        speak("angenhmen Tag!");
      }
	  }
	}
	
	# Tagesansage
  if($hour>=10&&$hour<23) {
  	if($cnt_1min==0) {
	  # Begrüßung nur, wenn laenger als 10 Min.
      if($since_last>=300) {
    	  speakWetterDaten();
        speak("Bis spaeter!");
      }
	  }
  }
	
  # TODO: geoeffnete Fenster melden
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

1;
