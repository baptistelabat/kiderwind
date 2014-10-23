# ####################################################################################
# ####################################################################################
# Nasal script to manage waterballast for the DG-101G
#
# ####################################################################################
# Author: Klaus Kerner
# Version: 2010-10-31
#
# ####################################################################################
# Concepts:
# 1. fill water tanks
# 2. toggle dumping water
# 3. refill if desired


# existing proterties, that are used to handle the waterballast

# ## required properties from the jsbsim config file,point masses
# /fdm/jsbsim/inertia/pointmass-weight-lbs[1]    tank 1, created by jsbsim config file
# /fdm/jsbsim/inertia/pointmass-weight-lbs[2]    tank 2, created by jsbsim config file

# ## new properties to handle the balast and animations
# /sim/glider/ballast/mass_per_tank_lbs              initial ballast per tank
# /sim/glider/ballast/mass_lbs_per_second            amount of water for dropping
# /sim/glider/ballast/drop                           flag for dropping water balast
#                                                      1: drop water 
#                                                      0: do not drop water



# ####################################################################################
# ####################################################################################
# initialise water ballast system
var initBallast = func {
  # close the valve
  setprop("sim/glider/ballast/drop", 0);
  # check for defined max amount of water per tank by config file
  # if not set a default value of 50kg (110lbs) per tank
  if ( getprop("sim/glider/ballast/mass_per_tank_lbs") == nil ) {
    atc_msg("set default water ballast: 110lbs");
    setprop("sim/glider/ballast/mass_per_tank_lbs", 110);
  }
  # check for defined water flow at dropping ballast, 
  # if not set a default value
  if ( getprop("sim/glider/ballast/mass_lbs_per_second") == nil ) {
    atc_msg("set default drop rate: 2lbs/s");
    setprop("sim/glider/ballast/mass_lbs_per_second", 2);
  }
}



# ####################################################################################
# ####################################################################################
# load water ballast
var loadBallast = func {
  
  # fill the tanks
  setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[1]", 
              getprop("sim/glider/ballast/mass_per_tank_lbs") );
  setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[2]", 
              getprop("sim/glider/ballast/mass_per_tank_lbs") );
  
  atc_msg("tanks loaded with water");
  
}


# ####################################################################################
# ####################################################################################
# dump water ballast
var toggleBallastDump = func {
  # drop of water is calculated by remaining water in tanks and drop-rate
  var droprate_lbps = getprop("sim/glider/ballast/mass_lbs_per_second");
  var tank1 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[1]");
  var tank2 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[2]");
  var status = getprop("sim/glider/ballast/drop");
  
  
  if ( status > 0 ) { # if valve will be opened
    # calculate remaining time till tanks are empty
    if ( tank1 <= droprate_lbps ) {
      interpolate("fdm/jsbsim/inertia/pointmass-weight-lbs[1]", 0, 1);
    }
    else {
      interpolate("fdm/jsbsim/inertia/pointmass-weight-lbs[1]", 
                   tank1 - droprate_lbps, 1);
    }
    if ( tank2 <= droprate_lbps ) {
      interpolate("fdm/jsbsim/inertia/pointmass-weight-lbs[2]", 0, 1);
    }
    else {
      interpolate("fdm/jsbsim/inertia/pointmass-weight-lbs[2]", 
                   tank2 - droprate_lbps, 1);
    }
    
    # interpolate drop property for smooth animation
    interpolate("sim/glider/ballast/drop", 0 , 1);
  }
  else { # if valve will be closed
    # interpolate drop property for smooth animation
    interpolate("sim/glider/ballast/drop", 1 , 1);
    
    var time1 = tank1/droprate_lbps;
    var time2 = tank2/droprate_lbps;
    
    interpolate("fdm/jsbsim/inertia/pointmass-weight-lbs[1]", 0, time1);
    interpolate("fdm/jsbsim/inertia/pointmass-weight-lbs[2]", 0, time2);
  }
  
}

# initialize water ballast at startup, after FDM is initialized
var initializing_ballast = setlistener("sim/signals/fdm-initialized", initBallast);
