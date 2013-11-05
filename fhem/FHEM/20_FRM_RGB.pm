#############################################
package main;

use vars qw{%attr %defs $readingFnAttributes};
use strict;
use warnings;

#add FHEM/lib to @INC if it's not allready included. Should rather be in fhem.pl than here though...
BEGIN {
	if (!grep(/FHEM\/lib$/,@INC)) {
		foreach my $inc (grep(/FHEM$/,@INC)) {
			push @INC,$inc."/lib";
		};
	};
};

use Device::Firmata::Constants  qw/ :all /;
use Color qw/ :all /;
use SetExtensions qw/ :all /;

#####################################

my %gets = (
);

my %sets = (
  "on"                  => 0,
  "off"                 => 0,
  "toggle"              => 0,
  "rgb:colorpicker,RGB" => 1,
  "fadeTo"              => 2,
  "dimUp"               => 0,
  "dimDown"             => 0,
  "getFade"             => 1,
  "setFade"             => 3,
  "startFade"           => 2,
  "reset"               => 0,
);

my %dim_values = (
   0 => "dim06%",
   1 => "dim12%",
   2 => "dim18%",
   3 => "dim25%",
   4 => "dim31%",
   5 => "dim37%",
   6 => "dim43%",
   7 => "dim50%",
   8 => "dim56%",
   9 => "dim62%",
  10 => "dim68%",
  11 => "dim75%",
  12 => "dim81%",
  13 => "dim87%",
  14 => "dim93%",
);

sub
FRM_RGB_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "FRM_RGB_Set";
  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{InitFn}    = "FRM_RGB_Init";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{AttrFn}    = "FRM_RGB_Attr";
  $hash->{StateFn}   = "FRM_RGB_State";
  
  $hash->{AttrList}  = "restoreOnReconnect:on,off restoreOnStartup:on,off IODev loglevel:0,1,2,3,4,5 $readingFnAttributes";
  
  LoadModule("FRM");
  FHEM_colorpickerInit();  
}

sub
FRM_RGB_Init($$)
{
  my ($hash,$args) = @_;
  my $name = $hash->{NAME};
  my $ret = FRM_Init_Pin_Client($hash,$args,PIN_PWM);
  return $ret if (defined $ret);
  delete $hash->{PIN};
  $hash->{PIN1} = @$args[0];
  $hash->{PIN2} = @$args[1];
  $hash->{PIN3} = @$args[2];
  eval {
    my $firmata = FRM_Client_FirmataDevice($hash);
    $firmata->pin_mode($hash->{PIN2},PIN_PWM);
    $firmata->pin_mode($hash->{PIN3},PIN_PWM);
  
    $hash->{".shift1"} = defined $firmata->{metadata}{pwm_resolutions} ? $firmata->{metadata}{pwm_resolutions}{$hash->{PIN1}}-8 : 0;
    $hash->{".shift2"} = defined $firmata->{metadata}{pwm_resolutions} ? $firmata->{metadata}{pwm_resolutions}{$hash->{PIN2}}-8 : 0;
    $hash->{".shift3"} = defined $firmata->{metadata}{pwm_resolutions} ? $firmata->{metadata}{pwm_resolutions}{$hash->{PIN3}}-8 : 0;
  
    if (! (defined AttrVal($name,"stateFormat",undef))) {
      $attr{$name}{"stateFormat"} = "value";
    }
    my $value = ReadingsVal($name,"rgb",undef);
    if (defined $value and AttrVal($hash->{NAME},"restoreOnReconnect","on") eq "on") {
      FRM_RGB_Set($hash,$name,"rgb",$value);
    }
  };
  return $@ if $@;
  readingsSingleUpdate($hash,"state","Initialized",1);
  return undef;  
}

sub
FRM_RGB_Set($@)
{
  my ($hash, $name, $cmd, @a) = @_;
  
  my @match = grep( $_ =~ /^$cmd($|:)/, keys %sets );
  #-- check argument
  return SetExtensions($hash, join(" ", keys %sets), $name, $cmd, @a) unless @match == 1;
  return "$cmd expects $sets{$match[0]} parameters" unless (@a eq $sets{$match[0]});

  SETHANDLER: {
    $cmd eq "on" and do {
      FRM_RGB_SetRGB($hash,"FFFFFF");
      $hash->{toggle} = "on";
      last;
    };
    $cmd eq "off" and do {
      FRM_RGB_SetRGB($hash,"000000");
      $hash->{toggle} = "off";
      last;
    };
    $cmd eq "toggle" and do {
      my $toggle = $hash->{toggle};
      TOGGLEHANDLER: {
        $toggle eq "off" and do {
          $hash->{toggle} = "up";
          FRM_RGB_SetRGB($hash,$hash->{dim} ? $hash->{dim} : "7F7F7F");
          last;    
        };
        $toggle eq "up" and do {
          FRM_RGB_SetRGB($hash,"FFFFFF");
          $hash->{toggle} = "on";
          last;
        };
        $toggle eq "on" and do {
          $hash->{toggle} = "down";
          FRM_RGB_SetRGB($hash,$hash->{dim} ? $hash->{dim} : "7F7F7F");
          last;    
        };
        $toggle eq "down" and do {
          FRM_RGB_SetRGB($hash,"000000");
          $hash->{toggle} = "off";
          last;
        };
      };
      last;
    };
  $cmd eq "rgb" and do {
    my $arg = $a[0];
    FRM_RGB_SetRGB($hash,$arg);
    RGBHANDLER: {
      $arg eq "000000" and do {
        $hash->{toggle} = "off";
        last;
      };
      $arg eq "FFFFFF" and do {
        $hash->{toggle} = "on";
        last;
      };
      $hash->{toggle} = "up";
      $hash->{dim} = $arg;
    };
  };
#  $cmd eq "fadeTo" and do {
#    return (undef, "$arg2 not a valid time" ) if( $arg2 !~ /^\d{1,2}$/ );
#    return( "regSet", CMD_REG, CMD_On.$arg.sprintf( "%02X",$arg2 )."00" ) if( $arg =~ /^[\da-f]{6}$/i );
#    return (undef, "$arg is not a valid rgb color" );
#  };
#  $cmd eq "dimUp" and do {
#    return( "regSet", CMD_REG, CMD_DimUp."0000000000" );
#  };
#  $cmd eq "dimDown" and do {
#    return( "regSet", CMD_REG, CMD_DimDown."0000000000" );
#  };
#  $cmd eq "getFade" and do {
#    if( $arg eq "all" ) {
#      for( my $reg = 0; $reg <= 0xF; ++$reg) {
#        SWAP_Send($hash, $hash->{addr}, "02", CMD_REG, CMD_GetFade."0".sprintf("%1X",$reg)."00000000" );
#      }
#      return undef;
#    }
#    return( "regSet", CMD_REG, CMD_GetFade."0".sprintf("%1X",$arg)."00000000" ) if( $arg =~ /^(\d|0\d|1[0-5])$/ );
#    return (undef, "$arg is not a valid fade register number" );
#  };
#  $cmd eq "setFade" and do {
#    return (undef, "$arg2 not a valid rgb value" ) if( $arg2 !~ /^[\da-f]{6}$/i );
#    return (undef, "$arg3 not a valid time value" ) if( $arg3 !~ /^[\da-f]{1,3}$/i );
#    return( "regSet", CMD_REG, CMD_SetFade."0".sprintf("%1X",$arg).$arg2.sprintf( "%02X",$arg3 ) ) if( $arg =~ /^(\d|0\d|1[0-5])$/ );
#    return (undef, "$arg not a valid fade register" );
#  };
#  $cmd eq "startFade" and do {
#    return (undef, "$arg is not a valid fade register number" ) if( $arg !~ /^(\d|0\d|1[0-5])$/ );
#    return( "regSet", CMD_REG, CMD_StartFade."0".sprintf("%1X",$arg)."0".sprintf( "%1X",$arg2 )."000000" ) if( $arg2 =~ /^(\d|0\d|1[0-5])$/ );
#    return (undef, "$arg2 not a valid fade register number" );
#  };
#  $cmd eq "reset" and do {
#    return( "regSet", CMD_REG, CMD_RESET."0000000000" );
#  };
}

  return undef;
}

sub
FRM_RGB_SetRGB($$)
{
  my ($hash,$rgb) = @_;

  die "$rgb is not the right format" unless( $rgb =~ /^[\da-f]{6}$/i );

  my ($r,$g,$b) = unpack("A2A2A2",$rgb);
  
  if ($hash->{".shift1"} > 0) {
    $r = hex($r) << $hash->{".shift1"};
  } else {
    $r = hex ($r) >> -$hash->{".shift1"};
  }
  
  if ($hash->{".shift2"} > 0) {
    $g = hex($g) << $hash->{".shift2"};
  } else {
    $g = hex($g) >> -$hash->{".shift2"};
  }
  
  if ($hash->{".shift3"} > 0) {
    $b = hex($b) << $hash->{".shift3"};
  } else {
    $b = hex($b) >> -$hash->{".shift3"};
  }

  my $firmata = FRM_Client_FirmataDevice($hash);

  $firmata->analog_write($hash->{PIN1},$r);
  $firmata->analog_write($hash->{PIN2},$g);
  $firmata->analog_write($hash->{PIN3},$b);
  
  main::readingsSingleUpdate($hash,"rgb",$rgb, 1);
}

sub FRM_RGB_State($$$$)
{
	my ($hash, $tim, $sname, $sval) = @_;
	
STATEHANDLER: {
		$sname eq "value" and do {
			if (AttrVal($hash->{NAME},"restoreOnStartup","on") eq "on") { 
				FRM_PWM_Set($hash,$hash->{NAME},$sval);
			}
			last;
		}
	}
}

sub
FRM_RGB_Attr($$$$) {
  my ($command,$name,$attribute,$value) = @_;
  if ($command eq "set") {
    ARGUMENT_HANDLER: {
      $attribute eq "IODev" and do {
      	my $hash = $main::defs{$name};
      	if (!defined ($hash->{IODev}) or $hash->{IODev}->{NAME} ne $value) {
        	$hash->{IODev} = $defs{$value};
      		FRM_Init_Client($hash) if (defined ($hash->{IODev}));
      	}
        last;
      };
      $main::attr{$name}{$attribute}=$value;
    }
  }
}

1;

=pod
=begin html

<a name="FRM_PWM"></a>
<h3>FRM_PWM</h3>
<ul>
  represents a pin of an <a href="http://www.arduino.cc">Arduino</a> running <a href="http://www.firmata.org">Firmata</a>
  configured for analog output.<br>
  The value set will be output by the specified pin as a pulse-width-modulated signal.<br> 
  Requires a defined <a href="#FRM">FRM</a>-device to work.<br><br> 
  
  <a name="FRM_PWMdefine"></a>
  <b>Define</b>
  <ul>
  <code>define &lt;name&gt; FRM_PWM &lt;pin&gt;</code> <br>
  Defines the FRM_PWM device. &lt;pin&gt> is the arduino-pin to use.
  </ul>
  
  <br>
  <a name="FRM_PWMset"></a>
  <b>Set</b><br>
  <ul>
  <code>set &lt;name&gt; value &lt;value&gt;</code><br>
  sets the pulse-width of the signal that is output on the configured arduino pin<br>
  Range is from 0 to 255 (see <a href="http://arduino.cc/en/Reference/AnalogWrite">analogWrite()</a> for details)
  </ul>
  <a name="FRM_PWMget"></a>
  <b>Get</b><br>
  <ul>
  N/A
  </ul><br>
  <a name="FRM_PWMattr"></a>
  <b>Attributes</b><br>
  <ul>
      <li>restoreOnStartup &lt;on|off&gt;</li>
      <li>restoreOnReconnect &lt;on|off&gt;</li>
      <li><a href="#IODev">IODev</a><br>
      Specify which <a href="#FRM">FRM</a> to use. (Optional, only required if there is more
      than one FRM-device defined.)
      </li>
      <li><a href="#eventMap">eventMap</a><br></li>
      <li><a href="#readingFnAttributes">readingFnAttributes</a><br></li>
    </ul>
  </ul>
<br>

=end html
=cut
