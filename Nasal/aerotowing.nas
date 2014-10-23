# ####################################################################################
# ####################################################################################
# Nasal script to handle aerotowing, with AI-dragger
#
# ####################################################################################
# Author: Klaus Kerner
# Version: 2012-03-16
#
# ####################################################################################
# Concepts:
# 1. search for allready existing dragger in the property tree
# 2. if an existing dragger is too far away or no dragger exists: create a new one
# 3. hook in to the dragger, that is close to the glider
# 4. lift up into the air
# 5. finish towing

# ## properties tree setup
# to handle the aerotowing functionality following setup of the properties tree
# has been used
# /sim/glider/towing                         base node
# /sim/glider/towing/glob                    node, keeping all global configuration
#                                             attributes (default values)
# /sim/glider/towing/conf                    node, keeping all current configuration
#                                             attributes (currently in use)
# /sim/glider/towing/list                    node, keeping all possible candidates for
#                                             aerotowing, mainly used by gui

# existing properties from ai branch, to handle the dragger (or the drag-robot)
# /ai/models/xyz[x]                                       the dragger that lifts me up
#  ./id                                                   the id of the ai-model
#  ./callsign                                             the callsign of the dragger
#  ./position/latitude-deg                                latitude of dragger
#  ./position/longitude-deg                               longitude of dragger
#  ./position/altitude-ft                                 height of dragger
#  ./orientation/true-heading-deg                         heading
#  ./orientation/pitch-deg                                pitch
#  ./orientation/roll-deg                                 roll
#  ./velocities/true-airspeed-kt                          speed
#
# ## existing properties to get glider orientation
# /orientation/heading-deg
# /orientation/pitch-deg
# /orientation/roll-deg

# ## existing proterties from jsbsim config file, that are used to handle 
#     the towing forces
# /fdm/jsbsim/fcs/dragger-cmd-norm                       created by jsbsim config file
#                                                          1: dragger engaged
#                                                          0: drager not engaged
# /fdm/jsbsim/external_reactions/dragx/magnitude         created by jsbsim config file
# /fdm/jsbsim/external_reactions/dragy/magnitude         created by jsbsim config file
# /fdm/jsbsim/external_reactions/dragz/magnitude         created by jsbsim config file

# ## new properties to handle the dragger
# /sim/glider/towing/conf/...                     property tree current configuration
# /sim/glider/towing/glob/...                     property tree generic configuration
# .../rope_length_m                                length of rope, 
#                                                    set by config file or default
# .../nominal_towforce_lbs                         nominal force at nominal distance
# .../breaking_towforce_lbs                        max. force of tow
# .../rope_x1                                      describes relative starting point
#                                                    for force
# .../rope_characteristics                         describes force/elongation ratio
#                                                    of rope

# /sim/glider/towing/dragid                       the ID of /ai/models/xyz[x]/id
# /sim/glider/towing/hooked                       flag to control engaged tow
#                                                   1: rope hooked in
#                                                   0: rope not hooked in
# /sim/glider/towing/list/candidate[x]            keeps possible draggers
# /sim/glider/towing/list/candidate[x]/type       keeps type of dragger
#                                                   MP=multiplayer, 
#                                                   AI=ai-plane, 
#                                                   DR=drag roboter
# /sim/glider/towing/list/candidate[x]/id         the id from /ai/models/xyz[x]/id
# /sim/glider/towing/list/candidate[x]/callsign   the according callsign
# /sim/glider/towing/list/candidate[x]/distance   the distance to the glider
# /sim/glider/towing/list/candidate[x]/selected   boolean for choosen candidate

# ## new properties to handle animated towing rope
# /ai/models/towrope/...
# .../id
# .../callsign
# .../valid
# .../position/latitude-deg
# .../position/longitude-deg
# .../position/altitude-ft
# .../orientation/true-heading-deg
# .../orientation/pitch-deg
# .../orientation/roll-deg
# /models/model[x]/...
# .../path
# .../longitude-deg-prop
# .../latitude-deg-prop
# .../elevation-ft-prop
# .../heading-deg-prop
# .../roll-deg-prop
# .../pitch-deg-prop
# /sim/glider/towrope/...
# .../data/id_AI
# .../data/id_model
# .../data/rope_distance_m
# .../data/xstretch_rel
# .../data/rope_heading_deg
# .../data/rope_pitch_deg
# .../data/rope_roll_deg
# .../flag/exist


# ####################################################################################
# global variables in this module
var towing_timeincrement = 0;                        # timer increment



# ####################################################################################
# set aerotowing parameters to global values, if not properly defined by plane 
#   setup-file
# store global values or plane-specific values to prepare for reset option
var globalsTowing = func {
  var glob_rope_length_m = 60;
  var glob_nominal_towforce_lbs = 500;
  var glob_breaking_towforce_lbs = 9999;
  var glob_rope_x1 = 0.7;
  var glob_rope_characteristics = 2;
  
  # set rope length X2, if not defined from "plane"-set.xml 
  if ( getprop("sim/glider/towing/conf/rope_length_m") == nil ) {
    setprop("sim/glider/towing/conf/rope_initial_length_m", glob_rope_length_m);
    setprop("sim/glider/towing/glob/rope_initial_length_m", glob_rope_length_m);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/rope_length_m", 
            getprop("sim/glider/towing/conf/rope_length_m"));
  }
  
  # set nominal force for pulling F2, if not defined from "plane"-set.xml
  if ( getprop("sim/glider/towing/conf/nominal_towforce_lbs") == nil ) {
    setprop("sim/glider/towing/conf/nominal_towforce_lbs", glob_nominal_towforce_lbs);
    setprop("sim/glider/towing/glob/nominal_towforce_lbs", glob_nominal_towforce_lbs);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/nominal_towforce_lbs", 
            getprop("sim/glider/towing/conf/nominal_towforce_lbs"));
  }
  
  # set breaking force for pulling Fmax, if not defined from "plane"-set.xml
  if ( getprop("sim/glider/towing/conf/breaking_towforce_lbs") == nil ) {
    setprop("sim/glider/towing/conf/breaking_towforce_lbs", glob_breaking_towforce_lbs);
    setprop("sim/glider/towing/glob/breaking_towforce_lbs", glob_breaking_towforce_lbs);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/breaking_towforce_lbs", 
            getprop("sim/glider/towing/conf/breaking_towforce_lbs"));
  }
  
  # set relative rope length X1, if not defined from "plane"-set.xml 
  if ( getprop("sim/glider/towing/conf/rope_x1") == nil ) {
    setprop("sim/glider/towing/conf/rope_x1", glob_rope_x1);
    setprop("sim/glider/towing/glob/rope_x1", glob_rope_x1);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/rope_x1", 
            getprop("sim/glider/towing/conf/rope_x1"));
  }
  
  # set relative rope characteristics, if not defined from "plane"-set.xml 
  if ( getprop("sim/glider/towing/conf/rope_characteristics") == nil ) {
    setprop("sim/glider/towing/conf/rope_characteristics", glob_rope_characteristics);
    setprop("sim/glider/towing/glob/rope_characteristics", glob_rope_characteristics);
  }
  else { # if defined, set global to plane specific for reset option
    setprop("sim/glider/towing/glob/rope_characteristics", 
            getprop("sim/glider/towing/conf/rope_characteristics"));
  }
  
} # End Function globalsTowing



# ####################################################################################
# reset aerotowing parameters to global values
var resetTowing = func {
  # set rope length to global
  setprop("sim/glider/towing/conf/rope_length_m", 
            getprop("sim/glider/towing/glob/rope_length_m"));
  
  # set nominal force for pulling to global
  setprop("sim/glider/towing/conf/nominal_towforce_lbs", 
            getprop("sim/glider/towing/glob/nominal_towforce_lbs"));
  
  # set breaking force for pulling to global
  setprop("sim/glider/towing/conf/breaking_towforce_lbs", 
            getprop("sim/glider/towing/glob/breaking_towforce_lbs"));
  
  # set rope length X1 to global
  setprop("sim/glider/towing/conf/rope_x1", 
            getprop("sim/glider/towing/glob/rope_x1"));
  
  
  # set rope characteristics to global
  setprop("sim/glider/towing/conf/rope_characteristics", 
            getprop("sim/glider/towing/glob/rope_characteristics"));
  
} # End Function resetTowing



# ####################################################################################
# restore position to location before towing dialog
# used by gui, when aborting selection of dragger
var restorePosition = func {
  # reset to temporarily stored initial position (before calling gui)
  setprop("position/latitude-deg", getprop("sim/glider/towing/list/init_lat_deg"));
  setprop("position/longitude-deg", getprop("sim/glider/towing/list/init_lon_deg"));
  setprop("position/altitude-ft", getprop("sim/glider/towing/list/init_alt_ft"));
  setprop("orientation/heading-deg", getprop("sim/glider/towing/list/init_head_deg"));
  setprop("orientation/pitch-deg", 0);
  setprop("orientation/roll-deg", 0);
} # End Function restorePosition



# ####################################################################################
# listCandidates
# used by gui, for setting up an selection list of possible candidates
var listCandidates = func {
  
  # first check for available multiplayer and ai-planes 
  # if ai-objects are available 
  #   store them in an array
  #   get the glider position
  #   for every ai-object
  #     calculate the distance to the glider
  #     if the distance is lower than max. tow length
  #       get id
  #       get callsign
  #       print details to the console
  
  # local variables
  var aiobjects = [];                            # keeps the ai-objects from the 
                                                 #   property tree
  var candidates_id = [];                        # keeps all found candidates
  var candidates_dst_m = [];                     # keeps the distance to the glider
  var candidates_callsign = [];                  # keeps the callsigns
  var candidates_type = [];                      # keeps the type of candidate
  var dragid = 0;                                # id of dragger
  var callsign = 0;                              # callsign of dragger
  var cur = geo.Coord.new();                     # current processed ai-object
                                                 # from the current aiobject
  var lat_deg = 0;                               #   latitude
  var lon_deg = 0;                               #   longitude
  var alt_m = 0;                                 #   altitude
  var glider = geo.Coord.new();                  # coordinates of glider
  var distance_m = 0;                            # distance to ai-plane
  var counter = 0;                               # temporary counter
  var listbasis = "/sim/glider/towing/list/";    # string keeping basis of drag 
                                                 #   candidates list
  
  
  glider = geo.aircraft_position(); 
  
  # first scan for multiplayers
  aiobjects = props.globals.getNode("ai/models").getChildren("multiplayer"); 
  
  print("found MP: ", size(aiobjects));
  
  if (size(aiobjects) > 0 ) {
    foreach (var aimember; aiobjects) { 
      lat_deg = aimember.getNode("position/latitude-deg").getValue(); 
      lon_deg = aimember.getNode("position/longitude-deg").getValue(); 
      alt_m = aimember.getNode("position/altitude-ft").getValue() * FT2M; 
      cur = geo.Coord.set_latlon( lat_deg, lon_deg, alt_m );
      distance_m = (glider.distance_to(cur)); 
      
      append( candidates_id, aimember.getNode("id").getValue() );
      append( candidates_callsign, aimember.getNode("callsign").getValue() );
      append( candidates_dst_m, distance_m );
      append( candidates_type, "MP" );
    }
  }
  
  # second scan for ai-planes
  aiobjects = props.globals.getNode("ai/models").getChildren("aircraft"); 
  
  print("found AI: ", size(aiobjects));
  
  if (size(aiobjects) > 0 ) {
    foreach (var aimember; aiobjects) { 
      lat_deg = aimember.getNode("position/latitude-deg").getValue(); 
      lon_deg = aimember.getNode("position/longitude-deg").getValue(); 
      alt_m = aimember.getNode("position/altitude-ft").getValue() * FT2M; 
      cur = geo.Coord.set_latlon( lat_deg, lon_deg, alt_m );
      distance_m = (glider.distance_to(cur)); 
      
      append( candidates_id, aimember.getNode("id").getValue() );
      append( candidates_callsign, aimember.getNode("callsign").getValue() );
      append( candidates_dst_m, distance_m );
      append( candidates_type, "AI" );
    }
  }
  
  
  # some kind of sorting, criteria is distance, 
  # but only if there are more than 1 candidate
  if (size(candidates_id) > 1) {
    # first push the closest candidate on the first position
    for (var index = 1; index < size(candidates_id); index += 1 ) {
      if ( candidates_dst_m[0] > candidates_dst_m[index] ) {
        var tmp_id = candidates_id[index];
        var tmp_cs = candidates_callsign[index];
        var tmp_dm = candidates_dst_m[index];
        var tmp_tp = candidates_type[index];
        candidates_id[index] = candidates_id[0];
        candidates_callsign[index] = candidates_callsign[0];
        candidates_dst_m[index] = candidates_dst_m[0];
        candidates_type[index] = candidates_type[0];
        candidates_id[0] = tmp_id;
        candidates_callsign[0] = tmp_cs;
        candidates_dst_m[0] = tmp_dm;
        candidates_type[0] = tmp_tp;
      }
    }
    # then sort all the remaining candidates, if there are more than 2
    if (size(candidates_id) > 2) {
      # do all other sorting
      for (var index = 2; index < size(candidates_id); index += 1) {
        # compare and change
        var bubble = index;
        while (( candidates_dst_m[bubble] < candidates_dst_m[bubble - 1] ) and (bubble >1)) {
          # exchange elements
          var tmp_id = candidates_id[bubble];
          var tmp_cs = candidates_callsign[bubble];
          var tmp_dm = candidates_dst_m[bubble];
          var tmp_tp = candidates_type[bubble];
          candidates_id[bubble] = candidates_id[bubble - 1];
          candidates_callsign[bubble] = candidates_callsign[bubble - 1];
          candidates_dst_m[bubble] = candidates_dst_m[bubble - 1];
          candidates_type[bubble] = candidates_type[bubble - 1];
          candidates_id[bubble - 1] = tmp_id;
          candidates_callsign[bubble - 1] = tmp_cs;
          candidates_dst_m[bubble - 1] = tmp_dm;
          candidates_type[bubble - 1] = tmp_tp;
          bubble = bubble - 1;
        }
      }
    }
  }
  
  # now, finally write the five closest candidates to the property tree
  # if there are less than five, fill up with empty objects
  for (var index = 0; index < 5; index += 1 ) {
    if (index >= size(candidates_id)) {
      var candidate_x_id_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/id";
      var candidate_x_cs_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/callsign";
      var candidate_x_dm_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/distance_m";
      var candidate_x_tp_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/type";
      var candidate_x_sl_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/selected";
      setprop(candidate_x_id_prop, -1);
      setprop(candidate_x_cs_prop, "undef");
      setprop(candidate_x_dm_prop, 99999);
      setprop(candidate_x_tp_prop, "XX");
      setprop(candidate_x_sl_prop, 0);
      # set color in dialog for aerotowing
      var guigroup = index + 1;
      var guicolor = "sim/gui/dialogs/dg101g/dragger/dialog/group[1]/group[" ~ guigroup ~ "]/text[";
        setprop(guicolor ~ "0]/color/green", 0.1 );
        setprop(guicolor ~ "0]/color/red", 0.1 );
        setprop(guicolor ~ "0]/color/blue", 0.1 );
        setprop(guicolor ~ "1]/color/green", 0.1 );
        setprop(guicolor ~ "1]/color/red", 0.1 );
        setprop(guicolor ~ "1]/color/blue", 0.1 );
        setprop(guicolor ~ "2]/color/green", 0.1 );
        setprop(guicolor ~ "2]/color/red", 0.1 );
        setprop(guicolor ~ "2]/color/blue", 0.1 );
        setprop(guicolor ~ "3]/color/green", 0.1 );
        setprop(guicolor ~ "3]/color/red", 0.1 );
        setprop(guicolor ~ "3]/color/blue", 0.1 );
    }
    else {
      var candidate_x_id_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/id";
      var candidate_x_cs_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/callsign";
      var candidate_x_dm_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/distance_m";
      var candidate_x_tp_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/type";
      var candidate_x_sl_prop = "sim/glider/towing/list/candidate[" ~ index ~ "]/selected";
      setprop(candidate_x_id_prop, candidates_id[index]);
      setprop(candidate_x_cs_prop, candidates_callsign[index]);
      setprop(candidate_x_dm_prop, candidates_dst_m[index]);
      setprop(candidate_x_tp_prop, candidates_type[index]);
      setprop(candidate_x_sl_prop, 0);
      # set color in dialog for aerotowing
      var guigroup = index + 1;
      var guicolor = "sim/gui/dialogs/dg101g/dragger/dialog/group[1]/group[" ~ guigroup ~ "]/text[";
      if ( candidates_dst_m[index] < 1000) {
        setprop(guicolor ~ "0]/color/green", 0.9 );
        setprop(guicolor ~ "0]/color/red", 0.1 );
        setprop(guicolor ~ "0]/color/blue", 0.1 );
        setprop(guicolor ~ "1]/color/green", 0.9 );
        setprop(guicolor ~ "1]/color/red", 0.1 );
        setprop(guicolor ~ "1]/color/blue", 0.1 );
        setprop(guicolor ~ "2]/color/green", 0.9 );
        setprop(guicolor ~ "2]/color/red", 0.1 );
        setprop(guicolor ~ "2]/color/blue", 0.1 );
        setprop(guicolor ~ "3]/color/green", 0.9 );
        setprop(guicolor ~ "3]/color/red", 0.1 );
        setprop(guicolor ~ "3]/color/blue", 0.1 );
      }
      elsif ( candidates_dst_m[index] < 3000.01 ) {
        setprop(guicolor ~ "0]/color/green", 0.9 );
        setprop(guicolor ~ "0]/color/red", 0.1 );
        setprop(guicolor ~ "0]/color/blue", 0.9 );
        setprop(guicolor ~ "1]/color/green", 0.9 );
        setprop(guicolor ~ "1]/color/red", 0.1 );
        setprop(guicolor ~ "1]/color/blue", 0.9 );
        setprop(guicolor ~ "2]/color/green", 0.9 );
        setprop(guicolor ~ "2]/color/red", 0.1 );
        setprop(guicolor ~ "2]/color/blue", 0.9 );
        setprop(guicolor ~ "3]/color/green", 0.9 );
        setprop(guicolor ~ "3]/color/red", 0.1 );
        setprop(guicolor ~ "3]/color/blue", 0.9 );
      }
      else {
        setprop(guicolor ~ "0]/color/green", 0.1 );
        setprop(guicolor ~ "0]/color/red", 0.9 );
        setprop(guicolor ~ "0]/color/blue", 0.1 );
        setprop(guicolor ~ "1]/color/green", 0.1 );
        setprop(guicolor ~ "1]/color/red", 0.9 );
        setprop(guicolor ~ "1]/color/blue", 0.1 );
        setprop(guicolor ~ "2]/color/green", 0.1 );
        setprop(guicolor ~ "2]/color/red", 0.9 );
        setprop(guicolor ~ "2]/color/blue", 0.1 );
        setprop(guicolor ~ "3]/color/green", 0.1 );
        setprop(guicolor ~ "3]/color/red", 0.9 );
        setprop(guicolor ~ "3]/color/blue", 0.1 );
      }
    }
  }
  # and write the initial position of the glider to the property tree for 
  # cancel possibility
  setprop("sim/glider/towing/list/init_lat_deg", 
           getprop("position/latitude-deg"));
  setprop("sim/glider/towing/list/init_lon_deg", 
           getprop("position/longitude-deg"));
  setprop("sim/glider/towing/list/init_alt_ft", 
           getprop("position/altitude-ft"));
  setprop("sim/glider/towing/list/init_head_deg", 
           getprop("orientation/heading-deg"));
  
} # End Function listCandidates



# ####################################################################################
# selectCandidates
# used by gui, for selection of dragger and putting the glider behind dragger
var selectCandidates = func (select) {
  var candidates = [];
  var aiobjects = [];
  var initpos_geo = geo.Coord.new();
  var dragpos_geo = geo.Coord.new();
  # place behind dragger with a distance, that the tow is nearly tautened
  var rope_length_m = getprop("/sim/glider/towing/conf/rope_length_m");
  var tauten_relative = getprop("/sim/glider/towing/conf/rope_x1");
  var install_distance_m = rope_length_m * (tauten_relative - 0.02);
  
  # first reset all candidate selections and then set selected
  candidates = props.globals.getNode("sim/glider/towing/list").getChildren("candidate");
  foreach (var camember; candidates) { 
    camember.getNode("selected").setValue(0); 
  }
  var candidate_x_sl_prop = "sim/glider/towing/list/candidate[" ~ select ~ "]/selected";
  var candidate_x_id_prop = "sim/glider/towing/list/candidate[" ~ select ~ "]/id";
  var candidate_x_tp_prop = "sim/glider/towing/list/candidate[" ~ select ~ "]/type";
  setprop(candidate_x_sl_prop, 1);
  
  # next set properties for dragid
  setprop("sim/glider/towing/dragid", getprop(candidate_x_id_prop));
  
  # and finally place the glider a few meters behind chosen dragger
  aiobjects = props.globals.getNode("ai/models").getChildren(); 
  foreach (var aimember; aiobjects) { 
    if ( (var c = aimember.getNode("id") ) != nil ) { 
      var testprop = c.getValue();
      if ( testprop == getprop(candidate_x_id_prop)) {
        # get coordinates
        drlat = aimember.getNode("position/latitude-deg").getValue(); 
        drlon = aimember.getNode("position/longitude-deg").getValue(); 
        dralt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M; 
        drhed = aimember.getNode("orientation/true-heading-deg").getValue();
      }
    }
  }
  dragpos_geo.set_latlon(drlat, drlon, dralt);
  initpos_geo.set_latlon(drlat, drlon, dralt);
  if (drhed > 180) {
    initpos_geo.apply_course_distance( (drhed - 180), install_distance_m );
  }
  else {
    initpos_geo.apply_course_distance( (drhed + 180), install_distance_m );
  }
  var initelevation_m = geo.elevation( initpos_geo.lat(), initpos_geo.lon() ) + 0.5;
  setprop("position/latitude-deg", initpos_geo.lat());
  setprop("position/longitude-deg", initpos_geo.lon());
  setprop("position/altitude-ft", initelevation_m * M2FT);
  setprop("orientation/heading-deg", drhed);
  setprop("orientation/roll-deg", 0);
  
} # End Function selectCandidates



# ####################################################################################
# clearredoutCandidates
# used by gui to clear red-out
# sometimes it happens, that the glider drops off a dragger, if a huge dragger has
# been selected. in that case you can get a red-out. and this function allows to 
# clear this.
var clearredoutCandidates = func {
  # remove redout blackout caused by selectCandidates()
  setprop("sim/rendering/redout/enabled", "false");
  setprop("sim/rendering/redout/alpha",0);
  
} # End Function clearredoutCandidates



# ####################################################################################
# removeCandidates
# used by gui to remove list of candidates, after selecting or aborting
var removeCandidates = func {
  # and finally remove the list of candidates
  props.globals.getNode("sim/glider/towing/list").remove();
  
} # End Function removeCandidates



# ####################################################################################
# findDragger
# used by key 
# used by gui, when dealing with drag roboter
# the first found plane, that is close enough and has callsign "dragger" will be used
var findDragger = func {
  
  # local variables
  var aiobjects = [];                     # keeps the ai-planes from the property tree
  var dragid = 0;                         # id of dragger
  var callsign = 0;                       # callsign of dragger
  var cur = geo.Coord.new();              # current processed ai-plane
  var lat_deg = 0;                        # latitude of current processed aiobject
  var lon_deg = 0;                        # longitude of current processed aiobject
  var alt_m = 0;                          # altitude of current processed aiobject
  var glider = geo.Coord.new();           # coordinates of glider
  var distance_m = 0;                     # distance to ai-plane
  
  
  var towlength_m = getprop("sim/glider/towing/conf/rope_length_m");
  
  
  aiobjects = props.globals.getNode("ai/models").getChildren(); 
  glider = geo.aircraft_position(); 
  
  foreach (var aimember; aiobjects) { 
    if ( (var c = aimember.getNode("callsign") ) != nil ) { 
      callsign = c.getValue();
      dragid = aimember.getNode("id").getValue();
      if ( callsign == "dragger" ) {
        lat_deg = aimember.getNode("position/latitude-deg").getValue(); 
        lon_deg = aimember.getNode("position/longitude-deg").getValue(); 
        alt_m = aimember.getNode("position/altitude-ft").getValue() * FT2M; 
        
        cur = geo.Coord.set_latlon( lat_deg, lon_deg, alt_m ); 
        distance_m = (glider.distance_to(cur)); 
        
        if ( distance_m < towlength_m ) { 
          atc_msg("dragger with id %s nearby in %s m", dragid, distance_m);
          setprop("sim/glider/towing/dragid", dragid); 
          break; 
        }
        else {
          atc_msg("dragger with id %s too far at %s m", dragid, distance_m);
        }
      }
    }
    else {
      atc_msg("no dragger found");
    }
  }
  
} # End Function findDragger



# ####################################################################################
# get the next free id of models/model members
# required for animation of towing rope
# should be shifted to a generic module as same function exists in dragrobot.nas
var getFreeModelID = func {
  
  #local variables
  var modelid = 0;                                 # for the next unsused id
  var modelobjects = {};                           # vector to keep all model objects
  
  modelobjects = props.globals.getNode("models", 1).getChildren(); # get model objects
  foreach ( var member; modelobjects ) { 
    # get data from member
    if ( (var c = member.getNode("id")) != nil) {
      var id = c.getValue();
      if ( modelid <= id ) {
        modelid = id +1;
      } 
    }
  }
  return(modelid);
}



# ####################################################################################
# create the towing rope in the model property tree
var createTowingRope = func {
  # place towing rope at nose of glider and scale it to distance to dragger
  var rope_length_m = getprop("sim/glider/towing/conf/rope_length_m");
  var rope_distance_m = rope_length_m * (getprop("sim/glider/towing/conf/rope_x1") - 0.02);
  var install_distance_m = 0.05; # 0.05m in front of ref-point of glider
  
  # local variables
  var ac_pos = geo.aircraft_position();                   # get position of aircraft
  var ac_hd  = getprop("orientation/heading-deg");        # get heading of aircraft
  var ac_pt  = getprop("orientation/pitch-deg");          # get pitch of aircraft
  var ac_alt_m = getprop("position/altitude-ft") * FT2M;  # get altitude of aircraft
  
  
  var install_alt_m = -0.15; # 0.15m below of ref-point of glider
  
  var rope_pos    = ac_pos.apply_course_distance( ac_hd , install_distance_m );   
                                                          # initial rope position, 
                                                            # at nose of glider
  rope_pos.set_alt(ac_pos.alt() + install_alt_m);               # correct hight by pitch
  
  # get the next free ai id and model id
  var freeModelid = getFreeModelID();
  
  var towrope_ai  = props.globals.getNode("ai/models/towrope", 1);
  var towrope_mod = props.globals.getNode("models", 1);
  var towrope_sim = props.globals.getNode("sim/glider/towrope/data", 1);
  var towrope_flg = props.globals.getNode("sim/glider/towrope/flags", 1);
  
  towrope_sim.getNode("id_AI", 1).setIntValue(9998);
  towrope_sim.getNode("id_model", 1).setIntValue(freeModelid);
  towrope_sim.getNode("rope_distance_m", 1).setValue(rope_distance_m);
  towrope_sim.getNode("xstretch_rel", 1).setValue(rope_distance_m / rope_length_m);
  towrope_sim.getNode("rope_heading_deg", 1).setValue(ac_hd);
  towrope_sim.getNode("rope_pitch_deg", 1).setValue(0.0);
  towrope_sim.getNode("hook_x_m", 1).setValue(install_distance_m);
  towrope_sim.getNode("hook_z_m", 1).setValue(install_alt_m);
  
  towrope_flg.getNode("exist", 1).setIntValue(1);
  
  towrope_ai.getNode("id", 1).setIntValue(9998);
  towrope_ai.getNode("callsign", 1).setValue("towrope");
  towrope_ai.getNode("valid", 1).setBoolValue(1);
  towrope_ai.getNode("position/latitude-deg", 1).setValue(rope_pos.lat());
  towrope_ai.getNode("position/longitude-deg", 1).setValue(rope_pos.lon());
  towrope_ai.getNode("position/altitude-ft", 1).setValue(rope_pos.alt() * M2FT);
  towrope_ai.getNode("orientation/true-heading-deg", 1).setValue(ac_hd);
  towrope_ai.getNode("orientation/pitch-deg", 1).setValue(0);
  towrope_ai.getNode("orientation/roll-deg", 1).setValue(0);
  
  towrope_mod.model = towrope_mod.getChild("model", freeModelid, 1);
  towrope_mod.model.getNode("path", 1).setValue("Aircraft/DG-101G/Models/Ropes/towingrope.xml");
  towrope_mod.model.getNode("longitude-deg-prop", 1).setValue(
        "ai/models/towrope/position/longitude-deg");
  towrope_mod.model.getNode("latitude-deg-prop", 1).setValue(
        "ai/models/towrope/position/latitude-deg");
  towrope_mod.model.getNode("elevation-ft-prop", 1).setValue(
        "ai/models/towrope/position/altitude-ft");
  towrope_mod.model.getNode("heading-deg-prop", 1).setValue(
        "ai/models/towrope/orientation/true-heading-deg");
  towrope_mod.model.getNode("roll-deg-prop", 1).setValue(
        "ai/models/towrope/orientation/roll-deg");
  towrope_mod.model.getNode("pitch-deg-prop", 1).setValue(
        "ai/models/towrope/orientation/pitch-deg");
  towrope_mod.model.getNode("load", 1).remove();
  
}



# ####################################################################################
# update the towing rope in the model property tree
var updateTowingRope = func {
# functions from geo.nas
#     .course_to(<coord>)         ... returns course to another geo.Coord instance (degree)
#     .distance_to(<coord>)       ... returns distance in m along Earth curvature, ignoring altitudes
#                                     useful for map distance
#     .direct_distance_to(<coord>)      ...   distance in m direct, considers altitude,
#                                             but cuts through Earth surface
  
  # local variables
  var glider = geo.Coord.new();        # keeps the glider position
  var glider_head_deg = 0;             # keeps heading of glider
  var dragger = geo.Coord.new();       # keeps the dragger position
  var drlat = 0;                       # temporary latitude of dragger
  var drlon = 0;                       # temporary longitude of dragger
  var dralt = 0;                       # temporary altitude of dragger
  var distance = 0;                    # distance glider to dragger
  var dragheadto = 0;                  # heading to dragger
  var dragpitchto = 0;                 # pitch to dragger
  var aiobjects = [];                  # keeps the ai-planes from the property tree
  var dragid = 0;                      # id of dragger
  var install_distance_m = 0.15;
  var install_alt_m = -0.15;
  
  glider = geo.aircraft_position();
  glider_head_deg = getprop("orientation/heading-deg");
  var rope_pos    = glider.apply_course_distance( glider_head_deg , install_distance_m );   
  rope_pos.set_alt(glider.alt() + install_alt_m); 
  
  dragid = getprop("sim/glider/towing/dragid");        # id of former found dragger
  
  aiobjects = props.globals.getNode("ai/models").getChildren(); 
  foreach (var aimember; aiobjects) { 
    if ( (var c = aimember.getNode("id") ) != nil ) { 
      var testprop = c.getValue();
      if ( testprop == dragid ) {
        # get coordinates
        drlat = aimember.getNode("position/latitude-deg").getValue(); 
        drlon = aimember.getNode("position/longitude-deg").getValue(); 
        dralt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M; 
      }
    }
  }
  
  dragger = geo.Coord.set_latlon( drlat, drlon, dralt ); # position of current plane
  
  distance = (glider.direct_distance_to(dragger));      # distance to plane in meter
  dragheadto = (glider.course_to(dragger));
  var height = glider.alt() - dragger.alt();
#  print(" hoehe: ", height);
  if ( glider.alt() > dragger.alt() ) {
    dragpitchto = -math.asin((glider.alt()-dragger.alt())/distance) / 0.01745;
  }
  else {
    dragpitchto =  math.asin((glider.alt()-dragger.alt())/distance) / 0.01745;
  }
#  print("  pitch: ", dragpitchto);
  
  # update position of rope
  setprop("ai/models/towrope/position/latitude-deg", rope_pos.lat());
  setprop("ai/models/towrope/position/longitude-deg", rope_pos.lon());
  setprop("ai/models/towrope/position/altitude-ft", rope_pos.alt() * M2FT);
  
  # update length of rope
  setprop("sim/glider/towrope/data/xstretch_rel", distance);
  
  # update pitch and heading of rope
  setprop("sim/glider/towrope/data/rope_heading_deg", dragheadto);
  setprop("sim/glider/towrope/data/rope_pitch_deg", 0);
  setprop("ai/models/towrope/orientation/true-heading-deg", dragheadto);
  setprop("ai/models/towrope/orientation/pitch-deg", dragpitchto);

}



# ####################################################################################
# dummy function to delete the towing rope
var removeTowingRope = func {
  
  # look for allready existing ai object with callsign "towrope"
  # check for the towing rope is still existent
  # if yes, 
  #   remove the towing rope from the property tree ai/models
  #   remove the towing rope from the property tree models/
  #   remove the towing rope working properties
  # if no, 
  #   do nothing
  
  # local variables
  var modelsNode = {};
  
  if ( getprop("/sim/glider/towrope/flags/exist") == 1 ) {   # does the towing rope exist?
    # remove 3d model from scenery
    # identification is /models/model[x] with x=id_model
    var id_model = getprop("sim/glider/towrope/data/id_model");
    modelsNode = "models/model[" ~ id_model ~ "]";
    props.globals.getNode(modelsNode).remove();
    props.globals.getNode("ai/models/towrope").remove();
    props.globals.getNode("sim/glider/towrope/data").remove();
    atc_msg("towing rope removed");
    setprop("/sim/glider/towrope/flags/exist", 0);
  }
  else {                                                     # do nothing
    atc_msg("towing rope does not exist");
  }
  
}




# ####################################################################################
# hookDragger
# used by key
# used by gui
var hookDragger = func {
  
  # if dragid > 0
  #  set property /fdm/jsbsim/fcs/dragger-cmd-norm
  #  level plane
  
  if ( getprop("sim/glider/towing/dragid") != nil ) { 
    createTowingRope();                                           # create rope model
    setprop("fdm/jsbsim/fcs/dragger-cmd-norm", 1);                # closes the hook
    setprop("sim/glider/towing/hooked", 1); 
    atc_msg("hook closed"); 
    setprop("orientation/roll-deg", 0); 
    atc_msg("glider leveled"); 
  }
  else { 
    atc_msg("no dragger nearby"); 
  }
  
} # End Function hookDragger



# ####################################################################################
# releaseDragger
# used by key
var releaseDragger = func {
  
  # first check for dragger is pulling
  # if yes
  #   opens the hook
  #   sets the forces to zero
  #   print a message
  # if no
  #   print a message
  # exit
  
  if ( getprop ("sim/glider/towing/hooked") ) {
    removeTowingRope();                                         # remove towing model
    setprop  ("fdm/jsbsim/fcs/dragger-cmd-norm",0);                 # opens the hook
    setprop("fdm/jsbsim/external_reactions/dragx/magnitude", 0);    # set the forces to zero
    setprop("fdm/jsbsim/external_reactions/dragy/magnitude", 0);    # set the forces to zero
    setprop("fdm/jsbsim/external_reactions/dragz/magnitude", 0);    # set the forces to zero
    setprop("sim/glider/towing/hooked",0);                         # dragger is not pulling
    atc_msg("Hook opened, tow released");
  }
  else {                                                  # failure: winch not working
    atc_msg("Hook already opened");
  }
  
} # End Function releaseDragger



# ####################################################################################
# let the dragger pull the plane up into the sky
var runDragger = func {
  
  # strategy:
  # get current positions and orientations of glider and dragger
  # calculate the forces with respect of distance and spring-coefficient of tow
  # calculate force distribution in main axes
  # do this as long as the tow is engaged at the glider
  
  # local constants describing tow properties
  var tf0 = 0;                         # coresponding force
  # local variables
  var forcex = 0;                      # the force in x-direction, body ref system
  var forcey = 0;                      # the force in y-direction, body ref system
  var forcez = 0;                      # the force in z-direction, body ref system
  var glider = geo.Coord.new();        # keeps the glider position
  var gliderhead = 0;                  # keeps the glider heading
  var gliderpitch = 0;                 # keeps the glider pitch
  var gliderroll = 0;                  # keeps the glider roll
  var dragger = geo.Coord.new();       # keeps the dragger position
  var drlat = 0;                       # temporary latitude of dragger
  var drlon = 0;                       # temporary longitude of dragger
  var dralt = 0;                       # temporary altitude of dragger
  var dragheadto = 0;                  # heading to dragger
  var aiobjects = [];                     # keeps the ai-planes from the property tree
  var distance = 0;                    # distance glider to dragger
  var distancepr = 0;                  # projected distance glider to dragger
  var reldistance = 0;                 # relative distance glider to dragger
  var dragid = 0;                      # id of dragger
  var planeid = 0;                     # id of current processed plane
  
  var nominaltowforce = getprop("sim/glider/towing/conf/nominal_towforce_lbs");
  var breakingtowforce = getprop("sim/glider/towing/conf/breaking_towforce_lbs");
  var towlength_m = getprop("sim/glider/towing/conf/rope_length_m");
  var tl0 = getprop("sim/glider/towing/conf/rope_x1");
  var ropetype = getprop("sim/glider/towing/conf/rope_characteristics");
  
  # do all the stuff
  if ( getprop("sim/glider/towing/hooked") == 1 ) {            # is a dragger engaged
    
    glider = geo.aircraft_position();                        # current glider position
    gliderpitch = getprop("orientation/pitch-deg");
    gliderroll = getprop("orientation/roll-deg");
    gliderhead = getprop("orientation/heading-deg");
    
    dragid = getprop("sim/glider/towing/dragid");        # id of former found dragger
    
    aiobjects = props.globals.getNode("ai/models").getChildren(); 
    foreach (var aimember; aiobjects) { 
      if ( (var c = aimember.getNode("id") ) != nil ) { 
        var testprop = c.getValue();
        if ( testprop == dragid ) {
          # get coordinates
          drlat = aimember.getNode("position/latitude-deg").getValue(); 
          drlon = aimember.getNode("position/longitude-deg").getValue(); 
          dralt = (aimember.getNode("position/altitude-ft").getValue()) * FT2M; 
        }
      }
    }
    
    dragger = geo.Coord.set_latlon( drlat, drlon, dralt ); # position of current plane
    
    distance = (glider.direct_distance_to(dragger));      # distance to plane in meter
    distancepr = (glider.distance_to(dragger));
    dragheadto = (glider.course_to(dragger));
    reldistance = distance / towlength_m;
    
    if ( reldistance < tl0 ) {
      forcetow = tf0;
    }
    else {
      forcetow = math.pow((reldistance - tl0),ropetype) 
                 / math.pow((1-tl0),ropetype) * nominaltowforce;
    }
    
    if ( forcetow < breakingtowforce ) {
      
      # correct a failure, if the projected length is larger than direct length
      if (distancepr > distance) { distancepr = distance;} 
      
      
      var alpha = math.acos( (distancepr / distance) );
      var beta = ( dragheadto - gliderhead ) * 0.01745;
      var gamma = gliderpitch * 0.01745;
      var delta = gliderroll * 0.01745;
      
      
      var sina = math.sin(alpha);
      var cosa = math.cos(alpha);
      var sinb = math.sin(beta);
      var cosb = math.cos(beta);
      var sing = math.sin(gamma);
      var cosg = math.cos(gamma);
      var sind = math.sin(delta);
      var cosd = math.cos(delta);
      
      # global forces: alpha beta
      var fglobalx = forcetow * cosa * cosb;
      var fglobaly = forcetow * cosa * sinb;
      var fglobalz = forcetow * sina;
      if ( dragger.alt() > glider.alt()) {
        fglobalz = -fglobalz;
      }
      
      
      # local forces by pitch: gamma
      var flpitchx = fglobalx * cosg - fglobalz * sing;
      var flpitchy = fglobaly;
      var flpitchz = fglobalx * sing + fglobalz * cosg;
      
      
      # local forces by roll: delta
      var flrollx  = flpitchx;
      var flrolly  = flpitchy * cosd + flpitchz * sind;
      var flrollz  = flpitchy * sind + flpitchz * cosd;
      
      # asigning to LOCAL coord of plane
      var forcex = flrollx;
      var forcey = flrolly;
      var forcez = flrollz;
      
      # apply forces to clutch
      setprop("fdm/jsbsim/external_reactions/dragx/magnitude",  forcex);
      setprop("fdm/jsbsim/external_reactions/dragy/magnitude",  forcey);
      setprop("fdm/jsbsim/external_reactions/dragz/magnitude",  forcez);
      
      # keep the glider leveled up to a certain speed
      # thanks to the helper, who holds the left wing tip
      var spd_ground_mps = getprop("velocities/groundspeed-kt") * KT2MPS;
      if (spd_ground_mps < 5 ) {
        setprop("orientation/roll-deg", 0);
      }
    }
    else {
      releaseDragger();
      atc_msg("TOWFORCE EXCEEDED");
    }
      
    # update animated towing rope
    updateTowingRope();
    
    settimer(runDragger, towing_timeincrement);
    
  }
  
} # End Function runDragger



# ####################################################################################
var dragging = setlistener("sim/glider/towing/hooked", runDragger); 
var initialize_aerotowing = setlistener("sim/signals/fdm-initialized", globalsTowing);
