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
  $rooms->{wohnzimmer}->{fhem_name}="Wohnzimmer";
  # Definiert nutzbare Sensoren. Reihenfolge gibt Priorität an. <= ODER BRAUCHT MAN NUR DIE EINZEL-READING-DEFINITIONEN?
  $rooms->{wohnzimmer}->{sensors}=["wz_raumsensor","wz_wandthermostat","tt_sensor"];
  $rooms->{wohnzimmer}->{sensors_outdoor}=["hg_sensor","vr_luftdruck"]; # Sensoren 'vor dem Fenster'. Wichtig vor allen bei Licht (wg. Sonnenstand)
  # Definiert nutzbare Messwerte einzeln. Hat vorrang vor der Definition von kompletten Sensoren. Reihenfolge gibt Priorität an.
  #ggf. for future use
  #$rooms->{wohnzimmer}->{measurements}->{temperature}=["wz_raumsensor:temperature"];
  #$rooms->{wohnzimmer}->{measurements_outdoor}->{temperature}=["hg_sensor:temperature"];
  #$rooms->{wohnzimmer}->{measurements}->{pressure}=["wz_raumsensor:pressure"];
  #$rooms->{wohnzimmer}->{measurements_outdoor}->{pressure}=["hg_sensor:pressure"];
  
  $rooms->{kueche}->{alias}="Küche";
  $rooms->{kueche}->{fhem_name}="Kueche";
  $rooms->{kueche}->{sensors}=["ku_raumsensor"];
  $rooms->{kueche}->{sensors_outdoor}=["hg_sensor","vr_luftdruck"]; 
    
  $rooms->{umwelt}->{alias}="Umwelt";
  $rooms->{umwelt}->{fhem_name}="Umwelt";
  $rooms->{umwelt}->{sensors}=["TODO","um_vh_licht","um_hh_licht"]; # Licht/Bewegung, 1wTemp, TinyTX-Garten (T/H), LichtGarten, LichtVorgarten
  $rooms->{umwelt}->{sensors_outdoor}=[]; # Keine
  
  # EG Flur, HWR, GästeWC, Garage
  # OG Flur, Bad, Schlafzimmer, Duschbad
  # DG
  # Räume ohne Sensoren: Speisekammer, Abstellkammer, Kinderzimmer 1 und 2
  
  
# Sensoren
my $sensors;
  $sensors->{wz_raumsensor}->{alias}     ="WZ Raumsensor";
  $sensors->{wz_raumsensor}->{fhem_name} ="EG_WZ_KS01";
  $sensors->{wz_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{wz_raumsensor}->{location}  ="wohnzimmer";
  $sensors->{wz_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{wz_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{wz_raumsensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{wz_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $sensors->{wz_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{wz_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{wz_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{wz_raumsensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{wz_raumsensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{wz_raumsensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  $sensors->{wz_raumsensor}->{readings}->{pressure}    ->{reading}  ="pressure";
  $sensors->{wz_raumsensor}->{readings}->{pressure}    ->{unit}     ="hPa";
  $sensors->{wz_raumsensor}->{readings}->{pressure}    ->{act_cycle} ="600"; 
  $sensors->{wz_raumsensor}->{readings}->{pressure}    ->{alias}    ="Luftdruck";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesittät";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}    ->{act_cycle} ="600"; 
  $sensors->{wz_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{wz_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{wz_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  
  # idee: 
  # $sensors->{vr_luftdruck}->{alias}       ="VirtuellerSensor";
  # $sensors->{vr_luftdruck}->{type}        ="virtuel";
  # $sensors->{vr_luftdruck}->{readings}->{X}->{ValueFn}     ="max"; #min, summe, average, eigene... bekommt Record, liefert Wert # wenn ValueFn, dann nur deren Wert, keine weitere Logik
  # $sensors->{vr_luftdruck}->{readings_list} =["X",...]; # für ValueFn?
  # $sensors->{vr_luftdruck}->{readings}->{pressure} ="device:reading"; # 'Weiterleitung' ? 
  #
  $sensors->{test}->{alias}       ="TestSensor";
  $sensors->{test}->{type}        ="virtuel";
  #$sensors->{test}->{readings}->{test1}->{ValueFn} = '{my $t=1; my $s=2; max($t,$s)}'; # mit Klammern: Direkt evaluieren, ansonsten als Funktion mit Reading-Hash und Device-Hash aufrufen.
  $sensors->{test}->{readings}->{test1}->{ValueFn} = 'senTest';
  $sensors->{test}->{readings}->{test1}->{FnParams} = ["1","2"];
  $sensors->{test}->{readings}->{test1}->{unit} ="?";
  $sensors->{test}->{readings}->{test1}->{alias} ="Funktionstest";
  $sensors->{test}->{readings}->{test2}->{link} ="vr_luftdruck:pressure";
  # 
  
  $sensors->{vr_luftdruck}->{alias}     ="Luftdrucksensor";
  $sensors->{vr_luftdruck}->{fhem_name} ="EG_WZ_KS01";
  $sensors->{vr_luftdruck}->{type}      ="HomeMatic compatible";
  $sensors->{vr_luftdruck}->{location}  ="virtuel";
  $sensors->{vr_luftdruck}->{readings}->{pressure}    ->{reading}  ="pressure";
  $sensors->{vr_luftdruck}->{readings}->{pressure}    ->{unit}     ="hPa";
  $sensors->{vr_luftdruck}->{readings}->{pressure}    ->{alias}     ="Luftdruck";
  
  $sensors->{wz_wandthermostat}->{alias}     ="WZ Wandthermostat";
  $sensors->{wz_wandthermostat}->{fhem_name} ="EG_WZ_WT01";
  $sensors->{wz_wandthermostat}->{type}      ="HomeMatic";
  $sensors->{wz_wandthermostat}->{location}  ="wohnzimmer";
  $sensors->{wz_wandthermostat}->{composite} =["wz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{wz_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{wz_wandthermostat_climate}->{alias}     ="WZ Wandthermostat (Ch)";
  $sensors->{wz_wandthermostat_climate}->{fhem_name} ="EG_WZ_WT01_Climate";
  $sensors->{wz_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{wz_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{wz_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{wz_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{wz_wandthermostat_climate}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{wz_wandthermostat_climate}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{wz_wandthermostat_climate}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{hg_sensor}->{alias}     ="Garten-Sensor";
  $sensors->{hg_sensor}->{fhem_name} ="GSD_1.4";
  $sensors->{hg_sensor}->{type}      ="GSD";
  $sensors->{hg_sensor}->{location}  ="garten";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{hg_sensor}->{readings}->{bat_voltage} ->{reading}  ="power_main";
  $sensors->{hg_sensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{hg_sensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{hg_sensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{tt_sensor}->{alias}     ="Test-Sensor";
  $sensors->{tt_sensor}->{fhem_name} ="GSD_1.1";
  $sensors->{tt_sensor}->{type}      ="GSD";
  $sensors->{tt_sensor}->{location}  ="wohnzimmer";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{tt_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{tt_sensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{tt_sensor}->{readings}->{bat_voltage}  ->{reading} ="power_main";
  $sensors->{tt_sensor}->{readings}->{bat_voltage}  ->{unit}    ="V";
  
  $sensors->{ku_raumsensor}->{alias}     ="KU Raumsensor";
  $sensors->{ku_raumsensor}->{fhem_name} ="EG_KU_KS01";
  $sensors->{ku_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{ku_raumsensor}->{location}  ="kueche";
  $sensors->{ku_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{ku_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{ku_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{ku_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{ku_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{ku_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{ku_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesittät";
  $sensors->{ku_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{ku_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{ku_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  
  
  
  $sensors->{um_vh_licht}->{alias}     ="VH Aussensensor";
  $sensors->{um_vh_licht}->{fhem_name} ="UM_VH_KS01";
  $sensors->{um_vh_licht}->{type}      ="HomeMatic compatible";
  $sensors->{um_vh_licht}->{location}  ="umwelt";
  $sensors->{um_vh_licht}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{um_vh_licht}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{um_vh_licht}->{readings}->{luminosity}  ->{alias}    ="Lichtintesittät";
  $sensors->{um_vh_licht}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{um_vh_licht}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{um_vh_licht}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  $sensors->{um_hh_licht}->{alias}     ="HH Aussensensor";
  $sensors->{um_hh_licht}->{fhem_name} ="UM_HH_KS01";
  $sensors->{um_hh_licht}->{type}      ="HomeMatic compatible";
  $sensors->{um_hh_licht}->{location}  ="umwelt";
  $sensors->{um_hh_licht}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{um_hh_licht}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{um_hh_licht}->{readings}->{luminosity}  ->{alias}    ="Lichtintesittät";
  $sensors->{um_hh_licht}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{um_hh_licht}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{um_hh_licht}->{readings}->{bat_status}  ->{reading}  ="battery";
  
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
	return myCtrlProxies_getRoomMeasurementRecord_($roomName, $measurementName, "");
}

# Liefert Record zu der Reading für die angeforderte Messwerte
# Param Room-Name, Measurement-Name
# return ReadingsRecord
sub myCtrlProxies_getRoomOutdoorMeasurementRecord($$) {
	my ($roomName, $measurementName) = @_;
	return myCtrlProxies_getRoomMeasurementRecord_($roomName, $measurementName, "_outdoor");
}

# Liefert Record zu der Reading für die angeforderte Messwerte und Sensorliste (Internal)
# Param Room-Name, Measurement-Name, Name der Liste (sensors, sensors_outdoor)
# return ReadingsRecord
sub myCtrlProxies_getRoomMeasurementRecord_($$$) {
	my ($roomName, $measurementName, $listNameSuffix) = @_;
	my $listName.="sensors".$listNameSuffix;
	
	#TODO: EinzelReadings
	
	my $sensorList = myCtrlProxies_getRoomSensorNames_($roomName, $listName);	#myCtrlProxies_getRoomSensorNames($roomName);
	return undef unless $sensorList;
	
	foreach my $sName (@$sensorList) {
		if(!defined($sName)) {next;} 
		my $rec = myCtrlProxies_getSensorValueRecord($sName, $measurementName);
		if(defined $rec) {
			my $roomRec=myCtrlProxies_getRoom($roomName);
			$rec->{room_alias}=$roomRec->{alias};
			$rec->{room_fhem_name}=$roomRec->{fhem_name};
			# XXX: ggf. weitere Room Eigenschaften
			return $rec;
		}
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
	my $ret = $sensors->{$name};
	$ret->{name} = $name; # Name hinzufuegen
	return $ret;
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
	my $ret = $rooms->{$name};
	$ret->{name} = $name; # Name hinzufuegen
	return $ret;
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


#### TODO: Sind die Methoden, die Hashesliste zurückgeben überhaupt notwendig?
## liefert Liste der Sensors in einem Raum (Array of Hashes)
## Param: Raumname
##  Beispiel:  {(myCtrlProxies_getRoomSensors("wohnzimmer"))[0]->{alias}}
#sub myCtrlProxies_getRoomSensors($)
#{
#	my ($roomName) = @_;
#  return myCtrlProxies_getRoomSensors_($roomName,"sensors");	
#}
#
## liefert Liste der Sensors für einen Raum draussen (Array of Hashes)
## Param: Raumname
##  Beispiel:  {(myCtrlProxies_getRoomOutdoorSensors("wohnzimmer"))[0]->{alias}}
#sub myCtrlProxies_getRoomOutdoorSensors($)
#{
#	my ($roomName) = @_;
#  return myCtrlProxies_getRoomSensors_($roomName,"sensors_outdoor");	
#}
#
## liefert Liste der Sensors in einem Raum (Array of Hashes)
## Param: Raumname, SensorListName (z.B. sensors, sensors_outdoor)
#sub myCtrlProxies_getRoomSensors_($$)
#{
#	my ($roomName, $listName) = @_;
#	my $roomRec=myCtrlProxies_getRoom($roomName);
#	return undef unless $roomRec;
#	my $sensorList=$roomRec->{$listName};
#	return undef unless $sensorList;
#	
#	my @ret;
#	foreach my $sName (@{$sensorList}) {
#		my $sRec = myCtrlProxies_getSensor($sName);
#		push(@ret, \%{$sRec}) if $sRec ;
#	}
#	
#	return @ret;
#}
## <---------------



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
# X->{time} # Timestamp der letzten Value Aenderung
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
  
  return myCtrlProxies_getReadingsValueRecord($device, $record);
  
	#if (defined($record)) {
	#  my $fhem_name = $device->{fhem_name};
  #  my $reading_fhem_name = $record->{reading};
  #
  #  my $val = ReadingsVal($fhem_name,$reading_fhem_name,undef); 
  #  my $ret;
  #  $ret->{value}     =$val;
  #  $ret->{unit}      =$record->{unit};
  #  $ret->{alias}     =$record->{alias};
  #  $ret->{fhem_name} =$device->{fhem_name};
  #  $ret->{reading}   =$record->{reading};
  #  #$ret->{sensor_alias} =$
  #  $ret->{device_alias} =$device->{alias};
  #  return $ret;
	#}
	#return undef;
}

# Nur zum Testen! DELETE ME
sub senTest($;$) {
  my($hash,$device) = @_;
  #return $hash->{FnParams}->[0];
  #return $hash->{FnParams};
  my $w = $hash->{FnParams};
  return "Sen. name: '".$device->{name}."', Params: '".join(", ", @$w)."'";
}

# Liefert ValueRecord (ermittelter Wert und andere SensorReadingDaten)
# Param: Device-Hash, Reading-Hash
# Return: Value-Hash
sub myCtrlProxies_getReadingsValueRecord($$) {
	my ($device, $record) = @_;
	
	if (defined($record)) {
		my $val=undef;
		my $time=undef;
		my $ret;
		
		my $link = $record->{link};
		if($link) {
			my($sensorName,$readingName) = split(/:/, $link);
			$sensorName = $device->{name} unless $sensorName; # wenn nichts angegeben (vor dem :) dann den Sensor selbst verwenden (Kopie eigenes Readings)
			return undef unless $readingName;
			return myCtrlProxies_getSensorValueRecord($sensorName,$readingName);
		} 
		
		my $valueFn =  $record->{ValueFn};
		if($valueFn) {
	    if($valueFn=~m/\{.*\}/) {
	    	# Klammern: direkt evaluieren
	      $val= eval $valueFn;	
	    } else {
	    	no strict "refs";
        my $r = &{$valueFn}($record,$device);
        use strict "refs";
        if(ref $r eq ref {}) {
        	# wenn Hash
        	$ret = $r;
        } else {
        	# Scalar-Wert annehmen
        	$val=$r;
        }
	    }
			#TODO
			#$val="not implemented";
			
		}
		else
		{
	    my $fhem_name = $device->{fhem_name};
      my $reading_fhem_name = $record->{reading};

      $val = ReadingsVal($fhem_name,$reading_fhem_name,undef);
      $time = ReadingsTimestamp($fhem_name,$reading_fhem_name,undef);
    }
    
    $ret->{value}     =$val if($val);
    # dead or alive?
    $ret->{status} = 'unknown';
    my $actCycle = $record->{act_cycle};
    $actCycle = 0 unless $actCycle;
    my $iactCycle = int($actCycle);
    if($actCycle && $iactCycle == 0) {
      $ret->{status} = 'alive'; # wenn actCycle == 0 immer alive
    }
    if($time) {
      $ret->{time} = $time;
      if($actCycle && $iactCycle > 0) {
        my $ttime = dateTime2dec($time);
        if($ttime && $ttime>0) {
      	  my $delta = time()-$ttime;
      	  if($delta>$iactCycle) {
      	  	$ret->{status} = 'dead';
      	  } else {
      	  	$ret->{status} = 'alive';
      	  }
        }
      }
    }
    # 'bool' zum Auswerten
    $ret->{alive} = $ret->{status} eq 'alive';
    
    # value_alive nur setzen, wenn Sensor 'alive' ist.
    if ($ret->{alive}) {
      $ret->{value_alive} = $ret->{value};
    } else {
    	$ret->{value_alive} = undef;
    }
    
    $ret->{unit}      =$record->{unit};
    $ret->{alias}     =$record->{alias};
    $ret->{fhem_name} =$device->{fhem_name};
    $ret->{reading}   =$record->{reading};
    #$ret->{sensor_alias} =$
    $ret->{device_alias} =$device->{alias};
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
