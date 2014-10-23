# ####################################################################################
# ####################################################################################
# Nasal script to manage thermals for the kider
#
# ####################################################################################
# Author: Klaus Kerner
# Version: 2011-10-31
#
# ####################################################################################
# Concepts:
# 1. check, whether the "thermal-demo" scenario (or other AI-thermals) is loaded
# 2. search for thermals out of area
# 3. distribute these thermals in area of interest
# 4. be happy and fly

# existing proterties, that are used to handle the thermals

# thermals from thermal_demo
# /ai/models/thermal[0]        upwind
# /ai/models/thermal[1]        upwind
# /ai/models/thermal[2]        upwind
# /ai/models/thermal[3]        upwind
# /ai/models/thermal[4]        upwind
# /ai/models/thermal[5]        upwind
# /ai/models/thermal[6]        upwind
# /ai/models/thermal[7]        upwind
# /ai/models/thermal[8]        upwind
# /ai/models/thermal[9]        upwind
# /ai/models/thermal[10]       upwind
# /ai/models/thermal[11]       downwind
# /ai/models/thermal[12]       downwind
# /ai/models/thermal[13]       downwind
# /ai/models/thermal[14]       downwind
# /ai/models/thermal[15]       downwind
# /ai/models/thermal[16]       downwind
#
# location of a thermal
#  position/latitude-deg       latitude of center
#  position/longitude-deg      longitude of center
#  position/altitude-ft        height of thermal above sealevel

# ####################################################################################
# ####################################################################################
# update thermals 
# search for thermals out of a certain area around the current position of the plane
# place these thermals in a certain area around the current position of the plane 


var thermals = [];                   # vector to keep all thermals
var border0 = 2000;                  # ring for placing the first thermal
var border1 = 5000;                  # inner border for placing all remaining thermals
var border2 = 15000;                 # outer border for placing all remaining thermals


var updateThermals = func {
  
  print("Function: updateThermals");
  
  
  var index = 0;                  # counter for individual thermal
  var thcur = geo.Coord.new();    # variable to keep current thermal
  var lat = 0;                    # variable to store latitude of current thermal
  var lon = 0;                    # variable to store longitude of current thermal
  var alt = 0;                    # variable to store height of current thermal
  var distance = 0;               # variable to store distance to current thermal
  var heading = 0;                # variable to store heading to current thermal
  var outofarea = 0;              # variable to count thermals out of local area
  var countsec1 = 0;              # variable to count thermals in section 1
  var countsec2 = 0;              # variable to count thermals in section 2
  var countsec3 = 0;              # variable to count thermals in section 3
  var countsec4 = 0;              # variable to count thermals in section 4
  var countsec5 = 0;              # variable to count thermals in section 5
  var countsec6 = 0;              # variable to count thermals in section 6
  var distnew = 0;                # variable to store new distance for current thermal
  var headnew = 0;                # variable to store new heading for current thermal
  var thnew = geo.Coord.new();    # variable to keep new thermal
  var distance_new = 0;           # variable to store distanc of new thermal
  var heading_new = 0;            # variable to store heading of new thermal
  var ac = geo.Coord.new();       # variable to store aircraft position
  
  
  ac = geo.aircraft_position();   # gets aircraft position
  
  # available thermals?
  if ( getprop("ai/models/thermal[0]/position/latitude-deg") == nil ) { 
    atc_msg(" no thermals available"); 
  }
  else {                          # mangle available thermals
    # store thermals
    thermals = props.globals.getNode("ai/models").getChildren("thermal");  
    
    foreach (var th; thermals) {         # go through the array and get for every one:
      lat = th.getNode("position/latitude-deg").getValue();    # latitude
      lon = th.getNode("position/longitude-deg").getValue();   # longitude
      alt = th.getNode("position/altitude-ft").getValue();     # height
      
      ac = geo.aircraft_position();             # current aircraft position
      thcur = geo.Coord.set_latlon( lat, lon ); # position of current thermal
      distance = (ac.distance_to(thcur));       # distance to thermal in meter
      heading = (ac.course_to(thcur));          # heading to thermal
      
      if ( distance > border2) {                # check for thermals out of area
        outofarea = outofarea + 1;              # increment counter for these thermals
      }
      else {                                    # with thermals inside the border 
        if ( heading < 60 ) {                   # check for thermals in sector 1
          countsec1 = countsec1 + 1;            # increase counter for sector 1
        }
        else { 
          if ( heading < 120 ) {                # check for thermals in sector 2
            countsec2 = countsec2 + 1;          # increase counter for sector 2
          }
          else { 
            if ( heading < 180 ) {              # and so on
              countsec3 = countsec3 + 1; 
            }
            else { 
              if ( heading < 240 ) { 
                countsec4 = countsec4 + 1; 
              }
              else { 
                if ( heading < 320 ) {
                  countsec5 = countsec5 + 1;
                }
                else {
                  countsec6 = countsec6 + 1;
                }
              }
            }
          }
        }
      }
      index = index + 1;
    }
    
    foreach (var th; thermals) {                          # go again through the array
      lat = th.getNode("position/latitude-deg").getValue(); 
      lon = th.getNode("position/longitude-deg").getValue(); 
      alt = th.getNode("position/altitude-ft").getValue(); 
      
      
      ac = geo.aircraft_position();               # current aircraft position
      thcur = geo.Coord.set_latlon( lat, lon );   # position of current thermal
      distance = (ac.distance_to(thcur));         # distance to thermal in meter
      heading = (ac.course_to(thcur));            # heading to thermal
      
      
      if ( distance > border2) {          # check for thermal out of area
        
        if ( outofarea == index ) {       # current thermal on ring 1, 
          distnew = border0;              # distance for first thermal on inner ring
          outofarea = outofarea - 1;      # decrement counter for thermals out of area
        }
        else {                            # distance for all other thermals
          distnew = border1 + (border2 - border1) * rand(); 
        }
        
        headnew = 60 * rand();            # sets heading for current thermal
        
        if ( countsec1 < 3 ) {            # checks for not enough thermals in sector 1
          headnew = headnew + 0;          # adjusts heading
          countsec1 = countsec1 + 1;      # increment sector 1 counter for thermals
        }
        else {
          if ( countsec2 < 3 ) {          # checks for not enough thermals in sector 2
            headnew = headnew + 60;       # adjusts heading
            countsec2 = countsec2 + 1;    # increment sector 1 counter for thermals
          }
          else {
            if (countsec3 < 3 ) {       # and so on
              headnew = headnew + 120;
              countsec3 = countsec3 + 1; 
            }
            else {
              if ( countsec4 < 3 ) {
                headnew = headnew + 180;
                countsec4 = countsec4 + 1; 
              }
              else {
                if ( countsec5 < 3 ) { 
                  headnew = headnew + 240;
                  countsec5 = countsec5 + 1; 
                }
                else {
                  headnew = headnew + 300;
                  countsec6 = countsec6 + 1; 
                }
              }
            }
          }
        }
        
        thnew = ac.apply_course_distance( headnew , distnew ); # new thermal position
        
                                                        # assigns to current thermal
        th.getNode("position/latitude-deg").setValue(thnew.lat());    # latitude
        th.getNode("position/longitude-deg").setValue(thnew.lon());   # longitude
        
        ac = geo.aircraft_position();                   # re-assign aircraft position
        distance_new = (ac.distance_to(thnew));         # distance to thermal in meter
        heading_new = (ac.course_to(thnew));            # heading to thermal
      }
      
    }
    atc_msg("Thermals arranged around plane");
  }
} # End Function updateThermals
