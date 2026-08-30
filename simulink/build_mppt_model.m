function mdl = build_mppt_model(opts)

    arguments
        opts.Name (1,1) string = "mppt_boost_switched"
        opts.Save (1,1) logical = true
        opts.Open (1,1) logical = false
    end

    here = fileparts(mfilename('fullpath'));
    if ~isfile(fullfile(here, 'pvsrc_lib.slx'))
        old = cd(here);
        cleanup = onCleanup(@() cd(old));
        ssc_build('pvsrc');
        clear cleanup
    end
    load_system(fullfile(here, 'pvsrc_lib.slx'));

    mdl = char(opts.Name);
    if bdIsLoaded(mdl)
        close_system(mdl, 0);
    end
    new_system(mdl);
    load_system(mdl);

    P = @(x, y, w, h) [x y x+w y+h];
    fails = strings(0, 1);

    add(mdl, 'pvsrc_lib/pv_module',                                        'PV array',  P(300, 280, 90, 90));
    add(mdl, 'fl_lib/Electrical/Electrical Sensors/Current Sensor',        'Ipv sense', P(440, 280, 60, 60));
    add(mdl, 'fl_lib/Electrical/Electrical Elements/Capacitor',            'Cpv',       P(560, 300, 40, 60));
    add(mdl, 'fl_lib/Electrical/Electrical Sensors/Voltage Sensor',        'Vpv sense', P(560, 180, 60, 60));
    add(mdl, 'fl_lib/Electrical/Electrical Elements/Inductor',             'L',         P(670, 190, 60, 40));
    add(mdl, 'fl_lib/Electrical/Electrical Elements/Resistor',             'RL',        P(760, 190, 60, 40));
    add(mdl, 'fl_lib/Electrical/Electrical Sensors/Current Sensor',        'IL sense',  P(850, 190, 60, 60));
    add(mdl, 'fl_lib/Electrical/Electrical Elements/Switch',               'MOSFET',    P(950, 300, 60, 60));
    add(mdl, 'fl_lib/Electrical/Electrical Elements/Diode',                'D',         P(1050, 190, 60, 40));
    add(mdl, 'fl_lib/Electrical/Electrical Elements/Capacitor',            'Co',        P(1150, 300, 40, 60));
    add(mdl, 'fl_lib/Electrical/Electrical Sources/DC Voltage Source',     'Vbus',      P(1250, 300, 40, 60));
    add(mdl, 'fl_lib/Electrical/Electrical Elements/Electrical Reference', 'GND',       P(840, 470, 40, 30));
    add(mdl, 'nesl_utility/Solver Configuration',                          'Solver',    P(620, 470, 70, 40));

    add(mdl, 'nesl_utility/Simulink-PS Converter', 'G2ps',    P(190, 300, 50, 40));
    add(mdl, 'nesl_utility/Simulink-PS Converter', 'T2ps',    P(190, 360, 50, 40));
    add(mdl, 'nesl_utility/PS-Simulink Converter', 'ipv2sl',  P(440, 120, 50, 40));
    add(mdl, 'nesl_utility/PS-Simulink Converter', 'vpv2sl',  P(660, 100, 50, 40));
    add(mdl, 'nesl_utility/PS-Simulink Converter', 'iL2sl',   P(950, 100, 50, 40));
    add(mdl, 'nesl_utility/Simulink-PS Converter', 'gate2ps', P(850, 620, 50, 40));

    add(mdl, 'simulink/Sources/From Workspace', 'Irradiance', P(50, 295, 90, 40));
    add(mdl, 'simulink/Sources/Constant',       'Tcell',      P(50, 365, 90, 30));

    add(mdl, 'simulink/Sources/Constant', 'Gains',      P(200, 600, 90, 30));
    add(mdl, 'simulink/Sources/Constant', 'Mode',       P(200, 650, 90, 30));
    add(mdl, 'simulink/Sources/Constant', 'Fixed duty', P(200, 700, 90, 30));
    add(mdl, 'simulink/User-Defined Functions/MATLAB Function', 'Controller', P(380, 560, 120, 180));

    add(mdl, 'simulink/Discrete/Unit Delay', 'Duty delay', P(510, 625, 50, 40));
    add(mdl, 'simulink/Sources/Repeating Sequence', 'Carrier', P(380, 790, 90, 40));
    add(mdl, 'simulink/Logic and Bit Operations/Relational Operator', 'PWM', P(580, 620, 50, 50));
    add(mdl, 'simulink/Signal Attributes/Data Type Conversion', 'to double', P(700, 630, 60, 30));

    add(mdl, 'simulink/Sinks/To Workspace', 'log vpv',  P(780, 60, 70, 30));
    add(mdl, 'simulink/Sinks/To Workspace', 'log iL',   P(1070, 60, 70, 30));
    add(mdl, 'simulink/Sinks/To Workspace', 'log ipv',  P(560, 120, 70, 30));
    add(mdl, 'simulink/Sinks/To Workspace', 'log duty', P(580, 540, 70, 30));
    add(mdl, 'simulink/Sinks/To Workspace', 'log vref', P(580, 490, 70, 30));
    add(mdl, 'simulink/Sinks/To Workspace', 'log G',    P(200, 200, 70, 30));

    fails = [fails; softSet([mdl '/PV array'], {'IphRef','IphRef','I0Ref','I0Ref', ...
        'RsRef','RsRef','RshRef','RshRef','aRef','aRef','alphaIsc','alphaIscPV', ...
        'EgRef','EgRef','NsMod','NsMod','NpStr','NpStr'})];
    fails = [fails; softSet([mdl '/Cpv'],    {'c', 'Cpv'})];
    fails = [fails; softSet([mdl '/Co'],     {'c', 'Co'})];
    fails = [fails; softSet([mdl '/L'],      {'l', 'Lboost'})];
    fails = [fails; softSet([mdl '/RL'],     {'R', 'RL'})];
    fails = [fails; softSet([mdl '/Vbus'],   {'v0', 'Vdc'})];
    fails = [fails; softSet([mdl '/MOSFET'], {'R_closed','Rds_on','G_open','G_off','Threshold','0.5'})];
    fails = [fails; softSet([mdl '/D'],      {'Vf','Vf_diode','Ron','Ron_diode'})];

    fails = [fails; softSet([mdl '/G2ps'],   {'unit', 'W/m^2'})];
    fails = [fails; softSet([mdl '/T2ps'],   {'unit', 'K'})];
    fails = [fails; softSet([mdl '/gate2ps'],{'unit', '1'})];
    fails = [fails; softSet([mdl '/vpv2sl'], {'unit', 'V'})];
    fails = [fails; softSet([mdl '/ipv2sl'], {'unit', 'A'})];
    fails = [fails; softSet([mdl '/iL2sl'],  {'unit', 'A'})];

    set_param([mdl '/Irradiance'], 'VariableName', 'Gts', 'Interpolate', 'on', ...
        'OutputAfterFinalValue', 'Holding final value');
    set_param([mdl '/Tcell'],      'Value', 'Tcell');
    set_param([mdl '/Gains'],      'Value', 'kvec');
    set_param([mdl '/Mode'],       'Value', 'ctrlMode');
    set_param([mdl '/Fixed duty'], 'Value', 'dFixed');

    set_param([mdl '/Carrier'], 'rep_seq_t', '[0 Tsw]', 'rep_seq_y', '[0 1]');
    set_param([mdl '/PWM'], 'Operator', '<');
    set_param([mdl '/to double'], 'OutDataTypeStr', 'double');

    logs = {'log vpv','vpv'; 'log iL','iL'; 'log ipv','ipv'; ...
            'log duty','duty'; 'log vref','vref'; 'log G','Girr'};
    for k = 1:size(logs, 1)
        set_param([mdl '/' logs{k,1}], 'VariableName', logs{k,2}, ...
            'SaveFormat', 'Structure With Time', 'MaxDataPoints', 'inf', 'Decimation', '1');
    end

    setChartCode(mdl, 'Controller', controllerCode());
    setChartDiscrete(mdl, 'Controller', 'Tctrl');
    fails = [fails; softSet([mdl '/Duty delay'], {'SampleTime', 'Tctrl', 'InitialCondition', 'dFixed'})];

    wire(mdl, 'PV array/LConn1',  'Ipv sense/LConn1');
    wire(mdl, 'Ipv sense/RConn2', 'Cpv/LConn1');
    wire(mdl, 'PV array/RConn1',  'GND/LConn1');
    wire(mdl, 'Cpv/RConn1',       'GND/LConn1');
    wire(mdl, 'Vpv sense/LConn1', 'Cpv/LConn1');
    wire(mdl, 'Vpv sense/RConn2', 'GND/LConn1');
    wire(mdl, 'L/LConn1',         'Cpv/LConn1');
    wire(mdl, 'L/RConn1',         'RL/LConn1');
    wire(mdl, 'RL/RConn1',        'IL sense/LConn1');
    wire(mdl, 'IL sense/RConn2',  'MOSFET/LConn1');
    wire(mdl, 'MOSFET/RConn2',    'GND/LConn1');
    wire(mdl, 'D/LConn1',         'MOSFET/LConn1');
    wire(mdl, 'D/RConn1',         'Co/LConn1');
    wire(mdl, 'Co/RConn1',        'GND/LConn1');
    wire(mdl, 'Vbus/LConn1',      'Co/LConn1');
    wire(mdl, 'Vbus/RConn1',      'GND/LConn1');
    wire(mdl, 'Solver/RConn1',    'GND/LConn1');

    wire(mdl, 'G2ps/RConn1',      'PV array/LConn2');
    wire(mdl, 'T2ps/RConn1',      'PV array/LConn3');
    wire(mdl, 'Ipv sense/RConn1', 'ipv2sl/LConn1');
    wire(mdl, 'Vpv sense/RConn1', 'vpv2sl/LConn1');
    wire(mdl, 'IL sense/RConn1',  'iL2sl/LConn1');
    wire(mdl, 'gate2ps/RConn1',   'MOSFET/RConn1');

    wire(mdl, 'Irradiance/1', 'G2ps/1');
    wire(mdl, 'Irradiance/1', 'log G/1');
    wire(mdl, 'Tcell/1',      'T2ps/1');

    wire(mdl, 'vpv2sl/1', 'Controller/1');
    wire(mdl, 'ipv2sl/1', 'Controller/2');
    wire(mdl, 'iL2sl/1',  'Controller/3');
    wire(mdl, 'Gains/1',      'Controller/4');
    wire(mdl, 'Mode/1',       'Controller/5');
    wire(mdl, 'Fixed duty/1', 'Controller/6');

    wire(mdl, 'Carrier/1',      'PWM/1');
    wire(mdl, 'Controller/1',   'Duty delay/1');
    wire(mdl, 'Duty delay/1',   'PWM/2');
    wire(mdl, 'PWM/1',        'to double/1');
    wire(mdl, 'to double/1',  'gate2ps/1');

    wire(mdl, 'vpv2sl/1',     'log vpv/1');
    wire(mdl, 'iL2sl/1',      'log iL/1');
    wire(mdl, 'ipv2sl/1',     'log ipv/1');
    wire(mdl, 'Controller/1', 'log duty/1');
    wire(mdl, 'Controller/2', 'log vref/1');

    set_param(mdl, 'SolverType', 'Variable-step', 'Solver', 'ode23t', ...
        'RelTol', '1e-4', 'AbsTol', '1e-6', 'MaxStep', 'Tsw/20', ...
        'StopTime', 'Tstop', 'SaveOutput', 'off', 'SaveTime', 'off');

    if opts.Save
        save_system(mdl, fullfile(here, [mdl '.slx']));
    end
    if opts.Open
        open_system(mdl);
    end

    if ~isempty(fails)
        fprintf('Parameters that could not be set (defaults retained):\n');
        fprintf('  %s\n', fails);
    end
end

function add(mdl, src, name, pos)
    add_block(src, [mdl '/' name], 'Position', pos);
end

function wire(mdl, a, b)
    add_line(mdl, a, b, 'autorouting', 'on');
end

function bad = softSet(blk, pairs)
    bad = strings(0, 1);
    for k = 1:2:numel(pairs)
        try
            set_param(blk, pairs{k}, pairs{k+1});
        catch
            bad(end+1) = string(blk) + " : " + string(pairs{k}); %#ok<AGROW>
        end
    end
end

function setChartDiscrete(mdl, blockName, ts)
    rt = sfroot;
    ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [mdl '/' blockName]);
    try
        ch.ChartUpdate = 'DISCRETE';
        ch.SampleTime  = ts;
    catch
        fprintf('Could not force discrete sample time on %s\n', blockName);
    end
end

function setChartCode(mdl, blockName, code)
    rt = sfroot;
    ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [mdl '/' blockName]);
    ch.Script = code;
end

function c = controllerCode()
    c = [ ...
"function [duty, vref, iref] = controller(vpv, ipv, iL, k, mode, dFixed)"
"%#codegen"
"persistent xi xv Vref cnt Pprev dirn ready"
"KpI = k(1); KiI = k(2); KpV = k(3); KiV = k(4); Ts = k(5);"
"dMin = k(6); dMax = k(7); ILmax = k(8); nM = k(9); step = k(10);"
"V0 = k(11); Vlo = k(12); Vhi = k(13);"
"if isempty(ready)"
"    ready = true; xi = k(14); xv = k(15); Vref = V0; cnt = 0; Pprev = -1; dirn = 1;"
"end"
"if mode > 0.5"
"    cnt = cnt + 1;"
"    if cnt >= nM"
"        cnt = 0;"
"        Pnow = vpv * ipv;"
"        if Pprev >= 0 && Pnow < Pprev"
"            dirn = -dirn;"
"        end"
"        Vref = Vref + dirn * step;"
"        Pprev = Pnow;"
"    end"
"end"
"if Vref < Vlo, Vref = Vlo; end"
"if Vref > Vhi, Vref = Vhi; end"
"ev = vpv - Vref;"
"rawI = KpV*ev + xv;"
"iref = min(max(rawI, 0), ILmax);"
"xv = xv + Ts*(KiV*ev + (KiV/KpV)*(iref - rawI));"
"ei = iref - iL;"
"rawD = KpI*ei + xi;"
"duty = min(max(rawD, dMin), dMax);"
"xi = xi + Ts*(KiI*ei + (KiI/KpI)*(duty - rawD));"
"if mode < -0.5"
"    duty = dFixed;"
"end"
"vref = Vref;"];
    c = char(join(c, newline));
end
