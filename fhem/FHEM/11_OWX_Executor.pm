package OWX_Executor;

use strict;
use warnings;

use constant {
	SEARCH  => 1,
	ALARMS  => 2,
	EXECUTE => 3,
	EXIT    => 4,
	LOG     => 5
};

sub new($) {
	my ( $class, $owx ) = @_;

	return bless {
		worker => OWX_Worker->new($owx)
	}, $class;
}

sub search($) {
	my ($self,$hash) = @_;
	if($self->{worker}->submit( { command => SEARCH }, $hash )) {
		$self->poll($hash);
		return 1;
	}
	return undef;
}

sub alarms($) {
	my ($self,$hash) = @_;
	if($self->{worker}->submit( { command => ALARMS }, $hash )) {
		$self->poll($hash);
		return 1;
	}
	return undef;
}

sub execute($$$$$$$) {
	my ( $self, $hash, $context, $reset, $owx_dev, $data, $numread, $delay ) = @_;
	if($self->{worker}->submit( {
		command   => EXECUTE,
		context   => $context,
		reset     => $reset,
		address   => $owx_dev,
		writedata => $data,
		numread   => $numread,
		delay     => $delay
 		}, $hash )) {
		$self->poll($hash);
		return 1;
	}
	return undef;
};

sub exit($) {
	my ( $self,$hash ) = @_;
	if($self->{worker}->submit( { command => EXIT }, $hash )) {
		$self->poll($hash);
		return 1;
	}
	return undef;
}

sub poll($) {
	my ( $self,$hash ) = @_;
	$self->{worker}->PT_SCHEDULE($hash);
}

# start of worker code

package OWX_Worker;

use Time::HiRes qw( gettimeofday tv_interval usleep );
use ProtoThreads;

use vars qw/@ISA/;
@ISA='ProtoThreads';

sub new($) {
	my ($class,$owx) = @_;
	
	my $worker = PT_THREAD(\&pt_main);
	
	$worker->{commands} = [];
	$worker->{delayed} = {};
	$worker->{pt_search} = PT_THREAD(\&pt_search);
	$worker->{pt_search}->{owx} = $owx;
	$worker->{pt_alarms} = PT_THREAD(\&pt_alarms);
	$worker->{pt_alarms}->{owx} = $owx;
	$worker->{pt_execute} = PT_THREAD(\&pt_execute);
	$worker->{pt_execute}->{owx} = $owx;
	$worker->{pt_execute}->{delayed} = $worker->{delayed};  
	
	return bless $worker,$class;  
}

sub submit($$) {
	my ($self,$command,$hash) = @_;
	push @{$self->{commands}}, $command;
    $self->PT_SCHEDULE($hash);
	return 1;
}

sub pt_main($) {
	my ( $self, $hash ) = @_;
    my $item = undef;
    PT_BEGIN($self);
	PT_YIELD_UNTIL($item = $self->nextItem());
	
	REQUEST_HANDLER: {
		my $command = $item->{command};
		
		$command eq OWX_Executor::SEARCH and do {
			PT_WAIT_THREAD($self->{pt_search},$hash);
			PT_EXIT;
		};
		
		$command eq OWX_Executor::ALARMS and do {
			PT_WAIT_THREAD($self->{pt_alarms},$hash);
			PT_EXIT;
		};

		$command eq OWX_Executor::EXECUTE and do {
			PT_WAIT_THREAD($self->{pt_execute},$hash,$item);
			PT_EXIT;
		};
		
		$command eq OWX_Executor::EXIT and do {
			main::OWX_Disconnected($hash);
			PT_EXIT;
		};
		main::Log3($hash->{NAME},3,"OWX_Executor: unexpected command: "+$command);
	};
	PT_END;
};

sub nextItem() {
	my ( $self ) = @_;
	my $item = undef;
	my $delayed = $self->{delayed};
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
				return undef; 
			};
		};
	};
	return $item;
}

sub pt_search($) {
	my ( $self, $hash ) = @_;
    PT_BEGIN($self);
	my $devices = $self->{owx}->Discover();
	if (defined $devices) {
		main::OWX_AfterSearch($hash,$devices);
	}
	PT_END;
};

sub pt_alarms($) {
	my ( $self, $hash ) = @_;
    PT_BEGIN($self);
	my $devices = $self->{owx}->Alarms();
	if (defined $devices) {
		main::OWX_AfterAlarms($hash,$devices);
	}
	PT_END;
};

sub pt_execute($) {
	my ( $self, $hash, $item ) = @_;
    PT_BEGIN($self);
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
			my $delayed = $self->{delayed};
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
	PT_END;
};

1;
