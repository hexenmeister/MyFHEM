##############################################
#
# fhem bridge to mqtt (see http://mqtt.org)
#
# Copyright (C) 2017 Stephan Eisler
# Copyright (C) 2014 - 2016 Norbert Truchsess
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
# $Id: 10_MQTT_BRIDGE.pm 15150 2017-09-28 20:39:00Z eisler $
#
##############################################

use strict;
use warnings;

my $DEBUG = 1;
my $cvsid = '$Id: $';
my $VERSION = "version 0.2.1 by hexenmeister\n$cvsid";

my %sets = (
);

my %gets = (
  "version"   => "noArg",
  #"readings"  => ""
);

use constant {
  CTRL_ATTR_NAME_DEFAULTS            => "Defaults",
  CTRL_ATTR_NAME_ALIAS               => "Alias",
  CTRL_ATTR_NAME_PUBLISH             => "Publish",
  CTRL_ATTR_NAME_SUBSCRIBE           => "Subscribe",
  CTRL_ATTR_NAME_IGNORE              => "Disable",
  CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE => "globalTypeExclude",
  CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE  => "globalDeviceExclude",
  CTRL_ATTR_NAME_GLOBAL_PREFIX       => "global"
};

sub MQTT_GENERIC_BRIDGE_Initialize($) {

  my $hash = shift @_;

  # Consumer
  $hash->{DefFn}    = "MQTT::GENERIC_BRIDGE::Define";
  $hash->{UndefFn}  = "MQTT::GENERIC_BRIDGE::Undefine";
  $hash->{GetFn}    = "MQTT::GENERIC_BRIDGE::Get";
  $hash->{NotifyFn} = "MQTT::GENERIC_BRIDGE::Notify";
  $hash->{AttrFn}   = "MQTT::GENERIC_BRIDGE::Attr";
  $hash->{OnMessageFn} = "MQTT::GENERIC_BRIDGE::onmessage";

  $hash->{OnClientConnectFn}           = "MQTT::GENERIC_BRIDGE::ioDevConnect";  
  $hash->{OnClientDisconnectFn}        = "MQTT::GENERIC_BRIDGE::ioDevDisconnect";  
  $hash->{OnClientConnectionTimeoutFn} = "MQTT::GENERIC_BRIDGE::ioDevDisconnect";  
  
  $hash->{AttrList} =
    "IODev ".
    CTRL_ATTR_NAME_GLOBAL_PREFIX.CTRL_ATTR_NAME_DEFAULTS." ".
    CTRL_ATTR_NAME_GLOBAL_PREFIX.CTRL_ATTR_NAME_ALIAS." ".
    CTRL_ATTR_NAME_GLOBAL_PREFIX.CTRL_ATTR_NAME_PUBLISH." ".
    #CTRL_ATTR_NAME_GLOBAL_PREFIX.CTRL_ATTR_NAME_SUBSCRIBE." ".
    CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE." ".
    CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE." ".
    #"mqttTopicPrefix ".
    "disable:1,0 ".
    #"qos ".
    #"retain ".
    #"publish-topic-base ".
    #"publishState ".
    #"publishReading_.* ".
    #"subscribeSet ".
    #"subscribeSet_.* ".
    $main::readingFnAttributes;

    main::LoadModule("MQTT");

    # Beim ModulReload Deviceliste loeschen (eig. nur fuer bei der Entwicklung nuetzich)
    if($DEBUG) {
      foreach my $d (keys %defs) {
        if($defs{$d}{TYPE} eq "MQTT_GENERIC_BRIDGE") {
          $defs{$d}{".initialized"} = 0;
        }
      }
    }
}

package MQTT::GENERIC_BRIDGE;

use strict;
use warnings;
use GPUtils qw(:all);

use Net::MQTT::Constants;

if ($DEBUG) {
  use Data::Dumper;
#   $gets{"debugInfo"}="noArg";
#   $gets{"debugReinit"}="noArg";
}

BEGIN {
  MQTT->import(qw(:all));

  GP_Import(qw(
    AttrVal
    CommandAttr
    readingsSingleUpdate
    Log3
    DoSet
    fhem
    defs
    AttrVal
    ReadingsVal
    AssignIoPort
    addToDevAttrList
    devspec2array
    gettimeofday
    InternalTimer
    RemoveInternalTimer
    CTRL_ATTR_NAME_DEFAULTS
    CTRL_ATTR_NAME_ALIAS
    CTRL_ATTR_NAME_PUBLISH
    CTRL_ATTR_NAME_SUBSCRIBE
    CTRL_ATTR_NAME_IGNORE
    CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE
    CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE
    CTRL_ATTR_NAME_GLOBAL_PREFIX
  ))

};

use constant {
  HS_TAB_NAME_DEVICES         => "devices",
  HS_TAB_NAME_SUBSCRIBE       => "subscribeTab", # subscribed topics 
  
  HS_PROP_NAME_PREFIX         => "prefix",
  HS_PROP_NAME_PREFIX_OLD     => "prefix_old",
  HS_PROP_NAME_DEVSPEC        => "devspec",
  HS_FLAG_INITIALIZED         => ".initialized",

  HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE    => "globalTypeExcludes",
  HS_PROP_NAME_GLOBAL_EXCLUDES_READING => "globalReadingExcludes",
  HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES => "globalDeviceExcludes",
  DEFAULT_GLOBAL_TYPE_EXCLUDES     => "MQTT:transmission-state MQTT_DEVICE:transmission-state MQTT_BRIDGE:transmission-state MQTT_GENERIC_BRIDGE "
                                      ."Global telnet FHEMWEB ",
                                      #."CUL HMLAN HMUARTLGW TCM MYSENSORS MilightBridge JeeLink ZWDongle TUL SIGNALDuino *:transmission-state ",
  DEFAULT_GLOBAL_DEV_EXCLUDES     => ""
};

sub publishDeviceUpdate($$$$);
sub UpdateSubscriptionsSingleDevice($$);
sub InitializeDevices($);
sub firstInit($);
sub removeOldUserAttr($;$$);
sub IsObservedAttribute($$);
sub defineGlobalTypeExclude($;$);
sub defineGlobalDevExclude($;$);
sub defineDefaultGlobalExclude($);
sub isTypeDevReadingExcluded($$$$);
sub getDevicePublishRecIntern($$$$$);
sub getDevicePublishRec($$$);
sub isConnected($);
sub ioDevConnect($);
sub ioDevDisconnect($);

# Device define
sub Define() {
  my ( $hash, $def, $prefix, $devspec ) = @_;
  # Definition :=> defmod mqttGeneric MQTT_GENERIC_BRIDGE [prefix] [devspec]

  $prefix="mqtt" unless defined $prefix; # default prefix is 'mqtt'
  $hash->{+HS_PROP_NAME_PREFIX_OLD}=$hash->{+HS_PROP_NAME_PREFIX};
  $hash->{+HS_PROP_NAME_PREFIX}=$prefix; # store in device hash
  $hash->{+HS_PROP_NAME_DEVSPEC} = defined($devspec)?$devspec:".*";

  $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_READING} = {};
  $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE}    = {};
  $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES} = {};

  $hash->{INTERVAL} = 60; # Sekunden

  firstInit($hash);

  return undef;
}

# Device undefine
sub Undefine() {
  my ($hash) = @_;
  RemoveInternalTimer($hash);
  MQTT::client_stop($hash);
  removeOldUserAttr($hash);
}

# Erstinitialization. 
# Variablen werden im HASH abgelegt, userattr der betroffenen Geraete wird erweitert, MQTT-Initialisierungen.
sub firstInit($) {
  my ($hash) = @_;
  if ($main::init_done) {
    # IO
    AssignIoPort($hash);

    $hash->{+HS_FLAG_INITIALIZED} = 0;

    # wenn bereits ein prefix bestand, die userAttr entfernen : HS_PROP_NAME_PREFIX_OLD != HS_PROP_NAME_PREFIX
    my $prefix = $hash->{+HS_PROP_NAME_PREFIX};
    #$hash->{+HS_PROP_NAME_DEVSPEC} = defined($devspec)?$devspec:".*";
    my $devspec = $hash->{+HS_PROP_NAME_DEVSPEC};
    $devspec = 'global' if ($devspec eq '.*'); # use global, if all devices observed
    my $prefix_old = $hash->{+HS_PROP_NAME_PREFIX_OLD};
    if(defined($prefix_old) and ($prefix ne $prefix_old)) {
      removeOldUserAttr($hash, $prefix_old, $devspec);
    }
    my @devices = devspec2array($devspec);
    foreach my $dev (@devices) {
      addToDevAttrList($dev, $prefix.CTRL_ATTR_NAME_DEFAULTS);
      addToDevAttrList($dev, $prefix.CTRL_ATTR_NAME_ALIAS);
      addToDevAttrList($dev, $prefix.CTRL_ATTR_NAME_PUBLISH);
      addToDevAttrList($dev, $prefix.CTRL_ATTR_NAME_SUBSCRIBE);
      addToDevAttrList($dev, $prefix.CTRL_ATTR_NAME_IGNORE.":both,incoming,outgoing");
    }

    # Default-Excludes
    defineDefaultGlobalExclude($hash);

    # ggf. bestehenden subscriptions kuendigen
    RemoveAllSubscripton($hash);
    #$hash->{subscribe} = [];
    #$hash->{subscribeQos} = {};
    #$hash->{subscribeExpr} = [];

    # tabelle aufbauen, Start (subscriptions erstellen, anpassen, loeschen)
    InitializeDevices($hash);
  
    RemoveInternalTimer($hash);
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "MQTT::GENERIC_BRIDGE::timerProc", $hash, 0);

    MQTT::client_start($hash);
  }
}

sub timerProc($) {
  my ($hash, $refresh_all) = @_;
  my $name = $hash->{NAME};

  # TODO: Resend

  RemoveInternalTimer($hash);
  InternalTimer(gettimeofday()+$hash->{INTERVAL}, "MQTT::GENERIC_BRIDGE::timerProc", $hash, 0);
}

# prueft, ob Verbindung zum MQTT-Broker besteht.
# Parameter: Bridge-Hash
sub isConnected($) {
  my $hash = shift;
  return MQTT::isConnected($hash->{IODev});
}

# loescht angelegte userattr aus den jeweiligen Devices (oder aus dem global-Device)
# Parameter: 
#   $hash:    Bridge-hash
#   $prefix:  Attribute (publish, subscribe, defaults und alis) mit diesem Prefix werden entfernt
#   $devspec: definiert Geraete, deren userattr bereinigt werden
# Die letzten zwei Parameter sind optinal, fehlen sie, werden werte aus dem Hash genommen.
sub removeOldUserAttr($;$$) {
  my ($hash, $prefix, $devspec) = @_;
  $prefix = $hash->{+HS_PROP_NAME_PREFIX} unless defined $prefix;
  # Pruefen, on ein weiteres Device (MQTT_GENERIC_BRIDGE) mit dem selben Prefic existiert (waere zwar Quatsch, aber dennoch)
  my @bridges = devspec2array("TYPE=MQTT_GENERIC_BRIDGE");
  my $name = $hash->{NAME};
  foreach my $dev (@bridges) {
    if($dev ne $name) {
      my $aPrefix = $defs{$dev}->{+HS_PROP_NAME_PREFIX};
      return if ($aPrefix eq $prefix);
    }
  }
  $devspec = $hash->{+HS_PROP_NAME_DEVSPEC} unless defined $devspec;
  $devspec = 'global' if ($devspec eq '.*');
  my @devices = devspec2array($devspec);
  foreach my $dev (@devices) {
    my $ua = $main::attr{$dev}{userattr};
    if (defined $ua) {
      my %h = map { ($_ => 1) } split(" ", "$ua");
      delete $h{$prefix.CTRL_ATTR_NAME_DEFAULTS};
      delete $h{$prefix.CTRL_ATTR_NAME_ALIAS};
      delete $h{$prefix.CTRL_ATTR_NAME_PUBLISH};
      delete $h{$prefix.CTRL_ATTR_NAME_SUBSCRIBE};
      delete $h{$prefix.CTRL_ATTR_NAME_IGNORE};
      $main::attr{$dev}{userattr} = join(" ", sort keys %h);
    }
  }
}

# Prueft, ob der gegebene Zeichenkette einem der zu ueberwachenden Device-Attributennamen entspricht.
sub IsObservedAttribute($$) {
  my ($hash, $aname) = @_;
  my $prefix = $hash->{+HS_PROP_NAME_PREFIX};

  if($aname eq $prefix.CTRL_ATTR_NAME_DEFAULTS) {
    return 1;
  }
  if($aname eq $prefix.CTRL_ATTR_NAME_ALIAS) {
    return 1;
  }
  if($aname eq $prefix.CTRL_ATTR_NAME_PUBLISH) {
    return 1;
  }
  if($aname eq $prefix.CTRL_ATTR_NAME_SUBSCRIBE) {
    return 1;
  }
  if($aname eq $prefix.CTRL_ATTR_NAME_IGNORE) {
    return 1;
  }

  return undef;
}

# Internal. Legt Defaultwerte im Map ab. Je nach Schluessel werden die Werte fuer 'pub:', 'sub:' oder beides abgelegt.
# Parameter:
#   $map:     Werte-Map (Ziel)
#   $dev:     Devicename
#   $valMap:  Map mit den Werten (Quelle)
#   $key:     Schluessel. Unter Inhalt aus dem Quellmap unter diesem Schluessel wird in Zielmap kopiert.
sub _takeDefaults($$$$) {
  my ($map, $dev, $valMap, $key) = @_;
  if (defined($valMap->{$key})) {
    # ggf. nicht ueberschreiben (damit nicht undefiniertes VErhalten entsteht,
    # wenn mit und ohne Prefx gleichzeitig angegeben wird. So wird die Definition mit Prefix immer gewinnen)
    $map->{$dev}->{':defaults'}->{'pub:'.$key}=$valMap->{$key} unless defined $map->{$dev}->{':defaults'}->{'pub:'.$key};
    $map->{$dev}->{':defaults'}->{'sub:'.$key}=$valMap->{$key} unless defined $map->{$dev}->{':defaults'}->{'sub:'.$key};
  }
  $map->{$dev}->{':defaults'}->{'pub:'.$key}=$valMap->{'pub:'.$key} if defined($valMap->{'pub:'.$key});
  $map->{$dev}->{':defaults'}->{'sub:'.$key}=$valMap->{'sub:'.$key} if defined($valMap->{'sub:'.$key});
}

sub CreateSingleDeviceTableAttrDefaults($$$$) {
  my($hash, $dev, $map, $attrVal) = @_;
  # collect defaults
  delete ($map->{$dev}->{':defaults'});
  if(defined $attrVal) {
    # format: [pub:|sub:]base=ha/wz/ [pub:|sub:]qos=0 [pub:|sub:]retain=0
    my($unnamed, $named) = main::parseParams($attrVal);
    _takeDefaults($map, $dev, $named, 'base');
    _takeDefaults($map, $dev, $named, 'qos');
    _takeDefaults($map, $dev, $named, 'retain');
    _takeDefaults($map, $dev, $named, 'expression');
    return defined($map->{$dev}->{':defaults'});
  } else {
    return undef;
  }
}

sub CreateSingleDeviceTableAttrAlias($$$$) {
  my($hash, $dev, $map, $attrVal) = @_;
  delete ($map->{$dev}->{':alias'});
  if(defined $attrVal) {
    # format [pub:|sub:]<reading>[=<newName>] ...
    my($unnamed, $named) = main::parseParams($attrVal);
    if(defined($named)){
      foreach my $param (keys %{$named}) {
        my $val = $named->{$param};
        my($pref,$name) = split(":",$param);
        if(defined($name)) {
          if($pref eq 'pub' or $pref eq 'sub') {
            $map->{$dev}->{':alias'}->{$pref.":".$name}=$val;
          }
        } else {
          $name = $pref;
          # ggf. nicht ueberschreiben (damit nicht undefiniertes Verhalten entsteht, 
          # wenn mit und ohne Prefx gleichzeitig angegeben wird. So wird die Definition mit Prefix immer gewinnen)
          $map->{$dev}->{':alias'}->{"pub:".$name}=$val unless defined $map->{$dev}->{':alias'}->{"pub:".$name};
          $map->{$dev}->{':alias'}->{"sub:".$name}=$val unless defined $map->{$dev}->{':alias'}->{"sub:".$name};
        }
      }
      return defined($map->{$dev}->{':alias'});
    }
  }
  return undef;
}

sub CreateSingleDeviceTableAttrPublish($$$$) {
  my($hash, $dev, $map, $attrVal) = @_;
  #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> CreateSingleDeviceTableAttrPublish: $dev, $attrVal, ".Dumper($map));
  # collect publish topics
  delete ($map->{$dev}->{':publish'});
  if(defined $attrVal) {
    # format: 
    #   <reading|alias>:topic=<"static topic"|{evaluated (first time only) topic 
    #     (avialable vars: $base, $reading (oringinal name), $name ($reading oder alias))}>
    #   <reading>:qos=0 <reading>:retain=0 ... 
    #  wildcards:
    #   *:qos=0 *:retain=0 ...
    #   *:topic=<{}> wird jedesmal ausgewertet und ggf. ein passendes Eintrag im Map erzeugt
    #   *:topic=# same as *:topic={"$base/$reading"}
    my($unnamed, $named) = main::parseParams($attrVal);
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> CreateSingleDeviceTableAttrPublish: parseParams: ".Dumper($named));
    if(defined($named)){
      foreach my $param (keys %{$named}) {
        my $val = $named->{$param};
        my($name,$ident) = split(":",$param);
        if(!defined($ident) or !defined($name)) { next; }
        if(($ident eq 'topic') or ($ident eq 'qos') or ($ident eq 'retain') or ($ident eq 'expression')) {
          my @nameParts = split(/\|/, $name);
          while (@nameParts) {
            my $namePart = shift(@nameParts);
            next if($namePart eq "");
            $map->{$dev}->{':publish'}->{$namePart}->{$ident}=$val;
          }
          #$map->{$dev}->{':publish'}->{$name}->{$ident}=$val;
        } #elsif ($ident eq 'qos') {
        #  # Sonderfaelle wie '*:' werden hier einfach abgespeichert und spaeter bei der Suche verwendet
        #  # Gueltige Werte 0, 1 oder 2 (wird nicht geprueft)
        #  $map->{$dev}->{':publish'}->{$name}->{$ident}=$val;
        #} elsif ($ident eq 'retain') {
        #  # Sonderfaelle wie '*:' werden hier einfach abgespeichert und spaeter bei der Suche verwendet
        #  # Gueltige Werte 0 oder 1 (wird nicht geprueft)
        #  $map->{$dev}->{':publish'}->{$name}->{$ident}=$val;
        #}
      }
    }
  }

  return undef;
}

#########################################################################################
# sucht zu den gegebenen device und reading die publish-Eintraege (topic, qos, retain)
# verwendet device-record und beruecksichtigt defaults und globals
# parameter: $hash, device-name, reading-name
sub getDevicePublishRec($$$) {
  my($hash, $dev, $reading) = @_;
  my $map = $hash->{+HS_TAB_NAME_DEVICES};
  return undef unless defined $map;
  
  my $devMap = $map->{$dev};
  my $globalMap = $map->{':global'};

  return getDevicePublishRecIntern($hash, $devMap, $globalMap, $dev, $reading);
}

# sucht zu den gegebenen device und reading die publish-Eintraege (topic, qos, retain) 
# in den uebergebenen Maps
# verwendet device-record und beruecksichtigt defaults und globals
# parameter: $hash, map, globalMap, device-name, reading-name
sub getDevicePublishRecIntern($$$$$) {
  my($hash, $devMap, $globalMap, $dev, $reading) = @_;

  # publish map
  my $publishMap = $devMap->{':publish'};
  my $globalPublishMap = $globalMap->{':publish'};
  #return undef unless defined $publishMap;

  # reading map
  my $readingMap = $publishMap->{$reading} if defined $publishMap;
  my $defaultReadingMap = $publishMap->{'*'} if defined $publishMap;
  
  # global reading map
  my $globalReadingMap = $globalPublishMap->{$reading} if defined $globalPublishMap;
  my $globalDefaultReadingMap = $globalPublishMap->{'*'} if defined $globalPublishMap;

  #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> readingMap ".Dumper($readingMap));
  #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> defaultReadingMap ".Dumper($defaultReadingMap));
  #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> readingMap ".Dumper($globalReadingMap));
  #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> defaultReadingMap ".Dumper($globalDefaultReadingMap));
  # topic
  my $topic = undef;
  $topic = $readingMap->{'topic'} if defined $readingMap;
  $topic = $defaultReadingMap->{'topic'} if (defined($defaultReadingMap) and !defined($topic));

  # global topic
  $topic = $globalReadingMap->{'topic'} if (defined($globalReadingMap) and !defined($topic));
  $topic = $globalDefaultReadingMap->{'topic'} if (defined($globalDefaultReadingMap) and !defined($topic));

  #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> topic ".Dumper($topic));

  return undef unless defined $topic;
  # eval
  if($topic =~ m/^{.*}$/) {
    # $topic evaluieren (avialable vars: $base, $dev (device name), $reading (oringinal name), $name ($reading oder alias, if defined))
    my $name = undef;
    if (defined($devMap) and defined($devMap->{':alias'})) {
      $name = $devMap->{':alias'}->{'pub:'.$reading};
    }
    if (defined($globalMap) and defined($globalMap->{':alias'}) and !defined($name)) {
      $name = $globalMap->{':alias'}->{'pub:'.$reading};
    }
    $name = $reading unless defined $name;

    my $base=undef;
    if (defined($devMap) and defined($devMap->{':defaults'})) {
      $base = $devMap->{':defaults'}->{'pub:base'};
    }
    if (defined($globalMap) and defined($globalMap->{':defaults'}) and !defined($base)) {
      $base = $globalMap->{':defaults'}->{'pub:base'};
    }
    $base='' unless defined $base;
    #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> vor eval: (base, dev, reading, name) $base, $dev, $reading, $name");
    $base = _evalValue($hash->{NAME},$base,$base,$dev,$reading,$name);
    $topic = _evalValue($hash->{NAME},$topic,$base,$dev,$reading,$name);
  }
  return undef unless defined $topic;
  return undef if ($topic eq "");

  # qos & retain
  my $qos=undef;
  my $retain = undef;
  my $expression = undef;

  if(defined $readingMap) {
    $qos =          $readingMap->{'qos'};
    $retain =       $readingMap->{'retain'};
    $expression =   $readingMap->{'expression'};
    if(defined($readingMap->{':defaults'})) {
      $qos =        $readingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain =     $readingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
      $expression = $readingMap->{':defaults'}->{'expression'} unless defined $expression;
    }
  }

  if(defined $defaultReadingMap) {
    $qos =          $defaultReadingMap->{'qos'} unless defined $qos;
    $retain =       $defaultReadingMap->{'retain'} unless defined $retain;
    $expression =   $defaultReadingMap->{'expression'} unless defined $expression;
    if(defined($defaultReadingMap->{':defaults'})) {
      $qos =        $defaultReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain =     $defaultReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
      $expression = $defaultReadingMap->{':defaults'}->{'expression'} unless defined $expression;
    }
  }

  if(defined $globalReadingMap) {
    $qos =          $globalReadingMap->{'qos'};
    $retain =       $globalReadingMap->{'retain'};
    $expression =   $globalReadingMap->{'expression'} unless defined $expression;
    if(defined($globalReadingMap->{':defaults'})) {
      $qos =        $globalReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain =     $globalReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
      $expression = $globalReadingMap->{':defaults'}->{'expression'} unless defined $expression;
    }
  }
  
  if(defined $globalDefaultReadingMap) {
    $qos =          $globalDefaultReadingMap->{'qos'} unless defined $qos;
    $retain =       $globalDefaultReadingMap->{'retain'} unless defined $retain;
    $expression =   $globalDefaultReadingMap->{'expression'} unless defined $expression;
    if(defined($globalDefaultReadingMap->{':defaults'})) {
      $qos =        $globalDefaultReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain =     $globalDefaultReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
      $expression = $globalDefaultReadingMap->{':defaults'}->{'expression'} unless defined $expression;
    }
  }

  $qos = 0 unless defined $qos;
  $retain = 0 unless defined $retain;
  
  return {'topic'=>$topic,'qos'=>$qos,'retain'=>$retain,'expression'=>$expression};
}

sub _evalValue($$$$$$) {
  my($mod, $str, $base, $device, $reading, $name) = @_;
  #Log3('xxx',1,"MQTT-GB:DEBUG:> eval: (str, base, dev, reading, name) $str, $base, $device, $reading, $name");
  my$ret = $str;
  #$base="" unless defined $base;
  if($str =~ m/^{.*}$/) {
    no strict "refs";
    local $@;
    #Log3('xxx',1,"MQTT-GB:DEBUG:> eval !!!");
    $ret = eval($str);
    #Log3('xxx',1,"MQTT-GB:DEBUG:> eval done: $ret");
    if ($@) {
      Log3($mod,2,"user value ('".$str."'') eval error: ".$@);
    }
  }
  return $ret;
}

# sucht zu dem gegebenen (ankommenden) topic das entsprechende device und reading
# Params: $hash, $topic (empfangene topic)
# return: map (device1->{reading}=>reading1, device1->{expression}=>{...}, deviceN->{reading}=>readingM)
sub searchDeviceForTopic($$) {
  my($hash, $topic) = @_;
  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
  my $ret = {};
  my $map = $hash->{+HS_TAB_NAME_DEVICES};
  if(defined ($map)) {
    foreach my $dname (keys %{$map}) {
      my $dmap = $map->{$dname}->{':subscribe'};
      foreach my $rmap (@{$dmap}) {
        my $topicExp = $rmap->{'topicExp'};
        #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> searchDeviceForTopic: expr: ".Dumper($topicExp));
        if (defined($topicExp) and $topic =~ $topicExp) {
          #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> searchDeviceForTopic: match topic: $topic, reading: ".$rmap->{'reading'});
          #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> searchDeviceForTopic: >>>: \$+{name}: ".$+{name}.", \$+{reading}: ".$+{reading});
          # Check named groups: $+{reading},..
          my $reading = undef;
          if($rmap->{'wildcardTarget'}) {
            $reading = $+{name} unless defined $reading;
            # Remap name
            $reading = $+{reading} unless defined $reading;
          }
          $reading = $rmap->{'reading'} unless defined $reading;
          my $tn = $dname.':'.$reading;
          $ret->{$tn}->{'mode'}=$rmap->{'mode'};
          $ret->{$tn}->{'reading'}=$reading;
          my $device = $+{device}; # TODO: Pruefen, ob Device zu verwenden ist => wie?
          $device = $dname unless defined $device;
          $ret->{$tn}->{'device'}=$device;
          $ret->{$tn}->{'expression'}=$rmap->{'expression'};
          #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> searchDeviceForTopic: deliver: ".Dumper($ret));
        }
      }
    }
  }

  return $ret;
}

sub createRegexpForTopic($) {
  my $t = shift;
  $t =~ s|#$|.\*|;
  # Zugriff auf benannte captures: $+{reading}
  $t =~ s|(\$reading)|(\?\<reading\>+)|g;
  $t =~ s|(\$device)|(\?\<device\>+)|g;
  $t =~ s|\$|\\\$|g;
  $t =~ s|\/\.\*$|.\*|;
  $t =~ s|\/|\\\/|g;
  #$t =~ s|(\+)([^+]*$)|(+)$2|;
  $t =~ s|\+|[^\/]+|g;
  return "^$t\$";
}

sub CreateSingleDeviceTableAttrSubscribe($$$$) {
  my($hash, $dev, $map, $attrVal) = @_;
  #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> CreateSingleDeviceTableAttrSubscribe: $dev, $attrVal, ".Dumper($map));
  # collect subscribe topics
  my $devMap = $map->{$dev};
  my $globalMap = $map->{':global'};
  delete ($devMap->{':subscribe'});
  if(defined $attrVal) {
    # format: 
    #   <reading|alias>:topic="asd/asd"
    #   <set-cmd or * for 'state'>:stopic="asd/asd"
    #   <reading>:topic={"$base/$reading"}
    #   <reading>:qos=0
    #   <reading|alias|set-cmd>:expression={...} (vars: $dev, $reading (oringinal name), $name ($reading oder alias), $value (received value), $topic)
    #  wildcards:
    #   *:qos=0 
    #   *:expression={...}
    #   *:topic={"$base/$reading/xyz"} => topic = "$base/+/xyz"
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> CreateSingleDeviceTableAttrSubscribe: attrVal: ".Dumper($attrVal));
    my($unnamed, $named) = MQTT::parseParams($attrVal, undef, undef, '=', undef);
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> CreateSingleDeviceTableAttrSubscribe: parseParams: named ".Dumper($named));
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> CreateSingleDeviceTableAttrSubscribe: parseParams: unnamed ".Dumper($unnamed));
    if(defined($named)){
      my $dmap = {};
      foreach my $param (keys %{$named}) {
        my $val = $named->{$param};
        my($name,$ident) = split(":",$param);
        if(!defined($ident) or !defined($name)) { next; }
        if(($ident eq 'topic') or ($ident eq 'stopic') or ($ident eq 'qos') or ($ident eq 'retain') or ($ident eq 'expression')) {
          my @nameParts = split(/\|/, $name);
          while (@nameParts) {
            my $namePart = shift(@nameParts);
            next if($namePart eq "");
            my $rmap = $dmap->{$namePart};
            $rmap = {} unless defined $rmap;
            $rmap->{'reading'}=$namePart;
            $rmap->{'wildcardTarget'} = $namePart =~ /^\*/;
            #$rmap->{'evalTarget'} = $namePart =~ /^{.+}.*$/;
            $rmap->{'dev'}=$dev;
            $rmap->{$ident}=$val;
            if(($ident eq 'topic') or ($ident eq 'stopic')) { # -> topic
              my $base=undef;
              if (defined($devMap->{':defaults'})) {
                $base = $devMap->{':defaults'}->{'sub:base'};
              }
              if (defined($globalMap) and defined($globalMap->{':defaults'}) and !defined($base)) {
                $base = $globalMap->{':defaults'}->{'sub:base'};
              }
              $base='' unless defined $base;

              $base = _evalValue($hash->{NAME},$base,$base,$dev,'$reading','$name');
              
              $rmap->{'mode'} = 'R';
              $rmap->{'mode'} = 'S' if ($ident eq 'stopic');

              # $base verwenden => eval
              my $topic = _evalValue($hash->{NAME},$val,$base,$dev,'$reading','$name');
              $rmap->{'topicOrig'} = $val;

              #$rmap->{'wildcardDev'}=index($topic, '$device');       
              #$rmap->{'wildcardReading'}=index($topic, '$reading');  
              #$rmap->{'wildcardName'}=index($topic, '$name');        
              
              $rmap->{'topicExp'}=createRegexpForTopic($topic);

              $topic =~ s/\$reading/+/g;
              $topic =~ s/\$name/+/g;
              $topic =~ s/\$device/+/g;
              $rmap->{'topic'} = $topic;
            } # <- topic
            $dmap->{$namePart} = $rmap;
          }
        } 
      }
      #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> >>> CreateSingleDeviceTableAttrSubscribe ".Dumper($dmap));
      my @vals = values %{$dmap};
      $devMap->{':subscribe'}= \@vals;
    }
  }
  return undef;
}

sub CreateSingleDeviceTable($$$$$) {
  my ($hash, $dev, $devMapName, $prefix, $map) = @_;
  # Divece-Attribute fuer ein bestimmtes Device aus Device-Attributen auslesen
  #my $prefix = $hash->{+HS_PROP_NAME_PREFIX};
  CreateSingleDeviceTableAttrDefaults($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_DEFAULTS, undef));
  CreateSingleDeviceTableAttrAlias($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_ALIAS, undef)); 
  CreateSingleDeviceTableAttrPublish($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_PUBLISH, undef));
  CreateSingleDeviceTableAttrSubscribe($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_SUBSCRIBE, undef));
  # Wenn keine Eintraege => Device loeschen
  if(defined($map->{$devMapName})) {
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> >>> ".(keys %{$map->{$dev}})." - ".Dumper($map->{$dev}));
    if(keys %{$map->{$devMapName}} == 0) {
      delete($map->{$devMapName});
    }
  }
}

sub _RefreshDeviceTable($$$$;$$) {
  my ($hash, $dev, $devMapName, $prefix, $attrName, $attrVal) = @_;
  #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> _RefreshDeviceTable: $dev, $devMapName, $prefix, $attrName, $attrVal");
  # Attribute zu dem angegeben Geraet neu erfassen
  my $map = $hash->{+HS_TAB_NAME_DEVICES};
  if(defined($attrName)) {
    # ... entweder fuer bestimmte Attribute ...
    CreateSingleDeviceTableAttrDefaults($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_DEFAULTS);
    CreateSingleDeviceTableAttrAlias($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_ALIAS); 
    CreateSingleDeviceTableAttrPublish($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_PUBLISH);
    CreateSingleDeviceTableAttrSubscribe($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_SUBSCRIBE);
  } else {
    # ... oder gleich fuer alle (dann aus Device Attributes gelesen)
    CreateSingleDeviceTable($hash, $dev, $devMapName, $prefix, $map);
  }
  UpdateSubscriptionsSingleDevice($hash, $dev);
}

sub RefreshDeviceTable($$;$$) {
  my ($hash, $dev, $attrName, $attrVal) = @_;
  my $prefix = $hash->{+HS_PROP_NAME_PREFIX};
  _RefreshDeviceTable($hash, $dev, $dev, $prefix, $attrName, $attrVal);
}

sub RefreshGlobalTable($;$$) {
  my ($hash, $attrName, $attrVal) = @_;
  my $prefix = CTRL_ATTR_NAME_GLOBAL_PREFIX;
  _RefreshDeviceTable($hash, $hash->{NAME}, ":global", $prefix, $attrName, $attrVal);
}

sub RenameDeviceInTable($$$) {
  my($hash, $dev, $devNew) = @_;
  my $map = $hash->{+HS_TAB_NAME_DEVICES};
  if(defined($map->{$dev})) {
    #$map->{$devNew}=$map->{$dev};
    delete($map->{$dev});
    my $prefix = $hash->{+HS_PROP_NAME_PREFIX};
    CreateSingleDeviceTable($hash, $devNew, $devNew, $prefix, $map);
    UpdateSubscriptionsSingleDevice($hash, $devNew);
  }
}

sub DeleteDeviceInTable($$) {
  my($hash, $dev) = @_;
  my $map = $hash->{+HS_TAB_NAME_DEVICES};
  if(defined($map->{$dev})) {
    delete($map->{$dev});
    UpdateSubscriptions($hash);
  }
}

sub CreateDevicesTable($) {
  my ($hash) = @_;
  # alle zu ueberwachende Geraete durchgehen und Attribute erfassen
  my $map={};

  my @devices = devspec2array($hash->{+HS_PROP_NAME_DEVSPEC});
  #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> CreateDevicesTable: ".Dumper(@devices));
  my $prefix = $hash->{+HS_PROP_NAME_PREFIX};
  foreach my $dev (@devices) {
    if($dev ne $hash->{NAME}) {
      Log3($hash->{NAME},5,"MQTT-GB:DEBUG:> CreateDevicesTable for ".$dev);
      CreateSingleDeviceTable($hash, $dev, $dev, $prefix, $map); 
    }
  }

  # crerate global defaults table
  CreateSingleDeviceTable($hash, $hash->{NAME}, ":global", CTRL_ATTR_NAME_GLOBAL_PREFIX, $map);

  $hash->{+HS_TAB_NAME_DEVICES} = $map;
  UpdateSubscriptions($hash);
  $hash->{+HS_FLAG_INITIALIZED} = 1;
}

sub UpdateSubscriptionsSingleDevice($$) {
  my ($hash, $dev) = @_;
  # Liste der Geraete mit der Liste der Subscriptions abgleichen
  # neue Subscriptions bei Bedarf anlegen und/oder ueberfluessige loeschen
  # fuer Einzeldevices vermutlich eher schwer, erstmal komplet updaten
  UpdateSubscriptions($hash);
}

sub UpdateSubscriptions($) {
  my ($hash) = @_;
    #RemoveAllSubscripton($hash);
    #return;
  my $topicMap = {};
  my $gmap = $hash->{+HS_TAB_NAME_DEVICES};
  if(defined($gmap)) {
    foreach my $dname (keys %{$gmap}) {
      my $smap = $gmap->{$dname}->{':subscribe'};
      #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> UpdateSubscriptions: smap = ".Dumper($gmap->{$dname}));
      if(defined($smap)) {
        # foreach my $rname (keys %{$smap}) {
        #   my $topic = $smap->{$rname}->{'topic'};
        #   $topicMap->{$topic}=1 if defined $topic;
        # }
        foreach my $rmap (@{$smap}) {
          my $topic = $rmap->{'topic'};
          #$topicMap->{$topic}=1 if defined $topic;
          $topicMap->{$topic}->{'qos'}=$rmap->{'qos'} if defined $topic;
        }
      }
    }
  }

  unless (%{$topicMap}) {
    RemoveAllSubscripton($hash);
    return;
  }

  my @topics = keys %{$topicMap};
  #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> UpdateSubscriptions: topics = ".Dumper(@topics));
  my @new=();
  my @remove=();
  foreach my $topic (@topics) {
    next if ($topic eq "");
    push @new,$topic unless grep {$_ eq $topic} @{$hash->{subscribe}};
  }
  foreach my $topic (@{$hash->{subscribe}}) {
    next if ($topic eq "");
    push @remove,$topic unless grep {$_ eq $topic} @topics;
  }

  #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> UpdateSubscriptions: remove = ".Dumper(@remove));
  #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> UpdateSubscriptions: new = ".Dumper(@new));

  foreach my $topic (@remove) {
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> UpdateSubscriptions: unsubscribe: topic = ".Dumper($topic));
    client_unsubscribe_topic($hash,$topic);
  }
  foreach my $topic (@new) {
    my $qos = $topicMap->{$topic}->{'qos'};    # TODO: Default lesen
    $qos = 0 unless defined $qos;
    my $retain = 0; # not supported
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> UpdateSubscriptions: subscribe: topic = ".Dumper($topic).", qos = ".Dumper($qos).", retain = ".Dumper($retain));
    client_subscribe_topic($hash,$topic,$qos,$retain);
  }

  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
}

sub RemoveAllSubscripton($) {
  my ($hash) = @_;
  # alle Subscription kuendigen (beim undefine)
  
  if (defined($hash->{subscribe}) and (@{$hash->{subscribe}})) {
    my $msgid = send_unsubscribe($hash->{IODev},
      topics => [@{$hash->{subscribe}}],
    );
    $hash->{message_ids}->{$msgid}++;
  }
  $hash->{subscribe}=[];
  $hash->{subscribeExpr}=[];
  $hash->{subscribeQos}={};
}

sub InitializeDevices($) {
  my ($hash) = @_;
  # alles neu aifbauen
  # Deviceliste neu aufbauen, ggf., alte subscription kuendigen, neue abonieren
  CreateDevicesTable($hash);
  #UpdateSubscriptions($hash);
}

sub CheckInitialization($) {
  my ($hash) = @_;
  # Pruefen, on interne Strukturen initialisiert sind
  return if $hash->{+HS_FLAG_INITIALIZED};
  InitializeDevices($hash);
}

my %getsDebug = (
);
if ($DEBUG) {
  $getsDebug{"debugInfo"}="";
  $getsDebug{"debugReinit"}="";
  $getsDebug{"debugShowPubRec"}="";
}

sub Get($$$@) {
  my ($hash, $name, $command, $args) = @_;
  return "Need at least one parameters" unless (defined $command);
  unless (defined($gets{$command}) or defined($getsDebug{$command})) {
    my $rstr="Unknown argument $command, choose one of";
    foreach my $vname (keys %gets) {
      $rstr.=" $vname";
      my $vval=$gets{$vname};
      $rstr.=":$vval" if $vval;
    }
    if ($DEBUG) {
      $rstr.=" debugInfo:noArg debugReinit:noArg";
      $rstr.=" debugShowPubRec:";
      foreach my $dname (sort keys %{$hash->{+HS_TAB_NAME_DEVICES}}) {
        foreach my $rname (sort keys %{$hash->{+HS_TAB_NAME_DEVICES}->{$dname}->{':publish'}}) {
          $rstr.= $dname.'>'.$rname.',';
        }
        $rstr.= $dname.'>unknownReading,';
      }
      $rstr.= 'unknownDevice>unknownReading';
    }
    return $rstr;
  }
  #return "Unknown argument $command, choose one of " . join(" ", sort keys %gets)
  #  unless (defined($gets{$command}));

  COMMAND_HANDLER: {
    $command eq "debugInfo" and $DEBUG and do {
      my $debugInfo = "initialized: ".$hash->{+HS_FLAG_INITIALIZED}."\n\n";
      $debugInfo.= "device data records: ".Dumper($hash->{+HS_TAB_NAME_DEVICES})."\n\n";
      $debugInfo.= "subscriptionTab: ".Dumper($hash->{+HS_TAB_NAME_SUBSCRIBE})."\n\n";
      $debugInfo.= "subscription helper array: ".Dumper($hash->{subscribe})."\n\n";

      # Exclude tables
      $debugInfo.= "exclude type map: ".Dumper($hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE})."\n\n";
      $debugInfo.= "exclude reading map: ".Dumper($hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_READING})."\n\n";
      $debugInfo.= "exclude device map: ".Dumper($hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES})."\n\n";

      $debugInfo =~ s/</&lt;/g;      
      $debugInfo =~ s/>/&gt;/g;      

      return $debugInfo;
    };
    $command eq "version" and do {
      return $VERSION;
    };
    $command eq "debugReinit" and $DEBUG and do {
      #Log3($hash->{NAME},1,">>>>>>>>>>>>>> : ".Dumper($command));
      InitializeDevices($hash);
      last;
    };
    $command eq "debugShowPubRec" and do {
      my($dev,$reading) = split(/>/,$args);
      return "PubRec: $dev:$reading = ".Dumper(getDevicePublishRec($hash, $dev, $reading));
      last;
    };
    # $command eq "YYY" and do {
    #   #  
    #   last;
    # };
  };
}
sub Notify() {
  my ($hash,$dev) = @_;
  #Log3($hash->{NAME},1,">>>>>>>>>>>>>> : ".Dumper($dev));
  if( $dev->{NAME} eq "global" ) {
    #Log3($hash->{NAME},1,">>>>>>>>>>>>>> : ".Dumper($dev));
    if( grep(m/^(INITIALIZED|REREADCFG)$/, @{$dev->{CHANGED}}) ) {
      firstInit($hash);
    }
    
    my $max = int(@{$dev->{CHANGED}});
    for (my $i = 0; $i < $max; $i++) {
      my $s = $dev->{CHANGED}[$i];
      $s = "" if(!defined($s));
      #Log3($hash->{NAME},1,">>>>>>>>>>>>>> : ".Dumper($s));
      if($s =~ m/^RENAMED ([^ ]*) ([^ ]*)$/) {
        # Device renamed
        my ($old, $new) = ($1, $2);
        #Log3($hash->{NAME},5,"MQTT-GB:DEBUG:> Device renamed: $old => $new");
        # wenn ein ueberwachtes device, tabelle korrigieren
        RenameDeviceInTable($hash, $old, $new);
      } elsif($s =~ m/^DELETED ([^ ]*)$/) {
        # Device deleted
        my ($name) = ($1);
        #Log3($hash->{NAME},5,"MQTT-GB:DEBUG:> Device deleted: $name");
        # wenn ein ueberwachtes device, tabelle korrigieren
        DeleteDeviceInTable($hash, $name);
      } elsif($s =~ m/^ATTR ([^ ]*) ([^ ]*) (.*)$/) {
        # Attribut created or changed
        my ($sdev, $attrName, $val) = ($1, $2, $3);
        #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> attr created/changed: $sdev : $attrName = $val");
        # wenn ein ueberwachtes device und attr bzw. steuer.attr, tabelle korrigieren
        RefreshDeviceTable($hash, $sdev, $attrName, $val) if(IsObservedAttribute($hash,$attrName));
      } elsif($s =~ m/^DELETEATTR ([^ ]*) ([^ ]*)$/) {
        # Attribut deleted
        my ($sdev, $attrName) = ($1, $2);
        #Log3($hash->{NAME},5,"MQTT-GB:DEBUG:> attr deleted: $sdev : $attrName");
        # wenn ein ueberwachtes device und attr bzw. steuer.attr, tabelle korrigieren
        RefreshDeviceTable($hash, $sdev, $attrName, undef) if(IsObservedAttribute($hash,$attrName));
      }
    }
    return undef;
  }

  return if( !$main::init_done );

  return "" if(main::IsDisabled($hash->{NAME}));

  CheckInitialization($hash);

  # Pruefen, ob ein ueberwachtes Geraet vorliegt 
  my $devName = $dev->{NAME}; 
  my $devDataTab = $hash->{+HS_TAB_NAME_DEVICES}; # Geraetetabelle
  return unless defined $devDataTab; # not initialized now or internal error
  my $devDataRecord = $devDataTab->{$devName}; # 
  unless (defined($devDataRecord)) {
    # Pruefen, ob ggf. Default map existiert.
    my $globalDataRecord = $devDataTab->{':global'};
    return "" unless defined $globalDataRecord;
    my $globalPublishMap = $globalDataRecord->{':publish'};
    return "" unless defined $globalPublishMap;
    my $size = int(keys %{$globalPublishMap});
    return "" unless ($size>0);
  }

  Log3($hash->{NAME},5,"Notify for $dev->{NAME}");
  foreach my $event (@{$dev->{CHANGED}}) {
    $event =~ /^([^:]+)(: )?(.*)$/;
    #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> event: $event, '".((defined $1) ? $1 : "-undef-")."', '".((defined $3) ? $3 : "-undef-")."'");
    my $devreading = undef;
    my $devval = undef;
    if (defined $3 and $3 ne "") {
      #send reading=$1 value=$3
      #publishDeviceUpdate($hash, $dev, $1, $3);
      $devreading = $1;
      $devval = $3;
    } else {
      #send reading=state value=$1
      #publishDeviceUpdate($hash, $dev, 'state', $1);
      $devreading = 'state';
      $devval = $1;
    }
    if(defined $devreading and defined $devval) {
      # wenn ueberwachtes device and reading
      publishDeviceUpdate($hash, $dev, $devreading, $devval);
    }
  }
}

# Definiert Liste der auszuschliessenden Type/Readings-Kombinationen.
#   Parameter:
#     $hash: HASH
#     $valueType: Werteliste im Textformat fuer TYPE:readings Excludes (getrennt durch Leerzeichen).
#       Ein einzelner Wert bedeutet, dass ein Geraetetyp mit diesem Namen komplett ignoriert wird (also fuer alle seine Readings).
#       Durch ein Doppelpunkt getrennte Paare werden als Type:Reading interptretiert. 
#       Das Bedeutet, dass an dem gegebenen Type die genannte Reading nicht uebertragen wird.
#       Ein Stern anstatt Type oder auch Reading bedeutet, dass alle Readings eines Geretaetueps 
#       bzw. genannte Readings an jedem Geraetetyp ignoriert werden.
sub defineGlobalTypeExclude($;$) {
  my ($hash, $valueType) = @_;
  #$valueType = AttrVal($hash->{NAME}, CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE, DEFAULT_GLOBAL_TYPE_EXCLUDES) unless defined $valueType;
  $valueType = DEFAULT_GLOBAL_TYPE_EXCLUDES unless defined $valueType;
  $valueType.= ' '.DEFAULT_GLOBAL_TYPE_EXCLUDES if defined $valueType;
  #$main::attr{$hash->{NAME}}{+CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE} = $valueType;
  # HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE und HS_PROP_NAME_GLOBAL_EXCLUDES_READING

  $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_READING} = {};
  $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE} = {};
  my @list = split("[ \t][ \t]*", $valueType);
  foreach (@list) {
    next if($_ eq "");
    my($type, $reading) = split(/:/, $_);
    $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_READING}->{$reading}=1 if (defined($reading) and ($type eq '*'));
    $reading='*' unless defined $reading;
    $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE}->{$type}=$reading if($type ne '*');
  }
}

# Definiert Liste der auszuschliessenden DeviceName/Readings-Kombinationen.
#   Parameter:
#     $hash: HASH
#     $valueName: Werteliste im Textformat fuer DeviceName:reading Excludes (getrennt durch Leerzeichen).
#       Ein einzelner Wert bedeutet, dass ein Geraet mit diesem Namen komplett ignoriert wird (also fuer alle seine Readings).
#       Durch ein Doppelpunkt getrennte Paare werden als DeviceName:Reading interptretiert. 
#       Das Bedeutet, dass an dem gegebenen Geraet die genannte Reading nicht uebertragen wird.
#       Ein Stern anstatt Reading bedeutet, dass alle Readings eines Geraets ignoriert werden.
sub defineGlobalDevExclude($;$) {
  my ($hash, $valueName) = @_;
  #$valueName = AttrVal($hash->{NAME}, CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE, DEFAULT_GLOBAL_DEV_EXCLUDES) unless defined $valueName;
  $valueName = DEFAULT_GLOBAL_DEV_EXCLUDES unless defined $valueName;
  $valueName.= ' '.DEFAULT_GLOBAL_DEV_EXCLUDES if defined $valueName;
  #$main::attr{$hash->{NAME}}{+CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE} = $valueName;
  # HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES

  $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES}={};
  my @list = split("[ \t][ \t]*", $valueName);
  foreach (@list) {
    next if($_ eq "");
    my($dev, $reading) = split(/:/, $_);
    $reading='*' unless defined $reading;
    $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES}->{$dev}=$reading if($dev ne '*');
  }
}

# Setzt Liste der auszuschliessenden Type/Readings-Kombinationenb auf Defaultwerte zurueck (also falls Attribut nicht definiert ist).
sub defineDefaultGlobalExclude($) {
  my ($hash) = @_;  
  defineGlobalTypeExclude($hash, undef);
  defineGlobalDevExclude($hash, undef);
}

# Prueft, ob Type/Reading- oder Geraete/Reading-Kombination von der Uebertragung ausgeschlossen werden soll, 
# oder im Geraet Ignore-Attribut gesetzt ist.
#   Parameter:
#     $hash:    HASH
#     $type:    Geraetetyp
#     $devName: Geraetename
#     $reading: Reading
sub isTypeDevReadingExcluded($$$$) {
  my ($hash, $type, $devName, $reading) = @_;

  # pruefen, ob im Geraet ignore steht
  my $devDisable = $main::attr{$devName}{$hash->{+HS_PROP_NAME_PREFIX}.CTRL_ATTR_NAME_IGNORE};
  $devDisable = '0' unless defined $devDisable;
  return 1 if(($devDisable eq 'both') or ($devDisable eq 'outgoing'));

  # Exclude tables
  my $gExcludesTypeMap = $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE};
  my $gExcludesReadingMap = $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_READING};
  my $gExcludesDevMap = $hash->{+HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES};

  # readings
  return 1 if (defined($gExcludesTypeMap) and ($gExcludesReadingMap->{$reading}));

  # types
  my $exType=$gExcludesTypeMap->{$type} if defined $gExcludesTypeMap;
  if(defined $exType) {
    return 1 if ($exType eq "*");
    return 1 if ($exType eq $reading);
  }

  # devices
  my $exDevName=$gExcludesDevMap->{$devName} if defined $gExcludesDevMap;
  if(defined $exDevName) {
    return 1 if ($exDevName eq "*");
    return 1 if ($exDevName eq $reading);
  }
  
  return undef;
}

sub doPublish($$$$$) {
  my ($hash,$topic,$message,$qos,$retain) = @_;

  #Log3($hash->{NAME},1,"publishDeviceUpdate for $devn, $reading, $value, topic: $topic, message: $message");
  my $msgid;
  if(defined($topic) and defined($message)) {
    $msgid = send_publish($hash->{IODev}, topic => $topic, message => $message, qos => $qos, retain => $retain);
    readingsSingleUpdate($hash,"transmission-state","outgoing publish sent",1);
  }
  $hash->{message_ids}->{$msgid}++ if defined $msgid;
}

sub publishDeviceUpdate($$$$) {
  my ($hash, $devHash, $reading, $value) = @_;
  my $devn = $devHash->{NAME};
  my $type = $devHash->{TYPE};
  # bestimmte bekannte types und readings ausschliessen (vor allem 'transmission-state' in der eigenen Instanz, das fuert sonst zu einem Endlosloop)
  return if($type eq "MQTT_GENERIC_BRIDGE");
  return if($type eq "MQTT");
  return if($reading eq "transmission-state");
  # extra definierte (ansonsten gilt eine Defaultliste) Types/Readings auschliessen.
  return if(isTypeDevReadingExcluded($hash, $type, $devn, $reading));

  #Log3($hash->{NAME},1,"publishDeviceUpdate for $devn, $reading, $value");
  #my $dummy = getDevicePublishRec($hash, ":dummy1", ":dummy2");
  my $pubRec = getDevicePublishRec($hash, $devn, $reading);
  #Log3($hash->{NAME},1,"publishDeviceUpdate pubRec: ".Dumper($pubRec));

  if(defined($pubRec)) {
    # my $msgid;

    my $topic = $pubRec->{'topic'};
    my $qos = $pubRec->{'qos'};
    my $retain = $pubRec->{'retain'};
    my $expression = $pubRec->{'expression'};

    my $redefMap=undef;
    my $message=$value;
    if(defined $expression) {
      # Expression: Direktes aendern von Attributen ($topic, $qos, $retain, $value) moeglich
      # Rueckgabe: bei undef wird die Ausfuehrung unterbunden. Sonst wird die Rueckgabe als neue message interpretiert, 
      # es sei denn, Variable $value wurde geaendert, dann hat die Aenderung Vorrang.
      # Rueckgabewert wird ignoriert, falls dieser ein Array ist. 
      # Bei einem Hash werden Paare als Topic-Message Paare verwendet und mehrere Nachrichten gesendet
      no strict "refs";
      local $@;
      #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> eval ($expression) !!!");
      my $ret = eval($expression);
      if(ref($ret) eq 'HASH') {
        $redefMap = $ret;
      } elsif(ref($ret) eq 'ARRAY') {
        # ignore
      } elsif(!defined($ret)) {
        $message = undef;
      } elsif($value ne $message) {
        $message = $value;
      } else {
        $message = $ret;
      }
      #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> eval done: ".Dumper($ret));
      if ($@) {
        Log3($hash->{NAME},2,"error while evaluating expression ('".$expression."'') eval error: ".$@);
      }
      use strict "refs";
    }

    if(defined($redefMap)) {
      foreach my $key (keys %{$redefMap}) {
        my $val = $redefMap->{$key};
        doPublish($hash,$key,$val,$qos,$retain);
      }
    } else {
        doPublish($hash,$topic,$message,$qos,$retain);
    }

    # #Log3($hash->{NAME},1,"publishDeviceUpdate for $devn, $reading, $value, topic: $topic, message: $message");
    # if(defined($topic) and defined($message)) {
    #   $msgid = send_publish($hash->{IODev}, topic => $topic, message => $message, qos => $qos, retain => $retain);
    #   readingsSingleUpdate($hash,"transmission-state","outgoing publish sent",1);
    # }
    # $hash->{message_ids}->{$msgid}++ if defined $msgid;
  }
}

sub Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;

  my $hash = $main::defs{$name};
  ATTRIBUTE_HANDLER: {
    $attribute eq CTRL_ATTR_NAME_GLOBAL_PREFIX.CTRL_ATTR_NAME_DEFAULTS and do {
      if ($command eq "set") {
        RefreshGlobalTable($hash, $attribute, $value);
      } else {
        RefreshGlobalTable($hash, $attribute, undef);
      }
      last;
    };
    $attribute eq CTRL_ATTR_NAME_GLOBAL_PREFIX.CTRL_ATTR_NAME_ALIAS and do {
      if ($command eq "set") {
        RefreshGlobalTable($hash, $attribute, $value);
      } else {
        RefreshGlobalTable($hash, $attribute, undef);
      }
      last;
    };
    $attribute eq CTRL_ATTR_NAME_GLOBAL_PREFIX.CTRL_ATTR_NAME_PUBLISH and do {
      if ($command eq "set") {
        RefreshGlobalTable($hash, $attribute, $value);
      } else {
        RefreshGlobalTable($hash, $attribute, undef);
      }
      last;
    };
    $attribute eq CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE and do {
      if ($command eq "set") {
        defineGlobalTypeExclude($hash,$value);
      } else {
        defineGlobalTypeExclude($hash,undef);
      }
      last;
    };
    $attribute eq CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE and do {
      if ($command eq "set") {
        defineGlobalDevExclude($hash,$value);
      } else {
        defineGlobalDevExclude($hash,undef);
      }
      last;
    };
     # $attribute eq "XXX" and do {
    #   if ($command eq "set") {
    #     #$hash->{publishState} = $value;
    #   } else {
    #     #delete $hash->{publishState};
    #   }
    #   last;
    # };
    my $prefix = $hash->{+HS_PROP_NAME_PREFIX};
    (($attribute eq $prefix.CTRL_ATTR_NAME_DEFAULTS) or 
      ($attribute eq $prefix.CTRL_ATTR_NAME_ALIAS) or 
      ($attribute eq $prefix.CTRL_ATTR_NAME_PUBLISH) or 
      ($attribute eq $prefix.CTRL_ATTR_NAME_SUBSCRIBE)or 
      ($attribute eq $prefix.CTRL_ATTR_NAME_IGNORE))and do {
      if ($command eq "set") {
        return "this attribute is not allowed here";
      }
      last;
    };
    #
    $attribute eq "IODev" and do {
      if ($main::init_done) {
        if ($command eq "set") {
          MQTT::client_stop($hash);
          $main::attr{$name}{IODev} = $value;
          MQTT::client_start($hash);
        } else {
          MQTT::client_stop($hash);
        }
      }
      last;
    };
    return undef;
  }
}

sub ioDevConnect($) {
  my $hash = shift;
  #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE DEBUG: ioDevConnect");
  # TODO
}

sub ioDevDisconnect($) {
  my $hash = shift;
  #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE DEBUG: ioDevDisconnect");
  # TODO
}


sub doSetUpdate($$$$$) {
  my ($hash,$mode,$device,$reading,$message) = @_;
  if($mode eq 'S') {
    my $err;
    if(($reading eq '') or ($reading eq 'state')) {
      $err = DoSet($device,$message);
    } else {
      $err = DoSet($device,$reading,$message);
    }
    Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE error in set command: ".$err) if defined $err;
  } elsif($mode eq 'R') {
    readingsSingleUpdate($defs{$device},$reading,$message,1);
  } else {
    Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE: unexpected mode: : ".$mode);
  }
}

sub onmessage($$$) {
  my ($hash,$topic,$message) = @_;
  CheckInitialization($hash);
  #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE DEBUG: onmessage: $topic => $message");

  my $fMap = searchDeviceForTopic($hash, $topic);
  #Log3($hash->{NAME},1,"MQTT_GENERIC_BRIDGE DEBUG: onmessage: $fMap : ".Dumper($fMap));
  foreach my $deviceKey (keys %{$fMap}) {
        my $device = $fMap->{$deviceKey}->{'device'};
        my $reading = $fMap->{$deviceKey}->{'reading'};
        my $mode = $fMap->{$deviceKey}->{'mode'};
        my $expression = $fMap->{$deviceKey}->{'expression'};

        my $redefMap=undef;

        if(defined $expression) {
          # Expression: Verfuegbare Variablen: $device, $reading, $message (initial gleich $value)
          # Rueckgabe: bei undef wird die Ausfuehrung unterbunden. Sonst wird die Rueckgabe als neue message interpretiert, 
          # es sei denn, Variable $value wurde geaendert, dann hat die Aenderung Vorrang.
          # Rueckgabewert wird ignoriert, falls dieser ein Array ist. 
          # Bei einem Hash werden Paare als Reading-Wert Paare gesetzt (auch set (stopic))
          no strict "refs";
          local $@;
          #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> eval ($expression) !!!");
          my $value = $message;
          my $ret = eval($expression);
          if(ref($ret) eq 'HASH') {
            $redefMap = $ret;
          } elsif(ref($ret) eq 'ARRAY') {
            # ignore
          } elsif(!defined($ret)) {
            $message = undef;
          } elsif($value ne $message) {
            $message = $value;
          } else {
            $message = $ret;
          }
          #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> eval done: ".Dumper($ret));
          if ($@) {
            Log3($hash->{NAME},2,"error while evaluating expression ('".$expression."'') eval error: ".$@);
          }
          use strict "refs";
        }

        next unless defined $device;
        next unless defined $reading;

        next unless defined $message;

        if(defined($redefMap)) {
          foreach my $key (keys %{$redefMap}) {
            my $val = $redefMap->{$key};
            doSetUpdate($hash,$mode,$device,$key,$val);
          }
        } else {
          doSetUpdate($hash,$mode,$device,$reading,$message);          
        }
  }

}
1;

# Subscribe: $reading/$device <=> +-Platzhalter: /TEST/BLUP/+ => der letzte + steht fue $reading, vorherige fuer $device
# oder besser Zerlegung von Vorne oder von Hinten? /xxxxxxx/xxx.../$reading?, bei global: /xxxx.../xxx../$device/$reading ? 
# oder so: /XXXX/+/+/$reading/xxx/#. Damit wurde MQTT-Subscription /XXXX/+/+/+/xxx/# sein und Suchpattern /XXXX/+/+/&lt;READING&gt;/xxx/#
#  analog fuer Devices: /XXXX/$device/+/$reading/xxx/# => /XXXX/+/+/+/xxx/# /XXXX/<DEVICE>/+/&lt;READING&gt;/xxx/#
# Definitionen:
#   mqttSubscribe &lt;reading&gt;:topic=<topic>
#   mqttSubscribe *:topic=<topic>
# Bei konkretten ist einfach:
#   &lt;reading&gt;:topic=/TEST/DEVX/temperature
# Mit Wilccards:
#   *:topic=/TEST/DEVX/$reading
#   *:topic=/TEST/DEVX/$reading/#
#   *:topic=/TEST/$device/$reading
#   *:topic=/TEST/$device/$reading/#
#   *:topic=/TEST/$device/$reading/blup
#   *:topic=/TEST/+/$device/$reading/#
#   *:topic=/TEST/+/$device/+/$reading/
#
# bei Definitionen in Geraeteattributen: $device=Devicename, $reading=Readingname, wenn mit konkretem Reading definiert, + sonst (also mit *)
# bei Definitionen in der Bridgeattributen: $device=Devicename, wenn konkret angegeben, + sonst (*), $reading analog $reading in Geraeteattributen.
# weitere Wildcards (+ und #) sind zugelassen (damit koennen ggf. mehrere konkrete Topics ein Device/Reading updaten. Duerfte meist unsinnig sein.).
# 
# Ersetzungshilfe:  {my $reading="rrr";;my $a='$reading/asd/$reading/+/sdfasd/$reading/#';;$a =~ s/\$reading/$reading/g;;$a} => rrr/asd/rrr/+/sdfasd/rrr/#
#
#
#
# Sollen ggf. Readings und vlt. sogar Devices automatisch angelegt werden (autocreate)? Dann vlr. sogar mit autosetzen von Attributen wie 'room' ($room)?
#  autocreate evtl. ja. room => nein.
#
# Gueltige Topics:   /TEMP/+/temperature, /+/+/#, /TEMP/#, #
# Ungueltige Topics: /TEMP/#/temperature, ++, +#
# 
# Strukturen:
# Suche eingehenden topics: 
#  => nein, es wird aenliche Struktur verwendet, wie beim Publish
#   --map->{topic ggf. mit wildcards}->{devicemaping}->'device-maping-topic'
#   --map->{topic ggf. mit wildcards}->{deviceliste}->[liste/map] # gefundenen Devices?
#   --map->{topic ggf. mit wildcards}->{wildcard?}->flag # Optmierungsmassnahme/Cache, optional
# 
# Suche nach Device-Mapping:
#   wird noch benoetigt?
# 
# Cache fuer gefundene topics: (Optimierung)
#   map->{incomming_topic}->[{deviceliste}]->[liste/map]-jeweils->{reading}
#   notwendig? Spaeter vlt.? => erstmal nicht
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


# Dieses Modul ist eine MQTT-Bridge, die gleichzeitig mehrere FHEM-Devices erfasst und deren Readings 
# per MQTT weiter gibt bzw. aus den eintreffenden MQTT-Nachrichten befuellt oder diese als 'set'-Befehl ausfuert.
# Es wird ein <a href="#MQTT">MQTT</a>-Geraet als IODev benoetigt.
#
# Die (minimal) Konfiguration der Bridge selbst ist grundsaetzlich sehr einfach.<br/>
# <br/>
# <a name="MQTT_GENERIC_BRIDGEdefine"></a>
# Definition:
#   Im einfachsten Fall reichen schon zwei Zeilen:
#     defmod mqttGeneric MQTT_GENERIC_BRIDGE [prefix] [devspec]
#     attr mqttGeneric IODev <MQTT-Device>
#   Alle Parameter im Define sind optional. 
#   Der erste ist ein Prefix fuer die Steuerattribute, worueber die zu ueberwachende Geraete (s.u.) 
#   konfiguriert werden. Dafaultwert ist 'mqtt'. 
#   Wird dieser z.B. als 'hugo' redefiniert, heissen die Steuerungsattribute entsprechend hugoPublish etc.
#   Der zweite Parameter ('devspec') erlaubt die Menge der zu ueberwachenden Geraeten 
#   zu begrenzen (sonst werden einfach alle ueberwacht, was jedoch Performance kosten kann).
#   s.a. <a href="https://fhem.de/commandref_DE.html#devspec">devspec</a>
#
# Attribute:
#   IODev
#     Dieses Attribut ist obligatorisch und muss den Namen einer funktionierenden MQTT-Modulinstanz enthalten.
#
#   disable
#     Wert 1 deaktiviert die Bridge
#
#     Beispiel:
#       attr &lt;dev&gt; disable 1
#
#   globalDefaults
#     Definiert Defaults, die greifen, falls in dem jeweiligen Geraet definierte Werte nicht greifen. s.a. <a href="#MQTT_GENERIC_BRIDGEmqttDefaults">mqttDefaults</a>. 
#
#   globalAlias
#     Definiert Alias, die greifen, falls in dem jeweiligen Geraet definierte Werte nicht greifen. s.a. <a href="#MQTT_GENERIC_BRIDGEmqttAlias">mqttAlias</a>.
#
#   globalPublish
#     Definiert Topics/Flags fuer die uebertragung per MQTT. Sie greifen, falls in dem jeweiligen Geraet 
#     definierte Werte nicht greifen oder nicht vorhanden sind. s.a. <a href="#MQTT_GENERIC_BRIDGEmqttPublish">mqttPublish</a>.
#
#   globalSubscribe TODO - wird derzeit nicht unterstuetzt und wird moeglicherweise gar nicht implementiert
#     Definiert Topics/Flags fuer die Aufnahme der Werte aus der MQTT-Uebertragung. Sie greifen, falls in dem jeweiligen Geraet 
#     definierte Werte nicht greifen oder nicht vorhanden sind. s.a. <a href="#MQTT_GENERIC_BRIDGEmqttSubscribe">mqttSubscribe</a>.
#
#   globalTypeExclude TODO - ist derzeit nicht implementiert
#     Definiert (Geraete)Typen und Readings, die nicht bei der Uebertragung beruecksichtigt werden. 
#     Ein einzelner Wert bedeutet, dass ein Geraete diesen Typen komplett ignoriert wird (also fuer alle seine Readings).
#     Durch ein Doppelpunkt getrennte Paare werden als Type:Reading interptretiert. 
#     Das Bedeutet, dass an dem gegebenen Type die genannte Reading nicht uebertragen wird.
#     Ein Stern anstatt Type oder auch Reading bedeutet, dass alle Readings eines Geretaetueps 
#     bzw. genannte Readings an jedem Geraetetyp ignoriert werden.
#
#     Beispiel:
#       attr &lt;dev&gt; globalTypeExclude MQTT MQTT_GENERIC_BRIDGE:* MQTT_BRIDGE:transmission-state *:baseID
#
#   globalDeviceExclude TODO - ist derzeit nicht implementiert
#     Definiert Geraetenamen und Readings, die nicht uebertragen werden. 
#     Ein einzelner Wert bedeutet, dass ein Geraet mit diesem Namen komplett ignoriert wird (also fuer alle seine Readings).
#     Durch ein Doppelpunkt getrennte Paare werden als Device:Reading interptretiert. 
#     Das Bedeutet, dass an dem gegebenen Geraet die genannte Reading nicht uebertragen wird.
#
#     Beispiel:
#       attr &lt;dev&gt; globalDeviceExclude Test Bridge:transmission-state
#
#
# Fuer die ueberwachten Geraete wird die Liste der moeglichen Attribute automatisch um mehrere weitere Eintraege ergaenzt, 
# die alle mit vorher in der Bridge definierten Prefix anfangen. Ueber diese wird die eigentliche MQTT-Anbindung konfiguriert.
#
# Defaultmaessig werden folgende Attribute verwendet: mqttDefaults, mqttAlias, mqttPublish, mqttSubscribe.
# Sie haben dabei folgende Bedeutung:
# 
#   mqttDefaults 
#     Hier wird eine Liste der "key=value"-Paare erwartet. Folgende Keys sind dabei moeglich:
#       'qos' definiert ein Default fuer MQTT-Paramter 'Quality of Service'.
#       'retain' erlaubt MQTT-Nachrichten als 'retained messages' zu markieren.
#       'base' wird als Variable ($base) bei der Konfiguration von konkreten Topics zur Verfuegung gestellt. 
#              Sie kann entweder Text oder eine Perl-Expression enthalten. 
#              Perl-Expression muss in Geschweifte Klammern eingeschlossen werden.
#              In einer Expression koennen Variablen verwendet werden.
#              ($reading = Original-Readingname, $device = Devicename, $name = Readingalias (s. <a href="#MQTT_GENERIC_BRIDGEmqttAlias">mqttAlias</a>). 
#              Ist kein Alias definiert, ist $name=$reading).
#
#     Alle diese Werte koennen durch vorangestelle Prefixe ('pub:' oder 'sub') in ihrer Gueltigkeit 
#     nur auf das Senden bzw. Empfangen begrenzt werden (soweit sinnvoll). 
#     Werte fuer 'qos' und 'retain' werden nur verwendet, 
#     wenn keine explizite Angaben darueber fuer ein konkretes Topic gemacht worden sind.
#
#     Beispiel:
#       attr &lt;dev&gt; mqttDefaults base={"/TEST/$device"} pub:qos=0 sub:qos=2 retain=0
#
#   mqttAlias 
#     Dieses Attribut ermoeglicht Readings unter einem anderen Namen auf MQTT-Topict zu mappen. 
#     Eigentlich nur sinnvoll, wenn Topicdefinitionen Perl-Expressions mit entsprechenden Variablen sind.
#     Auch hier werden 'pub:' und 'sub:' Prefixe unterstuetzt (fuer 'subscribe' gilt das Mapping quasi umgekehrt).
#     TODO: fuer siubscribe noch nicht implementiert.
#
#     Beispiel:
#       attr &lt;dev&gt; mqttAlias pub:temperature=temp
#
#   mqttPublish
#     Hier werden konkrette Topics definiet und den Readings zugeordnet (Format: &lt;reading&gt;:topic=<topic>). 
#     Weiterhin koennen diese einzeln mit 'qos'- und 'retain'-Flags versehen werden. 
#     Topics koennen auch als Perl-Expression mit Veriablen definiert werden ($reading, $device, $name, $base).
#     Werte fuer mehrere Readings koennen auch gemeinsam gleichzeitig definiert werden, 
#     indem sie, mittels '|' getrennt, zusammen angegeben werden.
#     Wird anstatt eines Readingsnamen ein '*' verwendet, gilt diese Definition fuer alle Readings, 
#     fuer die keine explizite Angaben gemacht worden.
#     Es koennen auch Expressions (reading:expression=...) definiert werden. 
#     Die Expressions koennen dabei entweder Variablen ($value, $topic, $qos, $retain) redefinieren, oder einen Wert != undef zurrueckgeben.
#     Der Rueckhgabe wert wird als neue Nachricht-Value verwendet, die Redefinition der Variable hat jedoch Vorrang.
#     Ist der Rueckgabewert undef, dann wird das Setzen/Ausfuehren unterbunden. 
#     Ist die Rueckgabe ein Hash (nur 'topic' und 'stopic'), werden seine Schluesselwerte als Topic verwendet, 
#     die Inhalte der Nachrichten sind entsprechend die Werte aus dem Hash.
#
#     Beispiel:
#       attr &lt;dev&gt; mqttPublish temperature:topic={"$base/$name"} temperature:qos=1 temperature:retain=0 *:topic={"$base/$name"} humidity:topic=/TEST/Feuchte
#       attr &lt;dev&gt; mqttPublish temperature|humidity:topic={"$base/$name"} temperature|humidity:qos=1 temperature|humidity:retain=0
#       attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} *:qos=2 *:retain=0
#       attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={"message: $value"}
#       attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={$value="message: $value"}
#       attr &lt;dev&gt; mqttPublish *:topic={"$base/$name"} reading:expression={"/TEST/Topic1"=>"$message", "/TEST/Topic2"=>"message: $message"}
#
#   mqttSubscribe 
#     Dieses Attribut konfiguriert das Empfangen der MQTT-Nachrichten und Reaktionen darauf.
#     Die Konfiguration ist aehnlich der fuer das 'mqttPublish'-Attribut. Es koennen topics fuer das Setzen von Readings ('topic') und
#     Aufrufe von 'set'-Befehl an dem Geraet ('stopic') definiert werden. 
#     Mit Hilfe von zusaetzliche auszufuehrenden Perl-Expressions ('expression') kann das Ergebnis vor dem Setzen/Ausfueren beeinflusst werden.
#     Die Expression kann dabei entweder Variable $value redefinieren, oder einen Wert != undef zurrueckgeben. Redefinition der Variable hat Vorrang.
#     Ist der Rueckgabewert undef, dann wird das Setzen/Ausfuehren unterbunden. 
#     Ist die Rueckgabe ein Hash (nur 'topic' und 'stopic'), werden seine Schluesselwerte als Readingsnamen/'set'-Parameter verwendet, 
#     die zu setzenden Werte sind entsprechend die Werte aus dem Hash.
#     Weiterhin kann das Attribut 'qos' angegeben werden ('retain' macht dagegen keinen Sinn).
#     In der Topic-Definition koennen MQTT-Wildcards (+ und #) verwendet werden. 
#     Falls der Reading-Name mit einem '*'-Zeichen am Anfang definiert wird, gilt dieser als 'Platzhalter'.
#     Der tatsaechlicher Name der Reading (und ggf. des Geraetes) wird dabei durch Variablen in dem Topic 
#     definiert ($device (nur fuer globale Definition in der Bridge), $reading, $name).
#     Im Topic wirken diese Variablen als Wildcards, macht natuerlich nur Sinn, wenn Reading-Name auch nicht fest definiert ist (also faengt mit '*' an). 
#     Die Variable $name wird im Unterschied zu $reading ggf. ueber die in 'mqttAlias' definierten Aliases beeinflusst.
#     Auch Verwendung von $base ist erlaubt.
#     Bei Verwendung von 'stopic' wird das 'set'-Befehl als 'set &lt;dev&gt; &lt;reading&gt; &lt;value&gt;' ausgefuert.
#     Fuer ein 'set &lt;dev&gt; &lt;value&gt;' soll als Reading-Name 'state' verwendet werden.
#
#     Beispiele:
#       attr &lt;dev&gt; mqttSubscribe temperature:topic=/TEST/temperature test:qos=0 *:topic={"/TEST/$reading/value"} 
#       attr &lt;dev&gt; mqttSubscribe desired-temperature:stopic={"/TEST/temperature/set"}
#       attr &lt;dev&gt; mqttSubscribe state:stopic={"/TEST/light/set"} state:expression={...}
#       attr &lt;dev&gt; mqttSubscribe state:stopic={"/TEST/light/set"} state:expression={$value="x"}
#       attr &lt;dev&gt; mqttSubscribe state:stopic={"/TEST/light/set"} state:expression={"R1"=>$value, "R2"=>"Val: $value", "R3"=>"x"}
#
#   mqttDisable
#     Wird dieses Attribut in einem Geraet gesetzt, wird dieses Geraet vom Versand der Readingswerten ausgeschlossen.
#
#   Beispiele: 
#     Bridge fuer alle moeglichen Geraete mit dem Standardprefix:
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE
#       attr mqttGeneric IODev mqtt
#
#     Bridge mit dem Prefix 'mqtt' fuer drei bestimmte Geraete:
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE mqtt sensor1,sensor2,sensor3
#       attr mqttGeneric IODev mqtt
#
#     Bridge fuer alle Geraete in einem bestimmten Raum:
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE mqtt room=Wohnzimmer
#       attr mqttGeneric IODev mqtt
#     
#     Einfachste Konfiguration eines Temperatursensors:
#       defmod sensor XXX
#       attr sensor mqttPublish temperature:topic=/haus/sensor/temperature
#
#     Alle Readings eines Sensors (mit ihren Namen wie sie sind) per MQTT versenden:
#       defmod sensor XXX
#       attr sensor mqttPublish *:topic={"/sensor/$reading"}
#     
#     Topicsdefinition mit Auslagerung von dem gemeinsamen Teilnamen in 'base'-Variable:
#       defmod sensor XXX
#       attr sensor mqttDefaults base={"/$device/$reading"}
#       attr sensor mqttPublish *:topic={$base}
#
#     Topicsdefinition nur fuer bestimmte Readings mit deren gleichzeitigen Umbennenung (Alias):
#       defmod sensor XXX
#       attr sensor mqttAlias temperature=temp humidity=hum
#       attr sensor mqttDefaults base={"/$device/$name"} 
#       attr sensor mqttPublish temperature:topic={$base} humidity:topic={$base}
#
#
#   Beispiel fuer eine zentralle Konfiguration in der Bridge fuer alle Devices, die Reading 'temperature' besitzen:
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE 
#       attr mqttGeneric IODev mqtt
#       attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0
#       attr mqttGeneric publish temperature:topic={"/haus/$device/$reading"}
#
#   Beispiel fuer eine zentralle Konfiguration in der Bridge fuer alle Devices 
#   (wegen schlechter uebersicht und einer unnoetig grossen Menge eher nicht zu empfehlen):
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE 
#       attr mqttGeneric IODev mqtt
#       attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0
#       attr mqttGeneric publish *:topic={"/haus/$device/$reading"}
#     
#    Einschraenkungen:
#      Wenn mehrere Readings das selbe Topic abonieren, sind dabei keine unterschiedlichen QOS moeglich.
#      Wird in so einem Fall QOS ungleich 0 benoetigt, sollte dieser entweder fuer alle Readings gleich einzeln definiert werden,
#      oder allgemeinguetltig ueber Defaults. Ansonsten wird beim Erstellen von Abonements der erst gefundene Wert verwendet. 
#
#      Abonements werden nur erneuert, wenn dich das Topic aendert, QOS-Flag-Aenderung alleine wirkt sich daher erst nach einem Neustart aus.
#
#   TODOs
#   - global Subscribe
#   - global excludes
#   - QOS for subscribe (fertig?), defaults(qos, fertig?), alias mapping
#   - resendOnConnect (no, first, last, all)
#   - resendInterval (no/0, x min)
#   - templates (template in der Bridge, mqttUseTemplate in Device)


=pod
=item [device]
=item summary MQTT_GENERIC_BRIDGE acts as a bridge for any fhem-devices and mqtt-topics
=begin html

<a name="MQTT_GENERIC_BRIDGE"></a>
<h3>MQTT_GENERIC_BRIDGE</h3>
<ul>
  <p>acts as a bridge for any fhem-devices and <a href="http://mqtt.org/">mqtt</a>-topics.</p>
  <p>requires a <a href="#MQTT">MQTT</a>-device as IODev<br/>
     Note: this module is based on <a href="https://metacpan.org/pod/distribution/Net-MQTT/lib/Net/MQTT.pod">Net::MQTT</a> which needs to be installed from CPAN first.</p>
  <a name="MQTT_GENERIC_BRIDGEdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MQTT_GENERIC_BRIDGE [&lt;configAttrPrefix&gt;] [&lt;dev-spec&gt;]</code></p>
    <p>Specifies the generic bridge. Publish/Subscriptions must be definen with the Device atributen<br/>
       &lt;configAttrPrefix&gt; Prefix fuer Konfig-Attributeinden Geraeten</p>

       <p>For a detailed Description see <a href="commandref_DE.html#MQTT_GENERIC_BRIDGE">german section</a>.</a>
  </ul>
  
</ul>

=end html

=item summary_DE MQTT_GENERIC_BRIDGE acts as a bridge for any fhem-devices and mqtt-topics
=begin html_DE

<a name="MQTT_GENERIC_BRIDGE"></a>
<h3>MQTT_GENERIC_BRIDGE</h3>
<ul>

  <p>Dieses Modul ist eine MQTT-Bridge, die gleichzeitig mehrere FHEM-Devices erfasst und deren Readings 
     per MQTT weiter gibt bzw. aus den eintreffenden MQTT-Nachrichten befuellt.</p>
  <p>Es wird ein <a href="#MQTT">MQTT</a>-Geraet als IODev benoetigt.</p>
  <p>Die (minimal) Konfiguration der Bridge selbst ist grundsaetzlich sehr einfach.</p>
  <a name="MQTT_GENERIC_BRIDGEdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MQTT_GENERIC_BRIDGE [&lt;configAttrPrefix&gt;] [&lt;dev-spec&gt;]</code></p>
    <p>Specifies the generic bridge. Publish/Subscriptions must be definen with the Device atributen<br/>
       &lt;configAttrPrefix&gt; Prefix fuer Konfig-Attributeinden Geraeten</p>
  </ul>
  <a name="MQTT_GENERIC_BRIDGEget"></a>
  <p><b>Get</b></p>
  <ul>
    <li>
      <p><code>get &lt;name&gt; TODO</code><br/>
         TODO</p>
    </li>
  </ul>
  <a name="MQTT_GENERIC_BRIDGEattr"></a>
  <p><b>Attributes</b></p>
  <ul>
    <li>
      <p><code>attr &lt;name&gt; XXX</code><br/>
         TODO
      </p>
    </li>
    
  </ul>
</ul>
=end html_DE
=cut
