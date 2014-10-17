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
    CommandAttr
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
  $hash->{sets} = {};
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
    readingsSingleUpdate($hash,$command,$value,1);
  } else {
    if (defined (my $setcommand = $hash->{setcommands}->{$command})) {
      sendClientMessage($hash, cmd => C_SET, subType => variableTypeToIdx($setcommand->{var}), payload => $setcommand->{val});
      readingsSingleUpdate($hash,"state",$command,1);
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

1;

=pod
=begin html

<a name="MYSENSORS_NODE"></a>
<h3>MYSENSORS_NODE</h3>
<ul>
  <p>acts as a fhem-device that is mapped to <a href="http://mqtt.org/">mqtt</a>-topics.</p>
  <p>requires a <a href="#MQTT">MQTT</a>-device as IODev<br/>
     Note: this module is based on module <a href="https://metacpan.org/pod/distribution/Net-MQTT/lib/Net/MQTT.pod">Net::MQTT</a>.</p>
  <a name="MYSENSORS_NODEdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MYSENSORS_NODE</code><br/>
       Specifies the MQTT device.</p>
  </ul>
  <a name="MYSENSORS_NODEset"></a>
  <p><b>Set</b></p>
  <ul>
    <li>
      <p><code>set &lt;name&gt; &lt;command&gt;</code><br/>
         sets reading 'state' and publishes the command to topic configured via attr publishSet</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; &lt;h;reading&gt; &lt;value&gt;</code><br/>
         sets reading &lt;h;reading&gt; and publishes the command to topic configured via attr publishSet_&lt;h;reading&gt;</p>
    </li>
  </ul>
  <a name="MYSENSORS_NODEattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p><code>attr &lt;name&gt; publishSet [&lt;commands&gt;] &lt;topic&gt;</code><br/>
         configures set commands that may be used to both set reading 'state' and publish to configured topic</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; publishSet_&lt;reading&gt; [&lt;values&gt;] &lt;topic&gt;</code><br/>
         configures reading that may be used to both set 'reading' (to optionally configured values) and publish to configured topic</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; autoSubscribeReadings &lt;topic&gt;</code><br/>
         specify a mqtt-topic pattern with wildcard (e.c. 'myhouse/kitchen/+') and MYSENSORS_NODE automagically creates readings based on the wildcard-match<br/>
         e.g a message received with topic 'myhouse/kitchen/temperature' would create and update a reading 'temperature'</p>
    </li>
    <li>
      <p><code>attr &lt;name&gt; subscribeReading_&lt;reading&gt; &lt;topic&gt;</code><br/>
         mapps a reading to a specific topic. The reading is updated whenever a message to the configured topic arrives</p>
    </li>
  </ul>
</ul>

=end html
=cut
