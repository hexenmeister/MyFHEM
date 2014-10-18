##############################################
#
# fhem driver for MySensors serial or network gateway (see http://mysensors.org)
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

my %sets = (
  "connect" => [],
  "disconnect" => [],
  "inclusion-mode" => [qw(on off)],
);

my %gets = (
  "version"   => ""
);

my @clients = qw(
  MYSENSORS_NODE
  MYSENSORS_SENSOR
);

sub MYSENSORS_Initialize($) {

  my $hash = shift @_;

  require "$main::attr{global}{modpath}/FHEM/DevIo.pm";

  # Provider
  $hash->{Clients} = join (':',@clients);
  $hash->{ReadyFn} = "MYSENSORS::Ready";
  $hash->{ReadFn}  = "MYSENSORS::Read";

  # Consumer
  $hash->{DefFn}    = "MYSENSORS::Define";
  $hash->{UndefFn}  = "MYSENSORS::Undef";
  $hash->{SetFn}    = "MYSENSORS::Set";
  $hash->{AttrFn}   = "MYSENSORS::Attr";
  $hash->{NotifyFn} = "MYSENSORS::Notify";

  $hash->{AttrList} = 
    "autocreate:1 ".
    "first-sensorid ".
    "stateFormat";
}

package MYSENSORS;

use Exporter ('import');
@EXPORT = ();
@EXPORT_OK = qw(sendClientMessage);
%EXPORT_TAGS = (all => [@EXPORT_OK]);

use strict;
use warnings;

use GPUtils qw(:all);

use Device::MySensors::Constants qw(:all);
use Device::MySensors::Message qw(:all);

BEGIN {GP_Import(qw(
  CommandDefine
  CommandModify
  CommandAttr
  gettimeofday
  readingsSingleUpdate
  DevIo_OpenDev
  DevIo_SimpleWrite
  DevIo_SimpleRead
  DevIo_CloseDev
  RemoveInternalTimer
  InternalTimer
  AttrVal
  Log3
  ))};

my %sensorAttr = (
  ARDUINO_NODE          => [ 'config M' ],
  ARDUINO_REPEATER_NODE => [ 'config M' ],
  TEMP        => ['map_TEMP temperature'],
  HUM         => ['map_HUM humidity'],
  LIGHT       => ['setCommands on:V_LIGHT:1 off:V_LIGHT:0' ],
  DIMMER      => [],
  PRESSURE    => ['map_PRESSURE pressure'],
  FORECAST    => [],
  RAIN        => [],
  RAINRATE    => [],
  WIND        => [],
  GUST        => [],
  DIRECTION   => [],
  UV          => [],
  WEIGHT      => [],
  DISTANCE    => [],
  IMPEDANCE   => [],
  ARMED       => [],
  TRIPPED     => [],
  WATT        => [],
  KWH         => [],
  SCENE_ON    => [],
  SCENE_OFF   => [],
  HEATER      => [],
  HEATER_SW   => [],
  LIGHT_LEVEL => ['map_HUM brightness'],
  VAR1        => [],
  VAR2        => [],
  VAR3        => [],
  VAR4        => [],
  VAR5        => [],
  UP          => [],
  DOWN        => [],
  STOP        => [],
  IR_SEND     => [],
  IR_RECEIVE  => [],
  FLOW        => [],
  VOLUME      => [],
  LOCK_STATUS => [],
  DUST_LEVEL	=> [],
  VOLTAGE	    => [],
  CURRENT     => [],
);

sub Define($$) {
  my ( $hash, $def ) = @_;

  $hash->{NOTIFYDEV} = "global";

  if ($main::init_done) {
    return Start($hash);
  } else {
    return undef;
  }
}

sub Undef($) {
  Stop(shift);
}

sub Set($@) {
  my ($hash, @a) = @_;
  return "Need at least one parameters" if(@a < 2);
  return "Unknown argument $a[1], choose one of " . join(" ", map {@{$sets{$_}} ? $_.':'.join ',', @{$sets{$_}} : $_} sort keys %sets)
    if(!defined($sets{$a[1]}));
  my $command = $a[1];
  my $value = $a[2];

  COMMAND_HANDLER: {
    $command eq "connect" and do {
      Start($hash);
      last;
    };
    $command eq "disconnect" and do {
      Stop($hash);
      last;
    };
    $command eq "inclusion-mode" and do {
      sendMessage($hash,radioId => 0, childId => 0, cmd => C_INTERNAL, ack => 0, subType => I_INCLUSION_MODE, payload => $value eq 'on' ? 1 : 0);
      $hash->{'inclusion-mode'} = $value eq 'on' ? 1 : 0;
      last;
    };
  };
}

sub Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $main::defs{$name};
  ATTRIBUTE_HANDLER: {
    $attribute eq "autocreate" and do {
      if ($main::init_done) {
        my $mode = $command eq "set" ? 1 : 0;
        sendMessage($hash,radioId => $hash->{radioId}, childId => $hash->{childId}, ack => 0, subType => I_INCLUSION_MODE, payload => $mode);
        $hash->{'inclusion-mode'} = $mode;
      }
      last;
    };
  }
}

sub Notify($$) {
  my ($hash,$dev) = @_;
  if( grep(m/^(INITIALIZED|REREADCFG)$/, @{$dev->{CHANGED}}) ) {
    Start($hash);
  } elsif( grep(m/^SAVE$/, @{$dev->{CHANGED}}) ) {
  }
}

sub Start($) {
  my $hash = shift;
  my ($dev) = split("[ \t]+", $hash->{DEF});
  $hash->{DeviceName} = $dev;
  CommandAttr(undef, "$hash->{NAME} stateFormat connection") unless AttrVal($hash->{NAME},"stateFormat",undef);
  DevIo_CloseDev($hash);
  return DevIo_OpenDev($hash, 0, "MYSENSORS::Init");
}

sub Stop($) {
  my $hash = shift;
  DevIo_CloseDev($hash);
  RemoveInternalTimer($hash);
  readingsSingleUpdate($hash,"connection","disconnected",1);
}

sub Ready($) {
  my $hash = shift;
  return DevIo_OpenDev($hash, 1, "MYSENSORS::Init") if($hash->{STATE} eq "disconnected");
}

sub Init($) {
  my $hash = shift;
  $hash->{'inclusion-mode'} = AttrVal($hash->{NAME},"autocreate",0);
  readingsSingleUpdate($hash,"connection","connected",1);
  Timer($hash);
  return undef;
}

sub Timer($) {
  my $hash = shift;
  RemoveInternalTimer($hash);
#  InternalTimer(gettimeofday()+$hash->{timeout}, "MYSENSORS::Timer", $hash, 0);
}

sub Read {
  my ($hash) = @_;
  my $name = $hash->{NAME};

  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));

  my $data = $hash->{PARTIAL};
  Log3 ($name, 5, "MYSENSORS/RAW: $data/$buf");
  $data .= $buf;

  while ($data =~ m/\n/) {
    my $txt;
    ($txt,$data) = split("\n", $data, 2);
    $txt =~ s/\r//;
    my $msg = parseMsg($txt);
    Log3 ($name,5,"MYSENSORS Read: ".dumpMsg($msg));

    my $type = $msg->{cmd};
    MESSAGE_TYPE: {
      $type == C_PRESENTATION and do {
        onPresentationMsg($hash,$msg);
        last;
      };
      $type == C_SET and do {
        onSetMsg($hash,$msg);
        last;
      };
      $type == C_REQ and do {
        onRequestMsg($hash,$msg);
        last;
      };
      $type == C_INTERNAL and do {
        onInternalMsg($hash,$msg);
        last;
      };
      $type == C_STREAM and do {
        onStreamMsg($hash,$msg);
        last;
      };
    }
  }
  $hash->{PARTIAL} = $data;
  return undef;
};

sub onPresentationMsg($$) {
  my ($hash,$msg) = @_;
  my $client = matchClient($hash,$msg);
  
  my $sensorType = $msg->{subType};
  sensorTypeToStr($sensorType) =~ /^S_(.+)$/;
  my $sensorTypeStr = $1;
  my $module = ($sensorType == S_ARDUINO_NODE or $sensorType == S_ARDUINO_REPEATER_NODE) ? 'MYSENSORS_NODE' : 'MYSENSORS_SENSOR';
  if ($client) {
    if ($client->{sensorType} != $sensorType) {
      if ($hash->{'inclusion-mode'}) {
        CommandModify(undef,"$client->{NAME} $module $sensorTypeStr $msg->{radioId} $msg->{childId}");
        readingsSingleUpdate($client,"state","TYPE changed after presentation received for different sensorType $sensorTypeStr",1);
      } else {
        Log3($hash->{NAME},3,"MYSENSORS: ignoring presentation-msg different type $sensorType for $client->{NAME} radioId $msg->{radioId}, childId $msg->{childId}, type $client->{sensorType}");
        readingsSingleUpdate($client,"state","presentation received for different sensorType $sensorTypeStr",1);
      }
    } else {
      readingsSingleUpdate($client,"state","presentation received ok",1)
    }
  } else {
    if ($hash->{'inclusion-mode'}) {
      my $clientname = "MY_$sensorTypeStr\_$msg->{radioId}_$msg->{childId}";
      CommandDefine(undef,"$clientname $module $sensorTypeStr $msg->{radioId} $msg->{childId}");
      readingsSingleUpdate($main::defs{$clientname},"state","defined after presentation received ok",1);
      if ($sensorAttr{$sensorTypeStr}) {
        foreach my $attr (@{$sensorAttr{$sensorTypeStr}}) {
          CommandAttr(undef,"$clientname $attr");
        }
      }
    } else {
      Log3($hash->{NAME},3,"MYSENSORS: ignoring presentation-msg from unknown radioId $msg->{radioId}, childId $msg->{childId}, sensorType $sensorType");
    }
  }
};

sub onSetMsg($$) {
  my ($hash,$msg) = @_;
  if (my $client = matchClient($hash,$msg)) {
    if ($client->{TYPE} eq 'MYSENSORS_NODE') {
      MYSENSORS::NODE::onSetMessage($client,$msg);
    } else {
      MYSENSORS::SENSOR::onSetMessage($client,$msg);
    }
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring set-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".variableTypeToStr($msg->{subType}));
  }
};

sub onRequestMsg($$) {
  my ($hash,$msg) = @_;
  if (my $client = matchClient($hash,$msg)) {
    if ($client->{TYPE} eq 'MYSENSORS_NODE') {
      MYSENSORS::NODE::onRequestMessage($client,$msg);
    } else {
      MYSENSORS::SENSOR::onRequestMessage($client,$msg);
    }
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring req-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".variableTypeToStr($msg->{subType}));
  }
};

sub onInternalMsg($$) {
  my ($hash,$msg) = @_;
  my $address = $msg->{radioId};
  my $type = $msg->{subType};
  if ($address == 0 or $address == 255) { #msg to or from gateway
    TYPE: {
      $type == I_INCLUSION_MODE and do {
        if (AttrVal($hash->{NAME},"autocreate",0)) { #if autocreate is switched on, keep gateways inclusion-mode active
          if ($msg->{payload} == 0) {
            sendMessage($hash,radioId => $msg->{radioId}, childId => $msg->{childId}, ack => 0, subType => I_INCLUSION_MODE, payload => 1);
          }
        } else {
          $hash->{'inclusion-mode'} = $msg->{payload};
        }
        last;
      };
      $type == I_STARTUP_COMPLETE and do {
        readingsSingleUpdate($hash,'connection','startup complete',1);
        last;
      };
      $type == I_LOG_MESSAGE and do {
        Log3($hash->{NAME},5,"MYSENSORS gateway $hash->{NAME}: $msg->{payload}");
        last;
      };
      $type == I_ID_REQUEST and do {
        my %nodes = map {$_ => 1} (AttrVal($hash->{NAME},"first-sensorid",20) ... 254);
        GP_ForallClients($hash,sub {
          my $client = shift;
          delete $nodes{$client->{radioId}};
        });
        if (keys %nodes) {
          my $newid = (keys %nodes)[0];
          sendMessage($hash,radioId => 255, childId => 255, cmd => C_INTERNAL, ack => 0, subType => I_ID_RESPONSE, payload => $newid);
          Log3($hash->{NAME},4,"MYSENSORS $hash->{NAME} assigned new nodeid $newid");
        } else {
          Log3($hash->{NAME},4,"MYSENSORS $hash->{NAME} cannot assign new nodeid");
        }
        last;
      };
    }
  } elsif (my $client = matchClient($hash,$msg)) {
    MYSENSORS::NODE::onInternalMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring internal-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".internalMessageTypeToStr($msg->{subType}));
  }
};

sub onStreamMsg($$) {
  my ($hash,$msg) = @_;
};

sub sendMessage($%) {
  my ($hash,%msg) = @_;
  my $txt = createMsg(%msg);
  Log3 ($hash->{NAME},5,"MYSENSORS send: ".dumpMsg(\%msg));
  DevIo_SimpleWrite($hash,"$txt\n", undef);
};

sub matchClient($$) {
  my ($hash,$msg) = @_;
  my $radioId = $msg->{radioId};
  my $childId = $msg->{childId};
  my $found;
  GP_ForallClients($hash,sub {
    return if $found;
    my $client = shift;
    if ($client->{radioId} == $radioId and $client->{childId} == $childId) {
      $found = $client;
    }
  });
  return $found;
}

sub sendClientMessage($%) {
  my ($client,%msg) = @_;
  $msg{radioId} = $client->{radioId};
  $msg{childId} = $client->{childId};
  $msg{ack} = 0;
  sendMessage($client->{IODev},%msg);
}

1;

=pod
=begin html

<a name="MYSENSORS"></a>
<h3>MYSENSORS</h3>
<ul>
  <p>connects fhem to <a href="http://MYSENSORS.org">MYSENSORS</a>.</p>
  <p>A single MYSENSORS device can serve multiple <a href="#MYSENSORS_NODE">MYSENSORS_NODE</a> and <a href="#MYSENSORS_SENSOR">MYSENSORS_SENSOR</a> clients.<br/>
     Each <a href="#MYSENSORS_NODE">MYSENSORS_NODE</a> represents a mysensors node.<br/>
     Each <a href="#MYSENSORS_SENSOR">MYSENSORS_SENSOR</a> represents a sensor attached to a mysensors node.<br/>
  <a name="MYSENSORSdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MYSENSORS &lt;serial device&gt|&lt;ip:port&gt;</code></p>
    <p>Specifies the MYSENSORS device.</p>
  </ul>
  <a name="MYSENSORSset"></a>
  <p><b>Set</b></p>
  <ul>
    <li>
      <p><code>set &lt;name&gt; connect</code><br/>
         (re-)connects the MYSENSORS-device to the MYSENSORS-gateway</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; disconnect</code><br/>
         disconnects the MYSENSORS-device from the MYSENSORS-gateway</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; inclusion-mode on|off</code><br/>
         turns the gateways inclusion-mode on or off</p>
    </li>
  </ul>
  <a name="MYSENSORSattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p>autocreate<br/>
         enables auto-creation of MYSENSOR_NODE and MYSENSOR_SENSOR-devices on receival of presentation-messages</p>
    </li>
    <li>
      <p>first-sensorid<br/>
         configures the lowest node-id assigned to a mysensor-node on request (defaults to 20)</p>
    </li>
  </ul>
</ul>

=end html
=cut
