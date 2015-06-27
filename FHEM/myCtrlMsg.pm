##############################################
# $Id$
package main;

use strict;
use warnings;
use Switch;
use POSIX;
#use Time::Local;

#use myCtrlHAL;
#require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";
require "$attr{global}{modpath}/FHEM/99_myCtrlBase.pm";
require "$attr{global}{modpath}/FHEM/99_myCtrlVoice.pm";
require "$attr{global}{modpath}/FHEM/99_myCtrlJabber.pm";

use constant {
  MSG_OUT_VOICE    => "voice",
  MSG_OUT_HANDY    => "handy",
  
  MSG_OUT_DEFAULT  => "handy",
};

use constant {
  MSG_OUT_DEFAULT  => MSG_OUT_HANDY
};

sub
myCtrlMsg_Initialize($$)
{
  my ($hash) = @_;
}

#
# Msg-Hash-Format:
# $msg->{type}     => Art der Meldung (Fenster warnung, etc.)
# $msg->{subType}  => UnterArt der Meldung
# $msg->{severity} => SchwereGrad, kann benutzt werden, um z.B. eine Voranmeldung auszugeben
# $msg->{output}   => Ausgabekanal: XABBER, VOICE
# $msg->{text}     => Meldungsinhalt
# $msg->{to}       => Empfaenger (optional)
#

sub _Msg2Text($) {
	my($msg) = @_;
	
	my $type = $msg->{type}; $type="-" unless $type;
	my $subType = $msg->{subType}; $subType="-" unless $subType;
	my $severity = $msg->{severity}; $severity="-" unless $severity;
	my $output = $msg->{output}; $output="-" unless $output;
	my $text = $msg->{text}; $text="-" unless $text;
	my $to = $msg->{to}; $to="-" unless $to;
	
	my $ltext = "to: $to, type: $type, subType: $subType, severity: $severity, output: $output, text: $text";
	return $ltext;
}

###############################################################################
# Eine Meldung an den Benutzer absetzen. 
# Je nach Meldung werden mehrere Arten der Kanaele unterstuetzt (auch gleichzeitig)
# Voice-Meldung, Jabber_meldung, ...
# TODO: Unterstuetzung fuer Umleitung der einzelnen Kanaele.
# TODO: Unterstuetzung fuer 'Stummschaltung' einzelnen Kanaele je nach 'Dinglichkeit'
# 
# TODO: Doku
# 
# Aufruf: sendUserMessage(type=>'xyz', text=>'Hallo');
sub sendUserMessage(%) {
	my (%msg) = @_;
	
	myLog(undef, 3, _Msg2Text(\%msg));
	
	#voiceNotificationMsgWarn(100);
  #speak("Fenster in ".getDeviceLocation($deviceName,"unbekannt")." ist seit ueber ".rundeZahl0($dauer/60)." Minuten gekippt!",0);
  
  #speak($msg{text},0);
  # myLog(undef, 3, $msg{text});
  #
  
  # TODO: Umleitungen
  
  my $output = $msg{output};
  $output = MSG_OUT_DEFAULT unless $output;
  
  my $text = $msg{text};
  
  #if($output eq MSG_OUT_VOICE) {
  #	
  #} elsif($output eq MSG_OUT_VOICE)
  
  if($text) {
    switch ($output) {
    	case MSG_OUT_VOICE {
    		# TODO : Notification
    		#voiceNotificationMsgWarn(100);
    		# TODO: Lautstaerke
        speak($text,0);
      }
    	
    	case MSG_OUT_HANDY {
    		# TODO: Verschiedenen Empfaenger
    		sendMeJabberMessage($text);
    	}
    	
    	else {
    		sendMeJabberMessage($text);
    		myLog(undef, 3, "unexpected message output way: ".$output);
    	}
    }
  } else {
  	myLog(undef, 3, "undefined message text");
  }
  
}

# TODO: .

1;
