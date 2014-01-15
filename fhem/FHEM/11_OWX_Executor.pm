package OWX_Executor;

use strict;
use warnings;

use Time::HiRes qw( gettimeofday tv_interval usleep );

use constant {
	SEARCH  => 1,
	ALARMS  => 2,
	EXECUTE => 3,
	EXIT    => 4,
	LOG     => 5
};

sub new($) {
	my ( $class, $owx ) = @_;
	
	my $commands = [];
	return bless {
		commands => $commands,
		owx      => $owx,
		delayed  => {},
	}, $class;
}

sub _submit($$) {
	my ($self,$command,$hash) = @_;
	push @{$self->{commands}}, $command;
	return $self->poll($hash);
}

sub search($) {
	my ($self,$hash) = @_;
	return $self->_submit( { command => SEARCH }, $hash );
}

sub alarms($) {
	my ($self,$hash) = @_;
	return $self->_submit( { command => ALARMS }, $hash );
}

sub execute($$$$$$$) {
	my ( $self, $hash, $context, $reset, $owx_dev, $data, $numread, $delay ) = @_;
	return $self->_submit( {
		command   => EXECUTE,
		context   => $context,
		reset     => $reset,
		address   => $owx_dev,
		writedata => $data,
		numread   => $numread,
		delay     => $delay
	}, $hash );
};

sub exit($) {
	my ( $self,$hash ) = @_;
	return $self->_submit( { command => EXIT }, $hash );
}

# start of worker code

sub poll($) {
	my ( $self, $hash ) = @_;
	my $delayed = $self->{delayed};
	my $item = undef;
	foreach my $address (keys %$delayed) {
		next if (tv_interval($delayed->{$address}->{'until'}) < 0);
		my @delayed_items = @{$delayed->{$address}->{'items'}}; 
		$item = shift @delayed_items;
		delete $delayed->{$address} unless scalar(@delayed_items);# or $item->{delay};
		last;
	};
	unless ($item) {
		$item = shift @{$self->{commands}};
		if ($item and my $address = $item->{address}) {
			if ($delayed->{$address}) {
				push @{$delayed->{$address}->{'items'}},$item;
				return 1; 
			};
		};
	};
	return 1 unless ($item);
	
	REQUEST_HANDLER: {
		my $command = $item->{command};
		
		$command eq SEARCH and do {
			my $devices = $self->{owx}->Discover();
			if (defined $devices) {
				main::OWX_AfterSearch($hash,$devices);
			}
			return 1;
		};
		
		$command eq ALARMS and do {
			my $devices = $self->{owx}->Alarms();
			if (defined $devices) {
				main::OWX_AfterAlarms($hash,$devices);
			}
			return 1;
		};

		$command eq EXECUTE and do {
			if (defined $item->{reset}) {
				if(!$self->{owx}->Reset()) {
					main::OWX_AfterExecute($hash,$item->{context},undef,1,$item->{address},$item->{writedata},$item->{numread},undef);						
					return 1;
				};
			};
			my $address = $item->{address};
			my $res = $self->{owx}->Complex($address,$item->{writedata},$item->{numread});
			if (defined $res) {
				my $writelen = defined $item->{writedata} ? split (//,$item->{writedata}) : 0;
				my @result = split (//, $res);
				my $readdata = 9+$writelen < @result ? substr($res,9+$writelen) : ""; 
				main::OWX_AfterExecute($hash,$item->{context},1,$item->{reset},$item->{address},$item->{writedata},$item->{numread},$readdata);
			} else {
				main::OWX_AfterExecute($hash,$item->{context},undef,$item->{reset},$item->{address},$item->{writedata},$item->{numread},undef);
			}
			if (my $delay = $item->{delay}) {
				if ($address) {
					unless ($delayed->{$address}) {
						$delayed->{$address} = { items => [] };
					}
					my ($seconds,$micros) = gettimeofday;
					my $len = length ($delay); #delay is millis, tv_address works with [sec,micros]
					if ($len>3) {
						$seconds += substr($delay,0,$len-3);
						$micros += (substr ($delay,$len-8).000);
					} else {
						$micros += ($delay.000);
					}
					$delayed->{$address}->{'until'} = [$seconds,$micros];
				} else {
					select (undef,undef,undef,$delay/1000);
				}
			}
			return 1;
		};
		
		$command eq EXIT and do {
			main::OWX_Disconnected($hash);
			return 0;
		};
		main::Log3($hash->{NAME},3,"OWX_Executor: unexpected command: "+$command)
	};
};

1;
