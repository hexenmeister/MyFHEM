#############################################
package main;

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

#####################################

my %sets = (
  "reset"    => "noArg",
  "position" => "",
  "step"     => "",
);

my %gets = (
  "position" => "noArg",
);

sub
FRM_STEPPER_Initialize($)
{
  my ($hash) = @_;

  $hash->{SetFn}     = "FRM_STEPPER_Set";
  $hash->{GetFn}     = "FRM_STEPPER_Get";
  $hash->{DefFn}     = "FRM_Client_Define";
  $hash->{InitFn}    = "FRM_STEPPER_Init";
  $hash->{UndefFn}   = "FRM_Client_Undef";
  $hash->{AttrFn}    = "FRM_STEPPER_Attr";
  $hash->{StateFn}   = "FRM_STEPPER_State";
  
  $hash->{AttrList}  = "restoreOnReconnect:on,off restoreOnStartup:on,off speed acceleration deceleration IODev $main::readingFnAttributes";
  main::LoadModule("FRM");
}

sub
FRM_STEPPER_Init($$)
{
	my ($hash,$args) = @_;

	my $u = "wrong syntax: define <name> FRM_STEPPER [DRIVER|TWO_WIRE|FOUR_WIRE] directionPin stepPin [motorPin3 motorPin4] stepsPerRev [id]";
	return $u unless defined $args;
	
	my $driver = shift @$args;
	
	return $u unless ( $driver eq 'DRIVER' or $driver eq 'TWO_WIRE' or $driver eq 'FOUR_WIRE' );
	return $u if (($driver eq 'DRIVER' or $driver eq 'TWO_WIRE') and (scalar(@$args) < 3 or scalar(@$args) > 4));
	return $u if (($driver eq 'FOUR_WIRE') and (scalar(@$args) < 5 or scalar(@$args) > 6));
	
	$hash->{DRIVER} = $driver;
	
	$hash->{PIN1} = shift @$args;
	$hash->{PIN2} = shift @$args;
	
	if ($driver eq 'FOUR_WIRE') {
		$hash->{PIN3} = shift @$args;
		$hash->{PIN4} = shift @$args;
	}
	
	$hash->{STEPSPERREV} = shift @$args;
	$hash->{STEPPERNUM} = shift @$args;
	
	eval {
		FRM_Client_AssignIOPort($hash);
		my $firmata = FRM_Client_FirmataDevice($hash);
		$firmata->stepper_config(
			$hash->{STEPPERNUM},
			$driver,
			$hash->{STEPSPERREV},
			$hash->{PIN1},
			$hash->{PIN2},
			$hash->{PIN3},
			$hash->{PIN4});
		$firmata->observe_stepper(0, \&FRM_STEPPER_observer, $hash );
	};
	if ($@) {
		$@ =~ /^(.*)( at.*FHEM.*)$/;
		$hash->{STATE} = "error initializing: ".$1;
		return "error initializing '".$hash->{NAME}."': ".$1;
	}
	$hash->{POSITION} = 0;
	$hash->{DIRECTION} = 0;
	$hash->{STEPS} = 0;
	if (! (defined AttrVal($hash->{NAME},"stateFormat",undef))) {
		$main::attr{$hash->{NAME}}{"stateFormat"} = "position";
	}
	main::readingsSingleUpdate($hash,"state","Initialized",1);
	return undef;
}

sub
FRM_STEPPER_observer
{
	my ( $stepper, $hash ) = @_;
	my $name = $hash->{NAME};
	Log3 $name,5,"onStepperMessage for pins ".$hash->{PIN1}.",".$hash->{PIN2}.(defined ($hash->{PIN3}) ? ",".$hash->{PIN3} : ",-").(defined ($hash->{PIN4}) ? ",".$hash->{PIN4} : ",-")." stepper: ".$stepper;
	my $position = $hash->{DIRECTION} ? $hash->{POSITION} - $hash->{STEPS} : $hash->{POSITION} + $hash->{STEPS};
	$hash->{POSITION} = $position;
	$hash->{DIRECTION} = 0;
	$hash->{STEPS} = 0;
	main::readingsSingleUpdate($hash,"position",$position,1);
}

sub
FRM_STEPPER_Set
{
  my ($hash, @a) = @_;
  return "Need at least one parameters" if(@a < 2);
  shift @a;
  my $name = $hash->{NAME};
  my $command = shift @a;
  if(!defined($sets{$command})) {
  	my @commands = ();
    foreach my $key (sort keys %sets) {
      push @commands, $sets{$key} ? $key.":".join(",",$sets{$key}) : $key;
    }
    return "Unknown argument $command, choose one of " . join(" ", @commands);
  }
  COMMAND_HANDLER: {
    $command eq "reset" and do {
      $hash->{POSITION} = 0;
      main::readingsSingleUpdate($hash,"position",0,1);
      last;
    };
    $command eq "position" and do {
      my $position = $hash->{POSITION};
      my $value = shift @a;
      my $direction = $value < $position ? 1 : 0;
      my $steps = $direction ? $position - $value : $value - $position;
      my $speed = shift @a;
      $speed = AttrVal($name,"speed",1000) unless (defined $speed);
      my $accel = shift @a;
      $accel = AttrVal($name,"acceleration",undef) unless (defined $accel);
      my $decel = shift @a;
      $decel = AttrVal($name,"deceleration",undef) unless (defined $decel);
      $hash->{DIRECTION} = $direction;
      $hash->{STEPS} = $steps;
      eval {
      # $stepperNum, $direction, $numSteps, $stepSpeed, $accel, $decel
        FRM_Client_FirmataDevice($hash)->stepper_step($hash->{STEPPERNUM},$direction,$steps,$speed,$accel,$decel);
      };
      last;
    };
    $command eq "step" and do {
      my $value = shift @a;
      my $direction = $value < 0 ? 1 : 0;
      my $steps = abs $value;
      my $speed = shift @a;
      $speed = AttrVal($name,"speed",100) unless (defined $speed);
      my $accel = shift @a;
      $accel = AttrVal($name,"acceleration",undef) unless (defined $accel);
      my $decel = shift @a;
      $decel = AttrVal($name,"deceleration",undef) unless (defined $decel);
      $hash->{DIRECTION} = $direction;
      $hash->{STEPS} = $steps;
      eval {
      # $stepperNum, $direction, $numSteps, $stepSpeed, $accel, $decel
        FRM_Client_FirmataDevice($hash)->stepper_step($hash->{STEPPERNUM},$direction,$steps,$speed,$accel,$decel);
      };
      last;
    };
  }
}

sub
FRM_STEPPER_Get
{
  my ($hash, @a) = @_;
  return "Need at least one parameters" if(@a < 2);
  shift @a;
  my $name = $hash->{NAME};
  my $command = shift @a;
  return "Unknown argument $command, choose one of " . join(" ", sort keys %gets) unless defined($gets{$command});
}


sub FRM_STEPPER_State($$$$)
{
	my ($hash, $tim, $sname, $sval) = @_;
	
STATEHANDLER: {
		$sname eq "value" and do {
			if (AttrVal($hash->{NAME},"restoreOnStartup","on") eq "on") { 
				FRM_STEPPER_Set($hash,$hash->{NAME},$sval);
			}
			last;
		}
	}
}

sub
FRM_STEPPER_Attr($$$$) {
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

<a name="FRM_STEPPER"></a>
<h3>FRM_STEPPER</h3>
<ul>
  represents a pin of an <a href="http://www.arduino.cc">Arduino</a> running <a href="http://www.firmata.org">Firmata</a>
  configured for digital output.<br>
  Requires a defined <a href="#FRM">FRM</a>-device to work.<br><br> 
  
  <a name="FRM_STEPPERdefine"></a>
  <b>Define</b>
  <ul>
  <code>define &lt;name&gt; FRM_STEPPER &lt;pin&gt;</code> <br>
  Defines the FRM_STEPPER device. &lt;pin&gt> is the arduino-pin to use.
  </ul>
  
  <br>
  <a name="FRM_STEPPERset"></a>
  <b>Set</b><br>
  <ul>
  <code>set &lt;name&gt; on|off</code><br><br>
  </ul>
  <ul>
  <a href="#setExtensions">set extensions</a> are supported<br>
  </ul>
  <a name="FRM_STEPPERget"></a>
  <b>Get</b><br>
  <ul>
  N/A
  </ul><br>
  <a name="FRM_STEPPERattr"></a>
  <b>Attributes</b><br>
  <ul>
      <li>restoreOnStartup &lt;on|off&gt;</li>
      <li>restoreOnReconnect &lt;on|off&gt;</li>
      <li>activeLow &lt;yes|no&gt;</li>
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
