###############################################################################
#
# FHEM-Modul (see www.fhem.de)
# 36_GSD.pm
# GenericSmartDevice: sensor data receiver
#
# Usage: define  <Name> GSD <Node-Nr>
#   Example: define GSD_1.1 GSD 1.1
#   (or use autocreate)
#
###############################################################################
#
#  Copyright notice
#
#  (c) 2013 Alexander Schulz
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
###############################################################################

# $Id$

package main;
use strict;
use warnings;
use POSIX;
use Data::Dumper;
use vars qw(%defs);
use vars qw(%attr);
use vars qw(%data);
use vars qw(%modules);

my $GSD_MAGIC = 83; # ErkennungsByte

my $VERSION = "0.1.1";

#------------------------------------------------------------------------------
sub GSD_Initialize($)
{
  my ($hash) = @_;

  # Match/Prefix
  my $match = "GSD";
  $hash->{Match}     = "^GSD";
  $hash->{DefFn}     = "GSD_Define";
  $hash->{UndefFn}   = "GSD_Undefine";
  $hash->{ParseFn}   = "GSD_Parse";
  
  $hash->{GetFn}    = "GSD_Get";
  $hash->{SetFn}    = "GSD_Set";
  $hash->{AttrFn}   = "GSD_Attr";
  
  $hash->{AttrList}  = "disable:0,1".
                       $readingFnAttributes;
  #----------------------------------------------------------------------------
  
  # Arduino/JeeNodes-Variables:
  # http://arduino.cc/en/Reference/HomePage
  # Integer = 2 Bytes -> form -32,768 to 32,767
  # Long (unsigned) = 4 Bytes -> from 0 to 4,294,967,295
  # Long (signed) = 4 Bytes -> from -2,147,483,648 to 2,147,483,647
  #
# Proposal: 
# Typ-Byte-Aufbau: [xxx][xxxxx] => 3Bit sID, 5Bit SensorTyp. 
#                  Damit sind 32 Sensorarte möglich, mit bis zu 6 gleichartigen Stück 
#                  (ohne dass die Reihenfolge eingehalten werden muss.
#                  Teilübertragungen möglich).
#                  sID 7 (0b111) - reserviert:
#                  Dabei wird die Anzahl aus dem nächsten Byte genommen.
#                  Bedeutet bis zu 256 gleichartigen Sensoren, 
#                  jedoch längere Funknachtricht.
#                  sID 6 (0b110) - reserviert:
#                  Nächster Byte enthält Anzahl (sID) und dieSensor-spezifische 
#                  Anweisungen (z.B. Formatanweisungen , Arten etc.)
#  Sensoren:
#  Temperatur, Luftfeuchte, Textnachrichten, Spannung, LowBat-Warnung, Distance,
#  Licht, Bewegung, Luftdruck, Strommessung, 
#
# IDs:
#   0 - [reserved]
#   1 - [reserved]
#   2 - [reserved]
#   3 - [reserved]
#   4 - [reserved]
#   5 - temperature
#   6 - humidity
#   7 - brightness
#   8 - pressure
#   9 - motion
#  10 - distance
#  11 - angle
#  12 - current
#  13 - voltage
#  14 - 
#  15 - 
#  16 - [reserved]
#  17 - [reserved]
#  18 - [reserved]
#  19 - [reserved]
#  20 - [reserved]
#  21 - [reserved] [e] expanding 5 (temperature)
#  22 - [reserved] [e] expanding 6 (humidity)
#  23 - 
#  24 - 
#  25 - power supply
#  26 - low bat mark
#  27 - timemillis
#  28 - rtiple_axis
#  29 - counter
#  30 - raw data
#  31 - text message
# 
  # JeeConf
  # $data{JEECONF}{<SensorType>}{ReadingName}
  # $data{JEECONF}{<SensorType>}{DataBytes}
  # $data{JEECONF}{<SensorType>}{Prefix}     => Wozu?
  # $data{JEECONF}{<SensorType>}{CorrFactor} => Multiplikator
  # $data{JEECONF}{<SensorType>}{Offset}
  # $data{JEECONF}{<SensorType>}{Function}
  # <SensorType>: 0-9 -> Reserved/not Used
  # <SensorType>: 10-99 -> Default
  # <SensorType>: 100-199 -> Userdifined
  # <SensorType>: 200-255 -> Internal/Test
  # Default-2-Bytes-------------------------------------------------------------
  $data{JEECONF}{12}{ReadingName} = "SensorData";
  $data{JEECONF}{12}{DataBytes} = 2;
  $data{JEECONF}{12}{Prefix} = $match;
  # Temperature ----------------------------------------------------------------
  $data{JEECONF}{11}{ReadingName} = "temperature";
  $data{JEECONF}{11}{DataBytes} = 2;
  $data{JEECONF}{11}{Prefix} = $match;
  $data{JEECONF}{11}{CorrFactor} = 0.01;
  # Brightness- ----------------------------------------------------------------
  $data{JEECONF}{12}{ReadingName} = "brightness";
  $data{JEECONF}{12}{DataBytes} = 4;
  $data{JEECONF}{12}{Prefix} = $match;
  # Triple-Axis-X-Y-Z----------------------------------------------------------
  $data{JEECONF}{13}{ReadingName} = "rtiple_axis";
  $data{JEECONF}{13}{Function} = "GSD_parse_12";
  $data{JEECONF}{13}{DataBytes} = 12;
  $data{JEECONF}{13}{Prefix} = $match;
  #-----------------------------------------------------------------------------
  # 14 Used by 18_JME
  # Counter --------------------------------------------------------------------
  # $data{JEECONF}{14}{ReadingName} = "counter";
  # $data{JEECONF}{14}{DataBytes} = 4;
  # $data{JEECONF}{14}{Prefix} = $match;
  # Pressure -------------------------------------------------------------------
  $data{JEECONF}{15}{ReadingName} = "pressure";
  $data{JEECONF}{15}{DataBytes} = 4;
  $data{JEECONF}{15}{CorrFactor} = 0.01;
  $data{JEECONF}{15}{Prefix} = $match;
  # Humidity -------------------------------------------------------------------
  $data{JEECONF}{16}{ReadingName} = "humidity";
  $data{JEECONF}{16}{DataBytes} = 2;
  $data{JEECONF}{16}{CorrFactor} = 0.01;
  $data{JEECONF}{16}{Prefix} = $match;
  # Light LDR ------------------------------------------------------------------
  $data{JEECONF}{17}{ReadingName} = "light_ldr";
  $data{JEECONF}{17}{DataBytes} = 1;
  $data{JEECONF}{17}{Prefix} = $match;
  # Motion ---------------------------------------------------------------------
  $data{JEECONF}{18}{ReadingName} = "motion";
  $data{JEECONF}{18}{DataBytes} = 1;
  $data{JEECONF}{18}{Prefix} = $match;
  # JeeNode InternalTemperatur -------------------------------------------------
  $data{JEECONF}{251}{ReadingName} = "AtmelTemp";
  $data{JEECONF}{251}{DataBytes} = 2;
  $data{JEECONF}{251}{Prefix} = $match;
  # JeeNode InternalRefVolatge -------------------------------------------------
  $data{JEECONF}{252}{ReadingName} = "PowerSupply";
  $data{JEECONF}{252}{DataBytes} = 2;
  $data{JEECONF}{252}{CorrFactor} = 0.001;
  $data{JEECONF}{252}{Prefix} = $match;
  # JeeNode RF12 LowBat --------------------------------------------------------
  $data{JEECONF}{253}{ReadingName} = "RF12LowBat";
  $data{JEECONF}{253}{DataBytes} = 1;
  $data{JEECONF}{253}{Prefix} = $match;
  # JeeNode Milliseconds -------------------------------------------------------
  $data{JEECONF}{254}{ReadingName} = "Millis";
  $data{JEECONF}{254}{DataBytes} = 4;
  $data{JEECONF}{254}{Prefix} = $match;

}

#-------------------------------------------------------------------------------
sub GSD_Define($){
  # define GSD_1.1 GSD 1.1
  my ($hash, $def) = @_;
  my @a = split(/\s+/, $def);
  return "Usage: define <name> GSD NetID.NodeID"  if(int(@a) != 3);
  my $NodeID = $a[2];
  if(defined($modules{GSD}{defptr}{$NodeID})) {
    return "Node $NodeID allready defined";
  }
  $hash->{CODE} = $NodeID;
  $hash->{STATE} = "Initialized: " . TimeNow();
  #$hash->{OrderID} = $NodeID;
  $hash->{NodeID} = $NodeID;
  $modules{GSD}{defptr}{$NodeID}   = $hash;
  return undef;
}

#-------------------------------------------------------------------------------
sub GSD_Undefine($$){
  my ($hash, $name) = @_;
  Log 4, "GSD Undef: " . Dumper(@_);
  my $NodeID = $hash->{NodeID};
  if(defined($modules{GSD}{defptr}{$NodeID})) {
    delete $modules{GSD}{defptr}{$NodeID}
  }
  return undef;
}

#-------------------------------------------------------------------------------
sub GSD_Parse($$) {
  my ($hash, $rawmsg) = @_;
  # rawmsg =  GSD 1 83 1 252 241 15 11 172 8 16 66 19
  Log 3, "GSD: parse RAW message: " . $rawmsg . " IODev: " . $hash->{NAME};
  my @msg_data = split(/\s+/, $rawmsg);
  my $NodeID = $msg_data[1].".".$msg_data[3];
  my $magic = $msg_data[2];
  if($magic eq $GSD_MAGIC) {
    my ($dev_hash,$dev_name);
    if(defined($modules{GSD}{defptr}{$NodeID})) {
      $dev_hash =  $modules{GSD}{defptr}{$NodeID};
      $dev_name = $dev_hash->{NAME};
    } else {
      return "UNDEFINED GSD_$NodeID GSD $NodeID";
    };
  
    my $data_len = int(@msg_data);
    
    my $dMap;
    $dMap->{INDEX} = 4; # erster Byte der eigentlichen Nachricht
    @{$dMap->{DATA}} = @msg_data; # message data
    my $rMap;
    $dMap->{READINGS} = $rMap; # readings
    
    my $index_old = $dMap->{INDEX};
    while ($dMap->{INDEX} < $data_len) {
      #my $msg_data = $dMap->{DATA};
      #my $data_index = $dMap->{INDEX};
      my $msg_type = $msg_data[$dMap->{INDEX}];
      if(defined($data{JEECONF}{$msg_type}{ReadingName})) {
        if(defined($data{JEECONF}{$msg_type}{Function})) {
          my $func = $data{JEECONF}{$msg_type}{Function};
          if(!defined(&$func)) {
            # Function nicht bekannt
            Log 0, "GSD: ERROR: parse function not defined: $msg_type -> $func";
            return undef;
          }
          no strict "refs";
          $dMap = &$func($dMap);
          use strict "refs";
        } else {
          $dMap = GSD_parseDefault($hash, $dMap);
        }
        if (!defined($dMap)) {
          # Function hat Abbruch-Kennzeichen geliefert (es wir alles oder nichts verarbeitet)
          log 0, "GSD: ERROR: parse function failure";
          return undef;
        }
        #$data_index = $dMap->{INDEX};
      } else {
        # Nachricht ungueltig => abbruch
        Log 3, "GSD: ERROR: parse failure. unknown message type: " . $msg_type;
        return undef;
      }
      if($index_old == $dMap->{INDEX}) {
        # Index nicht versetzt, Function falsch / nicht ausgeführt
        Log 0, "GSD: ERROR: parse function failure. index not modified. message type: " . $msg_type;
        return undef;
      }
      $index_old = $dMap->{INDEX};  
    }
    
    # Readings erstellen / updaten
    Log 3, "GSD: update readings for $dev_name";
    my @readings_keys=keys($dMap->{READINGS});
    if(scalar(@readings_keys)>0) {
      readingsBeginUpdate($dev_hash);
      foreach my $reading (sort @readings_keys) {
        my $val = $dMap->{READINGS}->{$reading};
        Log 3, "GSD: update $dev_name $reading: " . $val;
        readingsBulkUpdate($dev_hash, $reading, $val);
      }
      readingsEndUpdate($dev_hash, 1);
    }
  } else {
    # Falsche MagicNumber
    DoTrigger($hash->{NAME}, "UNKNOWNCODE $rawmsg");
    Log3 $hash->{NAME}, 3, "$hash->{NAME}: Unknown code $rawmsg, help me!";
    return undef;
  }
}

#------------------------------------------------------------------------------
sub GSD_parseDefault($$) {
  my ($hash, $dMap) = @_;
  
  #Log 3, "GSD: default parse function. data: " . join(" ",@{$dMap->{DATA}});
  
  my @msg_data = @{$dMap->{DATA}};
  my $data_index = $dMap->{INDEX};
  my $msg_type = @msg_data[$data_index];
  
  Log 3, "GSD: default parse function. index: " . $data_index . " msg type: " . $msg_type;
   
  my $msg_len = $data{JEECONF}{$msg_type}{DataBytes};
  if(defined($msg_len)) {
    my $reading_name = $data{JEECONF}{$msg_type}{ReadingName};
    my $data_end = $data_index+1+$msg_len;
    my @sensor_data = @msg_data[$data_index+1..$data_end-1];
    @sensor_data = reverse(@sensor_data);
    #my $raw_value = join("",@sensor_data);
    my $value = "";
    map {$value .= sprintf "%02x",$_} @sensor_data;
    $value = hex($value);
    Log 3, "GSD: read sensor data: $msg_type : " . join(" " , @sensor_data) . " = " . $value;
    
    if(defined($data{JEECONF}{$msg_type}{CorrFactor})) {
      my $corr = $data{JEECONF}{$msg_type}{CorrFactor};
      $value = $value * $corr;
    }
  if(defined($data{JEECONF}{$msg_type}{Offset})) {
    my $offset = $data{JEECONF}{$msg_type}{Offset};
    $value = $value + $offset;
  }
    $dMap->{READINGS}{$reading_name} = $value;
    
    $dMap->{INDEX} = $data_end; # 1 Byte Type und N Bytes Data
  } else {
    # Definition des Message-Typs ungueltig
    Log 0, "GSD: ERROR: parse failed. no data length defined";
    return undef;
  }
  
  return $dMap; 
}

#------------------------------------------------------------------------------
sub GSD_parseTextMsg($$) {
  my ($hash, $dMap) = @_;
  #TODO
  
  return $dMap;
}

sub
GSD_Get($@)
{
  my ($hash, @a) = @_;

  my $name = $a[0];

  if(@a < 2)
  {
    logF($hash, "Get", "@a: get needs at least one parameter");
    return "$name: get needs at least one parameter";
  }

  my $cmd= $a[1];
  logF($hash, "Get", "@a");

  if($cmd eq "list") {
    my $ret = "";
    foreach my $kname (keys %{$defs{$name}{READINGS}}) {
      my $value = $defs{$name}{READINGS}->{$kname}->{VAL};
      my $time  = $defs{$name}{READINGS}->{$kname}->{TIME};
      $ret = "$ret\n".sprintf("%-20s %-10s (%s)", $kname, $value, $time);
    }
    return $ret;
  }

  if($cmd eq "version")
  {
    return $VERSION;
  }

  return "Unknown argument $cmd, choose one of list:noArg version:noArg";
}

sub
GSD_Set($@)
{
  my ($hash, @a) = @_;

  my $name = $a[0];

  if(@a < 2)
  {
    logF($hash, "Set", "@a: set needs at least one parameter");
    return "$name: set needs at least one parameter";
  }

  my $cmd= $a[1];
  logF($hash, "Set", "@a");

  if($cmd eq "clean") {    
    # alle Readings loeschen
    foreach my $aName (keys %{$defs{$name}{READINGS}}) {
      delete $defs{$name}{READINGS}{$aName};
    }
    return;
  }
  
  if($cmd eq "clear")
  {
    my $subcmd = my $cmd= $a[2];
    if(defined $subcmd) {
      delete $defs{$name}{READINGS}{$subcmd};
      return;
    }
    return "missing parameter. use clear <reading name>";
  }

  return "Unknown argument $cmd, choose one of clean:noArg clear";
}

sub
GSD_Attr($$$)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;

  Log 5, "GSD Attr: $cmd $name $attrName $attrVal";

  $attrVal= "" unless defined($attrVal);
  my $orig = AttrVal($name, $attrName, "");

  if( $cmd eq "set" ) {
    if( $orig ne $attrVal ) {
      my $hash = $main::defs{$name};
      if($attrName eq "disable")
      {
        # TODO
      }

      $attr{$name}{$attrName} = $attrVal;
      return undef;
    }
  }
  return;
}

#------------------------------------------------------------------------------
# Logging: Funkrionsaufrufe
#   Parameter: HASH, Funktionsname, Message
#------------------------------------------------------------------------------
sub logF($$$)
{
	my ($hash, $fname, $msg) = @_;
  #Log 5, "GSD $fname (".$hash->{NAME}."): $msg";
  Log 5, "GSD $fname $msg";
}

1;

=pod
=begin html

<a name="GSD"></a>
<h3>GSD</h3>

TODO: EN

=end html
=begin html_DE
<a name="GSD"></a>
<h3>GSD</h3>

TODO: DE

=end html_DE
=cut
