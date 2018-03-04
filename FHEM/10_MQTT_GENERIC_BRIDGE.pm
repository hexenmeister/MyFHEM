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

    # Beim ModulReload Deviceliste löschen (eig. nur für bei der Entwicklung nützich)
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
  # TODO derzeit muss wegen client_sztart/stop in 00_MQTT Liste der Topics parallel in
  # {subscribe} gehalten werden

  #HS_TAB_NAME_PUBLISH         => "publish",

  HS_PROP_NAME_PREFIX         => "prefix",
  HS_PROP_NAME_PREFIX_OLD     => "prefix_old",
  HS_PROP_NAME_DEVSPEC        => "devspec",
  HS_FLAG_INITIALIZED         => ".initialized",

  HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE    => "globalTypeExcludes",
  HS_PROP_NAME_GLOBAL_EXCLUDES_READING => "globalReadingExcludes",
  HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES => "globalDeviceExcludes",
  DEFAULT_GLOBAL_TYPE_EXCLUDES     => "MQTT MQTT_DEVICE MQTT_BRIDGE CUL HMLAN HMUARTLGW MAXLAN TCM MYSENSORS MilightBridge JeeLink ZWDongle telnet FHEMWEB Global TUL SIGNALDuino *:transmission-state",
  DEFAULT_GLOBAL_DEV_EXCLUDES     => ""
};

sub publishDeviceUpdate($$$$);
sub RemoveDeviceSubscriptons($$);
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

# Device define
sub Define() {
  my ( $hash, $def, $prefix, $devspec ) = @_;
  # Definition :=> defmod mqttGeneric MQTT_GENERIC_BRIDGE [prefix] [devspec]

  $prefix="mqtt" unless defined $prefix; # default prefix is 'mqtt'
  $hash->{+HS_PROP_NAME_PREFIX_OLD}=$hash->{+HS_PROP_NAME_PREFIX};
  $hash->{+HS_PROP_NAME_PREFIX}=$prefix; # store in device hash
  $hash->{+HS_PROP_NAME_DEVSPEC} = defined($devspec)?$devspec:".*";
  firstInit($hash);

  return undef;
}

# Device undefine
sub Undefine() {
  my ($hash) = @_;
  MQTT::client_stop($hash);
  # TODO subscriptions löschen
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

    # tabelle aufbauen, Start (subscriptions erstellen, anpassen, löschen)
    InitializeDevices($hash);
  
    # TODO ggf. bestehenden subscriptions kuendigen
    # TODO client_start und client_stop in MQTT-Modul weiterreichen
    $hash->{subscribe} = [];

    # TODO eigene implementierung
    MQTT::client_start($hash);
  }
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
        if(($ident eq 'topic') or ($ident eq 'qos') or ($ident eq 'retain')) {
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
# sucht zu den gegebenen device und reading die publish-Einträge (topic, qos, retain)
# verwendet device-record und berücksichtigt defaults und globals
# parameter: $hash, device-name, reading-name
sub getDevicePublishRec($$$) {
  my($hash, $dev, $reading) = @_;
  my $map = $hash->{+HS_TAB_NAME_DEVICES};
  return undef unless defined $map;
  
  my $devMap = $map->{$dev};
  my $globalMap = $map->{':global'};

  return getDevicePublishRecIntern($hash, $devMap, $globalMap, $dev, $reading);
}

# sucht zu den gegebenen device und reading die publish-Einträge (topic, qos, retain) 
# in den uebergebenen Maps
# verwendet device-record und berücksichtigt defaults und globals
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

  if(defined $readingMap) {
    $qos = $readingMap->{'qos'};
    $retain = $readingMap->{'retain'};
    if(defined($readingMap->{':defaults'})) {
      $qos = $readingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain = $readingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
    }
  }

  if(defined $defaultReadingMap) {
    $qos = $defaultReadingMap->{'qos'} unless defined $qos;
    $retain = $defaultReadingMap->{'retain'} unless defined $retain;
    if(defined($defaultReadingMap->{':defaults'})) {
      $qos = $defaultReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain = $defaultReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
    }
  }

  if(defined $globalReadingMap) {
    $qos = $globalReadingMap->{'qos'};
    $retain = $globalReadingMap->{'retain'};
    if(defined($globalReadingMap->{':defaults'})) {
      $qos = $globalReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain = $globalReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
    }
  }
  
  if(defined $globalDefaultReadingMap) {
    $qos = $globalDefaultReadingMap->{'qos'} unless defined $qos;
    $retain = $globalDefaultReadingMap->{'retain'} unless defined $retain;
    if(defined($globalDefaultReadingMap->{':defaults'})) {
      $qos = $globalDefaultReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
      $retain = $globalDefaultReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
    }
  }

  $qos = 0 unless defined $qos;
  $retain = 0 unless defined $retain;
  
  return {'topic'=>$topic,'qos'=>$qos,'retain'=>$retain};
}


# sucht zu den gegebenen device und reading die publish-Einträge (topic, qos, retain)
# verwendet device-record und berücksichtigt defaults
# parameter: $hash, device-name, reading-name
# sub old_getDevicePublishRec($$$) {
#   my($hash, $dev, $reading) = @_;
#   my $map = $hash->{+HS_TAB_NAME_DEVICES};
#   # return: topic, qos, retain
#   my $devMap = $map->{$dev};
#   #return undef unless defined $devMap; # TODO : globale defaults
#   my $devReadingMap = $devMap->{':publish'}->{$reading} if defined $devMap;
#   #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> devReadingMap ".Dumper($devReadingMap));
#   #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> devReadingMap->topic ".Dumper($devReadingMap->{'topic'}));
#   my $dummy = $devReadingMap->{'topic'} if defined $devMap; # Ich weiss nicht warum, vlt. ein intepreter fehler, aber ohne funktioniert es nicht (liefert teilweise werte aus vorherigen Abfrage, wie ein cache...) (perl 5, version 20, subversion 2 (v5.20.2))
#   my $devReadingDefaultMap = $devMap->{':publish'}->{'*'} if defined $devMap;
#   #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> devReadingDefaultMap ".Dumper($devReadingDefaultMap));
#   # search topic
#   my $topic = undef;
#   $topic = $devReadingMap->{'topic'} if defined $devReadingMap;
#   #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> topic1 ".Dumper($topic));
#   $topic = $devReadingDefaultMap->{'topic'} if (!defined($topic) and defined($devReadingDefaultMap));
#   #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> topic2 ".Dumper($topic));

#   # falls topic nicht in dev-Map gefunden werden konnte, in der global-Map versuchen
#   my $globalMap = $map->{':global'};
#   my $globalPublishMap = $globalMap->{':publish'} if defined $globalMap;
#   my $globalReadingMap = $globalPublishMap->{$reading}  if defined $globalPublishMap;
#   #my $dummy2 = $globalReadingMap->{'topic'} if defined $devMap; 
#   my $globalReadingDefaultMap = $globalPublishMap->{'*'}  if defined $globalPublishMap;

#   #$dummy = $globalReadingMap->{'topic'} if defined $globalReadingMap; ###
#   $topic = $globalReadingMap->{'topic'} if (!defined($topic) and (defined $globalReadingMap));
#   #$dummy = $globalReadingDefaultMap->{'topic'} if defined $globalReadingDefaultMap; ###
#   $topic = $globalReadingDefaultMap->{'topic'} if (!defined($topic) and defined($globalReadingDefaultMap));

#   # unless (defined $topic) {
#   #   my $globalMap = $map->{':global'};
#   #   if(defined ($globalMap)) {
#   #     my $globalPublishMap = $globalMap->{':publish'};
#   #     if(defined $globalPublishMap) {
#   #       #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> devReadingDefaultMap ".Dumper($globalPublishMap));
#   #       my $globalReadingMap = $globalPublishMap->{$reading};
#   #       #my $dummy = $globalReadingMap->{'topic'} if defined $globalReadingMap; 
#   #       my $globalReadingDefaultMap = $globalPublishMap->{'*'};
#   #       #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> globalReadingDefaultMap ".Dumper($globalReadingDefaultMap));
#   #       $topic = $globalReadingMap->{'topic'} if defined $globalReadingMap;
#   #       $topic = $globalReadingDefaultMap->{'topic'} if (!defined($topic) and defined($globalReadingDefaultMap));
#   #       #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> topicGl ".Dumper($topic));
#   #     }
#   #   }
#   # }

#   return undef unless defined $topic;
#   # evaluate
#   if($topic =~ m/^{.*}$/) {
#     # $topic evaluieren (avialable vars: $base, $dev (device name), $reading (oringinal name), $name ($reading oder alias, if defined))
#     #no strict "refs";
#     # TODO: $base auch extra evaluieren? => vermutlich passier automatisch => prüfen
#     my $name = $devMap->{':alias'}->{'pub:'.$reading} if defined $devMap;
#     $name = $globalMap->{':alias'}->{'pub:'.$reading} if (!defined($name) and defined($globalMap)); # global
#     $name = $reading unless defined $name;

#     my $base = $devMap->{':defaults'}->{'pub:base'} if defined $devMap;
#     $base = $globalMap->{':defaults'}->{'pub:base'} if (!defined($base) and defined($globalMap)); # global
#     $base='' unless defined $base;
#     #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> vor eval: (base, dev, reading, name) $base, $dev, $reading, $name");
#     $base = _evalValue($hash->{NAME},$base,$base,$dev,$reading,$name);
#     #if($base =~ m/^{.*}$/) {
#     #  $base = eval($base);
#     #}
#     #$topic = eval($topic);
#     $topic = _evalValue($hash->{NAME},$topic,$base,$dev,$reading,$name);
#     #undef $base;
#     #use strict "refs"; # eig. unnoetig
#   }
#   return undef unless defined $topic;
  
#   # looking for qos
#   my $qos = undef;
#   if(defined $devReadingMap) {
#     $qos = $devReadingMap->{'qos'};
#     $qos = $devReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
#   }
#   if(defined $devReadingDefaultMap) {
#     $qos = $devReadingDefaultMap->{'qos'} unless defined $qos;
#     $qos = $devReadingDefaultMap->{':defaults'}->{'pub:qos'} unless defined $qos;
#   }
#   if(defined $globalReadingMap) {
#     $qos = $globalReadingMap->{'qos'} unless defined $qos;
#     $qos = $globalReadingMap->{':defaults'}->{'pub:qos'} unless defined $qos;
#   }
#   if(defined $globalReadingDefaultMap) {
#     $qos = $globalReadingDefaultMap->{'qos'} unless defined $qos;
#     $qos = $globalReadingDefaultMap->{':defaults'}->{'pub:qos'} unless defined $qos;
#   }
#   $qos = 0 unless defined $qos;

#   # looking for retain
#   my $retain = undef;
#   if(defined $devReadingMap) {
#     $retain = $devReadingMap->{'retain'};
#     $retain = $devReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
#   }
#   if(defined $devReadingDefaultMap) {
#     $retain = $devReadingDefaultMap->{'retain'} unless defined $retain;    
#     $retain = $devReadingDefaultMap->{':defaults'}->{'pub:retain'} unless defined $retain;
#   }
#   if(defined $globalReadingMap) {
#     $retain = $globalReadingMap->{'retain'} unless defined $retain;
#     $retain = $globalReadingMap->{':defaults'}->{'pub:retain'} unless defined $retain;
#   }
#   if(defined $globalReadingDefaultMap) {
#     $retain = $globalReadingDefaultMap->{'retain'} unless defined $retain;    
#     $retain = $globalReadingDefaultMap->{':defaults'}->{'pub:retain'} unless defined $retain;
#   }
#   $retain = 0 unless defined $retain;
  
#   # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
#   #Log3('xxx',1,"MQTT-GB:DEBUG:> getDevicePublishRec> ret: (topic, qos, retain) $topic, $qos, $retain");
#   return undef unless defined $topic;
#   return undef if ($topic eq "");
#   #return {'topic'=>$topic,'qos'=>$qos,'retain'=>$retain};
#   my $ret={};
#   $ret->{topic}=$topic;
#   $ret->{qos}=$qos;
#   $ret->{retain}=$retain;
#   return $ret;
# }

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
sub searchDeviceForTopic($$) {
  my($hash, $topic) = @_;
  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
  my $map = $hash->{+HS_TAB_NAME_DEVICES};

  return undef;
}

sub CreateSingleDeviceTableAttrSubscribe($$$$) {
  my($hash, $dev, $map, $attrVal) = @_;
  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
  return undef;
}

sub CreateSingleDeviceTable($$$$$) {
  my ($hash, $dev, $devMapName, $prefix, $map) = @_;
  # Divece-Attribute für ein bestimmtes Device aus Device-Attributen auslesen
  #my $prefix = $hash->{+HS_PROP_NAME_PREFIX};
  CreateSingleDeviceTableAttrDefaults($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_DEFAULTS, undef));
  CreateSingleDeviceTableAttrAlias($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_ALIAS, undef)); 
  CreateSingleDeviceTableAttrPublish($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_PUBLISH, undef));
  CreateSingleDeviceTableAttrSubscribe($hash, $devMapName, $map, AttrVal($dev, $prefix.CTRL_ATTR_NAME_SUBSCRIBE, undef));
  # Wenn keine Einträge => Device löschen
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
  # Attribute zu dem angegeben Gerät neu erfassen
  my $map = $hash->{+HS_TAB_NAME_DEVICES};
  if(defined($attrName)) {
    # ... entweder für bestimmte Attribute ...
    CreateSingleDeviceTableAttrDefaults($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_DEFAULTS);
    CreateSingleDeviceTableAttrAlias($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_ALIAS); 
    CreateSingleDeviceTableAttrPublish($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_PUBLISH);
    CreateSingleDeviceTableAttrSubscribe($hash, $devMapName, $map, $attrVal) if($attrName eq $prefix.CTRL_ATTR_NAME_SUBSCRIBE);
  } else {
    # ... oder gleich für alle (dann aus Device Attributes gelesen)
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
    RemoveDeviceSubscriptons($hash, $dev);
  }
}

sub CreateDevicesTable($) {
  my ($hash) = @_;
  # alle zu überwachende Geräte durchgehen und Attribute erfassen
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
  $hash->{+HS_FLAG_INITIALIZED} = 1;
}

sub UpdateSubscriptionsSingleDevice($$) {
  my ($hash, $dev) = @_;
  # Liste der Geräte mit der Liste der Subscriptions abgleichen
  # neue Subscriptions bei Bedarf anlegen und/oder überflüssige löschen
  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
}

sub UpdateSubscriptions($) {
  my ($hash) = @_;
  # Liste der Geräte mit der Liste der Subscriptions abgleichen
  # neue Subscriptions bei Bedarf anlegen und/oder überflüssige löschen
  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
}

sub RemoveDeviceSubscriptons($$) {
  my ($hash,$dev) = @_;
  # alle Subscription kündigen (beim undefine)
  # HS_TAB_NAME_SUBSCRIBE
  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
}

sub RemoveAllSubscripton($) {
  my ($hash) = @_;
  # alle Subscription kündigen (beim undefine)
  # HS_TAB_NAME_SUBSCRIBE
  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
}

sub InitializeDevices($) {
  my ($hash) = @_;
  # alles neu aifbauen
  # Deviceliste neu aufbauen, ggf., alte subscription kündigen, neue abonieren
  #Log3($hash->{NAME},1,">>>>>>>>>>>>>> : !!!");
  CreateDevicesTable($hash);
  UpdateSubscriptions($hash);
}

sub CheckInitialization($) {
  my ($hash) = @_;
  # Prüfen, on interne Strukturen initialisiert sind
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

  # TODO: ggf. umstellen auf: my $events = deviceEvents($dev_hash,1); 
  if( $dev->{NAME} eq "global" ) {
    #Log3($hash->{NAME},1,">>>>>>>>>>>>>> : ".Dumper($dev));
    if( grep(m/^(INITIALIZED|REREADCFG)$/, @{$dev->{CHANGED}}) ) {
      # TODO: Stop/Start($hash): tabelle aufbauen, Start (subscriptions erstellen, anpassen, löschen)
      #InitializeDevices($hash);
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
        # wenn ein überwachtes device, tabelle korrigieren
        RenameDeviceInTable($hash, $old, $new);
      } elsif($s =~ m/^DELETED ([^ ]*)$/) {
        # Device deleted
        my ($name) = ($1);
        #Log3($hash->{NAME},5,"MQTT-GB:DEBUG:> Device deleted: $name");
        # wenn ein überwachtes device, tabelle korrigieren
        DeleteDeviceInTable($hash, $name);
      } elsif($s =~ m/^ATTR ([^ ]*) ([^ ]*) (.*)$/) {
        # Attribut created or changed
        my ($sdev, $attrName, $val) = ($1, $2, $3);
        #Log3($hash->{NAME},1,"MQTT-GB:DEBUG:> attr created/changed: $sdev : $attrName = $val");
        # wenn ein überwachtes device und attr bzw. steuer.attr, tabelle korrigieren
        RefreshDeviceTable($hash, $sdev, $attrName, $val) if(IsObservedAttribute($hash,$attrName));
      } elsif($s =~ m/^DELETEATTR ([^ ]*) ([^ ]*)$/) {
        # Attribut deleted
        my ($sdev, $attrName) = ($1, $2);
        #Log3($hash->{NAME},5,"MQTT-GB:DEBUG:> attr deleted: $sdev : $attrName");
        # wenn ein überwachtes device und attr bzw. steuer.attr, tabelle korrigieren
        RefreshDeviceTable($hash, $sdev, $attrName, undef) if(IsObservedAttribute($hash,$attrName));
      }
    }
    return undef;
  }

  return if( !$main::init_done );

  return "" if(main::IsDisabled($hash->{NAME}));

  CheckInitialization($hash);

  # Prüfen, ob ein überwachtes Gerät vorliegt 
  my $devName = $dev->{NAME}; 
  my $devDataTab = $hash->{+HS_TAB_NAME_DEVICES}; # Gerätetabelle
  return unless defined $devDataTab; # not initialized now or internal error
  my $devDataRecord = $devDataTab->{$devName}; # 
  unless (defined($devDataRecord)) {
    # Prüfen, ob ggf. Default map existiert.
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
      # wenn überwachtes device and reading
      publishDeviceUpdate($hash, $dev, $devreading, $devval);
    }
  }
}

# Definiert Liste der auszuschliessenden Type/Readings-Kombinationen.
#   Parameter:
#     $hash: HASH
#     $valueType: Werteliste im Textformat für TYPE:readings Excludes (getrennt durch Leerzeichen).
#       Ein einzelner Wert bedeutet, dass ein Gerätetyp mit diesem Namen komplett ignoriert wird (also für alle seine Readings).
#       Durch ein Doppelpunkt getrennte Paare werden als Type:Reading interptretiert. 
#       Das Bedeutet, dass an dem gegebenen Type die genannte Reading nicht übertragen wird.
#       Ein Stern anstatt Type oder auch Reading bedeutet, dass alle Readings eines Geretätüps 
#       bzw. genannte Readings an jedem Gerätetyp ignoriert werden.
sub defineGlobalTypeExclude($;$) {
  my ($hash, $valueType) = @_;
  $valueType = AttrVal($hash->{NAME}, CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE, DEFAULT_GLOBAL_TYPE_EXCLUDES) unless defined $valueType;
  $main::attr{$hash->{NAME}}{+CTRL_ATTR_NAME_GLOBAL_TYPE_EXCLUDE} = $valueType;
  # HS_PROP_NAME_GLOBAL_EXCLUDES_TYPE und HS_PROP_NAME_GLOBAL_EXCLUDES_READING

  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
}

# Definiert Liste der auszuschliessenden DeviceName/Readings-Kombinationen.
#   Parameter:
#     $hash: HASH
#     $valueName: Werteliste im Textformat für DeviceName:reading Excludes (getrennt durch Leerzeichen).
#       Ein einzelner Wert bedeutet, dass ein Gerät mit diesem Namen komplett ignoriert wird (also für alle seine Readings).
#       Durch ein Doppelpunkt getrennte Paare werden als DeviceName:Reading interptretiert. 
#       Das Bedeutet, dass an dem gegebenen Gerät die genannte Reading nicht übertragen wird.
#       Ein Stern anstatt Reading bedeutet, dass alle Readings eines Geräts ignoriert werden.
sub defineGlobalDevExclude($;$) {
  my ($hash, $valueName) = @_;
  $valueName = AttrVal($hash->{NAME}, CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE, DEFAULT_GLOBAL_DEV_EXCLUDES) unless defined $valueName;
  $main::attr{$hash->{NAME}}{+CTRL_ATTR_NAME_GLOBAL_DEV_EXCLUDE} = $valueName;
  # HS_PROP_NAME_GLOBAL_EXCLUDES_DEVICES

  # TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>
}

# Setzt Liste der auszuschliessenden Type/Readings-Kombinationenb auf Defaultwerte zurueck (also falls Attribut nicht definiert ist).
sub defineDefaultGlobalExclude($) {
  my ($hash) = @_;  
  defineGlobalTypeExclude($hash, undef);
  defineGlobalDevExclude($hash, undef);
}

# Prueft, ob Type/Reading- oder Geräte/Reading-Kombination von der Uebertragung ausgeschlossen werden soll, 
# oder im Gerät Ignore-Attribut gesetzt ist.
#   Parameter:
#     $hash:    HASH
#     $type:    Geraetetyp
#     $devName: Gerätename
#     $reading: Reading
sub isTypeDevReadingExcluded($$$$) {
  my ($hash, $type, $devName, $reading) = @_;

  # pruefen, ob im Gerät ignore steht
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

sub publishDeviceUpdate($$$$) {
  my ($hash, $devHash, $reading, $val) = @_;
  my $devn = $devHash->{NAME};
  my $type = $devHash->{TYPE};
  # bestimmte bekannte types und readings ausschliessen (vor allem 'transmission-state' in der eigenen Instanz, das fuert sonst zu einem Endlosloop)
  return if($type eq "MQTT_GENERIC_BRIDGE");
  return if($type eq "MQTT");
  return if($reading eq "transmission-state");
  # extra definierte (ansonsten gilt eine Defaultliste) Types/Readings auschliessen.
  return if(isTypeDevReadingExcluded($hash, $type, $devn, $reading));

  #Log3($hash->{NAME},1,"publishDeviceUpdate for $devn, $reading, $val");
  #my $dummy = getDevicePublishRec($hash, ":dummy1", ":dummy2");
  my $pubRec = getDevicePublishRec($hash, $devn, $reading);
  #Log3($hash->{NAME},1,"publishDeviceUpdate pubRec: ".Dumper($pubRec));

  if(defined($pubRec)) {
    my $msgid;

    my $topic = $pubRec->{'topic'};
    my $qos = $pubRec->{'qos'};
    my $retain = $pubRec->{'retain'};
    #Log3($hash->{NAME},1,"publishDeviceUpdate for $devn, $reading, $val, topic: $topic, message: $val");
    if(defined($topic) and defined($val)) {
      $msgid = send_publish($hash->{IODev}, topic => $topic, message => $val, qos => $qos, retain => $retain);
      readingsSingleUpdate($hash,"transmission-state","outgoing publish sent",1);
    }

    $hash->{message_ids}->{$msgid}++ if defined $msgid;
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

sub onmessage($$$) {
  my ($hash,$topic,$message) = @_;
  CheckInitialization($hash);
  if (defined (my $command = $hash->{subscribeSets}->{$topic}->{name})) {
    my $do=1;
    if(defined (my $cmd = $hash->{subscribeSets}->{$topic}->{cmd})) {
      Log3($hash->{NAME},5,"evaluating cmd: $cmd");
      my $name = $hash->{NAME};
      my $device = $hash->{DEF};
      $do=eval($cmd);
      Log3($hash->{NAME},1,"ERROR evaluating $cmd: $@") if($@);
      $do=1 if (!defined($do));
    }
    if($do) {    
      my @args = split ("[ \t]+",$message);
      if ($command eq "") {
        Log3($hash->{NAME},5,"calling DoSet($hash->{DEF}".(@args ? ",".join(",",@args) : ""));
        DoSet($hash->{DEF},@args);
      } else {
        Log3($hash->{NAME},5,"calling DoSet($hash->{DEF},$command".(@args ? ",".join(",",@args) : ""));
        DoSet($hash->{DEF},$command,@args);
      }
    }
  }
}
1;


# Dieses Modul ist eine MQTT-Bridge, die gleichzeitig mehrere FHEM-Devices erfasst und deren Readings 
# per MQTT weiter gibt bzw. aus den eintreffenden MQTT-Nachrichten befüllt.
# Es wird ein <a href="#MQTT">MQTT</a>-Gerät als IODev benötigt.
#
# Die (minimal) Konfiguration der Bridge selbst ist grundsätzlich sehr einfach.
#
# Definition:
#   Im einfachsten Fall reichen schon zwei Zeilen:
#     defmod mqttGeneric MQTT_GENERIC_BRIDGE [prefix] [devspec]
#     attr mqttGeneric IODev <MQTT-Device>
#   Alle Parameterim Define sind optional. 
#   Der erste ist ein Prefix für die Steuerattribute, worüber die zu überwachende Geräte (s.u.) 
#   konfiguriert werden. Dafaultwert ist 'mqtt'. 
#   Wird dieser z.B. als 'hugo' redefiniert, heissen die Steuerungsattribute entsprechend hugoPublish etc.
#   Der zweite Parameter ('devspec') erlaubt die Menge der zu überwachenden Geräten 
#   zu begrenzen (sonst werden einfach alle überwacht, was jedoch Performance kosten kann).
#   s.a. https://fhem.de/commandref_DE.html#devspec
#
# Attribute:
#   IODev
#     Dieses Attribut ist obligatorisch und muss den Namen einer funktionierenden MQTT-Modulinstanz beinhalten.
#
#   disable
#     Wert 1 deaktiviert die Bridge
#
#     Beispiel:
#       attr <dev> disable 1
#
#   globalDefaults
#     Definiert Defaults, die greifen, falls in dem jeweiligen Gerät definierte Werte nicht greifen. s.a. mqttDefaults. 
#
#   globalAlias
#     Definiert Alias, die greifen, falls in dem jeweiligen Gerät definierte Werte nicht greifen. s.a. mqttAlias.
#
#   globalPublish
#     Definiert Topics für die Übertragung per MQTT. Sie greifen, falls in dem jeweiligen Gerät definierte Werte nicht greifen. s.a. mqttPublish.
#
#   globalTypeExclude TODO
#     Definiert (Geräte)Typen und Readings, die nicht übertragen werden. 
#     Ein einzelner Wert bedeutet, dass ein Gerätetyp mit diesem Namen komplett ignoriert wird (also für alle seine Readings).
#     Durch ein Doppelpunkt getrennte Paare werden als Type:Reading interptretiert. 
#     Das Bedeutet, dass an dem gegebenen Type die genannte Reading nicht übertragen wird.
#     Ein Stern anstatt Type oder auch Reading bedeutet, dass alle Readings eines Geretätüps 
#     bzw. genennte Readings an jeddem Gerätetyp ignoriert werden.
#
#     Beispiel:
#       attr <dev> globalTypeExclude MQTT MQTT_GENERIC_BRIDGE:* MQTT_BRIDGE:transmission-state *:baseID
#
#   globalDeviceExclude TODO
#     Definiert Gerätenamen und Readings, die nicht übertragen werden. 
#     Ein einzelner Wert bedeutet, dass ein Geräte mit diesem Namen komplett ignoriert wird (also für alle seine Readings).
#     Durch ein Doppelpunkt getrennte Paare werden als Device:Reading interptretiert. 
#     Das Bedeutet, dass an dem gegebenen Gerät die genannte Reading nicht übertragen wird.
#
#     Beispiel:
#       attr <dev> globalDeviceExclude Test Bridge:transmission-state
#
#
# Für die überwachten Geräte wird die Liste der möglichen Attribute automatisch um mehrere weitere Einträge ergänzt, 
# die alle mit vorher in der Bridge definierten Prefix anfangen. Über diese wird die eigentliche MQTT-Anbindung konfiguriert.
#
# Defaultmäßig werden folgende Attribute verwendet: mqttDefaults, mqttAlias, mqttPublish, mqttSubscribe.
# Sie haben folgende Bedeutung:
#   mqttDefaults 
#     Hier wird eine Liste der "key=value"-Paare erwartet. Folgende Keys sind dabei möglich:
#       'qos' definiert ein Default für MQTT-Paramter 'Quality of Service'.
#       'retain' erlaubt MQTT-Nachrichten als 'retained messages' zu markieren.
#       'base' wird als Variable ($base) bei der Konfiguration von konkreten Topics zur Verfügung gestellt. 
#              Sie kann entweder Text oder eine Perl-Expression enthalten. 
#              Perl-Expression muss in Geschweifte Klammern eingeschlossen werden.
#              In einer Expression können Variablen  verwendet werden.
#              ($reading = Original-Readingname, $device = Devicename, $name = Readingalias (s. mqttAlias). 
#              Ist keine Alias definiert, ist $name=$reading).
#
#     Alle diese werte können durch vorangestelle Prefixe ('pub:' oder 'sub') in ihrer Gültigkeit 
#     nur auf das Senden bzw. Empfangen begrenzt werden. Werte für 'qos' und 'retain' werden nur verwendet, 
#     wenn keine explizite Angaben darüber für ein konkretes Topic gemacht worden sind.
#
#     Beispiel:
#       attr <dev> mqttDefaults base={"/TEST/$device"} pub:qos=0 sub:qos=2 retain=0
#
#   mqttAlias 
#     Dieses Attribut ermöglicht Readings unter einem anderen Namen auf MQTT-Topict zu mappen. 
#     Nur sinnvoll, wenn Topicdefinitionen Perl-Expressions mit entsprechenden Variablen sind.
#     Auch hier werden 'pub:' und 'sub:' Prefixe unterstützt.
#
#     Beispiel:
#       attr <dev> mqttAlias pub:temperature=temp
#
#   mqttPublish
#     Hier werden konkrette Topics definiet und den Readings zugeordnet. 
#     Weiterhin können diese einzeln mit 'qos'- und 'retain'-Flags versehen werden. 
#     Topics können auch als Perl-Expression mit Veriablen definiert werden ($reading, $device, $name, $base).
#     Werte fuer mehrere Readings können auch gemeinsam gleichzeitig definiert werden, 
#     indem sie, mittels '|' getrennt, zusammen angegeben werden.
#     Wird anstatt eines Readingsnamen ein '*' verwendet, gilt diese Definition für alle Readings, 
#     für die keine explizite Angaben gemacht worden.
#
#     Beispiel:
#       attr <dev> mqttPublish temperature:topic={"$base/$name"} temperature:qos=1 temperature:retain=0 *:topic={"$base/$name"} humidity:topic=/TEST/Feuchte
#       attr <dev> mqttPublish temperature|humidity:topic={"$base/$name"} temperature|humidity:qos=1 temperature|humidity:retain=0
#       attr <dev> mqttPublish *:topic={"$base/$name"} *:qos=2 *:retain=0
#
#   mqttSubscribe 
#     Dieses Attribut konfiguriert das Empfangen der MQTT-Nachrichten und deren Mapping auf die Attribute.
#     Die Konfiguration entspricht der für das 'mqttPublish'-Attribut.
#
#     Beispiel:
#       TODO
#
#   mqttIgnore
#     Wird dieses Attribut in einem Gerät gesetzt, wird TODO
#
#   Beispiele: 
#     Bridge für alle möglichen Geräte mit dem Standardprefix:
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE
#       attr mqttGeneric IODev mqtt
#
#     Bridge mit dem Prefix 'mqtt' für drei bestimmte Geräte:
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE mqtt sensor1,sensor2,sensor3
#       attr mqttGeneric IODev mqtt
#
#     Bridge für alle Geräte in einem bestimmten Raum:
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
#     Topicsdefinition nur für bestimmte Readings mit deren gleichzeitigen Umbennenung (Alias):
#       defmod sensor XXX
#       attr sensor mqttAlias temperature=temp humidity=hum
#       attr sensor mqttDefaults base={"/$device/$name"} 
#       attr sensor mqttPublish temperature:topic={$base} humidity:topic={$base}
#
#
#   Beispiel für eine zentralle Konfiguration in der Bridge für alle Devices, die Reading 'temperature' besitzen:
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE 
#       attr mqttGeneric IODev mqtt
#       attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0
#       attr mqttGeneric publish temperature:topic={"/haus/$device/$reading"}
#
#   Beispiel für eine zentralle Konfiguration in der Bridge für alle Devices 
#   (wegen schlechter Übersicht und einer unnötig großen Menge eher nicht zu empfehlen):
#       defmod mqttGeneric MQTT_GENERIC_BRIDGE 
#       attr mqttGeneric IODev mqtt
#       attr mqttGeneric defaults sub:qos=2 pub:qos=0 retain=0
#       attr mqttGeneric publish *:topic={"/haus/$device/$reading"}
#     
#
#   TODOs
#   - Subscribe ist noch nicht implementiert.
#   - damit beim Reconnect Subscriptions sauber wieder augebaut werden, ist ein Patch für IO (00_MQTT) notwendig (client_start und client_stop weiterreichen).



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
       &lt;configAttrPrefix&gt; Prefix für Konfig-Attributeinden Geräten</p>
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

=end html

=item summary_DE MQTT_GENERIC_BRIDGE acts as a bridge for any fhem-devices and mqtt-topics
=begin html_DE

<a name="MQTT_GENERIC_BRIDGE"></a>
<h3>MQTT_GENERIC_BRIDGE</h3>
<ul>

  <p>Dieses Modul ist eine MQTT-Bridge, die gleichzeitig mehrere FHEM-Devices erfasst und deren Readings 
     per MQTT weiter gibt bzw. aus den eintreffenden MQTT-Nachrichten befüllt.</p>
  <p>Es wird ein <a href="#MQTT">MQTT</a>-Gerät als IODev benötigt.</p>
  <p>Die (minimal) Konfiguration der Bridge selbst ist grundsätzlich sehr einfach.</p>
  <a name="MQTT_GENERIC_BRIDGEdefine"></a>
  <p><b>Define</b></p>
  <ul>
    <p><code>define &lt;name&gt; MQTT_GENERIC_BRIDGE [&lt;configAttrPrefix&gt;] [&lt;dev-spec&gt;]</code></p>
    <p>Specifies the generic bridge. Publish/Subscriptions must be definen with the Device atributen<br/>
       &lt;configAttrPrefix&gt; Prefix für Konfig-Attributeinden Geräten</p>
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
