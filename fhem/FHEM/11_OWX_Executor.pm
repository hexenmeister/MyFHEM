package OWX_Executor;

use strict;
use warnings;
use threads;
use Thread::Queue;
our $can_use_threads = eval { use threads; 1 };

use constant {
	SEARCH  => 1,
	ALARMS  => 2,
	EXECUTE => 3,
	EXIT    => 4,
	LOG     => 5
};

sub new($) {
	my ( $class, $owx, $daemon ) = @_;
	
	$daemon = 0 unless $can_use_threads;

	if ($daemon) {
	  my $requests   = Thread::Queue->new();
		my $responses  = Thread::Queue->new();
		threads->create(
			sub {
				OWX_Worker->new($owx,$requests,$responses,1)->run();
			}
		)->detach();
		return bless {
			requests     => $requests,
			responses    => $responses,
			delayed      => {},
			daemon       => 1
		}, $class;
	} else {
	  my $commands = [];
		return bless {
			commands => $commands,
			worker   => OWX_Worker->new($owx,$commands,undef,0),
			delayed  => {},
			daemon   => undef
		}, $class;
	}
}

sub _submit($$) {
	my ($self,$command,$hash) = @_;
	if ($self->{daemon}) {
		$self->{requests}->enqueue( $command );
		return 1;
	} else {
		push @{$self->{commands}}, $command;
		return $self->{worker}->work($hash);
	}
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

sub poll($) {
	my ($self,$hash) = @_;
	
	if ($self->{daemon}) {
		# Non-blocking dequeue
		while( my $item = $self->{responses}->dequeue_nb() ) {
	
			my $command = $item->{command};
			
			# Work on $item
			RESPONSE_HANDLER: {
				
				$command eq SEARCH and do {
					return unless $item->{success};
					my @devices = split(/;/,$item->{devices});
					main::OWX_AfterSearch($hash,\@devices);
					last;
				};
				
				$command eq ALARMS and do {
					return unless $item->{success};
					my @devices = split(/;/,$item->{devices});
					main::OWX_AfterAlarms($hash,\@devices);
					last;
				};
					
				$command eq EXECUTE and do {
					main::OWX_AfterExecute($hash,$item->{context},$item->{success},$item->{reset},$item->{address},$item->{writedata},$item->{numread},$item->{readdata});
					last;
				};
				
				$command eq LOG and do {
					my $loglevel = main::GetLogLevel($hash->{NAME},6);
					main::Log($loglevel <6 ? $loglevel : $item->{level},$item->{message});
					last;
				};
				
				$command eq EXIT and do {
					main::OWX_Disconnected($hash);
					last;
				};
			};
		};
	} else {
		$self->{worker}->work($hash);
	}
};

package OWX_Worker;

use strict;
use warnings;

use Time::HiRes qw( gettimeofday tv_interval usleep );

sub new($$$) {
	my ( $class, $owx, $requests, $responses, $daemon ) = @_;
	
	my $self = bless $daemon ? {
		requests  => $requests,
		responses => $responses,
		owx       => $owx,
		daemon    => 1
	} : {
		commands => $requests,
		owx      => $owx,
		daemon   => 0
	}, $class;
	
	$owx->{logger} = $self;
	
	$self->log(5,"OWX_Worker started device $owx->{interface}");
	
	return $self;
};

sub run() {
	my $self = shift;
	eval {
		while ($self->work()) {};
	};
	if ($@) {
		$self->log(2,"Error executing OWX_Worker. Reason: $@");
		$self->{responses}->enqueue({ command => OWX_Executor::EXIT });
	}
	return undef;
};

sub work(;$) {
	my ( $self, $hash ) = @_;
	$self->{hash} = $hash; #store for logger
	my $delayed = $self->{delayed};
	my $item = undef;
	foreach my $address (keys %$delayed) {
		next if (tv_interval($delayed->{$address}->{'until'}) < 0);
		my @now = gettimeofday;
		my @delayed_items = @{$delayed->{$address}->{'items'}}; 
		$item = shift @delayed_items;
		delete $delayed->{$address} unless scalar(@delayed_items);# or $item->{delay};
		last;
	};
	unless ($item) {
		if ($self->{daemon}) {
			$item = $self->{requests}->dequeue_nb();
		} else {
			$item = shift @{$self->{commands}};
		}
		if ($item and my $address = $item->{address}) {
			if ($delayed->{$address}) {
				push @{$delayed->{$address}->{'items'}},$item;
				return 1; 
			};
		};
	};
	unless ($item) {
		if ($self->{daemon}) {
			usleep(1000); #if there is no item to process sleep 1ms so we do not hog the cpu
		}
		return 1;
	}
	REQUEST_HANDLER: {
		my $command = $item->{command};
		
		$command eq OWX_Executor::SEARCH and do {
			my $devices = $self->{owx}->Discover();
			if ($self->{daemon}) {
				if (defined $devices) {
					$item->{success} = 1;
					$item->{devices} = join(';', @{$devices});
				} else {
					$item->{success} = 0;
				}
				$self->{responses}->enqueue($item);
			} elsif (defined $devices) {
				main::OWX_AfterSearch($hash,$devices);
			}
			return 1;
		};
		
		$command eq OWX_Executor::ALARMS and do {
			my $devices = $self->{owx}->Alarms();
			if ($self->{daemon}) {
				if (defined $devices) {
					$item->{success} = 1;
					$item->{devices} = join(';', @{$devices});
				} else {
					$item->{success} = 0;
				}
				$self->{responses}->enqueue($item);
			} elsif (defined $devices) {
				main::OWX_AfterAlarms($hash,$devices);
			}
			return 1;
		};

		$command eq OWX_Executor::EXECUTE and do {
			if (defined $item->{reset}) {
				if(!$self->{owx}->Reset()) {
					if ($self->{daemon}) {
						$item->{success}=0;
						$self->{responses}->enqueue($item);
					} else {
						main::OWX_AfterExecute($hash,$item->{context},undef,1,$item->{address},$item->{writedata},$item->{numread},undef);						
					}
					return 1;
				};
			};
			my $address = $item->{address};
			my $res = $self->{owx}->Complex($address,$item->{writedata},$item->{numread});
			if (defined $res) {
				my $writelen = defined $item->{writedata} ? split (//,$item->{writedata}) : 0;
				my @result = split (//, $res);
				my $readdata = 9+$writelen < @result ? substr($res,9+$writelen) : ""; 
				if ($self->{daemon}) {
					$item->{readdata} = $readdata; 
					$item->{success} = 1;
					$self->{responses}->enqueue($item);
				} else {
					main::OWX_AfterExecute($hash,$item->{context},1,$item->{reset},$item->{address},$item->{writedata},$item->{numread},$readdata);
				}
			} else {
				if ($self->{daemon}) {
					$item->{success} = 0;
					$self->{responses}->enqueue($item);
				} else {
					main::OWX_AfterExecute($hash,$item->{context},undef,$item->{reset},$item->{address},$item->{writedata},$item->{numread},undef);
				}
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
		
		$command eq OWX_Executor::EXIT and do {
			if ($self->{daemon}) {
				$self->{responses}->enqueue($item);
			} else {
				main::OWX_Disconnected($hash);
			}
			return 0;
			#TODO my perl crashes with double deallocation when leaving the thread...
			#return undef; #exit the thread
		};
		$self->log(3,"OWX_Executor: unexpected command: "+$command)
	};
};

sub log($$) {
	my ($self,$level,$msg) = @_;
	if ($self->{daemon}) {
		$self->{responses}->enqueue({
			command => OWX_Executor::LOG,
			level   => $level,
			message => $msg
		});
	} else {
		my $loglevel = main::GetLogLevel($self->{hash}->{NAME},6);
		main::Log($loglevel <6 ? $loglevel : $level,$msg);
	}
};

1;
