##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

use constant {
 MY_JABBER_ADDR    => 'hexenmeister@jabber.de'
};

sub
myCtrlJabber_Initialize($$)
{
  my ($hash) = @_;
}


######################################################
# Meldung per Jabber senden
######################################################
sub
sendJabberMessage($$)
{
  my($rcp, $msg) = @_;
  fhem("set ".+DEVICE_NAME_JABBER." msg $rcp $msg");
}

######################################################
# Meldung an mein Handy per Jabber senden
######################################################
sub
sendMeJabberMessage($)
{
	my($msg) = @_;
	sendJabberMessage(+MY_JABBER_ADDR, $msg);
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
	#TODO: HAL
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
  my $lastsender=ReadingsVal(+DEVICE_NAME_JABBER,"LastSenderJID","0");
  my $lastmsg=ReadingsVal(+DEVICE_NAME_JABBER,"LastMessage","0");
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
	  #TODO: HAL
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
  
  if(defined($newmsg)) {
    fhem("set ".+DEVICE_NAME_JABBER." msg ". $lastsender . " ".$newmsg);
  } else {
  	fhem("set ".+DEVICE_NAME_JABBER." msg ". $lastsender . " Unbekanter Befehl: ".$lastmsg);
  }
}

######################################################
# Test
######################################################
sub
sendJabberEcho()
{
  my $lastsender=ReadingsVal(+DEVICE_NAME_JABBER,"LastSenderJID","0");
  my $lastmsg=ReadingsVal(+DEVICE_NAME_JABBER,"LastMessage","0");
  fhem("set ".+DEVICE_NAME_JABBER." msg ". $lastsender . " Echo: ".$lastmsg);
} 


1;
