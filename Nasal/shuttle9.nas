# ====== Type 9 Shuttlecraft  version 6.32 for FlightGear 1.0 (PLIB and OSG) =====

# Add second popupTip to avoid being overwritten by primary joystick messages ===
var tipArg2 = props.Node.new({ "dialog-name" : "PopTip2" });
var currTimer2 = 0;
var popupTip2 = func {
	var delay2 = if(size(arg) > 1) {arg[1]} else {1.5};
	var tmpl2 = { name : "PopTip2", modal : 0, layout : "hbox",
					y: gui.screenHProp.getValue() - 110,
					text : { label : arg[0], padding : 6 } };

	fgcommand("dialog-close", tipArg2);
	fgcommand("dialog-new", props.Node.new(tmpl2));
	fgcommand("dialog-show", tipArg2);

	currTimer2 = currTimer2 + 1.5;
	var thisTimer2 = currTimer2;

		# Final argument is a flag to use "real" time, not simulated time
	settimer(func { if(currTimer2 == thisTimer2) { fgcommand("dialog-close", tipArg2); } }, 1.5, 1);
}

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

#==========================================================================
#             === define global nodes and constants ===

# beacons -----------------------------------------------------------
var beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
aircraft.light.new("sim/model/shuttle9/lighting/beacon1", [0.2, 1.5], beacon_switch);

# nav lights --------------------------------------------------------
var nav_lights_state = props.globals.getNode("sim/model/shuttle9/lighting/nav-lights-state", 1);
var nav_light_switch = props.globals.getNode("sim/model/shuttle9/lighting/nav-light-switch", 1);

# engines glow and main systems -------------------------------------
	# engine refers to impulse engines
	# /sim/model/shuttle9/lighting/engine-glow is a combination of engine sounds
	# anti-grav can provide hover capability (exclusively under 100 kts)
	# nacelles propulsion are powered by warp drive
	# stage 1 covers all forward flight modes up to 3900 kts.
	# stage 2 "increases plasma flow" so that orbital velocity can be attained

# movement and position ---------------------------------------------
var airspeed_kt_Node = props.globals.getNode("velocities/airspeed-kt", 1);
var abs_airspeed_Node = props.globals.getNode("velocities/abs-airspeed-kt", 1);

# maximum speed for ufo model at 100% throttle ----------------------
var maxspeed = props.globals.getNode("engines/engine/speed-max-mps", 1);
var speed_mps = [1, 20, 50, 100, 200, 500, 1000, 2000, 5000, 11177, 20000, 50000];
var limit = [1, 5, 6, 7, 2, 5, 6, 11];
var current = props.globals.getNode("engines/engine/speed-max-powerlevel", 1);

# VTOL anti-grav ----------------------------------------------------
# ---  expect joystick hat to provide best VTOL control ----
var joystick_elevator = props.globals.getNode("input/joysticks/js/axis[1]/binding/setting", 1);

# ground detection and adjustment -----------------------------------
var altitude_ft_Node = props.globals.getNode("position/altitude-ft", 1);
var ground_elevation_ft = props.globals.getNode("position/ground-elev-ft", 1);
var pitch_deg = props.globals.getNode("orientation/pitch-deg", 1);
var roll_deg = props.globals.getNode("orientation/roll-deg", 1);
var roll_control = props.globals.getNode("controls/flight/aileron", 1);
var pitch_control = props.globals.getNode("controls/flight/elevator", 1);

# Starfleet registration insignia ===================================
var active_insignia_button = [3, 1];

# config file entries ===============================================
aircraft.data.add("sim/model/shuttle9/shadow");

#==========================================================================
#    === define nasal non-local variables at startup ===
# -------- damage --------
var lose_altitude = 0;   # drift or sink when damaged or power shuts down
# ------ nav lights ------
var sun_angle = 0;  # down to 0 at high noon, 2 at midnight, depending on latitude
var visibility = 16000;                # 16Km
# -------- engines -------
var power_switch = 1;   # no request in-between. power goes direct to state.
var impulse_request = 1;
var impulse_level = 1;
var warp1_request = 1;
var warp1_level = 1;
var warp2_request = 1;
var warp2_level = 1;
var antigrav_request = 0;
var impulse_state = 0;  # destination level for impulse_level
var impulse_drift = 0;
var warp_state = 0;     # state = destination level
var warp_drift = 0;
# ------- movement -------
airspeed_kt_Node.setValue(0);
abs_airspeed_Node.setValue(0);
var contact_altitude = 0;   # the altitude at which the model touches ground
var pitch_d = 0;
var airspeed = 0;
var asas = 0;
var engines_lvl = 0;
var hover_add = 0;              # increase in altitude to keep nacelles and nose from touching ground
var hover_target_altitude = 0;  # ground_elevation + hover_ft (does not include hover_add)
var h_contact_target_alt = 0;   # adjusted for contact altitude
var skid_last_value = 0;
# --- ground detection ---
var init_agl = 5;     # some airports reported elevation change after movement begins
# ----- maximum speed ----
maxspeed.setValue(500);
current.setValue(5);  # needed for engine-digital panel
var cpl = 5;          # current power level
var current_to = 5;   # distinguishes between change_maximum types. Current or To
var max_drift = 0;    # smoothen drift between maxspeed power levels
var max_lose = 0;     # loss of momentum after shutdown of engines
var max_from = 5;
var max_to = 5;
# -------- sounds --------
var sound_level = 0;
var sound_state = 0;
# -------- dialog --------
var active_nav_button = [3, 3, 1];
var config_dialog = nil;

var reinit_shuttle9 = func {   # make it possible to reset the above variables
	lose_altitude = 0;
	contact_altitude = 0;
	power_switch = 1;
	impulse_request = 1;
	impulse_level = 1;
	warp1_request = 1;
	warp1_level = 1;
	warp2_request = 1;
	warp2_level = 1;
	antigrav_request = 0;
	impulse_state = 0;
	impulse_drift = 0;
	warp_state = 0;
	warp_drift = 0;
	pitch_d = 0;
	airspeed = 0;
	asas = 0;
	engines_lvl = 0;
	hover_add = 0;
	hover_target_altitude = 0;
	h_contact_target_alt = 0;
	skid_last_value = 0;
	init_agl = 5;
	cpl = 5;
	current_to = 5;
	max_drift = 0;
	max_lose = 0;
	max_from = 5;
	max_to = 5;
	sound_state = 0;
	active_nav_button = [3, 3, 1];
	active_insignia_button = [3, 1];
	name = "shuttle9-config";
	if (config_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		config_dialog = nil;
	}
}

 setlistener("sim/signals/reinit", func {
	reinit_shuttle9();
 });

# systems -----------------------------------------------------------

setlistener("sim/model/shuttle9/systems/power-switch", func {
	power_switch = getprop("sim/model/shuttle9/systems/power-switch");
});

setlistener("sim/model/shuttle9/systems/impulse-request", func {
	impulse_request = getprop("sim/model/shuttle9/systems/impulse-request");
});

setlistener("sim/model/shuttle9/systems/impulse-level", func {
	impulse_level = getprop("sim/model/shuttle9/systems/impulse-level");
});

setlistener("sim/model/shuttle9/lighting/engine-glow", func {
	engines_lvl = getprop("sim/model/shuttle9/lighting/engine-glow");
});

setlistener("sim/model/shuttle9/systems/warp1-request", func {
	warp1_request = getprop("sim/model/shuttle9/systems/warp1-request");
});

setlistener("sim/model/shuttle9/systems/warp1-level", func {
	warp1_level = getprop("sim/model/shuttle9/systems/warp1-level");
});

setlistener("sim/model/shuttle9/systems/warp2-request", func {
	warp2_request = getprop("sim/model/shuttle9/systems/warp2-request");
});

# lighting and texture ----------------------------------------------

setlistener("environment/visibility-m", func {
	visibility = getprop("environment/visibility-m");
}, 1);

#==========================================================================
# loop function #3 called by nav_light_loop every 3 seconds
#    or every 0.5 seconds when time warp ============================

var nav_lighting_update = func {
	var nlu_nav = nav_light_switch.getValue();
	sun_angle = getprop("sim/time/sun-angle-rad");  # Tied property, cannot listen
	if (nlu_nav == 2) {
		nav_lights_state.setBoolValue(1);
	} else {
		if (nlu_nav == 1) {
			nav_lights_state.setBoolValue(visibility < 5000 or sun_angle > 1.4);
		} else {
			nav_lights_state.setBoolValue(0);
		}
	}
}

var nav_light_loop = func {
	nav_lighting_update();
	if (getprop("sim/time/warp-delta")) {
		settimer(nav_light_loop, 0.5);
	} else {
		settimer(nav_light_loop, 3);
	}
}

#==========================================================================

var change_maximum = func(cm_from, cm_to, cm_type) {
	var lmt = limit[(impulse_level + (warp1_level* 2) + (warp2_level* 4))];
	if (lmt < 0) {
		lmt = 0;
	}
	if (cm_to < 0) {  # shutdown by crash
		cm_to = 0;
	}
	if (max_drift) {   # did not finish last request yet
		if (cm_to > cm_from) {
			if (cm_type < 2) {  # startup from power down. bring systems back online
				cm_to = max_to + 1;
			}
		} else {
			var cm_to_new = max_to - 1;
			if (cm_to_new < 0) {  # midair shutdown
				cm_to_new = 0;
			}
			cm_to = cm_to_new;
		}
		if (cm_to >= size(speed_mps)) { 
			cm_to = size(speed_mps) - 1;
		}
		if (cm_to >= lmt) {
			cm_to = lmt;
		}
		if (cm_to < 0) {
			cm_to = 0;
		}
	} else {
		max_from = cm_from;
	}
	max_to = cm_to;
	max_drift = abs(speed_mps[cm_from] - speed_mps[cm_to]) / 20;
	if (cm_type > 1) {  
		# separate new maximum from limit. by engine shutdown/startup
		current_to = cpl;
	} else { 
		# by joystick flaps request
		current_to = cm_to;
	}
}

# modify flaps to change maximum speed --------------------------

controls.flapsDown = func(fd_d) {  # 1 decrease speed gearing -1 increases by default
	var fd_return = 0;
	if(power_switch) {
		if (!fd_d) {
			return;
		} elsif (fd_d > 0 and cpl > 0) {    # reverse joystick buttons direction by exchanging < for >
			change_maximum(cpl, (cpl-1), 1);
			fd_return = 1;
		} elsif (fd_d < 0 and cpl < size(speed_mps) - 1) {    # reverse joystick buttons direction by exchanging < for >
			var check_max = cpl;
			if (max_drift > 0) {
				check_max = max_to;
			}
			if (cpl >= limit[(impulse_level + (warp1_level* 2) + (warp2_level* 4))]) {
				if (warp1_level) {
					if (impulse_level) {
						popupTip2("Unable to comply. Orbital velocities requires higher energy setting");
					} else {
						popupTip2("Unable to comply. Requested velocity requires fusion reactor to be online");
					}
				} else {  
					popupTip2("Unable to comply. Primary warp engine OFF LINE");
				}
			} elsif (check_max > 6 and contact_altitude < 15000) {
				popupTip2("Unable to comply below 15,000 ft.");
			} elsif (check_max > 7 and contact_altitude < 50000) {
				popupTip2("Unable to comply below 50,000 ft.");
			} elsif (check_max > 8 and contact_altitude < 328000) {
				popupTip2("Unable to comply below 328,000 ft. (100 Km) The boundary between atmosphere and space.");
			} elsif (check_max > 9 and contact_altitude < 792000) {
				popupTip2("Unable to comply below 792,000 ft. (150 Miles) The NASA defined boundary for space.");
			} else {
				change_maximum(cpl, (cpl + 1), 1);
				fd_return = 1;
			}
		}
		if (fd_return) {
			var ss = speed_mps[max_to];
			popupTip2("Max. Speed " ~ ss ~ " m/s");
		}
		current.setValue(cpl);
	} else {
		popupTip2("Unable to comply. Main power is off.");
	}
}


# position adjustment function =====================================

var settle_to_level = func {
	var hg_roll = roll_deg.getValue() * 0.75;
	roll_deg.setValue(hg_roll);  # unless on hill... doesn't work right with ufo model
	var hg_roll = roll_control.getValue() * 0.75;
	roll_control.setValue(hg_roll);
	var hg_pitch = pitch_deg.getValue() * 0.75;
	pitch_deg.setValue(hg_pitch);
	var hg_pitch = pitch_control.getValue() * 0.75;
	pitch_control.setValue(hg_pitch);
}

#==========================================================================
# -------- MAIN LOOP called by itself every cycle --------

var update_main = func {
var skid_altitude_change = 0;

	var gnd_elev = ground_elevation_ft.getValue();  # ground elevation
	var altitude = altitude_ft_Node.getValue();  # aircraft altitude

	if (gnd_elev == nil) {    # startup check
		gnd_elev = 0;
	}
	if (altitude == nil) {
		altitude = -9999;
	}
	if (altitude > -9990) {   # wait until program has started
		 pitch_d = pitch_deg.getValue();   # update variables used by everybody
		 airspeed = airspeed_kt_Node.getValue();
		 asas = abs(airspeed);
		 abs_airspeed_Node.setDoubleValue(asas);
		  # ----- initialization checks -----
		 if (init_agl > 0) { 
		    # trigger rumble sound to be on
		   setprop("controls/engines/engine/throttle",0.01);
		    # find real ground level
		   altitude = gnd_elev + init_agl;
		   altitude_ft_Node.setDoubleValue(altitude);
		   if (init_agl > 1) {
		     init_agl -= 0.75;
		   } elsif (init_agl > 0.25) {
		     init_agl -= 0.25;
		   } else {
		     init_agl -= 0.05;
		   }
		   if (init_agl <= 0) {
		     setprop("controls/engines/engine/throttle",0);
		   }
		 }
		 var hover_ft = 0;
		 contact_altitude = altitude - 5.1 - hover_add;   # adjust calculated altitude for nacelle/nose dip

		  # ----- only check hover if near ground ------------------
		 var check_agl = (asas * 0.05) + 40;
		 if (check_agl < 50) {
		   check_agl = 50;
		 }
		 if (contact_altitude < (gnd_elev + check_agl)) {
		   var roll_d = abs(roll_deg.getValue());
		   var skid_w2 = 0;
		   var skid_altitude_change = 0;
		   if (pitch_d > 0) {
		     if (pitch_d < 44) {  # try to keep rear of nacelles from touching ground
		       hover_add = pitch_d / 3.75;
		     } elsif (pitch_d < 70) {
		       hover_add = ((pitch_d - 44) / 4.5) + 11.73;
		     } else {
		       hover_add = ((pitch_d - 70) / 6.7) + 17.51;
		     }
		   } else {
		     if (pitch_d > -10) {  # try to keep nose from touching ground
		       hover_add = abs(pitch_d / 7);
		     } elsif (pitch_d > -24) {
		       hover_add = abs((pitch_d + 10) / 2.97 ) + 1.43;
		     } else {
		       hover_add = abs((pitch_d + 24) / 2.5) + 6.15;
		     }
		   }
		   if (roll_d < 32.5) {	# keep nacelles from touching ground
		     var rolld = roll_d / 6.5;
		   } else {
		     var rolld = ((roll_d - 32.5) / 8.125) + 32.5;
		   }
		   hover_add = hover_add + rolld;   # total clearance for model above gnd_elev
		     # add to hover the airspeed calculation to increase ground separation with airspeed
		   if (asas < 100) {  # near ground hovering altitude calculation
		     hover_ft = 2.3 + (0.022 * (asas - 100));
		   } elsif (asas > 500) {  # increase separation from ground
		     hover_ft = 22.3 + ((asas - 500) * 0.023);
		   } else {    # hold altitude above ground, increasing with velocity
		     hover_ft = (asas * 0.05) - 2.7;
		   }
		   if (engines_lvl < 1.0) {
		     hover_ft = (hover_ft * engines_lvl);  # smoothen assent on startup
		   }

		   if (gnd_elev < 0) {   
		     # likely over ocean water
		     gnd_elev = 0;  # keep above water until there is an ocean bottom
		   }
		   contact_altitude = altitude - 5.1 - hover_add;   # update with newer hover amounts
		   hover_target_altitude = gnd_elev + 5.1 + hover_add + hover_ft;  # hover elevation
		   h_contact_target_alt = gnd_elev + hover_ft;

		   if (contact_altitude < h_contact_target_alt) {
		      # below ground/flight level
		     if (altitude > 0) {            # check for skid, smoothen sound effects
		       if (contact_altitude < gnd_elev) {
		         skid_w2 = (gnd_elev - contact_altitude);  # depth
		         if (skid_w2 < skid_last_value) {  # abrupt impact or
		           skid_w2 = (skid_w2 + skid_last_value) * 0.75; # smoothen ascent
		          }
		         # below ground, contact should skid
		       }
		     }
		     skid_altitude_change = hover_target_altitude - altitude;
		     if (skid_altitude_change > 0.5) {
		       if (skid_altitude_change < hover_ft) {
		         # hover increasing altitude, but still above ground
		         # add just enough skid to create the sound of 
		         # emergency anti-grav and thruster action
		         if (skid_w2 < 1.0) {
		           skid_w2 = 1.0;
		         }
		       }
		       if (skid_altitude_change > skid_w2) {
		          # keep skid sound going and dig in if bounding up large hill
		         var impact_factor = (skid_altitude_change / asas * 25);
		          # vulnerability to impact. Increasing from 25 increases vulnerability
		         if (skid_altitude_change > impact_factor) {  # but not if on flat ground
		           skid_w2 = skid_altitude_change;  # choose the larger skid value
		         }
		       }
		     }
		     if (hover_ft < 0) {  # separate skid effects from actual impact
		       altitude = hover_target_altitude - hover_ft;
		     } else {
		       altitude = hover_target_altitude;
		     }
		     altitude_ft_Node.setDoubleValue(altitude);  # force above ground elev to hover elevation at contact
		     contact_altitude = altitude - 5.1 - hover_add;
		     if (pitch_d > 0 or pitch_d < -0.5) {
		        # If aircraft hits ground, then nose/tail gets thrown up
		       if (asas > 500) {  # new pitch adjusted for airspeed
		         var airspeed_pch = 0.2;  # rough ride
		       } else {
		         var airspeed_pch = asas / 500 * 0.2;
		       }
		       if (airspeed > 0.1) {
		         if (pitch_d > 0) {
		           # going uphill
		           pitch_d = pitch_d * (1.0 + airspeed_pch);
		           pitch_deg.setDoubleValue(pitch_d);
		         } else {
		           # nose down
		           pitch_d = pitch_d * (1.0 - airspeed_pch);
		           pitch_deg.setDoubleValue(pitch_d);
		         }
		       } elsif (airspeed < -0.1) {    # reverse direction
		         if (pitch_d < 0) {  # uphill
		           pitch_d = pitch_d * (1.0 + airspeed_pch);
		           pitch_deg.setDoubleValue(pitch_d);
		         } else {
		           pitch_d = pitch_d * (1.0 - airspeed_pch);
		           pitch_deg.setDoubleValue(pitch_d);
		         }
		       }
		     }
		   } else {  
		     # smoothen to zero
		     var skid_w2 = (skid_last_value) / 2;
		   }
		   if (skid_w2 < 0.001) {
		     skid_w2 = 0;
		   }
		   var skid_w_vol = skid_w2 * 0.1;  # factor for volume usage
		   if (skid_w_vol > 1.0) {
		     skid_w_vol = 1.0;
		   }
		   if (skid_altitude_change < 5) {
		     if (abs(pitch_d) < 3.75) {
		       skid_w_vol = skid_w_vol * (abs(pitch_d + 0.25)) * 0.25;
		     }
		   }
		   setprop("sim/model/shuttle9/position/skid-wow", skid_w_vol);
		   skid_last_value = skid_w2;
		 } else { 
		   # not near ground, skipping hover
		   setprop("sim/model/shuttle9/position/skid-wow", 0);
		   skid_last_value = 0;
		   hover_add = 0;
		   h_contact_target_alt = 0;
		 }
		  # ----- lose altitude -----
		 if (engines_lvl < 0.2 or power_switch == 0) {
		   if ((contact_altitude - 0.0001) < h_contact_target_alt) {
		     # already on/near ground
		     if (lose_altitude > 0.2) {
		       lose_altitude = 0.2;  # avoid bouncing by simulating gravity
		     }
		     if (!antigrav_request) {
		       if (!impulse_request) {
		         settle_to_level();
		       }
		     } else {
		       lose_altitude = 0;
		     }
		   } else {
		     # not on/near ground
		     if (!(warp1_level and asas > 150)) {
		       # warp power is off and not fast enough to fly without engines on-line
		       lose_altitude += 0.01;
		       if ((contact_altitude - h_contact_target_alt) < 3) {   # really close to ground but not below it
		         if (!impulse_request) {
		           settle_to_level();
		         }
		       }
		     } else { # fast enough to fly without anti-grav
		       lose_altitude = lose_altitude * 0.5;
		       if (lose_altitude < 0.001) { lose_altitude = 0; }
		     }
		   }
		   if (lose_altitude > 0) {
		     hover_grav(-1, lose_altitude, 0);
		   }
		 } else {
		   lose_altitude = 0;
		 }

		  # ----- also calculate altitude-agl since ufo model doesn't -----
		 var aa = altitude - gnd_elev;
		 setprop("sim/model/shuttle9/position/shadow-alt-agl-ft", aa);
		 var agl = contact_altitude - gnd_elev + hover_add;
		 setprop("sim/model/shuttle9/position/altitude-agl-ft", agl);

		  # ----- handle traveling backwards and update movement variables ------
		  #       including updating sound based on airspeed
		  # === speed up or slow down from engine level ===
		 var max = maxspeed.getValue();
		 if (!power_switch) { 
		   if (warp1_request) {   # deny warp drive request
		     setprop("sim/model/shuttle9/systems/warp1-request", "false");
		     warp1_request = 0;
		   }
		   if (warp2_request) {
		     setprop("sim/model/shuttle9/systems/warp2-request", "false");
		     warp2_request = 0;
		   }
		 }
		 if (cpl > 6) {
		   if (cpl > 10 and contact_altitude < 792000 and max_to > 10) {
		     popupTip2("Approaching planet. Reducing speed");
		     change_maximum(cpl, 10, 1); 
		   } elsif (cpl > 9 and contact_altitude < 328000 and max_to > 9) {
		     popupTip2("Entering upper atmosphere. Reducing speed");
		     change_maximum(cpl, 9, 1); 
		   } elsif (cpl > 8 and contact_altitude < 50000 and max_to > 8) {
		     popupTip2("Entering lower atmosphere. Reducing speed");
		     change_maximum(cpl, 8, 1); 
		   } elsif (cpl > 7 and contact_altitude < 15000 and max_to > 7) {
		     popupTip2("Entering lower atmosphere. Reducing speed");
		     change_maximum(cpl, 7, 1); 
		   }
		 }
		 if (!power_switch) {
		   change_maximum(cpl, 0, 2);
		   if (warp1_level) {
		     setprop("sim/model/shuttle9/systems/warp1-level", 0);
		   }
		   if (warp2_level) {
		     warp2_level = 0;
		   }
		   if (agl > 10) {   # not in ground contact, glide
		     max_lose = max_lose + (0.005 * abs(pitch_d));
		   } else {     # rapid deceleration
		     max_lose = asas * 0.2;
		   }
		   if (max_lose > 10) {  # don't decelerate too quickly
		     if (agl > 10) {
		       max_lose = 10;
		     } else {
		       if (max_lose > 75) {
		         max_lose = 75;
		       }
		     }
		   }
		   if (asas < 1) {  # already stopped
		     cpl = max_to;
		     max_from = max_to;
		     max = speed_mps[max_to];
		     max_drift = 0;
		     max_lose = 0;
		     maxspeed.setDoubleValue(max);
		   }
		   max_drift = max_lose;
		 } else {  # power is on
		   if (impulse_request != impulse_level) {
		     change_maximum(cpl, limit[(impulse_request + (warp1_level * 2) + (warp2_level * 4))], 2);
		     setprop("sim/model/shuttle9/systems/impulse-level", impulse_request);
		   }
		   if (warp1_request != warp1_level) {
		     change_maximum(cpl, limit[(impulse_level + (warp1_request * 2) + (warp2_level * 4))], 2);
		     setprop("sim/model/shuttle9/systems/warp1-level", warp1_request);
		   }
		   if (warp2_request != warp2_level) {
		     change_maximum(cpl, limit[(impulse_level + (warp1_level * 2) + (warp2_request * 4))], 2);
		     warp2_level = warp2_request;
		     setprop("sim/model/shuttle9/systems/warp2-level", warp2_level);
		   }
		 }
		 if (max > 1 and max_to < max_from) {      # decelerate smoothly
		   max -= (max_drift / 2);
		   if (max <= speed_mps[max_to]) {     # destination reached
		     cpl = max_to;
		     max_from = max_to;
		     max = speed_mps[max_to];
		     max_drift = 0;
		     max_lose = 0;
		     if (!power_switch) {       # override if no power
		       max = 1;
		     }
		   }
		   maxspeed.setDoubleValue(max);
		 }
		 if (max_to > max_from) {         # accelerate
		   if (current_to == max_to) {   # normal request to change power-maxspeed
		     max += max_drift;
		     if (max >= speed_mps[max_to]) { 
		       # destination reached
		       cpl = max_to;
		       max_from = max_to;
		       max = speed_mps[max_to];
		       max_drift = 0;
		       max_lose = 0;
		     }
		     maxspeed.setDoubleValue(max);
		   } else {    # only change maximum, as when turning on an engine
		     max_from = max_to;
		     max_drift = 0;
		     max_lose = 0;
		     if (cpl == 0 and current_to == 0) {     # turned on power from a complete shutdown
		       maxspeed.setDoubleValue(speed_mps[2]);
		       current_to = max_to;
		       cpl = 2;
		     }
		   }
		 }
		 current.setValue(cpl);

		   # === sound section based on position/airspeed/altitude ===
		 var slv = sound_level;
		 if (power_switch) {
		   if (impulse_drift < 1 and slv > 1) {  # shutdown reactor before timer shutdown of standby power
		     slv = 0.99;
		   }
		   if (asas < 1 and agl < 2 and !antigrav_request) {
		     if (sound_state and slv > 0.999) {  # shutdown request by landing has 2.5 sec delay
		       slv = 2.5;
		     }
		     sound_state = 0;
		   } else {
		     if (((impulse_state < impulse_drift) or (!impulse_state)) and asas < 5 and !antigrav_request) {  # antigrav shutdown
		       sound_state = 0;
		       antigrav_request = 0;
		       if (slv >= 1) {
		         slv = 0.99;
		       }
		     } else {
		       if (asas > 5 or agl >= 2 or antigrav_request) {
		         sound_state = 1;
		       } else {
		         sound_state = 0;
		       }
		     }
		   }
		 } else {
		   if (sound_state) {  # power shutdown with reactor on. single entry.
		     slv = 0.99;
		     sound_state = 0;
		     antigrav_request = 0;
		   }
		 }
		 if (sound_state != slv) {  # ramp up reactor sound fast or down slow
		   if (sound_state) { 
		     slv += 0.02;
		   } else {
		     slv -= 0.00625;
		   }
		   if (sound_state and slv > 1.0) {  # bounds check
		     slv = 1.000;
		     antigrav_request = 0;
		   }
		   if (slv > 0.5 and antigrav_request) {
		     if (antigrav_request <= 1) {
		       antigrav_request -= 0.025;  # reached sufficient power to turn off trigger
		       slv -= 0.02;  # hold this level for a couple seconds until either another
		        # keyboard/joystick request confirms startup, or time expires and shutdown
		       if (antigrav_request < 0.1) {
		         antigrav_request = 0;  # holding time expired
		       }
		     }
		   }
		   if (slv < 0.0) {
		     slv = 0.000;
		   }
		   sound_level = slv;
		 }
		 # engine rumble sound
		 if (asas < 200) {
			var a1 = 0.1 + (asas * 0.002);
		 } elsif (asas < 4000) {
			var a1 = 0.5 + ((asas - 200) * 0.0001315);
		 } else {
			var a1 = 1.0;
		 }
		 var a3 = (asas * 0.000187) + 0.25;
		 if (a3 > 0.75) {
		   a3 = ((asas - 4000) / 384000) + 0.75;
		 }
		 if (slv > 1.0) {    # timer to shutdown
		   var a2 = a1;
		   var a5 = (asas * 0.0002) + 0.4;
		   var a6 = 1;
		 } else {      # shutdown progressing
		   var a2 = a1 * slv;
		   a3 = a3 * slv;
		   var a5 = 0.2 + (slv * ((asas * 0.0002) + 0.2));
		   var a6 = slv;
		 }
		 a5 = clamp(a5, 0, 1);
		 if (warp1_level) {
		   setprop("sim/model/shuttle9/lighting/bussard-glow-red", a5);
		   setprop("sim/model/shuttle9/lighting/bussard-glow-blgr", (0.1 - (a5 * 0.1)));
		   if (asas > 1 or slv == 1.0 or slv > 2.0) {
		     warp_state = (asas * 0.00032) + 0.4;
		   } elsif (slv > 1.667) {
		     warp_state = ((slv * 3) - 5) * ((asas * 0.00032) + 0.4);
		   } else {
		     warp_state = 0;
		   }
		 } else {
			setprop("sim/model/shuttle9/lighting/bussard-glow-red", 0.2);
			setprop("sim/model/shuttle9/lighting/bussard-glow-blgr", 0.1);
		   warp_state = 0;
		 }
		 if (impulse_level) {
		   impulse_state = a6;
		 } else {
		   impulse_state = 0;
		 }
		 if (power_switch) {
		   if (impulse_state > impulse_drift) {
		     impulse_drift += 0.04;
		     if (impulse_drift > impulse_state) {
		       impulse_drift = impulse_state;
		     }
		   } elsif (impulse_state < impulse_drift) {
		     if (impulse_level) {
		       impulse_drift = impulse_state;
		     } else {
		       impulse_drift -= 0.02;
		     }
		   }
		 } else {
		   impulse_drift -= 0.02;
		 }
		 if (impulse_drift < 0) {  # bounds check
		   impulse_drift = 0;
		 }
		 if (warp_state > warp_drift) {
		   warp_drift += 0.1;
		   if (warp_drift > warp_state) {
		     warp_drift = warp_state;
		   }
		 } elsif (warp_state < warp_drift) {
		   if (warp1_level) {
		     warp_drift -= 0.1;
		   } else {
		     warp_drift -= 0.02;
		   }
		   if (warp_drift < warp_state) {
		     warp_drift = warp_state;
		   }
		 }
		 var a4 = warp_drift;
		 if (!impulse_level and !warp1_level) {
		   a2 = a2 / 2;
		 }
		 if (a3 > 12.5) {  # set upper limits
		   a3 = 12.5;
		 }
		 if (a4 > 1.75) {
		   a4 = 1.75;
		 }
		 setprop("sim/model/shuttle9/sound/engines-volume-level", a2);
		 setprop("sim/model/shuttle9/sound/pitch-level", a3);
		 setprop("sim/model/shuttle9/lighting/engine-glow", impulse_drift);
		 if (impulse_level) {
		   if (!impulse_drift and !power_switch and !slv) {
		     setprop("sim/model/shuttle9/systems/impulse-level", 0);
		   }
		 }
		 setprop("sim/model/shuttle9/lighting/warp-glow", a4);
	}
	settimer(update_main, 0);
}

# VTOL anti-grav functions ---------------------------------------

controls.elevatorTrim = func(et_d) {
	if (!et_d) {
		return;
	} else {
		var js1pitch = abs(joystick_elevator.getValue());
		if (et_d < 0) {
			hover_grav(-1, js1pitch, 1);
		} elsif (et_d > 0) {
			hover_grav(1, js1pitch, 1);
		}
	}
}

var reset_landing = func {
	setprop("sim/model/shuttle9/position/landing-wow", "false");
}

setlistener("sim/model/shuttle9/position/landing-wow", func {
	if (getprop("sim/model/shuttle9/position/landing-wow")) {
		settimer(reset_landing, 0.4);
	}
 });

var reset_squeal = func {
	setprop("sim/model/shuttle9/position/squeal-wow", "false");
}

setlistener("sim/model/shuttle9/position/squeal-wow", func {
	if (getprop("sim/model/shuttle9/position/squeal-wow")) {
		settimer(reset_squeal, 0.3);
	}
 });

var hover_grav = func(hg_dir, hg_thrust, hg_mode) {  # d=direction p=thrust_power m=source of request
	var entry_altitude = altitude_ft_Node.getValue();
	var altitude = entry_altitude;
	contact_altitude = altitude - 5.1 - hover_add;

		# set anti-grav power level below here. default= *4
		# Future plan to link this multiplier to the collective lever next to the throttle.
	var hg_rise = hg_thrust * 4 * hg_dir;
	var contact_rise = contact_altitude + hg_rise;
	if (hg_dir < 0) {    # down requested by drift, fall, or VTOL down buttons
		if (contact_rise < h_contact_target_alt) {  # too low
			contact_rise = h_contact_target_alt + 0.0001;
			if ((contact_rise < contact_altitude) and !antigrav_request) {
				if (asas < 40) {  # ground contact by landing or falling fast
					if (lose_altitude > 0.2 or hg_rise < -0.5) {
						var already_landed = getprop("sim/model/shuttle9/position/landing-wow");
						if (!already_landed) {
							setprop("sim/model/shuttle9/position/landing-wow", "true");
						} 
						lose_altitude = 0;
						if (!impulse_request) {
							settle_to_level();
						}
					} else {
						lose_altitude = lose_altitude * 0.5;
					}
				} elsif (lose_altitude > 0.26 and hg_rise < -1.1) {  # ground contact by skidding slowly
					setprop("sim/model/shuttle9/position/squeal-wow", "true");
						lose_altitude = lose_altitude * 0.5;
					if (!impulse_request) {
						settle_to_level();
					}
				}
			} else {
				lose_altitude = lose_altitude * 0.5;
			}
		}
		if (!antigrav_request) {  # fall unless antigrav just requested
			altitude = contact_rise + 5.1 + hover_add;
			altitude_ft_Node.setDoubleValue(altitude);
			contact_altitude = contact_rise;
		}
	} elsif (hg_dir > 0) {  # up
		if (engines_lvl < 0.5 and impulse_level) {  # on standby, power up requested for hover up
			if (power_switch) {
				setprop("sim/model/shuttle9/systems/impulse-request", "true");
				antigrav_request += 1;   # keep from forgetting until reactor powers up over 0.5
			}
		}
		if (engines_lvl > 0.2 and impulse_level) {  # sufficient power to comply and lift
			contact_rise = contact_altitude + (engines_lvl * hg_rise);
			altitude = contact_rise + 5.1 + hover_add;
			altitude_ft_Node.setDoubleValue(altitude);
			contact_altitude = contact_rise;
		}
	}
	if ((entry_altitude + hg_rise + 0.01) < altitude) {  # did not achieve full request. must've touched ground
		if (lose_altitude > 0.2) {
			lose_altitude = 0.2;
		}
	}
}

# keyboard and 3-d functions ----------------------------------------

var toggle_power = func(tp_mode) {
	if (tp_mode == 9) {  # clicked from dialog box
		if (!power_switch) {
			setprop("sim/model/shuttle9/systems/impulse-request", "false");
			setprop("sim/model/shuttle9/systems/warp1-request", "false");
			change_maximum(cpl, 0, 2);
		}
	} else {   # clicked from keyboard
		if (power_switch) {
			setprop("sim/model/shuttle9/systems/power-switch", "false");
			setprop("sim/model/shuttle9/systems/impulse-request", "false");
			setprop("sim/model/shuttle9/systems/warp1-request", "false");
			change_maximum(cpl, 0, 2);
		} else {
			setprop("sim/model/shuttle9/systems/power-switch", "true");
		}
	}
}

var toggle_impulse = func {
	if (impulse_request) {
		setprop("sim/model/shuttle9/systems/impulse-request", "false");
	} else {
		if (power_switch) {
			setprop("sim/model/shuttle9/systems/impulse-request", "true");
		} else {
			popupTip2("Unable to comply. Main power is off.");
		}
	}
}

var toggle_warp1 = func {
	if (warp1_request) {
		setprop("sim/model/shuttle9/systems/warp1-request", "false");
	} else {
		if (power_switch) {
			setprop("sim/model/shuttle9/systems/warp1-request", "true");
		} else {
			popupTip2("Unable to comply. Main power is off.");
		}
	}
}

var toggle_warp2 = func {
	if (warp2_request) {
		setprop("sim/model/shuttle9/systems/warp2-request", "false");
	} else {
		if (power_switch) {
			if (warp1_request) {
				setprop("sim/model/shuttle9/systems/warp2-request", "true");
			} else {
				popupTip2("Unable to comply. warp drive is off.");
			}
		} else {
			popupTip2("Unable to comply. Main power is off.");
		}
	}
}

# dialog functions --------------------------------------------------

var set_nav_lights = func(snl_i) {
	var snl_new = nav_light_switch.getValue();
	if (snl_i == -1) {
		snl_new += 1;
		if (snl_new > 2) {
			snl_new = 0;
		}
	} else {
		snl_new = snl_i;
	}
	nav_light_switch.setValue(snl_new);
	active_nav_button = [ 3, 3, 3];
	if (snl_new == 0) {
		active_nav_button[0]=1;
	} elsif (snl_new == 1) {
		active_nav_button[1]=1;
	} else {
		active_nav_button[2]=1;
	}
	nav_lighting_update();
}

setlistener("sim/model/livery/insignia", func {
	var new_li = getprop("sim/model/livery/insignia");
	active_insignia_button = [ 3, 3];
	if (new_li == 0) {
		active_insignia_button[0]=1;
	} else {
		active_insignia_button[1]=1;
	}
});

var reloadDialog = func {
	name = "shuttle9-config";
	if (config_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		config_dialog = nil;
		showDialog();
		return;
	}
}

var showDialog = func {
	name = "shuttle9-config";
	if (config_dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		config_dialog = nil;
		return;
	}

	config_dialog = gui.Widget.new();
	config_dialog.set("layout", "vbox");
	config_dialog.set("name", name);
	config_dialog.set("x", -40);
	config_dialog.set("y", -40);

 # "window" titlebar
	titlebar = config_dialog.addChild("group");
	titlebar.set("layout", "hbox");
	titlebar.addChild("empty").set("stretch", 1);
	titlebar.addChild("text").set("label", "Type 9 Shuttlecraft configuration");
	titlebar.addChild("empty").set("stretch", 1);

	config_dialog.addChild("hrule").addChild("dummy");

	w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.set("keynum", 27);
	w.set("border", 1);
	w.prop().getNode("binding[0]/command", 1).setValue("nasal");
	w.prop().getNode("binding[0]/script", 1).setValue("shuttle9.config_dialog = nil");
	w.prop().getNode("binding[1]/command", 1).setValue("dialog-close");

	var checkbox = func {
		group = config_dialog.addChild("group");
		group.set("layout", "hbox");
		group.addChild("empty").set("pref-width", 4);
		box = group.addChild("checkbox");
		group.addChild("empty").set("stretch", 1);

		box.set("halign", "left");
		box.set("label", arg[0]);
		box;
	}

 # master power switch
	w = checkbox("master power");
	w.set("property", "sim/model/shuttle9/systems/power-switch");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	w.prop().getNode("binding[1]/command", 1).setValue("nasal");
	w.prop().getNode("binding[1]/script", 1).setValue("shuttle9.toggle_power(9)");

 # impulse intake manifold glow
	w = checkbox("impulse engines");
	w.set("property", "sim/model/shuttle9/systems/impulse-request");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

 # warp drive backlight glow
	w = checkbox("warp engine");
	w.set("property", "sim/model/shuttle9/systems/warp1-request");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

 # extra glow and orbital velocities
	w = checkbox("increase plasma flow to warp drive");
	w.set("property", "sim/model/shuttle9/systems/warp2-request");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

	config_dialog.addChild("hrule").addChild("dummy");

 # lights
	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "nav lights:");
	g.addChild("empty").set("stretch", 1);

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);

	box = g.addChild("button");
	g.addChild("empty").set("stretch", 1);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 100);
	box.set("pref-height", 18);
	box.set("legend", "Stay On");
	box.set("border", active_nav_button[2]);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("shuttle9.set_nav_lights(2)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("shuttle9.reloadDialog()");
	box;

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 130);
	box.set("pref-height", 18);
	box.set("legend", "Dusk to Dawn");
	box.set("border", active_nav_button[1]);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("shuttle9.set_nav_lights(1)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("shuttle9.reloadDialog()");
	box;

	box = g.addChild("button");
	g.addChild("empty").set("pref-width", 4);
	box.set("halign", "left");
	box.set("label", "");
	box.set("pref-width", 50);
	box.set("pref-height", 18);
	box.set("legend", "Off");
	box.set("border", active_nav_button[0]);
	box.prop().getNode("binding[0]/command", 1).setValue("nasal");
	box.prop().getNode("binding[0]/script", 1).setValue("shuttle9.set_nav_lights(0)");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("shuttle9.reloadDialog()");
	box;

	# beacons
	w = checkbox("beacons");
	w.set("property", "controls/lighting/beacon");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

	config_dialog.addChild("hrule").addChild("dummy");

 # insignia
	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	w = g.addChild("text");
	w.set("halign", "left");
	w.set("label", "Show registration as assigned to:");
	g.addChild("empty").set("stretch", 1);

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	box = g.addChild("button");
	g.addChild("empty").set("stretch", 1);
	box.set("halign", "left");
	box.set("label", "Voyager");
	box.set("pref-width", 100);
	box.set("pref-height", 18);
	box.set("legend", "74656");
	box.set("border", active_insignia_button[1]);
	box.prop().getNode("binding[0]/command", 1).setValue("property-assign");
	box.prop().getNode("binding[0]/property", 1).setValue("sim/model/livery/insignia");
	box.prop().getNode("binding[0]/value", 1).setValue("1");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("shuttle9.reloadDialog()");
	box;

	g = config_dialog.addChild("group");
	g.set("layout", "hbox");
	g.addChild("empty").set("pref-width", 4);
	box = g.addChild("button");
	g.addChild("empty").set("stretch", 1);
	box.set("halign", "left");
	box.set("label", "None");
	box.set("pref-width", 100);
	box.set("pref-height", 18);
	box.set("legend", "");
	box.set("border", active_insignia_button[0]);
	box.prop().getNode("binding[0]/command", 1).setValue("property-assign");
	box.prop().getNode("binding[0]/property", 1).setValue("sim/model/livery/insignia");
	box.prop().getNode("binding[0]/value", 1).setValue("0");
	box.prop().getNode("binding[1]/command", 1).setValue("nasal");
	box.prop().getNode("binding[1]/script", 1).setValue("shuttle9.reloadDialog()");
	box;

	config_dialog.addChild("hrule").addChild("dummy");

	# simple and fast shadow - alternative to Rendered AC shadow
	w = checkbox("Simple 2D shadow");
	w.set("property", "sim/model/shuttle9/shadow");
	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

 # finale
	config_dialog.addChild("empty").set("pref-height", "3");
	fgcommand("dialog-new", config_dialog.prop());
	gui.showDialog(name);
}

#==========================================================================
#                 === initial calls at startup ===
 setlistener("sim/signals/fdm-initialized", func {

 update_main();  # starts continuous loop
 settimer(nav_light_loop, 0.5);
 settimer(reset_landing, 1.0);

 print ("Type 9 Shuttlecraft  by Stewart Andreason");
 print ("  version 6.32  release date 2014.Feb.03  for FlightGear 1.0 and 1.9+");
 });
