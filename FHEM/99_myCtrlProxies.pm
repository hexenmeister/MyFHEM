##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
#use List::Util qw[min max];


# Räume
my $rooms;
  $rooms->{wohnzimmer}->{alias}="Wohnzimmer";
  $rooms->{wohnzimmer}->{fhem_name}="1.01_Wohnzimmer";
  # Definiert nutzbare Sensoren. Reihenfolge gibt Priorität an. <= ODER BRAUCHT MAN NUR DIE EINZEL-READING-DEFINITIONEN?
  $rooms->{wohnzimmer}->{sensors}=("wz_raumsensor","wz_wandthermostat","tt_sensor"); 
  $rooms->{wohnzimmer}->{sensors_outdoor}=("hg_sensor"); # Sensoren 'vor dem Fenster'. Wichtig vor allen bei Licht (wg. Sonnenstand)
  # Definiert nutzbare Messwerte einzeln. Hat vorrang vor der Definition von kompletten Sensoren. Reihenfolge gibt Priorität an.
  $rooms->{wohnzimmer}->{measurements}->{temperature}=("wz_raumsensor:temperature"); 
  
# Sensoren
my $sensors;
  $sensors->{wz_raumsensor}->{alias}     ="WZ Raumsensor";
  $sensors->{wz_raumsensor}->{fhem_name} ="EG_WZ_KS01";
  $sensors->{wz_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{wz_raumsensor}->{room}      ="wohnzimmer";
  $sensors->{wz_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{wz_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{wz_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{wz_raumsensor}->{readings}->{humidity}    ->{unit}     ="°C";
  $sensors->{wz_raumsensor}->{readings}->{pressure}    ->{reading}  ="airpress";
  $sensors->{wz_raumsensor}->{readings}->{pressure}    ->{unit}     ="hPa";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx";
  $sensors->{wz_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{wz_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{wz_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  $sensors->{wz_wandthermostat}->{alias}     ="WZ Wandthermostat";
  $sensors->{wz_wandthermostat}->{fhem_name} ="EG_WZ_WT01";
  $sensors->{wz_wandthermostat}->{type}      ="HomeMatic";
  $sensors->{wz_wandthermostat}->{room}      ="wohnzimmer";
  $sensors->{wz_wandthermostat}->{composite} =("wz_wandthermostat_climate"); # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{wz_wandthermostat_climate}->{alias}     ="WZ Wandthermostat";
  $sensors->{wz_wandthermostat_climate}->{fhem_name} ="EG_WZ_WT01_Climate";
  $sensors->{wz_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{wz_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{wz_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{wz_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="°C";
  
  $sensors->{hg_sensor}->{alias}     ="Garten-Sensor";
  $sensors->{hg_sensor}->{fhem_name} ="GSD_1.4";
  $sensors->{hg_sensor}->{type}      ="GSD";
  $sensors->{hg_sensor}->{room}      ="garten";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{bat_voltage}  ->{reading}  ="power_main";
  $sensors->{hg_sensor}->{readings}->{bat_voltage}  ->{unit}     ="V";
  
  $sensors->{tt_sensor}->{alias}     ="Test-Sensor";
  $sensors->{tt_sensor}->{fhem_name} ="GSD_1.1";
  $sensors->{tt_sensor}->{type}      ="GSD";
  $sensors->{tt_sensor}->{room}      ="wohnzimmer";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{tt_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{tt_sensor}->{readings}->{humidity}    ->{unit}     ="°C";
  $sensors->{tt_sensor}->{readings}->{bat_voltage}  ->{reading}  ="power_main";
  $sensors->{tt_sensor}->{readings}->{bat_voltage}  ->{unit}     ="V";
  
  
my $actTab;
  $actTab->{"schatten"}->{checkFn}="";
  #$actTab->{"schatten"}->{disabled}="0"; #1=disabled, 0, undef,.. => enabled
  #$actTab->{"schatten"}->{deviceList}=(); # undef=> alle in devTab, ansonsten nur angegebenen
  $actTab->{"nacht"}->{checkFn}="";
  $actTab->{"test"}->{checkFn}=undef;

my $devTab;
# Default.
  $devTab->{DEFAULT}->{SetFn}="";
  $devTab->{DEFAULT}->{SetFn}="";
  $devTab->{DEFAULT}->{valueFns}->{"nacht"}="0";
# Badezimmer (Ost)
  $devTab->{"bz_rollo"}->{valueFns}->{"schatten"}="{if...}";
  $devTab->{"bz_rollo"}->{SetFn}="";
# Badezimmer (Ost)
  $devTab->{"bz_rollo"}->{valueFns}->{"nacht"}="0";
  $devTab->{"bz_rollo"}->{valueFns}->{"schatten"}="{if...}";
# Kinderzimmer A (Paula) (West)
  $devTab->{"ka_rollo"}->{SetFn}="";
# Kinderzimmer B (Hanna) (Ost)
  $devTab->{"kb_rollo"}->{SetFn}="";
# Kueche (Ost)
  $devTab->{"ku_rollo"}->{SetFn}="";
# Schlafzimmer (West)
  $devTab->{"sz_rollo"}->{SetFn}="";
# Wohnzimmer (West)
  $devTab->{"wz_rollo_l"}->{SetFn}="";
  $devTab->{"wz_rollo_r"}->{SetFn}=""; 

# TODO


sub myCtrlProxies_Initialize($$);

sub myCtrlProxies_getDevices(;$$$);# <DevName/undef>(undef => alles) [<Type>][<room>]
sub myCtrlProxies_getSensors(;$$$$); # <SenName/undef> [<type>][<DevName>][<room>]
sub myCtrlProxies_getRooms();
sub myCtrlProxies_getActions(;$); # <DevName>

sub myCtrlProxies_doAllActions();
sub myCtrlProxies_doAction($$);
sub myCtrlProxies_DeviceSetFn($@);

#------------------------------------------------------------------------------

sub
myCtrlProxies_Initialize($$)
{
  my ($hash) = @_;
}

#- Steuerung fuer manuelle Aufrufe (AT) ---------------------------------------

###############################################################################
# Alle Aktionen aus der Tabelle ausfuehren.
# (für alle Devices, solange nicht anders definiert) 
###############################################################################
sub
myCtrlProxies_doAllActions() {
	Main:Log 3, "PROXY_CTRL:--------> do all ";
	foreach my $act (keys %{$actTab}) {
		my $cTab = $actTab->{$act};
		myCtrlProxies_doAction($cTab, $act);
	}
}

###############################################################################
# Eine bestimmte Aktion ausfuehren.
# (für alle Devices, solange nicht anders definiert) 
###############################################################################
sub
myCtrlProxies_doAction($$) {
	my ($cTab, $actName) = @_;
	
	Log 3, "PROXY_CTRL:--------> do ".$actName;
	
	my $disabled = $cTab->{disabled}; # undef => enabled
	Log 3, "PROXY_CTRL:--------> act ".$actName." disabled:".$disabled;
	if(defined($disabled) && $disabled eq '1') { return }; # wenn disabled => raus
	
	my $checkFn = $cTab->{checkFn}; # undef => ausführen
	Log 3, "PROXY_CTRL:--------> act ".$actName." checkFn:".$checkFn;
	if(defined($checkFn)) {
		my $valueFn = eval $checkFn;
		if(!defined($valueFn)) { return }; # wenn undef => raus
    if( !$valueFn ) { return }; # wenn false => raus
	}
	
	my @devList = $cTab->{deviceList}; # undef => für alle ausführen
	Log 3, "PROXY_CTRL:--------> act ".$actName." deviceList: ".@devList;
	if(@devList) {
	 	foreach my $dev (@devList) {
	 		Log 3, "PROXY_CTRL:--------> act ".$actName." device:".$dev;
		  myCtrlProxies_DeviceSetFn($dev, $actName);
	  }
	} else {
	  foreach my $dev (keys %{$devTab}) {     
	  	Log 3, "PROXY_CTRL:--------> act ".$actName." device:".$dev;
  	  if($dev ne 'DEFAULT') {
  	  	myCtrlProxies_DeviceSetFn($dev, $actName, "www");
  	  }
    }
	}
}                                              

#- Steuerung aus ReadingProxy -------------------------------------------------

###############################################################################
# Eine bestimmte Set-Aktion für ein bestimmtes Gerät ausfuehren.
# (Commando kann gefiltert und verändert werden, 
# d.h. ggf. nicht oder anders ausgeführt)
# Beispiel: Befehl 'schatten' für Rolladen: es wird gfeprüft (für jedes Rollo
# einzeln) ob die Ausführung notwendig ist (richtige Tageszeit?, Temperatur? 
# starke Sonneneinstrahlung?, aus richtiger Richtung?)
# und auch wie stark (wie weit soll Rollo heruntergefahren werden).
###############################################################################
sub
myCtrlProxies_DeviceSetFn($@) {
	my ($DEVICE,@a) = @_;
	my $CMD = $a[0];
  my $ARGS = join(" ", @a[1..$#a]);
  
  #TODO
  Log 3, "PROXY_CTRL:--------> set ".$DEVICE." - ".$CMD." - ".$ARGS;
  my $cmdFn = $devTab->{$DEVICE}->{valueFns}->{$CMD};
  if(defined($cmdFn)) {
  	# TODO
  } else {
    return ""; # pass through cmd to device
  }
}

1;
