#-------------------------------------------------------------------------------
# FHEM-Modul see www.fhem.de
# 36_GSD.pm
# GenericSmartDevice
#
# Usage: define  <Name> GSD <Node-Nr>
#-------------------------------------------------------------------------------
# This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------------------
# Autor: 
# Version: 0.0
# Datum: 
# Kontakt: 
#-------------------------------------------------------------------------------

package main;
use strict;
use warnings;
use POSIX;
use Data::Dumper;
use vars qw(%defs);
use vars qw(%attr);
use vars qw(%data);
use vars qw(%modules);

my $GSD_MAGIC = 83;

#-------------------------------------------------------------------------------
sub GSD_Initialize($)
{
  my ($hash) = @_;

  # Match/Prefix
  my $match = "GSD";
  $hash->{Match}     = "^GSD";
  $hash->{DefFn}     = "GSD_Define";
  $hash->{UndefFn}   = "GSD_Undefine";
  $hash->{ParseFn}   = "GSD_Parse";
  #$hash->{AttrList}  = "do_not_notify:0,1 loglevel:0,5 disable:0,1";
  $hash->{AttrList}  = "disable:0,1";
  #-----------------------------------------------------------------------------
  
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
    
    #my @msg_data = @msg_data[4..($data_len-1)];
    #$data_len = int(@msg_data);
    
    my $dMap;
    $dMap->{INDEX} = 4; # erster Byte der eigentlichen Nachricht
    @{$dMap->{DATA}} = @msg_data; # message data
    my $rMap;
    $dMap->{READINGS} = $rMap; # readings
    
    #my $data_index = 4; # erster Byte der eigentlichen Nachricht
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
           # Function liefert Abbruch
	       Log 0, "GSD: ERROR: parse function failure";
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
    
    $dMap->{INDEX} = $data_end; # $data_index + $msg_len +1; # 1 Byte Type und N Bytes Data
  } else {
    # Definition des Msg-Typs ungueltig
    Log 0, "GSD: ERROR: parse failed. no data length defined";
    return $dMap;
  }
  
  return $dMap; 
}

sub _alt_GSD_Parse($$) {
  my ($iodev, $rawmsg) = @_;
  # $rawmsg = JeeNodeID + SensorType + SensorData
  # rawmsg =  GSD 1 83 1 252 241 15 11 172 8 16 66 19
  Log 3, "GSD PARSE RAW-MSG: " . $rawmsg . " IODEV:" . $iodev->{NAME};
  #
  my @data = split(/\s+/,$rawmsg);
  my $NodeID = $data[1].".".$data[3];
  my $magic = $data[2];
  
  my $SType = $data[4];
  my $data_bytes = $data{JEECONF}{$SType}{DataBytes};
  my $data_end = int(@data) - 1;
  # $array[$#array];
  Log 3, "GSD PARSE N:$NodeID S:$SType B:$data_bytes CNT:" . @data . " END:" . $data_end;
  my @SData = @data[4..$data_end];

	my ($hash,$name);
	if(defined($modules{GSD}{defptr}{$NodeID})) {
		$hash =  $modules{GSD}{defptr}{$NodeID};
		$name = $hash->{NAME};
	}
	else {
	  return "UNDEFINED GSD_$NodeID GSD $NodeID";
	};
	
  my %readings;
  
  # Function-Data --------------------------------------------------------------
  # If defined $data{JEECONF}{<SensorType>}{Function} then the function handels
  # data parsing...return a hash key:reading_name Value:reading_value
  # Param to Function: $iodev,$name,$NodeID, $SType,@SData
  # Function-Data --------------------------------------------------------------
  Log 3, "GSD PARSE F:$NodeID S:$SType >".$data{JEECONF}{$SType}{ReadingName};
  if(defined($data{JEECONF}{$SType}{Function})) {
	my $func = $data{JEECONF}{$SType}{Function};
	if(!defined(&$func)) {
	  Log 0, "GSD PARSE Function not defined: $SType -> $func";
	  return undef;
	}
	no strict "refs";
	%readings = &$func($iodev,$name,$NodeID, $SType,@SData);
	use strict "refs";
  }
  else {
	## Sensor-Data Bytes to Values
	## lowBit HighBit reverse ....
	#@SData = reverse(@SData);
	#my $raw_value = join("",@SData);
	#my $value = "";
	#map {$value .= sprintf "%02x",$_} @SData;
	#$value = hex($value);
	#Log 3, "GSD PARSE DATA $NodeID - $SType - " . join(" " , @SData) . " -> " . $value;
	Log 3, "GSD PARSE DATA $NodeID - $SType - " . join(" " , @SData) ;
    #@SData = GSD_parseDefault($NodeID, %readings, @SData);
    $SType = $SData[0];
	my $reading_name = $data{JEECONF}{$SType}{ReadingName};
	#$readings{$reading_name} = $value;
	#if(defined($data{JEECONF}{$SType}{CorrFactor})) {
	#  my $corr = $data{JEECONF}{$SType}{CorrFactor};
	#  $readings{$reading_name} = $value * $corr;
	#}
  }
  
  # Readings erstellen / updaten
  my $i = 0;
  foreach my $r (sort keys %readings) {
	Log 3, "GSD $name $r:" . $readings{$r};
	$defs{$name}{READINGS}{$r}{VAL} = $readings{$r};
	$defs{$name}{READINGS}{$r}{TIME} = TimeNow();
	#$defs{$name}{STATE} = TimeNow() . " " . $r;
	# Changed for Notify and Logs
	$defs{$name}{CHANGED}[$i] = $r . ": " . $readings{$r};
	$i++;
  }
  return $name;
}

sub _alt_GSD_parseDefault($$$) {
  my ($NodeID, %readings, @sdata) = @_;
  my $type = $sdata[0];
  my $data_bytes = $data{JEECONF}{$type}{DataBytes};
  my $reading_name = $data{JEECONF}{$type}{ReadingName};
  my @sensor_data = @sdata[1..$data_bytes];
  Log 3, "GSD PARSE MSG $NodeID - $type - $data_bytes > $reading_name";
  my $data_end = int(@sdata) - 1;
  @sdata = @sdata[$data_bytes+1..$data_end];
  
  #todo
  @sensor_data = reverse(@sensor_data);
  my $raw_value = join("",@sensor_data);
  my $value = "";
  map {$value .= sprintf "%02x",$_} @sensor_data;
  $value = hex($value);
  Log 3, "GSD PARSE DATA $NodeID - $type - " . join(" " , @sensor_data) . " -> " . $value;
 
  $readings{$reading_name} = $value;
 
	if(defined($data{JEECONF}{$type}{CorrFactor})) {
	  my $corr = $data{JEECONF}{$type}{CorrFactor};
	  $readings{$reading_name} = $value * $corr;
	}
  
  return @sdata;
}

################################################################################
sub GSD_parse_12($$) {
  my ($iodev,$name,$NodeID, $SType,@SData) = @_;
  Log 5, "GSD PARSE-12 DATA $NodeID - $SType - " . join(" " , @SData);
  my %reading;
  $reading{X} = "XXX";
  $reading{Y} = "YYY";
  $reading{Z} = "ZZZ";
  return \%reading;

}
################################################################################
1;
