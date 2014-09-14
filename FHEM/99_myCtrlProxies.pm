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
  $rooms->{wohnzimmer}->{sensors}=["wz_raumsensor","wz_wandthermostat","tt_sensor"];
  $rooms->{wohnzimmer}->{sensors_outdoor}=["hg_sensor"]; # Sensoren 'vor dem Fenster'. Wichtig vor allen bei Licht (wg. Sonnenstand)
  # Definiert nutzbare Messwerte einzeln. Hat vorrang vor der Definition von kompletten Sensoren. Reihenfolge gibt Priorität an.
  #ggf. for future use
  #$rooms->{wohnzimmer}->{measurements}->{temperature}=["wz_raumsensor:temperature"];
  #$rooms->{wohnzimmer}->{measurements_outdoor}->{temperature}=["hg_sensor:temperature"];
  
# Sensoren
my $sensors;
  $sensors->{wz_raumsensor}->{alias}     ="WZ Raumsensor";
  $sensors->{wz_raumsensor}->{fhem_name} ="EG_WZ_KS01";
  $sensors->{wz_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{wz_raumsensor}->{location}  ="wohnzimmer";
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
  $sensors->{wz_wandthermostat}->{location}  ="wohnzimmer";
  $sensors->{wz_wandthermostat}->{composite} =["wz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{wz_wandthermostat_climate}->{alias}     ="WZ Wandthermostat";
  $sensors->{wz_wandthermostat_climate}->{fhem_name} ="EG_WZ_WT01_Climate";
  $sensors->{wz_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{wz_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{wz_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{wz_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="°C";
  $sensors->{wz_wandthermostat_climate}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{wz_wandthermostat_climate}->{readings}->{dewpoint}    ->{unit}     ="°C";
  
  $sensors->{hg_sensor}->{alias}     ="Garten-Sensor";
  $sensors->{hg_sensor}->{fhem_name} ="GSD_1.4";
  $sensors->{hg_sensor}->{type}      ="GSD";
  $sensors->{hg_sensor}->{location}  ="garten";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{bat_voltage}  ->{reading}  ="power_main";
  $sensors->{hg_sensor}->{readings}->{bat_voltage}  ->{unit}     ="V";
  
  $sensors->{tt_sensor}->{alias}     ="Test-Sensor";
  $sensors->{tt_sensor}->{fhem_name} ="GSD_1.1";
  $sensors->{tt_sensor}->{type}      ="GSD";
  $sensors->{tt_sensor}->{location}  ="wohnzimmer";
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
#oder so?
# $devTab->{"bz_rollo"}->{actions}->{schatten}->{valueFn}="{if...}";
# $devTab->{"bz_rollo"}->{actions}->{schatten}->{value}="80"; # valueFn hat Vorrang, wenn sie undef liefert (oder nicht existiert), dann das hier
# $devTab->{"bz_rollo"}->{actions}->{schatten}->{enabledFn}="{if...}";
# $devTab->{"bz_rollo"}->{actions}->{schatten}->{enabled}="true"; # s.o. 
# $devTab->{"bz_rollo"}->{actions}->{schatten}->{valueFilterFn}="{...}"; #nachdem Wert errechnet wurde, prüft nochmal, ob dieser ggf. korrigiert werden soll (Grenzen etc. z.B. bei geöffneter Tür 'schatten' max. auf X% herunterfahren. etc.)
# Idee: Mehrere Action durch zwischengeschaltete Keys (mehrfach, alphabetisch sortiert): Idee: Wenn hier ein HASH, dann einzelene ausführen, ansonstel ist hier die Fn direkt
# $devTab->{"bz_rollo"}->{actions}->{schatten}->{enabledFn}->{DoorOpenCheck}="{if(sensorVal($CURRENT_DEVICE, wndOpen)!='closed') {...}}"; # DoorOpenCheck ist ein solcher Key.

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


#technisches
sub myCtrlProxies_Initialize($$);


# Rooms
sub myCtrlProxies_getRoom($);
#sub myCtrlProxies_getRooms(;$); # Räume  nach verschiedenen Kriterien?
#sub myCtrlProxies_getActions(;$); # <DevName>

#sub myCtrlProxies_getRoomSensors($);
#sub myCtrlProxies_getRoomOutdoorSensors($);

sub myCtrlProxies_getRoomSensorNames($);
sub myCtrlProxies_getRoomOutdoorSensorNames($);

sub myCtrlProxies_getRoomMeasurementRecord($$);
sub myCtrlProxies_getRoomMeasurementValue($$);


# Sensoren
sub myCtrlProxies_getSensor($);

sub myCtrlProxies_getSensorValueRecord($$);
sub myCtrlProxies_getSensorReadingValue($$);
sub myCtrlProxies_getSensorReadingUnit($$);

#TODO sub myCtrlProxies_getSensors(;$$$$); # <SenName/undef> [<type>][<DevName>][<location>]

# 
#sub myCtrlProxies_getDevices(;$$$);# <DevName/undef>(undef => alles) [<Type>][<room>]



# Action
sub myCtrlProxies_doAllActions();
sub myCtrlProxies_doAction($$);
sub myCtrlProxies_DeviceSetFn($@);

#------------------------------------------------------------------------------

sub
myCtrlProxies_Initialize($$)
{
  my ($hash) = @_;
}

# Liefert Record zu der Reading für die angeforderte Messwerte
# Param Room-Name, Measurement-Name
# return ReadingsRecord
sub myCtrlProxies_getRoomMeasurementRecord($$) {
	my ($roomName, $measurementName) = @_;
	 
	my $sensorList = myCtrlProxies_getRoomSensorNames($roomName);
	return undef unless $sensorList;
	
	foreach my $sName (@$sensorList) {
		if(!defined($sName)) {next;} 
		my $rec = myCtrlProxies_getSensorValueRecord($sName, $measurementName);
		if(defined $rec) {return $rec;}
	}
	
	return undef;
}

# Liefert angeforderte Messwerte
# Param Room-Name, Measurement-Name
# return ReadingsWert
sub myCtrlProxies_getRoomMeasurementValue($$) {
	my ($roomName, $measurementName) = @_;
	 
	my $sensorList = myCtrlProxies_getRoomSensorNames($roomName);
	return undef unless $sensorList;
	
	foreach my $sName (@$sensorList) {
		if(!defined($sName)) {next;} 
		my $val = myCtrlProxies_getSensorReadingValue($sName, $measurementName);
		if(defined $val) {return $val;}
	}
	
	return undef;
}

#------------------------------------------------------------------------------
# returns Sensor-Record by name
# Parameter: name 
# record:
#  X->{name}->{alias}     ="Text zur Anzeige etc.";
#  X->{name}->{fhem_name} ="Name in FHEM";
#  X->{name}->{type}      ="Typ für Gruppierung und Suche";
#  X->{name}->{location}  ="Zugehörigkeit zu einem Raum ($rooms)";
#  X->{name}->{readings}->{<readings_name>} ->{reading}  ="temperature";
#  X->{name}->{readings}->{<readings_name>} ->{unit}     ="°C";
#  ...
sub 
myCtrlProxies_getSensor($)
{
	my ($name) = @_;
	return undef unless $name;
	return $sensors->{$name};
}

# returns Room-Record by name
# Parameter: name 
# record:
#  X->{name}->{alias}      ="Text zur Anzeige etc.";
#  X->{name}->{fhem_name} ="Text zur Anzeige etc.";
# Definiert nutzbare Sensoren. Reihenfolge gibt Priorität an. <= ODER BRAUCHT MAN NUR DIE EINZEL-READING-DEFINITIONEN?
#  X->{name}->{sensors}   =(<Liste der Namen>);
#  X->{name}->{sensors_outdor} =(<Liste der SensorenNamen 'vor dem Fenster'>);
sub myCtrlProxies_getRoom($) {
	my ($name) = @_;
	return $rooms->{$name};
}

# liefert Liste (Referenz) der Sensors in einem Raum (Liste der Namen)
# Param: Raumname
#  Beispiel:   {myCtrlProxies_getRoomSensorNames("wohnzimmer")->[0]}
sub myCtrlProxies_getRoomSensorNames($)
{
	my ($roomName) = @_;
  return myCtrlProxies_getRoomSensorNames_($roomName,"sensors");	
}
# liefert Liste (Referenz) der Sensors für einen Raum draussen (Liste der Namen)
# Param: Raumname
#  Beispiel:  {myCtrlProxies_getRoomSensorNames("wohnzimmer")->[0]}
sub myCtrlProxies_getRoomOutdoorSensorNames($)
{
	my ($roomName) = @_;
  return myCtrlProxies_getRoomSensorNames_($roomName,"sensors_outdoor");	
}
# liefert Referenz der Liste der Sensors in einem Raum (List der Namen)
# Param: Raumname, SensorListName (z.B. sensors, sensors_outdoor)
sub myCtrlProxies_getRoomSensorNames_($$)
{
	my ($roomName, $listName) = @_;
	my $roomRec=myCtrlProxies_getRoom($roomName);
	return undef unless $roomRec;
	my $sensorList=$roomRec->{$listName};
	return undef unless $sensorList;
	
	return $sensorList;
}



### TODO: Sind die Methoden, die Hashesliste zurückgeben überhaupt notwendig?
# liefert Liste der Sensors in einem Raum (Array of Hashes)
# Param: Raumname
#  Beispiel:  {(myCtrlProxies_getRoomSensors("wohnzimmer"))[0]->{alias}}
sub myCtrlProxies_getRoomSensors($)
{
	my ($roomName) = @_;
  return myCtrlProxies_getRoomSensors_($roomName,"sensors");	
}

# liefert Liste der Sensors für einen Raum draussen (Array of Hashes)
# Param: Raumname
#  Beispiel:  {(myCtrlProxies_getRoomOutdoorSensors("wohnzimmer"))[0]->{alias}}
sub myCtrlProxies_getRoomOutdoorSensors($)
{
	my ($roomName) = @_;
  return myCtrlProxies_getRoomSensors_($roomName,"sensors_outdoor");	
}

# liefert Liste der Sensors in einem Raum (Array of Hashes)
# Param: Raumname, SensorListName (z.B. sensors, sensors_outdoor)
sub myCtrlProxies_getRoomSensors_($$)
{
	my ($roomName, $listName) = @_;
	my $roomRec=myCtrlProxies_getRoom($roomName);
	return undef unless $roomRec;
	my $sensorList=$roomRec->{$listName};
	return undef unless $sensorList;
	
  #TEST:return @{$sensorList}[0];

	my @ret;
	foreach my $sName (@{$sensorList}) {
		my $sRec = myCtrlProxies_getSensor($sName);
		push(@ret, \%{$sRec}) if $sRec ;
	}
	
	return @ret;
}
# <---------------



sub myCtrlProxies_getSensorReadingCompositeRecord_intern($$);
# sucht gewünschtes reading zu dem angegebenen device, folgt den in {composite} definierten (Unter)-Devices.
# liefert Device und Reading Recors als Array 
sub
myCtrlProxies_getSensorReadingCompositeRecord_intern($$)
{
	my ($device_record,$reading) = @_;
	return (undef, undef) unless $device_record;
	return (undef, undef) unless $reading;
	
	my $readings_record = $device_record->{readings};
	my $single_reading_record = $readings_record->{$reading};
	return ($device_record, $single_reading_record) if $single_reading_record;
	
	# composites verarbeiten
	# e.g.  $sensors->{wz_wandthermostat}->{composite} =("wz_wandthermostat_climate"); 
	my $composites = $device_record->{composite};

	foreach my $composite_name (@{$composites}) {
		my $new_device_record = myCtrlProxies_getSensor($composite_name);
		my ($new_device_record2, $new_single_reading_record) = myCtrlProxies_getSensorReadingCompositeRecord_intern($new_device_record,$reading);
		if(defined($new_single_reading_record )) {
			return ($new_device_record2, $new_single_reading_record);
		}
	}
	
	return (undef, undef);
}

# parameters: name, reading name
# liefert Array mit Device und Reading -Hashes
# record:
#  X->{reading} = "<fhem_device_reading_name>";
#  X->{unit} = "";
sub 
myCtrlProxies_getSensorReadingRecord($$)
{
	my ($name, $reading) = @_;
	my $record = myCtrlProxies_getSensor($name);
	
	if(defined($record)) {
    return myCtrlProxies_getSensorReadingCompositeRecord_intern($record,$reading);
  }
	return (undef, undef);
}

# Sucht den Gewuenschten SensorDevice und liest den gesuchten Reading aus
# parameters: name, reading name
# returns Hash mit Werten zu dem gewuenschten Reading
# X->{value}
# X->{unit}
# X->{alias} # if any
# X->{fhem_name}
# X->{reading}
# X->...
sub myCtrlProxies_getSensorValueRecord($$)
{
	my ($name, $reading) = @_;
  # Sensor/Reading-Record suchen
  my ($device, $record) = myCtrlProxies_getSensorReadingRecord($name,$reading);
	if (defined($record)) {
	  my $fhem_name = $device->{fhem_name};
    my $reading_fhem_name = $record->{reading};

    my $val = ReadingsVal($fhem_name,$reading_fhem_name,undef); 
    my $ret;
    $ret->{value}     =$val;
    $ret->{unit}      =$record->{unit};
    $ret->{alias}     =$record->{alias};
    $ret->{fhem_name} =$device->{fhem_name};
    $ret->{reading}   =$record->{reading};
    return $ret;
	}
	return undef;
}


# Sucht den Gewuenschten SensorDevice und liest den gesuchten Reading aus
# parameters: name, reading name
# returns current readings value
sub myCtrlProxies_getSensorReadingValue($$)
{
	my ($name, $reading) = @_;
	my $h = myCtrlProxies_getSensorValueRecord($name, $reading);
	return undef unless $h;
	return $h->{value};
}

# Sucht den Gewuenschten SensorDevice und liest zu dem gesuchten Reading das Unit-String aus
# parameters: name, reading name
# returns readings unit
sub myCtrlProxies_getSensorReadingUnit($$)
{
	my ($name, $reading) = @_;
	my $h = myCtrlProxies_getSensorValueRecord($name, $reading);
	return undef unless $h;
	return $h->{unit};
	
	# Sensor/Reading-Record suchen
	my ($device, $record) = myCtrlProxies_getSensorReadingRecord($name,$reading);
	if (defined($record)) {
	  return $record->{unit};
	}
	return undef;
}


#------------------------------------------------------------------------------

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
  	  	myCtrlProxies_DeviceSetFn($dev, $actName, "www"); #?
  	  }
    }
	}
}                                              

#- Steuerung aus ReadingProxy -------------------------------------------------

###############################################################################
# Eine bestimmte (Set-)Aktion für ein bestimmtes Gerät ausfuehren.
# (Commando kann gefiltert und verändert werden, 
# d.h. ggf. nicht oder anders ausgeführt)
# Beispiel: Befehl 'schatten' für Rolladen: es wird geprüft (für jedes Rollo
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
  my $cmdFn = $devTab->{$DEVICE}->{valueFns}->{$CMD}; #TODO
  if(defined($cmdFn)) {
  	# TODO
  } else {
    return;
  }
}

# Zur Verwendung in ReadingProxy. Prüft (transparent) ob und wie ein Befehl ausgeführt werden soll.
# TODO
sub
myCtrlProxies_SetProxyFn($@) {
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
