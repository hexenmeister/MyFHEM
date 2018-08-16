##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";

use constant {
 MY_JABBER_ADDR    => 'hexenmeister@jabber.de',
 MY_TELEGRAM_GROUP => "admin"
};

sub myCtrlJabber_sendTelegramMessageToGroup($$);
sub myCtrlJabber_sendTelegramMessageToChat($$);
sub myCtrlJabber_sendJabberMessage($$);

sub
myCtrlJabber_Initialize($$)
{
  my ($hash) = @_;
}

my $useJabber = 0;
my $useTelegram = 1;

sub sendMessageToDefaultChannel($$) {
  my($rcp, $msg) = @_;
  
  if($useJabber) {
    myCtrlJabber_sendJabberMessage($rcp, $msg);
  }
  
  if($useTelegram) {
    myCtrlJabber_sendTelegramMessageToGroup($rcp, $msg);
  }
}

######################################################
# Meldung per Telegram senden an eine User-Gruppe
######################################################
sub myCtrlJabber_sendTelegramMessageToGroup($$)
{
  my($rcp, $msg) = @_;
  fhem('set NN_HA_Net_Telegram out-json {"group":"'.$rcp.'","content":'.'"'.$msg.'"}');
}

######################################################
# Meldung per Telegram senden an eine User-Gruppe
######################################################
sub myCtrlJabber_sendTelegramMessageToChat($$)
{
  my($rcp, $msg) = @_;
  my $find = "\n";
  my $replace = '\n';
  $msg =~ s/$find/$replace/g;
  fhem('set NN_HA_Net_Telegram out-json {"chatId":"'.$rcp.'","content":'.'"'.$msg.'"}');
}

######################################################
# Meldung per Jabber senden
######################################################
sub
myCtrlJabber_sendJabberMessage($$)
{
  my($rcp, $msg) = @_;
  fhem("set ".+DEVICE_NAME_JABBER." msg $rcp $msg");
}

######################################################
# Test only
######################################################
sub
sendJabberEcho()
{
  my $lastsender=ReadingsVal(+DEVICE_NAME_JABBER,"LastSenderJID","0");
  my $lastmsg=ReadingsVal(+DEVICE_NAME_JABBER,"LastMessage","0");
  fhem("set ".+DEVICE_NAME_JABBER." msg ". $lastsender . " Echo: ".$lastmsg);
}

######################################################
# Meldung an mein Handy per Jabber senden
######################################################
sub sendMeMessageToDefaultChannel($)
{
	my($msg) = @_;
	if($useJabber) {
	  myCtrlJabber_sendJabberMessage(+MY_JABBER_ADDR, $msg);
	}
	
	if($useTelegram) {
	  myCtrlJabber_sendTelegramMessageToGroup(+MY_TELEGRAM_GROUP, $msg);
	}
}

#--- User Methods -------------------------------------------------------------

######################################################
# Statusdaten an mein Handy per Jabber senden
# Wird aus Config per at taglich aufgerufen.
######################################################
sub
sendMeStatusMsg()
{
	#my($msg) = @_;
	my $msg = "Status: Umwelt";
	$msg.="\nTemperature: ".fhem("mget umwelt temperature value");
	$msg.="\nLuftfeuchte: ".fhem("mget umwelt humidity value");
	#$msg=$msg."\n  Ost: ";
	##TODO: HAL
	#$msg=$msg."T: ".ReadingsVal("UM_VH_OWTS01.Luft", "temperature", "---")." C";
	##$msg=$msg."\n  : ".$defs{"GSD_1.4"}{STATE};
	#$msg=$msg."\n  West: ";
	#$msg=$msg."T: ".ReadingsVal("GSD_1.4", "temperature", "---")." C,"; 
	#$msg=$msg." H: ".ReadingsVal("GSD_1.4", "humidity", "---")." %,";  
	#$msg=$msg." Bat: ".ReadingsVal("GSD_1.4", "batteryLevel", "---")." V";

  my $msgDead='';	
	my $sensors = HAL_getSensorNames();
  foreach my $sensorname (@$sensors) {
    if(!HAL_isSensorAlive($sensorname)) {
      # info: dead seit
      my $dauer = HAL_gerSensorDeadTimeDurationStr($sensorname);
      if($dauer) {
        $msgDead.="\n".$sensorname.' seit '.$dauer;
      } else {
        $msgDead.="\n".$sensorname;
      }
    }
  }
  if($msgDead) {
   $msg.="\nDead devices:".$msgDead;
  } else {
   $msg.="\nno dead devices"; 
  }
	
  my $msgBat='';
	#$sensors = HAL_getSensorNames();
  foreach my $sensorname (@$sensors) {
    if(HAL_isDeviceLowBat($sensorname)) {
      my $info = HAL_getDeviceBatStatus($sensorname);
      my $deadSt = HAL_isSensorAlive($sensorname)?'(alive)':'(dead)';
      $msgBat.="\n".$sensorname.' : '.$info.' '.$deadSt;
    }
  }
  if($msgBat) {
   $msg.="\nlow batteries:".$msgBat;
  } else {
   $msg.="\nno low batteries"; 
  }

	sendMeMessageToDefaultChannel($msg);
}

######################################################
# Kleines Cmd-Interface
######################################################
sub sendJabberAnswer() {
  my $lastsender=ReadingsVal(+DEVICE_NAME_JABBER,"LastSenderJID","0");
  my $lastmsg=ReadingsVal(+DEVICE_NAME_JABBER,"LastMessage","0");
  sendAnswerToChannel("jabber", $lastsender, $lastmsg);
}

sub sendTelegramAnswer() {
  my $lastsender=ReadingsVal("NN_HA_Net_Telegram","chatId","");
  my $lastmsg=ReadingsVal("NN_HA_Net_Telegram","content","");
  sendAnswerToChannel("telegram", $lastsender, $lastmsg);
}


sub sendAnswerToChannel($$$) {
  my($channel, $lastsender, $lastmsg) = @_;
  
  #my $lastsender=ReadingsVal(+DEVICE_NAME_JABBER,"LastSenderJID","0");
  #my $lastmsg=ReadingsVal(+DEVICE_NAME_JABBER,"LastMessage","0");
  my @cmd_list = split(/\s+/, trim($lastmsg));
  my $cmd = lc($cmd_list[0]);
  # erstes Element entfernen
  shift(@cmd_list);
  #Log 3, "Jabber: ".$lastsender." - ".$lastmsg;
    
  my $newmsg;
  if($cmd eq "status") {
  	#TODO
  	#Log 3, "Jabber: CMD: Status";
  	$newmsg.= "Status: \r\n";
  	my $owtStatus = checkOWTHERMTimeOut();
  	$newmsg.= $owtStatus;
  }
  
  if($cmd eq "umwelt") {
  	#Log 3, "Jabber: CMD: Umwelt";
    $newmsg.= "Umwelt\n";
	  #$newmsg.="\n  Ost: ";
	  ##TODO: HAL
	  #$newmsg.="T: ".ReadingsVal("UM_VH_OWTS01.Luft", "temperature", "---")." C, ";
	  #$newmsg.="B: ".ReadingsVal("UM_VH_HMBL01.Eingang", "brightness", "---").", ";
	  #$newmsg.="Bat: ".ReadingsVal("UM_VH_HMBL01.Eingang", "battery", "---")." ";
	  ##$newmsg.="\n  : ".$defs{"GSD_1.4"}{STATE};
	  #$newmsg.="\n  West: ";
	  #$newmsg.="T: ".ReadingsVal("GSD_1.4", "temperature", "---")." C,"; 
	  #$newmsg.=" H: ".ReadingsVal("GSD_1.4", "humidity", "---")." %,";  
	  #$newmsg.=" Bat: ".ReadingsVal("GSD_1.4", "batteryLevel", "---")." V";
	  #my $newmsg = "Status: Umwelt";
	  #$newmsg.=fhem("mget umwelt all value");
	  $newmsg.="\nTemperature: ".fhem("mget umwelt temperature value");
	  $newmsg.="\nLuftfeuchte: ".fhem("mget umwelt humidity value");
	  $newmsg.="\nLuftdruck:    ".fhem("mget umwelt pressure value");
	  $newmsg.="\nLicht:        ".fhem("mget umwelt luminosity value");
	  $newmsg.="\nTaupunkt:     ".fhem("mget umwelt dewpoint value");
	  $newmsg.="\nAbs. Feuchte: ".fhem("mget umwelt absFeuchte value");
	
  }

  if($cmd eq "system") {
  	#Log 3, "Jabber: CMD: System";
  	#TODO: HAL
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
  	speak($cmd_tail,0);
  	$newmsg.="ok";
  }
  
  if($cmd eq "mget" || $cmd eq "get" || $cmd eq "mg") {
    my $cmd_tail = join(" ",@cmd_list);
    $newmsg.=fhem("mget ".$cmd_tail);
  }
  
  if($channel eq "jabber") {
    if(defined($newmsg)) {
      myCtrlJabber_sendJabberMessage($lastsender, $newmsg);
      #fhem("set ".+DEVICE_NAME_JABBER." msg ". $lastsender . " ".$newmsg);
    } else {
      myCtrlJabber_sendJabberMessage($lastsender, "Unbekanter Befehl: ".$lastmsg);
    	#fhem("set ".+DEVICE_NAME_JABBER." msg ". $lastsender. " Unbekanter Befehl: ".$lastmsg);
    }
  }
    
  if($channel eq "telegram") {
    if(defined($newmsg)) {
      myCtrlJabber_sendTelegramMessageToChat($lastsender, $newmsg);
    } else {
      myCtrlJabber_sendTelegramMessageToChat($lastsender, "Unbekanter Befehl: ".$lastmsg);
    }
  }
  
}

1;
