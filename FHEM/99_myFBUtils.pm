##############################################
# $Id: 99_myFBUtils.pm 0001 2013-07-26 13:19:15Z a_schulz $
package main;

#use strict;
#use warnings;
#use POSIX;


sub
myFBUtils_Initialize($$)
{
  my ($hash) = @_;
}

# --- test ---->

sub ShowFritzBoxValues()
  { 
  
    my @FritzAlarmClockTime;
    my @FritzAlarmClockActive;
    my @FritzAlarmClockNumber;
    my @FritzTelName;
    my @FritzAlarmClockWeekdays;
    my @Weekdays;
    my $k;
    
    foreach $k (0..2) {
      my $AStr_Time = "ctlmgr_ctl r telcfg settings/AlarmClock".$k."/Time";
      my $AStr_Active = "ctlmgr_ctl r telcfg settings/AlarmClock".$k."/Active";
      my $AStr_Number = "ctlmgr_ctl r telcfg settings/AlarmClock".$k."/Number";
      my $AStr_Weekdays = "ctlmgr_ctl r telcfg settings/AlarmClock".$k."/Weekdays";
      $FritzAlarmClockTime[$k] = `$AStr_Time`;
      $FritzAlarmClockActive[$k] = `$AStr_Active`;
      $FritzAlarmClockNumber[$k] = `$AStr_Number`;
      $FritzAlarmClockWeekdays[$k] = `$AStr_Weekdays`;
      $FritzAlarmClockActive[$k] =~ s/\s*$//g;
    
      if ($FritzAlarmClockNumber[$k] == "1") {$FritzTelName[$k] = "Wohnzimmer"};
      if ($FritzAlarmClockNumber[$k] == "2") {$FritzTelName[$k] = "Haustür"};
      if ($FritzAlarmClockNumber[$k] == "9") {$FritzTelName[$k] = "alle Telefone"};
      if ($FritzAlarmClockNumber[$k] == "50") {$FritzTelName[$k] = "ISDN Telefone"};
      if ($FritzAlarmClockNumber[$k] == "60") {$FritzTelName[$k] = "Fritzbox 1"};
      if ($FritzAlarmClockNumber[$k] == "61") {$FritzTelName[$k] = "Fritzbox 2"};
      if ($FritzAlarmClockNumber[$k] == "62") {$FritzTelName[$k] = "BMC"};
      $Weekdays[$k] = "";
      my $i;
      foreach $i (reverse 0..6) {
        if ($FritzAlarmClockWeekdays[$k] - 2**$i >= 0) {
          if ($i == 6) {$Weekdays[$k] = "SO ".$Weekdays[$k]};
          if ($i == 5) {$Weekdays[$k] = "SA ".$Weekdays[$k]};
          if ($i == 4) {$Weekdays[$k] = "FR ".$Weekdays[$k]};
          if ($i == 3) {$Weekdays[$k] = "DO ".$Weekdays[$k]};
          if ($i == 2) {$Weekdays[$k] = "MI ".$Weekdays[$k]};
          if ($i == 1) {$Weekdays[$k] = "DI ".$Weekdays[$k]};
          if ($i == 0) {$Weekdays[$k] = "MO ".$Weekdays[$k]};
          $FritzAlarmClockWeekdays[$k] = $FritzAlarmClockWeekdays[$k] - 2**$i;
        } ;
      };
    };
    
    my $TelNewMessages;
    my $n;
    my $Datum = `date -d +"%d.%m.%y 0:00"`;
    my $one_day = 60*60*24 ;
    my $today = strftime "%d.%m.%y", localtime(time);
    $today = $today." 0:00";
    my $tomorrow = strftime "%d.%m.%y", localtime(time+$one_day);
    $tomorrow = $tomorrow." 0:00";
    my $yesterday = strftime "%d.%m.%y", localtime(time-$one_day);
    $yesterday = $yesterday." 0:00";
    my $today2 = strftime "%d.%m.%y %H:%M", localtime(time);
    
    foreach $n (0..3) {
      my $JStr_Duration = "ctlmgr_ctl r telcfg settings/Journal".$n."/Duration";
      my $JStr_Duration_Erg = `$JStr_Duration`;
      my $JStr_Number = "ctlmgr_ctl r telcfg settings/Journal".$n."/Number";
      my $JStr_Number_Erg = `$JStr_Number`;
      my $JStr_Date = "ctlmgr_ctl r telcfg settings/Journal".$n."/Date";
      my $JStr_Date_Erg = `$JStr_Date`;
      my $JStr_Route = "ctlmgr_ctl r telcfg settings/Journal".$n."/Route";
      my $JStr_Route_Erg = `$JStr_Route`;
      my $JStr_Name = "ctlmgr_ctl r telcfg settings/Journal".$n."/Name";
      my $JStr_Name_Erg = `$JStr_Name`;
      if (trim($JStr_Duration_Erg) eq "0:00" && $JStr_Date_Erg ge $today && trim($JStr_Route_Erg) eq "3") {
        $TelNewMessages = $TelNewMessages.$JStr_Date_Erg." ".$JStr_Number_Erg." ";
        if (trim($JStr_Name_Erg) eq "") {$JStr_Name_Erg = "unbekannt"};
        $TelNewMessages = $TelNewMessages."(".trim($JStr_Name_Erg).")"."<BR>";
      }
      $TelNewMessages = $TelNewMessages." ".$JStr_Duration_Erg." ".$JStr_Number_Erg." ".$JStr_Date_Erg." ".$JStr_Route_Erg." ".$JStr_Name_Erg;
    }
    if (trim($TelNewMessages) eq "") {$TelNewMessages = "0"}
    
    my $FritzLANActiveDevices;
    
    foreach $n (0..8) {
      my $JStr_LANDeviceName = "ctlmgr_ctl r landevice settings/landevice".$n."/name";
      my $JStr_LANDeviceName_Erg = `$JStr_LANDeviceName`;
      my $JStr_LANDeviceActive = "ctlmgr_ctl r landevice settings/landevice".$n."/active";
      my $JStr_LANDeviceActive_Erg = `$JStr_LANDeviceActive`;
      my $JStr_LANDeviceOnline = "ctlmgr_ctl r landevice settings/landevice".$n."/online";
      my $JStr_LANDeviceOnline_Erg = `$JStr_LANDeviceOnline`;
      if (trim($JStr_LANDeviceOnline_Erg) eq "1") {
        $FritzLANActiveDevices = $FritzLANActiveDevices.$JStr_LANDeviceName_Erg." (".$n.") ";
      }
    };
    if (trim($FritzLANActiveDevices) eq "") { $FritzLANActiveDevices = "0" }
    
    my %FritzValues =
    (
    "FritzCPUTemperature" => int(`ctlmgr_ctl r power status/act_temperature`).'°',
    "FritzDslConnectionStatus" => `ctlmgr_ctl r dslstatistic status/ifacestat0/connection_status`,
    "FritzDslIP-Adress" => `ctlmgr_ctl r dslstatistic status/ifacestat0/ipaddr`,
    "FritzWLANActiveStations" => `ctlmgr_ctl r wlan settings/active_stations`,
    "TelNewMessagesAB" => `ctlmgr_ctl r tam settings/NumNewMessages`,
    #"TelNewMessages" => $TelNewMessages,
    "TelAlarmClock0" => substr($FritzAlarmClockTime[0],0,2).":".substr($FritzAlarmClockTime[0],2,2).' Uhr, aktiv: '. $FritzAlarmClockActive[0] .', Telefon: '.$FritzTelName[0].', Wochentage: '. $Weekdays[0],
    "TelAlarmClock1" => substr($FritzAlarmClockTime[1],0,2).":".substr($FritzAlarmClockTime[1],2,2).' Uhr, aktiv: '. $FritzAlarmClockActive[1] .', Telefon: '.$FritzTelName[1].', Wochentage: '. $Weekdays[1],
    "TelAlarmClock2" => substr($FritzAlarmClockTime[2],0,2).":".substr($FritzAlarmClockTime[2],2,2).' Uhr, aktiv: '. $FritzAlarmClockActive[2] .', Telefon: '.$FritzTelName[2].', Wochentage: '. $Weekdays[2],
    "FritzLANActiveDevices" => $FritzLANActiveDevices,
    "FritzCapi" => `ctlmgr_ctl r capiotcp settings/enabled`
    );
    
    my $tag;
    my $value;
    my $tr_class = "odd";
    
    my $htmlcode = "";
    $htmlcode .= "<table>\n";
    $htmlcode .= "<tr><td><div class=\"devType\">Parameter</div></td></tr>\n";
    $htmlcode .= "<tr><td>\n";
    $htmlcode .= "<table class=\"block wide\" id=\"Parameter\">\n";
    
    foreach $tag (sort keys %FritzValues)
    {
     $htmlcode .= "<tr class=\"$tr_class\"><td>\n<div class=\"col1\">$tag: </div></td>\n<td><div class=\"col2\">$FritzValues{$tag}</div></td></tr>\n";
     if ($tr_class eq "odd") {$tr_class = "even"} else {$tr_class = "odd"};
    }
    
    $htmlcode .= "<tr class=\"$tr_class\"><td><div class=\"col1\">Datum Uhrzeit: </div></td>\n<td><div class=\"col2\">$today2</div></td></tr>\n";
    $htmlcode .= "</table>\n";
    $htmlcode .= "</td></tr>\n";
    $htmlcode .= "</table>\n";
    return $htmlcode;
  }

1;
