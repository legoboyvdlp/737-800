
var activateRoute = func()
{
    fgcommand("activate-flightplan");
}

var PosInitModel = 
{
    new: func()
    {
      m = {parents: [PosInitModel, CDU.AbstractModel.new()]};
      m._refAirport = nil;
      m._gate = nil;
      m._routeActiveNode = props.globals.getNode('autopilot/route-manager/active', 1);
      return m;
    },
    
    dataForRefAirport: func {(me._refAirport == nil) ? CDU.EMPTY_FIELD4 : me._refAirport.id;},
    dataForGate: func { me._gate != nil ? me._gate.name : CDU.EMPTY_FIELD5; },
    
    dataForRefAirportPos: func { 
        if (me._refAirport == nil) return '';
        return CDU.formatLatLonString(me._refAirport); 
    }
    ,
    dataForGatePos: func { 
        if (me._gate == nil) return '';
        return CDU.formatLatLonString(me._gate);
    },
        
    dataForLastPos: func { CDU.formatLatLonString(geo.aircraft_position());  },  
    dataForFMCPos: func { CDU.formatLatLonString(geo.aircraft_position());  },  
    dataForFMCG: func { sprintf("%3d",getprop("velocities/groundspeed-kt"))~'~KT';  },  
    dataForIRSPos: func { CDU.formatLatLonString(geo.aircraft_position());  },  
    dataForGPSPos: func { CDU.formatLatLonString(geo.aircraft_position());  },  
    dataForRadioPos: func() { CDU.formatLatLonString(geo.aircraft_position());  }, 
    
    dataForIRSPosInit: func {
        var posInitDone = getprop('instrumentation/fmc/pos-init-complete');
        if (!posInitDone) return CDU.BOX3 ~ 'g' ~ CDU.BOX2_1 ~ ' ' ~ CDU.BOX4 ~ 'g' ~ CDU.BOX2_1;
        return CDU.formatLatLonString(geo.aircraft_position());
    },
    
    editIRSPosInit: func(scratch) {        
        setprop('instrumentation/fmc/pos-init-complete', 1);
        return 1;
    },
    
    dataForGMTDate: func {
        var raw = getprop("/sim/time/gmt");
        # format is HHMM
        var hour = substr(raw, 11, 2);
        var min = substr(raw, 14, 2);
        
        return hour ~ min ~ '~Z';  
    },
    
    editRefAirport: func(scratch) {
		if (scratch == 'DELETE')
			apt = nil;
		else {
			var apt = airportinfo(scratch);
			if (apt == nil) {
				cdu.message('NOT IN DATA BASE');
				return 0;
			}
		}
        
        me._refAirport = apt;
        return 1;
    },
    
    editGate: func(scratch) {
        if (me._refAirport == nil) {
            return 0;
        }
            
        foreach (var park; me._refAirport.parking()) {
            if (park.name == scratch) {
                me._gate = park;
                return 1;
            }
        }
        
		cdu.message('NOT IN DATA BASE');
        return 0;
    },
    
    #titleForGate: func {  (me._refAirport == nil) ? nil : 'GATE'; }
};


var TakeoffModel = 
{
    new: func()
    {
      m = {parents: [TakeoffModel, CDU.AbstractModel.new()]};
      return m;
    },
    
    dataForFlaps: func { 
        var f = getprop('instrumentation/fmc/inputs/takeoff-flaps');
		var h = getprop('instrumentation/fmc/inputs/acceleration-height-ft') or '~1500';
        if (f != 10 and f != 20) return CDU.BOX2~'/'~h~'FT';
        return sprintf('%2d', f)~'/'~h;
    },
    
    editFlaps: func(scratch) {
        var fields = CDU.parseDualFieldInput(scratch);
        debug.dump('fields:', scratch, fields);
        
        if (fields[0] != nil) {
            var f = num(fields[0]);
			if ((f != 10) and (f != 20)) return 0;
			setprop('instrumentation/fmc/inputs/takeoff-flaps', f);
			Boeing747.vspeeds();
        }
        
        if (fields[1] != nil) {
            var n = fields[1];
            if ((n < 400) or (n > 9999)) return 0;
            setprop('instrumentation/fmc/inputs/acceleration-height-ft', n);
			Boeing747.vspeeds();
        }
		
        return 1;
    },
	
	dataForThrReduction: func {
		var clbModeId = getprop('instrumentation/fmc/inputs/climb-derate-index');
        var clbMode = (clbModeId == 0) ? 'CLB' : sprintf('CLB %d', clbModeId);
		var redAlt = getprop('instrumentation/fmc/settings/thrust-reduction-alt-ft');
		var redFlap = getprop('instrumentation/fmc/settings/thrust-reduction-flaps');
		return ((redAlt == 0) ? 'FLAPS 5' : sprintf('%4d~FT',redAlt))~' !'~clbMode;
	},
	
	editThrReduction: func(scratch) {
        var n = num(scratch);
        if (n != 5 and ((n < 400) or (n > 9999))) return 0;
        
        if (n == 5) {
			setprop('instrumentation/fmc/settings/thrust-reduction-flaps',5);
			setprop('instrumentation/fmc/settings/thrust-reduction-alt-ft',0);
        } else {
			setprop('instrumentation/fmc/settings/thrust-reduction-flaps',0);
			setprop('instrumentation/fmc/settings/thrust-reduction-alt-ft',n);
		}
		
        return 1;
    },
    
    dataForV1: func { 
        var v1 = getprop('instrumentation/fmc/speeds/v1-kt');
		if (v1 == 0) return '---';
        return sprintf('%3d', v1)~'~KT';
    },
	
    dataForV2: func { 
        var v2 = getprop('instrumentation/fmc/speeds/v2-kt');
		if (v2 == 0) return '---';
        return sprintf('%3d', v2)~'~KT';
    },
	
    dataForVr: func { 
        var vr = getprop('instrumentation/fmc/speeds/vr-kt');
		if (vr == 0) return '---';;
        return sprintf('%3d', vr)~'~KT';
    },

    dataForTakeoffCG: func {
        sprintf('~%4.01f%%', getprop('/instrumentation/fmc/cg'));
    },
    
    dataForTakeoffTrim: func {
        sprintf('~%4.01f ', getprop('/instrumentation/fmc/stab-trim-units'));
    },
    
    titleForTakeoffThrust: func {
        var n = getprop('instrumentation/fmc/inputs/takeoff-derate-index');
        var rating = getprop('instrumentation/fmc/settings/takeoff-derate-rating[' ~ n ~']');
        sprintf('%dK', rating);
    },
    
    dataForTakeoffThrust: func {
        var n = getprop('instrumentation/fmc/takeoff/takeoff-thrust-n1');
        sprintf('%5.1f/%5.1f', n * 100, n * 100);
    },
    
    titleForPreflight: func(index) {
        if (index != 0) return '';
        var f = getprop('instrumentation/fmc/preflight-complete');
        return '-----------------' ~ (f ? '-------' : '~PRE-FLT');
    },

    dataForPreflight: func(index) {
        if (!getprop('instrumentation/fmc/pos-init-complete'))
            return 'POS INIT>';
        else if (!getprop('instrumentation/fmc/perf-complete'))
            return 'PERF INIT>';
        else if (!getprop('autopilot/route-manager/active'))
            return 'ROUTE>';
		else if (flightplan().departure_runway == nil)
			return 'DEPARTURE>';
		else
			return 'THRUST LIM>';
    },
    
    selectPreflight: func(index) {
        if (!getprop('instrumentation/fmc/pos-init-complete'))
            cdu.displayPageByTag('pos-init');
        else if (!getprop('instrumentation/fmc/perf-complete'))
            cdu.displayPageByTag('performance');
        else if (!getprop('autopilot/route-manager/active'))
            cdu.displayPageByTag('route');
		else if (flightplan().departure_runway == nil)
            cdu.displayPageByTag('departure');
		else
            cdu.displayPageByTag('n1-limit');
        return 1;
    },
};
var fp=flightplan();
var segment = airwaysRoute(navinfo('COL')[0],navinfo('PAM')[0]);

var RouteModel = 
{
    new: func()
    {
      m = {parents: [RouteModel, CDU.AbstractModel.new()]};
      m._fileSelector = nil;
      return m;
    },
	
	_wpIndexFromModel: func(index) { index + flightplan().current; },
    
    _wpFromModel: func(index) { flightplan().getWP(me._wpIndexFromModel(index)); },
    
    firstLineForTo: func 0,
    countForTo: func flightplan().getPlanSize()-1,
    firstLineForVia: func 0,
    countForVia: func flightplan().getPlanSize()-1,
  
    titleForTo: func(index) { (index == 0) ? '~TO' : ''; },
    titleForVia: func(index) { (index == 0) ? '~VIA' : ''; },
    
    dataForTo: func(index) {
		if (index == (flightplan().getPlanSize()-2)) return CDU.EMPTY_FIELD4;
		var wp = me._wpFromModel(index+1);
        return wp.wp_name;
	},
    dataForVia: func(index) {
		if (index == (flightplan().getPlanSize()-2)) return CDU.EMPTY_FIELD4;
		return 'DIRECT';
	},
	
    selectTo: func(index) {
		var scratch = cdu.getScratchpad();
		if (size(scratch) == 0) return 0;
		
		if (scratch == 'DELETE'){
			setprop("/autopilot/route-manager/input","@DELETE"~(index+1));
			return 1;
		}
		var data = navinfo(scratch);
		if (size(data) > 0) {
			flightplan().insertWP(createWPFrom(data[0]),index+1);
			cdu.clearScratchpad();
			return 1;
		} else {
			cdu.message('NOT IN DATA BASE');
		}
	},
    selectVia: func(index) { },
	
    dataForCompanyRoute: func { CDU.EMPTY_FIELD10; },
    
    selectCompanyRoute: func()
    {
        # show a file picker!
        
        if (me._fileSelector == nil)
            me._fileSelector = gui.FileSelector.new(func(p) { me.loadRoute(p) }, "Load flight-plan", "Load");
        me._fileSelector.open();
        return 1;
    },
    
    loadRoute: func(pathNode)
    {
        var path = pathNode.getValue();
        debug.dump('will load from path', path);
        me._fileSelector.close();
        if (size(path) < 1) {
            return;
        }
    
        fgcommand("load-flightplan", props.Node.new({"path": path}));
    
        # re-display the page, even if already shown
        cdu.displayPageByTag('route');
    }
    
};

###########
    var posInit1 = CDU.Page.new(cdu, "      POS INIT");
    var positionModel = PosInitModel.new();
    
    posInit1.setModel(positionModel);
    posInit1.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");} ));
    posInit1.addAction(CDU.Action.new('ROUTE', 'R6', func {
        cdu.displayPageByTag("route");
        # preload scratch with ref airport if set
		if (positionModel.dataForRefAirport() != CDU.EMPTY_FIELD4)
			cdu.setScratchpad(positionModel.dataForRefAirport());
    } ));
  
    posInit1.addField(CDU.Field.createWithLSKAndTag('R1', '~LAST POS', 'LastPos'));
    posInit1.addField(CDU.Field.createWithLSKAndTag('L2', '~REF AIRPORT', 'RefAirport'));
    posInit1.addField(CDU.Field.createWithLSKAndTag('R2', '', 'RefAirportPos'));
    posInit1.addField(CDU.Field.new(pos:'L3', title:'~GATE', tag:'Gate'));
    posInit1.addField(CDU.Field.createWithLSKAndTag('R3', '', 'GatePos'));
    posInit1.addField(CDU.Field.new(pos:'L4', title:'~UTC(GPS)', tag:'GMTDate', dynamic:1));
    posInit1.addField(CDU.Field.createWithLSKAndTag('R4', '~GPS POS', 'GPSPos'));
    posInit1.addField(CDU.Field.createWithLSKAndTag('R5', '~SET IRS POS', 'IRSPosInit'));
    posInit1.addField(CDU.StaticField.new('L5', '~SET HDG', '---g'));
  
    var posInit2 = CDU.Page.new(cdu, "      POS REF");
    posInit2.setModel(positionModel);
    
    posInit2.addField(CDU.Field.createWithLSKAndTag('L1', '~FMC POS', 'FMCPos'));
    posInit2.addField(CDU.Field.createWithLSKAndTag('L2', '~IRS L', 'IRSPos'));
    posInit2.addField(CDU.Field.createWithLSKAndTag('L3', '~IRS R', 'IRSPos'));
    posInit2.addField(CDU.Field.createWithLSKAndTag('L4', '~GPS L', 'GPSPos'));
    posInit2.addField(CDU.Field.createWithLSKAndTag('L5', '~GPS R', 'GPSPos'));
    posInit2.addField(CDU.Field.createWithLSKAndTag('L6', '~RADIO', 'RadioPos'));
    posInit2.addField(CDU.Field.createWithLSKAndTag('R1', '~GS', 'FMCG'));
  
    var posInit3 = CDU.Page.new(cdu, "POS SHIFT");
  
  
    CDU.linkPages([posInit1, posInit2, posInit3]);
    cdu.addPage(posInit1, "pos-init");
    cdu.addPage(posInit2, "pos-init-2");
    cdu.addPage(posInit3, "pos-init-3");
  
##########  
	var route1 = CDU.Page.new(cdu, "         RTE 1");
    var routeModel = RouteModel.new();
    
    route1.setModel(routeModel);

    route1.addField(CDU.NasalField.new('L1', '~ORIGIN', 
        func { return (flightplan().departure == nil) ? CDU.BOX4 : flightplan().departure.id; },
        func(data) {
			if (data == 'DELETE')
				apt = nil;
			else {
				var apt = airportinfo(data);
				if (apt == nil) {
					cdu.message('NOT IN DATA BASE');
					return 0;
				}
			}
          
            flightplan().departure = apt;
            # FCOM 11.40.15: entry of a new origin erases the previous route
            return 1; 
        }));
    
    route1.addField(CDU.NasalField.new('L2', '~RUNWAY', 
        func { return (flightplan().departure_runway == nil) ? CDU.EMPTY_FIELD5 : flightplan().departure_runway.id; },
        func(data) {
            var apt = flightplan().departure;
			if (data == 'DELETE')
				rwy = nil;
			else {
				var rwy = apt.runway(data);
				if (rwy == nil) {
					cdu.message('NOT IN DATA BASE');
					return 0;
				}
			}
          
            flightplan().departure_runway = rwy;
            return 1; 
        }));
      
    route1.addField(CDU.NasalField.new('R1', '~DEST', 
        func { return (flightplan().destination == nil) ? CDU.BOX4 : flightplan().destination.id; },
        func(data) {
			if (data == 'DELETE')
				apt = nil;
			else {
				var apt = airportinfo(data);
				if (apt == nil) {
					cdu.message('NOT IN DATA BASE');
					return 0;
				}
			}
          
            flightplan().destination = apt;
            return 1; 
        }));
      
      route1.addField(CDU.EditablePropField.new('R2', 'instrumentation/fmc/inputs/flight-number', '~FLT NO.'));
      route1.fixedSeparator = [3, 3];
	  
      route1.addField(CDU.Field.new(pos:'R3', title:'~CO ROUTE', tag:'CompanyRoute', selectable:1));
    
      route1.addAction(CDU.Action.new('ACTIVATE', 'R6', 
          func {
              cdu.setExecCallback(activateRoute);
          },
          func {
              var inactive = (getprop('autopilot/route-manager/active') == 0);
              var fp = flightplan();
              return inactive and (fp.departure != nil) and (fp.destination != nil);
          }));
        
      route1.addAction(CDU.Action.new('PERF INIT', 'R6', 
          func { cdu.displayPageByTag("performance") },
          func { 
              var act = (getprop('autopilot/route-manager/active') != 0);
              return act and (getprop('instrumentation/fmc/perf-complete') == 0); 
          }
      ));
    
      route1.addAction(CDU.Action.new('TAKEOFF', 'R6', 
          func { cdu.displayPageByTag("takeoff") },
          func {
              return getprop('instrumentation/fmc/perf-complete') and
                  (getprop('instrumentation/fmc/phase-index') < 2);
          }
      ));
    
      route1.addAction(CDU.Action.new('OFFSET', 'R6', 
          func { cdu.displayPageByTag("offset") },
          func {
              return getprop('instrumentation/fmc/perf-complete') and
                  (getprop('instrumentation/fmc/phase-index') >= 2);
          }
      ));
    
      #var route2 = CDU.Page.new(cdu, "      RTE 1");
     # route2.setModel(routeModel);
	 var route12 = CDU.MultiPage.new(cdu:cdu, title:"         RTE 1", model:RouteModel.new(), dynamicActions:1);
    # actions are shared from route1 page
     # foreach(var act; route1.getActions()) route2.addAction(act);
      
      route12.addField(CDU.ScrolledField.new(tag:'Via', selectable:1));
      route12.addField(CDU.ScrolledField.new(tag:'To', selectable:1, alignRight:1));
      
      CDU.linkPages([route1, route12]);
      cdu.addPage(route1, "route");
      cdu.addPage(route12, "route-1-2");
      
      
###############
  var takeoff = CDU.Page.new(cdu, '       TAKEOFF REF');
  takeoff.setModel(TakeoffModel.new());
  cdu.addPage(takeoff, "takeoff");
    
  takeoff.addField(CDU.Field.new(pos:'L1', title:'~FLAP/ACCEL HT', tag:'Flaps'));
  takeoff.addField(CDU.StaticField.new('L2', '~E/O ACCEL HT', '~1000FT'));
  takeoff.addField(CDU.Field.new(pos:'L3', title:'~THR REDUCTION', tag:'ThrReduction'));
  #takeoff.addField(CDU.StaticField.new('L4', '~WIND/SLOPE', '~H00/U0.0'));
  #takeoff.addField(CDU.Field.new(pos:'L2', tag:'TakeoffThrust'));
  takeoff.addField(CDU.Field.new(pos:'R4', title:'~CG', tag:'TakeoffCG'));
  takeoff.addField(CDU.Field.new(tag:'TakeoffTrim', title:'~TRIM', pos:'R4+5'));
    
  takeoff.addField(CDU.Field.new(pos:'R1', title:'~REF V1', tag:'V1'));
  takeoff.addField(CDU.Field.new(pos:'R2', title:'~REF VR', tag:'Vr'));
  takeoff.addField(CDU.Field.new(pos:'R3', title:'~REF V2', tag:'V2'));
    
  takeoff.addField(CDU.Field.new(tag:'Preflight', pos:'R6', rows:1, selectable:1));
         
  takeoff.fixedSeparator = [5, 5];
  takeoff.addAction(CDU.Action.new('INDEX', 'L6', func {cdu.displayPageByTag("index");}));