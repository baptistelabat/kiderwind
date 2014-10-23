# ####################################################################################
# ####################################################################################
# Nasal script for dialogs
#
# ####################################################################################
# Author: Klaus Kerner
# Version: 2012-07-09
#

# ####################################################################################
# basic fucntions to create dialogs
var config_dialog = gui.Dialog.new("sim/gui/dialogs/kider/config/dialog", 
                                   "Aircraft/kider/Dialogs/config.xml");

var aerotowing_ai_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/kider/aerotowing_ai/dialog", 
                                  "Aircraft/kider/Dialogs/aerotowing_ai.xml");

var aerotowing_advanced_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/kider/aerotowing_advanced/dialog",
                                  "Aircraft/kider/Dialogs/aerotowing_advanced.xml");


var dragrobot_dialog = gui.Dialog.new("sim/gui/dialogs/kider/dragrobot/dialog", 
                                  "Aircraft/kider/Dialogs/dragrobot.xml");
var dragrobot_advanced_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/kider/dragrobot_advanced/dialog",
                                  "Aircraft/kider/Dialogs/dragrobot_advanced.xml");

var winch_dialog = gui.Dialog.new("sim/gui/dialogs/kider/winch/dialog", 
                                  "Aircraft/kider/Dialogs/winch.xml");

var winch_advanced_dialog = gui.Dialog.new(
                                  "sim/gui/dialogs/kider/winch_advanced/dialog", 
                                  "Aircraft/kider/Dialogs/winch_advanced.xml");


# ####################################################################################
# config dialog: helper function to display masses in SI units than imperial units
var guiUpdateConfig = func {
    # pilot's mass 
    if ( getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs") == nil ) {
        var mass_pilot_kg = 80;
    }
    else {
        var mass_pilot_kg = getprop(
                             "/fdm/jsbsim/inertia/pointmass-weight-lbs") * 0.45359237;
    }
    setprop("sim/glider/gui/config/mass_pilot_kg", mass_pilot_kg);
    
    # water tank masses 
    if ( getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]") == nil ) {
        var mass_tank_kg = 0;
    }
    else {
        var mass_tank_kg = getprop(
                          "/fdm/jsbsim/inertia/pointmass-weight-lbs[1]") * 0.45359237;
        # cleanup a bug as the gui slider does only update one property, not two
        setprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]", 
                getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]") );
    }
    setprop("sim/glider/gui/config/mass_tank_kg", mass_tank_kg);
    
    # payload mass 
    if ( getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]") == nil ) {
        var mass_payload_kg = 0;
    }
    else {
        var mass_payload_kg = getprop(
                          "/fdm/jsbsim/inertia/pointmass-weight-lbs[3]") * 0.45359237;
    }
    setprop("sim/glider/gui/config/mass_payload_kg", mass_payload_kg);
}

var guiconfiginit = setlistener("sim/signals/fdm-initialized", 
                                 guiUpdateConfig,,0);
var guiconfig1    = setlistener("/fdm/jsbsim/inertia/pointmass-weight-lbs", 
                                 guiUpdateConfig,,0);
var guiconfig2    = setlistener("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]", 
                                 guiUpdateConfig,,0);
var guiconfig3    = setlistener("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]", 
                                 guiUpdateConfig,,0);

 
# ####################################################################################
# winch dialog: helper function to cancel the winch, avoiding race conditions
var guiWinchCancel = func {
    kider.removeWinch();
    kider.resetWinch();
}
 


# ####################################################################################
# winch dialog: helper function to display winch operation points
var guiUpdateWinch = func {
    if ( getprop("sim/glider/winch/conf/pull_max_lbs") == nil ) {
        var pull_max_lbs = 1100;
    }
    else {
        var pull_max_lbs = getprop("sim/glider/winch/conf/pull_max_lbs");
    }
    var pull_max_daN = pull_max_lbs * 0.45359237;
    setprop("sim/glider/gui/winch/pull_max_daN", pull_max_daN);
    
    if ( getprop("sim/glider/winch/conf/pull_max_speed_mps") == nil ) {
        var pull_max_speed_mps = 40;
    }
    else {
        var pull_max_speed_mps = getprop("sim/glider/winch/conf/pull_max_speed_mps");
    }
    var pull_max_speed_kmh = pull_max_speed_mps * 3.6;
    setprop("sim/glider/gui/winch/pull_max_speed_kmh", pull_max_speed_kmh);
    
  # for the speed correction, relative factors are used: 
    #  k_speed_x1 = speed_x1 / pull_max_speed_mps
    #  or: speed_x1 = k_speed_x1 * pull_max_speed_mps
    if ( getprop("sim/glider/winch/conf/k_speed_x1") == nil ) {
        var k_speed_x1 = 0.85;
    }
    else {
        var k_speed_x1 = getprop("sim/glider/winch/conf/k_speed_x1");
    }
    var speed_x1 = k_speed_x1 * pull_max_speed_mps * 3.6;
    setprop("sim/glider/gui/winch/speed_x1", speed_x1);
    
    #  k_speed_y2 = speed_y2 / pull_max_lbs
    #  or: speed_y2 = k_speed_y2 * pull_max_lbs
    if ( getprop("sim/glider/winch/conf/k_speed_y2") == nil ) {
        var k_speed_y2 = 0.00;
    }
    else {
        var k_speed_y2 = getprop("sim/glider/winch/conf/k_speed_y2");
    }
    var speed_y2 = k_speed_y2 * pull_max_lbs * 0.45359237;
    setprop("sim/glider/gui/winch/speed_y2", speed_y2);
    
  # for the angle correction, relative factors are used: 
    #  k_angle_x1 = angle_x1 / 70 (as 70° is hard-coded, not changeable)
    #  or: angle_x1 = k_angle_x1 * 70
    if ( getprop("sim/glider/winch/conf/k_angle_x1") == nil ) {
        var k_angle_x1 = 0.75;
    }
    else {
        var k_angle_x1 = getprop("sim/glider/winch/conf/k_angle_x1");
    }
    var angle_x1 = k_angle_x1 * 70;
    setprop("sim/glider/gui/winch/angle_x1", angle_x1);
    
    #  k_angle_y2 = angle_y2 / pull_max_lbs
    #  or: angle_y2 = k_angle_y2 * pull_max_lbs
    if ( getprop("sim/glider/winch/conf/k_angle_y2") == nil ) {
        var k_angle_y2 = 0.30;
    }
    else {
        var k_angle_y2 = getprop("sim/glider/winch/conf/k_angle_y2");
    }
    var angle_y2 = k_angle_y2 * pull_max_lbs * 0.45359237;
    setprop("sim/glider/gui/winch/angle_y2", angle_y2);
}

var guiwinchinit = setlistener("sim/sginals/fdm-initialized", 
                                     guiUpdateWinch,,0);
var guiwinchspeed_x   = setlistener("sim/glider/winch/conf/pull_max_speed_mps", 
                                     guiUpdateWinch,,0);
var guiwinchforce_x   = setlistener("sim/glider/winch/conf/pull_max_lbs", 
                                     guiUpdateWinch,,0);
var guikspeedx1       = setlistener("sim/glider/winch/conf/k_speed_x1", 
                                     guiUpdateWinch,,0);
var guikspeedy2       = setlistener("sim/glider/winch/conf/k_speed_y2", 
                                     guiUpdateWinch,,0);
var guikanglex1       = setlistener("sim/glider/winch/conf/k_angle_x1", 
                                     guiUpdateWinch,,0);
var guikangley2       = setlistener("sim/glider/winch/conf/k_angle_y2", 
                                     guiUpdateWinch,,0);


# ####################################################################################
# drag-robot dialog: helper function to display properties in better readable SI units
var guiUpdateDragRobot = func {
    # min. takeoff speed 
    if ( getprop("sim/glider/dragger/conf/glob_min_speed_takeoff_mps") == nil ) {
        var min_speed_takeoff = 20 * 3.6;
    }
    else {
        var min_speed_takeoff = getprop(
                          "sim/glider/dragger/conf/glob_min_speed_takeoff_mps") * 3.6;
    }
    setprop("sim/glider/gui/dragrobot/min_speed_takeoff", min_speed_takeoff);
    
    # max. speed 
    if ( getprop("sim/glider/dragger/conf/glob_max_speed_mps") == nil ) {
        var max_speed = 36 * 3.6;
    }
    else {
        var max_speed = getprop("sim/glider/dragger/conf/glob_max_speed_mps") * 3.6;
    }
    setprop("sim/glider/gui/dragrobot/max_speed", max_speed);
    
    # max. tauten speed 
    if ( getprop("sim/glider/dragger/conf/glob_max_speed_tauten_mps") == nil ) {
        var max_speed_tauten = 3 * 3.6;
    }
    else {
        var max_speed_tauten = getprop(
                           "sim/glider/dragger/conf/glob_max_speed_tauten_mps") * 3.6;
    }
    setprop("sim/glider/gui/dragrobot/max_speed_tauten", max_speed_tauten);
    
}


# ####################################################################################
# drag-robot dialog: helper function to run the roboter, avoiding race conditions
var guiRunDragRobot = func {
    kider.findDragger();
    kider.hookDragger();
    kider.startDragRobot();
}


# ####################################################################################
# drag-robot dialog: helper function to cancel the roboter, avoiding race conditions
var guiCancelDragRobot = func {
    kider.removeDragRobot();
    kider.resetRobotAttributes();
    kider.removeTowingRope();
}


var guidragrobotinit = setlistener("sim/signals/fdm-initialized", 
                                     guiUpdateDragRobot,,0);
var guidragrobot_1   = setlistener("sim/glider/dragger/conf/glob_min_speed_takeoff_mps", 
                                     guiUpdateDragRobot,,0);
var guidragrobot_2   = setlistener("sim/glider/dragger/conf/glob_max_speed_mps", 
                                     guiUpdateDragRobot,,0);
var guidragrobot_3   = setlistener("sim/glider/dragger/conf/glob_max_speed_tauten_mps", 
                                     guiUpdateDragRobot,,0);
















