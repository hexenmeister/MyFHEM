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
  "connect" => "",
  "disconnect" => "",
);

my %gets = (
  "version"   => ""
);

my @clients = qw(
  MYSENSORS_NODE
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
  $hash->{NotifyFn} = "MYSENSORS::Notify";

  $hash->{AttrList} = 
    "keep-alive ".
    "autocreate";
}

package MYSENSORS;

use Exporter ('import');
@EXPORT = ();
@EXPORT_OK = qw(sendMessage);
%EXPORT_TAGS = (all => [@EXPORT_OK]);

use strict;
use warnings;

use GPUtils qw(:all);

use Device::MySensors::Constants qw(:all);
use Device::MySensors::Message qw(:all);

BEGIN {GP_Import(qw(
  CommandDefine
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
  return "Unknown argument $a[1], choose one of " . join(" ", sort keys %sets)
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
  };
}

sub Notify($$) {
  my ($hash,$dev) = @_;
  if( grep(m/^(INITIALIZED|REREADCFG)$/, @{$dev->{CHANGED}}) ) {
    Start($hash);
  } elsif( grep(m/^SAVE$/, @{$dev->{CHANGED}}) ) {
  }
}

sub Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $main::defs{$name};
  ATTRIBUTE_HANDLER: {
    $attribute eq "keep-alive" and do {
      if ($command eq "set") {
        $hash->{timeout} = $value;
      } else {
        $hash->{timeout} = 60;
      }
      if ($main::init_done) {
        Timer($hash);
      };
      last;
    };
  };
}

sub Start($) {
  my $hash = shift;
  my ($dev) = split("[ \t]+", $hash->{DEF});
  $hash->{DeviceName} = $dev;
  DevIo_CloseDev($hash);
  return DevIo_OpenDev($hash, 0, "MYSENSORS::Init");
}

sub Stop($) {
  my $hash = shift;
  send_disconnect($hash);
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
    
#  my $msg = { radioId => $fields[0],
#                 childId => $fields[1],
#                 cmd     => $fields[2],
#                 ack     => 0,
##                 ack     => $fields[3],    # ack is not (yet) passed with message
#                 subType => $fields[3],
#                 payload => $fields[4] };

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
      if (AttrVal($hash->{NAME},"autocreate","")) {
        CommandModify(undef,"$client->{NAME} $module $sensorTypeStr $msg->{radioId} $msg->{childId}");
      } else {
        Log3($hash->{NAME},3,"MYSENSORS: ignoring presentation-msg different type $sensorType for $client->{NAME} radioId $msg->{radioId}, childId $msg->{childId}, type $client->{sensorType}");
        readingsSingleUpdate($client,"error","msg different sensorType $sensorType",1);
      }
    }
  } else {
    if (AttrVal($hash->{NAME},"autocreate","")) {
      CommandDefine(undef,"MySensor_$sensorTypeStr\_$msg->{radioId}_$msg->{childId} $module $sensorTypeStr $msg->{radioId} $msg->{childId}");
    } else {
      Log3($hash->{NAME},3,"MYSENSORS: ignoring presentation-msg from unknown radioId $msg->{radioId}, childId $msg->{childId}, sensorType $sensorType");
    }
  }
};

sub onSetMsg($$) {
  my ($hash,$msg) = @_;
  if (my $client = matchClient($hash,$msg)) {
    $client->{'.package'}->onSetMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring set-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".variableTypeToStr($msg->{subType}));
  }
};

sub onRequestMsg($$) {
  my ($hash,$msg) = @_;
  if (my $client = matchClient($hash,$msg)) {
    $client->{'.package'}->onRequestMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring req-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".variableTypeToStr($msg->{subType}));
  }
};

sub onInternalMsg($$) {
  my ($hash,$msg) = @_;
  if (my $client = matchClient($hash,$msg)) {
    MYSENSORS::NODE::onInternalMessage($client,$msg);
  } else {
    Log3($hash->{NAME},3,"MYSENSORS: ignoring internal-msg from unknown radioId $msg->{radioId}, childId $msg->{childId} for ".variableTypeToStr($msg->{subType}));
  }
};

sub onStreamMsg($$) {
  my ($hash,$msg) = @_;
};

sub sendMessage($$) {
  my ($hash,$msg) = @_;
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

1;

=pod
=begin html

<a name="MYSENSORS"></a>
<h3>MYSENSORS</h3>
<ul>
  <p>connects fhem to <a href="http://MYSENSORS.org">MYSENSORS</a>.</p>
  <p>A single MYSENSORS device can serve multiple <a href="#MYSENSORS_DEVICE">MYSENSORS_DEVICE</a> and <a href="#MYSENSORS_BRIDGE">MYSENSORS_BRIDGE</a> clients.<br/>
     Each <a href="#MYSENSORS_DEVICE">MYSENSORS_DEVICE</a> acts as a bridge in between an fhem-device and MYSENSORS.<br/>
     Note: this module is based on module <a href="https://metacpan.org/pod/distribution/Net-MYSENSORS/lib/Net/MYSENSORS.pod">Net::MYSENSORS</a>.</p>
  <a name="MYSENSORSdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MYSENSORS &lt;ip:port&gt;</code></p>
    <p>Specifies the MYSENSORS device.</p>
  </ul>
  <a name="MYSENSORSset"></a>
  <p><b>Set</b></p>
  <ul>
    <li>
      <p><code>set &lt;name&gt; connect</code><br/>
         (re-)connects the MYSENSORS-device to the MYSENSORS-broker</p>
    </li>
    <li>
      <p><code>set &lt;name&gt; disconnect</code><br/>
         disconnects the MYSENSORS-device from the MYSENSORS-broker</p>
    </li>
  </ul>
  <a name="MYSENSORSattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p>keep-alive<br/>
         sets the keep-alive time (in seconds).</p>
    </li>
  </ul>
</ul>

=end html
=cut
