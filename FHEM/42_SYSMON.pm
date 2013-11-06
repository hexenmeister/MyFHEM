
# $Id: $

package main;

use strict;
use warnings;
#use Data::Dumper;

my $VERSION = "0.9";

sub
SYSMON_Initialize($)
{
  my ($hash) = @_;
  
  Log 5, "SYSMON Initialize: ".$hash->{NAME};

  $hash->{DefFn}    = "SYSMON_Define";
  $hash->{UndefFn}  = "SYSMON_Undefine";
  $hash->{GetFn}    = "SYSMON_Get";
  $hash->{SetFn}    = "SYSMON_Set";
  $hash->{AttrFn}   = "SYSMON_Attr";
  $hash->{AttrList} = "filesystems disable:0,1 raspberrytemperature:0,1,2 uptime:1,2 ".
                       $readingFnAttributes;
}

#####################################


sub
SYSMON_Define($$)
{
  my ($hash, $def) = @_;
  
  logF($hash, "Define", "$def");
  #Log 5, "SYSMON Define: ".$hash->{NAME};

  my @a = split("[ \t][ \t]*", $def);

  return "Usage: define <name> SYSMON [interval]"  if(@a < 2);

  #my $interval = 60;
  #if(int(@a)>=3) { $interval = $a[2]; }
  if(int(@a)>=3) 
  { 
  	SYSMON_setInterval($hash, $a[2]);
  } else {
    SYSMON_setInterval($hash, undef);
  }
  #if( $interval < 60 ) { $interval = 60; }

  #delete( $hash->{INTERVAL_FS} );
  
  $hash->{STATE} = "Initialized";
  #$hash->{INTERVAL} = $interval;

  #$starttime = time() unless defined($starttime);
  $hash->{DEF_TIME} = time() unless defined($hash->{DEF_TIME});

  RemoveInternalTimer($hash);
  InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SYSMON_Update", $hash, 0);

  #$hash->{LOCAL} = 1;
  #SYSMON_Update($hash); #-> so nicht. hat im Startvorgang gelegentlich (oft) den Server 'aufgehängt'
  #delete $hash->{LOCAL};  
  
  return undef;
}

sub
SYSMON_setInterval($$)
{
	my ($hash, $def) = @_;
	
	my $interval = 60;
  if(defined($def)) {$interval = $def;}
  if($interval < 60) {$interval = 60;}

  $hash->{INTERVAL} = $interval;
}

sub
SYSMON_Undefine($$)
{
  my ($hash, $arg) = @_;
  
  logF($hash, "Undefine", "");
  #Log 5, "SYSMON Undefine: ".$hash->{NAME};

  RemoveInternalTimer($hash);
  return undef;
}

sub
SYSMON_Get($@)
{
  my ($hash, @a) = @_;

  my $name = $a[0];
  
  if(@a < 2) 
  {
  	logF($hash, "Get", "@a: get needs at least one parameter");
  	#Log 5, "SYSMON (".$hash->{NAME}.") Get $name : get needs at least one parameter";
    return "$name: get needs at least one parameter";
  }
  
  my $cmd= $a[1];
  
  logF($hash, "Get", "@a");
  #Log 5, "SYSMON (".$hash->{NAME}.") Get $name $cmd";

  if($cmd eq "update")
  {
  	$hash->{LOCAL} = 1;
  	SYSMON_Update($hash);
  	delete $hash->{LOCAL};
  	return undef;
  }
  
  if($cmd eq "list") {
    my $map = SYSMON_obtainParameters($hash);
    my $ret = "";
    foreach my $name (keys %{$map}) {
  	  my $value = $map->{$name};
  	  $ret = "$ret\n".sprintf("%-20s %s", $name, $value);
    }
    return $ret;
  }
  
  if($cmd eq "version")
  {
  	return $VERSION;
  }

  if($cmd eq "interval")
  {
  	return $hash->{INTERVAL};
  }
  
  return "Unknown argument $cmd, choose one of list:noArg update:noArg interval:noArg version:noArg";
}

sub
SYSMON_Set($@)
{
  my ($hash, @a) = @_;

  my $name = $a[0];
  
  if(@a < 2) 
  {
  	logF($hash, "Set", "@a: set needs at least one parameter");
  	#Log 5, "SYSMON (".$hash->{NAME}.") Set $name : set needs at least one parameter";
    return "$name: set needs at least one parameter";
  }
  
  my $cmd= $a[1];
  
  logF($hash, "Set", "@a");
  #Log 5, "SYSMON (".$hash->{NAME}.") Set $name $cmd";

  if($cmd eq "interval")
  {
  	if(@a < 3) {
  		logF($hash, "Set", "$name: not enought parameters");
      return "$name: not enought parameters";
  	} 
  	#my $val= $a[2];
  	SYSMON_setInterval($hash, $a[2]);
  	#$hash->{INTERVAL} = $val;
  	return $cmd ." set to ".($hash->{INTERVAL});
  }

  return "Unknown argument $cmd, choose one of interval";
}

sub
SYSMON_Attr($$$)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;
  
  Log 5, "SYSMON Attr: $cmd $name $attrName $attrVal";

  $attrVal= "" unless defined($attrVal);
  #my $orig = $attrVal;
  my $orig = AttrVal($name, $attrName, "");

  if( $cmd eq "set" ) {# set, del
    if( $orig ne $attrVal ) {
    	
    	if($attrName eq "disable")
      {
        my $hash = $main::defs{$name};
        RemoveInternalTimer($hash);
      	if($attrVal ne "0")
      	{
      		InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SYSMON_Update", $hash, 0);
      	}
       	$hash->{LOCAL} = 1;
  	    SYSMON_Update($hash);
  	    delete $hash->{LOCAL};
      }
    	
      $attr{$name}{$attrName} = $attrVal;
      #return $attrName ." set to ". $attrVal;
      return undef;
    }
  }
  return;
}

sub
SYSMON_Update($)
{
  my ($hash) = @_;
  
  logF($hash, "Update", "");
  #Log 5, "SYSMON Update: ".$hash->{NAME};
  
  my $name = $hash->{NAME};

  if(!$hash->{LOCAL}) {
    RemoveInternalTimer($hash);
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "SYSMON_Update", $hash, 1);
  }

  readingsBeginUpdate($hash);

  if( AttrVal($name, "disable", "") eq "1" ) 
  {
  	logF($hash, "Update", "disabled");
  	$hash->{STATE} = "Inactive";
  } else {
  
    my $map = SYSMON_obtainParameters($hash);
 
    $hash->{STATE} = "Active";
    #my $state = $map->{"loadavg"};
    #readingsBulkUpdate($hash,"state",$state);
  
    foreach my $name (keys %{$map}) {
  	  my $value = $map->{$name};
  	  Log 3, "SYSMON DEBUG: ---> ".$name."=".$value;
  	  readingsBulkUpdate($hash,$name,$value);
    }
  
  }

  readingsEndUpdate($hash,defined($hash->{LOCAL} ? 0 : 1));
}


sub
SYSMON_obtainParameters($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	
	my $map;
  
  $map = SYSMON_getUptime($hash, $map);
  $map = SYSMON_getFHEMUptime($hash, $map);
  $map = SYSMON_getLoadAvg($hash, $map);
  $map = SYSMON_getRamAndSwap($hash, $map);
  $map = SYSMON_getCPUTemp($hash, $map);
  $map = SYSMON_getCPUFreq($hash, $map);
  
  my $filesystems = AttrVal($name, "filesystems", undef);
  if(defined $filesystems) 
  {
    my @filesystem_list = split(/,\s*/, trim($filesystems));
    foreach (@filesystem_list)
    {
    	$map = SYSMON_getFileSystemInfo($hash, $map, "$_");
    }
  } else {
    $map = SYSMON_getFileSystemInfo($hash, $map, "/dev/root");
  }
  
  return $map;
}

sub
SYSMON_getUptime($$)
{
	my ($hash, $map) = @_;
	
	my $uptime_str = qx(cat /proc/uptime );
  my ($uptime, $idle) = split(/\s+/, trim($uptime_str));
	
	$map->{"uptime"}=sprintf("%d",$uptime);
	#$map->{"uptime_text"} = sprintf("%d days, %02d hours, %02d minutes, %02d seconds",SYSMON_decode_time_diff($uptime));
	$map->{"uptime_text"} = sprintf("%d days, %02d hours, %02d minutes",SYSMON_decode_time_diff($uptime));
	
  $map->{"idletime"}=sprintf("%d",$idle);
	#$map->{"idletime_text"} = sprintf("%d days, %02d hours, %02d minutes, %02d seconds",SYSMON_decode_time_diff($idle));
	$map->{"idletime_text"} = sprintf("%d days, %02d hours, %02d minutes",SYSMON_decode_time_diff($idle));

  my $idle_percent = $idle/$uptime*100;  
	$map->{"idletime_percent"} = sprintf ("%.2f %",$idle_percent);
	
	return $map; 
}

sub
SYSMON_getFHEMUptime($$)
{
	my ($hash, $map) = @_;
	
	if(defined ($hash->{DEF_TIME})) {
	  my $fhemuptime = time()-$hash->{DEF_TIME};
	  $map->{"fhemuptime"} = sprintf("%d",$fhemuptime);
	  $map->{"fhemuptime_text"} = sprintf("%d days, %02d hours, %02d minutes",SYSMON_decode_time_diff($fhemuptime));
  }

	return $map;
}

sub
SYSMON_getLoadAvg($$)
{
	my ($hash, $map) = @_;
	
	my $la_str = qx(cat /proc/loadavg );
  my ($la1, $la5, $la15, $prc, $lastpid) = split(/\s+/, trim($la_str));
	
	$map->{"loadavg"}="$la1 $la5 $la15";
  $map->{"load"}="$la1";
	$map->{"load5"}="$la5";
	$map->{"load15"}="$la15";
	
	return $map; 
}

#------------------------------------------------------------------------------
# leifert Raspberry Pi CPU Temperature
#------------------------------------------------------------------------------
sub
SYSMON_getCPUTemp($$)
{
	my ($hash, $map) = @_;
	
	my $val = qx( cat /sys/class/thermal/thermal_zone0/temp );
  my $val_txt = sprintf("%.2f", $val/1000);
  $map->{"cpu_temp"}="$val_txt";
  my $t_avg = sprintf( "%.1f", (3 * ReadingsVal($hash->{NAME},"cpu_temp_avg",$val_txt) + $val_txt ) / 4 );
  $map->{"cpu_temp_avg"}="$t_avg";
	
	return $map; 
}

sub
SYSMON_getCPUFreq($$)
{
	my ($hash, $map) = @_;
	
	my $val = qx( cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq );
  my $val_txt = sprintf("%d", $val/1000);
  $map->{"cpu_freq"}="$val_txt";
	
	return $map; 
}

#------------------------------------------------------------------------------
# Liefert Werte für RAM und SWAP (Gesamt, Verwendet, Frei).
#------------------------------------------------------------------------------
sub SYSMON_getRamAndSwap($$)
{
  my ($hash, $map) = @_;
  
  my @speicher = qx(free -m);
  
  shift @speicher;
  my ($fs_desc, $total, $used, $free, $shared, $buffers, $cached) = split(/\s+/, trim($speicher[0]));
  shift @speicher;
  my ($fs_desc2, $total2, $used2, $free2, $shared2, $buffers2, $cached2) = split(/\s+/, trim($speicher[0]));
  
  if($fs_desc2 ne "Swap:")
  {
    shift @speicher;
    ($fs_desc2, $total2, $used2, $free2, $shared2, $buffers2, $cached2) = split(/\s+/, trim($speicher[0]));
  }
  
  my $ram;
  my $swap;
  my $percentage_ram;
  my $percentage_swap;
  
  $percentage_ram = sprintf ("%.2f", (($used - $buffers - $cached) / $total * 100), 0);
  $ram = "Total: ".$total." MB, Used: ".($used - $buffers - $cached)." MB (".$percentage_ram." %), Free: ".($free + $buffers + $cached)." MB";
  
  $map->{"ram"} = $ram;
  
  # if no swap present, total2 is zero -> prevent division by zero
  if($total2 > 0)
  {
    $percentage_swap = sprintf ("%.2f", ($used2 / $total2 * 100), 0);
    $swap = "Total: ".$total2." MB, Used: ".$used2." MB  (".$percentage_swap." %), Free: ".$free2." MB";
  }
  else
  {
    $swap = "n/a"
  }
  
  $map->{"swap"} = $swap;

  return $map; 
}

#------------------------------------------------------------------------------
# Liefert Füllstand für das angegebene Dateisystem (z.B. '/dev/root', '/dev/sda1' (USB stick)).
# Eingabeparameter: HASH; MAP; FS-Bezeichnung
#------------------------------------------------------------------------------
sub SYSMON_getFileSystemInfo ($$$)
{
	my ($hash, $map, $fs) = @_;
  
  # my @filesystems = qx(df /dev/root);
  my $disk = "df ".$fs." -m 2>&1"; # in case of failure get string from stderr

  my @filesystems = qx($disk);

  # if filesystem is not present, output goes to stderr, i.e. @filesystems is empty
  shift @filesystems;
  #Log 3, "SYSMON DEBUG: ---> filesystems:=".$filesystems[0];
  if (index($filesystems[0], $fs) >= 0) # check if filesystem available -> gives failure on console
  {
    my ($fs_desc, $total, $used, $available, $percentage_used, $mnt_point) = split(/\s+/, $filesystems[0]);
    #my $out_txt = $fs_desc." at ".$mnt_point." => Total: ".$total." MB, Used: ".$used." MB (".$percentage_used."), Available: ".$available." MB";
    my $out_txt = "Total: ".$total." MB, Used: ".$used." MB (".$percentage_used."), Available: ".$available." MB";
    $map->{"fs[$mnt_point]"} = $out_txt; 
  }

  return $map;
}

#------------------------------------------------------------------------------
# Übersetzt Sekunden (Dauer) in Tage/Stunden/Minuten/Sekunden
#------------------------------------------------------------------------------
sub SYSMON_decode_time_diff($)
{
  my $s = shift;

  my $d = int($s/86400);
  $s -= $d*86400;
  my $h = int($s/3600);
  $s -= $h*3600;
  my $m = int($s/60);
  $s -= $m*60;

  return ($d,$h,$m,$s);
}
 
#
# Logging: FUnkrionsaufrufe
#   Parameter: HASH, Funktionsname, Message
#
sub logF($$$)
{
	my ($hash, $fname, $msg) = @_;
  #Log 5, "SYSMON $fname (".$hash->{NAME}."): $msg";
  Log 5, "SYSMON $fname $msg";
}


1;

=pod
=begin html

<a name="SYSMON"></a>
<h3>SYSMON</h3>
TODO
  <b>Define</b>
  
    <code>define &lt;name&gt; SYSMON ...</code><br>
    <br>

  TODO
=end html
=cut
