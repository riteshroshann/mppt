function ok = verify_install()

    fprintf("========================================================\n");
    fprintf("  Solar MPPT project: installation check\n");
    fprintf("========================================================\n\n");

    here = fileparts(mfilename("fullpath"));
    addpath(fullfile(here, "matlab"));
    startup_mpptlab();
    addpath(fullfile(here, "simulink"));

    checks = struct("name", {}, "pass", {}, "detail", {});
    checks = add(checks, "MATLAB release", true, string(version("-release")));

    needed = ["Control System Toolbox", "Simulink", "Simscape", "Optimization Toolbox"];
    v = ver;
    have = string({v.Name});
    for n = needed
        checks = add(checks, "toolbox: " + n, any(have == n), "");
    end

    try
        ds  = mpptlab.pv.datasheet("KC200GT");
        [ref, d] = mpptlab.pv.extractParams(ds);
        checks = add(checks, "PV parameter extraction", d.maxAbsErrorPct < 1e-6, ...
            sprintf("worst datasheet error %.2g %%", d.maxAbsErrorPct));
    catch e
        checks = add(checks, "PV parameter extraction", false, e.message);
        ref = [];
    end

    try
        cfg = mpptlab.util.config();
        [Vmp, Imp, Pmp] = cfg.pv.mpp();
        good = abs(Vmp - 157.8) < 1 && abs(Pmp - 2402) < 10;
        checks = add(checks, "array operating point", good, ...
            sprintf("%.1f V, %.2f A, %.0f W", Vmp, Imp, Pmp));
    catch e
        checks = add(checks, "array operating point", false, e.message);
    end

    try
        R = mpptlab.ctrl.loopAnalysis(cfg.boost, cfg.pv, cfg.gains, Glist = [200 1000]);
        checks = add(checks, "control loop analysis", R.worstPmV > 45, ...
            sprintf("worst outer phase margin %.1f deg", R.worstPmV));
    catch e
        checks = add(checks, "control loop analysis", false, e.message);
    end

    try
        prof = mpptlab.bench.irradiance("constant", G0 = 1000, Duration = 0.3);
        tr   = mpptlab.mppt.PandO(Ts = 20e-3, Step = 1.5);
        o    = mpptlab.bench.simulate(cfg.pv, cfg.boost, tr, cfg.gains, prof, ...
                   V0 = 150, RecordEvery = 40);
        checks = add(checks, "closed-loop simulation", o.metrics.etaMppt > 0.9, ...
            sprintf("eta = %.2f %%", 100 * o.metrics.etaMppt));
    catch e
        checks = add(checks, "closed-loop simulation", false, e.message);
    end

    try
        old = cd(fullfile(here, "simulink"));
        c = onCleanup(@() cd(old));
        if ~isfile("pvsrc_lib.slx")
            ssc_build("pvsrc");
        end
        checks = add(checks, "Simscape PV component", ...
            isfile("pvsrc_lib.slx"), "pvsrc_lib.slx built from pv_module.ssc");
        clear c
    catch e
        checks = add(checks, "Simscape PV component", false, e.message);
    end

    try
        setup_workspace("fixedduty", Open = false, Duration = 0.02);
        out = sim("mppt_boost_switched");
        checks = add(checks, "switched Simulink model", true, "simulated 0.02 s");
    catch e
        checks = add(checks, "switched Simulink model", false, e.message);
    end

    fprintf("\n");
    ok = true;
    for k = 1:numel(checks)
        mark = "FAIL";
        if checks(k).pass
            mark = " OK ";
        else
            ok = false;
        end
        fprintf("  [%s]  %-28s %s\n", mark, checks(k).name, checks(k).detail);
    end

    fprintf("\n--------------------------------------------------------\n");
    if ok
        fprintf("  Everything works. Next steps:\n");
        fprintf("    run_all                 the whole pipeline, about 11 min\n");
        fprintf("    runtests('matlab/tests') the 27 unit tests\n");
        fprintf('    setup_workspace(''step'')  open the Simulink model ready to run\n');
    else
        fprintf("  Some checks failed. See the messages above.\n");
    end
    fprintf("--------------------------------------------------------\n\n");

    if nargout == 0
        clear ok
    end
end

function c = add(c, name, pass, detail)
    c(end+1) = struct("name", string(name), "pass", logical(pass), ...
                      "detail", string(detail));
end
