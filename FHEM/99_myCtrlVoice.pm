##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

#use myCtrlHAL;

use constant {
 NOTIFICATION_CONFIRM => ":sonic-ring.mp3:"
};

sub
myCtrlVoice_Initialize($$)
{
  my ($hash) = @_;
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
      fhem("set ".+DEVICE_NAME_TTS." volume ".$volume);
    } else {
    	if(int($volume) == 0) {
    	# Adaptiv 
    	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
    	# 5 - sehr leise
    	# 10 - ok
    	# 50 - gut hoerbar
    	# 100 - default / gut laut
    	#
    	# 20:00 - 22:00 => 10
    	# 22:00 - 05:00 =>  5
    	# 05:00 - 07:00 => 10
    	# 07:00 - 08:00 => 50
    	# 08:00 - 20:00 => 100
    	if ($hour>=20 && $hour<22) {$volume=18}
    	if ($hour>=22 || $hour<5)  {$volume=8}
    	if ($hour>=5  && $hour<7)  {$volume=15}
    	if ($hour>=7  && $hour<8)  {$volume=40}
    	if ($hour>=8  && $hour<20)  {$volume=100}
    	
    	fhem("set ".+DEVICE_NAME_TTS." volume ".$volume);
      }
    }
  }
	fhem("set ".+DEVICE_NAME_TTS." tts ".prepareTextToSpeak($text));
}

sub voiceNotificationConfirm() {
  speak(NOTIFICATION_CONFIRM,0);
}

sub voiceDoorbell() {
  #my($since_last, $sinse_l2, $cnt, $cnt_1min)=getGenericCtrlBlock("ctrl_last_haustuer_klingel", "on", 30);
  
  my $ret = getGenericCtrlBlock("ctrl_last_haustuer_klingel", "on", 30);
  my $cnt_1min = $ret->{EQ_ACT_PP_CNT};
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	# nur am Tage
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
      speak(":hund1.mp3:",100);
    }
    if($cnt_1min==3) {
      speak(":hund2.mp3:",80);
    }  
    if($cnt_1min==4) {
      speak(":hund7.mp3:",100);
    }   
  }
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
    speak("Aussentemperatur ".$temp." Grad. Feuchtigkeit ".$humi." Prozent.",0);
  }
  if($art==1) {
    speak("Die Aussentemperatur betraegt ".$temp." Grad. Die Luftfeuchtigkeit liegt bei ".$humi." Prozent.",0);
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
		$text = "Wetter heute ";
	}
	if($day==2) {
		$text = "Morgen ";
	}
	if($day==3) {
		$text = "Uebermorgen ";
	}
	if($day>3) {
		$text = "Wetter in ".($day-1)." Tagen ";
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
	
	speak($text,0);
}

sub voiceActAutomaticOn() {
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
	
	voiceNotificationConfirm();
	
	# Nachtansage
	if($hour>=23||$hour<3) {
		# 0: 
		# 1: GuteNachtWunsch, ZirkPumpe
		# 2: Wetter
		# 3: Wetterprognose fuer den nächsten Tag (Uhrzeit beanchten: vor/ nach 24:00)
		# 
		if($cnt_1min==0) {
		  # Begrueßung nur, wenn laenger als 10 Min.
			if($since_last>=600) {
        speak("Willkommen zurueck!",0);
      }
      # Dauer nur ansagen, wenn laenger als 15 Min.
      if($since_last>=900) {
        speak("Abwesenheitsdauer: ".sec2DauerSprache($since_last),0);
      }
		}
		if($cnt_1min==1) {
			# Nicht zu oft wiederholen
      speak("Gute Nacht!",0);
      
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
		# 0: Begrueßung
		# 1: Begrueßung, Wetterdaten
		# 2: Wetterprognose
		# 3: Wiederholen: Wetter und Prognose
		if($cnt_1min==0) {
			# Begrueßung nur, wenn laenger als 10 Min.
			if($since_last>=600) {
        speak("Willkommen!",0);
      }
      # Dauer nur ansagen, wenn laenger als 15 Min.
      if($since_last>=900) {
        speak("Abwesenheitsdauer: ".sec2DauerSprache($since_last),0);
      }
    }
		if($cnt_1min==1) {
			# Nicht zu oft wiederholen
      speak("Guten Morgen!",0);
      speakWetterDaten();
    } 
    if($cnt_1min==2) {
      speakWetterVorhersage(1);
    }
    if($cnt_1min==3) {
      speak("Ok, nochmal!.",0);
      speakWetterDaten(0);
      speakWetterVorhersage(1);
    }    
  }
  
  # Tagesansage
  if($hour>=10&&$hour<23) {
  	# 0: Begruessung
  	# 1: Begrueßung, Wetter
  	# 2: Wetterprognose (nur bis 14 Uhr?), sonst Aktuelles Wetter
  	# 3: Wiederholen: Wetter und Prognose
  	if($cnt_1min==0) {
			# Begrueßung nur, wenn laenger als 10 Min.
			if($since_last>=600) {
        speak("Willkommen!",0);
      }
      # Dauer nur ansagen, wenn laenger als 15 Min.
      if($since_last>=900) {
        speak("Abwesenheitsdauer: ".sec2DauerSprache($since_last),0);
      }
    }
  	if($cnt_1min==1) {
			# Nicht zu oft wiederholen
      speak("Hallo!",0);
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
      speak("Ok, nochmal!.",0);
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
    speak("Hi! Ich bin Lea. Ich bin fuer die Ueberwachung und Steuerung zustaendig.",0);
    # TODO Versionsangaben: Mit git in /opt/fhem/_Mirror/FHEM: git log -1 --date=short --pretty=format:"%h; %d; %an; %ad; %s" 99_myUtils.pm
		#        => Ausgabe: 0076531;  (HEAD, origin/master, master); hexenmeister; 2014-08-22; Refactoring, Optimizing, Improvement
		#                    (Kurzhash; Bransh; Author; Date(iso); Subject)
		my $cmd="cd ./_Mirror/FHEM/;; git log -1 --date=short --pretty=format:\"%h;; %d;; %an;; %ad;; %s\" 99_myUtils.pm";;qx($cmd);;
		
  }
  # 6: schweigen
  # 7/8: Kleiner Scherz ;)
  if($cnt_1min==8) {
    speak("Lass doch den Knopf endlich in Ruhe!",0);
  }
  if($cnt_1min==9) {
    speak("Mit dir spreche ich nicht mehr!",0);
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

sub voiceActAutomaticOff() {
  # Hier (Sprach)Meldungen:
  # Konzept: ein "Knopf-Bedienung": 
  #   Auswertung: vorheriger Zustand.
  #    Wenn Zustand unverändert: Tageszeitabhängige Meldungen
  #    Auswertung: Wann war dieser Knopf zuletzt gedrueckt? Wie oft?
  my($since_last, $sinse_l2, $cnt, $cnt_1min)=getHomeAutomaticCtrlBlock("off");
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
  
  voiceNotificationConfirm(); #TODO ? Anderer Sound als beim 'On'?
  
  
  my @wndOpen = getWindowDoorList(+STATE_NAME_WIN_OPENED);
  my @wndTilted = getWindowDoorList(+STATE_NAME_WIN_TILTED);
  my @wndNotClosed = getWindowDoorList(+STATE_NAME_WIN_CLOSED,1);
  my $numOpen = scalar(@wndOpen);
  my $numTilted = scalar(@wndTilted);
  my $numNotClosed = scalar(@wndNotClosed);
  my $flag=undef;
  my $text="";
  
  if($numNotClosed>($numOpen+$numTilted)) {
    # Fenster im undefiniertem Zustand => Problem  mit Sensoren melden
    $text.="Achtung, ".($numNotClosed-$numOpen-$numTilted)." Fenster in unbekannten Zustand! Bitte ueberpruefen Sie die Sensoren!";
    $flag=1;
  }
  
  if($numOpen>0) {
    # Offene Fenster
    $text.="Dringende Warnung! Es sind noch ".$numOpen." Fenster offen. ";
    foreach my $d (@wndOpen) {
      $text.=$d." ";
    }
    $flag=1;
  }
  
  if($numTilted>0) {
    # gekippte Fenster
    $text.="Warnung! Es sind noch ".$numTilted." Fenster gekippt. ";
    foreach my $d (@wndTilted) {
      $text.=$d." ";
    }
    $flag=1;
  }
  
  speak($text);
  # TODO: bessere Sprache/Saetze

  if(!$flag) {
  # Nachtansage
	if($hour>=23||$hour<3) {
	  if($cnt_1min==0) {
	  # Begrueßung nur, wenn laenger als 10 Min.
      if($since_last>=300) {
    	  speakWetterDaten(0);
        speak("Bis dann!",0);
      }
	  }
	}
	
	# Morgensansage
	if($hour>=3&&$hour<10) {
		if($cnt_1min==0) {
	  # Begrueßung nur, wenn laenger als 10 Min.
      if($since_last>=300) {
    	  speakWetterDaten();
        speak("angenehmen Tag!",0);
      }
	  }
	}
	
	# Tagesansage
    if($hour>=10&&$hour<23) {
  	  if($cnt_1min==0) {
	    # Begrueßung nur, wenn laenger als 10 Min.
        if($since_last>=300) {
    	  speakWetterDaten();
          speak("Bis spaeter!",0);
        }
      }
    }
  }

}

# TODO:


1;
