#------------------------------------------------------------------------------
# $Id: 99_RPiUtils.pm $ 05/30/2013
#
# call in fhem (for showing):
# define <name> weblink htmlCode {ShowRPiValues()}
# attr <name> room <name_room>
#
# call in fhem (for logging):
# define <name> dummy
# attr <name> room <name_room>
# define <name_log> FileLog ./log/<filename>-%Y-%m.log <name>
# attr <name_log> room <name_room>
# define <name_at> at +*00:01 { fhem("trigger <name> ".RPiTemp(" ")) }
#  or
# define <name_at> at +*00:01 { fhem("trigger <name> ".RPiRamSwap("R")) }
#  or
# define <name_at> at +*00:01 { fhem("trigger <name> ".RPiRamSwap("S")) }
#  or
# define <name_at> at +*00:01 { fhem("trigger <name> ".RPiFileSystem("", "/dev/root")) }
#  or
# define <name_at> at +*00:01 { fhem("trigger <name> ".RPiFileSystem("", "/dev/sda1")) }
#  or
# define <name_at> at +*00:01 { fhem("trigger <name_at> ".RPiNetwork("", "eth0")) }
#  or
# define <name_at> at +*00:01 { fhem("trigger <name_at> ".RPiNetwork("", "wlan0")) }
# attr <name_at> room <name_room>
#
# RPiTemp, RPiRamSwap, RPiFileSystem:
# parameter "I" optimizes output for webfronted, none for logging
# RPiRamSwap: parameter "R" for RAM, "S" for swap
#
# programming:
# initial module by Jörg Wiemann
# https://groups.google.com/forum/?fromgroups#!topic/fhem-users/cfefH97QeY4
# corrections by Prof. Dr. Peter A. Henning
# modifications by Peter Mühlbeyer:
#  - WLAN added, CPU frequency changed, added USB stick (/dev/sda1)
#  - changed german words to english
#  - changed sequence of filesystem values to match others
#  - implemented division by zero check if no swap is present
#  - implemented filesystem and USB stick check in one function w/ parameter
#  - implemented WLAN and LAN check in one function w/ parameter
#  - date implemented (Raspberry Pi does not have RTC)
#
# bugs/improvements:
#  - get rid of sequence numbering and implement intelligent sorting
#------------------------------------------------------------------------------

package main;

use strict;
use warnings;
use POSIX;

#------------------------------------------------------------------------------
# Initialization of fhem module, defines exact name of function (and other stuff)
#------------------------------------------------------------------------------
sub RPiUtils_Initialize($$)
{
  my ($hash) = @_;
}

#------------------------------------------------------------------------------
# gets the RAM and SWAP values
#------------------------------------------------------------------------------
sub RPiRamSwap ($)
{
  my $Para = shift;
  my $ram;
  my $swap;
  my $percentage;
  my @retvalues;
  my @speicher = qx(free);
  shift @speicher;

  my ($fs_desc, $total, $used, $free, $shared, $buffers, $cached) = split(/\s+/, trim($speicher[0]));

  shift @speicher;
  my ($fs_desc2, $total2, $used2, $free2, $shared2, $buffers2, $cached2) = split(/\s+/, trim($speicher[0]));

  if($fs_desc2 ne "Swap:")
  {
    shift @speicher;
    ($fs_desc2, $total2, $used2, $free2, $shared2, $buffers2, $cached2) = split(/\s+/, trim($speicher[0]));
  }

  $used = sprintf ("%.2f", $used / 1000);
  $buffers = sprintf ("%.2f", $buffers / 1000);
  $cached = sprintf ("%.2f", $cached / 1000);
  $total = sprintf ("%.2f", $total / 1000);
  $free = sprintf ("%.2f", $free / 1000);

  $used2 = sprintf ("%.2f", $used2 / 1000);
  $total2 = sprintf ("%.2f", $total2 / 1000);
  $free2 = sprintf ("%.2f", $free2 / 1000);

  if($Para eq "I")
  {
    $percentage = sprintf ("%.2f", (($used - $buffers - $cached) / $total * 100), 0);
    $ram = "RAM: " . $percentage . "%" . "<br>" . "Free: " . ($free + $buffers + $cached) . " MB" . "<br>" . "Used: " . ($used - $buffers - $cached) . " MB" . "<br>" . "Total: " . $total . " MB";
    push (@retvalues, $ram);

    # if no swap present, total2 is zero -> prevent division by zero
    if($total2 > 0)
    {
      $percentage = sprintf ("%.2f", ($used2 / $total2 * 100), 0);
      $swap = "Swap: " . $percentage . "%" . "<br>" . "Free: " . $free2 . " MB" . "<br>" . "Used: " . $used2 . " MB" . "<br>" . "Total: " . $total2 . " MB";
    }
    else
    {
      $swap = "n/a"
    }
    push (@retvalues, $swap);

    return @retvalues;
  } 
  elsif($Para eq "R")
  {
    $percentage = sprintf ("%.2f", (($used - $buffers - $cached) / $total * 100), 0);
    $ram = "R: " . $percentage . " F: " . ($free + $buffers + $cached) . " U: " . ($used - $buffers - $cached) . " T: " . $total;
    return $ram;

  } 
  elsif($Para eq "S")
  {
    $percentage = sprintf ("%.2f", ($used2 / $total2 * 100), 0);
    $swap = "R: " . $percentage . " F: " . $free2 . " U: " . $used2 . " T: " . $total2 . " MB";
    return $swap;
  }
  else
  {
    return "Fehler";
  }
  return "Fehler";
}

#------------------------------------------------------------------------------
# gets the values for CPU temperature
#------------------------------------------------------------------------------
sub RPiTemp ($)
{

  my $Para = shift;
  my $Temperatur;

  if($Para eq "I")
  {
    $Temperatur = sprintf ("%.2f", qx(cat /sys/class/thermal/thermal_zone0/temp) / 1000);
  }
  else
  {
    $Temperatur = "T: ".sprintf ("%.2f", qx(cat /sys/class/thermal/thermal_zone0/temp) / 1000);
  }

  return $Temperatur;
}

#------------------------------------------------------------------------------
# gets the values for CPU speed
#------------------------------------------------------------------------------
sub RPiCPUSpeed ()
{
  # /proc/cpuinfo gives the speed in BogoMIPS and not in MHz, for overclocking
  # the MHz value is more interesting
  # my $CPUSpeed = qx(cat /proc/cpuinfo | grep "BogoMIPS" | sed 's/[^0-9\.]//g');
  # original thread from Jörg
  # RPiCPUSpeed" => substr(qx(cat /proc/cpuinfo | grep BogoMIPS),11).' MHz',
  
  # comments for unix/perl newbie, can be deleted
  # drei letzte Zeichen löschen mit sed: sed -e 's/.\{3\}$//' -> funktioniert nicht
  # letztes Zeichen löschen mit sed: sed 's/.$//' (3 mal) -> funktioniert nicht
  # drei letzte Zeichen löschen mit sed: sed 's/...\$//' sollte funktionieren
  
  my $CPUSpeed = qx(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq | sed 's/[^0-9\.]//g') / 1000;

  return $CPUSpeed;
}

#------------------------------------------------------------------------------
# gets the uptime of Raspberry Pi
#------------------------------------------------------------------------------
sub RPiUpTime ()
{

  my @uptime = split(/ /, qx(cat /proc/uptime));
  my $seconds = $uptime[0];
  my $y = floor($seconds / 60/60/24/365);
  my $d = floor($seconds/60/60/24) % 365;
  my $h = floor(($seconds / 3600) % 24);
  my $m = floor(($seconds / 60) % 60);
  my $s = $seconds % 60;

  my $string = '';

  if($y > 0)
  {
    my $yw = $y > 1 ? ' years ' : ' year ';
    $string .= $y . $yw . '<br>';
  }

  if($d > 0)
  {
    my $dw = $d > 1 ? ' days ' : ' day ';
    $string .= $d . $dw . '<br>';
  }

  if($h > 0)
  {
    my $hw = $h > 1 ? ' hours ' : ' hour ';
    $string .= $h . $hw . '<br>';
  }

  if($m > 0)
  {
    my $mw = $m > 1 ? ' minutes ' : ' minute ';
    $string .= $m . $mw . '<br>';
  }

  if($s > 0)
  {
    my $sw = $s > 1 ? ' seconds ' : ' second ';
    $string .= $s . $sw . '<br>';
  }

  return $string;
}

#------------------------------------------------------------------------------
# gets the values for filesystems (/dev/root or USB stick on /dev/sda1)
#------------------------------------------------------------------------------
sub RPiFileSystem ($$)
{
  my ($Para, $disk) = @_;
  my $out;
  # my @filesystems = qx(df /dev/root);
  $disk = "df ".$disk." 2>&1"; # in case of failure get string from stderr

  my @filesystems = qx($disk);

  # if filesystem is not present, output goes to stderr, i.e. @filesystems is empty
  shift @filesystems;
  if (index($filesystems[0], "dev") >= 0) # check if filesystem available -> gives failure on console
  {
    my ($fs_desc, $all, $used, $avail, $fused) = split(/\s+/, $filesystems[0]);

    if($Para eq "I")
    {
      $out = "Free: ".sprintf ("%.2f", (($avail)/1024))." MB <br>"."Used: ".sprintf ("%.2f", (($used)/1024))." MB <br>"."Total: ".sprintf ("%.2f", (($all)/1024))." MB";
    }
    else
    {
      $out = " A: ".sprintf ("%.2f", (($avail)/1024))." U: ".sprintf ("%.2f", (($used)/1024))." T: ".sprintf ("%.2f", (($all)/1024));
    }
  }
  else {$out = "n/a"};

  return $out;
}

#------------------------------------------------------------------------------
# gets the the amout of traffic over the network (LAN or WLAN): eth0 or wlan0
#------------------------------------------------------------------------------
sub RPiNetwork ($$)
{
  my ($Para, $Nettype) = @_;

  # my $Para = shift;
  # my $Nettype = shift;
  my $network;
  my @dataThroughput;

  # original: my $dataThroughput = qx(ifconfig eth0 | grep RX\\ bytes);
  # explanation: grep RX\ bytes (\ is needed for grep to indicate additional text, \ for perl)

  # next line does not work, therefore other (unintelligent) solution
  # $Nettype = "ifconfig ".$Nettype." | grep RX\\ bytes");

  # in case of network not present get failure from stderr (2>&1)
  if ("$Nettype" eq "eth0") {@dataThroughput = qx(ifconfig eth0 2>&1);}
  if ("$Nettype" eq "wlan0") {@dataThroughput = qx(ifconfig wlan0 2>&1);}

  if (not grep(/Fehler/, @dataThroughput)) # check if network available
  {

    # perform grep from above
    @dataThroughput = grep(/RX bytes/, @dataThroughput); # reduce more than one line to only one line

    # change array into scalar variable
    my $dataThroughput = $dataThroughput[0];

    # remove RX bytes or TX bytes from string
    $dataThroughput =~ s/RX bytes://;
    $dataThroughput =~ s/TX bytes://;
    $dataThroughput = trim($dataThroughput);

    @dataThroughput = split(/ /, $dataThroughput); # return of split is array

    my $rxRaw = $dataThroughput[0] / 1024 / 1024;
    my $txRaw = $dataThroughput[4] / 1024 / 1024;
    my $rx = sprintf ("%.2f", $rxRaw, 2);
    my $tx = sprintf ("%.2f", $txRaw, 2);
    my $totalRxTx = $rx + $tx;

    if($Para eq "I")
    {
      # if no traffic over network, most probably network is not present
      if($totalRxTx eq "0")
      {
        $network = "n/a";
      }
      else
      {
        $network = "Received: " . $rx . " MB" . "<br>" . "Sent: " . $tx . " MB" . "<br>" . "Total: " . $totalRxTx . " MB";
      }
    }
    else
    {
      $network = "R: " . $rx . " S: " . $tx . " T: " . $totalRxTx;
    }
  }
  else {$network = "n/a";}

  return $network;
}

my $Datum = `date "+%d.%m.20%y %H.%M.%S"`;

#------------------------------------------------------------------------------
# shows the values on the screen
#------------------------------------------------------------------------------
sub ShowRPiValues ()
{
  my @RamValues = RPiRamSwap("I");
  my %RPiValues =
  (
    "0. Date" => $Datum,
    "1. CPU temperature" => RPiTemp("I").' &deg;C',
    "2. CPU frequency" => RPiCPUSpeed().' MHz',
    "3. Up time" => RPiUpTime(),
    "4. RAM" => $RamValues[0], 
    "5. Swap" => $RamValues[1],
    "6. File system" => RPiFileSystem("I", "/dev/root"),
    "7. USB stick" => RPiFileSystem("I", "/dev/sda1"),
    "8. Ethernet" => RPiNetwork("I", "eth0"),
    "9. WLAN" => RPiNetwork("I", "wlan0"),
  );

  my $tag;
  my $value;
  my $div_class="";

  my $htmlcode = '<div  class="'.$div_class."\"><table>\n";

  foreach $tag (sort keys %RPiValues)
  {
    $htmlcode .= "<tr><td valign='top'>$tag : </td><td>$RPiValues{$tag}</td></tr>\n";
  }

# if necessary use summarizing end line
#  $htmlcode .= "<tr><td></td></tr>\n";
  $htmlcode .= "</table></div><br>";
#  $htmlcode .= "--------------------------------------------------------------------------";

  return $htmlcode;
}

1;
#------------------------------------------------------------------------------
