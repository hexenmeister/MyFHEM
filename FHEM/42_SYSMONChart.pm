################################################################
# (c) 2015 Sebastian Grebe (snx8)
#
# CHANGELOG
# VERSION  DATE        AUTHOR  CHANGES
# 0.1b     2015-05-23  snx8    finished first implementation..
#
# TODO
# - Netzwerk-Daten einbauen
# - Automatische Aktualisierung bei Änderung der entsprechenden
#   SYSMON-Readings (notify)
# - Automatische Anpassung der Oberfläche ohne Browser-Refresh
# - Daten von SYSMON nur holen, wenn neue Daten ermittelt
#   wurden (SYSMON Refresh-Interval berücksichtigen)
################################################################

package main;

use strict;
use warnings;

my $VERSION = "0.1b";

use constant {
  DEFAULT_ITEMS => 'uf,us,ct,cl,cf,mr,ms,fs|fs_root',
  DEFAULT_LABEL => { uf => 'uptime fhem',
                     us => 'uptime system',
                     ct => 'cpu temp',
                     cl => 'cpu% load',
                     cf => 'cpu% freq',
                     mr => 'mem ram',
                     ms => 'mem swap',
                     fs => 'fs %',
                     'fs|fs_root' => 'fs root' },
  DEFAULT_COLOR_BORDER => 'black',
  DEFAULT_COLOR_FILL => 'tan',
  DEFAULT_COLOR_TEXT =>  '', # use font color by style..
  DEFAULT_COLOR_MIN_AVG => 'lightsalmon',
  DEFAULT_COLOR_AVG_MAX => 'lightgreen',
  HTML_TITLE_SIMPLE => '<div>#title#</div>',
  HTML_TITLE_LINK => '<div><a href="?detail=#link#">#title#</a></div>',
  HTML_ROW => ''
  . '<tr>'
  . '  <td>#name#</td>'
  . '  <td>#value#</td>'
  . '</tr>',
  HTML_BAR_SIMPLE => ''
  . '<div style="position:relative; cursor:default; width:200px; border:1px solid #colorBorder#;'
  . '            height:1.5em; text-align:center; color:#colorText#;'
  . '            background:   -moz-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:       -webkit-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:-webkit-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:     -o-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:    -ms-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:        linear-gradient(to right,#colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '           ">#text#</div>',
  HTML_BAR_STAT => ''
  . '<div onclick="tgl(this)" style="position:relative; cursor:default; height:1.8em; width:200px; border:1px solid #colorBorder#; overflow:hidden;">'
  . '  <div style="height:100%; padding-top:.3em; text-align:center; color:#colorText#;'
  . '            transition: font-size .4s, padding-top .4s;'
  . '            background:   -moz-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:       -webkit-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:-webkit-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:     -o-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:    -ms-linear-gradient(left,    #colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '            background:        linear-gradient(to right,#colorFill# #value#%,rgba(0,0,0,0) #value#%);'
  . '           " title="min: #textMin# | avg: #textAvg# | max: #textMax#"'
  . '            text="#text#" stat="#textMin# < #textAvg# < #textMax#"'
  . '            >#text#</div>'
  . '  <div style="height:.3em; position:absolute; top:0; width:100%; overflow:hidden;'
  . '            background:   -moz-linear-gradient(left,    rgba(0,0,0,0) #valueMin#%,#colorPeak# #valueMin#%,#colorPeak# #valueMin2#%,#colorMinAvg# #valueMin#%,#colorMinAvg# #valueAvg#%,#colorPeak# #valueAvg#%,#colorPeak# #valueAvg2#%,#colorAvgMax# #valueAvg#%,#colorAvgMax# #valueMax#%,#colorPeak# #valueMax#%,#colorPeak# #valueMax2#%,rgba(0,0,0,0) #valueMax#%);'
  . '            background:       -webkit-gradient(left,    rgba(0,0,0,0) #valueMin#%,#colorPeak# #valueMin#%,#colorPeak# #valueMin2#%,#colorMinAvg# #valueMin#%,#colorMinAvg# #valueAvg#%,#colorPeak# #valueAvg#%,#colorPeak# #valueAvg2#%,#colorAvgMax# #valueAvg#%,#colorAvgMax# #valueMax#%,#colorPeak# #valueMax#%,#colorPeak# #valueMax2#%,rgba(0,0,0,0) #valueMax#%);'
  . '            background:-webkit-linear-gradient(left,    rgba(0,0,0,0) #valueMin#%,#colorPeak# #valueMin#%,#colorPeak# #valueMin2#%,#colorMinAvg# #valueMin#%,#colorMinAvg# #valueAvg#%,#colorPeak# #valueAvg#%,#colorPeak# #valueAvg2#%,#colorAvgMax# #valueAvg#%,#colorAvgMax# #valueMax#%,#colorPeak# #valueMax#%,#colorPeak# #valueMax2#%,rgba(0,0,0,0) #valueMax#%);'
  . '            background:     -o-linear-gradient(left,    rgba(0,0,0,0) #valueMin#%,#colorPeak# #valueMin#%,#colorPeak# #valueMin2#%,#colorMinAvg# #valueMin#%,#colorMinAvg# #valueAvg#%,#colorPeak# #valueAvg#%,#colorPeak# #valueAvg2#%,#colorAvgMax# #valueAvg#%,#colorAvgMax# #valueMax#%,#colorPeak# #valueMax#%,#colorPeak# #valueMax2#%,rgba(0,0,0,0) #valueMax#%);'
  . '            background:    -ms-linear-gradient(left,    rgba(0,0,0,0) #valueMin#%,#colorPeak# #valueMin#%,#colorPeak# #valueMin2#%,#colorMinAvg# #valueMin#%,#colorMinAvg# #valueAvg#%,#colorPeak# #valueAvg#%,#colorPeak# #valueAvg2#%,#colorAvgMax# #valueAvg#%,#colorAvgMax# #valueMax#%,#colorPeak# #valueMax#%,#colorPeak# #valueMax2#%,rgba(0,0,0,0) #valueMax#%);'
  . '            background:        linear-gradient(to right,rgba(0,0,0,0) #valueMin#%,#colorPeak# #valueMin2#%,#colorMinAvg# #valueMin#%,#colorMinAvg# #valueAvg#%,#colorPeak# #valueAvg#%,#colorAvgMax# #valueAvg2#%,#colorAvgMax# #valueMax#%,#colorPeak# #valueMax2#%,rgba(0,0,0,0) #valueMax#%);'
  . '           " title="min: #textMin# | avg: #textAvg# | max: #textMax#"></div>'
  . '</div>',
  HTML_SCRIPT => ''
  . '<script>'
  . 'function tgl(o) {'
  . '  var m=o.getElementsByTagName("div")[0];'
  . '  if (m.mam=="yes") { m.mam=""; m.innerHTML=m.getAttribute("text"); m.style.fontSize="1em"; m.style.paddingTop=".3em"; }'
  . '  else { m.mam="yes"; m.innerHTML=m.getAttribute("stat"); m.style.fontSize=".8em"; m.style.paddingTop=".6em"; }'
  . '}'
  . '</script>'
};

sub
SYSMONChart_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn} = "SYSMONChart_Define";
  $hash->{UndefFn} = "SYSMONChart_Undefine";
  $hash->{AttrFn} = "SYSMONChart_Attr";
  $hash->{FW_summaryFn} = "SYSMONChart_FW";
  $hash->{FW_detailFn} = "SYSMONChart_FW";
  $hash->{FW_atPageEnd} = 1;
  $hash->{AttrList} = "title titleLinkTo "
                    . "items statisticValues:none "
                    . "label-us label-uf label-ct "
                    . "label-mr label-ms "
                    . "label-cl label-cl|.. "
                    . "label-cf label-cf|.. "
                    . "label-fs label-fs|.. "
                    . "colorBorder colorFill colorText colorPeak colorMinAvg colorAvgMax "
  # $hash->{helper}: items, htmlBarSimple, htmlBarStat
}


sub
SYSMONChart_Define($$)
{
  my ($hash, $def) = @_;
  SYSMONChart_log($hash, 5, "$def");
  my ($dev, $type, $sm) = split("[ \t]+", $def, 3);
  return "Usage: define <name> SYSMONChart <sysmon>"
      if (!defined($sm) or $sm eq '');
  return "Unknown device: $sm"
      if(!defined($main::defs{$sm}));
  return "device $sm is not a SYSMON"
      if($main::defs{$sm}{TYPE} ne 'SYSMON');
  $hash->{SYSMON} = $sm;
 # destroy buffered bar info..
  delete($hash->{helper}{items});
  # destroy buffered html..
  delete($hash->{helper}{htmlBarSimple});
  delete($hash->{helper}{htmlBarStat}); 
  $hash->{STATE} = "initialized";
  return undef;
}


sub
SYSMONChart_Undefine($$)
{
  my ($hash, $arg) = @_;
  SYSMONChart_log($hash, 5, "$arg");
  return undef;
}


sub
SYSMONChart_Attr($$$)
{
  my ($cmd, $name, $attrName, $attrVal) = @_;
  my $hash = $main::defs{$name};
  SYSMONChart_log($hash, 5, "$cmd $name ".$attrName?$attrName:''." $attrVal");
  # update helpers..
  if ($attrName =~ /^(items|label-.*)$/){
    # destroy buffered bar info..
    delete($hash->{helper}{items});
  }
  elsif ($attrName =~ /^color/){
    # destroy buffered html..
    delete($hash->{helper}{htmlBarSimple});
    delete($hash->{helper}{htmlBarStat}); 
  }
  return undef;
}


sub 
SYSMONChart_FW($$$$)
{
  my ($FW_wname, $dev, $room, $pageHash) = @_; # pageHash is set in case of summaryFn.
  my $hash = $defs{$dev};
  SYSMONChart_log($hash, 5, "$FW_wname, $dev, $room, $pageHash");
  SYSMONChart_prepare($hash);
  my $html = '';
  $html .= '<div>';
  $html .= SYSMONChart_htmlTitle($hash);
  $html .= '  <table>';
  $html .= SYSMONChart_htmlItems($hash);
  $html .= '  </table>';
  $html .= '</div>';
  $html .= SYSMONChart_htmlScript($hash);
  return $html;
}


sub
SYSMONChart_log($$$)
{
   my ($hash, $loglevel, $text) = @_;
   my $xline = ( caller(0) )[2];
   my $xsubroutine = ( caller(1) )[3];
   my $sub= ( split( ':', $xsubroutine ) )[2];
   $sub =~ s/SYSMONChart_//;
   my $instName = ( ref($hash) eq "HASH" ) ? $hash->{NAME} : $hash;
   $instName="" unless $instName;
   Log3 $hash, $loglevel, "SYSMONChart $instName: $sub.$xline " . $text;
}


sub
SYSMONChart_prepare($)
{
  my $hash = shift;
  SYSMONChart_log($hash, 5, "");
  my $dev = $hash->{NAME};
  SYSMONChart_prepareHTMLBar($hash);
  SYSMONChart_prepareBars($hash);
  $hash->{helper}{stat} = (AttrVal($dev, 'statisticValues', '') eq 'none') ? 0 : 1;
  SYSMONChart_prepareData($hash);
}


sub
SYSMONChart_prepareHTMLBar($)
{
  my $hash = shift;
  SYSMONChart_log($hash, 5, "");
  my $dev = $hash->{NAME};
  my $htmlBarSimple = $hash->{helper}{htmlBarSimple} || '';
  my $htmlBarStat = $hash->{helper}{htmlBarStat} || '';
  return if ($htmlBarSimple ne '' and $htmlBarStat ne '');
  my $colorBorder = AttrVal($dev, 'colorBorder', DEFAULT_COLOR_BORDER);
  my $colorFill = AttrVal($dev, 'colorFill', DEFAULT_COLOR_FILL);
  my $colorText = AttrVal($dev, 'colorText', DEFAULT_COLOR_TEXT);
  my $colorPeak = AttrVal($dev, 'colorPeak', $colorBorder);
  my $colorMinAvg = AttrVal($dev, 'colorMinAvg', DEFAULT_COLOR_MIN_AVG);
  my $colorAvgMax = AttrVal($dev, 'colorAvgMax', DEFAULT_COLOR_AVG_MAX);
  if ($htmlBarSimple eq ''){
    $hash->{helper}{htmlBarSimple} = 
       HTML_BAR_SIMPLE
        =~ s/#colorBorder#/$colorBorder/gr
        =~ s/#colorFill#/$colorFill/gr
        =~ s/#colorText#/$colorText/gr;
  }
  if ($htmlBarStat eq ''){
    $hash->{helper}{htmlBarStat} = 
       HTML_BAR_STAT
        =~ s/#colorBorder#/$colorBorder/gr
        =~ s/#colorFill#/$colorFill/gr
        =~ s/#colorText#/$colorText/gr
        =~ s/#colorPeak#/$colorPeak/gr
        =~ s/#colorMinAvg#/$colorMinAvg/gr
        =~ s/#colorAvgMax#/$colorAvgMax/gr;
  }
}


sub
SYSMONChart_prepareBars($)
{
  my $hash = shift;
  SYSMONChart_log($hash, 5, "");
  return if (defined($hash->{helper}{items}));
  $hash->{helper}{items} = ();
  my $dev = $hash->{NAME};
  my $items = AttrVal($dev, 'items', DEFAULT_ITEMS);
  foreach my $item (split(/\s*,+\s*/,$items)){
    my ($type,$param) = split(/\|/,$item);
    $param = $param || '';
    my $label = AttrVal($dev, 'label-'.$type, '');
    if ($param ne ''){
      #fs_root: hmm was das?, fs_boot: das BOOT
      my $labels = AttrVal($dev, 'label-'.$type.'|..', '');
      $label = $1 if ($labels =~ /$param\:([^,]*)/);
    }
    $label = DEFAULT_LABEL->{$item} if ($label eq '');
    $label = DEFAULT_LABEL->{$type} if ($label eq '');
    $label =~ s/%/$param/g;
    push(@{$hash->{helper}{items}}, { type => $type,
                                      param => $param || '',
                                      label => $label });
  }
}


sub
SYSMONChart_prepareData($)
{
  my $hash = shift;
  SYSMONChart_log($hash, 5, "");
  my $sm = $hash->{SYSMON};
  return if(!defined($main::defs{$sm}{READINGS}));
  my $smr = \%{$main::defs{$sm}{READINGS}};
  foreach my $item (@{$hash->{helper}{items}}){
    SYSMONChart_log($hash, 5, "$item->{type}");
    SYSMONChart_prepareDataInit($item);
    if ($item->{type} eq 'us'){ SYSMONChart_prepareDataUptimeSystem($hash, $item, $smr); }
    elsif ($item->{type} eq 'uf'){ SYSMONChart_prepareDataUptimeFhem($hash, $item, $smr); }
    elsif ($item->{type} eq 'ct'){ SYSMONChart_prepareDataCPUTemperature($hash, $item, $smr); }
    elsif ($item->{type} eq 'cl'){ SYSMONChart_prepareDataCPULoad($hash, $item, $smr); }
    elsif ($item->{type} eq 'cf'){ SYSMONChart_prepareDataCPUFrequency($hash, $item, $smr); }
    elsif ($item->{type} =~ /^m[r|s]$/){ SYSMONChart_prepareDataMemory($hash, $item, $smr); }
    elsif ($item->{type} eq 'fs'){ SYSMONChart_prepareDataFileSystem($hash, $item, $smr); }
    SYSMONChart_prepareDataExtend($item);
  }
}


sub
SYSMONChart_prepareDataInit($)
{
  my $item = shift;
  delete($item->{value});
  delete($item->{valueMin});
  delete($item->{valueMax});
  delete($item->{valueAvg});
  delete($item->{text});
  delete($item->{textMin});
  delete($item->{textMax});
  delete($item->{textAvg});
  $item->{has} = 0;
  $item->{hasStat} = 0;
}


sub
SYSMONChart_prepareDataExtend($)
{
  my $item = shift;
  return if (!$item->{hasStat});
  $item->{valueMin2} = $item->{valueMin} + 1;
  $item->{valueMax2} = $item->{valueMax} + 1;
  $item->{valueAvg2} = $item->{valueAvg} + 1;
}


sub
SYSMONChart_prepareDataUptimeSystem($$$)
{
  my ($hash, $item, $smr) = @_;
  SYSMONChart_log($hash, 5, "$item, $smr");
  return if (!defined($smr->{uptime}));
  $item->{text} = SYSMONChart_secsToReadable($smr->{uptime}{VAL});
  $item->{has} = 1;
  return if (!defined($smr->{idletime}));
  #2404413 99.59 %
  my (undef,$idle,undef) = split(/\s+/,$smr->{idletime}{VAL});
  $item->{text} .= " ($idle % idle)";
}


sub
SYSMONChart_prepareDataUptimeFhem($$$)
{
  my ($hash, $item, $smr) = @_;
  SYSMONChart_log($hash, 5, "$item, $smr");
  return if (!defined($smr->{fhemuptime}));
  $item->{text} = SYSMONChart_secsToReadable($smr->{fhemuptime}{VAL});
  $item->{has} = 1;
}


sub
SYSMONChart_prepareDataCPUTemperature($$$)
{
  my ($hash, $item, $smr) = @_;
  SYSMONChart_log($hash, 5, "$item, $smr");
  return if (!defined($smr->{cpu_temp}));
  return if ($smr->{cpu_temp}{VAL} < 1);
  $item->{value} = sprintf("%.1f",$smr->{cpu_temp}{VAL});
  $item->{text} = $item->{value}." &deg;C";
  $item->{has} = 1;
  return if (!$hash->{helper}{stat});
  return if (!defined($smr->{cpu_temp_stat}));
  #40.62 42.24 41.54
  my ($min, $max, $avg) = split(/\s+/,$smr->{cpu_temp_stat}{VAL});
  $item->{valueMin} = sprintf("%.1f",$min);
  $item->{valueMax} = sprintf("%.1f",$max);
  $item->{valueAvg} = sprintf("%.1f",$avg);
  $item->{textMin} = $item->{valueMin}." &deg;C";
  $item->{textMax} = $item->{valueMax}." &deg;C";
  $item->{textAvg} = $item->{valueAvg}." &deg;C";
  $item->{hasStat} = 1;
}


sub
SYSMONChart_prepareDataCPULoad($$$)
{
  my ($hash, $item, $smr) = @_;
  SYSMONChart_log($hash, 5, "$item, $smr");
  my $read = 'stat_cpu'.$item->{param}.'_percent';
  my $readStat = 'cpu'.$item->{param}.'_idle_stat';
  return if (!defined($smr->{$read}));
  #0.28 0.00 0.20 99.43 0.02 0.00 0.07
  my (undef,undef,undef,$idle,undef,undef,undef) = split(/\s+/,$smr->{$read}{VAL});
  $item->{value} = sprintf("%.1f",100-$idle);
  $item->{text} = $item->{value}." %";
  $item->{has} = 1;
  return if (!$hash->{helper}{stat});
  return if (!defined($smr->{$readStat}));
  #92.53 99.75 98.84
  my ($min, $max, $avg) = split(/\s+/,$smr->{$readStat}{VAL});
  $item->{valueMin} = sprintf("%.1f",100-$max);
  $item->{valueMax} = sprintf("%.1f",100-$min);
  $item->{valueAvg} = sprintf("%.1f",100-$avg);
  $item->{textMin} = $item->{valueMin}." %";
  $item->{textMax} = $item->{valueMax}." %";
  $item->{textAvg} = $item->{valueAvg}." %";
  $item->{hasStat} = 1;
}


sub
SYSMONChart_prepareDataCPUFrequency($$$)
{
  my ($hash, $item, $smr) = @_;
  SYSMONChart_log($hash, 5, "$item, $smr");
  my $read = 'cpu'.$item->{param}.'_freq';
  my $readStat = $read.'_stat';
  return if (!defined($smr->{$read}));
  my $total = ceil($smr->{$read}{VAL});
  my ($min, $max, $avg);
  if (defined($smr->{$readStat})){
    #600.00 900.00 845.36
    ($min, $max, $avg) = split(/\s+/,$smr->{$readStat}{VAL});
    $total = ceil($max);
  }
  my $unit = 'MHz';
  my $factor = 1;
  if ($total > 1000){
    $unit = 'GHz';
    $factor = 1000;
  }
  $item->{value} = sprintf("%.1f",$smr->{$read}{VAL}/$total*100);
  $item->{text} = sprintf("%.1f %s",$smr->{$read}{VAL}/$factor,$unit);
  $item->{has} = 1;
  return if (!$hash->{helper}{stat});
  return if (!defined($smr->{$readStat}));
  $item->{valueMin} = sprintf("%.1f",$min/$total*100);
  $item->{valueMax} = sprintf("%.1f",$max/$total*100);
  $item->{valueAvg} = sprintf("%.1f",$avg/$total*100);
  $item->{textMin} = sprintf("%.1f %s",$min/$factor,$unit);
  $item->{textMax} = sprintf("%.1f %s",$max/$factor,$unit);
  $item->{textAvg} = sprintf("%.1f %s",$avg/$factor,$unit);
  $item->{hasStat} = 1;
}


sub
SYSMONChart_prepareDataMemory($$$)
{
  my ($hash, $item, $smr) = @_;
  SYSMONChart_log($hash, 5, "$item, $smr");
  my $read = ($item->{type} eq 'mr') ? 'ram' : 'swap';
  my $readStat = $read.'_used_stat';
  return if (!defined($smr->{$read}));
  return if ($smr->{$read}{VAL} eq 'n/a');
  #Total: 927.08 MB, Used: 47.86 MB, 5.16 %, Free: 879.22 MB
  my (undef,$total,$unit,undef,$used,undef,undef,undef,undef,undef,undef) = split(/[\s,]+/,$smr->{$read}{VAL});
  my $factor = 1;
  if ($total > 1024){
    $factor = 1024;
    $unit = 'GB';
  }
  $item->{value} = sprintf("%.1f",$used/$total*100);
  $item->{text} = sprintf("%.1f / %.1f %s",$used/$factor,$total/$factor,$unit);
  $item->{has} = 1;
  return if (!$hash->{helper}{stat});
  return if (!defined($smr->{$readStat}));
  #92.53 99.75 98.84
  my ($min, $max, $avg) = split(/\s+/,$smr->{$readStat}{VAL});
  $item->{valueMin} = sprintf("%.1f",$min/$total*100);
  $item->{valueMax} = sprintf("%.1f",$max/$total*100);
  $item->{valueAvg} = sprintf("%.1f",$avg/$total*100);
  $item->{textMin} = sprintf("%.1f %s",$min/$factor,$unit);
  $item->{textMax} = sprintf("%.1f %s",$max/$factor,$unit);
  $item->{textAvg} = sprintf("%.1f %s",$avg/$factor,$unit);
  $item->{hasStat} = 1;
}


sub
SYSMONChart_prepareDataFileSystem($$$)
{
  my ($hash, $item, $smr) = @_;
  SYSMONChart_log($hash, 5, "$item, $smr");
  my $read = $item->{param};
  return if (!defined($smr->{$read}));
  #Total: 14831 MB, Used: 2004 MB, 15 %, Available: 12176 MB at /
  my (undef,$total,$unit,undef,$used,undef,undef,undef,undef,undef,undef) = split(/[\s,]+/,$smr->{$read}{VAL});
  my $factor = 1;
  if ($total > 1024){
    $factor = 1024;
    $unit = 'GB';
  }
  $item->{value} = sprintf("%.1f",$used/$total*100);
  $item->{text} = sprintf("%.1f / %.1f %s",$used/$factor,$total/$factor,$unit);
  $item->{has} = 1;
}


sub
SYSMONChart_htmlTitle($)
{
  my $hash = shift;
  SYSMONChart_log($hash, 5, "");
  my $dev = $hash->{NAME};
  my $sysmon = $hash->{SYSMON};
  my $title = AttrVal($dev, 'title', $dev);
  return '' if ($title eq 'none');
  $title = $sysmon if ($title eq 'sysmon');
  my $link = AttrVal($dev, 'titleLinkTo', $dev);
  if ($link eq 'none'){
    return HTML_TITLE_SIMPLE
              =~ s/#title#/$title/r;
  }
  else{
    $link = $sysmon if ($link eq 'sysmon');
    return HTML_TITLE_LINK
              =~ s/#title#/$title/r
              =~ s/#link#/$link/r;
  }
}


sub
SYSMONChart_htmlItems($)
{
  my $hash = shift;
  SYSMONChart_log($hash, 5, "");
  my $html = '';
  foreach my $item (@{$hash->{helper}{items}}){
    if ($item->{type} =~ /^u[sf]$/){
      $html .= SYSMONChart_htmlItemText($hash, $item);
    }
    elsif ($item->{type} =~ /^(c[tlf]|m[rs]|fs)$/){
      $html .= SYSMONChart_htmlItemBar($hash, $item);
    }
  }
  return $html;
}


sub 
SYSMONChart_htmlItemText($$)
{
  my ($hash, $item) = @_;
  SYSMONChart_log($hash, 5, "$item");
  return '' if (!$item->{has});
  return HTML_ROW
          =~ s/#name#/$item->{label}/gr
          =~ s/#value#/$item->{text}/gr;
}


sub 
SYSMONChart_htmlItemBar($$)
{
  my ($hash, $item) = @_;
  SYSMONChart_log($hash, 5, "$item");
  return '' if (!$item->{has});
  my $htmlBar = $item->{hasStat}
                  ? $hash->{helper}{htmlBarStat}
                      =~ s/#value#/$item->{value}/gr
                      =~ s/#text#/$item->{text}/gr
                      =~ s/#valueMin#/$item->{valueMin}/gr
                      =~ s/#valueMin2#/$item->{valueMin2}/gr
                      =~ s/#textMin#/$item->{textMin}/gr
                      =~ s/#valueAvg#/$item->{valueAvg}/gr
                      =~ s/#valueAvg2#/$item->{valueAvg2}/gr
                      =~ s/#textAvg#/$item->{textAvg}/gr
                      =~ s/#valueMax#/$item->{valueMax}/gr
                      =~ s/#valueMax2#/$item->{valueMax2}/gr
                      =~ s/#textMax#/$item->{textMax}/gr
                  : $hash->{helper}{htmlBarSimple}
                      =~ s/#value#/$item->{value}/gr
                      =~ s/#text#/$item->{text}/gr;
  return HTML_ROW
          =~ s/#name#/$item->{label}/gr
          =~ s/#value#/$htmlBar/gr;
}


sub
SYSMONChart_htmlScript($)
{
  my $hash = shift;
  return '' if (!$hash->{helper}{stat});
  return HTML_SCRIPT;
}


sub SYSMONChart_secsToReadable($){
  my $secs = shift;
  my $y = floor($secs / 60/60/24/365);
  my $d = floor($secs/60/60/24) % 365;
  my $h = floor(($secs / 3600) % 24);
  my $m = floor(($secs / 60) % 60);
  my $s = $secs % 60;
  my $string = '';
  $string .= $y.'y ' if ($y > 0);
  $string .= $d.'d ' if ($d > 0);
  $string .= $h.'h ' if ($h > 0);
  $string .= $m.'m ' if ($m > 0);
  $string .= $s.'s' if ($s > 0);
  return $string;
}


#
# example usage inside a weblink instance:
# - no customization..
#   define wlRasPi1 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi")}
# - define which bars to show (cpu load, cpu temperature and filesystem fs_root)..
#   define wlRasPi2 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{bars=>"cl,ct,fs|fs_root"})}
# - show bars for each cpu core (in this case we've got 4 cores)..
#   define wlRasPi3 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{bars=>"ct,cl,cl|0,cl|1,cl|2,cl|3"})}
# - customize bar titles (cpu load => CPULoad, uptime system => System Uptime, common filesystem FileSystem <readingName> and the specific root filesystem (reading fs_root) => Root)..
#   define wlRasPi4 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{title_cl=>"CPULoad",title_us=>"System Uptime",title_fs=>"FileSystem %",title_fs2=>{fs_root=>"Root"}})}
# - customize colors (bar will be filled red, the text will be white)
#   define wlRasPi5 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{colorFill=>"red",colorText=>"#fff"})}
# - let the chart title become a link to the weblink instance
#   define wlRasPi6 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{weblink=>"wlRasPi6"})}
# - customize chart title
#   define wlRasPi7 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{title=>"This is my Chart"})}
# - disable statistical data
#   define wlRasPi8 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{stat=>0})}
# - mix previous options
#   define wlRasPi9 weblink htmlCode {SYSMON_ShowBarChartHtml("sysRaspi",{weblink=>"wlRasPi9", title=>"Rasperry Pi", stat=>0, bars=>"cl,ct,us,fs|fs_root,fs|fs_boot", title_cl=>"CPU load", title_ct=>"CPU temperature", title_fs=>"FileSystem %", title_fsx=>{fs_root=>"Root"}, colorBorder=>"blue", colorFill=>"lightgray" ,colorText=>"blue"})}


1;


=pod
=begin html

<a name="SYSMONChart"></a>
<h3>SYSMONChart</h3>
<ul>
  This is a <a href="#weblink">weblink</a>-like placeholder device used with FHEMWEB to display <a href="#SYSMON">SYSMON</a> data.
  <br>
  Supported <a href="#SYSMON">SYSMON</a> data:
  <ul>
    <li>CPU load as bar</li>
    <li>CPU temperature as bar</li>
    <li>CPU frequency as bar</li>
    <li>RAM as bar</li>
    <li>Swap as bar</li>
    <li>Filesystem as bar</li>
    <li>Uptime system as text</li>
    <li>Uptime fhem as text</li>
  </ul>
  <br>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; SYSMONChart &lt;sysmon&gt;</code>
    <br>
    &lt;sysmon&gt; is the name of the linked <a href="#SYSMON">SYSMON</a> device.
    <br>
    Example: <code>define smcRasPi SYSMONChart smRasPi</code>
    <br>
  </ul>
  <br>
  <b>Attributes</b>
  <ul>
    <li><i>items</i><br>
      Comma separated list of items to show. Possible items are:
      <ul>
        <li><code>us</code>: Uptime system</li>
        <li><code>uf</code>: Uptime Fhem</li>
        <li><code>cf[|&lt;core&gt;]</code>: CPU frequency - &lt;core&gt; is the target CPU core number [0..n]</li>
        <li><code>cl[|&lt;core&gt;]</code>: CPU load - &lt;core&gt; is the target CPU core number [0..n]</li>
        <li><code>ct</code>: CPU temperature</li>
        <li><code>mr</code>: Memory RAM</li>
        <li><code>ms</code>: Memory swap</li>
        <li><code>fs|&lt;name></code>: Filesystem - &lt;name&gt; is the target reading name</li>
      </ul>
      The default value (if this attribute is not provided) is: "us,uf,cl,ct,cf,mr,ms,fs|fs_root"
      <br>
      An item won't displayed if the appropriate <a href="#SYSMON">SYSMON</a> reading doesn't
      exist (e.g. cpu_freq @ FritzBox) or is empty (e.g. cpu_temp @ FritzBox), even if you
      defined the item to show.
    </li>
    <li><i>label-&lt;item&gt;</i><br>
      Define a specific item label where &lt;item&gt; is one of the possible items mentioned above.
      <br>
      The followng items support the variable % within the label:
      <ul>
        <li><code>cf</code>: % will be replaced by the cpu core number</li>
        <li><code>cl</code>: % will be replaced by the cpu core number</li>
        <li><code>fs</code>: % will be replaced by the reading name (e.g. fs_root)</li>
      </ul>
      Using label attributes ending with |.. you can provide the label for specific
      items (e.g. cpu1, cpu2, fs_root, fs_boot).
      <br>
      Those attributes' values have to be a comma separated list of &lt;special&gt;:&lt;title&gt; pairs, e.g.:
      <ul>
        <li>label-fs|.. =&gt; "fs_root: root, fs_boot: boot"</li>
        <li>label-cf|.. =&gt; "0:cpu freq (1st core), 1:cpu freq (2nd core)"</li>
      </ul>
      If you provide a label for a specific item (e.g label-cf|.. =&gt; "cpu freq (1st core)"), this
      will be prefered and 'override' the general title (e.g. label-cf =&gt; "cpu% freq").
      <br>
      If there is no specific item label defined the default label will be displayed:
      <ul>
        <li><code>us</code>: uptime</li>
        <li><code>uf</code>: uptime fhem</li>
        <li><code>cf</code>: cpu% freq</li>
        <li><code>cl</code>: cpu% load</li>
        <li><code>ct</code>: cpu temp</li>
        <li><code>mr</code>: mem ram</li>
        <li><code>ms</code>: mem swap</li>
        <li><code>fs</code>: fs %</li>
        <li><code>fs|fs_root</code>: fs root</li>
      </ul>
    </li>
    <li><i>statisticValues</i> none<br>
      Define display of statistic data (min, max, avg). Possible values:
      <ul>
        <li><code>none</code>: no statistic data</li>
      </ul>
    </li>
    <li><i>title</i> none|sysmon|..<br>
      Define the chart title.
      <br>
      The default title (if this attribute is not provided) is the device name.
      Possible values:
      <ul>
        <li><code>none</code>: no title</li>
        <li><code>sysmon</code>: name of the linked <a href="#SYSMON">SYSMON</a> device</li>
        <li>..: arbitrary title..</li>
      </ul>
    </li>
    <li><i>titleLinkTo</i> none|sysmon|..<br>
      Define title link target (devices' details page).
      <br>
      By default (if this attribute is not provided) the title is a link to this device.
      Possible values:
      <ul>
        <li><code>none</code>: no link</li>
        <li><code>sysmon</code>: link to the linked <a href="#SYSMON">SYSMON</a> device</li>
        <li>..: arbitrary device..</li>
      </ul>
    </li>
    <li><i>color&lt;type&gt;</i><br>
      Change bar colors. The value can be any valid html/css color definition
      (e.g. red, #ff0000, rgb(255,0,0), rgba(255,0,0,.5)).
      <br>
      The possible types and their default colors (in brackets) are:
      <ul>
        <li><code>Border</code>: bar border (black)</li>
        <li><code>Fill</code>: bar content (tan)</li>
        <li><code>Text</code>: bar text (empty -&gt; css style default)</li>
        <li><code>Stat</code>: statistic data [min, max, avg] indicatator (=border -&gt; if you change border, this will changed as well)</li>
        <li><code>MinAvg</code>: statistic data range1 - min to avg</li>
        <li><code>AvgMax</code>: staristic data range2 - avg to max</li>
      </ul>
    </li>
  </ul>
  <br>

</ul>

=end html
=cut
