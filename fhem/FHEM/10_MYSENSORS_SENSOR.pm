##############################################
#
# fhem bridge to MySensors (see http://mysensors.org)
#
# Copyright (C) 2014 Norbert Truchsess
#
#     This file is part of fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with fhem.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id$
#
##############################################

use strict;
use warnings;

my %gets = (
  "version"   => "",
);

sub MYSENSORS_SENSOR_Initialize($) {

  my $hash = shift @_;

  # Consumer
  $hash->{DefFn}    = "MYSENSORS::SENSOR::Define";
  $hash->{UndefFn}  = "MYSENSORS::SENSOR::UnDefine";
  $hash->{SetFn}    = "MYSENSORS::SENSOR::Set";
  $hash->{AttrFn}   = "MYSENSORS::SENSOR::Attr";
  
  $hash->{AttrList} =
    "IODev ".
    "setCommands ".
    "set_.* ".
    "map_.* ".
    $main::readingFnAttributes;

  main::LoadModule("MYSENSORS");
}

package MYSENSORS::SENSOR;

use strict;
use warnings;
use GPUtils qw(:all);

use Device::MySensors::Constants qw(:all);
use Device::MySensors::Message qw(:all);

BEGIN {
  MYSENSORS->import(qw(:all));

  GP_Import(qw(
    CommandDeleteReading
    readingsSingleUpdate
    AssignIoPort
    Log3
  ))
};

sub Define($$) {
  my ( $hash, $def ) = @_;
  my ($name, $type, $sensorType, $radioId, $childId) = split("[ \t]+", $def);
  return "requires 3 parameters" unless (defined $childId and $childId ne "");
  return "unknown sensor type $sensorType, must be one of ".join(" ",map { $_ =~ /^S_(.+)$/; $1 } (sensorTypes)) unless grep { $_ eq "S_$sensorType"} (sensorTypes);
  $hash->{sensorType} = sensorTypeToIdx("S_$sensorType");
  $hash->{radioId} = $radioId;
  $hash->{childId} = $childId;
  $hash->{sets} = {};
  $hash->{mappings} = {};
  $hash->{setcommands} = {};
  AssignIoPort($hash);
};

sub UnDefine($) {
  my ($hash) = @_;
}

sub Set($$$@) {
  my ($hash,$name,$command,@values) = @_;
  return "Need at least one parameters" unless defined $command;
  return "Unknown argument $command, choose one of " . join(" ", map {$hash->{sets}->{$_} eq "" ? $_ : "$_:".$hash->{sets}->{$_}} sort keys %{$hash->{sets}})
    if(!defined($hash->{sets}->{$command}));
  if (@values) {
    my $value = join " ",@values;
    sendClientMessage($hash, cmd => C_SET, subType => variableTypeToIdx($command), payload => $value);
    readingsSingleUpdate($hash,mapReadings($hash,$command),$value,1);
  } else {
    if (defined (my $setcommand = $hash->{setcommands}->{$command})) {
      sendClientMessage($hash, cmd => C_SET, subType => variableTypeToIdx($setcommand->{var}), payload => $setcommand->{val});
      readingsSingleUpdate($hash,"state",mapReadings($hash,$command),1);
    } else {
      return "$command not defined by attr setCommands";
    }
  }
  return undef;
}

sub Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $main::defs{$name};
  ATTRIBUTE_HANDLER: {
    $attribute eq "setCommands" and do {
      if ($command eq "set") {
        foreach my $setCmd (split ("[, \t]+",$value)) {
          my ($set,$var,$val) = split (":",$setCmd);
          $hash->{sets}->{$set}="";
          $hash->{setcommands}->{$set} = {
            var => $var,
            val => $val,
          };
        }
      } else {
        foreach my $set (keys %{$hash->{setcommands}}) {
          delete $hash->{sets}->{$set};
        }
        $hash->{setcommands} = {};
      }
      last;
    };
    $attribute =~ /^set_(.+)/ and do {
      if ($command eq "set") {
        $hash->{sets}->{$1}=join(",",split ("[, \t]+",$value));
      } else {
        CommandDeleteReading(undef,"$hash->{NAME} $1");
        delete $hash->{sets}->{$1};
      }
      last;
    };
    $attribute =~ /^map_(.+)/ and do {
      if ($command eq "set") {
        $hash->{mappings}->{$1}=join(",",split ("[, \t]+",$value));
      } else {
        CommandDeleteReading(undef,"$hash->{NAME} $1");
        delete $hash->{mappings}->{$1};
      }
      last;
    };
  }
}

sub onSetMessage($$) {
  my ($hash,$msg) = @_;
  variableTypeToStr($msg->{subType}) =~ /^V_(.+)$/;
  readingsSingleUpdate($hash,mapReadings($hash,$1),$msg->{payload},1);
}

sub onRequestMessage($$) {
  my ($hash,$msg) = @_;
  variableTypeToStr($msg->{subType}) =~ /^V_(.+)$/;
  sendClientMessage($hash,
    radioId => $hash->{radioId},
    childId => $hash->{childId},
    cmd => C_SET, 
    subType => $msg->{subType},
    payload => ReadingsVal($hash->{NAME},$1,""),
  );
}

sub onInternalMessage($$) {
  my ($hash,$msg) = @_;
  $hash->{internalMessageTypeToStr($msg->{subType})} = $msg->{payload};
}

sub mapReadings($$) {
	my($hash, $rName) = @_;
	
	if(defined($hash->{mappings}->{$rName})) {
		return $hash->{mappings}->{$rName};
	}
	
	return $rName;
}

1;

=pod
=begin html

<a name="MYSENSORS_SENSOR"></a>
<h3>MYSENSORS_SENSOR</h3>
<ul>
  <p>represents a mysensors sensor attached to a mysensor-node</p>
  <p>requires a <a href="#MYSENSOR">MYSENSOR</a>-device as IODev</p>
  <a name="MYSENSORS_SENSORdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MYSENSORS_SENSOR &lt;Sensor-type&gt; &lt;node-id&gt; &lt;sensor-id&gt;</code><br/>
      Specifies the MYSENSOR_SENSOR device.
      Sensor-type is on of
      <li>DOOR</li>
      <li>MOTION</li>
      <li>SMOKE</li>
      <li>LIGHT</li>
      <li>DIMMER</li>
      <li>COVER</li>
      <li>TEMP</li>
      <li>HUM</li>
      <li>BARO</li>
      <li>WIND</li>
      <li>RAIN</li>
      <li>UV</li>
      <li>WEIGHT</li>
      <li>POWER</li>
      <li>HEATER</li>
      <li>DISTANCE</li>
      <li>LIGHT_LEVEL</li>
      <li>LOCK</li>
      <li>IR</li>
      <li>WATER</li>
      <li>AIR_QUALITY</li></p>
  </ul>
  <a name="MYSENSORS_SENSORset"></a>
  <p><b>Set</b></p>
  <ul>
    <li>
      <p><code>set &lt;name&gt; &lt;command&gt;</code><br/>
         sets reading 'state' and sends C_SET-messages to the sensor as configured by attribute 'setCommands'</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; &lt;h;reading&gt; &lt;value&gt;</code><br/>
         sets reading &lt;reading&gt; and sends C_SET-messages to the sensor as configured by attribute 'set_&lt;reading&gt;</p>
    </li>
  </ul>
  <a name="MYSENSORS_SENSORattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p><code>attr &lt;name&gt; setCommands [&lt;commands&gt;]</code><br/>
         configures set commands that may be used to both set reading 'state' and send C_SET-messages to the sensor<br/>
         format of command is 'command:variable:value'.<br/>
         E.g.: <code>attr xxx setCommands on:V_LIGHT:1 off:V_LIGHT_0'</code></p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; set_&lt;reading&gt; [&lt;values&gt;]</code><br/>
         configures reading that may be used to both set 'reading' and send C_SET-messages to the sensors<br/>
         E.g.: <code>attr xxx set_V_LIGHT 0 1</code></p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; map_&lt;reading&gt; [&lt;new reading name&gt;]</code><br/>
         configures reading user names that should be used instead of technical names<br/>
         E.g.: <code>attr xxx map_TEMP temperature</code></p>
    </li>
  </ul>
</ul>

=end html
=cut
