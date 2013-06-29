package OWX_Executor;
use constant {
	SEARCH  => 1,
	ALARMS  => 2,
	EXECUTE => 3,
	EXIT    => 4,
	LOG     => 5
};

package OWX_SyncExecutor;
use strict;
use warnings;

sub new($) {
	my ( $class, $owx ) = @_;
	return bless {
		owx => $owx,
		commands => []
	}, $class;
};

sub search() {
	my $self = shift;
	push @{$self->{commands}},{ command => OWX_Executor::SEARCH, devices => $self->{owx}->Discover() }; 
};

sub alarms() {
	my $self = shift;
	push @{$self->{commands}},{ command => OWX_Executor::ALARMS, devices => $self->{owx}->Alarms() }; 
}

sub execute($$$$$$) {
	my ( $self, $context, $reset, $owx_dev, $data, $numread, $delay ) = @_;
	my $owx = $self->{owx};
	my $item = {
		command   => OWX_Executor::EXECUTE,
		context   => $context,
		reset     => $reset,
		address   => $owx_dev,
		writedata => $data,
		numread   => $numread,
		delay     => $delay
	};

	if ($reset) {
		if(!$owx->Reset()) {
			$item->{success}=0;
			push @{$self->{commands}},$item;
			return;
		};
	};
	my $res = $owx->Complex($item->{address},$item->{writedata},$item->{numread});
	if (defined $res) {
		my $writelen = defined $item->{writedata} ? split (//,$item->{writedata}) : 0;
		my @result = split (//, $res);
		$item->{readdata} = 9+$writelen < @result ? substr($res,9+$writelen) : "";
		$item->{success} = 1;
		if ($delay) {
			select (undef,undef,undef,$item->{delay}/1000); #TODO implement device (address) specific wait
		}
	} else {
		$item->{success} = 0;
	}
	push @{$self->{commands}},$item;
};

sub exit($) {
	my ( $self,$hash ) = @_;
	main::OWX_Disconnected($hash);
}

sub poll($) {
	my ($self,$hash) = @_;
	while (my $item = shift @{$self->{commands}}) {
		my $command = $item->{command};
		COMMANDS: {
			$command eq OWX_Executor::SEARCH and do {
				main::OWX_AfterSearch($hash,$item->{devices});
				last;
			};
			$command eq OWX_Executor::ALARMS and do {
				main::OWX_AfterAlarms($hash,$item->{devices});
				last;
			};
			$command eq OWX_Executor::EXECUTE and do {
				main::OWX_AfterExecute($hash,$item->{context},$item->{success},$item->{reset},$item->{address},$item->{writedata},$item->{numread},$item->{readdata});
				last;
			};
		};
	};
};

package OWX_AsyncExecutor;
use strict;
use warnings;
use threads;
use Thread::Queue;

sub new($) {
	my ( $class, $owx ) = @_;
	my $requests   = Thread::Queue->new();
	my $responses  = Thread::Queue->new();
	my $worker = OWX_Worker->new($owx,$requests,$responses);
	my $thr = threads->create(
			sub {
				$worker->run();
			}
		)->detach();
	return bless {
		requests     => $requests,
		responses    => $responses,
		workerthread => $thr,
		owx => $owx,
	}, $class;
}

sub search() {
	my $self = shift;
	$self->{requests}->enqueue( { command => OWX_Executor::SEARCH } );
}

sub alarms() {
	my $self = shift;
	$self->{requests}->enqueue( { command => OWX_Executor::ALARMS } );
}

sub execute($$$$$$) {
	my ( $self, $context, $reset, $owx_dev, $data, $numread, $delay ) = @_;
	$self->{requests}->enqueue(
		{
			command   => OWX_Executor::EXECUTE,
			context   => $context,
			reset     => $reset,
			address   => $owx_dev,
			writedata => $data,
			numread   => $numread,
			delay     => $delay
		}
	);
};

sub exit($) {
	my ( $self,$hash ) = @_;
	$self->{requests}->enqueue(
		{
			command => OWX_Executor::EXIT
		}
	);
}

sub poll($) {
	my ($self,$hash) = @_;
	
	# Non-blocking dequeue
	while( my $item = $self->{responses}->dequeue_nb() ) {

		my $command = $item->{command};
		
		# Work on $item
		RESPONSE_HANDLER: {
			
			$command eq OWX_Executor::SEARCH and do {
				return unless $item->{success};
				my @devices = split(/;/,$item->{devices});
				main::OWX_AfterSearch($hash,\@devices);
				last;
			};
			
			$command eq OWX_Executor::ALARMS and do {
				return unless $item->{success};
				my @devices = split(/;/,$item->{devices});
				main::OWX_AfterAlarms($hash,\@devices);
				last;
			};
				
			$command eq OWX_Executor::EXECUTE and do {
				main::OWX_AfterExecute($hash,$item->{context},$item->{success},$item->{reset},$item->{address},$item->{writedata},$item->{numread},$item->{readdata});
				last;
			};
			
			$command eq OWX_Executor::LOG and do {
				my $loglevel = main::GetLogLevel($hash->{NAME},6);
				main::Log($loglevel <6 ? $loglevel : $item->{level},$item->{message});
				last;
			};
			
			$command eq OWX_Executor::EXIT and do {
				main::OWX_Disconnected($hash);
				last;
			};
		};
	};
};

package OWX_Worker;

use strict;
use warnings;

use Time::HiRes qw( gettimeofday tv_interval usleep );

sub new($$$) {
	my ( $class, $owx, $requests, $responses ) = @_;

	return bless {
		requests  => $requests,
		responses => $responses,
		owx       => $owx
	}, $class;
};

sub run() {
	my $self = shift;
	my $requests = $self->{requests};
	my $responses = $self->{responses};
	my %delayed = ();
	my $owx = $self->{owx};
	$owx->{logger} = $self;
	while ( 1 ) {
	  my $item = undef;
		foreach my $address (keys %delayed) {
			next if (tv_interval($delayed{$address}->{'until'}) < 0);
			my @now = gettimeofday;
			my @delayed_items = @{$delayed{$address}->{'items'}}; 
			$item = shift @delayed_items;
			delete $delayed{$address} unless scalar(@delayed_items);# or $item->{delay};
			last;
		};
		unless ($item) {
			$item = $requests->dequeue_nb();
			if ($item and my $address = $item->{address}) {
				if ($delayed{$address}) {
					push @{$delayed{$address}->{'items'}},$item;
					next; 
				};
			};
		};
		unless ($item) {
			usleep(1000); #if there is no item to process sleep 1ms so we do not hog the cpu
			next;
		}
		REQUEST_HANDLER: {
			my $command = $item->{command};
			
			$command eq OWX_Executor::SEARCH and do {
				my $devices = $owx->Discover();
				if (defined $devices) {
					$item->{success} = 1;
					$item->{devices} = join(';', @{$devices});
				} else {
					$item->{success} = 0;
				}
				$responses->enqueue($item);
				last;
			};
			
			$command eq OWX_Executor::ALARMS and do {
				my $devices = $owx->Alarms();
				if (defined $devices) {
					$item->{success} = 1;
					$item->{devices} = join(';', @{$devices});
				} else {
					$item->{success} = 0;
				}
				$responses->enqueue($item);
				last;
			};
	
			$command eq OWX_Executor::EXECUTE and do {
				if (defined $item->{reset}) {
					if(!$owx->Reset()) {
						$item->{success}=0;
						$responses->enqueue($item);
						last;
					};
				};
				my $address = $item->{address};
				my $res = $owx->Complex($address,$item->{writedata},$item->{numread});
				if (defined $res) {
					my $writelen = defined $item->{writedata} ? split (//,$item->{writedata}) : 0;
					my @result = split (//, $res);
					$item->{readdata} = 9+$writelen < @result ? substr($res,9+$writelen) : "";
					$item->{success} = 1;
					$responses->enqueue($item);
				} else {
					$item->{success} = 0;
					$responses->enqueue($item);
				}
				if (my $delay = $item->{delay}) {
					if ($address) {
						unless ($delayed{$address}) {
							$delayed{$address} = { items => [] };
						}
						my ($seconds,$micros) = gettimeofday;
            my $len = length ($delay); #delay is millis, tv_address works with [sec,micros]
            if ($len>3) {
              $seconds += substr($delay,0,$len-3);
              $micros += (substr ($delay,$len-8).000);
            } else {
              $micros += ($delay.000);
            }
						$delayed{$address}->{'until'} = [$seconds,$micros];
					} else {
						select (undef,undef,undef,$delay/1000);
					}
				}
				last;
			};
			
			$command eq OWX_Executor::EXIT and do {
				$responses->enqueue($item);
				last;
				#TODO my perl crashes with double deallocation when leaving the thread...
				#return undef; #exit the thread
			};
		};
	};
};

sub log($$) {
	my ($self,$level,$msg) = @_;
	my $responses = $self->{responses};
	$responses->enqueue({
		command => OWX_Executor::LOG,
		level   => $level,
		message => $msg
	});
};

1;
