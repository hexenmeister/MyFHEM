##############################################
# $Id$
package main;

use strict;
use warnings;
use POSIX;
use Time::Local;

use constant {
 
 ATTR_NAME_DEVLOCATION => "devLocation", # Attribut mit dem Standort zum Vorlesen etc.
 STATE_NAME_WIN_OPENED => "open", # Status: Fenster /Tuer ofen
 STATE_NAME_WIN_CLOSED => "closed", # Status: Fenster / Tuer zu
 STATE_NAME_WIN_TILTED => "tilted", # Status: Fenster gekippt

};

# --- Konstanten fuer die verwendeten Device/Element-Namen (TODO: Element_XXX Umbenennen) ----------------------------
use constant {
	DEVICE_NAME_TTS    => "tts",
  DEVICE_NAME_WEATHER => "Wetter",
  DEVICE_NAME_JABBER => "jabber",
 
  DEVICE_NAME_CTRL_ANWESENHEIT    => "T.DU_Ctrl.Anwesenheit",
  DEVICE_NAME_GC_ANWESENHEIT      => "GC_Abwesend",
  DEVICE_NAME_CTRL_ZIRK_PUMPE     => "T.DU_Ctrl.ZP_Mode",
  DEVICE_NAME_CTRL_BESCHATTUNG    => "T.DU_Ctrl.Beschattung",
  DEVICE_NAME_CTRL_ROLLADEN_DAY_NIGHT => "T.DU_Ctrl.Rolladen", # reserved for future use
  # Element, dessen Readings persistenten Steuerungsdaten speichern. Es ist eigentlich egel, an welchen Device/Element diese landen.
  DEVICE_NAME_CTRL_STORE => "T.DU_Ctrl.Rolladen",
  
  DEVICE_NAME_FK_WZ1  => "EG_WZ_FK01.Fenster",
  DEVICE_NAME_FK_WZ2l => "wz_fenster_l",
  DEVICE_NAME_FK_WZ2r => "wz_fenster_r",
  DEVICE_NAME_FK_KU1  => "EG_KU_FK01.Fenster",
  DEVICE_NAME_FK_BZ1  => "OG_BZ_FK01.Fenster",
  DEVICE_NAME_FK_SZ1  => "OG_SZ_FK01.Fenster",
  DEVICE_NAME_FK_KA1l => "", # Paulas Zimmer
  DEVICE_NAME_FK_KA1r => "", # Paulas Zimmer
  DEVICE_NAME_FK_KB1  => "", # Hannas Zimmer
};

# --- Konstanten für die Werte f. Auto, Enabled, Disabled
use constant {
  AUTOMATIC    => "Automatik",
  ENABLED      => "Aktiviert",
  DISABLED     => "Deaktiviert",
  #ON          => "Ein",
  #OFF         => "Aus",
  PRESENT      => "Anwesend",
  ABSENT       => "Abwesend",
  FAR_AWAY     => "Verreist"
};

sub
myCtrlHAL_Initialize($$)
{
  my ($hash) = @_;
}

################################################################################
# liefert Liste der Tueren und Fenster, die bestimmten Status haben
#  >list model=HM-SEC-RHS:FILTER=state=closed
#  Param: gesuchter Status (also geschlossen, offen oder gekippt)
#         NOT-modifikator: wenn defined wird nach Devices gesucht, die NICHT im
#                          angegbenen Status sind.
#  Returns: Liste der Fenter in gewuenschten Status. 
#    Die Elemente der Liste sind Werte fuer ATTR_NAME_DEVLOCATION, 
#    wenn nicht vorhanden, dann 'alias', wenn auch nicht vorhanden, dann NAME
################################################################################
sub getWindowDoorList($;$) {
 my($state, $not)=@_;
 my $spec = 'model=HM-SEC-RHS:FILTER=state='.$state;
 if(defined($not)) {
   $spec = 'model=HM-SEC-RHS:FILTER=state!='.$state;
 }
 my @ret;
 my @devArray = devspec2array($spec);
 foreach my $d (@devArray) {
   next unless $d;
   my $dName = $defs{$d}{NAME};
   my $dAlias = AttrVal($dName,+ATTR_NAME_DEVLOCATION,undef);
   $dAlias = AttrVal($dName,'alias',undef) unless defined $dAlias;
   $dAlias = $dName unless defined $dAlias;
   push(@ret, $dAlias);
 }
 return @ret;
}

# Liefert Liste aller Fenster (Namen). Keine Terrassentueren.
# Festdefinierte Liste, muss ggf. angepasst werden.
sub getAllWindowNames() {
	return [DEVICE_NAME_FK_WZ1,  
	        DEVICE_NAME_FK_KU1,  DEVICE_NAME_FK_BZ1,  DEVICE_NAME_FK_SZ1,
          DEVICE_NAME_FK_KA1l, DEVICE_NAME_FK_KA1r, DEVICE_NAME_FK_KB1];
}

# Liefert Liste aller Fenster (Namen).
# Festdefinierte Liste, muss ggf. angepasst werden.
sub getGardenDoors() {
	return [DEVICE_NAME_FK_WZ2l, DEVICE_NAME_FK_WZ2r];
}

# TODO:

1;
