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

my %sets = (
);

my %gets = (
  "version"   => "",
);

sub MYSENSORS_NODE_Initialize($) {

  my $hash = shift @_;

  # Consumer
  $hash->{DefFn}    = "MYSENSORS::NODE::Define";
  $hash->{UndefFn}  = "MYSENSORS::NODE::UnDefine";
  $hash->{SetFn}    = "MYSENSORS::NODE::Set";
  $hash->{AttrFn}   = "MYSENSORS::NODE::Attr";
  
  $hash->{AttrList} =
    "config:M,I ".
    "IODev ".
    "stateFormat";

  main::LoadModule("MYSENSORS");
}

package MYSENSORS::NODE;

use strict;
use warnings;
use GPUtils qw(:all);

use Device::MySensors::Constants qw(:all);
use Device::MySensors::Message qw(:all);

BEGIN {
  MYSENSORS->import(qw(:all));

  GP_Import(qw(
    AttrVal
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
  if ($hash->{sensorType} == S_ARDUINO_REPEATER_NODE) {
    $hash->{sets} = { 
        'time'  => [],
        'clear' => [],
      };
  } else {
    $hash->{sets} = {
        'time'  => [],
      };
  }
  AssignIoPort($hash);
};

sub UnDefine($) {
  my ($hash) = @_;
}

sub Set($@) {
  my ($hash, @a) = @_;
  return "Need at least one parameters" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", map {@{$hash->{sets}->{$_}} ? $_.':'.join ',', @{$hash->{sets}->{$_}} : $_} sort keys %{$hash->{sets}})
    if(!defined($hash->{sets}->{$a[1]}));
  my $command = $a[1];
  my $value = $a[2];

  COMMAND_HANDLER: {
    $command eq "clear" and do {
      sendClientMessage($hash,cmd => C_INTERNAL, ack => 0, subType => I_CHILDREN, payload => "C");
      last;
    };
    $command eq "time" and do {
      sendClientMessage($hash,cmd => C_INTERNAL, akk => 0, subType => I_TIME, payload => time);
      last;
    }
  }
}

sub Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $main::defs{$name};
  ATTRIBUTE_HANDLER: {
    $attribute eq "config" and do {
      if ($main::init_done) {
        sendClientMessage($hash, cmd => C_INTERNAL, subType => I_CONFIG, payload => $command eq 'set' ? $value : "M");
      }
      last;
    };
  }
}

sub onSetMessage($$) {
  my ($hash,$msg) = @_;
  variableTypeToStr($msg->{subType}) =~ /^V_(.+)$/;
  readingsSingleUpdate($hash,$1,$msg->{payload},1);
}

sub onRequestMessage($$) {
  my ($hash,$msg) = @_;
  variableTypeToStr($msg->{subType}) =~ /^V_(.+)$/;
  sendClientMessage($hash,
    cmd => C_SET, 
    subType => $msg->{subType},
    payload => ReadingsVal($hash->{NAME},$1,"")
  );
}

sub onInternalMessage($$) {
  my ($hash,$msg) = @_;
  my $type = $msg->{subType};
  my $typeStr = internalMessageTypeToStr($type);
  INTERNALMESSAGE: {
    $type == I_BATTERY_LEVEL and do {
      readingsSingleUpdate($hash,"batterylevel",$msg->{payload},1);
      Log3 ($hash->{NAME},4,"MYSENSORS_NODE $hash->{name}: batterylevel $msg->{payload}");
      last;
    };
    $type == I_TIME and do {
      sendClientMessage($hash,cmd => C_INTERNAL, ack => 0, subType => I_TIME, payload => time);
      Log3 ($hash->{NAME},4,"MYSENSORS_NODE $hash->{name}: update of time requested");
      last;
    };
    $type == I_VERSION and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_ID_REQUEST and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_ID_RESPONSE and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_INCLUSION_MODE and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_CONFIG and do {
      sendClientMessage($hash,cmd => C_INTERNAL, ack => 0, subType => I_CONFIG, payload => AttrVal($hash->{NAME},"config","M"));
      Log3 ($hash->{NAME},4,"MYSENSORS_NODE $hash->{name}: respond to config-request");
      last;
    };
    $type == I_PING and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_PING_ACK and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_LOG_MESSAGE and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_CHILDREN and do {
      readingsSingleUpdate($hash,"state","routingtable cleared",1);
      Log3 ($hash->{NAME},4,"MYSENSORS_NODE $hash->{name}: routingtable cleared");
      last;
    };
    $type == I_SKETCH_NAME and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_SKETCH_VERSION and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
    $type == I_REBOOT and do {
      $hash->{$typeStr} = $msg->{payload};
      last;
    };
  }
}

1;

=pod
=begin html

<a name="MYSENSORS_NODE"></a>
<h3>MYSENSORS_NODE</h3>
<ul>
  <p>represents a mysensors sensor attached to a mysensor-node</p>
  <p>requires a <a href="#MYSENSOR">MYSENSOR</a>-device as IODev</p>
  <a name="MYSENSORS_NODEdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MYSENSORS_NODE &lt;Sensor-type&gt; &lt;node-id&gt; &lt;sensor-id&gt;</code><br/>
      Specifies the MYSENSOR_NODE device.
      Sensor-type is on of
      <li>ARDUINO_NODE</li>
      <li>ARDUINO_REPEATER_NODE</li></p>
  </ul>
  <a name="MYSENSORS_NODEattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p><code>attr &lt;name&gt; config [&lt;M|I&gt;]</code><br/>
         configures metric (M) or inch (I). Defaults to 'M'</p>
    </li>
  </ul>
</ul>

=end html
=cut
