##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

#use myCtrlHAL;
require "$attr{global}{modpath}/FHEM/myCtrlHAL.pm";
require "$attr{global}{modpath}/FHEM/99_myCtrlBase.pm";
#require "$attr{global}{modpath}/FHEM/99_myCtrlVoice.pm";

sub
myCtrlAutomation_Initialize($$)
{
  my ($hash) = @_;
  Log 2, "AutomationControlUser: initialized";
}

sub
myCtrlAutomation_Undef($$)
{
  Log 2, "AutomationControlUser: clean-up";
  return undef;
}

###############################################################################

# --- User Methods ------------------------------------------------------------

# TODO


###############################################################################
1;
