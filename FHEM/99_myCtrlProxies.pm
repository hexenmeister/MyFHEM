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
  $rooms->{wohnzimmer}->{sensors}=["wz_raumsensor","wz_wandthermostat","tt_sensor","wz_ms_sensor","eg_wz_fk01","eg_wz_tk","virtual_wz_fenster","virtual_wz_terrassentuer"];
  $rooms->{wohnzimmer}->{sensors_outdoor}=["vr_luftdruck","um_hh_licht_th","um_vh_licht","um_vh_owts01","hg_sensor"]; # Sensoren 'vor dem Fenster'. Wichtig vor allen bei Licht (wg. Sonnenstand)
  # auch moeglich: Sensor mit der Liste der zu nutzenden Readings.
  # $rooms->{wohnzimmer}->{sensors}=["wz_raumsensor:temperature,humidity",...
  # TODO: ROllostand: Kombiniert ("eg_wz_rl01","eg_wz_rl02"..)
  
  $rooms->{kueche}->{alias}="Küche";
  $rooms->{kueche}->{fhem_name}="Kueche";
  $rooms->{kueche}->{sensors}=["ku_raumsensor","eg_ku_fk01","virtual_ku_fenster"];
  $rooms->{kueche}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_vh_owts01","um_hh_licht_th","hg_sensor"]; 
    
  $rooms->{umwelt}->{alias}="Umwelt";
  $rooms->{umwelt}->{fhem_name}="Umwelt";
  $rooms->{umwelt}->{sensors}=["virtual_umwelt_sensor","vr_luftdruck","um_vh_bw_licht"]; # Licht/Bewegung, 1wTemp, TinyTX-Garten (T/H), LichtGarten, LichtVorgarten
  $rooms->{umwelt}->{sensors_outdoor}=[]; # Keine
  
  $rooms->{vorgarten}->{alias}="Vorgarten";
  $rooms->{vorgarten}->{fhem_name}="---";
  $rooms->{vorgarten}->{sensors}=["um_vh_licht","um_vh_bw_licht","um_vh_bw_motion","um_vh_owts01","vr_luftdruck"];
  $rooms->{vorgarten}->{sensors_outdoor}=[];
  
  $rooms->{garten}->{alias}="Vorgarten";
  $rooms->{garten}->{fhem_name}="---";
  $rooms->{garten}->{sensors}=["hg_sensor","um_hh_licht_th","vr_luftdruck"];
  $rooms->{garten}->{sensors_outdoor}=[];
  
  $rooms->{eg_flur}->{alias}="Flur EG";
  $rooms->{eg_flur}->{fhem_name}="EG_Flur";
  $rooms->{eg_flur}->{sensors}=["eg_fl_raumsensor","fl_eg_ms_sensor"];
  $rooms->{eg_flur}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{og_flur}->{alias}="Flur OG";
  $rooms->{og_flur}->{fhem_name}="OG_Flur";
  $rooms->{og_flur}->{sensors}=["og_fl_raumsensor", "fl_og_ms_sensor"];
  $rooms->{og_flur}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{garage}->{alias}="Garage";
  $rooms->{garage}->{fhem_name}="Garage";
  $rooms->{garage}->{sensors}=["eg_ga_owts01","ga_sensor"];
  $rooms->{garage}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{schlafzimmer}->{alias}="Schlafzimmer";
  $rooms->{schlafzimmer}->{fhem_name}="Schlafzimmer";
  $rooms->{schlafzimmer}->{sensors}=["sz_raumsensor","sz_wandthermostat","og_sz_fk01"];
  $rooms->{schlafzimmer}->{sensors_outdoor}=["vr_luftdruck","um_hh_licht_th","um_vh_licht","um_vh_owts01","hg_sensor"];
  
  $rooms->{badezimmer}->{alias}="Badezimmer";
  $rooms->{badezimmer}->{fhem_name}="Badezimmer";
  $rooms->{badezimmer}->{sensors}=["bz_raumsensor","bz_wandthermostat","og_bz_fk01"];
  $rooms->{badezimmer}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{duschbad}->{alias}="Duschbad";
  $rooms->{duschbad}->{fhem_name}="Duschbad";
  $rooms->{duschbad}->{sensors}=["dz_wandthermostat"]; # TODO: Thermostat
  $rooms->{duschbad}->{sensors_outdoor}=["vr_luftdruck"];
  
  $rooms->{paula}->{alias}="Paulas Zimmer";
  $rooms->{paula}->{fhem_name}="Paula";
  $rooms->{paula}->{sensors}=["ka_raumsensor","ka_wandthermostat","og_ka_fk"];#,"og_ka_fk01","og_ka_fk02"
  $rooms->{paula}->{sensors_outdoor}=["vr_luftdruck","um_hh_licht_th","um_vh_licht","um_vh_owts01","hg_sensor"];
  
  $rooms->{hanna}->{alias}="Hannas Zimmer";
  $rooms->{hanna}->{fhem_name}="Hanna";
  $rooms->{hanna}->{sensors}=["kb_raumsensor","kb_wandthermostat","og_kb_fk01"];
  $rooms->{hanna}->{sensors_outdoor}=["vr_luftdruck","um_vh_licht","um_hh_licht_th","um_vh_owts01","hg_sensor"];
  
  $rooms->{ar}->{alias}="OG Abstellraum";
  $rooms->{ar}->{fhem_name}="OG_AR";
  $rooms->{ar}->{sensors}=["of_sensor"];
  $rooms->{ar}->{sensors_outdoor}=["vr_luftdruck",""];
  
  $rooms->{wc}->{alias}="Gäste WC";
  $rooms->{wc}->{fhem_name}="WC";
  $rooms->{wc}->{sensors}=["eg_wc_owts01"];
  $rooms->{wc}->{sensors_outdoor}=["vr_luftdruck",""];
  
  $rooms->{hwr}->{alias}="HWR";
  $rooms->{hwr}->{fhem_name}="hwr";
  $rooms->{hwr}->{sensors}=["eg_ha_owts01"];
  $rooms->{hwr}->{sensors_outdoor}=["vr_luftdruck",""];
  
  # DG
  # Räume ohne Sensoren: Speisekammer, (Abstellkammer => GSD1.3)
  
# Aktoren
my $actors;
  $actors->{wz_rollo_r}->{class}="rollo";
  $actors->{wz_rollo_r}->{alias}="WZ Rolladen";
  $actors->{wz_rollo_r}->{fhem_name}="wz_rollo_r";
  $actors->{wz_rollo_r}->{type}="HomeMatic compatible";
  $actors->{wz_rollo_r}->{location}="wohnzimmer";
  $actors->{wz_rollo_r}->{readings}->{level}="level";
  $actors->{wz_rollo_r}->{actions}->{level}->{set}="pct";
  $actors->{wz_rollo_r}->{actions}->{level}->{type}="int"; #?
  $actors->{wz_rollo_r}->{actions}->{level}->{min}="0";    #?
  $actors->{wz_rollo_r}->{actions}->{level}->{max}="100";  #?
  $actors->{wz_rollo_r}->{actions}->{level}->{alias}->{hoch}->{value}="100";
  $actors->{wz_rollo_r}->{actions}->{level}->{alias}->{runter}->{value}="0";
  $actors->{wz_rollo_r}->{actions}->{level}->{alias}->{halb}->{value}="60";
  $actors->{wz_rollo_r}->{actions}->{level}->{alias}->{nacht}->{value}="0";
  $actors->{wz_rollo_r}->{actions}->{level}->{alias}->{schatten}->{valueFn}="TODO";
  
  
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
  $sensors->{wz_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{wz_raumsensor}->{readings}->{luminosity}    ->{act_cycle} ="600"; 
  $sensors->{wz_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{wz_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{wz_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  $sensors->{eg_fl_raumsensor}->{alias}     ="EG Flur Raumsensor";
  $sensors->{eg_fl_raumsensor}->{fhem_name} ="EG_FL_KS01";
  $sensors->{eg_fl_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{eg_fl_raumsensor}->{location}  ="eg_flur";
  $sensors->{eg_fl_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{eg_fl_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{eg_fl_raumsensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{eg_fl_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $sensors->{eg_fl_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{eg_fl_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{eg_fl_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{eg_fl_raumsensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{eg_fl_raumsensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{eg_fl_raumsensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  $sensors->{eg_fl_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{eg_fl_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{eg_fl_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{eg_fl_raumsensor}->{readings}->{luminosity}    ->{act_cycle} ="600"; 
  $sensors->{eg_fl_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{eg_fl_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{eg_fl_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  $sensors->{og_fl_raumsensor}->{alias}     ="OG Flur Raumsensor";
  $sensors->{og_fl_raumsensor}->{fhem_name} ="OG_FL_KS01";
  $sensors->{og_fl_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{og_fl_raumsensor}->{location}  ="og_flur";
  $sensors->{og_fl_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{og_fl_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{og_fl_raumsensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{og_fl_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600";
  $sensors->{og_fl_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{og_fl_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{og_fl_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{og_fl_raumsensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{og_fl_raumsensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{og_fl_raumsensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  $sensors->{og_fl_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{og_fl_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{og_fl_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{og_fl_raumsensor}->{readings}->{luminosity}    ->{act_cycle} ="600"; 
  $sensors->{og_fl_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{og_fl_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{og_fl_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";

  $sensors->{sz_raumsensor}->{alias}     ="Schlafzimmer Raumsensor";
  $sensors->{sz_raumsensor}->{fhem_name} ="OG_SZ_KS01";
  $sensors->{sz_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{sz_raumsensor}->{location}  ="schlafzimmer";
  $sensors->{sz_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{sz_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{sz_raumsensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{sz_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600";
  $sensors->{sz_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{sz_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{sz_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{sz_raumsensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{sz_raumsensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{sz_raumsensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  $sensors->{sz_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{sz_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{sz_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{sz_raumsensor}->{readings}->{luminosity}  ->{act_cycle} ="600"; 
  $sensors->{sz_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{sz_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{sz_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  $sensors->{bz_raumsensor}->{alias}     ="Badezimmer Raumsensor";
  $sensors->{bz_raumsensor}->{fhem_name} ="OG_BZ_KS01";
  $sensors->{bz_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{bz_raumsensor}->{location}  ="badezimmer";
  $sensors->{bz_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{bz_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{bz_raumsensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{bz_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $sensors->{bz_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{bz_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{bz_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{bz_raumsensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{bz_raumsensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{bz_raumsensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  $sensors->{bz_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{bz_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{bz_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{bz_raumsensor}->{readings}->{luminosity}  ->{act_cycle} ="600"; 
  $sensors->{bz_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{bz_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{bz_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  $sensors->{ka_raumsensor}->{alias}     ="Kinderzimmer1 Raumsensor";
  $sensors->{ka_raumsensor}->{fhem_name} ="OG_KA_KS01";
  $sensors->{ka_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{ka_raumsensor}->{location}  ="paula";
  $sensors->{ka_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{ka_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{ka_raumsensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{ka_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $sensors->{ka_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{ka_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{ka_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{ka_raumsensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{ka_raumsensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{ka_raumsensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  $sensors->{ka_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{ka_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{ka_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{ka_raumsensor}->{readings}->{luminosity}  ->{act_cycle} ="600"; 
  $sensors->{ka_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{ka_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{ka_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";
  
  $sensors->{kb_raumsensor}->{alias}     ="Kinderzimmer2 Raumsensor";
  $sensors->{kb_raumsensor}->{fhem_name} ="OG_KB_KS01";
  $sensors->{kb_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{kb_raumsensor}->{location}  ="hanna";
  $sensors->{kb_raumsensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{kb_raumsensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{kb_raumsensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{kb_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $sensors->{kb_raumsensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{kb_raumsensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{kb_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{kb_raumsensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{kb_raumsensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{kb_raumsensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  $sensors->{kb_raumsensor}->{readings}->{luminosity}  ->{reading}  ="luminosity";
  $sensors->{kb_raumsensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{kb_raumsensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{kb_raumsensor}->{readings}->{luminosity}  ->{act_cycle} ="600"; 
  $sensors->{kb_raumsensor}->{readings}->{bat_voltage} ->{reading}  ="batVoltage";
  $sensors->{kb_raumsensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{kb_raumsensor}->{readings}->{bat_status}  ->{reading}  ="battery";


  # idee: 
  # $sensors->{vr_luftdruck}->{alias}       ="VirtuellerSensor";
  # $sensors->{vr_luftdruck}->{type}        ="virtual";
  # $sensors->{vr_luftdruck}->{readings}->{X}->{ValueFn}     ="max"; #min, summe, average, eigene... bekommt Record, liefert Wert # wenn ValueFn, dann nur deren Wert, keine weitere Logik
  # $sensors->{vr_luftdruck}->{readings_list} =["X",...]; # für ValueFn?
  # $sensors->{vr_luftdruck}->{readings}->{pressure} ="device:reading"; # 'Weiterleitung' ? 
  #
  $sensors->{test}->{alias}       ="TestSensor";
  $sensors->{test}->{type}        ="virtual";
  #$sensors->{test}->{readings}->{test1}->{ValueFn} = '{my $t=1; my $s=2; max($t,$s)}'; # mit Klammern: Direkt evaluieren, ansonsten als Funktion mit Reading-Hash und Device-Hash aufrufen.
  $sensors->{test}->{readings}->{test1}->{ValueFn} = 'senTest';
  $sensors->{test}->{readings}->{test1}->{FnParams} = ["1","2"];
  $sensors->{test}->{readings}->{test1}->{unit} ="?";
  $sensors->{test}->{readings}->{test1}->{alias} ="Funktionstest";
  $sensors->{test}->{readings}->{test2}->{link} ="vr_luftdruck:pressure";
  # 
  $sensors->{virtual_sun_sensor}->{alias}       ="Virtueller Sonnen-Sensor";
  $sensors->{virtual_sun_sensor}->{type}        ="virtual";
  $sensors->{virtual_sun_sensor}->{location}    ="umwelt";
  $sensors->{virtual_sun_sensor}->{comment}     ="Virtueller Sensor mit (berechneten) Readings zur Steuerungszwecken.";
  $sensors->{virtual_sun_sensor}->{composite} =["twilight_sensor","virtual_umwelt_sensor:luminosity"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{virtual_sun_sensor}->{readings}->{sun}->{ValueFn} = "HAL_SunValueFn";
  $sensors->{virtual_sun_sensor}->{readings}->{sun}->{FnParams} = [["um_vh_licht:luminosity",10,15], ["um_hh_licht_th:luminosity",10,15], ["um_vh_bw_licht:brightness",120,130]]; # Liste der Lichtsensoren zur Auswertung mit Grenzwerten (je 2 wg. Histerese)
  $sensors->{virtual_sun_sensor}->{readings}->{sun}->{alias} = "Virtuelle Sonne";
  $sensors->{virtual_sun_sensor}->{readings}->{sun}->{comment} = "gibt an, ob die 'Sonne' scheint, oder ob es genuegend dunkel ist (z.B. Rolladensteuerung).";
  
  $sensors->{twilight_sensor}->{alias}       ="Virtueller Sonnen-Sensor";
  $sensors->{twilight_sensor}->{fhem_name}   ="T";
  $sensors->{twilight_sensor}->{type}        ="virtual";
  $sensors->{twilight_sensor}->{location}    ="umwelt";
  $sensors->{twilight_sensor}->{comment}     ="Virtueller Sensor mit (berechneten) Readings zur Steuerungszwecken.";
  $sensors->{twilight_sensor}->{readings}->{azimuth} ->{reading}   ="azimuth";
  $sensors->{twilight_sensor}->{readings}->{azimuth} ->{unit}      ="grad";
  $sensors->{twilight_sensor}->{readings}->{azimuth} ->{alias}     ="Sonnenazimuth";
  $sensors->{twilight_sensor}->{readings}->{elevation} ->{reading} ="elevation";
  $sensors->{twilight_sensor}->{readings}->{elevation} ->{unit}    ="grad";
  $sensors->{twilight_sensor}->{readings}->{elevation} ->{alias}   ="Sonnenhoehe";
  $sensors->{twilight_sensor}->{readings}->{horizon} ->{reading}   ="horizon";
  $sensors->{twilight_sensor}->{readings}->{horizon} ->{unit}      ="grad";
  $sensors->{twilight_sensor}->{readings}->{horizon} ->{alias}     ="Stand über den Horizon";
  $sensors->{twilight_sensor}->{readings}->{sunrise} ->{reading}    ="sr";
  $sensors->{twilight_sensor}->{readings}->{sunrise} ->{unit}       ="time";
  $sensors->{twilight_sensor}->{readings}->{sunrise} ->{alias}      ="Sonnenaufgang";
  $sensors->{twilight_sensor}->{readings}->{sunset} ->{reading}     ="ss";
  $sensors->{twilight_sensor}->{readings}->{sunset} ->{unit}        ="time";
  $sensors->{twilight_sensor}->{readings}->{sunset} ->{alias}       ="Sonnenuntergang";
  
  $sensors->{virtual_umwelt_sensor}->{alias}       ="Virtuelle Umweltsensoren";
  $sensors->{virtual_umwelt_sensor}->{type}        ="virtual";
  $sensors->{virtual_umwelt_sensor}->{location}    ="umwelt";
  $sensors->{virtual_umwelt_sensor}->{comment}     ="Virtueller Sensor: Berechnet Max. Helligkeit mehreren Sensoren, Durchschnittstemperatur etc.";
  $sensors->{virtual_umwelt_sensor}->{readings}->{luminosity}->{ValueFn} = "HAL_MaxReadingValueFn";
  $sensors->{virtual_umwelt_sensor}->{readings}->{luminosity}->{FnParams} = ["um_vh_licht:luminosity", "um_hh_licht_th:luminosity"];
  $sensors->{virtual_umwelt_sensor}->{readings}->{luminosity}->{alias} = "Kombiniertes Lichtsensor";
  $sensors->{virtual_umwelt_sensor}->{readings}->{luminosity}->{comment} = "Kombiniert Werte beider Sensoren und nimmt das Maximum. Damit soll der Einfluss von Hausschatten entfernt werden.";
  $sensors->{virtual_umwelt_sensor}->{readings}->{temperature}->{ValueFn} = "HAL_MinReadingValueFn";
  $sensors->{virtual_umwelt_sensor}->{readings}->{temperature}->{ValueFilterFn} = "HAL_round1";
  $sensors->{virtual_umwelt_sensor}->{readings}->{temperature}->{FnParams} = ["um_vh_owts01:temperature", "um_hh_licht_th:temperature", "hg_sensor:temperature"];
  $sensors->{virtual_umwelt_sensor}->{readings}->{temperature}->{alias} = "Kombiniertes Temperatursensor";
  $sensors->{virtual_umwelt_sensor}->{readings}->{temperature}->{comment} = "Kombiniert Werte mehrerer Sensoren und bildet einen Durchschnittswert.";
  $sensors->{virtual_umwelt_sensor}->{readings}->{humidity}->{ValueFn} = "HAL_AvgReadingValueFn";
  $sensors->{virtual_umwelt_sensor}->{readings}->{humidity}->{ValueFilterFn} = "HAL_round1";
  $sensors->{virtual_umwelt_sensor}->{readings}->{humidity}->{FnParams} = ["um_hh_licht_th:humidity", "hg_sensor:humidity"];
  $sensors->{virtual_umwelt_sensor}->{readings}->{humidity}->{alias} = "Kombiniertes Feuchtesensor";
  $sensors->{virtual_umwelt_sensor}->{readings}->{humidity}->{comment} = "Kombiniert Werte mehrerer Sensoren und bildet einen Durchschnittswert.";
  
  # Schatten berechen: fuer X Meter Hohen Gegenstand :  {X/tan(deg2rad(50))}
  # Fenster-Höhen: WZ: 210 (unten 92), Terrassentuer: 207, Kueche: 212
  $sensors->{virtual_wz_fenster}->{alias}    = "Wohnzimmer Fenster";
  $sensors->{virtual_wz_fenster}->{type}     = "virtual";
  $sensors->{virtual_wz_fenster}->{location} = "wohnzimmer";
  $sensors->{virtual_wz_fenster}->{comment}  = "Wohnzimmer: Fenster: Zustand und Sonne";
  $sensors->{virtual_wz_fenster}->{composite} =["eg_wz_fk01:state",
                                                "eg_wz_rl01:level",
                                                "twilight_sensor:azimuth,elevation",
                                                "virtual_umwelt_sensor",
                                                "wz_ms_sensor:motiontime,motion15m,motion1h"];
  $sensors->{virtual_wz_fenster}->{readings}->{dim_top}->{ValueFn} = "{2.10}";
  $sensors->{virtual_wz_fenster}->{readings}->{dim_top}->{alias}   = "Hoehe";
  $sensors->{virtual_wz_fenster}->{readings}->{dim_top}->{comment} = "Hoehe ueber den Boden";
  $sensors->{virtual_wz_fenster}->{readings}->{dim_top}->{unit} = "m";
  $sensors->{virtual_wz_fenster}->{readings}->{dim_bottom}->{ValueFn} = "{0.92}";
  $sensors->{virtual_wz_fenster}->{readings}->{dim_bottom}->{alias}   = "Hoehe";
  $sensors->{virtual_wz_fenster}->{readings}->{dim_bottom}->{comment} = "Hoehe ueber den Boden";
  $sensors->{virtual_wz_fenster}->{readings}->{dim_bottom}->{unit} = "m";
  #$sensors->{virtual_wz_fenster}->{readings}->{cf_wall_thickness}->{ValueFn} = "{0.38}";
  #$sensors->{virtual_wz_fenster}->{readings}->{cf_wall_thickness}->{alias}   = "Korrekturfaktor Wanddicke";
  #$sensors->{virtual_wz_fenster}->{readings}->{cf_wall_thickness}->{comment} = "Korrektur fuer die Wand/Rolladenkasten-Dicke";
  #$sensors->{virtual_wz_fenster}->{readings}->{cf_wall_thickness}->{unit} = "m";
  #$sensors->{virtual_wz_fenster}->{readings}->{cf_sun_room_range}->{ValueFn} = "{0.85}";
  #$sensors->{virtual_wz_fenster}->{readings}->{cf_sun_room_range}->{alias}   = "Korrekturfaktor";
  #$sensors->{virtual_wz_fenster}->{readings}->{cf_sun_room_range}->{comment} = "Korrektur Anpassung";
  $sensors->{virtual_wz_fenster}->{readings}->{secure}->{ValueFn} = 'HAL_WinSecureStateValueFn';#'{my $t=HAL_getSensorReadingValue("eg_wz_fk01","state");$t eq "closed"?1:0}';
  $sensors->{virtual_wz_fenster}->{readings}->{secure}->{FnParams} = ['eg_wz_fk01:state'];
  $sensors->{virtual_wz_fenster}->{readings}->{secure}->{alias}   = "gesichert";
  $sensors->{virtual_wz_fenster}->{readings}->{secure}->{comment} = "Nicht offen oder gekippt";
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_side}->{ValueFn} = 'HAL_WinSunnySideValueFn';
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_side}->{FnParams} = [215,315]; # zu beachtender Winkel (Azimuth): von, bis
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_side}->{alias}   = "Sonnenseite";
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_side}->{comment} = "Sonne strahlt ins Fenster (Sonnenseite (und nicht Nacht))";
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_room_range}->{ValueFn} = 'HAL_WinSunRoomRange';
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.10, 0.57, 265]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_room_range}->{alias}   = "Sonnenreichweite";
  $sensors->{virtual_wz_fenster}->{readings}->{sunny_room_range}->{comment} = "Wie weit die Sonne ins Zimmer hineinragt (auf dem Boden)";
  $sensors->{virtual_wz_fenster}->{readings}->{presence}->{link} = "wz_ms_sensor:motion15m"; # PIR als Presence-Sensor verwenden
  
  $sensors->{virtual_wz_terrassentuer}->{alias}    = "Wohnzimmer Terrassentuer";
  $sensors->{virtual_wz_terrassentuer}->{type}     = "virtual";
  $sensors->{virtual_wz_terrassentuer}->{location} = "wohnzimmer";
  $sensors->{virtual_wz_terrassentuer}->{comment}  = "Wohnzimmer: Terrassentuer: Zustand und Sonne";
  $sensors->{virtual_wz_terrassentuer}->{composite} =["eg_wz_tk:state",
                                                      "eg_wz_rl02:level",
                                                      "twilight_sensor:azimuth,elevation",
                                                      "virtual_umwelt_sensor",
                                                      "wz_ms_sensor:motiontime,motion15m,motion1h"]; # TODO: Kombiniertes 2-KontaktSensor
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_top}->{ValueFn} = "{2.07}";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_top}->{alias}   = "Hoehe";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_top}->{comment} = "Hoehe ueber den Boden";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_top}->{unit} = "m";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_bottom}->{ValueFn} = "{0.12}";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_bottom}->{alias}   = "Hoehe";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_bottom}->{comment} = "Hoehe ueber den Boden";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{dim_bottom}->{unit} = "m";
  #$sensors->{virtual_wz_terrassentuer}->{readings}->{cf_wall_thickness}->{ValueFn} = "{0.38}";
  #$sensors->{virtual_wz_terrassentuer}->{readings}->{cf_wall_thickness}->{alias}   = "Korrekturfaktor Wanddicke";
  #$sensors->{virtual_wz_terrassentuer}->{readings}->{cf_wall_thickness}->{comment} = "Korrektur fuer die Wand/Rolladenkasten-Dicke";
  #$sensors->{virtual_wz_terrassentuer}->{readings}->{cf_wall_thickness}->{unit} = "m";
  #$sensors->{virtual_wz_terrassentuer}->{readings}->{cf_sun_room_range}->{ValueFn} = "{0.85}";
  #$sensors->{virtual_wz_terrassentuer}->{readings}->{cf_sun_room_range}->{alias}   = "Korrekturfaktor";
  #$sensors->{virtual_wz_terrassentuer}->{readings}->{cf_sun_room_range}->{comment} = "Korrektur Anpassung";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{secure}->{ValueFn} = 'HAL_WinSecureStateValueFn';
  $sensors->{virtual_wz_terrassentuer}->{readings}->{secure}->{FnParams} = ['eg_wz_tk:state']; # Kombiniertes 2-KontaktSensor
  $sensors->{virtual_wz_terrassentuer}->{readings}->{secure}->{alias}   = "gesichert";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{secure}->{comment} = "Nicht offen oder gekippt";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_side}->{ValueFn} = 'HAL_WinSunnySideValueFn';
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_side}->{FnParams} = [195,315]; # Beachten Winkel (Azimuth): von, bis
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_side}->{alias}   = "Sonnenseite";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_side}->{comment} = "Sonne strahlt ins Fenster (Sonnenseite (und nicht Nacht))";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_room_range}->{ValueFn} = 'HAL_WinSunRoomRange';
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_room_range}->{FnParams} = [2.07, 0.58, 265]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_room_range}->{alias}   = "Sonnenreichweite";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{sunny_room_range}->{comment} = "Wie weit die Sonne ins Zimmer hineinragt (auf dem Boden)";
  $sensors->{virtual_wz_terrassentuer}->{readings}->{presence}->{link} = "wz_ms_sensor:motion15m"; # PIR als Presence-Sensor verwenden

  $sensors->{virtual_ku_fenster}->{alias}    = "Kueche Fenster";
  $sensors->{virtual_ku_fenster}->{type}     = "virtual";
  $sensors->{virtual_ku_fenster}->{location} = "kueche";
  $sensors->{virtual_ku_fenster}->{comment}  = "Kueche: Fenster: Zustand und Sonne";
  $sensors->{virtual_ku_fenster}->{composite} =["eg_ku_fk01:state","eg_ku_rl01:level","twilight_sensor:azimuth,elevation","virtual_umwelt_sensor"];
  $sensors->{virtual_ku_fenster}->{readings}->{dim_top}->{ValueFn} = "{2.12}";
  $sensors->{virtual_ku_fenster}->{readings}->{dim_top}->{alias}   = "Hoehe";
  $sensors->{virtual_ku_fenster}->{readings}->{dim_top}->{comment} = "Hoehe ueber den Boden";
  $sensors->{virtual_ku_fenster}->{readings}->{dim_top}->{unit} = "m";
  $sensors->{virtual_ku_fenster}->{readings}->{dim_bottom}->{ValueFn} = "{1.28}";
  $sensors->{virtual_ku_fenster}->{readings}->{dim_bottom}->{alias}   = "Hoehe";
  $sensors->{virtual_ku_fenster}->{readings}->{dim_bottom}->{comment} = "Hoehe ueber den Boden";
  $sensors->{virtual_ku_fenster}->{readings}->{dim_bottom}->{unit} = "m";
  #$sensors->{virtual_ku_fenster}->{readings}->{cf_wall_thickness}->{ValueFn} = "{0.55}";
  #$sensors->{virtual_ku_fenster}->{readings}->{cf_wall_thickness}->{alias}   = "Korrekturfaktor Wanddicke";
  #$sensors->{virtual_ku_fenster}->{readings}->{cf_wall_thickness}->{comment} = "Korrektur fuer die Wand/Rolladenkasten-Dicke";
  #$sensors->{virtual_ku_fenster}->{readings}->{cf_wall_thickness}->{unit} = "m";
  #$sensors->{virtual_ku_fenster}->{readings}->{cf_sun_room_range}->{ValueFn} = "{0.85}";
  #$sensors->{virtual_ku_fenster}->{readings}->{cf_sun_room_range}->{alias}   = "Korrekturfaktor";
  #$sensors->{virtual_ku_fenster}->{readings}->{cf_sun_room_range}->{comment} = "Korrektur Anpassung";
  $sensors->{virtual_ku_fenster}->{readings}->{secure}->{ValueFn} = 'HAL_WinSecureStateValueFn';
  $sensors->{virtual_ku_fenster}->{readings}->{secure}->{FnParams} = ['eg_ku_fk01:state'];
  $sensors->{virtual_ku_fenster}->{readings}->{secure}->{alias}   = "gesichert";
  $sensors->{virtual_ku_fenster}->{readings}->{secure}->{comment} = "Nicht offen oder gekippt";
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_side}->{ValueFn} = 'HAL_WinSunnySideValueFn';
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_side}->{FnParams} = [43,144];
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_side}->{alias}   = "Sonnenseite";
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_side}->{comment} = "Sonne strahlt ins Fenster (Sonnenseite (und nicht Nacht))";
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_room_range}->{ValueFn} = 'HAL_WinSunRoomRange';
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_room_range}->{FnParams} = [2.12, 0.55, 85]; # Hoehe zum Berechnen des Sonneneinstrahlung, Wanddicke, SonnenWinkel: Elevation bei 90° Winkel zu Fenster (fuer Berechnungen: Wanddicke)
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_room_range}->{alias}   = "Sonnenreichweite";
  $sensors->{virtual_ku_fenster}->{readings}->{sunny_room_range}->{comment} = "Wie weit die Sonne ins Zimmer hineinragt (auf dem Boden)";
  
  # + state: sensor: eg_wz_fk01:state
  # + secure: 0,1
  # + Sonnenseite? 240° bis 290° (ca.)  sunny side
  # Sonne scheint ins Fenster: sunny (sunny_side + Helligkeit>X)
  # sunny + temp_outside > rollo zu 
  # + Länge des Sonnenflecks im Zimmer
  # + rollostand

# ValueFn: Berechnet, wieweit die Sonne aktuell ins Zimmer hineinstrahlt (am Boden). Beruecksichtigt nur Azimuth/Elevation, nicht die aktuelle Intensitaet.
# FnParams: Fensterhoehe (Oberkante)
sub HAL_WinSunRoomRange($$) {
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
	      #	$val-=$cf;
	      #	$val = 0 unless $val>0;
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
	      #	$val*=$cf;
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
	$ret->{reading_name} = $record->{name};
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
	$ret->{reading_name} = $record->{name};
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
	$ret->{reading_name} = $record->{name};
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
  		if(!defined($rname)) { $rname = $sRec->{reading}; }
  		if($time && $sRec->{time}) {
    		if($time lt $sRec->{time}) { $time = $sRec->{time}; }
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
  	$ret->{reading_name} = $rname;
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
  		  $rname = $sRec->{reading};
  		}
  	}
  }
  my $ret;
	$ret->{value} = $mVal;
	$ret->{unit} = $unit;
	$ret->{time} = $time;
	$ret->{reading_name} = $rname;
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
  		  $rname = $sRec->{reading};
  		}
  	}
  }
  my $ret;
	$ret->{value} = $mVal;
	$ret->{unit} = $unit;
	$ret->{time} = $time;
	$ret->{reading_name} = $rname;
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
    	  	$retTime = $time if($retTime lt $time);
    	  }
    	} elsif ($state eq 'tilted') {
      	if($retVal eq 'closed') {
    			$retVal = $state;
    		  $retTime = $time;
    	  } elsif ($retVal eq 'open') {
    	  	# NOP
      	} else { # gleiche
    	  	$retTime = $time if($retTime lt $time);
    	  }
    	} else { # closed
    		if($retVal eq 'closed') {
    		  $retTime = $time if($retTime lt $time);
    	  }
    	}
    }    	
    
    my $ret;
    $ret->{value} = $retVal;
  	$ret->{time} = $retTime;
  	return $ret;
}
    
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


  $sensors->{vr_luftdruck}->{alias}     ="Luftdrucksensor";
  $sensors->{vr_luftdruck}->{fhem_name} ="EG_WZ_KS01";
  $sensors->{vr_luftdruck}->{type}      ="HomeMatic compatible";
  $sensors->{vr_luftdruck}->{location}  ="virtual";
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
  
  $sensors->{sz_wandthermostat}->{alias}     ="SZ Wandthermostat";
  $sensors->{sz_wandthermostat}->{fhem_name} ="OG_SZ_WT01";
  $sensors->{sz_wandthermostat}->{type}      ="HomeMatic";
  $sensors->{sz_wandthermostat}->{location}  ="schlafzimmer";
  $sensors->{sz_wandthermostat}->{composite} =["sz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{sz_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{sz_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{sz_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{sz_wandthermostat_climate}->{alias}     ="WZ Wandthermostat (Ch)";
  $sensors->{sz_wandthermostat_climate}->{fhem_name} ="OG_SZ_WT01_Climate";
  $sensors->{sz_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{sz_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{sz_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{sz_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{sz_wandthermostat_climate}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{sz_wandthermostat_climate}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{sz_wandthermostat_climate}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{dz_wandthermostat}->{alias}     ="DZ Wandthermostat";
  $sensors->{dz_wandthermostat}->{fhem_name} ="OG_DZ_WT01";
  $sensors->{dz_wandthermostat}->{type}      ="HomeMatic";
  $sensors->{dz_wandthermostat}->{location}  ="duschbad";
  $sensors->{dz_wandthermostat}->{composite} =["dz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{dz_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{dz_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{dz_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{dz_wandthermostat_climate}->{alias}     ="DZ Wandthermostat (Ch)";
  $sensors->{dz_wandthermostat_climate}->{fhem_name} ="OG_DZ_WT01_Climate";
  $sensors->{dz_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{dz_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{dz_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{dz_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{dz_wandthermostat_climate}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{dz_wandthermostat_climate}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{dz_wandthermostat_climate}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{bz_wandthermostat}->{alias}     ="BZ Wandthermostat";
  $sensors->{bz_wandthermostat}->{fhem_name} ="OG_BZ_WT01";
  $sensors->{bz_wandthermostat}->{type}      ="HomeMatic";
  $sensors->{bz_wandthermostat}->{location}  ="badezimmer";
  $sensors->{bz_wandthermostat}->{composite} =["bz_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{bz_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{bz_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{bz_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{bz_wandthermostat_climate}->{alias}     ="BZ Wandthermostat (Ch)";
  $sensors->{bz_wandthermostat_climate}->{fhem_name} ="OG_BZ_WT01_Climate";
  $sensors->{bz_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{bz_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{bz_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{bz_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{bz_wandthermostat_climate}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{bz_wandthermostat_climate}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{bz_wandthermostat_climate}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{ka_wandthermostat}->{alias}     ="KA Wandthermostat";
  $sensors->{ka_wandthermostat}->{fhem_name} ="OG_KA_WT01";
  $sensors->{ka_wandthermostat}->{type}      ="HomeMatic";
  $sensors->{ka_wandthermostat}->{location}  ="paula";
  $sensors->{ka_wandthermostat}->{composite} =["ka_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{ka_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{ka_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{ka_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{ka_wandthermostat_climate}->{alias}     ="KA Wandthermostat (Ch)";
  $sensors->{ka_wandthermostat_climate}->{fhem_name} ="OG_KA_WT01_Climate";
  $sensors->{ka_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{ka_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{ka_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{ka_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{ka_wandthermostat_climate}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{ka_wandthermostat_climate}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{ka_wandthermostat_climate}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{kb_wandthermostat}->{alias}     ="KB Wandthermostat";
  $sensors->{kb_wandthermostat}->{fhem_name} ="OG_KA_WT01";
  $sensors->{kb_wandthermostat}->{type}      ="HomeMatic";
  $sensors->{kb_wandthermostat}->{location}  ="hanna";
  $sensors->{kb_wandthermostat}->{composite} =["kb_wandthermostat_climate"]; # Verbindung mit weitere (logischen) Geräten, die eine Einheit bilden.
  $sensors->{kb_wandthermostat}->{readings}        ->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{kb_wandthermostat}->{readings}        ->{bat_voltage} ->{unit}     ="V";
  $sensors->{kb_wandthermostat}->{readings}        ->{bat_status}  ->{reading}  ="battery";
  $sensors->{kb_wandthermostat_climate}->{alias}     ="KB Wandthermostat (Ch)";
  $sensors->{kb_wandthermostat_climate}->{fhem_name} ="OG_KB_WT01_Climate";
  $sensors->{kb_wandthermostat_climate}->{readings}->{temperature} ->{reading}  ="measured-temp";
  $sensors->{kb_wandthermostat_climate}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{kb_wandthermostat_climate}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{kb_wandthermostat_climate}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{kb_wandthermostat_climate}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{kb_wandthermostat_climate}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{kb_wandthermostat_climate}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{hg_sensor}->{alias}     ="Garten-Sensor";
  $sensors->{hg_sensor}->{fhem_name} ="GSD_1.4";
  $sensors->{hg_sensor}->{type}      ="GSD";
  $sensors->{hg_sensor}->{location}  ="garten";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{temperature} ->{act_cycle} ="600";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{hg_sensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{hg_sensor}->{readings}->{bat_voltage} ->{reading}  ="batteryLevel";
  $sensors->{hg_sensor}->{readings}->{bat_voltage} ->{unit}     ="V";
  $sensors->{hg_sensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{hg_sensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{hg_sensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{tt_sensor}->{alias}     ="Test-Sensor";
  $sensors->{tt_sensor}->{fhem_name} ="GSD_1.1";
  $sensors->{tt_sensor}->{type}      ="GSD";
  $sensors->{tt_sensor}->{location}  ="wohnzimmer";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{tt_sensor}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $sensors->{tt_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{tt_sensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{tt_sensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{tt_sensor}->{readings}->{bat_voltage}  ->{reading} ="batteryLevel";
  $sensors->{tt_sensor}->{readings}->{bat_voltage}  ->{unit}    ="V";
  $sensors->{tt_sensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{tt_sensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{tt_sensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";
  
  $sensors->{of_sensor}->{alias}     ="OG AR Sensor";
  $sensors->{of_sensor}->{fhem_name} ="GSD_1.3";
  $sensors->{of_sensor}->{type}      ="GSD";
  $sensors->{of_sensor}->{location}  ="OG_AR";
  $sensors->{of_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{of_sensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{of_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{of_sensor}->{readings}->{temperature} ->{act_cycle} ="600";
  $sensors->{of_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{of_sensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{of_sensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{of_sensor}->{readings}->{bat_voltage}  ->{reading} ="batteryLevel";
  $sensors->{of_sensor}->{readings}->{bat_voltage}  ->{unit}    ="V";
  $sensors->{of_sensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{of_sensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{of_sensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt";

  $sensors->{ga_sensor}->{alias}     ="Garage Kombisensor";
  $sensors->{ga_sensor}->{fhem_name} ="EG_GA_MS01";
  $sensors->{ga_sensor}->{type}      ="MySensors";
  $sensors->{ga_sensor}->{location}  ="garage";
  $sensors->{ga_sensor}->{readings}->{temperature} ->{reading}  ="temperature";
  $sensors->{ga_sensor}->{readings}->{temperature} ->{alias}    ="Temperatur";
  $sensors->{ga_sensor}->{readings}->{temperature} ->{unit}     ="°C";
  $sensors->{ga_sensor}->{readings}->{temperature} ->{act_cycle} ="600";
  $sensors->{ga_sensor}->{readings}->{humidity}    ->{reading}  ="humidity";
  $sensors->{ga_sensor}->{readings}->{humidity}    ->{alias}    ="rel. Feuchte";
  $sensors->{ga_sensor}->{readings}->{humidity}    ->{unit}     ="% rH";
  $sensors->{ga_sensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{ga_sensor}->{readings}->{dewpoint}    ->{reading}  ="dewpoint";
  $sensors->{ga_sensor}->{readings}->{dewpoint}    ->{unit}     ="°C";
  $sensors->{ga_sensor}->{readings}->{dewpoint}    ->{alias}    ="Taupunkt"; 
  $sensors->{ga_sensor}->{readings}->{absFeuchte}  ->{reading}  ="absFeuchte";
  $sensors->{ga_sensor}->{readings}->{absFeuchte}  ->{unit}     ="g/m3";
  $sensors->{ga_sensor}->{readings}->{absFeuchte}  ->{alias}    ="Abs. Feuchte";
  $sensors->{ga_sensor}->{readings}->{luminosity}  ->{reading}  ="brightness";
  $sensors->{ga_sensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{ga_sensor}->{readings}->{luminosity}  ->{unit}     ="RANGE: 0-120000";  
  $sensors->{ga_sensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{ga_sensor}->{readings}->{motion}      ->{reading}   ="motion";
  $sensors->{ga_sensor}->{readings}->{motion}      ->{alias}     ="Bewegungsmelder";
  $sensors->{ga_sensor}->{readings}->{motion}      ->{unit_type} ="ENUM: on";
  $sensors->{ga_sensor}->{readings}->{motiontime_str}->{ValueFn}   = "HAL_MotionTimeStrValueFn";
  $sensors->{ga_sensor}->{readings}->{motiontime}->{ValueFn}   = "HAL_MotionTimeValueFn";
  #$sensors->{ga_sensor}->{readings}->{motiontime}->{FnParams}  = "motion";
  $sensors->{ga_sensor}->{readings}->{motiontime}->{alias}     = "Zeit in Sekunden seit der letzten Bewegung";
  $sensors->{ga_sensor}->{readings}->{motiontime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Bewegung erkannt wurde";
  $sensors->{ga_sensor}->{readings}->{motion1m}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{ga_sensor}->{readings}->{motion1m}->{FnParams}  = [60, "motion"];
  $sensors->{ga_sensor}->{readings}->{motion1m}->{alias}     = "Bewegung in der letzten Minute";
  $sensors->{ga_sensor}->{readings}->{motion1m}->{comment}   = "gibt an, ob in der letzten Minute eine Bewegung erkannt wurde";
  $sensors->{ga_sensor}->{readings}->{motion15m}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{ga_sensor}->{readings}->{motion15m}->{FnParams} = [900, "motion"];
  $sensors->{ga_sensor}->{readings}->{motion15m}->{alias}    = "Bewegung in den letzten 15 Minuten";
  $sensors->{ga_sensor}->{readings}->{motion15m}->{comment}  = "gibt an, ob in den letzten 15 Minuten eine Bewegung erkannt wurde";
  $sensors->{ga_sensor}->{readings}->{motion1h}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{ga_sensor}->{readings}->{motion1h}->{FnParams}  = [3600, "motion"];
  $sensors->{ga_sensor}->{readings}->{motion1h}->{alias}     = "Bewegung in der letzten Stunde";
  $sensors->{ga_sensor}->{readings}->{motion1h}->{comment}   = "gibt an, ob in der letzten Stunde eine Bewegung erkannt wurde";
  $sensors->{ga_sensor}->{readings}->{motion12h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{ga_sensor}->{readings}->{motion12h}->{FnParams} = [43200, "motion"];
  $sensors->{ga_sensor}->{readings}->{motion12h}->{alias}    = "Bewegung in den letzten 12 Stunden";
  $sensors->{ga_sensor}->{readings}->{motion12h}->{comment}  = "gibt an, ob in den letzten 12 Stunden eine Bewegung erkannt wurde";
  $sensors->{ga_sensor}->{readings}->{motion24h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{ga_sensor}->{readings}->{motion24h}->{FnParams} = [86400, "motion"];
  $sensors->{ga_sensor}->{readings}->{motion24h}->{alias}    = "Bewegung in den letzten 24 Stunden";
  $sensors->{ga_sensor}->{readings}->{motion24h}->{comment}  = "gibt an, ob in den letzten 24 Stunden eine Bewegung erkannt wurde";

  
  $sensors->{wz_ms_sensor}->{alias}     ="WZ MS Kombisensor";
  $sensors->{wz_ms_sensor}->{fhem_name} ="EG_WZ_MS01";
  $sensors->{wz_ms_sensor}->{type}      ="MySensors";
  $sensors->{wz_ms_sensor}->{location}  ="wohnzimmer";
  $sensors->{wz_ms_sensor}->{readings}->{luminosity} ->{act_cycle} ="600";
  $sensors->{wz_ms_sensor}->{readings}->{luminosity}  ->{reading}  ="brightness";
  $sensors->{wz_ms_sensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{wz_ms_sensor}->{readings}->{luminosity}  ->{unit}     ="RANGE: 0-120000";  
  $sensors->{wz_ms_sensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{wz_ms_sensor}->{readings}->{motion}      ->{reading}   ="motion";
  $sensors->{wz_ms_sensor}->{readings}->{motion}      ->{alias}     ="Bewegungsmelder";
  $sensors->{wz_ms_sensor}->{readings}->{motion}      ->{unit_type} ="ENUM: on";
  $sensors->{wz_ms_sensor}->{readings}->{motiontime_str}->{ValueFn}   = "HAL_MotionTimeStrValueFn";
  $sensors->{wz_ms_sensor}->{readings}->{motiontime}->{ValueFn}   = "HAL_MotionTimeValueFn";
  #$sensors->{wz_ms_sensor}->{readings}->{motiontime}->{FnParams}  = "motion";
  $sensors->{wz_ms_sensor}->{readings}->{motiontime}->{alias}     = "Zeit in Sekunden seit der letzten Bewegung";
  $sensors->{wz_ms_sensor}->{readings}->{motiontime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Bewegung erkannt wurde";
  $sensors->{wz_ms_sensor}->{readings}->{motion1m}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{wz_ms_sensor}->{readings}->{motion1m}->{FnParams}  = [60, "motion"];
  $sensors->{wz_ms_sensor}->{readings}->{motion1m}->{alias}     = "Bewegung in der letzten Minute";
  $sensors->{wz_ms_sensor}->{readings}->{motion1m}->{comment}   = "gibt an, ob in der letzten Minute eine Bewegung erkannt wurde";
  $sensors->{wz_ms_sensor}->{readings}->{motion15m}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{wz_ms_sensor}->{readings}->{motion15m}->{FnParams} = [900, "motion"];
  $sensors->{wz_ms_sensor}->{readings}->{motion15m}->{alias}    = "Bewegung in den letzten 15 Minuten";
  $sensors->{wz_ms_sensor}->{readings}->{motion15m}->{comment}  = "gibt an, ob in den letzten 15 Minuten eine Bewegung erkannt wurde";
  $sensors->{wz_ms_sensor}->{readings}->{motion1h}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{wz_ms_sensor}->{readings}->{motion1h}->{FnParams}  = [3600, "motion"];
  $sensors->{wz_ms_sensor}->{readings}->{motion1h}->{alias}     = "Bewegung in der letzten Stunde";
  $sensors->{wz_ms_sensor}->{readings}->{motion1h}->{comment}   = "gibt an, ob in der letzten Stunde eine Bewegung erkannt wurde";
  $sensors->{wz_ms_sensor}->{readings}->{motion12h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{wz_ms_sensor}->{readings}->{motion12h}->{FnParams} = [43200, "motion"];
  $sensors->{wz_ms_sensor}->{readings}->{motion12h}->{alias}    = "Bewegung in den letzten 12 Stunden";
  $sensors->{wz_ms_sensor}->{readings}->{motion12h}->{comment}  = "gibt an, ob in den letzten 12 Stunden eine Bewegung erkannt wurde";
  $sensors->{wz_ms_sensor}->{readings}->{motion24h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{wz_ms_sensor}->{readings}->{motion24h}->{FnParams} = [86400, "motion"];
  $sensors->{wz_ms_sensor}->{readings}->{motion24h}->{alias}    = "Bewegung in den letzten 24 Stunden";
  $sensors->{wz_ms_sensor}->{readings}->{motion24h}->{comment}  = "gibt an, ob in den letzten 24 Stunden eine Bewegung erkannt wurde";

  
  $sensors->{fl_eg_ms_sensor}->{alias}     ="FL EG MS Kombisensor";
  $sensors->{fl_eg_ms_sensor}->{fhem_name} ="EG_FL_MS01";
  $sensors->{fl_eg_ms_sensor}->{type}      ="MySensors";
  $sensors->{fl_eg_ms_sensor}->{location}  ="eg_flur";
  $sensors->{fl_eg_ms_sensor}->{readings}->{luminosity} ->{act_cycle} ="600";
  $sensors->{fl_eg_ms_sensor}->{readings}->{luminosity}  ->{reading}  ="brightness";
  $sensors->{fl_eg_ms_sensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{fl_eg_ms_sensor}->{readings}->{luminosity}  ->{unit}     ="RANGE: 0-120000";  
  $sensors->{fl_eg_ms_sensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion}      ->{reading}   ="motion";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion}      ->{alias}     ="Bewegungsmelder";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion}      ->{unit_type} ="ENUM: on";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motiontime_str}->{ValueFn}   = "HAL_MotionTimeStrValueFn";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motiontime}->{ValueFn}   = "HAL_MotionTimeValueFn";
  #$sensors->{fl_eg_ms_sensor}->{readings}->{motiontime}->{FnParams}  = "motion";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motiontime}->{alias}     = "Zeit in Sekunden seit der letzten Bewegung";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motiontime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Bewegung erkannt wurde";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1m}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1m}->{FnParams}  = [60, "motion"];
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1m}->{alias}     = "Bewegung in der letzten Minute";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1m}->{comment}   = "gibt an, ob in der letzten Minute eine Bewegung erkannt wurde";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion15m}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion15m}->{FnParams} = [900, "motion"];
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion15m}->{alias}    = "Bewegung in den letzten 15 Minuten";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion15m}->{comment}  = "gibt an, ob in den letzten 15 Minuten eine Bewegung erkannt wurde";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1h}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1h}->{FnParams}  = [3600, "motion"];
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1h}->{alias}     = "Bewegung in der letzten Stunde";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion1h}->{comment}   = "gibt an, ob in der letzten Stunde eine Bewegung erkannt wurde";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion12h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion12h}->{FnParams} = [43200, "motion"];
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion12h}->{alias}    = "Bewegung in den letzten 12 Stunden";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion12h}->{comment}  = "gibt an, ob in den letzten 12 Stunden eine Bewegung erkannt wurde";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion24h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion24h}->{FnParams} = [86400, "motion"];
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion24h}->{alias}    = "Bewegung in den letzten 24 Stunden";
  $sensors->{fl_eg_ms_sensor}->{readings}->{motion24h}->{comment}  = "gibt an, ob in den letzten 24 Stunden eine Bewegung erkannt wurde";


  $sensors->{fl_og_ms_sensor}->{alias}     ="FL OG MS Kombisensor";
  $sensors->{fl_og_ms_sensor}->{fhem_name} ="OG_FL_MS01";
  $sensors->{fl_og_ms_sensor}->{type}      ="MySensors";
  $sensors->{fl_og_ms_sensor}->{location}  ="og_flur";
  $sensors->{fl_og_ms_sensor}->{readings}->{luminosity} ->{act_cycle} ="600";
  $sensors->{fl_og_ms_sensor}->{readings}->{luminosity}  ->{reading}  ="brightness";
  $sensors->{fl_og_ms_sensor}->{readings}->{luminosity}  ->{alias}    ="Lichtintesität";
  $sensors->{fl_og_ms_sensor}->{readings}->{luminosity}  ->{unit}     ="RANGE: 0-120000";  
  $sensors->{fl_og_ms_sensor}->{readings}->{luminosity}  ->{unit}     ="Lx (*)";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion}      ->{reading}   ="motion";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion}      ->{alias}     ="Bewegungsmelder";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion}      ->{unit_type} ="ENUM: on";
  $sensors->{fl_og_ms_sensor}->{readings}->{motiontime_str}->{ValueFn}   = "HAL_MotionTimeStrValueFn";
  $sensors->{fl_og_ms_sensor}->{readings}->{motiontime}->{ValueFn}   = "HAL_MotionTimeValueFn";
  #$sensors->{fl_og_ms_sensor}->{readings}->{motiontime}->{FnParams}  = "motion";
  $sensors->{fl_og_ms_sensor}->{readings}->{motiontime}->{alias}     = "Zeit in Sekunden seit der letzten Bewegung";
  $sensors->{fl_og_ms_sensor}->{readings}->{motiontime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Bewegung erkannt wurde";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1m}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1m}->{FnParams}  = [60, "motion"];
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1m}->{alias}     = "Bewegung in der letzten Minute";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1m}->{comment}   = "gibt an, ob in der letzten Minute eine Bewegung erkannt wurde";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion15m}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion15m}->{FnParams} = [900, "motion"];
  $sensors->{fl_og_ms_sensor}->{readings}->{motion15m}->{alias}    = "Bewegung in den letzten 15 Minuten";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion15m}->{comment}  = "gibt an, ob in den letzten 15 Minuten eine Bewegung erkannt wurde";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1h}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1h}->{FnParams}  = [3600, "motion"];
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1h}->{alias}     = "Bewegung in der letzten Stunde";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion1h}->{comment}   = "gibt an, ob in der letzten Stunde eine Bewegung erkannt wurde";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion12h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion12h}->{FnParams} = [43200, "motion"];
  $sensors->{fl_og_ms_sensor}->{readings}->{motion12h}->{alias}    = "Bewegung in den letzten 12 Stunden";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion12h}->{comment}  = "gibt an, ob in den letzten 12 Stunden eine Bewegung erkannt wurde";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion24h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion24h}->{FnParams} = [86400, "motion"];
  $sensors->{fl_og_ms_sensor}->{readings}->{motion24h}->{alias}    = "Bewegung in den letzten 24 Stunden";
  $sensors->{fl_og_ms_sensor}->{readings}->{motion24h}->{comment}  = "gibt an, ob in den letzten 24 Stunden eine Bewegung erkannt wurde";

  
  $sensors->{ku_raumsensor}->{alias}     ="KU Raumsensor";
  $sensors->{ku_raumsensor}->{fhem_name} ="EG_KU_KS01";
  $sensors->{ku_raumsensor}->{type}      ="HomeMatic compatible";
  $sensors->{ku_raumsensor}->{location}  ="kueche";
  $sensors->{ku_raumsensor}->{readings}->{temperature} ->{reading}   ="temperature";
  $sensors->{ku_raumsensor}->{readings}->{temperature} ->{alias}     ="Temperatur";
  $sensors->{ku_raumsensor}->{readings}->{temperature} ->{unit}      ="°C";
  $sensors->{ku_raumsensor}->{readings}->{temperature} ->{act_cycle} ="600"; # Zeit in Sekunden ohne Rückmeldung, dann wird Device als 'dead' erklaert.
  $sensors->{ku_raumsensor}->{readings}->{humidity}    ->{reading}   ="humidity";
  $sensors->{ku_raumsensor}->{readings}->{humidity}    ->{alias}     ="Luftfeuchtigkeit"; 
  $sensors->{ku_raumsensor}->{readings}->{humidity}    ->{unit}      ="% rH";
  $sensors->{ku_raumsensor}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{ku_raumsensor}->{readings}->{luminosity}  ->{reading}   ="luminosity";
  $sensors->{ku_raumsensor}->{readings}->{luminosity}  ->{alias}     ="Lichtintesität";
  $sensors->{ku_raumsensor}->{readings}->{luminosity}  ->{unit}      ="Lx (*)";
  $sensors->{ku_raumsensor}->{readings}->{luminosity}  ->{act_cycle} ="600"; 
  $sensors->{ku_raumsensor}->{readings}->{bat_voltage} ->{reading}   ="batVoltage";
  $sensors->{ku_raumsensor}->{readings}->{bat_voltage} ->{alias}     ="Batteriespannung";
  $sensors->{ku_raumsensor}->{readings}->{bat_voltage} ->{unit}      ="V";
  $sensors->{ku_raumsensor}->{readings}->{bat_status}  ->{reading}   ="battery";
  $sensors->{ku_raumsensor}->{readings}->{dewpoint}    ->{reading}   ="dewpoint";
  $sensors->{ku_raumsensor}->{readings}->{dewpoint}    ->{unit}      ="°C";
  $sensors->{ku_raumsensor}->{readings}->{dewpoint}    ->{alias}     ="Taupunkt";
  
  $sensors->{um_vh_licht}->{alias}     ="VH Aussensensor";
  $sensors->{um_vh_licht}->{fhem_name} ="UM_VH_KS01";
  $sensors->{um_vh_licht}->{type}      ="HomeMatic compatible";
  $sensors->{um_vh_licht}->{location}  ="umwelt";
  #$sensors->{um_vh_licht}->{readings}->{luminosity}  ->{reading}   ="luminosity";
  $sensors->{um_vh_licht}->{readings}->{luminosity}  ->{reading}   ="normalizedLuminosity";
  $sensors->{um_vh_licht}->{readings}->{luminosity}  ->{alias}     ="Lichtintesität";
  $sensors->{um_vh_licht}->{readings}->{luminosity}  ->{unit}      ="Lx (*)";
  $sensors->{um_vh_licht}->{readings}->{luminosity}  ->{act_cycle} ="600"; 
  $sensors->{um_vh_licht}->{readings}->{bat_voltage} ->{reading}   ="batVoltage";
  $sensors->{um_vh_licht}->{readings}->{bat_voltage} ->{alias}     ="Batteriespannung";
  $sensors->{um_vh_licht}->{readings}->{bat_voltage} ->{unit}      ="V";
  $sensors->{um_vh_licht}->{readings}->{bat_status}  ->{reading}   ="battery";
  
  $sensors->{um_hh_licht_th}->{alias}     ="HH Aussensensor";
  $sensors->{um_hh_licht_th}->{fhem_name} ="UM_HH_KS01";
  $sensors->{um_hh_licht_th}->{type}      ="HomeMatic compatible";
  $sensors->{um_hh_licht_th}->{location}  ="umwelt";
  #$sensors->{um_hh_licht_th}->{readings}->{luminosity}  ->{reading}   ="luminosity";
  $sensors->{um_hh_licht_th}->{readings}->{luminosity}  ->{reading}   ="normalizedLuminosity"; 
  $sensors->{um_hh_licht_th}->{readings}->{luminosity}  ->{alias}     ="Lichtintesität";
  $sensors->{um_hh_licht_th}->{readings}->{luminosity}  ->{unit}      ="Lx (*)";
  $sensors->{um_hh_licht_th}->{readings}->{luminosity}  ->{act_cycle} ="600"; 
  $sensors->{um_hh_licht_th}->{readings}->{bat_voltage} ->{reading}   ="batVoltage";
  $sensors->{um_hh_licht_th}->{readings}->{bat_voltage} ->{alias}     ="Batteriespannung";
  $sensors->{um_hh_licht_th}->{readings}->{bat_voltage} ->{unit}      ="V";
  $sensors->{um_hh_licht_th}->{readings}->{bat_status}  ->{reading}   ="battery";
  $sensors->{um_hh_licht_th}->{readings}->{bat_status}  ->{alias}     ="Batteriezustand";
  $sensors->{um_hh_licht_th}->{readings}->{temperature} ->{reading}   ="temperature";
  $sensors->{um_hh_licht_th}->{readings}->{temperature} ->{alias}     ="Temperatur";
  $sensors->{um_hh_licht_th}->{readings}->{temperature} ->{unit}      ="°C";
  $sensors->{um_hh_licht_th}->{readings}->{temperature} ->{act_cycle} ="600";
  $sensors->{um_hh_licht_th}->{readings}->{humidity}    ->{reading}   ="humidity";
  $sensors->{um_hh_licht_th}->{readings}->{humidity}    ->{alias}     ="Luftfeuchtigkeit"; 
  $sensors->{um_hh_licht_th}->{readings}->{humidity}    ->{unit}      ="% rH";
  $sensors->{um_hh_licht_th}->{readings}->{humidity}    ->{act_cycle} ="600"; 
  $sensors->{um_hh_licht_th}->{readings}->{dewpoint}    ->{reading}   ="dewpoint";
  $sensors->{um_hh_licht_th}->{readings}->{dewpoint}    ->{unit}      ="°C";
  $sensors->{um_hh_licht_th}->{readings}->{dewpoint}    ->{alias}     ="Taupunkt";
  
  $sensors->{um_vh_bw_licht}->{alias}     ="Bewegungsmelder (Vorgarten)";
  $sensors->{um_vh_bw_licht}->{fhem_name} ="UM_VH_HMBL01.Eingang";
  $sensors->{um_vh_bw_licht}->{type}      ="HomeMatic";
  $sensors->{um_vh_bw_licht}->{location}  ="umwelt";
  $sensors->{um_vh_bw_licht}->{readings}->{brightness}  ->{reading}   ="brightness";
  $sensors->{um_vh_bw_licht}->{readings}->{brightness}  ->{alias}     ="Helligkeit";
  $sensors->{um_vh_bw_licht}->{readings}->{brightness}  ->{unit}      ="RANGE: 0-250";
  $sensors->{um_vh_bw_licht}->{readings}->{brightness}  ->{act_cycle} ="600";
  
  $sensors->{um_vh_bw_motion}->{alias}     ="Bewegungsmelder (Vorgarten)";
  $sensors->{um_vh_bw_motion}->{fhem_name} ="UM_VH_HMBL01.Eingang";
  $sensors->{um_vh_bw_motion}->{type}      ="HomeMatic";
  $sensors->{um_vh_bw_motion}->{location}  ="vorgarten";
  $sensors->{um_vh_bw_motion}->{readings}->{motion}      ->{reading}   ="motion";
  $sensors->{um_vh_bw_motion}->{readings}->{motion}      ->{alias}     ="Bewegungsmelder";
  $sensors->{um_vh_bw_motion}->{readings}->{motion}      ->{unit_type} ="ENUM: on";
  $sensors->{um_vh_bw_motion}->{readings}->{motiontime_str}->{ValueFn}   = "HAL_MotionTimeStrValueFn";
  $sensors->{um_vh_bw_motion}->{readings}->{motiontime}->{ValueFn}   = "HAL_MotionTimeValueFn";
  #$sensors->{um_vh_bw_motion}->{readings}->{motiontime}->{FnParams}  = "motion";
  $sensors->{um_vh_bw_motion}->{readings}->{motiontime}->{alias}     = "Zeit in Sekunden seit der letzten Bewegung";
  $sensors->{um_vh_bw_motion}->{readings}->{motiontime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Bewegung erkannt wurde";
  $sensors->{um_vh_bw_motion}->{readings}->{bat_status}  ->{reading}   ="battery";
  $sensors->{um_vh_bw_motion}->{readings}->{bat_status}  ->{alias}     ="Batteriezustand";
  $sensors->{um_vh_bw_motion}->{readings}->{bat_status}  ->{unit_type} ="ENUM: ok,low";
  $sensors->{um_vh_bw_motion}->{readings}->{motion1m}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{um_vh_bw_motion}->{readings}->{motion1m}->{FnParams}  = [60, "motion"];
  $sensors->{um_vh_bw_motion}->{readings}->{motion1m}->{alias}     = "Bewegung in der letzten Minute";
  $sensors->{um_vh_bw_motion}->{readings}->{motion1m}->{comment}   = "gibt an, ob in der letzten Minute eine Bewegung erkannt wurde";
  $sensors->{um_vh_bw_motion}->{readings}->{motion15m}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{um_vh_bw_motion}->{readings}->{motion15m}->{FnParams} = [900, "motion"];
  $sensors->{um_vh_bw_motion}->{readings}->{motion15m}->{alias}    = "Bewegung in den letzten 15 Minuten";
  $sensors->{um_vh_bw_motion}->{readings}->{motion15m}->{comment}  = "gibt an, ob in den letzten 15 Minuten eine Bewegung erkannt wurde";
  $sensors->{um_vh_bw_motion}->{readings}->{motion1h}->{ValueFn}   = "HAL_MotionValueFn";
  $sensors->{um_vh_bw_motion}->{readings}->{motion1h}->{FnParams}  = [3600, "motion"];
  $sensors->{um_vh_bw_motion}->{readings}->{motion1h}->{alias}     = "Bewegung in der letzten Stunde";
  $sensors->{um_vh_bw_motion}->{readings}->{motion1h}->{comment}   = "gibt an, ob in der letzten Stunde eine Bewegung erkannt wurde";
  $sensors->{um_vh_bw_motion}->{readings}->{motion12h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{um_vh_bw_motion}->{readings}->{motion12h}->{FnParams} = [43200, "motion"];
  $sensors->{um_vh_bw_motion}->{readings}->{motion12h}->{alias}    = "Bewegung in den letzten 12 Stunden";
  $sensors->{um_vh_bw_motion}->{readings}->{motion12h}->{comment}  = "gibt an, ob in den letzten 12 Stunden eine Bewegung erkannt wurde";
  $sensors->{um_vh_bw_motion}->{readings}->{motion24h}->{ValueFn}  = "HAL_MotionValueFn";
  $sensors->{um_vh_bw_motion}->{readings}->{motion24h}->{FnParams} = [86400, "motion"];
  $sensors->{um_vh_bw_motion}->{readings}->{motion24h}->{alias}    = "Bewegung in den letzten 24 Stunden";
  $sensors->{um_vh_bw_motion}->{readings}->{motion24h}->{comment}  = "gibt an, ob in den letzten 24 Stunden eine Bewegung erkannt wurde";
  
  #$sensors->{eg_fl_bw_licht}->{alias}     ="Bewegungsmelder (Flur hinten)";
  #$sensors->{eg_fl_bw_licht}->{fhem_name} ="EG_FL_MS01";
  #$sensors->{eg_fl_bw_licht}->{type}      ="MySensors";
  #$sensors->{eg_fl_bw_licht}->{location}  ="eg_flur";
  #$sensors->{eg_fl_bw_licht}->{readings}->{brightness}  ->{reading}   ="brightness";
  #$sensors->{eg_fl_bw_licht}->{readings}->{brightness}  ->{alias}     ="Helligkeit";
  #$sensors->{eg_fl_bw_licht}->{readings}->{brightness}  ->{unit}      ="RANGE: 0-54612";
  #$sensors->{eg_fl_bw_licht}->{readings}->{brightness}  ->{act_cycle} ="600";
  #$sensors->{eg_fl_bw_licht}->{readings}->{motion}      ->{reading}   ="motion";
  #$sensors->{eg_fl_bw_licht}->{readings}->{motion}      ->{alias}     ="Bewegungsmelder";
  #$sensors->{eg_fl_bw_licht}->{readings}->{motion}      ->{unit_type} ="ENUM: on";
  
  $sensors->{um_vh_owts01}->{alias}     ="OWX Aussentemperatur";
  $sensors->{um_vh_owts01}->{fhem_name} ="UM_VH_OWTS01.Luft";
  $sensors->{um_vh_owts01}->{type}      ="OneWire";
  $sensors->{um_vh_owts01}->{location}  ="umwelt";
  $sensors->{um_vh_owts01}->{readings}->{temperature}  ->{reading}  ="temperature";
  $sensors->{um_vh_owts01}->{readings}->{temperature}  ->{unit}     ="°C";
  $sensors->{um_vh_owts01}->{readings}->{temperature}  ->{ValueFilterFn} ='HAL_round1';
  $sensors->{um_vh_owts01}->{readings}->{temperature}  ->{alias}    ="Temperatur";
  
  $sensors->{eg_ga_owts01}->{alias}     ="OWX Garage";
  $sensors->{eg_ga_owts01}->{fhem_name} ="EG_GA_OWTS01.Raum";
  $sensors->{eg_ga_owts01}->{type}      ="OneWire";
  $sensors->{eg_ga_owts01}->{location}  ="garage";
  $sensors->{eg_ga_owts01}->{readings}->{temperature}  ->{reading}  ="temperature";
  $sensors->{eg_ga_owts01}->{readings}->{temperature}  ->{unit}     ="°C";
  $sensors->{eg_ga_owts01}->{readings}->{temperature}  ->{ValueFilterFn} ='HAL_round1';
  $sensors->{eg_ga_owts01}->{readings}->{temperature}  ->{alias}    ="Temperatur";
  
  $sensors->{eg_fl_owts01}->{alias}     ="OWX Flur";
  $sensors->{eg_fl_owts01}->{fhem_name} ="EG_FL_OWTS01.Raum";
  $sensors->{eg_fl_owts01}->{type}      ="OneWire";
  $sensors->{eg_fl_owts01}->{location}  ="eg_flur";
  $sensors->{eg_fl_owts01}->{readings}->{temperature}  ->{reading}  ="temperature";
  $sensors->{eg_fl_owts01}->{readings}->{temperature}  ->{unit}     ="°C";
  $sensors->{eg_fl_owts01}->{readings}->{temperature}  ->{ValueFilterFn} ='HAL_round1';
  $sensors->{eg_fl_owts01}->{readings}->{temperature}  ->{alias}    ="Temperatur";
  
  $sensors->{eg_wc_owts01}->{alias}     ="OWX Gäste WC";
  $sensors->{eg_wc_owts01}->{fhem_name} ="EG_WC_OWTS01.Raum";
  $sensors->{eg_wc_owts01}->{type}      ="OneWire";
  $sensors->{eg_wc_owts01}->{location}  ="wc";
  $sensors->{eg_wc_owts01}->{readings}->{temperature}  ->{reading}  ="temperature";
  $sensors->{eg_wc_owts01}->{readings}->{temperature}  ->{unit}     ="°C";
  $sensors->{eg_wc_owts01}->{readings}->{temperature}  ->{ValueFilterFn} ='HAL_round1';
  $sensors->{eg_wc_owts01}->{readings}->{temperature}  ->{alias}    ="Temperatur";
  
  $sensors->{eg_ha_owts01}->{alias}     ="OWX HWR";
  $sensors->{eg_ha_owts01}->{fhem_name} ="EG_HA_OWTS01.Raum_Oben";
  $sensors->{eg_ha_owts01}->{type}      ="OneWire";
  $sensors->{eg_ha_owts01}->{location}  ="hwr";
  $sensors->{eg_ha_owts01}->{readings}->{temperature}  ->{reading}  ="temperature";
  $sensors->{eg_ha_owts01}->{readings}->{temperature}  ->{unit}     ="°C";
  $sensors->{eg_ha_owts01}->{readings}->{temperature}  ->{ValueFilterFn} ='HAL_round1';
  $sensors->{eg_ha_owts01}->{readings}->{temperature}  ->{alias}    ="Temperatur";

  $sensors->{eg_ku_rl01}->{alias}     ="Rollo";
  $sensors->{eg_ku_rl01}->{fhem_name} ="ku_rollo";
  $sensors->{eg_ku_rl01}->{type}      ="HomeMatic";
  $sensors->{eg_ku_rl01}->{location}  ="kueche";
  $sensors->{eg_ku_rl01}->{comment}   ="Rollostand";
  $sensors->{eg_ku_rl01}->{readings}->{level} ->{reading}   ="level";
  $sensors->{eg_ku_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $sensors->{eg_ku_rl01}->{readings}->{level} ->{unit} ="%";
  
  $sensors->{eg_ku_fk01}->{alias}     ="Fensterkontakt";
  $sensors->{eg_ku_fk01}->{fhem_name} ="EG_KU_FK01.Fenster";
  $sensors->{eg_ku_fk01}->{type}      ="HomeMatic";
  $sensors->{eg_ku_fk01}->{location}  ="kueche";
  $sensors->{eg_ku_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{eg_ku_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{eg_ku_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{eg_ku_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{eg_ku_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{eg_ku_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{eg_ku_fk01}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{eg_ku_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{eg_ku_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $sensors->{eg_ku_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{eg_ku_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{eg_ku_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{eg_ku_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{eg_ku_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{eg_ku_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  #TODO: Mapping f. Zustaende: closed => geschlossen?
  
  $sensors->{eg_wz_rl01}->{alias}     ="Rollo";
  $sensors->{eg_wz_rl01}->{fhem_name} ="wz_rollo_l";
  $sensors->{eg_wz_rl01}->{type}      ="HomeMatic";
  $sensors->{eg_wz_rl01}->{location}  ="wohnzimmer";
  $sensors->{eg_wz_rl01}->{comment}   ="Rollostand";
  $sensors->{eg_wz_rl01}->{readings}->{level} ->{reading}   ="level";
  $sensors->{eg_wz_rl01}->{readings}->{level} ->{alias}     ="Rollostand";
  $sensors->{eg_wz_rl01}->{readings}->{level} ->{unit} ="%";
  
  $sensors->{eg_wz_rl02}->{alias}     ="Rollo";
  $sensors->{eg_wz_rl02}->{fhem_name} ="wz_rollo_r";
  $sensors->{eg_wz_rl02}->{type}      ="HomeMatic";
  $sensors->{eg_wz_rl02}->{location}  ="wohnzimmer";
  $sensors->{eg_wz_rl02}->{comment}   ="Rollostand";
  $sensors->{eg_wz_rl02}->{readings}->{level} ->{reading}   ="level";
  $sensors->{eg_wz_rl02}->{readings}->{level} ->{alias}     ="Rollostand";
  $sensors->{eg_wz_rl02}->{readings}->{level} ->{unit} ="%";
  
  $sensors->{eg_wz_fk01}->{alias}     ="Fensterkontakt";
  $sensors->{eg_wz_fk01}->{fhem_name} ="EG_WZ_FK01.Fenster";
  $sensors->{eg_wz_fk01}->{type}      ="HomeMatic";
  $sensors->{eg_wz_fk01}->{location}  ="wohnzimmer";
  $sensors->{eg_wz_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{eg_wz_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{eg_wz_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{eg_wz_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{eg_wz_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{eg_wz_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{eg_wz_fk01}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{eg_wz_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{eg_wz_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $sensors->{eg_wz_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{eg_wz_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{eg_wz_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{eg_wz_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{eg_wz_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{eg_wz_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{eg_wz_tk01}->{alias}     ="Terrassentürkontakt Links";
  $sensors->{eg_wz_tk01}->{fhem_name} ="wz_fenster_l";
  $sensors->{eg_wz_tk01}->{type}      ="HomeMatic";
  $sensors->{eg_wz_tk01}->{location}  ="wohnzimmer";
  $sensors->{eg_wz_tk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{eg_wz_tk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{eg_wz_tk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{eg_wz_tk01}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{eg_wz_tk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{eg_wz_tk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{eg_wz_tk01}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{eg_wz_tk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{eg_wz_tk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{eg_wz_tk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{eg_wz_tk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{eg_wz_tk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{eg_wz_tk01}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{eg_wz_tk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{eg_wz_tk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";

  $sensors->{eg_wz_tk02}->{alias}     ="Terrassentürkontakt Recht";
  $sensors->{eg_wz_tk02}->{fhem_name} ="wz_fenster_r";
  $sensors->{eg_wz_tk02}->{type}      ="HomeMatic";
  $sensors->{eg_wz_tk02}->{location}  ="wohnzimmer";
  $sensors->{eg_wz_tk02}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{eg_wz_tk02}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{eg_wz_tk02}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{eg_wz_tk02}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{eg_wz_tk02}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{eg_wz_tk02}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{eg_wz_tk02}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{eg_wz_tk02}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{eg_wz_tk02}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{eg_wz_tk02}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{eg_wz_tk02}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{eg_wz_tk02}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{eg_wz_tk02}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{eg_wz_tk02}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{eg_wz_tk02}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{eg_wz_tk}->{alias}     ="Terrassentürkontakt Kombiniert";
  $sensors->{eg_wz_tk}->{type}      ="virtual";
  $sensors->{eg_wz_tk}->{location}  ="wohnzimmer";
  $sensors->{eg_wz_tk}->{readings}->{state}         ->{ValueFn}   ="HAL_WinCombiStateValueFn";
  $sensors->{eg_wz_tk}->{readings}->{state}         ->{FnParams}   =["eg_wz_tk01:state","eg_wz_tk02:state"];
  $sensors->{eg_wz_tk}->{readings}->{state}         ->{alias}     ="Terrassentuerzustand";
  $sensors->{eg_wz_tk}->{readings}->{state}         ->{unit_type} ="ENUM: closed,open";
  $sensors->{eg_wz_tk}->{readings}->{state1}        ->{link}   = "eg_wz_tk01:state";
  $sensors->{eg_wz_tk}->{readings}->{state2}        ->{link}   = "eg_wz_tk02:state";
  $sensors->{eg_wz_tk}->{readings}->{statetime1}    ->{link}   = "eg_wz_tk01:statetime";
  $sensors->{eg_wz_tk}->{readings}->{statetime2}    ->{link}   = "eg_wz_tk02:statetime";
  $sensors->{eg_wz_tk}->{readings}->{statetime1_str}->{link}   = "eg_wz_tk01:statetime_str";
  $sensors->{eg_wz_tk}->{readings}->{statetime2_str}->{link}   = "eg_wz_tk02:statetime_str";
  $sensors->{eg_wz_tk}->{readings}->{statetime_str} ->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{eg_wz_tk}->{readings}->{statetime_str} ->{FnParams}  = "state";
  $sensors->{eg_wz_tk}->{readings}->{statetime}     ->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{eg_wz_tk}->{readings}->{statetime}     ->{FnParams}  = "state";
  $sensors->{eg_wz_tk}->{readings}->{statetime}     ->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{eg_wz_tk}->{readings}->{statetime}     ->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{og_bz_fk01}->{alias}     ="Fensterkontakt";
  $sensors->{og_bz_fk01}->{fhem_name} ="OG_BZ_FK01.Fenster";
  $sensors->{og_bz_fk01}->{type}      ="HomeMatic";
  $sensors->{og_bz_fk01}->{location}  ="badezimmer";
  $sensors->{og_bz_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{og_bz_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{og_bz_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{og_bz_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{og_bz_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{og_bz_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{og_bz_fk01}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{og_bz_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{og_bz_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $sensors->{og_bz_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{og_bz_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{og_bz_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{og_bz_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{og_bz_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{og_bz_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{og_sz_fk01}->{alias}     ="Fensterkontakt";
  $sensors->{og_sz_fk01}->{fhem_name} ="OG_SZ_FK01.Fenster";
  $sensors->{og_sz_fk01}->{type}      ="HomeMatic";
  $sensors->{og_sz_fk01}->{location}  ="schlafzimmer";
  $sensors->{og_sz_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{og_sz_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{og_sz_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{og_sz_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{og_sz_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{og_sz_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{og_sz_fk01}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{og_sz_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{og_sz_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $sensors->{og_sz_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{og_sz_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{og_sz_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{og_sz_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{og_sz_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{og_sz_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{og_ka_fk}->{alias}     ="Fensterkontakt Kombiniert";
  $sensors->{og_ka_fk}->{type}      ="virtual";
  $sensors->{og_ka_fk}->{location}  ="wohnzimmer";
  $sensors->{og_ka_fk}->{readings}->{state}         ->{ValueFn}   ="HAL_WinCombiStateValueFn";
  $sensors->{og_ka_fk}->{readings}->{state}         ->{FnParams}   =["og_ka_fk01:state","og_ka_fk02:state"];
  $sensors->{og_ka_fk}->{readings}->{state}         ->{alias}     ="Fensterzustand";
  $sensors->{og_ka_fk}->{readings}->{state}         ->{unit_type} ="ENUM: closed,open";
  $sensors->{og_ka_fk}->{readings}->{state1}        ->{link}   = "og_ka_fk01:state";
  $sensors->{og_ka_fk}->{readings}->{state2}        ->{link}   = "og_ka_fk02:state";
  $sensors->{og_ka_fk}->{readings}->{statetime1}    ->{link}   = "og_ka_fk01:statetime";
  $sensors->{og_ka_fk}->{readings}->{statetime2}    ->{link}   = "og_ka_fk02:statetime";
  $sensors->{og_ka_fk}->{readings}->{statetime1_str}->{link}   = "og_ka_fk01:statetime_str";
  $sensors->{og_ka_fk}->{readings}->{statetime2_str}->{link}   = "og_ka_fk02:statetime_str";
  $sensors->{og_ka_fk}->{readings}->{statetime_str} ->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{og_ka_fk}->{readings}->{statetime_str} ->{FnParams}  = "state";
  $sensors->{og_ka_fk}->{readings}->{statetime}     ->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{og_ka_fk}->{readings}->{statetime}     ->{FnParams}  = "state";
  $sensors->{og_ka_fk}->{readings}->{statetime}     ->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{og_ka_fk}->{readings}->{statetime}     ->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{og_ka_fk01}->{alias}     ="Fensterkontakt";
  $sensors->{og_ka_fk01}->{fhem_name} ="OG_KA_FK01.Fenster";
  $sensors->{og_ka_fk01}->{type}      ="HomeMatic";
  $sensors->{og_ka_fk01}->{location}  ="paula";
  $sensors->{og_ka_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{og_ka_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{og_ka_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{og_ka_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{og_ka_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{og_ka_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{og_ka_fk01}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{og_ka_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{og_ka_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $sensors->{og_ka_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{og_ka_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{og_ka_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{og_ka_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{og_ka_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{og_ka_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{og_ka_fk02}->{alias}     ="Fensterkontakt";
  $sensors->{og_ka_fk02}->{fhem_name} ="OG_KA_FK02.Fenster";
  $sensors->{og_ka_fk02}->{type}      ="HomeMatic";
  $sensors->{og_ka_fk02}->{location}  ="paula";
  $sensors->{og_ka_fk02}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{og_ka_fk02}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{og_ka_fk02}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{og_ka_fk02}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{og_ka_fk02}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{og_ka_fk02}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{og_ka_fk02}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{og_ka_fk02}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{og_ka_fk02}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $sensors->{og_ka_fk02}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{og_ka_fk02}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{og_ka_fk02}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{og_ka_fk02}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{og_ka_fk02}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{og_ka_fk02}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
  $sensors->{og_kb_fk01}->{alias}     ="Fensterkontakt";
  $sensors->{og_kb_fk01}->{fhem_name} ="OG_KB_FK01.Fenster";
  $sensors->{og_kb_fk01}->{type}      ="HomeMatic";
  $sensors->{og_kb_fk01}->{location}  ="hanna";
  $sensors->{og_kb_fk01}->{readings}->{bat_status}   ->{reading}   ="battery";
  $sensors->{og_kb_fk01}->{readings}->{bat_status}   ->{alias}     ="Batteriezustand";
  $sensors->{og_kb_fk01}->{readings}->{bat_status}   ->{unit_type} ="ENUM: ok,low";
  $sensors->{og_kb_fk01}->{readings}->{cover}        ->{reading}   ="cover";
  $sensors->{og_kb_fk01}->{readings}->{cover}        ->{alias}     ="Coverzustand";
  $sensors->{og_kb_fk01}->{readings}->{cover}        ->{unit_type} ="ENUM: closed,open";
  $sensors->{og_kb_fk01}->{readings}->{state}        ->{reading}   ="state";
  $sensors->{og_kb_fk01}->{readings}->{state}        ->{alias}     ="Fensterzustand";
  $sensors->{og_kb_fk01}->{readings}->{state}        ->{unit_type} ="ENUM: closed,open,tilted";
  $sensors->{og_kb_fk01}->{readings}->{statetime_str}->{ValueFn}   = "HAL_ReadingTimeStrValueFn";
  $sensors->{og_kb_fk01}->{readings}->{statetime_str}->{FnParams}  = "state";
  $sensors->{og_kb_fk01}->{readings}->{statetime}->{ValueFn}   = "HAL_ReadingTimeValueFn";
  $sensors->{og_kb_fk01}->{readings}->{statetime}->{FnParams}  = "state";
  $sensors->{og_kb_fk01}->{readings}->{statetime}->{alias}     = "Zeit in Sekunden seit der letzten Statusaenderung";
  $sensors->{og_kb_fk01}->{readings}->{statetime}->{comment}   = "gibt an, wie viel zeit in Sekunden vergangen ist seit die letzte Aenderung stattgefunden hat";
  
#------------------------------------------------------------------------------
my $actTab;
  $actTab->{"schatten"}->{checkFn}="";
  #$actTab->{"schatten"}->{disabled}="0"; #1=disabled, 0, undef,.. => enabled
  #$actTab->{"schatten"}->{deviceList}=[]; # undef=> alle in devTab, ansonsten nur angegebenen
  $actTab->{"nacht"}->{checkFn}="";
  $actTab->{"test"}->{checkFn}=undef;
#------------------------------------------------------------------------------

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
#TODO: Statt FHEM-Namen als Keys die Verweise auf actors-Tab verwenden.
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
sub HAL_getRooms();
sub HAL_getRoomRecord($);
sub HAL_getRoomNames();
#sub HAL_getRooms(;$); # Räume  nach verschiedenen Kriterien?
#sub HAL_getActions(;$); # <DevName>

sub HAL_getRoomSensorNames($);
sub HAL_getRoomOutdoorSensorNames($);
sub HAL_getRoomSensorReadingsList($;$);
sub HAL_getRoomOutdoorSensorReadingsList($;$);

sub HAL_getRoomReadingRecord($$);
sub HAL_getRoomOutdoorReadingRecord($$);
sub HAL_getRoomReadingValue($$;$$);


# Sensoren
sub HAL_getSensors();
sub HAL_getSensorNames();
sub HAL_getSensorRecord($);
sub HAL_getSensorReadingsList($);
sub HAL_getSensorValueRecord($$);
sub HAL_getSensorReadingValue($$);
sub HAL_getSensorReadingUnit($$);
sub HAL_getSensorReadingTime($$);

#TODO sub HAL_getSensors(;$$$$); # <SenName/undef> [<type>][<DevName>][<location>]

# 
#sub HAL_getDevices(;$$$);# <DevName/undef>(undef => alles) [<Type>][<room>]

# Readings
sub HAL_getReadingRecord($); # "sname:rname" => HAL_getSensorValueRecord
sub HAL_getReadingValue($);  # "sname:rname" => HAL_getSensorReadingValue
sub HAL_getReadingUnit($);   # "sname:rname" => HAL_getSensorReadingUnit
sub HAL_getReadingTime($);   # "sname:rname" => HAL_getSensorReadingTime

#

require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";

# Action
sub HAL_doAllActions();
sub HAL_doAction($$);
sub HAL_DeviceSetFn($@);

#------------------------------------------------------------------------------

sub
myCtrlProxies_Initialize($$)
{
  my ($hash) = @_;
}

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
		
	my $sensorList = HAL_getRoomSensorNames_($roomName, $listName);	#HAL_getRoomSensorNames($roomName);
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
		Log 3,"+++++++++++++++++> >>> ".$sName." > :: ".$readingName;
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
HAL_getSensorRecord($)
{
	my ($name) = @_;
	return undef unless $name;
	my $ret = HAL_getSensors()->{$name};
	$ret->{name} = $name; # Name hinzufuegen
	return $ret;
}

# Liefert HASH mit Sensor-Definitionen
sub HAL_getSensors() {
  return $sensors;
}

# Liefert Liste der Sensornamen.
sub HAL_getSensorNames() {
	my $r = HAL_getSensors();
	return keys($r);
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
	$ret->{name} = $name; # Name hinzufuegen
	return $ret;
}

# Liefert HASH mit Raum-Definitionen
sub HAL_getRooms() {
  return $rooms;
}

# Liefert Liste der Raumnamen.
sub HAL_getRoomNames() {
	my $r = HAL_getRooms();
	return keys($r);
}

# liefert Liste (Referenz) der Sensors in einem Raum (Liste der Namen)
# Param: Raumname
#  Beispiel:   {HAL_getRoomSensorNames("wohnzimmer")->[0]}
sub HAL_getRoomSensorNames($)
{
	my ($roomName) = @_;
  return HAL_getRoomSensorNames_($roomName,"sensors");	
}

# liefert Liste (Referenz) der Sensors für einen Raum draussen (Liste der Namen)
# Param: Raumname
#  Beispiel:  {HAL_getRoomSensorNames("wohnzimmer")->[0]}
sub HAL_getRoomOutdoorSensorNames($)
{
	my ($roomName) = @_;
  return HAL_getRoomSensorNames_($roomName,"sensors_outdoor");	
}

# liefert Referenz der Liste der Sensors in einem Raum (List der Namen)
# Param: Raumname, SensorListName (z.B. sensors, sensors_outdoor)
sub HAL_getRoomSensorNames_($$)
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
	
	my $snames = HAL_getRoomSensorNames_($roomName,$listName);
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
#	my ($roomName) = @_;
#  return HAL_getRoomSensors_($roomName,"sensors");	
#}
#
## liefert Liste der Sensors für einen Raum draussen (Array of Hashes)
## Param: Raumname
##  Beispiel:  {(HAL_getRoomOutdoorSensors("wohnzimmer"))[0]->{alias}}
#sub HAL_getRoomOutdoorSensors($)
#{
#	my ($roomName) = @_;
#  return HAL_getRoomSensors_($roomName,"sensors_outdoor");	
#}
#
## liefert Liste der Sensors in einem Raum (Array of Hashes)
## Param: Raumname, SensorListName (z.B. sensors, sensors_outdoor)
#sub HAL_getRoomSensors_($$)
#{
#	my ($roomName, $listName) = @_;
#	my $roomRec=HAL_getRoomRecord($roomName);
#	return undef unless $roomRec;
#	my $sensorList=$roomRec->{$listName};
#	return undef unless $sensorList;
#	
#	my @ret;
#	foreach my $sName (@{$sensorList}) {
#		my $sRec = HAL_getSensorRecord($sName);
#		push(@ret, \%{$sRec}) if $sRec ;
#	}
#	
#	return @ret;
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

sub HAL_getSensorReadingCompositeRecord_intern($$);
# sucht gewünschtes reading zu dem angegebenen device, folgt den in {composite} definierten (Unter)-Devices.
# liefert Device und Reading Recors als Array 
sub
HAL_getSensorReadingCompositeRecord_intern($$)
{
	my ($device_record,$reading) = @_;
	return (undef, undef) unless $device_record;
	return (undef, undef) unless $reading;
	
	my $readings_record = $device_record->{readings};
	my $single_reading_record = $readings_record->{$reading};
	
	if ($single_reading_record) {
		$single_reading_record->{reading_name} = $reading;
	  return ($device_record, $single_reading_record);
	}
	
	# composites verarbeiten
	# e.g.  $sensors->{wz_wandthermostat}->{composite} =("wz_wandthermostat_climate"); 
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
			$new_single_reading_record->{reading_name} = $reading;
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
HAL_getSensorReadingRecord($$)
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
			return HAL_getSensorValueRecord($sensorName,$readingName);
		} 
		
		my $valueFn =  $record->{ValueFn};
		if($valueFn) {
	    if($valueFn=~m/\{.*\}/) {
	    	# Klammern: direkt evaluieren
	      $val= eval $valueFn;	
	    } else {
	    	no strict "refs";
        my $r = &{$valueFn}($device,$record);
        use strict "refs";
        if(ref $r eq ref {}) {
        	# wenn Hash (also kompletter Hash zurückgegeben, mit value, time etc.)
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
      #Log 3,"+++++++++++++++++> ".Dumper($record);
      $val = ReadingsVal($fhem_name,$reading_fhem_name,undef);
      $time = ReadingsTimestamp($fhem_name,$reading_fhem_name,undef);
      #Log 3,"+++++++++++++++++> Name: ".$fhem_name." Reading: ".$reading_fhem_name." =>VAL:".$val;
    }
    
    $ret->{value}     =$val if(defined $val);
    $val = $ret->{value};
    
    # ValueFilterFn
    my $valueFilterFn =  $record->{ValueFilterFn};
    if($valueFilterFn) {
    	#Log 3,"+++++++++++++++++> D: ".$val;
			if($valueFilterFn=~m/\{.*\}/) {
	    	# Klammern: direkt evaluieren
	    	my $VAL = $val;
	      $val= eval $valueFilterFn;
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
    $actCycle = 0 unless defined $actCycle;
    my $iactCycle = int($actCycle);
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
    
    $ret->{unit}      =$record->{unit};
    $ret->{alias}     =$record->{alias};
    $ret->{fhem_name} =$device->{fhem_name};
    $ret->{sensor} =$device->{name};
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
sub HAL_getSensorReadingTime($$)
{
	my ($name, $reading) = @_;
	my $h = HAL_getSensorValueRecord($name, $reading);
	return undef unless $h;
	return $h->{time};
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

#------------------------------------------------------------------------------

#- Steuerung fuer manuelle Aufrufe (AT) ---------------------------------------

###############################################################################
# Alle Aktionen aus der Tabelle ausfuehren.
# (für alle Devices, solange nicht anders definiert) 
###############################################################################
sub
HAL_doAllActions() {
	Main:Log 3, "PROXY_CTRL:--------> do all ";
	foreach my $act (keys %{$actTab}) {
		my $cTab = $actTab->{$act};
		HAL_doAction($cTab, $act);
	}
}

###############################################################################
# Eine bestimmte Aktion ausfuehren.
# (für alle Devices, solange nicht anders definiert) 
###############################################################################
sub
HAL_doAction($$) {
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
		  HAL_DeviceSetFn($dev, $actName);
	  }
	} else {
	  foreach my $dev (keys %{$devTab}) {     
	  	Log 3, "PROXY_CTRL:--------> act ".$actName." device:".$dev;
  	  if($dev ne 'DEFAULT') {
  	  	HAL_DeviceSetFn($dev, $actName, "www"); #?
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
HAL_DeviceSetFn($@) {
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
HAL_SetProxyFn($@) {
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
