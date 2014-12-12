################################################################
#
#  Copyright notice
#
#  (c) 2014 Alexander Schulz
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  This copyright notice MUST APPEAR in all copies of the script!
#
################################################################

# $Id$

package main;

use strict;
use warnings;

my $VERSION = "0.0.0.1";

my $DEFAULT_INTERVAL = 60; # in minuten

sub
SMARTMON_Initialize($)
{
  my ($hash) = @_;

  Log 5, "SMARTMON Initialize";

  $hash->{DefFn}    = "SMARTMON_Define";
  $hash->{UndefFn}  = "SMARTMON_Undefine";
  $hash->{GetFn}    = "SMARTMON_Get";
  #$hash->{SetFn}    = "SMARTMON_Set";
  #$hash->{AttrFn}   = "SMARTMON_Attr";
  $hash->{AttrList} = "disable:0,1 ".$readingFnAttributes;
}

sub SMARTMON_Log($$$) {
   my ( $hash, $loglevel, $text ) = @_;
   my $xline       = ( caller(0) )[2];
   
   my $xsubroutine = ( caller(1) )[3];
   my $sub         = ( split( ':', $xsubroutine ) )[2];
   $sub =~ s/SMARTMON_//;

   my $instName = ( ref($hash) eq "HASH" ) ? $hash->{NAME} : $hash;
   Log3 $hash, $loglevel, "SMARTMON $instName: $sub.$xline " . $text;
}

my $device;

sub SMARTMON_Define($$)
{
  my ($hash, $def) = @_;

  SMARTMON_Log($hash, 4, "Define $def");

  my @a = split("[ \t][ \t]*", $def);

  SMARTMON_Log($hash, 5, "Define: ".Dumper(@a));

  return "Usage: define <name> SMARTMON <device> [M1]" if(@a < 3);

  $hash->{DEVICE} = $a[2];
  if(int(@a)>=4)
  {
  	$hash->{INTERVAL} = $a[3]*60;
  } else {
  	$hash->{INTERVAL} = $DEFAULT_INTERVAL*60;
  }

  $hash->{STATE} = "Initialized";

  RemoveInternalTimer($hash);
  # erstes update zeitversetzt starten
  InternalTimer(gettimeofday()+10, "SMARTMON_Update", $hash, 0);

  return undef;
}

sub SMARTMON_Undefine($$)
{
  my ($hash, $arg) = @_;

  SMARTMON_Log($hash, 4, "Undefine");

  RemoveInternalTimer($hash);
  return undef;
}

sub SMARTMON_Get($@)
{
  my ($hash, @a) = @_;

  my $name = $a[0];

  if(@a < 2)
  {
    return "$name: get needs at least one parameter";
  }

  my $cmd= $a[1];

  SMARTMON_Log($hash, 5, "Get: ".Dumper(@a));

  if($cmd eq "update")
  {
  	SMARTMON_refreshReadings($hash);
  	return undef;
  }

  if($cmd eq "version")
  {
  	return $VERSION;
  }
  
  #DEVICE SCAN:  sudo smartctl --scan

  return "Unknown argument $cmd, choose one of update:noArg version:noArg";
}

sub SMARTMON_Update($@)
{
  my ($hash, $refresh_all) = @_;

  SMARTMON_Log($hash, 5, "Update");
  
  my $name = $hash->{NAME};

  RemoveInternalTimer($hash);
  InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SMARTMON_Update", $hash, 1);
  
  SMARTMON_refreshReadings($hash);

}

sub SMARTMON_refreshReadings($) {
	my ($hash) = @_;
	
	SMARTMON_Log($hash, 5, "Refresh readings");
	
	my $name = $hash->{NAME};
	
  readingsBeginUpdate($hash);
  
  if( AttrVal($name, "disable", "") eq "1" )
  {
  	SMARTMON_Log($hash, 5, "Update disabled");
  	$hash->{STATE} = "Inactive";
  } else {
	  # Parameter holen
    my $map = SMARTMON_obtainParameters($hash);
	  
    $hash->{STATE} = "Active";

    foreach my $aName (keys %{$map}) {
  	  my $value = $map->{$aName};
  	  # Nur aktualisieren, wenn ein gueltiges Value vorliegt
  	  if(defined $value) {
  	    readingsBulkUpdate($hash,$aName,$value);
  	  }

    }
    
    # Alle anderen Readings entfernen
    foreach my $rName (sort keys %{$hash->{READINGS}}) {
    	if(!defined($map->{$rName})) {
        delete $hash->{READINGS}->{$rName};
    	}
    }
     
  }

  readingsEndUpdate($hash,1);	
}

sub SMARTMON_obtainParameters($) {
	my ($hash) = @_;
	SMARTMON_Log($hash, 5, "Obtain parameters");
	my $map;

  # /usr/sbin/smartctl in /etc/sudoers aufnehmen
  # fhem ALL=(ALL) NOPASSWD: [...,] /usr/sbin/smartctl 
  # Natuerlich muss der user auch der Gruppe "sudo" angehören.
  
  # TODO: In Methoden auslagern
  
	# Health	
	my $dev_health = SMARTMON_execute($hash, "sudo smartctl -H ".$hash->{DEVICE}." | grep 'test result:'");
	SMARTMON_Log($hash, 5, "health: $dev_health");
	if($dev_health=~m/test\s+result:\s+(\S+).*/) {
    $map->{"overall_health_test"} = $1;
  } else {
  	delete $map->{"overall_health_test"};
  }
  
  $map = getSmartDataReadings($hash, $map);
  
  return $map;
}

sub getSmartDataReadings($$) {
  my ($hash, $map) = @_;
  
  # SMART Data
  
  # smartctl 5.41 2011-06-09 r3365 [armv7l-linux-3.4.98-sun7i+] (local build)
  # Copyright (C) 2002-11 by Bruce Allen, http://smartmontools.sourceforge.net
  # 
  # === START OF READ SMART DATA SECTION ===
  # SMART Attributes Data Structure revision number: 16
  # Vendor Specific SMART Attributes with Thresholds:
  # ID# ATTRIBUTE_NAME          FLAG     VALUE WORST THRESH TYPE      UPDATED  WHEN_FAILED RAW_VALUE
  #   1 Raw_Read_Error_Rate     0x002f   200   200   051    Pre-fail  Always       -       0
  #   3 Spin_Up_Time            0x0027   184   183   021    Pre-fail  Always       -       1800
  #   4 Start_Stop_Count        0x0032   100   100   000    Old_age   Always       -       28
  #   5 Reallocated_Sector_Ct   0x0033   200   200   140    Pre-fail  Always       -       0
  #   7 Seek_Error_Rate         0x002e   200   200   000    Old_age   Always       -       0
  #   9 Power_On_Hours          0x0032   096   096   000    Old_age   Always       -       3444
  #  10 Spin_Retry_Count        0x0032   100   253   000    Old_age   Always       -       0
  #  11 Calibration_Retry_Count 0x0032   100   253   000    Old_age   Always       -       0
  #  12 Power_Cycle_Count       0x0032   100   100   000    Old_age   Always       -       28
  # 192 Power-Off_Retract_Count 0x0032   200   200   000    Old_age   Always       -       20
  # 193 Load_Cycle_Count        0x0032   200   200   000    Old_age   Always       -       7
  # 194 Temperature_Celsius     0x0022   103   097   000    Old_age   Always       -       44
  # 196 Reallocated_Event_Count 0x0032   200   200   000    Old_age   Always       -       0
  # 197 Current_Pending_Sector  0x0032   200   200   000    Old_age   Always       -       0
  # 198 Offline_Uncorrectable   0x0030   100   253   000    Old_age   Offline      -       0
  # 199 UDMA_CRC_Error_Count    0x0032   200   200   000    Old_age   Always       -       0
  # 200 Multi_Zone_Error_Rate   0x0008   100   253   000    Old_age   Offline      -       0


  my $dmap = readSmartData($hash);
  foreach my $id (sort keys %{$dmap}) {
  	my $rName = $dmap->{$id}->{name};
  	my $raw   = $dmap->{$id}->{raw};
  	$map->{$rName} = "$raw";
  }
  
	# TODO
	
	return $map;
}

sub readSmartData($) {
	my ($hash) = @_;
	my $map;
	
	my @dev_data = SMARTMON_execute($hash, "sudo smartctl -A ".$hash->{DEVICE});
	SMARTMON_Log($hash, 5, "device data: ".Dumper(@dev_data));
	if(defined($dev_data[0])) {
		while(scalar(@dev_data)>0) {
			shift @dev_data;
			if(scalar(@dev_data)>0 && $dev_data[0]=~m/ID#.*/) {
			  shift @dev_data;
				while(scalar(@dev_data)>0) {
					my ($d_id, $d_attr_name, $d_flag, $d_value, $d_worst, $d_thresh, 
					    $d_type, $d_updated, $d_when_failed, $d_raw_value) 
					    = split(/\s+/, trim($dev_data[0]));
					shift @dev_data;
					
					if(defined($d_attr_name)) {
            #$map->{$d_attr_name} = "Value: $d_value, Worst: $d_worst, Type: $d_type, Raw: $d_raw_value";
            $map->{$d_id}->{name}    = $d_attr_name;
            $map->{$d_id}->{flag}    = $d_flag;
            $map->{$d_id}->{value}   = $d_value;
            $map->{$d_id}->{worst}   = $d_worst;
            $map->{$d_id}->{thresh}  = $d_thresh;
            $map->{$d_id}->{type}    = $d_type;
            $map->{$d_id}->{updated} = $d_updated;
            $map->{$d_id}->{failed}  = $d_when_failed;
            $map->{$d_id}->{raw}     = $d_raw_value;
          }
				}
			}
		}
	}
	
	return $map;
} 

sub SMARTMON_execute($$)
{
	my ($hash, $cmd) = @_;
	
	SMARTMON_Log($hash, 5, "Execute: $cmd");
	
  return qx($cmd);
}


1;

=pod
=begin html

<!-- ================================ -->
<a name="SMARTMON"></a>
<h3>SMARTMON</h3>
<ul>
This module provides ...
  <br><br>
  <b>Define</b>
  <br><br>
    <code>define &lt;name&gt; SMARTMON &lt;device&gt; [interval]</code><br>
    <br>
    
This statement creates a new SMARTMON instance. The parameters ...

  <b>Readings:</b>
  <br><br>
  <ul>
    <li>...<br>
        ...
    </li>
    <br>    
  <br>
  </ul>

  Sample output:<br>
  <ul>
...
  </ul><br>

  <b>Get:</b><br><br>
    <ul>
    <li>...<br>
    ...
    </li>
    <br>
    </ul><br>

  <b>Set:</b><br><br>
    <ul>
    <li>...<br>
       ...
    </li>
    <br>
    </ul><br>

  <b>Attributes:</b><br><br>
    <ul>
    <li>...<br>
    ...<br>
    </li>
    <br>
    </ul><br>

  <b>Examples:</b><br><br>
    <ul>
    <code>
      # Modul-Definition<br>
      define sysmon SMARTMON ...<br>
      ...<br>
      <br>
      # Log<br>
      define FileLog_smartmon FileLog ./log/smartmon-%Y-%m.log smartmon<br>
      attr FileLog_smartmon group SYSTEM<br>
      <br>

    </code>
    </ul>

  </ul>
<!-- ================================ -->

=end html
=begin html_DE

<a name="SMARTMON"></a>
<h3>SMARTMON</h3>
<ul>
  Dieses Modul liefert diverse Informationen ...
  <br><br>
  <b>Define</b>
  <br><br>
    <code>define &lt;name&gt; SMARTMON ...</code><br>
    <br>
    Diese Anweisung erstellt eine neue SMARTMON-Instanz.
    Die Parameter ...<br>
    <br>
    
    </ul>
  <br>

  <b>Readings:</b>
  <br><br>
  <ul>
    <li>...<br>
        ...
    </li>
  <br>
  </ul>

  Beispiel-Ausgabe:<br>
  <ul>
...
  </ul><br>

  <b>Get:</b><br><br>
    <ul>
    <li>...<br>
    ...
    </li>
    <br>
    </ul><br>

  <b>Set:</b><br><br>
    <ul>
    <li>...<br>
    ...
    </li>
    <br>
    </ul><br>

  <b>Attributes:</b><br><br>
    <ul>
    <li>...<br>
    ...
    </li>
    <br>
    </ul><br>

  <b>Beispiele:</b><br><br>
    <ul>
    <code>
      ...
    </code>
    </ul>

  </ul>

=end html_DE
=cut
