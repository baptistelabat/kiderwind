# ####################################################################################
# ####################################################################################
# Nasal script for binding speedbrakes to throttle
#
# ####################################################################################
# Author: Klaus Kerner
# Version: 2011-10-31
#


var speedbrake_throttle_link = func {
  setprop("controls/flight/speedbrake", getprop("controls/engines/engine/throttle"));
  settimer(speedbrake_throttle_link, 0);
}

var linking = setlistener("sim/signals/fdm-initialized", speedbrake_throttle_link);
