function setup_workspace(scenario, opts)

    arguments
        scenario (1,1) string = "step"
        opts.Open (1,1) logical = true
        opts.Duration (1,1) double = 0
    end

    here = fileparts(mfilename("fullpath"));
    addpath(fullfile(fileparts(here), "matlab"));
    startup_mpptlab();
    addpath(here);

    cfg = mpptlab.util.config();
    pv  = cfg.pv;
    bc  = cfg.boost;
    K   = cfg.gains;

    v = struct();
    v.Cpv = bc.Cpv;      v.Co = bc.Co;       v.Lboost = bc.L;
    v.RL  = bc.RL;       v.Vdc = bc.Vdc;
    v.Tsw = 1 / bc.fsw;  v.Tctrl = v.Tsw;
    v.Rds_on = 5e-3;     v.G_off = 1e-8;
    v.Vf_diode = 0.7;    v.Ron_diode = 10e-3;
    v.Tcell = 298.15;

    v.IphRef = cfg.ref.IphRef;  v.I0Ref = cfg.ref.I0Ref;
    v.RsRef  = cfg.ref.RsRef;   v.RshRef = cfg.ref.RshRef;
    v.aRef   = cfg.ref.aRef;    v.alphaIscPV = cfg.ref.alphaIsc;
    v.EgRef  = cfg.ref.EgRef;
    v.NsMod  = cfg.NsMod;       v.NpStr = cfg.NpStr;

    pv.G = 1000; pv.Tc = v.Tcell;
    p = pv.params();
    [Vmp, Imp, Pmp] = pv.mpp(p);
    op = bc.operatingPoint(pv, Vmp, p);

    v.kvec = [K.KpI; K.KiI; K.KpV; K.KiV; v.Tctrl; bc.dMin; bc.dMax; 40; ...
              round(20e-3 / v.Tctrl); 1.5; Vmp; 20; 250; op.D; Imp];

    switch lower(scenario)
        case "step"
            v.ctrlMode = 1;  v.dFixed = op.D;
            v.Tstop = pick(opts.Duration, 1.2);
            v.Gts = timeseries([1000; 1000; 500; 500], ...
                               [0; 0.5; 0.5001; v.Tstop]);
            note = "closed loop, P&O, 1000 -> 500 W/m^2 step at 0.5 s";

        case "ramp"
            v.ctrlMode = 1;  v.dFixed = op.D;
            v.Tstop = pick(opts.Duration, 8.0);
            v.Gts = timeseries([300; 300; 1000; 1000; 300], ...
                               [0; 1; 4; 5; v.Tstop]);
            note = "closed loop, P&O, trapezoidal 300 <-> 1000 W/m^2 ramp";

        case "fixedduty"
            v.ctrlMode = -1; v.dFixed = op.D;
            v.Tstop = pick(opts.Duration, 0.10);
            v.Gts = timeseries([1000; 1000], [0; v.Tstop]);
            note = "open loop at fixed duty, for ripple and averaging check";

        case "constant"
            v.ctrlMode = 1;  v.dFixed = op.D;
            v.Tstop = pick(opts.Duration, 1.5);
            v.Gts = timeseries([1000; 1000], [0; v.Tstop]);
            note = "closed loop, P&O, constant 1000 W/m^2";

        otherwise
            error("mpptlab:setup:badScenario", ...
                "Scenario must be step, ramp, fixedduty or constant.");
    end

    f = fieldnames(v);
    for k = 1:numel(f)
        assignin("base", f{k}, v.(f{k}));
    end

    mdl = "mppt_boost_switched";
    slx = fullfile(here, mdl + ".slx");
    if ~isfile(slx)
        fprintf("Model not found, building it from build_mppt_model.m ...\n");
        build_mppt_model(Save = true);
    end

    fprintf("\n=== Simulink workspace ready ===\n");
    fprintf("scenario   : %s\n", scenario);
    fprintf("             %s\n", note);
    fprintf("stop time  : %.3f s\n", v.Tstop);
    fprintf("array MPP  : %.1f V, %.2f A, %.0f W at 1000 W/m^2\n", Vmp, Imp, Pmp);
    fprintf("duty at MPP: %.4f\n", op.D);
    fprintf("%d variables placed in the base workspace.\n", numel(f));
    fprintf("\nPress the green Run button, or type:  sim('%s')\n", mdl);
    fprintf("Then plot the result with:            plot_last_run\n\n");

    if opts.Open
        open_system(char(mdl));
    end
end

function y = pick(requested, fallback)
    if requested > 0
        y = requested;
    else
        y = fallback;
    end
end
