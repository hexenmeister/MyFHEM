#------------------------------------------------------------------------------
# $Id$
#------------------------------------------------------------------------------
package main;

use strict;
use warnings;
use POSIX;
#use List::Util qw[min max];


#--- Methods: Defs ------------------------------------------------------------
#technisches
sub myCtrlDev_Initialize($$);

# Rooms
sub HAL_getRooms();
sub HAL_getRoomRecord($);
sub HAL_getRoomNames();
#sub HAL_getRooms(;$); # Räume  nach verschiedenen Kriterien?
#sub HAL_getActions(;$); # <DevName>

sub HAL_getRoomActorNames($);
sub HAL_getRoomSensorNames($);
sub HAL_getRoomOutdoorSensorNames($);
sub HAL_getRoomSensorReadingsList($;$);
sub HAL_getRoomOutdoorSensorReadingsList($;$);

sub HAL_getRoomReadingRecord($$);
sub HAL_getRoomOutdoorReadingRecord($$);
sub HAL_getRoomReadingValue($$;$$);

# Device
sub HAL_getDeviceTab();
sub HAL_getDeviceRecord($);
sub HAL_isDeviceExist($);
sub HAL_isDeviceLowBat($);
sub HAL_getDeviceBatStatus($);

# Actors
sub HAL_getActorNames();
sub HAL_getActorRecord($);
sub HAL_setActionValue($$$);

# Sensoren
#sub HAL_getSensors();
sub HAL_getSensorNames();
sub HAL_getSensorRecord($);
sub HAL_getSensorReadingsList($);
sub HAL_getSensorReadingRecord($$);
sub HAL_getSensorValueRecord($$);
sub HAL_getSensorReadingValue($$);
sub HAL_getSensorReadingUnit($$);
sub HAL_getSensorReadingTime($$);
sub HAL_getSensorReadingTimeDurationStr($$);
sub HAL_getSensorReadingTimeDuration($$);
sub HAL_isSensorAlive($);
sub HAL_isReadingAlive($$);
sub HAL_gerSensorDeadTimeDuration($);
sub HAL_gerSensorDeadTimeDurationStr($);

# Aliases
sub HAL_getAliasTab();
sub HAL_getRoomAliasTab();
sub HAL_getDeviceAliasTab();

#TODO sub HAL_getSensors(;$$$$); # <SenName/undef> [<type>][<DevName>][<location>]

# 
#sub HAL_getDevices(;$$$);# <DevName/undef>(undef => alles) [<Type>][<room>]

# Readings
sub HAL_getReadingRecord($); # "sname:rname" => HAL_getSensorValueRecord
sub HAL_getReadingValue($);  # "sname:rname" => HAL_getSensorReadingValue
sub HAL_getReadingUnit($);   # "sname:rname" => HAL_getSensorReadingUnit
sub HAL_getReadingTime($);   # "sname:rname" => HAL_getSensorReadingTime
sub HAL_getReadingsValueRecord($$);
#

require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";

# Action
#sub HAL_doAllActions();
#sub HAL_doAction($$);
#sub HAL_DeviceSetFn($@);

# Internal
sub HAL_expandTemplates($);
sub HAL_applyTemplates($$);

#--- Definitions --------------------------------------------------------------
my $HAL_defs  = {};
my $rooms     = {};
my $devices   = {};
#my $actors    = {};
#my $sensors   = {};
my $actions   = {}; # ? Was ist der Zweck ?
my $scenarios = {};
my $templates = {};
my $aliases = {};

$HAL_defs->{rooms}     = $rooms;
$HAL_defs->{devices}   = $devices;
#$HAL_defs->{actors}    = $actors;
#$HAL_defs->{sensors}   = $sensors;
$HAL_defs->{actions}   = $actions;
$HAL_defs->{scenarios} = $scenarios;
$HAL_defs->{templates} = $templates;
$HAL_defs->{aliases}   = $aliases;

my $sensornames;
my $actornames;

# >>> Räume
# Eigenschaften: 
#  - alias : Freitext
#  - fhem_name : Raumname in FHEM
#  - sensors  : Liste der Sensoren im Raum. Reihenfolge gibt Priorität an.
#  - sensors_outdoor : Liste der Sensoren 'vor dem Fenster'.
# Sensoren können ggf. mit Readings (Liste) angegeben werden, ansonsten werden alle vorhandenen Readings verwendet: 
# ['<sensorName1>'[,.., '<sensorNameN>:<readingName1>[,<readingName2>,..]',..]]

 # > Outdoor
  $rooms->{umwelt}->{alias}     = "Umwelt";
  $rooms->{umwelt}->{fhem_name} = "Umwelt";
  $rooms->{umwelt}->{sensors}   = ["virtual_umwelt_sensor","vr_luftdruck","um_vh_bw_licht"]; # Licht/Bewegung, 1wTemp, TinyTX-Garten (T/H), LichtGarten, LichtVorgarten
  $rooms->{umwelt}->{sensors_outdoor}=[]; # Keine
  
  $rooms->{vorgarten}->{alias}     = " Vorgarten";
  $rooms->{vorgarten}->{fhem_name} = "---";
  $rooms->{vorgarten}->{sensors}   = ["um_vh_licht","um_vh_bw_licht","um_vh_bw_motion","um_vh_owts01","vr_luftdruck"];
  $rooms->{vorgarten}->{sensors_outdoor}=[];
  
  $rooms->{garten}->{alias}     = "Vorgarten";
  $rooms->{garten}->{fhem_name} = undef;
  $rooms->{garten}->{sensors}   = ["hg_sensor","um_hh_licht_th","vr_luftdruck"];
  $rooms->{garten}->{sensors_outdoor}=[];
 
 # > EG 
  $rooms->{wohnzimmer}->{alias}     = "Wohnzimmer";
  $rooms->{wohnzimmer}->{fhem_name} = "Wohnzimmer";
  $rooms->{wohnzimmer}->{sensors}   = ["wz_ms_sensor","wz_raumsensor","wz_wandthermostat",
                                       "tt_sensor",
                                       "eg_wz_fk01","eg_wz_tk",
                                       "virtual_wz_fenster","virtual_wz_terrassentuer",
                                       "eg_wz_rl",'virtual_raum_sensor_wz'];
  $rooms->{wohnzimmer}->{sensors_outdoor}=["vr_luftdruck","um_hh_licht_th","um_vh_licht","um_vh_owts01","hg_sensor"]; # Sensoren 'vor dem Fenster'. Wichtig vor allen bei Licht (wg. Sonnenstand)
  $rooms->{wohnzimmer}->{actors}=['wz_rollo_r'];
  
  $rooms->{kueche}->{alias}     = "Küche";
  $rooms->{kueche}->{fhem_name} = "Kueche";
  $rooms->{kueche}->{sensors}   = ["ku_raumsensor","eg_ku_fk01","virtual_ku_fenster","eg_ku_rl01",'virtual_raum_sensor_ku'];
  $rooms->{kueche}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_vh_owts01","um_hh_licht_th","hg_sensor"]; 

  $rooms->{wc}->{alias}     = "Gäste WC";
  $rooms->{wc}->{fhem_name} = "WC";
  $rooms->{wc}->{sensors}   = ["eg_wc_owts01"];
  $rooms->{wc}->{sensors_outdoor}=["vr_luftdruck",""];
  
  $rooms->{hwr}->{alias}     = "HWR";
  $rooms->{hwr}->{fhem_name} = "hwr";
  $rooms->{hwr}->{sensors}   = ["eg_ha_owts01"];
  $rooms->{hwr}->{sensors_outdoor}=["vr_luftdruck",""];
  
  $rooms->{eg_flur}->{alias}     = "Flur EG";
  $rooms->{eg_flur}->{fhem_name} = "EG_Flur";
  $rooms->{eg_flur}->{sensors}   = ["eg_fl_raumsensor","fl_eg_ms_sensor",'virtual_raum_sensor_ef'];
  $rooms->{eg_flur}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
    
  $rooms->{garage}->{alias}     = "Garage";
  $rooms->{garage}->{fhem_name} = "Garage";
  $rooms->{garage}->{sensors}   = ["eg_ga_owts01","ga_sensor",'virtual_raum_sensor_ga'];
  $rooms->{garage}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];

 # > OG
  $rooms->{og_flur}->{alias}="Flur OG";
  $rooms->{og_flur}->{fhem_name}="OG_Flur";
  $rooms->{og_flur}->{sensors}=["fl_og_ms_sensor", "og_fl_raumsensor", 'virtual_raum_sensor_of'];
  $rooms->{og_flur}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{schlafzimmer}->{alias}="Schlafzimmer";
  $rooms->{schlafzimmer}->{fhem_name}="Schlafzimmer";
  $rooms->{schlafzimmer}->{sensors}=["sz_raumsensor","sz_wandthermostat","og_sz_fk01","og_sz_rl01","virtual_sz_fenster",'virtual_raum_sensor_sz'];
  $rooms->{schlafzimmer}->{sensors_outdoor}=["vr_luftdruck","um_hh_licht_th","um_vh_licht","um_vh_owts01","hg_sensor"];
  
  $rooms->{badezimmer}->{alias}="Badezimmer";
  $rooms->{badezimmer}->{fhem_name}="Badezimmer";
  $rooms->{badezimmer}->{sensors}=["bz_raumsensor","bz_wandthermostat","og_bz_fk01","og_bz_rl01","virtual_bz_fenster",'virtual_raum_sensor_bz'];
  $rooms->{badezimmer}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{duschbad}->{alias}="Duschbad";
  $rooms->{duschbad}->{fhem_name}="Duschbad";
  $rooms->{duschbad}->{sensors}=["dz_wandthermostat"]; # TODO: Thermostat
  $rooms->{duschbad}->{sensors_outdoor}=["vr_luftdruck"];
  
  $rooms->{paula}->{alias}     = "Paulas Zimmer";
  $rooms->{paula}->{fhem_name} = "Paula";
  $rooms->{paula}->{sensors}   = ["ka_raumsensor","ka_wandthermostat","og_ka_fk","og_ka_rl01","virtual_ka_fenster",'virtual_raum_sensor_ka'];#,"og_ka_fk01","og_ka_fk02"
  $rooms->{paula}->{sensors_outdoor}=["vr_luftdruck","um_hh_licht_th","um_vh_licht","um_vh_owts01","hg_sensor"];
  
  $rooms->{hanna}->{alias}     = "Hannas Zimmer";
  $rooms->{hanna}->{fhem_name} = "Hanna";
  $rooms->{hanna}->{sensors}   = ["kb_raumsensor","kb_wandthermostat","og_kb_fk01","og_kb_rl01","virtual_kb_fenster",'virtual_raum_sensor_kb'];
  $rooms->{hanna}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{ar}->{alias}     = "OG Abstellraum";
  $rooms->{ar}->{fhem_name} = "OG_AR";
  $rooms->{ar}->{sensors}   = ["of_sensor"];
  $rooms->{ar}->{sensors_outdoor}=["vr_luftdruck",""];

  # TODO  
 # > DG
  # Räume (noch) ohne Sensoren: Speisekammer, (Abstellkammer => GSD1.3)


# >>> Aktoren

# TODO
  #$devices->{wz_rollo_r}->{class}="rollo"; # optional zum gruppieren #TODO?
  $devices->{wz_rollo_r}->{alias}="WZ Rolladen";
  $devices->{wz_rollo_r}->{fhem_name}="wz_rollo_r";
  $devices->{wz_rollo_r}->{type}="HomeMatic";
  $devices->{wz_rollo_r}->{location}="wohnzimmer";
  #$devices->{wz_rollo_r}->{readings}->{level}="level";
  #$devices->{wz_rollo_r}->{actions}->{xxx}->{valueFn}="{...}";
  $devices->{wz_rollo_r}->{actions}->{level}->{setting}="pct";
  $devices->{wz_rollo_r}->{actions}->{level}->{type}="int"; #?
  $devices->{wz_rollo_r}->{actions}->{level}->{min}="0";    #?
  $devices->{wz_rollo_r}->{actions}->{level}->{max}="100";  #?
  $devices->{wz_rollo_r}->{actions}->{level}->{alias} = "Rolladenstellung";
  $devices->{wz_rollo_r}->{actions}->{level}->{predefined}->{hoch}->{value}="100";
  $devices->{wz_rollo_r}->{actions}->{level}->{predefined}->{runter}->{value}="0";
  $devices->{wz_rollo_r}->{actions}->{level}->{predefined}->{halb}->{value}="60";
  $devices->{wz_rollo_r}->{actions}->{level}->{predefined}->{nacht}->{value}="0";
  $devices->{wz_rollo_r}->{actions}->{level}->{predefined}->{schatten}->{valueFn}="TODO";
  $devices->{wz_rollo_r}->{actions}->{level}->{predefined}->{schatten}->{fnParams}="TODO";
  
  $devices->{wz_licht_r}->{alias}="WZ Licht (Dimmer)";
  $devices->{wz_licht_r}->{fhem_name}="EG_WZ_DA01_Licht_Rechts_Sw";
  $devices->{wz_licht_r}->{type}="HomeMatic";
  $devices->{wz_licht_r}->{location}="wohnzimmer";
  $devices->{wz_licht_r}->{readings}->{level}->{reading} ="level";
  $devices->{wz_licht_r}->{readings}->{level}->{alias}   ="Dimmwert";
  $devices->{wz_licht_r}->{readings}->{level}->{unit}    ="%";
  #$devices->{wz_licht_r}->{actions}->{xxx}->{valueFn}="{...}";
  $devices->{wz_licht_r}->{actions}->{level}->{setting}="pct";
  $devices->{wz_licht_r}->{actions}->{level}->{type}="int"; #?
  $devices->{wz_licht_r}->{actions}->{level}->{min}="0";    #?
  $devices->{wz_licht_r}->{actions}->{level}->{max}="100";  #?
  $devices->{wz_licht_r}->{actions}->{level}->{alias} = "Licht Dimmer";
  $devices->{wz_licht_r}->{actions}->{level}->{predefined}->{an}->{value}="100";
  $devices->{wz_licht_r}->{actions}->{level}->{predefined}->{aus}->{value}="0";
  $devices->{wz_licht_r}->{actions}->{level}->{predefined}->{on}->{value}="100";
  $devices->{wz_licht_r}->{actions}->{level}->{predefined}->{off}->{value}="0";
  $devices->{wz_licht_r}->{actions}->{level}->{predefined}->{dunkel}->{value}="10";
  #$devices->{wz_licht_r}->{actions}->{level}->{predefined}->{schatten}->{valueFn}="TODO";
  #$devices->{wz_licht_r}->{actions}->{level}->{predefined}->{schatten}->{fnParams}="TODO";
  #TODO: Coposite,Link
  
#TODO: Verlagern
# Sendet neuen Wert an den Aktor
# Params:
#   name:  Name des Aktors
#   value: Neuer Wert
sub HAL_setActionValue($$$) {
  my($actorname, $actionname, $value) = @_;
  my $actor_record = HAL_getActorRecord($actorname);
  
  if(!defined($actorname)) {return "no actor specified";}
  if(!defined($actionname)) {return "no action specified";}
  if(!defined($value)) {return "no value specified";}
  if(!$actor_record) {return "no actor $actorname found";}
  if(!$actor_record->{actions}) {return "no actions found in $actorname";}
  my $action_record = $actor_record->{actions}->{$actionname};
  if(!$action_record) {return "no action $actorname:$actionname found";}
  
  my $fhem_actor_name = $actor_record->{fhem_name};
  my $setting = $action_record->{setting};
  
  # wenn es eine predefined-Tabelle gibt...
  my $predefined_record = $action_record->{predefined};
  if(defined($predefined_record)) {
    my $predefined_value_record = $predefined_record->{$value};
    # ... wenn dort ein entsprechender Eintrag vorhanen ist...
    if(defined($predefined_value_record)) { 
      #TODO: ValueFn
      my $predefined_value = $predefined_value_record->{value};
      # ... dann ggf. als Wert aufnehmen.
      if(defined($predefined_value)) { 
        $value = $predefined_value;
      }
    }
  }
  
  # TODO: Pruefen type
  # TODO: Pruefen Grenzen
  # TODO: Pruefen interna
  # 
  
  
  return fhem("set $fhem_actor_name $setting $value");
  #return undef;
}

# TODO: setRoomActionValue

# >>> Sensoren
  #$templates->{global};
  
  # >>> Virtual Devices
  $templates->{virtual}->{location}  =':virtual';
  $templates->{virtual}->{type}      ='virtual';

  # >>> HM Templates
  $templates->{hm}->{type}='HomeMatic';
  $templates->{hm_channel}->{type}='HomeMatic Channel';
  $templates->{hm_channel}->{location}=':channel';
  # >>> Dirks Homebrew
  $templates->{hm_raumsensor_general}->{type}='HomeMatic compatible';
  $templates->{hm_raumsensor_general}->{templates}=['hm'];
  # >>> mit Bat-Messung
  $templates->{readings_bat_voltage_base}->{readings}->{bat_voltage} ->{reading} =undef;
  $templates->{readings_bat_voltage_base}->{readings}->{bat_voltage} ->{unit}    ="V";
  $templates->{readings_bat_voltage_base}->{readings}->{bat_voltage} ->{alias}   ="Batterie-Spannung";
  # 0 (reserved / unknown), 1 (Hauptwerte. Temp,Hum,..), 2 (primär, wichtig. Licht,..), 3 (sekunder, wichtig. Taupunkt, AbsFeuchte,..), 4 (info, weniger wichtig. BatLevel,..) 5 (technik, weniger wichtig. BatLowLimit,..) 6 (technik / debug)
  $templates->{readings_bat_voltage_base}->{readings}->{bat_voltage} ->{level}   ='4'; 
  
  $templates->{readings_bat_voltage}->{templates} =['readings_bat_voltage_base'];
  $templates->{readings_bat_voltage}->{readings}->{bat_voltage} ->{reading} ="batVoltage";
  #$templates->{readings_bat_voltage}->{readings}->{bat_voltage} ->{unit}    ="V";
  #$templates->{readings_bat_voltage}->{readings}->{bat_voltage} ->{alias}   ="Batterie-Spannung";
  #$templates->{readings_bat_voltage}->{readings}->{bat_voltage} ->{level}   ='4'; 
  # >>>
  $templates->{readings_bat_level}->{templates} =['readings_bat_voltage_base'];
  $templates->{readings_bat_level}->{readings}->{bat_voltage} ->{reading}   ="batteryLevel";
  #$templates->{readings_bat_level}->{readings}->{bat_voltage} ->{unit}      ="V";
  #$templates->{readings_bat_level}->{readings}->{bat_voltage} ->{alias}     ="Batterie-Spannung";
  #$templates->{readings_bat_level}->{readings}->{bat_voltage} ->{level}     ='5';
  # >>> LowBatLimit-Template
  $templates->{readings_low_bat_limit}->{readings}->{low_bat_limit} ->{reading}       =undef;
  $templates->{readings_low_bat_limit}->{readings}->{low_bat_limit} ->{ValueFilterFn} ='{(split(/\s/,$VAL))[0]}';
  $templates->{readings_low_bat_limit}->{readings}->{low_bat_limit} ->{unit}          ="V";
  $templates->{readings_low_bat_limit}->{readings}->{low_bat_limit} ->{alias}         ="Spannungsrenze für schwache Batterie";
  $templates->{readings_low_bat_limit}->{readings}->{low_bat_limit} ->{level}         ='5';
  # >>> LowBatLimit-RT
  $templates->{readings_low_bat_limit_rt}->{readings}->{low_bat_limit} ->{reading}       ="R-lowBatLimitRT";
  $templates->{readings_low_bat_limit_rt}->{templates}=['readings_low_bat_limit'];
  # >>> LowBatLimit-THPL
  $templates->{readings_low_bat_limit_thpl}->{readings}->{low_bat_limit} ->{reading}       ="R-lowBatLimitTHPL";
  $templates->{readings_low_bat_limit_thpl}->{templates}=['readings_low_bat_limit'];
  # >>> 
  $templates->{readings_bat_status}->{readings}->{bat_status}  ->{reading}  ="battery";
  $templates->{readings_bat_status}->{readings}->{bat_status}  ->{alias}    ="Batterie-Status";
  $templates->{readings_bat_status}->{readings}->{bat_status}  ->{level}    ='4';

  # >>> ... mit Lux-Messung
  $templates->{readings_lux}->{readings}->{luminosity}->{reading}  ="luminosity";
  $templates->{readings_lux}->{readings}->{luminosity}->{alias}    ="Lichtintesität";
  $templates->{readings_lux}->{readings}->{luminosity}->{unit}     ="Lx (*)";
  $templates->{readings_lux}->{readings}->{luminosity}->{act_cycle} ="600"; 
  $templates->{readings_lux}->{readings}->{luminosity}->{level}    ='2';
  
  # >>> ... Erweiterung fuer TH-Readings um Taupunkt und ABs.Feuchte
  $templates->{readings_dewpoint}->{readings}->{dewpoint}->{ValueFn}   = "HAL_TaupunktValueFn";
  $templates->{readings_dewpoint}->{readings}->{dewpoint}->{alias}     = "Taupunkt";
  $templates->{readings_dewpoint}->{readings}->{dewpoint}->{level}     = '3';
  $templates->{readings_dewpoint}->{readings}->{absFeuchte}->{ValueFn} = "HAL_AbsFeuchteValueFn";
  $templates->{readings_dewpoint}->{readings}->{absFeuchte}->{alias}   = "Absolute Feuchte";
  $templates->{readings_dewpoint}->{readings}->{absFeuchte}->{level}   = '3';

  # >>> ... mit Temp/Hum
  $templates->{readings_temperature}->{readings}->{temperature} ->{reading}  ="temperature";
  $templates->{readings_temperature}->{readings}->{temperature} ->{unit}     ="°C";
  $templates->{readings_temperature}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $templates->{readings_temperature}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $templates->{readings_temperature}->{readings}->{temperature} ->{level}    ='1';
  
  $templates->{readings_th}->{templates}=['readings_temperature','readings_dewpoint'];
  #$templates->{readings_th}->{readings}->{temperature} ->{reading}  ="temperature";
  #$templates->{readings_th}->{readings}->{temperature} ->{unit}     ="°C";
  #$templates->{readings_th}->{readings}->{temperature} ->{alias}    ="Temperatur";
  #$templates->{readings_th}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  #$templates->{readings_th}->{readings}->{temperature} ->{level}    ='1';
  $templates->{readings_th}->{readings}->{humidity}    ->{reading}  ="humidity";
  $templates->{readings_th}->{readings}->{humidity}    ->{unit}     ="% rH";
  $templates->{readings_th}->{readings}->{humidity}    ->{alias}    ="Luftfeuchtigkeit";
  $templates->{readings_th}->{readings}->{humidity}    ->{act_cycle} ="600";
  $templates->{readings_th}->{readings}->{humidity}    ->{level}    ='1';
  #$templates->{readings_th}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  #$templates->{readings_th}->{readings}->{dewpoint}    ->{unit}     ="°C";
  #$templates->{readings_th}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  #$templates->{readings_th}->{readings}->{dewpoint}    ->{act_cycle} ="600";
  #$templates->{readings_th}->{readings}->{absFeuchte}  ->{reading}  ="absFeuchte";
  #$templates->{readings_th}->{readings}->{absFeuchte}  ->{unit}     ="g/m3";
  #$templates->{readings_th}->{readings}->{absFeuchte}  ->{alias}    ="Absolute Feuchte";
  #$templates->{readings_th}->{readings}->{absFeuchte}  ->{act_cycle} ="600";
  
  # >>> ... mit Temp/Hum mit 'measured-temp'
  $templates->{readings_th2}->{templates}=['readings_th'];
  $templates->{readings_th2}->{readings}->{temperature} ->{reading}  ="measured-temp";
  
  #virtual_raum_sensor
  $templates->{virtual_raum_sensor}->{comment}     ="Virtueller Sensor: Berechnet Temperaturdifferenz zw. Innen und Außen.";
  $templates->{virtual_raum_sensor}->{alias}       ="Virtueller Raumsensor";
  $templates->{virtual_raum_sensor}->{templates}   =['virtual'];
  $templates->{virtual_raum_sensor}->{readings}->{outdoor_temp_diff}->{ValueFn} = "HAL_TempDiffOutdoorValueFn";

  # >>> virtual_fenster (f. Beschattung)
  $templates->{virtual_fenster}->{readings}->{outdoor_luminosity}  ->{link} = "virtual_umwelt_sensor:luminosity";
  $templates->{virtual_fenster}->{readings}->{outdoor_temperature} ->{link} = "virtual_umwelt_sensor:temperature";
  $templates->{virtual_fenster}->{readings}->{outdoor_humidity}    ->{link} = "virtual_umwelt_sensor:humidity";
  #$templates->{virtual_fenster}->{readings}->{dim_top}->{ValueFn} = "{2.10}";
  $templates->{virtual_fenster}->{readings}->{dim_top}->{alias}   = "Hoehe";
  $templates->{virtual_fenster}->{readings}->{dim_top}->{comment} = "Hoehe ueber den Boden";
  $templates->{virtual_fenster}->{readings}->{dim_top}->{unit} = "m";
  #$templates->{virtual_fenster}->{readings}->{dim_bottom}->{ValueFn} = "{0.92}";
  $templates->{virtual_fenster}->{readings}->{dim_bottom}->{alias}   = "Hoehe";
  $templates->{virtual_fenster}->{readings}->{dim_bottom}->{comment} = "Hoehe ueber den Boden";
  $templates->{virtual_fenster}->{readings}->{dim_bottom}->{unit} = "m";
  $templates->{virtual_fenster}->{readings}->{secure}->{ValueFn} = 'HAL_WinSecureStateValueFn';
  #$templates->{virtual_fenster}->{readings}->{secure}->{FnParams} = ['eg_wz_fk01:state'];
  $templates->{virtual_fenster}->{readings}->{secure}->{alias}   = "gesichert";
  $templates->{virtual_fenster}->{readings}->{secure}->{comment} = "Nicht offen oder gekippt";
  $templates->{virtual_fenster}->{readings}->{sunny_side}->{ValueFn} = 'HAL_WinSunnySideValueFn';
  #$templates->{virtual_fenster}->{readings}->{sunny_side}->{FnParams} = [215,315]; # zu beachtender Winkel (Azimuth): von, bis
  $templates->{virtual_fenster}->{readings}->{sunny_side}->{alias}   = "Sonnenseite";
  $templates->{virtual_fenster}->{readings}->{sunny_side}->{comment} = "Sonne strahlt ins Fenster (Sonnenseite (und nicht Nacht))";
  $templates->{virtual_fenster}->{readings}->{sunny_room_range}->{ValueFn} = 'HAL_WinSunRoomRangeValueFn';
  #$templates->{virtual_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.10, 0.57, 265]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  $templates->{virtual_fenster}->{readings}->{sunny_room_range}->{alias}   = "Sonnenreichweite";
  $templates->{virtual_fenster}->{readings}->{sunny_room_range}->{comment} = "Wie weit die Sonne ins Zimmer hineinragt (auf dem Boden)";
  
  #>>> GSD (Eigenbau, depricated)
  $templates->{gsd}->{type}      ='GSD';
  $templates->{gsd}->{templates} = ['readings_th','readings_dewpoint','readings_bat_level'];

  #>>> Readings: Motion (Basis)
  $templates->{readings_motion}->{readings}->{motion}         ->{reading}   ="motion";
  $templates->{readings_motion}->{readings}->{motion}         ->{alias}     ="Bewegungsmelder";
  $templates->{readings_motion}->{readings}->{motion}         ->{unit_type} ="ENUM: on";
  $templates->{readings_motion}->{readings}->{motion}         ->{level}     ='6';
  $templates->{readings_motion}->{readings}->{motiontime_str} ->{ValueFn}   = "HAL_MotionTimeStrValueFn";
  $templates->{readings_motion}->{readings}->{motiontime_str} ->{level}     = '2';
  $templates->{readings_motion}->{readings}->{motiontime}     ->{ValueFn}   = "HAL_MotionTimeValueFn";
  #$templates->{readings_motion}->{readings}->{motiontime}     ->{FnParams}  = "motion";
  $templates->{readings_motion}->{readings}->{motiontime}     ->{alias}     = "Zeit in Sekunden seit der letzten Bewegung";
  $templates->{readings_motion}->{readings}->{motiontime}     ->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Bewegung erkannt wurde";
  $templates->{readings_motion}->{readings}->{motiontime}     ->{level}     = '2';
  #>>> Readings: Motion (letzte Minute)
  $templates->{readings_motion_1m}->{readings}->{motion1m}->{ValueFn}   = "HAL_MotionValueFn";
  $templates->{readings_motion_1m}->{readings}->{motion1m}->{FnParams}  = [60, "motion"];
  $templates->{readings_motion_1m}->{readings}->{motion1m}->{alias}     = "Bewegung in der letzten Minute";
  $templates->{readings_motion_1m}->{readings}->{motion1m}->{comment}   = "gibt an, ob in der letzten Minute eine Bewegung erkannt wurde";
  $templates->{readings_motion_1m}->{readings}->{motion1m}->{level}     = '3';
  #>>> Readings: Motion (letzten 15 Minuten)
  $templates->{readings_motion_15m}->{readings}->{motion15m}->{ValueFn}  = "HAL_MotionValueFn";
  $templates->{readings_motion_15m}->{readings}->{motion15m}->{FnParams} = [900, "motion"];
  $templates->{readings_motion_15m}->{readings}->{motion15m}->{alias}    = "Bewegung in den letzten 15 Minuten";
  $templates->{readings_motion_15m}->{readings}->{motion15m}->{comment}  = "gibt an, ob in den letzten 15 Minuten eine Bewegung erkannt wurde";
  $templates->{readings_motion_15m}->{readings}->{motion15m}->{level}     = '3';
  #>>> Readings: Motion (letzte Stunde)
  $templates->{readings_motion_1h}->{readings}->{motion1h}->{ValueFn}   = "HAL_MotionValueFn";
  $templates->{readings_motion_1h}->{readings}->{motion1h}->{FnParams}  = [3600, "motion"];
  $templates->{readings_motion_1h}->{readings}->{motion1h}->{alias}     = "Bewegung in der letzten Stunde";
  $templates->{readings_motion_1h}->{readings}->{motion1h}->{comment}   = "gibt an, ob in der letzten Stunde eine Bewegung erkannt wurde";
  $templates->{readings_motion_1h}->{readings}->{motion1h}->{level}     = '3';
  #>>> Readings: Motion (letzten 12 Stunden)
  $templates->{readings_motion_12h}->{readings}->{motion12h}->{ValueFn}  = "HAL_MotionValueFn";
  $templates->{readings_motion_12h}->{readings}->{motion12h}->{FnParams} = [43200, "motion"];
  $templates->{readings_motion_12h}->{readings}->{motion12h}->{alias}    = "Bewegung in den letzten 12 Stunden";
  $templates->{readings_motion_12h}->{readings}->{motion12h}->{comment}  = "gibt an, ob in den letzten 12 Stunden eine Bewegung erkannt wurde";
  $templates->{readings_motion_12h}->{readings}->{motion12h}->{level}    = '3';
  #>>> Readings: Motion (letzten 24 Stunden)
  $templates->{readings_motion_24h}->{readings}->{motion24h}->{ValueFn}  = "HAL_MotionValueFn";
  $templates->{readings_motion_24h}->{readings}->{motion24h}->{FnParams} = [86400, "motion"];
  $templates->{readings_motion_24h}->{readings}->{motion24h}->{alias}    = "Bewegung in den letzten 24 Stunden";
  $templates->{readings_motion_24h}->{readings}->{motion24h}->{comment}  = "gibt an, ob in den letzten 24 Stunden eine Bewegung erkannt wurde";
  $templates->{readings_motion_24h}->{readings}->{motion24h}->{level}    = '3';

  $templates->{readings_motion_set}->{templates}     =['readings_motion','readings_motion_1m','readings_motion_15m','readings_motion_1h','readings_motion_12h','readings_motion_24h'];
  
  #>>> MySensors (Eigenbau)  
  $templates->{ms_base}->{type}              ="MySensors";
  $templates->{ms_combi_th}->{templates}     =['ms_base','readings_th','readings_dewpoint'];
  $templates->{ms_combi_lux}->{templates}    =['ms_base','readings_lux'];
  $templates->{ms_combi_lux}->{readings}->{luminosity}->{reading}="brightness";
  $templates->{ms_combi_motion}->{templates} =['ms_base','readings_motion_set'];
  $templates->{ms_combi_lm}->{templates}   =['ms_combi_lux','ms_combi_motion'];
  $templates->{ms_combi_lmth}->{templates} =['ms_combi_th','ms_combi_lux','ms_combi_motion'];
  #<<<
  
  #>>> OneWire
  $templates->{owx_base}->{type}      ="OneWire";
  $templates->{owx_temp}->{templates} =['readings_temperature','owx_base'];
  $templates->{owx_temp}->{readings}->{temperature}->{ValueFilterFn} ='HAL_round1';
  #<<<
  
  # >>> Devices
  #$devices->{vr_luftdruck}->{alias}     ="Luftdrucksensor";
  #$devices->{vr_luftdruck}->{fhem_name} ="EG_WZ_KS01";
  #$devices->{vr_luftdruck}->{type}      ="HomeMatic compatible";
  #$devices->{vr_luftdruck}->{location}  ="virtual";
  #$devices->{vr_luftdruck}->{templates} =['hm_raumsensor_general','global'];
  #$devices->{vr_luftdruck}->{readings}->{pressure}    ->{reading}  ="pressure";
  #$devices->{vr_luftdruck}->{readings}->{pressure}    ->{unit}     ="hPa";
  #$devices->{vr_luftdruck}->{readings}->{pressure}    ->{act_cycle} ="600"; 
  #$devices->{vr_luftdruck}->{readings}->{pressure}    ->{alias}     ="Luftdruck";
  
  $devices->{vr_luftdruck}->{alias}                        ="Luftdrucksensor";
  $devices->{vr_luftdruck}->{readings}->{pressure}->{link} ="wz_raumsensor:pressure";
  $devices->{vr_luftdruck}->{templates}                    =['virtual','global'];
  #<<<
  
  $devices->{wz_raumsensor}->{alias}     ="WZ Raumsensor";
  $devices->{wz_raumsensor}->{fhem_name} ="EG_WZ_KS01";
  $devices->{wz_raumsensor}->{location}  ="wohnzimmer";
  $devices->{wz_raumsensor}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  $devices->{wz_raumsensor}->{readings}->{pressure}    ->{reading}  ="pressure";
  $devices->{wz_raumsensor}->{readings}->{pressure}    ->{unit}     ="hPa";
  $devices->{wz_raumsensor}->{readings}->{pressure}    ->{act_cycle} ="600"; 
  $devices->{wz_raumsensor}->{readings}->{pressure}    ->{alias}    ="Luftdruck";
  #<<<
  
  $devices->{ku_raumsensor}->{alias}     ="KU Raumsensor";
  $devices->{ku_raumsensor}->{fhem_name} ="EG_KU_KS01";
  $devices->{ku_raumsensor}->{location}  ="kueche";
  $devices->{ku_raumsensor}->{templates}  =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #<<<
  
  $devices->{eg_fl_raumsensor}->{alias}     ="EG Flur Raumsensor";
  $devices->{eg_fl_raumsensor}->{fhem_name} ="EG_FL_KS01";
  $devices->{eg_fl_raumsensor}->{location}  ="eg_flur";
  $devices->{eg_fl_raumsensor}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #<<<
  
  $devices->{og_fl_raumsensor}->{alias}     ="OG Flur Raumsensor";
  $devices->{og_fl_raumsensor}->{fhem_name} ="OG_FL_KS01";
  $devices->{og_fl_raumsensor}->{location}  ="og_flur";
  $devices->{og_fl_raumsensor}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #<<<
  
  $devices->{sz_raumsensor}->{alias}     ="Schlafzimmer Raumsensor";
  $devices->{sz_raumsensor}->{fhem_name} ="OG_SZ_KS01";
  $devices->{sz_raumsensor}->{location}  ="schlafzimmer";
  $devices->{sz_raumsensor}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #<<<
  
  $devices->{bz_raumsensor}->{alias}     ="Badezimmer Raumsensor";
  $devices->{bz_raumsensor}->{fhem_name} ="OG_BZ_KS01";
  $devices->{bz_raumsensor}->{location}  ="badezimmer";
  $devices->{bz_raumsensor}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #<<<
  
  $devices->{ka_raumsensor}->{alias}     ="Kinderzimmer1 Raumsensor";
  $devices->{ka_raumsensor}->{fhem_name} ="OG_KA_KS01";
  $devices->{ka_raumsensor}->{location}  ="paula";
  $devices->{ka_raumsensor}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #<<<
  
  $devices->{kb_raumsensor}->{alias}     ="Kinderzimmer2 Raumsensor";
  $devices->{kb_raumsensor}->{fhem_name} ="OG_KB_KS01";
  $devices->{kb_raumsensor}->{location}  ="hanna";
  $devices->{kb_raumsensor}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #<<<
  
  $devices->{um_vh_licht}->{alias}     ="VH Aussensensor";
  $devices->{um_vh_licht}->{fhem_name} ="UM_VH_KS01";
  $devices->{um_vh_licht}->{location}  ="umwelt";
  $devices->{um_vh_licht}->{templates} =['readings_bat_status','readings_bat_voltage','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #$devices->{um_vh_licht}->{readings}->{luminosity}  ->{reading}   ="luminosity";
  # Umgerechnete Lichtintensitaet verwenden (wg. der 26%-durchlaessiger Folie)
  $devices->{um_vh_licht}->{readings}->{luminosity}  ->{reading}   ="normalizedLuminosity";
  #<<<
  
  $devices->{um_hh_licht_th}->{alias}     ="HH Aussensensor";
  $devices->{um_hh_licht_th}->{fhem_name} ="UM_HH_KS01";
  $devices->{um_hh_licht_th}->{location}  ="umwelt";
  $devices->{um_hh_licht_th}->{templates} =['readings_bat_status','readings_bat_voltage','readings_th','readings_lux','readings_low_bat_limit_thpl','hm_raumsensor_general','global'];
  #$devices->{um_hh_licht_th}->{readings}->{luminosity}  ->{reading}   ="luminosity";
  $devices->{um_hh_licht_th}->{readings}->{luminosity}  ->{reading}   ="normalizedLuminosity"; 
  #<<<
  
  $devices->{wz_wandthermostat}->{alias}     ="WZ Wandthermostat";
  $devices->{wz_wandthermostat}->{fhem_name} ="EG_WZ_WT01";
  $devices->{wz_wandthermostat}->{location}  ="wohnzimmer";
  $devices->{wz_wandthermostat}->{templates} =['readings_low_bat_limit_rt','readings_bat_level','hm','global'];
  $devices->{wz_wandthermostat}->{composite} =["wz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $devices->{wz_wandthermostat_climate}->{alias}     ="WZ Wandthermostat (Ch)";
  $devices->{wz_wandthermostat_climate}->{fhem_name} ="EG_WZ_WT01_Climate";
  $devices->{wz_wandthermostat_climate}->{templates} =['readings_th2','readings_bat_status','hm_channel','global'];  
  #<<<
  
  $devices->{sz_wandthermostat}->{alias}     ="SZ Wandthermostat";
  $devices->{sz_wandthermostat}->{fhem_name} ="OG_SZ_WT01";
  $devices->{sz_wandthermostat}->{location}  ="schlafzimmer";
  $devices->{sz_wandthermostat}->{templates} =['readings_low_bat_limit_rt','readings_bat_level','hm','global'];
  $devices->{sz_wandthermostat}->{composite} =["sz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $devices->{sz_wandthermostat_climate}->{alias}     ="WZ Wandthermostat (Ch)";
  $devices->{sz_wandthermostat_climate}->{fhem_name} ="OG_SZ_WT01_Climate";
  $devices->{sz_wandthermostat_climate}->{templates} =['readings_th2','readings_bat_status','hm_channel','global'];  
  #<<<
  
  $devices->{dz_wandthermostat}->{alias}     ="DZ Wandthermostat";
  $devices->{dz_wandthermostat}->{fhem_name} ="OG_DZ_WT01";
  $devices->{dz_wandthermostat}->{location}  ="duschbad";
  $devices->{dz_wandthermostat}->{templates} =['readings_low_bat_limit_rt','readings_bat_level','hm','global'];
  $devices->{dz_wandthermostat}->{composite} =["dz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $devices->{dz_wandthermostat_climate}->{alias}     ="DZ Wandthermostat (Ch)";
  $devices->{dz_wandthermostat_climate}->{fhem_name} ="OG_DZ_WT01_Climate";
  $devices->{dz_wandthermostat_climate}->{templates} =['readings_th2','readings_bat_status','hm_channel','global'];  
  #<<<
  
  $devices->{bz_wandthermostat}->{alias}     ="BZ Wandthermostat";
  $devices->{bz_wandthermostat}->{fhem_name} ="OG_BZ_WT01";
  $devices->{bz_wandthermostat}->{location}  ="badezimmer";
  $devices->{bz_wandthermostat}->{templates} =['readings_low_bat_limit_rt','readings_bat_level','hm','global'];
  $devices->{bz_wandthermostat}->{composite} =["bz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $devices->{bz_wandthermostat_climate}->{alias}     ="BZ Wandthermostat (Ch)";
  $devices->{bz_wandthermostat_climate}->{fhem_name} ="OG_BZ_WT01_Climate";
  $devices->{bz_wandthermostat_climate}->{templates} =['readings_th2','readings_bat_status','hm_channel','global'];  
  #<<<
  
  $devices->{ka_wandthermostat}->{alias}     ="KA Wandthermostat";
  $devices->{ka_wandthermostat}->{fhem_name} ="OG_KA_WT01";
  $devices->{ka_wandthermostat}->{location}  ="paula";
  $devices->{ka_wandthermostat}->{templates} =['readings_low_bat_limit_rt','readings_bat_level','hm','global'];
  $devices->{ka_wandthermostat}->{composite} =["ka_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $devices->{ka_wandthermostat_climate}->{alias}     ="KA Wandthermostat (Ch)";
  $devices->{ka_wandthermostat_climate}->{fhem_name} ="OG_KA_WT01_Climate";
  $devices->{ka_wandthermostat_climate}->{templates} =['readings_th2','readings_bat_status','hm_channel','global'];  
  #<<<
  
  $devices->{kb_wandthermostat}->{alias}     ="KB Wandthermostat";
  $devices->{kb_wandthermostat}->{fhem_name} ="OG_KA_WT01";
  $devices->{kb_wandthermostat}->{location}  ="hanna";
  $devices->{kb_wandthermostat}->{templates} =['readings_low_bat_limit_rt','readings_bat_level','hm','global'];
  $devices->{kb_wandthermostat}->{composite} =["kb_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $devices->{kb_wandthermostat_climate}->{alias}     ="KB Wandthermostat (Ch)";
  $devices->{kb_wandthermostat_climate}->{fhem_name} ="OG_KB_WT01_Climate";
  $devices->{kb_wandthermostat_climate}->{templates} =['readings_th2','readings_bat_status','hm_channel','global'];  
  #<<<
  
  # >>>
  $devices->{virtual_sun_sensor}->{alias}       ="Virtueller Sonnen-Sensor";
  $devices->{virtual_sun_sensor}->{templates}=['virtual'];
  $devices->{virtual_sun_sensor}->{location}    ="umwelt";
  $devices->{virtual_sun_sensor}->{comment}     ="Virtueller Sensor mit (berechneten) Readings zur Steuerungszwecken.";
  $devices->{virtual_sun_sensor}->{composite} =["twilight_sensor","virtual_umwelt_sensor:luminosity"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $devices->{virtual_sun_sensor}->{readings}->{sun}->{ValueFn} = "HAL_SunValueFn";
  $devices->{virtual_sun_sensor}->{readings}->{sun}->{FnParams} = [["um_vh_licht:luminosity",10,15], ["um_hh_licht_th:luminosity",10,15], ["um_vh_bw_licht:brightness",120,130]]; # Liste der Lichtsensoren zur Auswertung mit Grenzwerten (je 2 wg. Histerese)
  $devices->{virtual_sun_sensor}->{readings}->{sun}->{alias} = "Virtuelle Sonne";
  $devices->{virtual_sun_sensor}->{readings}->{sun}->{comment} = "gibt an, ob die 'Sonne' scheint, oder ob es genuegend dunkel ist (z.B. Rolladensteuerung).";
  #<<<
  
  $devices->{twilight_sensor}->{alias}       ="Virtueller Sonnen-Sensor";
  $devices->{twilight_sensor}->{templates}=['virtual'];
  $devices->{twilight_sensor}->{fhem_name}   ="T";
  $devices->{twilight_sensor}->{location}    ="umwelt";
  $devices->{twilight_sensor}->{comment}     ="Virtueller Sensor mit (berechneten) Readings zur Steuerungszwecken.";
  $devices->{twilight_sensor}->{readings}->{azimuth} ->{reading}   ="azimuth";
  $devices->{twilight_sensor}->{readings}->{azimuth} ->{unit}      ="grad";
  $devices->{twilight_sensor}->{readings}->{azimuth} ->{alias}     ="Sonnenazimuth";
  $devices->{twilight_sensor}->{readings}->{elevation} ->{reading} ="elevation";
  $devices->{twilight_sensor}->{readings}->{elevation} ->{unit}    ="grad";
  $devices->{twilight_sensor}->{readings}->{elevation} ->{alias}   ="Sonnenhoehe";
  $devices->{twilight_sensor}->{readings}->{horizon} ->{reading}   ="horizon";
  $devices->{twilight_sensor}->{readings}->{horizon} ->{unit}      ="grad";
  $devices->{twilight_sensor}->{readings}->{horizon} ->{alias}     ="Stand über den Horizon";
  $devices->{twilight_sensor}->{readings}->{sunrise} ->{reading}    ="sr";
  $devices->{twilight_sensor}->{readings}->{sunrise} ->{unit}       ="time";
  $devices->{twilight_sensor}->{readings}->{sunrise} ->{alias}      ="Sonnenaufgang";
  $devices->{twilight_sensor}->{readings}->{sunset} ->{reading}     ="ss";
  $devices->{twilight_sensor}->{readings}->{sunset} ->{unit}        ="time";
  $devices->{twilight_sensor}->{readings}->{sunset} ->{alias}       ="Sonnenuntergang";
  #<<<
  
  
  
  # >>>
  $devices->{virtual_umwelt_sensor}->{alias}       ="Virtuelle Umweltsensoren";
  #$devices->{virtual_umwelt_sensor}->{type}        ="virtual";
  $devices->{virtual_umwelt_sensor}->{location}    ="umwelt";
  $devices->{virtual_umwelt_sensor}->{comment}     ="Virtueller Sensor: Berechnet Max. Helligkeit mehreren Sensoren, Durchschnittstemperatur etc.";
  $devices->{virtual_umwelt_sensor}->{templates}   =['readings_th','readings_lux','readings_dewpoint','virtual'];
  $devices->{virtual_umwelt_sensor}->{readings}->{luminosity}->{ValueFn} = "HAL_MaxReadingValueFn";
  $devices->{virtual_umwelt_sensor}->{readings}->{luminosity}->{FnParams} = ["um_vh_licht:luminosity", "um_hh_licht_th:luminosity"];
  #$devices->{virtual_umwelt_sensor}->{readings}->{luminosity}->{unit} = "Lx";
  #$devices->{virtual_umwelt_sensor}->{readings}->{luminosity}->{alias} = "Kombiniertes Lichtsensor";
  $devices->{virtual_umwelt_sensor}->{readings}->{luminosity}->{comment} = "Kombiniert Werte beider Sensoren und nimmt das Maximum. Damit soll der Einfluss von Hausschatten entfernt werden.";
  $devices->{virtual_umwelt_sensor}->{readings}->{temperature}->{ValueFn} = "HAL_MinReadingValueFn";
  $devices->{virtual_umwelt_sensor}->{readings}->{temperature}->{ValueFilterFn} = "HAL_round1";
  $devices->{virtual_umwelt_sensor}->{readings}->{temperature}->{FnParams} = ["um_vh_owts01:temperature", "um_hh_licht_th:temperature", "hg_sensor:temperature"];
  #$devices->{virtual_umwelt_sensor}->{readings}->{temperature}->{unit} = "°C";
  #$devices->{virtual_umwelt_sensor}->{readings}->{temperature}->{alias} = "Kombiniertes Temperatursensor";
  $devices->{virtual_umwelt_sensor}->{readings}->{temperature}->{comment} = "Kombiniert Werte mehrerer Sensoren und bildet einen Durchschnittswert.";
  $devices->{virtual_umwelt_sensor}->{readings}->{humidity}->{ValueFn} = "HAL_AvgReadingValueFn";
  $devices->{virtual_umwelt_sensor}->{readings}->{humidity}->{ValueFilterFn} = "HAL_round1";
  $devices->{virtual_umwelt_sensor}->{readings}->{humidity}->{FnParams} = ["um_hh_licht_th:humidity"];#["um_hh_licht_th:humidity", "hg_sensor:humidity"];
  #$devices->{virtual_umwelt_sensor}->{readings}->{humidity}->{unit} = "% rH";
  #$devices->{virtual_umwelt_sensor}->{readings}->{humidity}->{alias} = "Kombiniertes Feuchtesensor";
  $devices->{virtual_umwelt_sensor}->{readings}->{humidity}->{comment} = "Kombiniert Werte mehrerer Sensoren und bildet einen Durchschnittswert.";
  #$devices->{virtual_umwelt_sensor}->{readings}->{dewpoint}->{ValueFn} = "HAL_TaupunktValueFn";
  #$devices->{virtual_umwelt_sensor}->{readings}->{dewpoint}->{unit} = "°C";
  #$devices->{virtual_umwelt_sensor}->{readings}->{dewpoint}->{FnParams} = ["temperature", "humidity"];
  #$devices->{virtual_umwelt_sensor}->{readings}->{dewpoint}->{alias}   = "Taupunkt";
  #$devices->{virtual_umwelt_sensor}->{readings}->{absFeuchte}->{ValueFn} = "HAL_AbsFeuchteValueFn";
  #$devices->{virtual_umwelt_sensor}->{readings}->{absFeuchte}->{unit} = "g/m3";
  #$devices->{virtual_umwelt_sensor}->{readings}->{absFeuchte}->{alias}   = "Absolute Feuchte";
  #<<<

  # >>> Virtuelle Raumsensoren  
  $devices->{virtual_raum_sensor_wz}->{alias}       ="Virtueller Raumsensor: WZ";
  $devices->{virtual_raum_sensor_wz}->{location}    ="wohnzimmer";
  $devices->{virtual_raum_sensor_wz}->{templates}   =['virtual_raum_sensor'];
  
  $devices->{virtual_raum_sensor_ku}->{alias}       ="Virtueller Raumsensor: KU";
  $devices->{virtual_raum_sensor_ku}->{location}    ="kueche";
  $devices->{virtual_raum_sensor_ku}->{templates}   =['virtual_raum_sensor'];
  
  $devices->{virtual_raum_sensor_sz}->{alias}       ="Virtueller Raumsensor";
  $devices->{virtual_raum_sensor_sz}->{location}    ="schlafzimmer";
  $devices->{virtual_raum_sensor_sz}->{templates}   =['virtual_raum_sensor'];
  
  $devices->{virtual_raum_sensor_bz}->{alias}       ="Virtueller Raumsensor";
  $devices->{virtual_raum_sensor_bz}->{location}    ="badezimmer";
  $devices->{virtual_raum_sensor_bz}->{templates}   =['virtual_raum_sensor'];

  $devices->{virtual_raum_sensor_ka}->{alias}       ="Virtueller Raumsensor";
  $devices->{virtual_raum_sensor_ka}->{location}    ="paula";
  $devices->{virtual_raum_sensor_ka}->{templates}   =['virtual_raum_sensor'];

  $devices->{virtual_raum_sensor_kb}->{alias}       ="Virtueller Raumsensor";
  $devices->{virtual_raum_sensor_kb}->{location}    ="hanna";
  $devices->{virtual_raum_sensor_kb}->{templates}   =['virtual_raum_sensor'];
    
  $devices->{virtual_raum_sensor_ef}->{alias}       ="Virtueller Raumsensor";
  $devices->{virtual_raum_sensor_ef}->{location}    ="eg_flur";
  $devices->{virtual_raum_sensor_ef}->{templates}   =['virtual_raum_sensor'];

  $devices->{virtual_raum_sensor_of}->{alias}       ="Virtueller Raumsensor";
  $devices->{virtual_raum_sensor_of}->{location}    ="og_flur";
  $devices->{virtual_raum_sensor_of}->{templates}   =['virtual_raum_sensor'];

  $devices->{virtual_raum_sensor_ga}->{alias}       ="Virtueller Raumsensor";
  $devices->{virtual_raum_sensor_ga}->{location}    ="garage";
  $devices->{virtual_raum_sensor_ga}->{templates}   =['virtual_raum_sensor'];
  #TODO: ggf. Weitere Räume

  # Schatten berechen: fuer X Meter Hohen Gegenstand :  {X/tan(deg2rad(50))}
  # >>> virtual_fenster: WZ
  # Fenster-Höhen: WZ: 210 (unten 92), Terrassentuer: 207
  $devices->{virtual_wz_fenster}->{alias}     = "Wohnzimmer Fenster";
  $devices->{virtual_wz_fenster}->{templates} = ['virtual_fenster','virtual'];
  $devices->{virtual_wz_fenster}->{location}  = "wohnzimmer";
  $devices->{virtual_wz_fenster}->{comment}   = "Wohnzimmer: Fenster: Zustand und Sonne";
  $devices->{virtual_wz_fenster}->{composite} =["eg_wz_fk01:state","eg_wz_rl01:level","twilight_sensor:azimuth,elevation",
                                                "wz_ms_sensor:motiontime,motion15m,motion1h"];
  $devices->{virtual_wz_fenster}->{readings}->{dim_top}->{ValueFn} = "{2.10}";
  $devices->{virtual_wz_fenster}->{readings}->{dim_bottom}->{ValueFn} = "{0.92}";
  $devices->{virtual_wz_fenster}->{readings}->{secure}->{FnParams} = ['eg_wz_fk01:state'];
  $devices->{virtual_wz_fenster}->{readings}->{sunny_side}->{FnParams} = [215,315]; # zu beachtender Winkel (Azimuth): von, bis
  $devices->{virtual_wz_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.10, 0.57, 265]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  $devices->{virtual_wz_fenster}->{readings}->{presence}->{link} = "wz_ms_sensor:motion15m"; # PIR als Presence-Sensor verwenden
  #<<<
  
  # >>> virtual_fenster: WZ
  $devices->{virtual_wz_terrassentuer}->{alias}     = "Wohnzimmer Terrassentuer";
  $devices->{virtual_wz_terrassentuer}->{templates} = ['virtual_fenster','virtual'];
  $devices->{virtual_wz_terrassentuer}->{location}  = "wohnzimmer";
  $devices->{virtual_wz_terrassentuer}->{comment}   = "Wohnzimmer: Terrassentuer: Zustand und Sonne";
  $devices->{virtual_wz_terrassentuer}->{composite} =["eg_wz_tk:state","eg_wz_rl02:level","twilight_sensor:azimuth,elevation",
                                                      "wz_ms_sensor:motiontime,motion15m,motion1h"]; # TODO: Kombiniertes 2-KontaktSensor
  $devices->{virtual_wz_terrassentuer}->{readings}->{dim_top}->{ValueFn} = "{2.07}";
  $devices->{virtual_wz_terrassentuer}->{readings}->{dim_bottom}->{ValueFn} = "{0.12}";
  $devices->{virtual_wz_terrassentuer}->{readings}->{secure}->{FnParams} = ['eg_wz_tk:state']; # Kombiniertes 2-KontaktSensor
  $devices->{virtual_wz_terrassentuer}->{readings}->{sunny_side}->{FnParams} = [195,315]; # Beachten Winkel (Azimuth): von, bis
  $devices->{virtual_wz_terrassentuer}->{readings}->{sunny_room_range}->{FnParams} = [2.07, 0.58, 265]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  $devices->{virtual_wz_terrassentuer}->{readings}->{presence}->{link} = "wz_ms_sensor:motion15m"; # PIR als Presence-Sensor verwenden
  #<<<
  
  # >>> virtual_fenster: KU
  $devices->{virtual_ku_fenster}->{alias}     = "Kueche Fenster";
  $devices->{virtual_ku_fenster}->{templates} = ['virtual_fenster','virtual'];
  $devices->{virtual_ku_fenster}->{location}  = "kueche";
  $devices->{virtual_ku_fenster}->{comment}   = "Kueche: Fenster: Zustand und Sonne";
  $devices->{virtual_ku_fenster}->{composite} =["eg_ku_fk01:state","eg_ku_rl01:level","twilight_sensor:azimuth,elevation"];  
  $devices->{virtual_ku_fenster}->{readings}->{dim_top}->{ValueFn} = "{2.12}";
  $devices->{virtual_ku_fenster}->{readings}->{dim_bottom}->{ValueFn} = "{1.28}";
  $devices->{virtual_ku_fenster}->{readings}->{secure}->{FnParams} = ['eg_ku_fk01:state'];
  $devices->{virtual_ku_fenster}->{readings}->{sunny_side}->{FnParams} = [43,144];
  $devices->{virtual_ku_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.12, 0.55, 85]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  #<<<
  
  # >>> virtual_fenster: SZ
  $devices->{virtual_sz_fenster}->{alias}     = "Schlafzimmer Fenster";
  $devices->{virtual_sz_fenster}->{templates} = ['virtual_fenster','virtual'];
  $devices->{virtual_sz_fenster}->{location}  = "schlafzimmer";
  $devices->{virtual_sz_fenster}->{comment}   = "Schlafzimmer: Fenster: Zustand und Sonne";
  $devices->{virtual_sz_fenster}->{composite} =["og_sz_fk01:state","og_sz_rl01:level","twilight_sensor:azimuth,elevation"];
  $devices->{virtual_sz_fenster}->{readings}->{dim_top}->{ValueFn} = "{2.12}";
  $devices->{virtual_sz_fenster}->{readings}->{dim_bottom}->{ValueFn} = "{1.28}";
  $devices->{virtual_sz_fenster}->{readings}->{secure}->{FnParams} = ['og_sz_fk01:state'];
  $devices->{virtual_sz_fenster}->{readings}->{sunny_side}->{FnParams} = [215,315];
  $devices->{virtual_sz_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.10, 0.57, 265]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  #<<<
  
  # >>> virtual_fenster: BZ
  $devices->{virtual_bz_fenster}->{alias}     = "Badezimmer Fenster";
  $devices->{virtual_bz_fenster}->{templates} = ['virtual_fenster','virtual'];
  $devices->{virtual_bz_fenster}->{location}  = "badezimmer";
  $devices->{virtual_bz_fenster}->{comment}   = "Badezimmer: Fenster: Zustand und Sonne";
  $devices->{virtual_bz_fenster}->{composite} =["og_bz_fk01:state","og_bz_rl01:level","twilight_sensor:azimuth,elevation"];  
  $devices->{virtual_bz_fenster}->{readings}->{dim_top}->{ValueFn} = "{2.12}";
  $devices->{virtual_bz_fenster}->{readings}->{dim_bottom}->{ValueFn} = "{1.28}";
  $devices->{virtual_bz_fenster}->{readings}->{secure}->{FnParams} = ['og_bz_fk01:state'];
  $devices->{virtual_bz_fenster}->{readings}->{sunny_side}->{FnParams} = [43,144];
  $devices->{virtual_bz_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.12, 0.55, 85]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  #<<<
  
  # >>> virtual_fenster: KA
  $devices->{virtual_ka_fenster}->{alias}     = "Kinderzimmer1 Fenster";
  $devices->{virtual_ka_fenster}->{templates} = ['virtual_fenster','virtual'];
  $devices->{virtual_ka_fenster}->{location}  = "paula";
  $devices->{virtual_ka_fenster}->{comment}   = "Kinderzimmer1: Fenster: Zustand und Sonne";
  $devices->{virtual_ka_fenster}->{composite} =["og_ka_fk:state","og_ka_rl01:level","twilight_sensor:azimuth,elevation"];
  $devices->{virtual_ka_fenster}->{readings}->{dim_top}->{ValueFn}     = "{2.12}";
  $devices->{virtual_ka_fenster}->{readings}->{dim_bottom}->{ValueFn}  = "{1.28}";
  $devices->{virtual_ka_fenster}->{readings}->{secure}->{FnParams}     = ['og_ka_fk01:state'];
  $devices->{virtual_ka_fenster}->{readings}->{sunny_side}->{FnParams} = [195,315];
  $devices->{virtual_ka_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.12, 0.55, 265]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  #<<<
  
  # >>> virtual_fenster: KB
  $devices->{virtual_kb_fenster}->{alias}     = "Kinderzimmer2 Fenster";
  $devices->{virtual_kb_fenster}->{templates} = ['virtual_fenster','virtual'];
  $devices->{virtual_kb_fenster}->{location}  = "hanna";
  $devices->{virtual_kb_fenster}->{comment}   = "Kinderzimmer2: Fenster: Zustand und Sonne";
  $devices->{virtual_kb_fenster}->{composite} =["og_kb_fk01:state","og_kb_rl01:level","twilight_sensor:azimuth,elevation"];  
  $devices->{virtual_kb_fenster}->{readings}->{dim_top}->{ValueFn}     = "{2.12}";
  $devices->{virtual_kb_fenster}->{readings}->{dim_bottom}->{ValueFn}  = "{1.28}";
  $devices->{virtual_kb_fenster}->{readings}->{secure}->{FnParams}     = ['og_kb_fk01:state'];
  $devices->{virtual_kb_fenster}->{readings}->{sunny_side}->{FnParams} = [43,144];
  $devices->{virtual_kb_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.12, 0.55, 85]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  #<<<

  $devices->{hg_sensor}->{alias}     ="Garten-Sensor";
  $devices->{hg_sensor}->{fhem_name} ="GSD_1.4";
  $devices->{hg_sensor}->{templates} =['gsd'];
  $devices->{hg_sensor}->{location}  ="garten";
  #<<<
  
  $devices->{tt_sensor}->{alias}     ="Test-Sensor";
  $devices->{tt_sensor}->{fhem_name} ="GSD_1.1";
  $devices->{tt_sensor}->{templates} =['gsd'];
  $devices->{tt_sensor}->{location}  ="wohnzimmer";
  #<<<
  
  $devices->{of_sensor}->{alias}     ="OG AR Sensor";
  $devices->{of_sensor}->{fhem_name} ="GSD_1.3";
  $devices->{of_sensor}->{templates} =['gsd'];
  $devices->{of_sensor}->{location}  ="OG_AR";
  #<<<
  
  #>>> MySensors
  $devices->{ga_sensor}->{alias}     ="Garage Kombisensor";
  $devices->{ga_sensor}->{fhem_name} ="EG_GA_MS01";
  $devices->{ga_sensor}->{templates} =['ms_combi_lmth'];
  $devices->{ga_sensor}->{location}  ="garage";
  #<<<
  
  $devices->{wz_ms_sensor}->{alias}     ="WZ MS Kombisensor";
  $devices->{wz_ms_sensor}->{fhem_name} ="EG_WZ_MS01";
  $devices->{wz_ms_sensor}->{templates} =['ms_combi_lm'];
  $devices->{wz_ms_sensor}->{location}  ="wohnzimmer";
  #<<<
  
  $devices->{fl_eg_ms_sensor}->{alias}     ="FL EG MS Kombisensor";
  $devices->{fl_eg_ms_sensor}->{fhem_name} ="EG_FL_MS01";
  $devices->{fl_eg_ms_sensor}->{templates} =['ms_combi_lm'];
  $devices->{fl_eg_ms_sensor}->{location}  ="eg_flur";
  #<<<

  $devices->{fl_og_ms_sensor}->{alias}     ="FL OG MS Kombisensor";
  $devices->{fl_og_ms_sensor}->{fhem_name} ="OG_FL_MS01";
  $devices->{fl_og_ms_sensor}->{templates} =['ms_combi_lm'];
  $devices->{fl_og_ms_sensor}->{location}  ="og_flur";
  #<<<
  
  $devices->{um_vh_bw_licht}->{alias}     ="Bewegungsmelder (Vorgarten)";
  $devices->{um_vh_bw_licht}->{fhem_name} ="UM_VH_HMBL01.Eingang";
  $devices->{um_vh_bw_licht}->{templates} =['hm'];
  #$devices->{um_vh_bw_licht}->{type}      ="HomeMatic";
  $devices->{um_vh_bw_licht}->{location}  ="umwelt";
  $devices->{um_vh_bw_licht}->{readings}->{brightness}  ->{reading}   ="brightness";
  $devices->{um_vh_bw_licht}->{readings}->{brightness}  ->{alias}     ="Helligkeit";
  $devices->{um_vh_bw_licht}->{readings}->{brightness}  ->{unit}      ="RANGE: 0-250";
  $devices->{um_vh_bw_licht}->{readings}->{brightness}  ->{act_cycle} ="600";
  $devices->{um_vh_bw_licht}->{readings}->{brightness}  ->{level} ='2';
  #<<<
  
  $devices->{um_vh_bw_motion}->{alias}     ="Bewegungsmelder (Vorgarten)";
  $devices->{um_vh_bw_motion}->{fhem_name} ="UM_VH_HMBL01.Eingang";
  $devices->{um_vh_bw_motion}->{templates} =['hm','readings_bat_status','readings_motion_set'];
  $devices->{um_vh_bw_motion}->{location}  ="vorgarten";
  #<<<
  
  #>>> OneWire
  $devices->{um_vh_owts01}->{alias}     ="OWX Aussentemperatur";
  $devices->{um_vh_owts01}->{fhem_name} ="UM_VH_OWTS01.Luft";
  $devices->{um_vh_owts01}->{templates} =['owx_temp'];
  $devices->{um_vh_owts01}->{location}  ="umwelt";
  #<<<
  
  $devices->{eg_ga_owts01}->{alias}     ="OWX Garage";
  $devices->{eg_ga_owts01}->{fhem_name} ="EG_GA_OWTS01.Raum";
  $devices->{eg_ga_owts01}->{templates} =['owx_temp'];
  $devices->{eg_ga_owts01}->{location}  ="garage";
  #<<<
  
  $devices->{eg_fl_owts01}->{alias}     ="OWX Flur";
  $devices->{eg_fl_owts01}->{fhem_name} ="EG_FL_OWTS01.Raum";
  $devices->{eg_fl_owts01}->{templates} =['owx_temp'];
  $devices->{eg_fl_owts01}->{location}  ="eg_flur";
  #<<<
  
  $devices->{eg_wc_owts01}->{alias}     ="OWX Gäste WC";
  $devices->{eg_wc_owts01}->{fhem_name} ="EG_WC_OWTS01.Raum";
  $devices->{eg_wc_owts01}->{templates} =['owx_temp'];
  $devices->{eg_wc_owts01}->{location}  ="wc";
  #<<<
  
  $devices->{eg_ha_owts01}->{alias}     ="OWX HWR";
  $devices->{eg_ha_owts01}->{fhem_name} ="EG_HA_OWTS01.Raum_Oben";
  $devices->{eg_ha_owts01}->{templates} =['owx_temp'];
  $devices->{eg_ha_owts01}->{location}  ="hwr";
  #<<<
  
  #TODO: template
  $devices->{eg_ku_rl01}->{alias}     ="Rollo";
  $devices->{eg_ku_rl01}->{fhem_name} ="ku_rollo";
  $devices->{eg_ku_rl01}->{type}      ="HomeMatic";
  $devices->{eg_ku_rl01}->{location}  ="kueche";
  $devices->{eg_ku_rl01}->{comment}   ="Rollostand";
  $devices->{eg_ku_rl01}->{readings}->{level} ->{reading}   ="level";
  $devices->{eg_ku_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $devices->{eg_ku_rl01}->{readings}->{level} ->{unit} ="%";
  #<<<
  
  $devices->{eg_ku_fk01}->{alias}     ="Fensterkontakt";
  $devices->{eg_ku_fk01}->{fhem_name} ="EG_KU_FK01.Fenster";
  $devices->{eg_ku_fk01}->{type}      ="HomeMatic";
  $devices->{eg_ku_fk01}->{location}  ="kueche";
  $devices->{eg_ku_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{eg_ku_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{eg_ku_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{eg_ku_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{eg_ku_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{eg_ku_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{eg_ku_fk01}->{readings}->{state}        ->{reading}   ="state";
  $devices->{eg_ku_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{eg_ku_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $devices->{eg_ku_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{eg_ku_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{eg_ku_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{eg_ku_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{eg_ku_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{eg_ku_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #TODO: Mapping f. Zustaende: closed => geschlossen?
  #<<<
  
  $devices->{eg_wz_rl}->{alias}     ="Rollos Kombiniert";
  $devices->{eg_wz_rl}->{type}      ="virtual";
  $devices->{eg_wz_rl}->{location}  ="wohnzimmer";
  $devices->{eg_wz_rl}->{readings}->{level}         ->{ValueFn}   ="HAL_AvgReadingValueFn";
  $devices->{eg_wz_rl}->{readings}->{level}         ->{FnParams}  =["eg_wz_rl01:level","eg_wz_rl02:level"];
  $devices->{eg_wz_rl}->{readings}->{level}         ->{ValueFilterFn} = "HAL_round0";
  $devices->{eg_wz_rl}->{readings}->{level}         ->{alias}     ="Rollostand Durchschnitt";
  $devices->{eg_wz_rl}->{readings}->{level}         ->{unit}      ="%";
  $devices->{eg_wz_rl}->{readings}->{level1}        ->{link}      = "eg_wz_rl01:level";
  $devices->{eg_wz_rl}->{readings}->{level2}        ->{link}      = "eg_wz_rl02:level";
  $devices->{eg_wz_rl}->{readings}->{leveltime_str} ->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{eg_wz_rl}->{readings}->{leveltime_str} ->{FnParams}  = "level";
  $devices->{eg_wz_rl}->{readings}->{leveltime}     ->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{eg_wz_rl}->{readings}->{leveltime}     ->{FnParams}  = "level";
  $devices->{eg_wz_rl}->{readings}->{leveltime}     ->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{eg_wz_rl}->{readings}->{leveltime}     ->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{eg_wz_rl01}->{alias}     ="Rollo";
  $devices->{eg_wz_rl01}->{fhem_name} ="wz_rollo_l";
  $devices->{eg_wz_rl01}->{type}      ="HomeMatic";
  $devices->{eg_wz_rl01}->{location}  ="wohnzimmer";
  $devices->{eg_wz_rl01}->{comment}   ="Rollostand";
  $devices->{eg_wz_rl01}->{readings}->{level} ->{reading}   ="level";
  $devices->{eg_wz_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $devices->{eg_wz_rl01}->{readings}->{level} ->{unit} ="%";
  #<<<
  
  $devices->{eg_wz_rl02}->{alias}     ="Rollo";
  $devices->{eg_wz_rl02}->{fhem_name} ="wz_rollo_r";
  $devices->{eg_wz_rl02}->{type}      ="HomeMatic";
  $devices->{eg_wz_rl02}->{location}  ="wohnzimmer";
  $devices->{eg_wz_rl02}->{comment}   ="Rollostand";
  $devices->{eg_wz_rl02}->{readings}->{level} ->{reading}   ="level";
  $devices->{eg_wz_rl02}->{readings}->{level} ->{alias}     ="Rollostand";
  $devices->{eg_wz_rl02}->{readings}->{level} ->{unit} ="%";
  #<<<
  
  $devices->{eg_wz_fk01}->{alias}     ="Fensterkontakt";
  $devices->{eg_wz_fk01}->{fhem_name} ="EG_WZ_FK01.Fenster";
  $devices->{eg_wz_fk01}->{type}      ="HomeMatic";
  $devices->{eg_wz_fk01}->{location}  ="wohnzimmer";
  $devices->{eg_wz_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{eg_wz_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{eg_wz_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{eg_wz_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{eg_wz_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{eg_wz_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{eg_wz_fk01}->{readings}->{state}        ->{reading}   ="state";
  $devices->{eg_wz_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{eg_wz_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $devices->{eg_wz_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{eg_wz_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{eg_wz_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{eg_wz_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{eg_wz_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{eg_wz_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{eg_wz_tk01}->{alias}     ="Terrassentürkontakt Links";
  $devices->{eg_wz_tk01}->{fhem_name} ="wz_fenster_l";
  $devices->{eg_wz_tk01}->{type}      ="HomeMatic";
  $devices->{eg_wz_tk01}->{location}  ="wohnzimmer";
  $devices->{eg_wz_tk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{eg_wz_tk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{eg_wz_tk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{eg_wz_tk01}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{eg_wz_tk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{eg_wz_tk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{eg_wz_tk01}->{readings}->{state}        ->{reading}   ="state";
  $devices->{eg_wz_tk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{eg_wz_tk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open";
  $devices->{eg_wz_tk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{eg_wz_tk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{eg_wz_tk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{eg_wz_tk01}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{eg_wz_tk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{eg_wz_tk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{eg_wz_tk02}->{alias}     ="Terrassentürkontakt Recht";
  $devices->{eg_wz_tk02}->{fhem_name} ="wz_fenster_r";
  $devices->{eg_wz_tk02}->{type}      ="HomeMatic";
  $devices->{eg_wz_tk02}->{location}  ="wohnzimmer";
  $devices->{eg_wz_tk02}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{eg_wz_tk02}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{eg_wz_tk02}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{eg_wz_tk02}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{eg_wz_tk02}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{eg_wz_tk02}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{eg_wz_tk02}->{readings}->{state}        ->{reading}   ="state";
  $devices->{eg_wz_tk02}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{eg_wz_tk02}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open";
  $devices->{eg_wz_tk02}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{eg_wz_tk02}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{eg_wz_tk02}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{eg_wz_tk02}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{eg_wz_tk02}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{eg_wz_tk02}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{eg_wz_tk}->{alias}     ="Terrassentürkontakt Kombiniert";
  $devices->{eg_wz_tk}->{type}      ="virtual";
  $devices->{eg_wz_tk}->{location}  ="wohnzimmer";
  $devices->{eg_wz_tk}->{readings}->{state}         ->{ValueFn}   ="HAL_WinCombiStateValueFn";
  $devices->{eg_wz_tk}->{readings}->{state}         ->{FnParams}   =["eg_wz_tk01:state","eg_wz_tk02:state"];
  $devices->{eg_wz_tk}->{readings}->{state}         ->{alias}     ="Terrassentuerzustand";
  $devices->{eg_wz_tk}->{readings}->{state}         ->{unit_type} ="ENUM: closed,open";
  $devices->{eg_wz_tk}->{readings}->{state1}        ->{link}   = "eg_wz_tk01:state";
  $devices->{eg_wz_tk}->{readings}->{state2}        ->{link}   = "eg_wz_tk02:state";
  $devices->{eg_wz_tk}->{readings}->{statetime1}    ->{link}   = "eg_wz_tk01:statetime";
  $devices->{eg_wz_tk}->{readings}->{statetime2}    ->{link}   = "eg_wz_tk02:statetime";
  $devices->{eg_wz_tk}->{readings}->{statetime1_str}->{link}   = "eg_wz_tk01:statetime_str";
  $devices->{eg_wz_tk}->{readings}->{statetime2_str}->{link}   = "eg_wz_tk02:statetime_str";
  $devices->{eg_wz_tk}->{readings}->{statetime_str} ->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{eg_wz_tk}->{readings}->{statetime_str} ->{FnParams}  = "state";
  $devices->{eg_wz_tk}->{readings}->{statetime}     ->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{eg_wz_tk}->{readings}->{statetime}     ->{FnParams}  = "state";
  $devices->{eg_wz_tk}->{readings}->{statetime}     ->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{eg_wz_tk}->{readings}->{statetime}     ->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{og_bz_rl01}->{alias}     ="Rollo";
  $devices->{og_bz_rl01}->{fhem_name} ="bz_rollo";
  $devices->{og_bz_rl01}->{type}      ="HomeMatic";
  $devices->{og_bz_rl01}->{location}  ="badezimmer";
  $devices->{og_bz_rl01}->{comment}   ="Rollostand";
  $devices->{og_bz_rl01}->{readings}->{level} ->{reading}   ="level";
  $devices->{og_bz_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $devices->{og_bz_rl01}->{readings}->{level} ->{unit} ="%";
  #<<<
  
  $devices->{og_bz_fk01}->{alias}     ="Fensterkontakt";
  $devices->{og_bz_fk01}->{fhem_name} ="OG_BZ_FK01.Fenster";
  $devices->{og_bz_fk01}->{type}      ="HomeMatic";
  $devices->{og_bz_fk01}->{location}  ="badezimmer";
  $devices->{og_bz_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{og_bz_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{og_bz_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{og_bz_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{og_bz_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{og_bz_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{og_bz_fk01}->{readings}->{state}        ->{reading}   ="state";
  $devices->{og_bz_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{og_bz_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $devices->{og_bz_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{og_bz_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{og_bz_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{og_bz_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{og_bz_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{og_bz_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{og_sz_rl01}->{alias}     ="Rollo";
  $devices->{og_sz_rl01}->{fhem_name} ="sz_rollo";
  $devices->{og_sz_rl01}->{type}      ="HomeMatic";
  $devices->{og_sz_rl01}->{location}  ="schlafzimmer";
  $devices->{og_sz_rl01}->{comment}   ="Rollostand";
  $devices->{og_sz_rl01}->{readings}->{level} ->{reading}   ="level";
  $devices->{og_sz_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $devices->{og_sz_rl01}->{readings}->{level} ->{unit} ="%";
  #<<<
  
  $devices->{og_sz_fk01}->{alias}     ="Fensterkontakt";
  $devices->{og_sz_fk01}->{fhem_name} ="OG_SZ_FK01.Fenster";
  $devices->{og_sz_fk01}->{type}      ="HomeMatic";
  $devices->{og_sz_fk01}->{location}  ="schlafzimmer";
  $devices->{og_sz_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{og_sz_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{og_sz_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{og_sz_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{og_sz_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{og_sz_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{og_sz_fk01}->{readings}->{state}        ->{reading}   ="state";
  $devices->{og_sz_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{og_sz_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $devices->{og_sz_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{og_sz_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{og_sz_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{og_sz_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{og_sz_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{og_sz_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{og_ka_rl01}->{alias}     ="Rollo";
  $devices->{og_ka_rl01}->{fhem_name} ="ka_rollo";
  $devices->{og_ka_rl01}->{type}      ="HomeMatic";
  $devices->{og_ka_rl01}->{location}  ="hanna";
  $devices->{og_ka_rl01}->{comment}   ="Rollostand";
  $devices->{og_ka_rl01}->{readings}->{level} ->{reading}   ="level";
  $devices->{og_ka_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $devices->{og_ka_rl01}->{readings}->{level} ->{unit} ="%";
  #<<<
  
  $devices->{og_ka_fk}->{alias}     ="Fensterkontakt Kombiniert";
  $devices->{og_ka_fk}->{type}      ="virtual";
  $devices->{og_ka_fk}->{location}  ="hanna";
  $devices->{og_ka_fk}->{readings}->{state}         ->{ValueFn}   ="HAL_WinCombiStateValueFn";
  $devices->{og_ka_fk}->{readings}->{state}         ->{FnParams}   =["og_ka_fk01:state","og_ka_fk02:state"];
  $devices->{og_ka_fk}->{readings}->{state}         ->{alias}     ="Fensterzustand";
  $devices->{og_ka_fk}->{readings}->{state}         ->{unit_type} ="ENUM: closed,open";
  $devices->{og_ka_fk}->{readings}->{state1}        ->{link}   = "og_ka_fk01:state";
  $devices->{og_ka_fk}->{readings}->{state2}        ->{link}   = "og_ka_fk02:state";
  $devices->{og_ka_fk}->{readings}->{statetime1}    ->{link}   = "og_ka_fk01:statetime";
  $devices->{og_ka_fk}->{readings}->{statetime2}    ->{link}   = "og_ka_fk02:statetime";
  $devices->{og_ka_fk}->{readings}->{statetime1_str}->{link}   = "og_ka_fk01:statetime_str";
  $devices->{og_ka_fk}->{readings}->{statetime2_str}->{link}   = "og_ka_fk02:statetime_str";
  $devices->{og_ka_fk}->{readings}->{statetime_str} ->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{og_ka_fk}->{readings}->{statetime_str} ->{FnParams}  = "state";
  $devices->{og_ka_fk}->{readings}->{statetime}     ->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{og_ka_fk}->{readings}->{statetime}     ->{FnParams}  = "state";
  $devices->{og_ka_fk}->{readings}->{statetime}     ->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{og_ka_fk}->{readings}->{statetime}     ->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{og_ka_fk01}->{alias}     ="Fensterkontakt";
  $devices->{og_ka_fk01}->{fhem_name} ="OG_KA_FK01.Fenster";
  $devices->{og_ka_fk01}->{type}      ="HomeMatic";
  $devices->{og_ka_fk01}->{location}  ="paula";
  $devices->{og_ka_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{og_ka_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{og_ka_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{og_ka_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{og_ka_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{og_ka_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{og_ka_fk01}->{readings}->{state}        ->{reading}   ="state";
  $devices->{og_ka_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{og_ka_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $devices->{og_ka_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{og_ka_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{og_ka_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{og_ka_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{og_ka_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{og_ka_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
  
  $devices->{og_ka_fk02}->{alias}     ="Fensterkontakt";
  $devices->{og_ka_fk02}->{fhem_name} ="OG_KA_FK02.Fenster";
  $devices->{og_ka_fk02}->{type}      ="HomeMatic";
  $devices->{og_ka_fk02}->{location}  ="paula";
  $devices->{og_ka_fk02}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{og_ka_fk02}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{og_ka_fk02}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{og_ka_fk02}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{og_ka_fk02}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{og_ka_fk02}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{og_ka_fk02}->{readings}->{state}        ->{reading}   ="state";
  $devices->{og_ka_fk02}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{og_ka_fk02}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $devices->{og_ka_fk02}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{og_ka_fk02}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{og_ka_fk02}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{og_ka_fk02}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{og_ka_fk02}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{og_ka_fk02}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<
    
  $devices->{og_kb_rl01}->{alias}     ="Rollo";
  $devices->{og_kb_rl01}->{fhem_name} ="kb_rollo";
  $devices->{og_kb_rl01}->{type}      ="HomeMatic";
  $devices->{og_kb_rl01}->{location}  ="paula";
  $devices->{og_kb_rl01}->{comment}   ="Rollostand";
  $devices->{og_kb_rl01}->{readings}->{level} ->{reading}   ="level";
  $devices->{og_kb_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $devices->{og_kb_rl01}->{readings}->{level} ->{unit} ="%";
  #<<<
  
  $devices->{og_kb_fk01}->{alias}     ="Fensterkontakt";
  $devices->{og_kb_fk01}->{fhem_name} ="OG_KB_FK01.Fenster";
  $devices->{og_kb_fk01}->{type}      ="HomeMatic";
  $devices->{og_kb_fk01}->{location}  ="hanna";
  $devices->{og_kb_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $devices->{og_kb_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $devices->{og_kb_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $devices->{og_kb_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $devices->{og_kb_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $devices->{og_kb_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $devices->{og_kb_fk01}->{readings}->{state}        ->{reading}   ="state";
  $devices->{og_kb_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $devices->{og_kb_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $devices->{og_kb_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $devices->{og_kb_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $devices->{og_kb_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $devices->{og_kb_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $devices->{og_kb_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $devices->{og_kb_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #<<<

# >>> Actions/Scenarios
# : Conditions

# aliases
# $aliases->{rooms}->{alias_name}="device_name";
# $aliases->{devices}->{alias_name}="device_name";
$aliases->{rooms}->{wz}="wohnzimmer";

$aliases->{devices}->{umweltsensor}="virtual_umwelt_sensor";
#TODO: Aliases definieren


#--- Methods: Utils ------------------------------------------------------------

sub HAL_round0($) {
  my($val)=@_;
  return rundeZahl0($val);
}
  
sub HAL_round1($) {
  my($val)=@_;
  return rundeZahl1($val);
}

sub HAL_round2($) {
  my($val)=@_;
  return rundeZahl2($val);
}

# Taupunkt-MEthoden entnommen aus dewpoint-Modul
# -----------------------------
# Dewpoint calculation.
# see http://www.faqs.org/faqs/meteorology/temp-dewpoint/ "5. EXAMPLE"
sub HAL_dewpoint($$) {
  my ($temperature, $humidity) = @_;
  my $dp;
  my $A = 17.2694;
  my $B = ($temperature > 0) ? 237.3 : 265.5;
  my $es = 610.78 * exp( $A * $temperature / ($temperature + $B) );
  my $e = $humidity/ 100 * $es;
  if ($e == 0) {
    Log 1, "Error: dewpoint() e==0: temp=$temperature, hum=$humidity";
    return 0;
  }
  my $e1 = $e / 610.78;
  my $f = log( $e1 ) / $A;
  my $f1 = 1 - $f;
  if ($f1 == 0) {
  Log 1, "Error: dewpoint() (1-f)==0: temp=$temperature, hum=$humidity";
  return 0;
  }
  $dp = $B * $f / $f1  ;
  return $dp ;
}

sub HAL_absFeuchte ($$) {
  # Formeln von http://kellerlueftung.blogspot.de/p/blog-page_9.html
  #             http://www.wettermail.de/wetter/feuchte.html
  my ($T, $rh) = @_;
  if (($rh < 0) || ($rh > 110)){
    Log 1, "Error dewpoint: humidity invalid: $rh";
    return "";
  }
  # a = 7.5, b = 237.3 für T >= 0
  # a = 7.6, b = 240.7 für T < 0 über Wasser (Taupunkt)
  my $a = ($T > 0) ? 7.5 : 7.6;
  my $b = ($T > 0) ? 237.3 : 240.7;
  my $SDD = 6.1078 * 10**(($a*$T)/($b+$T));
  my $DD  = $rh/100 * $SDD;
  my $AF  = (10**5) * (18.016 / 8314.3) * ($DD / (273.15 + $T));
  my $af  = sprintf( "%.1f",$AF);
  return $af; # $aF = absolute Feuchte in g Wasserdampf pro m3 Luft
}

#--- Methods: User ------------------------------------------------------------
# ValueFn: Berechnet Taupunkt aus Temperatur und Feuchte
# FnParams: Namen der Readings fuer Temperatur und Feuchte (default: 'temperature' und 'humidity')
sub HAL_TaupunktValueFn($$) {
  my ($device, $record) = @_;
  my $params = $record->{FnParams};
  my $tempReading = "temperature";
  my $humReading = "humidity";
  if($params) {
    $tempReading = @{$params}[0];
    $humReading = @{$params}[1];
  }
  
  my $tRec = HAL_getSensorValueRecord($device->{name},$tempReading);
  my $hRec = HAL_getSensorValueRecord($device->{name},$humReading);
  if($tRec && $hRec) {
    my $temp = $tRec->{value};
    my $hum  = $hRec->{value};
    my $time = $tRec->{time};

    if($temp && $hum) {
      my $val = HAL_dewpoint($temp, $hum);
      my $ret;
      $ret->{value} = HAL_round0($val);
      #Log 3,'>------------>: '.$val.', ROUND: '.$ret->{value};
      $ret->{time} = $time;#TimeNow();
      #$ret->{time} = TimeNow();
      #$ret->{reading_name} = $record->{name};
      $ret->{unit} = '°C';
      return $ret;
    }
  }

  return undef;
}

# ValueFn: Berechnet Abs.Feuchte Taupunkt aus Temperatur und Feuchte
# FnParams: Namen der Readings fuer Temperatur und Feuchte (default: 'temperature' und 'humidity')
sub HAL_AbsFeuchteValueFn($$) {
  my ($device, $record) = @_;
  my $params = $record->{FnParams};
  my $tempReading = "temperature";
  my $humReading = "humidity";
  if($params) {
    $tempReading = @{$params}[0];
    $humReading = @{$params}[1];
  }
  
  my $tRec = HAL_getSensorValueRecord($device->{name},$tempReading);
  my $hRec = HAL_getSensorValueRecord($device->{name},$humReading);
  if($tRec && $hRec) {
    my $temp = $tRec->{value};
    my $hum  = $hRec->{value};
    my $time = $tRec->{time};

    if($temp && $hum) {
      my $val = HAL_absFeuchte($temp, $hum);
      my $ret;
      $ret->{value} = HAL_round0($val);
      $ret->{time} = $time;#TimeNow();
      #$ret->{reading_name} = $record->{name};
      $ret->{unit} = 'g/m3';
      return $ret;
    }
  }
          
  return undef;
}

# ValueFn: Berechnet, wieweit die Sonne aktuell ins Zimmer hineinstrahlt (am Boden). Beruecksichtigt nur Azimuth/Elevation, nicht die aktuelle Intensitaet.
# FnParams: Fensterhoehe (Oberkante)
sub HAL_WinSunRoomRangeValueFn($$) {
  my ($device, $record) = @_;
  my $params = $record->{FnParams};
  
  my $val = 0;
  my $msg = undef;
  
  my $sRec = HAL_getSensorValueRecord($device->{name},'sunny_side');
  if($sRec) {
    my $sside = $sRec->{value};
    if($sside==0) {
      $val = 0;
      $msg = $sRec->{message};
    } else {
      $sRec = HAL_getSensorValueRecord($device->{name},'elevation');
      if($sRec) {
      my $elevation = $sRec->{value};
        my $height = @{$params}[0];
        $val = $height/tan(deg2rad($elevation));
        
        # Korrekturfaktor Wanddicke
        #my $cf = HAL_getSensorReadingValue($device->{name},'cf_wall_thickness');
        my $cf = @{$params}[1];
        #if($cf) {
        # $val-=$cf;
        # $val = 0 unless $val>0;
        #}
        
        # Winkel: Elevation bei 90° Winkel zu Fenster
        my $cfW = @{$params}[2];
        if($cfW) {
          my $aRec = HAL_getSensorValueRecord($device->{name},'azimuth');
          if($aRec) {
            my $azimuth = $aRec->{value};
            my $winkel = abs($azimuth-$cfW);
            # Aus dem Winkel die neue Dicke der Wand berechen (entlang der Strahlen)
            my $wdc = $cf/cos(deg2rad($winkel));
            $wdc=$cf if ($wdc<$cf);
            # Bei großen Winkel wird auch sehr groß. Max Fensterbreite ist aber der Begrenzender Faktor (praktisch nicht wirklich relevant).
            $wdc=2 if ($wdc>2); # 2 meter annehmen
            
            #Log 3,'>------------>WD: '.$cf.', W: '.$winkel.', WDC: '.$wdc;
            
            $val-=$wdc;
            $val = 0 unless $val>0;
          }
        }

        # Korrekturfaktor Anpassung
        #my $cf = HAL_getSensorReadingValue($device->{name},'cf_sun_room_range');
        #if($cf) {
        # $val*=$cf;
        #}
        
        #Log 3,'>------------>Val: '.$val;
        $val=HAL_round2($val);
        #Log 3,'>------------>Val: '.$val;
        
        $msg = "elevation: $elevation, height: $height";
      } else {
        $val = 0;
        $msg = 'error: elevation';
      }
    }
  } else {
    $val = 0;
    $msg = 'error: elevation';
  }
  
  my $ret;
  $ret->{value} = $val;
  $ret->{time} = TimeNow();
  #$ret->{reading_name} = $record->{name};
  $ret->{message} = $msg;
  return $ret;
  
}

# ValueFn: Prueft, ob das Fenster auf der Sonnenseite ist (Sonne ist zum Fenster zugewandt: Azimut) und nicht Nacht ist (Elevation).
# FnParams: Liste der zu betrachtenden Fenster/Tueren. Jeder Eintrag muss in Form DevName:ReadingName angegeben sein.
sub HAL_WinSunnySideValueFn($$) {
  my ($device, $record) = @_;
  my $params = $record->{FnParams};
  
  my $val = 0;
  my $msg = undef;
  
  my $sRec = HAL_getSensorValueRecord($device->{name},'elevation');
  if($sRec) {
    if($sRec->{value} < 10) { # XXX fester Wert für Sonnenwinkel. 10 OK?
      $val = 0;
      $msg = 'dark: elevation';
    } else {
      $sRec = HAL_getSensorValueRecord($device->{name},'azimuth');
      if($sRec) {
        my $t = $sRec->{value};
        if($t > @{$params}[0] && $t < @{$params}[1]) {
          $val = 1;
          $msg = 'sunny'; 
        } else {
          $val = 0;
          $msg = 'shady: azimuth (now: '.$t.', Limits: ['.@{$params}[0].', '.@{$params}[1].'])';
        }
      } else {
        $val = 0;
        $msg = 'error: azimuth';
      }
    }
  } else {
    $val = 0;
        $msg = 'error: elevation';
  }
  
  my $ret;
  $ret->{value} = $val;
  $ret->{time} = TimeNow();
  #$ret->{reading_name} = $record->{name};
  $ret->{message} = $msg;
  return $ret;
}

  
# ValueFn: Fragt angegebene (Fenster)Sensoren ab un liefert den Sicherheitsstand (ob alles geschlossen ist).
# FnParams: Liste der zu betrachtenden Fenster/Tueren. Jeder Eintrag muss in Form DevName:ReadingName angegeben sein.
sub HAL_WinSecureStateValueFn($$) {
  my ($device, $record) = @_;
  my $senList = $record->{FnParams};
  
  my $secure = 1;
  my $msg = undef;
  
  foreach my $a (@{$senList}) {
    my($sensorName,$readingName) = split(/:/, $a);
    my $sRec = HAL_getSensorValueRecord($sensorName,$readingName);
    if(!defined($sRec)) {
      $secure=0;
      $msg = 'error: undefined sensor';
      last;
    } elsif(!$sRec->{alive}) {
      $secure=0;
      $msg = 'dead sensor';
      last;
    } else {
      if($sRec->{value} ne 'closed') {
        $secure=0;
        $msg = 'insecure state: '.$sRec->{value};
        last;
      }
    }
  }
  
  my $ret;
  $ret->{value} = $secure;
  $ret->{time} = TimeNow();
  #$ret->{reading_name} = $record->{name};
  $ret->{message} = $msg;
  return $ret;
}  
  
  
# ValueFn: Fragt angegebene Sensoren ab un liefert den Durchschnittswert aller Readings.
# FnParams: Liste der zu betrachtenden Sensoren. Jeder Eintrag muss in Form DevName:ReadingName angegeben sein.
sub HAL_AvgReadingValueFn($$) {
  my ($device, $record) = @_;
  my $senList = $record->{FnParams};
  # keine 'dead' Sensoren verwenden. 
  my $time;
  my $unit;
  my $rname;
  my $aVal = 0;
  my $aCnt = 0;
  foreach my $a (@{$senList}) {
    my($sensorName,$readingName) = split(/:/, $a);
    my $sRec = HAL_getSensorValueRecord($sensorName,$readingName);
    #Log 3,'>------------>Name: '.$sensorName.', Reading: '.$readingName.', val: '. $sRec->{value}.', alive: '.$sRec->{alive};
    if($sRec->{alive}) {
      $aCnt += 1;
      my $sVal = $sRec->{value};
      $aVal += $sVal;
      if(!defined($unit)) { $unit = $sRec->{unit}; }
      if(!defined($rname)) { $rname = $sRec->{name}; }
      if($time && $sRec->{time}) {
        if($time lt $sRec->{time}) { $time = $sRec->{time}; }
      } else {
        $time = $sRec->{time};
      }
    }
    #Log 3,'>------------>aVal: '.$aVal.', aCnt: '.$aCnt;
  }
  if($aCnt>0) {
    my $retVal = $aVal / $aCnt;
    my $ret;
    $ret->{value} = $retVal;
    $ret->{unit} = $unit;
    $ret->{time} = $time;
    #$ret->{name} = $rname;
    return $ret;
  }
  return undef;
}

# ValueFn: Fragt angegebene Sensoren ab un liefert den Min. Wert aller Readings.
# FnParams: Liste der zu betrachtenden Sensoren. Jeder Eintrag muss in Form DevName:ReadingName angegeben sein.
sub HAL_MinReadingValueFn($$) {
  my ($device, $record) = @_;
  my $senList = $record->{FnParams};
  # keine 'dead' Sensoren verwenden. 
  my $time;
  my $unit;
  my $rname;
  my $mVal = undef;
  foreach my $a (@{$senList}) {
    my($sensorName,$readingName) = split(/:/, $a);
    my $sRec = HAL_getSensorValueRecord($sensorName,$readingName);
    if($sRec->{alive}) {
      my $sVal = $sRec->{value};
      if(!defined($mVal) || $sVal<$mVal) {
        $mVal = $sVal;
        $unit = $sRec->{unit};
        $time = $sRec->{time};
        $rname = $sRec->{name};
      }
    }
  }
  my $ret;
  $ret->{value} = $mVal;
  $ret->{unit} = $unit;
  $ret->{time} = $time;
  #$ret->{name} = $rname;
  return $ret;
}

# ValueFn: Fragt angegebene Sensoren ab un liefert den Max. Wert aller Readings.
# FnParams: Liste der zu betrachtenden Sensoren. Jeder Eintrag muss in Form DevName:ReadingName angegeben sein.
sub HAL_MaxReadingValueFn($$) {
  my ($device, $record) = @_;
  my $senList = $record->{FnParams};
  # keine 'dead' Sensoren verwenden.
  my $time;
  my $unit;
  my $rname;
  my $mVal = undef;
  foreach my $a (@{$senList}) {
    my($sensorName,$readingName) = split(/:/, $a);
    my $sRec = HAL_getSensorValueRecord($sensorName,$readingName);
    if($sRec->{alive}) {
      my $sVal = $sRec->{value};
      if(!defined($mVal) || $sVal>$mVal) {
        $mVal = $sVal;
        $unit = $sRec->{unit};
        $time = $sRec->{time};
        $rname = $sRec->{name};
      }
    }
  }
  my $ret;
  $ret->{value} = $mVal;
  $ret->{unit} = $unit;
  $ret->{time} = $time;
  #$ret->{name} = $rname;
  return $ret;
}

# ValueFn: Benutzt Time der angegebenen Reading 
#    (default kann bei direktem Aufruf mitgegeben werden) und
#    berechnet die vergangene Zeitspanne. Ausgabe menschenlesbar
# FnParams: Readingname 
# Params: Dev-Hash, Record-HASH
sub HAL_ReadingTimeStrValueFn($$;$) {
  my ($device, $record, $default) = @_;
  my $rName = $record->{FnParams};
  $rName = $default unless $rName;
  if(!defined($rName)){
    return undef;
  }
  my $t = HAL_ReadingTimeValueFn($device, $record,$rName);
  
  if($t) {
    if(ref $t eq ref {}) {
      # wenn Hash (also kompletter Hash zurückgegeben, mit value, time etc.)
      $t->{value} = sec2Dauer($t->{value});
      return $t;
    } else {
      # Scalar-Wert annehmen
      return sec2Dauer($t);
    }
  }
  return undef;
}

# ValueFn: Benutzt Time der angegebenen Reading (default: motion) und
#    berechnet die vergangene Zeitspanne. Ausgabe menschenlesbar
# FnParams: Readingname 
# Params: Dev-Hash, Record-HASH
sub HAL_MotionTimeStrValueFn($$) {
  my ($device, $record) = @_;
  my $t = HAL_MotionTimeValueFn($device, $record);
  if($t) {
    if(ref $t eq ref {}) {
      # wenn Hash (also kompletter Hash zurückgegeben, mit value, time etc.)
      $t->{value} = sec2Dauer($t->{value});
      return $t;
    } else {
      # Scalar-Wert annehmen
      return sec2Dauer($t);
    }
  }
  return undef;
}

# ValueFn: Benutzt Time der angegebenen Reading (default: motion) und
#    berechnet die vergangene Zeitspanne. Ausgabe: Zahl in Sekunden
# FnParams: Readingname 
# Params: Dev-Hash, Record-HASH
sub HAL_MotionTimeValueFn($$) {
  my ($device, $record) = @_;
  return HAL_ReadingTimeValueFn($device, $record,'motion');
}

# ValueFn: Benutzt Time der angegebenen Reading 
#    (default kann bei direktem Aufruf mitgegeben werden) und
#    berechnet die vergangene Zeitspanne. Ausgabe: Zahl in Sekunden
# FnParams: Readingname 
# Params: Dev-Hash, Record-HASH
sub HAL_ReadingTimeValueFn($$;$) {
  my ($device, $record, $default) = @_;
  my $rName = $record->{FnParams};
  my $devName = $device->{name};
  $rName = $default unless $rName;
  if(!defined($rName)){
    return undef;
  }
  my $mTime = HAL_getSensorReadingTime($devName, $rName);    
  
  if($mTime) {
    my $dTime = dateTime2dec($mTime);
    my $diffTime = time() - $dTime;
    
    my $ret;
    $ret->{value} = int($diffTime);
    $ret->{time} = TimeNow();
    return $ret;
  }
  
  return undef;
}

# ValueFn: Benutzt Time der angegebenen Reading (default: motion) und 
#   vergleich mit der angegebener Zeitspanne. Wenn diese noch nicht überschritten ist, 
#   wird 1 (true), ansonsten 0 (false) zurückgegeben.
# FnParams: Zeit in Sekunden [, Readingname] 
# Params: Dev-Hash, Record-HASH
sub HAL_MotionValueFn($$) {
  my ($device, $record) = @_;
  my ($pTime,$rName) = @{$record->{FnParams}};
  my $devName = $device->{name};
  $rName = "motion" unless $rName;
  my $mTime = HAL_getSensorReadingTime($devName, $rName);    
  #Log 3,'>------------>Name: '.$devName.', Reading: '.$rName.', time: '.$mTime;

  if($mTime) {
    my $dTime = dateTime2dec($mTime);
    my $diffTime = time() - $dTime;
    
    #return $diffTime < $pTime?1:0;
    my $ret;
    $ret->{value} = $diffTime < $pTime?1:0;
    $ret->{time} = TimeNow();
    return $ret;
  }
  
  return 0;
}

# ValueFn: Berechnet Temperaturdifferenz zw. Innen und Außen 
# (wenn draußen kaelter ist, dann ist der Wert negativ)
sub HAL_TempDiffOutdoorValueFn($$) {
  my ($device, $record) = @_;
  
  my $room = $device->{location};
  
  my $tIn = HAL_getRoomReadingRecord($room, 'temperature');
  my $tOut = HAL_getRoomOutdoorReadingRecord($room,'temperature');
  if($tIn && $tOut) {
    my $tempIn = $tIn->{value};
    my $tempOut = $tOut->{value};
    my $time = $tIn->{time};

    if($tempIn && $tempOut) {
      my $val = $tempOut - $tempIn;
      my $ret;
      $ret->{value} = HAL_round0($val);
      $ret->{time} = $time;#TimeNow();
      #$ret->{reading_name} = $record->{name};
      $ret->{unit} = '°C';
      return $ret;
    }
  }
  
  return undef;
}

  #TODO:
  sub HAL_SunValueFn($$) {
    my ($device, $record) = @_;
    #my $oRecord=$_[1];
    my $senList = $record->{FnParams};
    # keine 'dead' Sensoren verwenden. Wenn verschiedene Ergebnisse => Mehrheit entscheidet. Bei Gleichstand => on, alle 'dead' => on
    # oldVal (letzter ermittelter Wert) speichern. Je nach oldVal obere oder untere Grenze verwenden
    my $oldVal = $record->{oldVal};
    $oldVal='on' unless defined $oldVal;
    my $cnt_on = 0;
    my $cnt_off = 0;
    foreach my $a (@{$senList}) {
      my $senSpec = $a->[0];
      my($sensorName,$readingName) = split(/:/, $senSpec);
      my $senLim1 = $a->[1];
      my $senLim2 = $a->[2];
      #Log 3,'>------------>Name: '.$sensorName.', Reading: '.$readingName.', Lim1/2: '.$senLim1.'/'.$senLim2;
      my $sRec = HAL_getSensorValueRecord($sensorName,$readingName);
      if($sRec->{alive}) {
        my $sVal = $sRec->{value};
        #Log 3,'>------------>sVal: '.$sVal;
        if($oldVal eq 'on') {
          #Log 3,">------------>XXX: $sVal / $senLim1";
          if($sVal < $senLim1) {
            $cnt_off+=1;
            # Log 3,'>------------>1.1 oldVal: '.$oldVal." => new: off";
          } else {
            $cnt_on+=1;
            # Log 3,'>------------>1.2 oldVal: '.$oldVal." => new: on";
          }
        } else {
          # oldVal war off
          if($sVal > $senLim2) {
            $cnt_on+=1;
            # Log 3,'>------------>2.1 oldVal: '.$oldVal." => new: on";
          } else {
            $cnt_off+=1;
            # Log 3,'>------------>2.2 oldVal: '.$oldVal." => new: off";
          }
        }
      }
    }
    my $newVal = 'on';
    if($cnt_off>$cnt_on) {$newVal = 'off';}
    
    $record->{oldVal}=$newVal;  #TODO: Dauerhaft (Neustartsicher) speichern (Reading?)
    $record->{oldTime}=time();
    #Log 3,'>------------> => newVal '.$newVal;
    
    #return $newVal;
    my $ret;
    $ret->{value} = $newVal;
    $ret->{time} = TimeNow();
    return $ret;
  }

# ValueFn: Kombiniert State-Readings zweier (oder auch mhr) Fenstersensoren.
#   Es wird der 'hichste' Stand aller Sensoren ausgegeben.
#   Reihenfolge: open > tilted > closed
# FnParams: Liste der Sensoren mit Readings: sensorName:readingName
# Params: Dev-Hash, Record-HASH  
sub HAL_WinCombiStateValueFn($$) {
    my ($device, $record) = @_;
    
    my $senList = $record->{FnParams};
    my $retVal = 'closed';
    my $retTime = undef;
    foreach my $senSpec (@{$senList}) {
      my($sensorName,$readingName) = split(/:/, $senSpec);
      my $sRec = HAL_getSensorValueRecord($sensorName,$readingName);
      my $state = $sRec->{value};
      my $time = $sRec->{time};
      if($state eq 'open') {
        if($retVal eq 'closed' || $retVal eq 'tilted') {
          $retVal = $state;
          $retTime = $time;
        } else { # gleiche
          $retTime = $time if(!defined($retTime)||$retTime lt $time);
        }
      } elsif ($state eq 'tilted') {
        if($retVal eq 'closed') {
          $retVal = $state;
          $retTime = $time;
        } elsif ($retVal eq 'open') {
          # NOP
        } else { # gleiche
          $retTime = $time if(!defined($retTime)||$retTime lt $time);
        }
      } else { # closed
        if($retVal eq 'closed') {
          $retTime = $time if(!defined($retTime)||$retTime lt $time);
        }
      }
    }     
    
    my $ret;
    $ret->{value} = $retVal;
    $ret->{time} = $retTime;
    return $ret;
}


#--- Methods: Base ------------------------------------------------------------
  
 # >>> Commands
my @usage = ("[room] (roomname) all[:level]*|(readingname) [plain*|full|value|time|brief|dump]",
            "sensor (sensorname) all[:level]*|(readingname) [plain*|full|value|time|brief|dump]",
            "rooms [rexExp|all*]",
            "sensors [(roomname)|all*] [regExp|dead|lowbat[ info]]",
            "dump (roomname|sensorname)",
            "dead",
            "lowbat");
my $mget_mods = {room=>1,sensor=>1,rooms=>1,sensors=>1,dump=>1,dead=>1,lowbat=>1,low=>1};
sub myCtrlDev_Initialize($$)
{
  my ($hash) = @_;
  
  # Templates
  HAL_expandTemplates($templates);
  # Templates anwenden
  HAL_applyTemplates($devices, $templates);
  
  # Console-Commandos registrieren
  my %lhash = ( Fn=>"CommandMGet",
                Hlp=>join(",",@usage).",request sensor values"); 
  $cmds{mget} = \%lhash;
}

# Verarbeitungsroutine für mger Befehl
sub CommandMGet($$$) {
  my($hash, $param, $cmd) = @_;
  my @line = split(/\s+/,$param);
  
  if(scalar(@line)==0) {
    return "Usage: $cmd ".join("\n",@usage);
  }
  
  my $modifier = $line[0];
  my $devname;
  #if($modifier ne 'room' && $modifier ne 'sensor' && $modifier ne 'rooms' && $modifier ne 'sensors') {
  if(!$mget_mods->{$modifier}) {
    # Default is room
    $modifier = 'room';
  } else {
    # modifier entfernen
    shift(@line);
  }
  # Device/Room name
  $devname = shift(@line);
  
  my $rname = shift(@line);
  
  my $showmod = shift(@line);
  $showmod = '' unless defined $showmod;
  
  my $showmod2 = shift(@line);
  #$showmod2 = '' unless defined $showmod2;
  
  my $ret={};
  my @retOrder=();
  
  if($modifier eq 'room') {
    if(!defined($devname)) {
      return 'no room name provided';
    }
    if(!defined($rname)) { 
      # all als Default
      $rname = 'all';
    }
    #if($rname eq 'all') {
    if($rname=~m/all(:\d+)*$/) {
      my(undef,$level)=split(/:/,$rname);
      $level = 3 unless defined $level;
      my @readings = HAL_getRoomSensorReadingsList($devname);
      $showmod2 = 'r' unless defined $showmod2; # reading name anzeigen (a fuer alias)
      foreach $rname (@readings) {
        $ret->{$rname}=CommandMGet_room($devname,$rname,int($level),$showmod,$showmod2);
      }
    } else {
      my @readings = split(/,/,$rname);
      if(@readings && $#readings>0) {
        @retOrder = @readings;
        $showmod2 = 'r' unless defined $showmod2; # reading name anzeigen (a fuer alias)
        foreach $rname (@readings) {
          $ret->{$rname}=CommandMGet_room($devname,$rname,0,$showmod,$showmod2);
        }
      } else {
        return CommandMGet_room($devname,$rname,0,$showmod,$showmod2);
      }
    }
    if(keys($ret)==0) {return 'no rooms found';}
  } elsif($modifier eq 'sensor') {
    if(!defined($devname)) {
      return 'no sensor name provided';
    }
    if(!defined($rname)) { 
      # all als Default
      $rname = 'all';
    }
    #if($rname eq 'all') {
    if($rname=~m/all(:\d+)*$/) {
      my(undef,$level)=split(/:/,$rname);
      $level = 3 unless defined $level;
      my @readings = HAL_getSensorReadingsList($devname);
      $showmod2 = 'r' unless defined $showmod2;
      foreach $rname (@readings) {
        $ret->{$rname}=CommandMGet_sensor($devname,$rname,int($level),$showmod,$showmod2);
      }
    } else {
      my @readings = split(/,/,$rname);
      if(@readings && $#readings>0) {
        @retOrder = @readings;
        $showmod2 = 'r' unless defined $showmod2;
        foreach $rname (@readings) {
          $ret->{$rname}=CommandMGet_sensor($devname,$rname,0,$showmod,$showmod2);
        } 
      } else {
        return CommandMGet_sensor($devname,$rname,0,$showmod,$showmod2);
      }
    }
    if(keys($ret)==0) {return 'no sensors found';}
  } elsif($modifier eq 'rooms') {
    my $rooms = HAL_getRoomNames();
    foreach my $roomname (@$rooms) {
      if(!$devname || $devname eq 'all' || $roomname=~m/^$devname/) {
          $ret->{$roomname}=$roomname;
      }
    }
    if(keys($ret)==0) {return 'no rooms found';}
  } elsif($modifier eq 'sensors') {
    my $sensors;
    if(!defined($devname) || $devname eq 'all') {
      $sensors = HAL_getSensorNames();
    } else {
      $sensors = HAL_getRoomSensorNames($devname);
      if(scalar($sensors) == 0) {return "no room '$devname' or no sensors in room"; }
    }
    foreach my $sensorname (@$sensors) {
        if(defined($rname)) {
          if($rname eq 'dead') {
            if(!HAL_isSensorAlive($sensorname)) {
              # info: dead seit
              my $dauer = HAL_gerSensorDeadTimeDurationStr($sensorname);
              if($dauer) {
                $ret->{$sensorname}=$sensorname.' : '.$dauer;
              } else {
                $ret->{$sensorname}=$sensorname;
              }
            }
          } elsif($rname eq 'lowbat' || $rname eq 'low') {
            if(HAL_isDeviceLowBat($sensorname)) {
              if($showmod eq 'info') {
                my $info = HAL_getDeviceBatStatus($sensorname);
                my $deadSt = HAL_isSensorAlive($sensorname)?'(alive)':'(dead)';
                $ret->{$sensorname}=$sensorname.' : '.$info.' '.$deadSt;
              } else {
                $ret->{$sensorname}=$sensorname;
              }
            }
          } else {
            if($sensorname=~m/^$rname/) {
              $ret->{$sensorname}=$sensorname;
            }
          }
      } else {
        $ret->{$sensorname}=$sensorname;
      }
    }
    if(keys($ret)==0) {return 'no devices found';}
  } elsif($modifier eq 'dump') {
    my $rec;
    my $type;
    if($rec=HAL_getRoomRecord($devname)) {
      $type='ROOM';
    } elsif($rec=HAL_getSensorRecord($devname)) {
      if($rec->{readings} && $rec->{actions}) {$type='ACTOR+SENSOR';}
      elsif($rec->{readings}) {$type='SENSOR';}
      elsif($rec->{actions}) {$type='ACTOR';}
      else {$type='UNKNOWN';}
    #} elsif($rec=HAL_getActorRecord($devname)) {
    #  #TODO: Actor
    #  $type='ACTOR';
    } elsif($rec=$templates->{$devname}) {
      $type='TEMPLATE' unless $type;
    } else {
      return 'unknown device' unless $rec;
    }
    return $type."\n".Dumper($rec);
  } elsif($modifier eq 'dead') {
    my $sensors = HAL_getSensorNames();
    foreach my $sensorname (@$sensors) {
      if(!HAL_isSensorAlive($sensorname)) {
        # info: dead seit
        my $dauer = HAL_gerSensorDeadTimeDurationStr($sensorname);
        if($dauer) {
          $ret->{$sensorname}=$sensorname.' : '.$dauer;
        } else {
          $ret->{$sensorname}=$sensorname;
        }
      }
    }
    if(keys($ret)==0) { return 'no dead devices'; }
  } elsif($modifier eq 'low') {
    my $sensors = HAL_getSensorNames();
    foreach my $sensorname (@$sensors) {
      if(HAL_isDeviceLowBat($sensorname)) {
        my $info = HAL_getDeviceBatStatus($sensorname);
        my $deadSt = HAL_isSensorAlive($sensorname)?'(alive)':'(dead)';
        $ret->{$sensorname}=$sensorname.' : '.$info.' '.$deadSt;
      }
    }
    if(keys($ret)==0) { return 'no low batteries'; }
  } else {
    return 'unknown command';
  }
  
  my $str='';
  if(ref $ret eq 'HASH') {
    @retOrder = sort(keys($ret)) unless @retOrder && $#retOrder>0;
    foreach my $key (@retOrder) {
      #if($showmod ne 'full') {
      #  $str.="$key";
      #}
      #$str.=sprintf("%-12s", $key);
      my $val = $ret->{$key};
      if(defined($val)) {
        #if($showmod ne 'full') {
        #  $str.=' : ';
        #}
        $str.=$val;
        $str.="\n";
      }
    }
  } else {
    return "internal error";
  }
  return $str;
}

sub CommandMGet_room($$$$$) {
  my($name, $readingname, $level, $mod, $mod2) = @_;

Log3 "TEST", 3, '>>>>>>>>>> '.$level ;

  my $record = HAL_getRoomReadingRecord($name, $readingname);
  if(!defined($record)) {
    return "unknown room or reading: $name:$readingname";
  }
  # ggf. nach Level filtern
  if($level) { # 0 oder nichts (letzteres sollte nicht sein)
    my $rlevel = $record->{level};
    if(defined($rlevel)) {
      if(int($rlevel)>$level) {
        return undef;
      }
    }
  }
  return CommandMGet_format($record,$mod,$mod2);
  
  #return HAL_getRoomReadingValue($name, $readingname,'unknown reading '.$readingname,'unknown room '.$name);
}

sub CommandMGet_sensor($$$$$) {
  my($name, $readingname, $level, $mod, $mod2) = @_;

  my $record = HAL_getSensorValueRecord($name, $readingname);
  if(!defined($record)) {
    return "unknown sensor or reading: $name:$readingname";
  }
  # ggf. nach Level filtern
  if($level) { # 0 oder nichts (letzteres sollte nicht sein)
    my $rlevel = $record->{level};
    if(defined($rlevel)) {
      if(int($rlevel)>$level) {
        return undef;
      }
    }
  }
  return CommandMGet_format($record,$mod,$mod2);
  
  #return HAL_getSensorReadingValue($name, $readingname);
}

#[plain*|full|value|time|dump]
sub CommandMGet_format($$$) {
  my($record, $mod, $mod2) = @_;
  
  my $prefix = '';
  $mod2 = '' unless defined $mod2;
  $prefix .= sprintf("%-19s : ", $record->{alias}) if($mod2 eq 'alias' || $mod2 eq 'a');
  $prefix .= sprintf("%-19s : ", $record->{reading}) if($mod2 eq 'reading' || $mod2 eq 'r');
  
  if(!$mod || $mod eq 'plain' || $mod eq 'p') {
    return $prefix.$record->{value};
  }
  
  if($mod eq 'time' || $mod eq 't') {
    return $prefix.$record->{time};
  }
  
  if($mod eq 'value' || $mod eq 'v') {
    return $prefix.$record->{value}.' '.$record->{unit};
  }
  
  if($mod eq 'brief' || $mod eq 'b') {
    return $prefix.$record->{value}.' '.$record->{unit};
  }
  
  if($mod eq 'full' || $mod eq 'f') {
    #return '['.$record->{time}.'] '.$record->{sensor}.':'.$record->{name}.' = '.$record->{value}.' '.$record->{unit};
    #return $prefix.sprintf("%-8s [%s] %s:%s",$record->{value}.' '.$record->{unit},$record->{time},$record->{sensor},$record->{reading});
    return $prefix.sprintf("%-11s [%s] %s",$record->{value}.' '.(defined($record->{unit})?$record->{unit}:''),$record->{time},$record->{origin});
  }
  
  if($mod eq 'dump' || $mod eq 'd') {
    return Dumper($record);
  }
}


 #>>> Templates
 
# Füght einem Hash Zweige/werte aus dem anderen zu, aber nur, wenn Werte (Blaetter) noch nicht vorhanden waren.
# Params: Zu aendernder Hash, Template-Hash
sub merge_hash_recursive($$) {
  my($hash, $template) = @_;
  #Log3 "TEST", 3, 'ENTER';
  if(!defined($hash) || !defined($template)) { return };
  
  foreach my $key (keys($template)) {
    my $t = $template->{$key};
    #Log3 "TEST", 3, 'Key: '.$key;
    if(defined($t)) {
      if(defined($hash->{$key}) && (ref $hash->{$key} ne ref $t)) {
        #Log3 "TEST", 3, 'Verschiedenen Typen -> ignore';
        # Verschiedenen Typen -> ignore
      } elsif(ref $t eq "HASH") {
        #Log3 "TEST", 3, 'HASH';
        if(!defined($hash->{$key})) {
          #Log3 "TEST", 3, 'create empty hash';
          $hash->{$key}={};
        }
        merge_hash_recursive($hash->{$key},$template->{$key});
      } elsif(ref $t eq "ARRAY") {
        #Log3 "TEST", 3, 'ARRAY';
        if(!defined($hash->{$key})) {
          #Log3 "TEST", 3, 'copy array';
          my @a = @$t;
          $hash->{$key}=\@a;
        } else {
          # Nicht leere Arrays ignorieren
          #Log3 "TEST", 3, 'ignore';
        }
      } else {
        #Log3 "TEST", 3, 'SCALAR';
        # Scalar
        if(!defined($hash->{$key})) {
          #Log3 "TEST", 3, 'copy value';
          $hash->{$key}=$t;
        } else {
          # sonst ignorieren
          #Log3 "TEST", 3, 'ignore';
        }
      }
    }
  }
}

# Template-Tab rekursiv erweitern (Templates mit Templates)
# Param: Template-Tab-Hash
sub HAL_expandTemplates($) {
  my($templates) = @_;
  foreach my $key (keys($templates)) {
    my $subTab = $templates->{$key};
    HAL_expandTemplates_intern($templates, $subTab);
  }
}
# Interne Routine fuer expandTemplates (ein Zweig verarbeiten (rekursiv))
sub HAL_expandTemplates_intern($$) {
  my($templates, $tab) = @_;
  #Log3 "TEST", 3, 'expand_intern'.Dumper($templates);
  #Log3 "TEST", 3, 'expand_intern: --->';
  return unless defined $tab;
  my $desiredTemplates = $tab->{templates};
  if(defined($desiredTemplates) && ref($desiredTemplates) eq 'ARRAY') {
    foreach my $tName (@$desiredTemplates) {
      #Log3 "TEST", 3, 'expand_intern: apply '.$tName;
      my $node = $templates->{$tName};
      HAL_expandTemplates_intern($templates, $node);
      #Log3 "TEST", 3, 'expand_intern'.Dumper($templates)."\n\n".Dumper($node);
      merge_hash_recursive($tab, $node);
    }
    delete($tab->{templates});
  }
}

# Geht die Liste der Devices durch und wendet angegebenen Tempates an (Zweige ergaenzen/einfuegen)
# Params: Dev-Hash, Templates-Hash
sub HAL_applyTemplates($$) {
  my($tab,$templates) = @_;
  
  foreach my $key (keys($tab)) {
    #Log3 "myCtrlDev", 3, ">>>ExpandTemplates: $key";
    my $subTab = $tab->{$key};
    my $desiredTemplates = $subTab->{templates};
    if(defined($desiredTemplates)) {
      foreach my $tName (@$desiredTemplates) {
        my $tNode = $templates->{$tName};
        merge_hash_recursive($subTab, $tNode);
      }
    }
  }
}

 #>>> Data

# Liefert Record zu der Reading für die angeforderte Messwerte
# Param Room-Name, Reading-Name
# return ReadingsRecord
sub HAL_getRoomReadingRecord($$) {
  my ($roomName, $readingName) = @_;
  return HAL_getRoomReadingRecord_($roomName, $readingName, "");
}

# Liefert Record zu der Reading für die angeforderte Messwerte
# Param Room-Name, Reading-Name
# return ReadingsRecord
sub HAL_getRoomOutdoorReadingRecord($$) {
  my ($roomName, $readingName) = @_;
  return HAL_getRoomReadingRecord_($roomName, $readingName, "_outdoor");
}

# Liefert Record zu der Reading für die angeforderte Messwerte und Sensorliste (Internal)
# Param Room-Name, Reading-Name, Name der Liste (sensors, sensors_outdoor)
# return ReadingsRecord
sub HAL_getRoomReadingRecord_($$$) {
  my ($roomName, $readingName, $listNameSuffix) = @_;
  my $listName.="sensors".$listNameSuffix;
    
  my $sensorList = HAL_getRoomDeviceNames_($roomName, $listName); #HAL_getRoomSensorNames($roomName);
  return undef unless $sensorList;
  
  # Wenn Reading mit Sensorname ubergeben wurde
  my($tsname,$trname) = split(/:/,$readingName);
  #Log 3,"+++++++++++++++++> ::::: ".$tsname." > :: ".$trname;
  if($trname) {
    # Pruefen, ob dieser Sensor in der aktuellen Raum-Liste bekannt ist
    my $found=0;
    foreach my $tsn (@{$sensorList}) {
      #Log 3,"+++++++++++++++++> 1: ".$tsn." > 2: ".$tsname;
      my($tsnSN,$tsnRest) = split(/:/,$tsn);
      if($tsnSN eq $tsname) {
        if($tsnRest) {
          #Log 3,"+++++++++++++++++> XXX ".$tsnSN." > :: ".$tsnRest;
          # ggf. auch (kommaseparierte) Liste der ReadingsNamen pruefen
          my @aRN = split(/,\s*/,$tsnRest);
          foreach my $tRN (@aRN) {
            if($tRN eq $trname) {
              $found=1;
              last;
            }
          }
          if($found) {last;}
        } else {
          $found=1;
          last;
        }
      }
    }
    if(!$found) { return undef };
    #Log 3,"+++++++++++++++++> >>> ".$tsname." > :: ".$trname;
    my $rec = HAL_getSensorValueRecord($tsname, $trname);
    if(defined $rec) {
      my $roomRec=HAL_getRoomRecord($roomName);
      $rec->{room_alias}=$roomRec->{alias};
      $rec->{room_fhem_name}=$roomRec->{fhem_name};
      # XXX: ggf. weitere Room Eigenschaften
      return $rec;
    }
  }
  
  foreach my $sName (@$sensorList) {
    if(!defined($sName)) {next;} 
    #Log 3,"+++++++++++++++++> >>> ".$sName." > :: ".$readingName;
    # Pruefen, ob in den sName auch Reading(s) angegeben sind (in Raumdefinition)
    my($tsname,$trname) = split(/:/,$sName);
    if($trname) {
      #Pruefung, ob in trname readingName enthalten ist
      my @aRN = split(/,\s*/,$trname);
      my $found=0;
      foreach my $tRN (@aRN) {
        if($tRN eq $readingName) {
          $found=1;
          last;
        }
      }
      if(!$found) { next; }
      
      my $rec = HAL_getSensorValueRecord($tsname, $readingName);
      if(defined $rec) {
        my $roomRec=HAL_getRoomRecord($roomName);
        $rec->{room_alias}=$roomRec->{alias};
        $rec->{room_fhem_name}=$roomRec->{fhem_name};
        # XXX: ggf. weitere Room Eigenschaften
        return $rec;
      }
    } else {
      my $rec = HAL_getSensorValueRecord($sName, $readingName);
      if(defined $rec) {
        my $roomRec=HAL_getRoomRecord($roomName);
        $rec->{room_alias}=$roomRec->{alias};
        $rec->{room_fhem_name}=$roomRec->{fhem_name};
        # XXX: ggf. weitere Room Eigenschaften
        return $rec;
      }
    }
  }
  
  return undef;
}


# Liefert angeforderte Messwerte
# Param Room-Name, Reading-Name, Default1, Default2
# return ReadingsWert
# Wenn kein Wert gefunden werden kann, wird Default1 zurückgageben (wenn angegeben, ansonsten undef)
# Wenn Default2 angegeben, dann wird dieser zurückgegeben, falls Raum nicht bekannt ist, ansonsten Default1 (wenn nicht angegeben - undef)
sub HAL_getRoomReadingValue($$;$$) {
  my ($roomName, $readingName, $def1, $def2) = @_;
  
  $def2 = $def1 unless defined($def2); 
  
  my $sensorList = HAL_getRoomSensorNames($roomName);
  return $def2 unless $sensorList;
  
  foreach my $sName (@$sensorList) {
    if(!defined($sName)) {next;} 
    my $val = HAL_getSensorReadingValue($sName, $readingName);
    if(defined $val) {return $val;}
  }
  
  return $def1;
}

#------------------------------------------------------------------------------
# returns Device-Record by name
# Parameter: name 
# record:
#  X->{name}->{alias}     ="Text zur Anzeige etc.";
#  X->{name}->{fhem_name} ="Name in FHEM";
#  X->{name}->{type}      ="Typ für Gruppierung und Suche";
#  X->{name}->{location}  ="Zugehörigkeit zu einem Raum ($rooms)";
#  X->{name}->{readings}->{<readings_name>} ->{reading}  ="temperature";
#  X->{name}->{readings}->{<readings_name>} ->{unit}     ="°C";
#  ...
sub HAL_getDeviceRecord($) {
  my ($name) = @_;
  return undef unless $name;
  my $ret = HAL_getDeviceTab()->{$name};
  if($ret) {
    $ret->{name} = $name; # Name hinzufuegen
  }
  # AliasTab-Suche
  if(!defined($ret)) {
    my $alias = HAL_getDeviceAliasTab()->{$name};
    if(defined($alias)) {
      $ret =  HAL_getDeviceTab()->{$alias};
      if($ret) {
        $ret->{name} = $alias; # Echten Namen hinzufuegen
        $ret->{name_alias} = $name; # Alias hinzufuegen
      }
    }
  }
  
  
  return $ret;
}

# s. HAL_getDeviceRecord
sub HAL_getActorRecord($) {
  my ($name) = @_;
  return HAL_getDeviceRecord($name);
}

# s. HAL_getDeviceRecord
sub HAL_getSensorRecord($) {
  my ($name) = @_;
  return HAL_getDeviceRecord($name);
}

# Liefert HASH mit Sensor-Definitionen
sub HAL_getDeviceTab() {
  return $devices;
}

# Liefert HASH mit Aliases
sub HAL_getAliasTab() {
  return $aliases;
}

# Liefert HASH mit Aliases fuer Rooms
sub HAL_getRoomAliasTab() {
  return HAL_getAliasTab()->{rooms};
}

# Liefert HASH mit Aliases fuer Devices
sub HAL_getDeviceAliasTab() {
  return HAL_getAliasTab()->{devices};
}

# Liefert Liste der Sensornamen.
sub HAL_getSensorNames() {
  HAL_initDeviceNames_() unless defined($sensornames);
  return $sensornames;
}

# Liefert Liste der Actornamen.
sub HAL_getActorNames() {
  HAL_initDeviceNames_() unless defined($actornames);
  return $actornames;
}

# Initialisiert Listen der Sensor/Actor-Names
sub HAL_initDeviceNames_() {
  my $r = HAL_getDeviceTab();
  foreach my $name (keys %{$r}) {
    if(defined($r->{$name}->{readings})) {
      push(@$sensornames,$name);
    }
    if(defined($r->{$name}->{actions})) {
      push(@$actornames,$name);
    }
  }
}

# returns Room-Record by name
# Parameter: name 
# record:
#  X->{name}->{alias}      ="Text zur Anzeige etc.";
#  X->{name}->{fhem_name} ="Text zur Anzeige etc.";
# Definiert nutzbare Sensoren. Reihenfolge gibt Priorität an. <= ODER BRAUCHT MAN NUR DIE EINZEL-READING-DEFINITIONEN?
#  X->{name}->{sensors}   =(<Liste der Namen>);
#  X->{name}->{sensors_outdor} =(<Liste der SensorenNamen 'vor dem Fenster'>);
sub HAL_getRoomRecord($) {
  my ($name) = @_;
  my $ret = HAL_getRooms()->{$name};
  if($ret) {
    $ret->{name} = $name; # Name hinzufuegen
  }
  # AliasTab-Suche
  if(!defined($ret)) {
    my $alias = HAL_getRoomAliasTab()->{$name};
    if(defined($alias)) {
      $ret =  HAL_getRooms()->{$alias};
      if($ret) {
        $ret->{name} = $alias; # Echten Namen hinzufuegen
        $ret->{name_alias} = $name; # Alias hinzufuegen
      }
    }
  }
  
  return $ret;
}

# Liefert HASH mit Raum-Definitionen
sub HAL_getRooms() {
  return $rooms;
}

# Liefert Liste der Raumnamen.
sub HAL_getRoomNames() {
  my $r = HAL_getRooms();
  my @ret = keys($r);
  
  return \@ret;
}

# liefert Liste (Referenz) der Actoren in einem Raum (Liste der Namen)
# Param: Raumname
#  Beispiel:   {HAL_getRoomActorNames("wohnzimmer")->[0]}
sub HAL_getRoomActorNames($)
{
  my ($roomName) = @_;
  return HAL_getRoomDeviceNames_($roomName,"actors"); 
}

# liefert Liste (Referenz) der Sensors in einem Raum (Liste der Namen)
# Param: Raumname
#  Beispiel:   {HAL_getRoomSensorNames("wohnzimmer")->[0]}
sub HAL_getRoomSensorNames($)
{
  my ($roomName) = @_;
  return HAL_getRoomDeviceNames_($roomName,"sensors");  
}

# liefert Liste (Referenz) der Sensors für einen Raum draussen (Liste der Namen)
# Param: Raumname
#  Beispiel:  {HAL_getRoomSensorNames("wohnzimmer")->[0]}
sub HAL_getRoomOutdoorSensorNames($)
{
  my ($roomName) = @_;
  return HAL_getRoomDeviceNames_($roomName,"sensors_outdoor");  
}

# liefert Referenz der Liste der Geraete in einem Raum (List der Namen)
# Param: Raumname, SensorListName (z.B. sensors, sensors_outdoor)
sub HAL_getRoomDeviceNames_($$)
{
  my ($roomName, $listName) = @_;
  my $roomRec=HAL_getRoomRecord($roomName);
  return undef unless $roomRec;
  my $sensorList=$roomRec->{$listName};
  return undef unless $sensorList;
  
  return $sensorList;
}

# liefert liste aller veruegbaren Readings in einem Raum
# Param: Raumname, 
#        Flag, gibt an, ob die Sensor-Namen mit ausgegeben werden sollen (als sensorname:readingname).
#              Falls nicht, werden doppelte Eintraege aus der Liste entfernt.
sub HAL_getRoomSensorReadingsList($;$) {
  my ($roomName,$withSensorNames) = @_;
  return HAL_getRoomSensorReadingsList_($roomName,'sensors',$withSensorNames);
}

# liefert liste aller veruegbaren Readings in einem Raum für Außenbereich
# Param: Raumname, 
#        Flag, gibt an, ob die Sensor-Namen mit ausgegeben werden sollen (als sensorname:readingname).
#              Falls nicht, werden doppelte Eintraege aus der Liste entfernt.
sub HAL_getRoomOutdoorSensorReadingsList($;$) {
  my ($roomName,$withSensorNames) = @_;
  return HAL_getRoomSensorReadingsList_($roomName,'sensors_outdoor',$withSensorNames);
}

# liefert liste aller veruegbaren Readings in einem Raum
# Param: Raumname, 
#        Liste (sensors, sensors_outdoor)
#        Flag, gibt an, ob die Sensor-Namen mit ausgegeben werden sollen (als sensorname:readingname).
#              Falls nicht, werden doppelte Eintraege aus der Liste entfernt.
sub HAL_getRoomSensorReadingsList_($$;$) {
  my ($roomName,$listName,$withSensorNames) = @_;
  
  my $snames = HAL_getRoomDeviceNames_($roomName,$listName);
  my @rnames = ();
  #Log 3,"+++++++++++++++++> SNames: ".Dumper($snames);
  foreach my $sname (@{$snames}) {
    #Log 3,"+++++++++++++++++> Name:".$sname." | ".Dumper($sname);
    my @tnames = HAL_getSensorReadingsList($sname);
    if($withSensorNames) {
      @tnames = map {$sname.':'.$_} @tnames;
    }
    @rnames = (@rnames, @tnames);
  }
  
  if(!$withSensorNames) {
    #distinct
    @rnames = keys { map { $_ => 1 } @rnames };
  }
  
  return @rnames;
}


#### TODO: Sind die Methoden, die Hashesliste zurückgeben überhaupt notwendig?
## liefert Liste der Sensors in einem Raum (Array of Hashes)
## Param: Raumname
##  Beispiel:  {(HAL_getRoomSensors("wohnzimmer"))[0]->{alias}}
#sub HAL_getRoomSensors($)
#{
# my ($roomName) = @_;
#  return HAL_getRoomSensors_($roomName,"sensors"); 
#}
#
## liefert Liste der Sensors für einen Raum draussen (Array of Hashes)
## Param: Raumname
##  Beispiel:  {(HAL_getRoomOutdoorSensors("wohnzimmer"))[0]->{alias}}
#sub HAL_getRoomOutdoorSensors($)
#{
# my ($roomName) = @_;
#  return HAL_getRoomSensors_($roomName,"sensors_outdoor"); 
#}
#
## liefert Liste der Sensors in einem Raum (Array of Hashes)
## Param: Raumname, SensorListName (z.B. sensors, sensors_outdoor)
#sub HAL_getRoomSensors_($$)
#{
# my ($roomName, $listName) = @_;
# my $roomRec=HAL_getRoomRecord($roomName);
# return undef unless $roomRec;
# my $sensorList=$roomRec->{$listName};
# return undef unless $sensorList;
# 
# my @ret;
# foreach my $sName (@{$sensorList}) {
#   my $sRec = HAL_getSensorRecord($sName);
#   push(@ret, \%{$sRec}) if $sRec ;
# }
# 
# return @ret;
#}
## <---------------

# parameters: name
# liefert Array : Liste aller Readings eines Sensor-Device (auch composite)
sub HAL_getSensorReadingsList($) {
  my ($name) = @_;
  
  my $record = HAL_getSensorRecord($name);
  
  if(defined($record)) {
    # Eigene Readings
    my @areadings = keys($record->{readings});
    
    # Composite-Devices
    my $composites = $record->{composite};

    foreach my $composite_rec (@{$composites}) {
      my($composite_name,$composite_readings_names)= split(/:/,$composite_rec);
      if($composite_name) {
        my @composite_readings = HAL_getSensorReadingsList($composite_name);
        if(defined($composite_readings_names)) {
          my @a_composite_readings_names = split(/,\s*/,$composite_readings_names);
          @composite_readings = arraysIntesec(\@composite_readings,\@a_composite_readings_names);
        }
        
        @areadings = (@areadings,@composite_readings);
      }
    }
    
    return @areadings;
  }
  return undef;
}

# sucht gewünschtes reading zu dem angegebenen device, folgt den in {composite} definierten (Unter)-Devices.
# liefert Device und Reading Recors als Array 
sub HAL_getSensorReadingCompositeRecord_intern($$)
{
  my ($device_record,$reading) = @_;
  return (undef, undef) unless $device_record;
  return (undef, undef) unless $reading;
  
  my $readings_record = $device_record->{readings};
  my $single_reading_record = $readings_record->{$reading};
  
  #Log 3,"+++++++++++++++++> R:".$reading." SR: ".Dumper($single_reading_record);
  
  if(defined($single_reading_record) && (ref($single_reading_record) ne 'HASH')) {
    #Log 3,"+++++++++++++++++> R:".$reading." SR: ".Dumper($single_reading_record);
    return (undef, undef);
  }
  
  if ($single_reading_record) {
    #$single_reading_record->{reading_name} = $reading; Nicht noetig
    $single_reading_record->{name}=$reading; #XXX? So nicht! doch?
    return ($device_record, $single_reading_record);
  }
  
  # composites verarbeiten
  # e.g.  $devices->{wz_wandthermostat}->{composite} =("wz_wandthermostat_climate"); 
  my $composites = $device_record->{composite};

  foreach my $composite_rec (@{$composites}) {
    my($composite_name,$composite_readings)= split(/:/,$composite_rec);
    if(defined($composite_readings)) {
      my @a_composite_readings = split(/,\s*/,$composite_readings);
      #Log 3,"+++++++++++++++++> R:".$reading." A: ".Dumper(@a_composite_readings);
      my $found=0;
      for my $aval (@a_composite_readings) { if($aval eq $reading) {$found=1;last;} }
      if ( !$found ) {
        next;
      }
    }
    my $new_device_record = HAL_getSensorRecord($composite_name);
    my ($new_device_record2, $new_single_reading_record) = HAL_getSensorReadingCompositeRecord_intern($new_device_record,$reading);
    if(defined($new_single_reading_record )) {
      #$new_single_reading_record->{reading_name} = $reading; #Nicht noetig
      $new_single_reading_record->{name}=$reading; #XXX? So nicht! doch?
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
sub HAL_getSensorReadingRecord($$)
{
  my ($name, $reading) = @_;
  my $record = HAL_getSensorRecord($name);
  
  if(defined($record)) {
    return HAL_getSensorReadingCompositeRecord_intern($record,$reading);
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
sub HAL_getSensorValueRecord($$)
{
  my ($name, $reading) = @_;
  # Sensor/Reading-Record suchen
  my ($device, $record) = HAL_getSensorReadingRecord($name,$reading);
  
  return HAL_getReadingsValueRecord($device, $record);
}

# Liefert ValueRecord (ermittelter Wert und andere SensorReadingDaten)
# Param: Device-Hash, Reading-Hash
# Return: Value-Hash
sub HAL_getReadingsValueRecord($$) {
  my ($device, $record) = @_;
  
  #Log 3,"+++++++++++++++++> ".Dumper($device);
  #Log 3,"+++++++++++++++++> ".Dumper($record);
  
  if (defined($record)) {
    my $val=undef;
    my $time=undef;
    my $ret;
  
    my $link = $record->{link};
    if($link) {
      my($sensorName,$readingName) = split(/:/, $link);
      
      $sensorName = $device->{name} unless $sensorName; # wenn nichts angegeben (vor dem :) dann den Sensor selbst verwenden (Kopie eigenes Readings)
      return undef unless $readingName;
      $ret = HAL_getSensorValueRecord($sensorName,$readingName);
      # ggf. neue Sensor und Reading Namen (er)setzen
      $ret->{sensor}  =$device->{name};
      $ret->{reading} =$record->{name}; #XXX?
      return $ret;
    }

    my $valueFn =  $record->{ValueFn};
    if($valueFn) {
      if($valueFn=~m/\{.*\}/) {
        # Klammern: direkt evaluieren
        no warnings;
        $val= eval $valueFn;
        use warnings; 
        $time=TimeNow(); # Aktuelle Zeit
      } else {
        no strict "refs";
        my $r = &{$valueFn}($device,$record);
        use strict "refs";
        if(ref $r eq ref {}) {
          # wenn Hash (also kompletter Hash zurückgegeben, mit value, time etc.)
          $ret = $r;
          #Log 3,"+++++++++++++++++> D: ".Dumper($ret);
          $time=$ret->{time};
          $time=TimeNow() unless defined $ret->{time}; # Aktuelle Zeit, es sei denn, time wurde definiert
          $ret->{level} = $record->{level} unless defined($ret->{level});
          #Log 3,"+++++++++++++++++> D: ".Dumper($record);
        } else {
          # Scalar-Wert annehmen
          $val=$r;
          $time=TimeNow(); # Aktuelle Zeit
        }
      }
      #TODO
      #$val="not implemented";
      #Log 3,"+++++++++++++++++> D: ".Dumper($time);
    }
    else
    {
      my $fhem_name = $device->{fhem_name};
      my $reading_fhem_name = $record->{reading};
      #Log 3,"+++++++++++++++++> ".Dumper($record);
      $val = ReadingsVal($fhem_name,$reading_fhem_name,undef);
      $time = ReadingsTimestamp($fhem_name,$reading_fhem_name,undef);
      #Log 3,"+++++++++++++++++> Name: ".$fhem_name." Reading: ".$reading_fhem_name." =>VAL:".$val;
    }
    
    $ret->{value}     =$val if(defined $val);
    $val = $ret->{value};
    #Log 3,"+++++++++++++++++> D: ".Dumper($ret);
    # ValueFilterFn
    my $valueFilterFn =  $record->{ValueFilterFn};
    if($valueFilterFn) {
      #Log 3,"+++++++++++++++++> D: ".$val;
      if($valueFilterFn=~m/\{.*\}/) {
        # Klammern: direkt evaluieren
        my $VAL = $val;
        #Log 3,"+++++++++++++++++> V: ".Dumper($valueFilterFn);
        no warnings;
        $val= eval $valueFilterFn;
        use warnings;
      } else {
        no strict "refs";
        my $r = &{$valueFilterFn}($val,$device,$record);
        use strict "refs";
        if(defined($r)) {
          $val=$r;
        }
      #Log 3,"+++++++++++++++++> R: ".$val;
      }
      
      $ret->{value}     =$val if(defined $val);
    }
    
    # dead or alive?
    $ret->{status} = 'unknown';
    my $actCycle = $record->{act_cycle};
    $actCycle = $device->{act_cycle} unless defined $actCycle;
    $actCycle = 0 unless defined $actCycle;
    my $iactCycle = 0;
    $iactCycle = int($actCycle) if defined $actCycle;
    if(defined $actCycle && $iactCycle == 0) {
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
    
    $ret->{unit}      =$record->{unit} if defined($record->{unit});
    $ret->{alias}     =$record->{alias} if defined($record->{alias});
    $ret->{level}     =defined($record->{level})?$record->{level}:'0' unless defined($ret->{level});#$record->{level} if defined($record->{level});
    $ret->{fhem_name} =$device->{fhem_name} if defined($device->{fhem_name});
    $ret->{sensor}    =$device->{name};
    $ret->{reading}   =$record->{name}; #XXX?
    $ret->{origin}    =$device->{name}.':'.$record->{name}; # Ursprung
    #$ret->{sensor_alias} =$
    $ret->{device_alias} =$device->{alias};
    return $ret;
  }
  return undef;
}

# Sucht den Gewuenschten SensorDevice und liest den gesuchten Reading aus
# parameters: name, reading name
# returns current readings value
sub HAL_getSensorReadingValue($$)
{
  my ($name, $reading) = @_;
  my $h = HAL_getSensorValueRecord($name, $reading);
  return undef unless $h;
  return $h->{value};
}

# Sucht den Gewuenschten SensorDevice und liest zu dem gesuchten Reading das Unit-String aus
# parameters: name, reading name
# returns readings unit
sub HAL_getSensorReadingUnit($$)
{
  my ($name, $reading) = @_;
  my $h = HAL_getSensorValueRecord($name, $reading);
  return undef unless $h;
  return $h->{unit};
  
  # Sensor/Reading-Record suchen
  my ($device, $record) = HAL_getSensorReadingRecord($name,$reading);
  if (defined($record)) {
    return $record->{unit};
  }
  return undef;
}

# Sucht den Gewuenschten SensorDevice und liest zu dem gesuchten Reading die Zeitangabe aus
# parameters: name, reading name
# returns current readings time
sub HAL_getSensorReadingTime($$) {
  my ($name, $reading) = @_;
  my $h = HAL_getSensorValueRecord($name, $reading);
  return undef unless $h;
  return $h->{time};
}

# Sucht den Gewuenschten SensorDevice und liest zu dem gesuchten Reading die Zeitangabe aus.
# Zurückgegeben wird die Dauer seit dem Zeitpunkt der Reading als lesbarer Text
# parameters: name, reading name
# returns current readings time duration
sub HAL_getSensorReadingTimeDurationStr($$) {
  my ($name, $reading) = @_;
  
  my $mTime = HAL_getSensorReadingTimeDuration($name, $reading);
  if($mTime) {
    my $dauerTxt = sec2Dauer($mTime);
    return $dauerTxt;
  }
  
  return undef;
}

# Sucht den Gewuenschten SensorDevice und liest zu dem gesuchten Reading die Zeitangabe aus.
# Zurückgegeben wird die Dauer seit dem Zeitpunkt der Reading (in Sekunden).
# parameters: name, reading name
# returns current readings time duration
sub HAL_getSensorReadingTimeDuration($$) {
  my ($name, $reading) = @_;
  
  my $mTime = HAL_getSensorReadingTime($name, $reading);
  if($mTime) {
    my $dTime = dateTime2dec($mTime);
    my $diffTime = time() - $dTime;
    return $diffTime;
  }
  
  return undef;
}


# Liefert Record fuer eine Reading eines Sensors
# Param: Spec in Form SensorName:ReadingName
sub HAL_getReadingRecord($) {
  my($readingSpec) = @_;
  my($sNamem,$rName) = split(/:/,$readingSpec);
  return HAL_getSensorValueRecord($sNamem,$rName);
}

# Liefert Value einer Reading eines Sensors
# Param: Spec in Form SensorName:ReadingName
sub HAL_getReadingValue($) {
  my($readingSpec) = @_;
  my($sNamem,$rName) = split(/:/,$readingSpec);
  return HAL_getSensorReadingValue($sNamem,$rName);
}

# Liefert Unit einer Reading eines Sensors
# Param: Spec in Form SensorName:ReadingName
sub HAL_getReadingUnit($) {
  my($readingSpec) = @_;
  my($sNamem,$rName) = split(/:/,$readingSpec);
  return HAL_getSensorReadingUnit($sNamem,$rName);
}

# Liefert Time einer Reading eines Sensors
# Param: Spec in Form SensorName:ReadingName
sub HAL_getReadingTime($) {
  my($readingSpec) = @_;
  my($sNamem,$rName) = split(/:/,$readingSpec);
  return HAL_getSensorReadingTime($sNamem,$rName);
}

# Prueft, ob Device vorhanden ist
#  Param: Sensorname
sub HAL_isDeviceExist($) {
  my($name) = @_;
  my $record = HAL_getDeviceRecord($name);
  return (defined($record))?1:0;
}

# Prueft, ob der Sensor alive ist (s. actCycle)
#  Param: Sensorname
sub HAL_isSensorAlive($) {
  my($name) = @_;
  my @list = HAL_getSensorReadingsList($name);
  foreach my $reading (@list) {
    if(!HAL_isReadingAlive($name, $reading)) {
      return 0;
    }
  }
  return 1;
}

# Prueft, ob der Sensor alive ist (s. actCycle)
# Wenn nicht, liefert Dauer seit der letzten Meldung (in Sekunden)
#  Param: Sensorname
sub HAL_gerSensorDeadTimeDuration($) {
  my($name) = @_;
  my @list = HAL_getSensorReadingsList($name);
  foreach my $reading (@list) {
    if(!HAL_isReadingAlive($name, $reading)) {
      return HAL_getSensorReadingTimeDuration($name, $reading);
    }
  }
  return undef;
}

# Prueft, ob der Sensor alive ist (s. actCycle)
# Wenn nicht, liefert Dauer seit der letzten Meldung (in Sekunden)
#  Param: Sensorname
sub HAL_gerSensorDeadTimeDurationStr($) {
  my($name) = @_;
  my @list = HAL_getSensorReadingsList($name);
  foreach my $reading (@list) {
    if(!HAL_isReadingAlive($name, $reading)) {
      return HAL_getSensorReadingTimeDurationStr($name, $reading);
    }
  }
  return undef;
}

# Prueft, ob ein (Batterie-betriebener) Device schwache Batterie hat
#  Param: Sensorname
#  Return: (Status, Zusatzinfo)
sub HAL_isDeviceLowBat($) {
  my($name) = @_;
  my ($stat,undef) = HAL_getDeviceBatStatus($name);
  return ($stat eq 'low')?1:0;
}

# Liefert Batteriestatus eines (Batterie-betriebenen) Devices.
#  Param: Sensorname
#  Return: Array 
#        0: ok, low, non bat, unknown
#        1: Info-String
sub HAL_getDeviceBatStatus($) {
  my($name) = @_;
  
  # Pruefen, ob Device existiert
  if(!HAL_isDeviceExist($name)) {
    return 'device not found'; 
  }
  
  my $bStat = HAL_getSensorReadingValue($name,'bat_status');
  my $bLimit = HAL_getSensorReadingValue($name,'low_bat_limit');
  my $bVolt = HAL_getSensorReadingValue($name,'bat_voltage');
  my $zInfo = '';
  if(defined($bVolt)) {$zInfo = $bVolt.' V';}
  if(defined($bLimit)) {$zInfo .= ' / '.$bLimit.' V';}
  
  if($bStat) {
    if($bStat eq 'ok') {
      return ('ok',$zInfo); 
    }
    if($bStat eq 'low') {
      return ('low',$zInfo); 
    }
    
    return 'unknown status: '.$bStat;
  }
  
  if(defined($bLimit) && defined($bVolt)) {
    # wenn beides bekannt, kann man ausrechnen
    if((0+$bVolt)<=(0+$bLimit)) {
      return ('low',$zInfo); 
    } else {
      return ('ok',$zInfo); 
    }
  } elsif(defined($bVolt)) {
    # wenn Voltage bekannt aber kein Limit
    return ('unknown',$zInfo);
  }
  
  # vermutlich kein Batterie-Device
  return ('non bat',undef);
}

# Prueft, ob Reading eines Sensors alive ist (s. actCycle)
#  Param: Sensorname, Readingname
sub HAL_isReadingAlive($$) {
  my($sensor,$reading) = @_;

  my $record = HAL_getSensorValueRecord($sensor,$reading);
  if($record) {
    return $record->{alive};
  }
  return 0;
}

#------------------------------------------------------------------------------

#- Steuerung fuer manuelle Aufrufe (AT) ---------------------------------------

###############################################################################
# Alle Aktionen aus der Tabelle ausfuehren.
# (für alle Devices, solange nicht anders definiert) 
###############################################################################
#sub HAL_doAllActions() {
# Main:Log 3, "PROXY_CTRL:--------> do all ";
# foreach my $act (keys %{$actTab}) {
#   my $cTab = $actTab->{$act};
#   HAL_doAction($cTab, $act);
# }
#}

###############################################################################
# Eine bestimmte Aktion ausfuehren.
# (für alle Devices, solange nicht anders definiert) 
###############################################################################
#sub HAL_doAction($$) {
# my ($cTab, $actName) = @_;
# 
# Log 3, "PROXY_CTRL:--------> do ".$actName;
# 
# my $disabled = $cTab->{disabled}; # undef => enabled
# Log 3, "PROXY_CTRL:--------> act ".$actName." disabled:".$disabled;
# if(defined($disabled) && $disabled eq '1') { return }; # wenn disabled => raus
# 
# my $checkFn = $cTab->{checkFn}; # undef => ausführen
# Log 3, "PROXY_CTRL:--------> act ".$actName." checkFn:".$checkFn;
# if(defined($checkFn)) {
#   my $valueFn = eval $checkFn;
#   if(!defined($valueFn)) { return }; # wenn undef => raus
#    if( !$valueFn ) { return }; # wenn false => raus
# }
# 
# my @devList = $cTab->{deviceList}; # undef => für alle ausführen
# Log 3, "PROXY_CTRL:--------> act ".$actName." deviceList: ".@devList;
# if(@devList) {
#   foreach my $dev (@devList) {
#     Log 3, "PROXY_CTRL:--------> act ".$actName." device:".$dev;
#     HAL_DeviceSetFn($dev, $actName);
#   }
# } else {
#   foreach my $dev (keys %{$devTab}) {     
#     Log 3, "PROXY_CTRL:--------> act ".$actName." device:".$dev;
#     if($dev ne 'DEFAULT') {
#       HAL_DeviceSetFn($dev, $actName, "www"); #?
#     }
#    }
# }
#}

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
#sub HAL_DeviceSetFn($@) {
# my ($DEVICE,@a) = @_;
# my $CMD = $a[0];
#  my $ARGS = join(" ", @a[1..$#a]);
#  
#  #TODO
#  Log 3, "PROXY_CTRL:--------> set ".$DEVICE." - ".$CMD." - ".$ARGS;
#  my $cmdFn = $devTab->{$DEVICE}->{valueFns}->{$CMD}; #TODO
#  if(defined($cmdFn)) {
#   # TODO
#  } else {
#    return;
#  }
#}

# Zur Verwendung in ReadingProxy. Prüft (transparent) ob und wie ein Befehl ausgeführt werden soll.
# TODO
#sub HAL_SetProxyFn($@) {
# my ($DEVICE,@a) = @_;
# my $CMD = $a[0];
#  my $ARGS = join(" ", @a[1..$#a]);
#  
#  #TODO
#  Log 3, "PROXY_CTRL:--------> set ".$DEVICE." - ".$CMD." - ".$ARGS;
#  my $cmdFn = $devTab->{$DEVICE}->{valueFns}->{$CMD};
#  if(defined($cmdFn)) {
#   # TODO
#  } else {
#    return ""; # pass through cmd to device
#  }
#}

#--- TEST ---------------------------------------------------------------------
#--- Methods: Console Command -------------------------------------------------
 # >>> Test
 # my $template;
 # $template->{t1}->{test}      =">Test";
 # $template->{t1}->{test2}     =">Test2";
 # $template->{t1}->{testA}     =[">Test2"];
 # $template->{t1}->{type}      =">HomeMatic compatible";
 # $template->{t1}->{location}  =">test";
 # $template->{t1}->{set}->{1}  =">test1";
 # $template->{t1}->{set}->{2}  =">test2";
 # $template->{t1}->{readings}->{temperature} ->{reading}  =">temperature";
 # $template->{t1}->{readings}->{temperature} ->{unit}     =">°C";
 # $template->{t1}->{readings}->{bat} ->{reading}  =">bat";
 # $template->{t1}->{readings}->{bat} ->{unit}     =">v";
 # 
 # my $test;
 # $test->{sname}->{name}      = "Name";
 # $test->{sname}->{templates} = ["t1"];
 # $test->{sname}->{loacation} = "umwelt";
 # $test->{sname}->{readings}->{temperature}->{asd}  = "ASD";
 # $test->{sname}->{readings}->{humidity}->{asd}  = "DSF";
 #
 # $test->{sname2}->{name}      = "Name2";
 # $test->{sname2}->{templates} = ["t1"];
 # $test->{sname2}->{loacation} = "umwelt2";
 # $test->{sname2}->{readings}->{temperature}->{asd}  = "ASD2";
 # $test->{sname2}->{readings}->{humidity}->{asd}  = "DSF2";
 
sub sTest() {
  #merge_hash_recursive($test->{sname}, $template->{t1});
  #merge_hash_recursive($test->{sname2}, $template->{t1});
  
  HAL_expandTemplates($templates);
  return Dumper($templates);
  #return Dumper($test->{sname}) ."\n------------------\n". Dumper($test->{sname2});
}


1;
