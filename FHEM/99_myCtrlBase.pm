##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;
use Time::HiRes qw(gettimeofday);

#use myCtrlHAL;
require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";

sub putCtrlData($$);
sub getCtrlData($);
sub getGenericCtrlBlock($;$$$$$);
sub previewGenericCtrlBlock($;$$$$);
sub removeGenericCtrlBlock($);

sub scheduleTask($$;$$$);
sub scheduleStoredTask($$;$$);
sub listScheduledTasks(;$);

#-------
sub myCtrlBase_scheduleTask($$$;$$$);

my $mhash;
my $timerParam;

# Initialisierung
sub
myCtrlBase_Initialize($)
{
  my ($hash) = @_;
  $mhash = $hash;
  
  $hash->{UndefFn} = "myCtrlBase_Undef";

  myCtrlBase_loadAllScheduledTaskData();

  my $next = int(gettimeofday()) +1; 
  # Parameter fuer die HauptZeitschleife
  $timerParam -> {'next'} = $next;
  # Parameter fuer Heartbeat-Methode
  $timerParam -> {'haertbeat_last'} = $next;
  $timerParam -> {'haertbeat_interval'} = 60;
  InternalTimer($next, 'myCtrlBase_ProcessTimer', $timerParam, 0);
  Log 2, "AutomationControlBase: initialized";
  return $hash;
}

sub myLog($$$) {
   my ( $hash, $loglevel, $text ) = @_;
   my $xline       = ( caller(0) )[2];
   
   my $xsubroutine = ( caller(1) )[3];
   my $sub         = ( split( ':', $xsubroutine ) )[2];
   $sub="?" unless $sub;
   #$sub =~ s/SMARTMON_//;

   my $instName = ( ref($hash) eq "HASH" ) ? $hash->{NAME} : $hash;
   $instName="" unless $instName;
   Log3 $hash, $loglevel, "myCtrl $instName: $sub.$xline " . $text;
}


# interne Verarbeitung der periodischen Aufrufen (Steuerung)
sub
myCtrlBase_ProcessTimer(@)
{
  my $param = shift;
  my $now = gettimeofday();
  
  if ($now > $timerParam -> {'haertbeat_last'} + $timerParam -> {'haertbeat_interval'}) {
    $timerParam -> {'haertbeat_last'} = $now;
    # Wichtig ist, dass die Heartbeat-Methode moeglichst schnell ist.
    myCtrlBase_automationHeartbeat();
  }
  
  # Geplante Funktionen pruefen/ausfrufen
  myCtrlBase_handleScheduledTasks();
  
  $param -> {'next'} = int($now) +1;
  InternalTimer($param -> {'next'}, 'myCtrlBase_ProcessTimer', $param, 0);
}

my %scheduledTasks;
my $nexttime;
my $schedcnt=0;

#####################################
# Return the time to the next event (or undef if there is none)
# and call each function which was scheduled for this time
sub
myCtrlBase_handleScheduledTasks() {
  return undef if(!$nexttime);

  my $now = gettimeofday();
  return ($nexttime-$now) if($now < $nexttime);

  $now += 0.01;# need to cover min delay at least
  $nexttime = 0;
  # Check the internal list: unnamed
  foreach my $i (sort { $scheduledTasks{unnamed}{$a}{TRIGGERTIME} <=>
                        $scheduledTasks{unnamed}{$b}{TRIGGERTIME} } keys %{$scheduledTasks{unnamed}}) {
    my $tim = $scheduledTasks{unnamed}{$i}{TRIGGERTIME};
    my $fn = $scheduledTasks{unnamed}{$i}{FN};
    my $arg = $scheduledTasks{unnamed}{$i}{ARG};
    if(!defined($tim) || !defined($fn)) {
      delete($scheduledTasks{unnamed}{$i});
      myCtrlBase_removeScheduledTaskData("n".$i);
      next;
    } elsif($tim <= $now) {
      no strict "refs";
      if(defined($arg)) {
        eval {
        	&{$fn}($arg);
        };
        #Log (3, "scheduled task ($i) error: $@") if $@;
      } else {
      	eval($fn);
      	#Log (3, "scheduled task ($i) error: $@") if $@;
      }
      Log (3, "scheduled task ($i) error: $@") if $@;
      use strict "refs";
      delete($scheduledTasks{unnamed}{$i});
      myCtrlBase_removeScheduledTaskData("n".$i);
    } else {
      $nexttime = $tim if(!$nexttime || $nexttime > $tim);
    }
  }
  
  # Check the internal list: named
  foreach my $i (sort { $scheduledTasks{named}{$a}{TRIGGERTIME} <=>
                        $scheduledTasks{named}{$b}{TRIGGERTIME} } keys %{$scheduledTasks{named}}) {
    my $tim = $scheduledTasks{named}{$i}{TRIGGERTIME};
    my $fn = $scheduledTasks{named}{$i}{FN};
    my $arg = $scheduledTasks{named}{$i}{ARG};
    if(!defined($tim) || !defined($fn)) {
      delete($scheduledTasks{named}{$i});
      myCtrlBase_removeScheduledTaskData($i);
      next;
    } elsif($tim <= $now) {
      no strict "refs";
      if(defined($arg)) {
        eval {
        	&{$fn}($arg);
        };
        #Log (3, "scheduled task ($i) error: $@") if $@;
      } else {
      	eval($fn);
      	#Log (3, "scheduled task ($i) error: $@") if $@;
      }
      Log (3, "scheduled task ($i) error: $@") if $@;
      use strict "refs";
      delete($scheduledTasks{named}{$i});
      myCtrlBase_removeScheduledTaskData($i);
    } else {
      $nexttime = $tim if(!$nexttime || $nexttime > $tim);
    }
  }

  return undef if(!$nexttime);
  $now = gettimeofday(); # possibly some tasks did timeout in the meantime
                         # we will cover them 
  return ($now+ 0.01 < $nexttime) ? ($nexttime-$now) : 0.01;
}

# Plant eine gegebene Funktion zur Ausfuehrung ein.
# Params: 
#   tim: Zeit in Sekunden, nach der Ablauf soll die Funktion aufgerufen werden
#   fn:  Funktion
# Opt. Params:
#   arg: Parameter, der an die angegebene Funktion beim Aufruf uebergeben wird
#        Es kann nur einen geben, mehrere sollen per Referenz (Array, Hash...) uebergeben werden.
#        Wird ein Parameter definiert, wird Funktionsaufruf verwendet, ansonsten eval()!
#        Damit können nicht nur Funktionsnamen, sondern auch Anwesungen verwendet werden.
#   ID_Name: Wenn angegeben, wird die ggf. bereits vorhandene Planung mit dem 
#            gleichen Namen entweder dadurch ersetzt oder die erneute Definition 
#            wird ignoriert.
#   mode: 0 (default): die zweite Definition wird verwofen, solange eine 
#            gleichnamige bereits existiert
#         1: die zweite Definition ersetzt die erste. Dadurch wird die Planzeit ggf. verändert.
#            Aber auch ggf. die Funktion und Argumente.
#         2: die laengste Zeit der beiden Definitionen wird genommen. 
#            Auch die Fn und die Parameter werden von dem "Gewinner" genommen.
sub
scheduleTask($$;$$$) {
	my ($tim, $fn, $arg, $nameID, $nMode) = @_;
	return myCtrlBase_scheduleTask(0, $tim, $fn, $arg, $nameID, $nMode);
}

# Plant eine gegebene Funktion zur Ausfuehrung ein. 
# Task kann keine extra Parameter enthalten, alles soll im String mitgegeben werden.
# Beispiel: "meineFunktion('parameter',123)"
# Die Ausführung wird Neustart-sicher gespeichert. 
# (Bei einem harten unmittelbaren Serverabsturz kann das jedoch nicht garantiert werden.)
#
# Params: 
#   tim: Zeit in Sekunden, nach der Ablauf soll die Funktion aufgerufen werden
#   fn:  Funktion (Aufrufstring ggf. mit parametern)
# Opt. Params:
#   ID_Name: Wenn angegeben, wird die ggf. bereits vorhandene Planung mit dem 
#            gleichen Namen entweder dadurch ersetzt oder die erneute Definition 
#            wird ignoriert.
#   mode: 0 (default): die zweite Definition wird verwofen, solange eine 
#            gleichnamige bereits existiert
#         1: die zweite Definition ersetzt die erste. Dadurch wird die Planzeit ggf. verändert.
#            Aber auch ggf. die Funktion und Argumente.
#         2: die laengste Zeit der beiden Definitionen wird genommen. 
#            Auch die Fn und die Parameter werden von dem "Gewinner" genommen.
sub
scheduleStoredTask($$;$$) {
	my ($tim, $fn, $nameID, $nMode) = @_;
	return myCtrlBase_scheduleTask(1, $tim, $fn, undef, $nameID, $nMode);
}

# Interne Funktion
# Plant eine gegebene Funktion zur Ausfuehrung ein.
# Params: 
#   stored: Task restartsicher speichern (1), oder nicht (0).
#        Nur möglich, wenn keine Funktionsargumente genutzt werden.
#   tim: Zeit in Sekunden, nach der Ablauf soll die Funktion aufgerufen werden
#   fn:  Funktion
# Opt. Params:
#   arg: Parameter, der an die angegebene Funktion beim Aufruf uebergeben wird
#        Es kann nur einen geben, mehrere sollen per Referenz (Array, Hash...) uebergeben werden.
#        Wird ein Parameter definiert, wird Funktionsaufruf verwendet, ansonsten eval()!
#        Damit können nicht nur Funktionsnamen, sondern auch Anwesungen verwendet werden.
#   ID_Name: Wenn angegeben, wird die ggf. bereits vorhandene Planung mit dem 
#            gleichen Namen entweder dadurch ersetzt oder die erneute Definition 
#            wird ignoriert.
#   mode: 0 (default): die zweite Definition wird verwofen, solange eine 
#            gleichnamige bereits existiert
#         1: die zweite Definition ersetzt die erste. Dadurch wird die Planzeit ggf. verändert.
#            Aber auch ggf. die Funktion und Argumente.
#         2: die laengste Zeit der beiden Definitionen wird genommen. 
#            Auch die Fn und die Parameter werden von dem "Gewinner" genommen.
sub myCtrlBase_scheduleTask($$$;$$$)
{
	my ($stored, $tim, $fn, $arg, $nameID, $nMode) = @_;
	
	if(!defined($tim) || !defined($fn)) {
		return;
	}
	
	if(defined($nameID) && !defined($nMode)) {
		$nMode=0; # default
	}
	
	if(!defined($schedcnt)) {
		$schedcnt = 0;
	}
	
	my $now = gettimeofday();
  $tim+=$now;
  
  if(defined($nameID)) {
  	#Log 3, "schedule: named mode";
  	if(defined($scheduledTasks{named}{$nameID})) {
  		if($nMode == 0) {
  			# ignore second definition
  		  $tim = $scheduledTasks{named}{$nameID}{TRIGGERTIME}; # Wichtig fuer die Berechnung der naechsten Ausfuehrungszeit
  			#Log 3, "schedule: definition allready exists, ignore new (mode 0)";
  		} elsif ($nMode == 1) {
  			#Log 3, "schedule: definition allready exists, update (mode 1)";
  			# update first definition
  			$scheduledTasks{named}{$nameID}{TRIGGERTIME} = $tim;
        $scheduledTasks{named}{$nameID}{FN} = $fn;
        $scheduledTasks{named}{$nameID}{ARG} = $arg;
        $scheduledTasks{named}{$nameID}{STORED} = $stored;
        myCtrlBase_saveScheduledTaskData($nameID,$scheduledTasks{named}{$nameID});
  		} else {
  			# update first definition else ignore
  			#Log 3, "schedule: definition allready exists, check time (mode 2)";
        if($scheduledTasks{named}{$nameID}{TRIGGERTIME} < $tim) {
        	#Log 3, "schedule: new time later then old, update (mode 2) => $scheduledTasks{named}{$nameID}{TRIGGERTIME} vs. $tim";
  			  $scheduledTasks{named}{$nameID}{TRIGGERTIME} = $tim;
          $scheduledTasks{named}{$nameID}{FN} = $fn;
          $scheduledTasks{named}{$nameID}{ARG} = $arg;
          $scheduledTasks{named}{$nameID}{STORED} = $stored;
          myCtrlBase_saveScheduledTaskData($nameID,$scheduledTasks{named}{$nameID});
  			} else {
  				#Log 3, "schedule: new time earlier then old, ignore (mode 2) => $scheduledTasks{named}{$nameID}{TRIGGERTIME} vs. $tim";
  				$tim = $scheduledTasks{named}{$nameID}{TRIGGERTIME}; # Wichtig fuer die Berechnung der naechsten Ausfuehrungszeit
  				#myCtrlBase_saveScheduledTaskData($nameID,$scheduledTasks{named}{$nameID});
  			}
  		}
  	} else {
  		#Log 3, "schedule: new definition";
      $scheduledTasks{named}{$nameID}{TRIGGERTIME} = $tim;
      $scheduledTasks{named}{$nameID}{FN} = $fn;
      $scheduledTasks{named}{$nameID}{ARG} = $arg;
      $scheduledTasks{named}{$nameID}{STORED} = $stored;
      myCtrlBase_saveScheduledTaskData($nameID,$scheduledTasks{named}{$nameID});
    }
  } else {
  	#Log 3, "schedule: unnamed mode";
    $scheduledTasks{unnamed}{$schedcnt}{TRIGGERTIME} = $tim;
    $scheduledTasks{unnamed}{$schedcnt}{FN} = $fn;
    $scheduledTasks{unnamed}{$schedcnt}{ARG} = $arg;
    $scheduledTasks{unnamed}{$schedcnt}{STORED} = $stored;
    myCtrlBase_saveScheduledTaskData("n".$schedcnt,$scheduledTasks{unnamed}{$schedcnt});
    $schedcnt++;
    if($schedcnt>9999999999999999) {
    	$schedcnt=0;
    }
  }
  $nexttime = $tim if(!$nexttime || $nexttime > $tim);
  
  return $tim;
}

###############################################################################
# Listet die geplanten Task auf.
# Params:
#   mode: 0: Alle; 1: unnamed tasks only; 2: named tasks only
###############################################################################
sub listScheduledTasks(;$) {
	my($mode) = @_;
	
	$mode = 0 unless defined($mode);
	
	my $ret="";
	
	#unnamed
	if($mode==0 || $mode==1) {
		foreach my $i (sort { $scheduledTasks{unnamed}{$a}{TRIGGERTIME} <=>
                        $scheduledTasks{unnamed}{$b}{TRIGGERTIME} } keys %{$scheduledTasks{unnamed}}) {
      my $tim = $scheduledTasks{unnamed}{$i}{TRIGGERTIME};
      my $fn = $scheduledTasks{unnamed}{$i}{FN};
      my $arg = $scheduledTasks{unnamed}{$i}{ARG};      
      $ret.= sprintf("%10d: %s [%-40s] (%s)\n",
                     $i, strftime("%d.%m.%Y %H:%M:%S", localtime($tim)),
                     $fn,defined($arg)?join(', ', @$arg):"");
    }
	}
	
	#named
	if($mode==0 || $mode==2) {
		foreach my $i (sort { $scheduledTasks{named}{$a}{TRIGGERTIME} <=>
                        $scheduledTasks{named}{$b}{TRIGGERTIME} } keys %{$scheduledTasks{named}}) {
      my $tim = $scheduledTasks{named}{$i}{TRIGGERTIME};
      my $fn = $scheduledTasks{named}{$i}{FN};
      my $arg = $scheduledTasks{named}{$i}{ARG};      
      $ret.= sprintf("%10s: %s [%-40s] (%s)\n",
                     $i, strftime("%d.%m.%Y %H:%M:%S", localtime($tim)),
                     $fn,defined($arg)?join(', ', @$arg):"");
    }
	}
	
	return $ret;
}

# Clean up
sub
myCtrlBase_Undef($$)
{
  RemoveInternalTimer($timerParam -> {'next'});
  myCtrlBase_saveAllScheduledTaskData();
  Log 2, "AutomationControlBase: clean-up";
  return undef;
}

# liefert gewuenschte Reading zu dem gegebenen Element
sub myCtrlBase_setReading($$$) {
  my($devName, $rName, $val) = @_;
  #fhem("setreading ".$devName." ".$rName." ".$val);
  CommandSetReading("setreading", $devName." ".$rName." ".$val);
}

# liefert angegenen Reading zu dem gegebenen Element
sub myCtrlBase_deleteReading($$) {
  my($devName, $rName) = @_;
  #fhem("deletereading ".$devName." ".$rName);
  CommandDeleteReading("deletereading", $devName." ".$rName);
}

# speichert (Restart-sicher) ein Key/Value-Paar (fuer Steuerungszwecke)
sub putCtrlData($$) {
	my($key, $val) = @_;
  # Ein Dummy als Container verwenden (ein nicht in Frontent sichtbares Reading speichern)
	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
	myCtrlBase_setReading(DEVICE_NAME_CTRL_STORE, $key, $val);
}

# liefert ein zum einem Key gespeicherten Wert (fuer Steuerungszwecke)
# TODO: In Schnitstellenschicht verlagern
sub getCtrlData($) {
	my($key) = @_;
	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
	my $val = ReadingsVal(DEVICE_NAME_CTRL_STORE, $key, undef);
	return $val;
}

# entfernt den Key und den gespeicherten Wert
sub removeCtrlData($) {
	my($key) = @_;
	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
	myCtrlBase_deleteReading(DEVICE_NAME_CTRL_STORE, $key);
}

## speichert (Restart-sicher) ein Key/Value-Paar (fuer Steuerungszwecke)
#sub removeCtrlData($) {
#	my($key) = @_;
#  # Ein Dummy als Container verwenden (ein nicht in Frontent sichtbares Reading speichern)
#	# es ist egal, an welchen Element man diese Angabe 'anhaengt'... nur ein Container
#	deleteReading(DEVICE_NAME_CTRL_STORE, $key);
#}

# speichert ein scheduledTask
sub myCtrlBase_saveScheduledTaskData($$) {
	my($key, $val) = @_;
	if($val->{STORED}) {
  	#TODO: Umformen
	  my $tim = $val->{TRIGGERTIME};
    my $fn = $val->{FN};
    #my $arg = %{$val}->{ARG};      
    #Mit Parametern geht das so infach nicht
    #my $txt= strftime("%d.%m.%Y_%H:%M:%S", localtime($tim)).'|'.$fn.'|'.(defined($arg)?join(', ', @$arg):"");
    my $txt= strftime("%d.%m.%Y_%H:%M:%S", localtime($tim)).'|'.$fn;
	  putCtrlData("ctrl_scheduled_task_".$key, $txt);
	}
}

# laedt Daten zu einem scheduledTask
sub myCtrlBase_loadScheduledTaskData($) {
	my($key) = @_;
	my $val = getCtrlData("ctrl_scheduled_task_".$key);
	#TODO: Umformen, Hash zurueck geben
	return $val;
}

# loescht die gespeicherten Daten zu einem scheduledTask
sub myCtrlBase_removeScheduledTaskData($) {
	my($key) = @_;
	removeCtrlData("ctrl_scheduled_task_".$key);
}

# speichert alle Tasks
sub myCtrlBase_saveAllScheduledTaskData() {
	#TODO
}

# laedt alle Tasks
sub myCtrlBase_loadAllScheduledTaskData() {
	#TODO
}

###############################################################################
# Controlblock: Liefert zu dem Group/Key die Daten der letzten Aufrufe
# Parameter: Group: Gruppe, die Keys der glichen Gruppe werden zusammengefast.
#            Key: Neuer Zustand.
#            Zeitangabe in Sekunden: Fuer diese Zeit wird die Anzahl der Aktionen
#                   der gleichen Gruppe/Key berechnet. Default = 60 (1 Min).
#            sequenceKey: String mit einem Wert, der für die Sequence-(Reihe) 
#                         Erkennung verwendet werden kann. 
#                         Wenn undef, wird ggf. bereits gespeicherte Reihe geloescht.
#                         Wenn angegeben, wird der Wert an die vorhandene Reihe
#                         angehaengt und die (ganze) Reihe zurueckgegeben.
#                         Die Reihe besteht aus den letzten N (s.u.) Keys incl.
#                         der gemessenen Abständen dazwischen (in Sekunden).
#            sequenceCnt: Maximale Länge der Sequenz 
#                         (Der Rest (aelteste Werte) wird abgeschnitten).
#                         Wenn nicht angegeben, wird auf den Wert EQ_ACT_PP_CNT
#                         gekuerzt. Damit wird die max. Zeitliche Dauer 
#                         fuer die Sequence begrenzt (N Sekunden, s.o.)
#                         Es werden auch max. soviele Werte gespeichert.
#            preview:     wenn angegeben und true (=1), dann wird nichts gespeichert.
#                         Der Sinn ist, nachzusehen, wie der Stand ist, 
#                         ohne ihn zu veraendern.
# Return: HASH:
#  SINCE_LAST_SEC     => Zeit seit der letzten Aktion der gleichen Gruppe
#  BETWEEN_2_LAST_SEC => Zeit zw. der letzten und der vorletzten Aktion der Gruppe
#  EQ_ACT_CNT         => Anzahl der Ereignisse der gleichen Gruppe UND Key
#  EQ_ACT_PP_CNT      => Anzahl der Ereignisse der gleichen Gruppe UND Key in letzten N Sekunden
#  EQ_ACT_1MIN_CNT    => Anzahl der Ereignisse der gleichen Gruppe UND Key in der letzten Minute
#  EQ_ACT_15MIN_CNT   => -/- 15
#  EQ_ACT_1HOUR_CNT
#  EQ_ACT_SAME_DAY_CNT=> Anzahl der Ereignisse an dem selben Tag (nicht 24 Stunden)
#  SEQUENCE           => Reihe der angegebenen Keys mit den Zeitwerten (Sec) zw. den Ereignissen
#                        Beispiel: 0:Key1;1.5:Key2;1:Key1 
#                        (erste zahl ist ohne Bedeutung und soll ignoriert werden 
#                        (Zeit der vergangenen Ereignissen))
# TODO: Sequenz kuerzen.
#  LAST_STATE         => Letzter gespeicherte Key.
###############################################################################
sub getGenericCtrlBlock($;$$$$$) {
	my($group, $new_state, $last_time_diff, $sequenceKey, $sequenceCnt, $preview)=@_;
	if(!defined($last_time_diff)) {$last_time_diff=60;}
	if(!defined($new_state)) {$new_state="X";} # Wenn State nicht definiert, irgendwas definiertes nehmen
	
	my ($ctrl_state, $ctrl_dt, 
     $ctrl_cnt, $ctrl_cnt_last_min, 
     $ctrl_sec_since, $ctrl_cnt_last_pp, 
     $ctrl_cnt_last_15min, $ctrl_cnt_last_hour, 
     $ctrl_cnt_same_day, $ctrl_sequence) = parseCtrlData($group);
	
	# Aktuelle Zeitangaben	
	my $c_date = CurrentDate();
	my $c_time = CurrentTime();
	#my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	my ($lsec,$lmin,$lhour,$lmday,$lmonth,$lyear,$lwday,$lyday,$lisdst) = localtime($ctrl_dt);
	#$month+=1, $year+=1900;
	#my $dt_dec = dateTime2dec($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
	my $dt_dec = gettimeofday();
	#$dt_dec=int(($dt_dec+0.5)*10)/10;
	#Log 3, "<<< ".$dt_dec;
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime($dt_dec);
	
	$ctrl_cnt_last_min=int($ctrl_cnt_last_min);
	$ctrl_cnt_last_pp = int($ctrl_cnt_last_pp);
	$ctrl_cnt_last_hour = int($ctrl_cnt_last_hour);
	$ctrl_cnt_same_day = int($ctrl_cnt_same_day);
	$ctrl_cnt_last_15min = int($ctrl_cnt_last_15min);
	$ctrl_sec_since=int($ctrl_sec_since);
	if(!defined($ctrl_state) || $new_state ne $ctrl_state) {
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
  
  # Runden: 2 Nachkommastellen (abschneiden)
  $dt_dec=int($dt_dec*100)/100;
  $ctrl_dt=int($ctrl_dt*100)/100;
  
  my $ctrl_last_since = $dt_dec-$ctrl_dt;
  #Log 3, "_____________> ".$dt_dec." - ".$ctrl_dt." > ".$ctrl_last_since;
  ##$ctrl_last_since=int(($ctrl_last_since*10)+0.5)/10;
  # Runden: 2 Nachkommastellen (abschneiden)
  $ctrl_last_since=int(($ctrl_last_since*100))/100;
  ##$dt_dec=int(($dt_dec+0.5)*100)/100;
  ##$ctrl_dt=int(($ctrl_dt+0.5)*10)/10;
  #Log 3, "-------------> ".$dt_dec." - ".$ctrl_dt." > ".$ctrl_last_since;
  
  if(defined($sequenceKey)) {
  	# Bengrentze Laenge: angegeben, oder die Anzahl der Ereignisse in der angegebener Periode
  	if(!defined($sequenceCnt)) {$sequenceCnt = $ctrl_cnt_last_pp;}
  	# Neuen Schluessel hinzufuegen incl. Zeit seit dem letzten Ereignis
    if($ctrl_sequence ne "") {$ctrl_sequence.=";";}
    $ctrl_sequence.=$ctrl_last_since.":".$sequenceKey;
    # Auf die benoetigte Anzahl kuerzen
    my @sarr = split(/;/,$ctrl_sequence);
    # Letzte N nehmen
    my $slng = scalar(@sarr);
    my $alng = $sequenceCnt<$slng?$sequenceCnt:$slng;
    @sarr= @sarr[$slng-$alng..$slng-1];
    $ctrl_sequence=join(';', @sarr); 
  } else {
  	# Sequence entfernen
  	$ctrl_sequence="";
  }

  if(!$preview) {
  	putCtrlData($group, 
	            $new_state.",".$dt_dec.",".
	            $ctrl_cnt.",".$ctrl_cnt_last_min.",".
	            $ctrl_last_since.",".$ctrl_cnt_last_pp.",".
	            $ctrl_cnt_last_15min.",".$ctrl_cnt_last_hour.",".
	            $ctrl_cnt_same_day.",".$ctrl_sequence);
	}
	
	my $ret;
	$ret->{SINCE_LAST_SEC}=$ctrl_last_since;
	$ret->{BETWEEN_2_LAST_SEC}=$ctrl_sec_since;
	$ret->{EQ_ACT_CNT}=$ctrl_cnt;
	$ret->{EQ_ACT_PP_CNT}=$ctrl_cnt_last_pp;
	$ret->{EQ_ACT_1MIN_CNT}=$ctrl_cnt_last_min;
	$ret->{EQ_ACT_15MIN_CNT}=$ctrl_cnt_last_15min;
	$ret->{EQ_ACT_1HOUR_CNT}=$ctrl_cnt_last_hour;
	$ret->{EQ_ACT_SAME_DAY_CNT}=$ctrl_cnt_same_day;
	$ret->{SEQUENCE}=$ctrl_sequence;
	$ret->{LAST_STATE}=$ctrl_state;
	
	return $ret;
}

# Entfernt den ControlBlock fuer die Gruppe
#   Param: Group: Gruppe
sub removeGenericCtrlBlock($) {
	my($group)=@_;
	removeCtrlData($group);
}

# Zerlegt den String, der zu der gegebener Gruppe gefunden wurde, in seine Einzelteile
# Wenn nichts gefunden, werden default-Werte geliefert.
sub parseCtrlData($) {
	my($group)=@_;
	
	my $ctrl_gl_au = getCtrlData($group);
	# Format: [zustand on|off...],[datum/zeit decimal (sec)],[counter],[counter_last_min],
	#         [sekunden seit letzter aktion],[Anzahl in der letzten Periode],
	#         [Anzahl seit 15 Min],[Anzahl seit 1 Std.],[Anzahl gleicher tag],
	#         [Sequence]
	my $ctrl_cnt=0;
	my $ctrl_state="";
	my $ctrl_dt = undef;
	my $ctrl_cnt_last_min = 0;
	my $ctrl_cnt_last_pp = 0;
	my $ctrl_sec_since = 0;
	
	my $ctrl_cnt_last_15min = 0;
	my $ctrl_cnt_last_hour = 0;
	my $ctrl_cnt_same_day = 0;
	
	my $ctrl_sequence = "";
	
	if(defined($ctrl_gl_au)) {
		# Last used state, Date, Count (eq Key), Cnt last min, cnt between 2 last actions, cnt last N
		($ctrl_state, $ctrl_dt, 
     $ctrl_cnt, $ctrl_cnt_last_min, 
     $ctrl_sec_since, $ctrl_cnt_last_pp, 
     $ctrl_cnt_last_15min, $ctrl_cnt_last_hour, 
     $ctrl_cnt_same_day, $ctrl_sequence)  = split(/,/,$ctrl_gl_au);
	} else {
		$ctrl_cnt=0;
		$ctrl_cnt_last_min = 0;
		$ctrl_cnt_last_pp = 0;
		$ctrl_cnt_last_hour = 0;
		$ctrl_cnt_last_15min = 0;
		$ctrl_cnt_same_day = 0;
  	$ctrl_state=undef;
  	#my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = localtime;
	  #$month+=1, $year+=1900;
	  #$ctrl_dt = dateTime2dec($year."-".$month."-".$mday." ".$hour.":".$min.":".$sec);
	  $ctrl_dt = gettimeofday();
	  #$ctrl_dt=int(($ctrl_dt+0.5)*10)/10;
	  #Log 3, ">>> ".$ctrl_dt;
	}
	
	return ($ctrl_state, $ctrl_dt, 
     $ctrl_cnt, $ctrl_cnt_last_min, 
     $ctrl_sec_since, $ctrl_cnt_last_pp, 
     $ctrl_cnt_last_15min, $ctrl_cnt_last_hour, 
     $ctrl_cnt_same_day, $ctrl_sequence);
}

# Macht die gleichen Berechnungen, wie getGenericCtrlBlock, 
# veraendert aber den gespeicherten Zustand nicht.
sub previewGenericCtrlBlock($;$$$$) {
	my($group, $new_state, $last_time_diff, $sequenceKey, $sequenceCnt)=@_;
	return getGenericCtrlBlock($group, $new_state, $last_time_diff, $sequenceKey, $sequenceCnt,1)
}

# Gleich wie previewGenericCtrlBlock, der Satz wird jedoch erzeugt, falls nicht vorhanden
sub previewGenericCtrlBlockAutocreate($;$$$$) {
	my($group, $new_state, $last_time_diff, $sequenceKey, $sequenceCnt)=@_;
	my $ret = getGenericCtrlBlock($group, $new_state, $last_time_diff, $sequenceKey, $sequenceCnt,1);
	if(!defined($ret->{LAST_STATE})) {
	  $ret = getGenericCtrlBlock($group, $new_state, $last_time_diff, $sequenceKey, $sequenceCnt,0);
	  $ret->{SINCE_LAST_SEC}=99999;
	  $ret->{BETWEEN_2_LAST_SEC}=99999;
	}
	return $ret;
}

sub test_getGenericCtrlBlock() {
	my $d;
	$d = getGenericCtrlBlock("TESTX");
	$d = getGenericCtrlBlock("TEST");
	Log 3,"1.1:".$d->{SINCE_LAST_SEC};
	sleep(1.7);
	$d = getGenericCtrlBlock("TEST");
	Log 3,"1.2:".$d->{SINCE_LAST_SEC};
	
	
	$d = getGenericCtrlBlock("TEST",undef, 0, undef, 0);
  #Log 3,"1:".$d->{SEQUENCE};
  $d = getGenericCtrlBlock("TEST",undef, 60, "SH", 10);
	#Log 3,"2:".$d->{SEQUENCE};
	sleep(1);
	$d = getGenericCtrlBlock("TEST",undef, 60, "SH", 10);
	#Log 3,"3:".$d->{SEQUENCE};
	sleep(1);
	$d = getGenericCtrlBlock("TEST",undef, 60, "LN", 10);
	#Log 3,"4:".$d->{SEQUENCE};
	sleep(2);
	$d = getGenericCtrlBlock("TEST",undef, 60, "SH", 10);
	Log 3,"5:".$d->{SEQUENCE};
}


# --- Automatik und Steuerung -------------------------------------------------

# wird regelmaessig (minuetlich) aufgerufen (AT)
sub myCtrlBase_automationHeartbeat() {
	automationHeartbeat(); # weiterleiten
}

1;
