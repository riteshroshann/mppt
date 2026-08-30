function summary = run_all(opts)

    arguments
        opts.SkipBenchmark (1,1) logical = false
        opts.SkipSwitched  (1,1) logical = false
        opts.SkipTests     (1,1) logical = false
    end

    here = fileparts(mfilename("fullpath"));
    root = fileparts(here);
    addpath(here);
    startup_mpptlab();

    stages = struct("name", {}, "status", {}, "seconds", {});
    tAll = tic;

    stages = runStage(stages, "s01 PV characterisation",  @() evalin("base", "s01_pv_characterisation"));
    stages = runStage(stages, "s02 plant analysis",       @() evalin("base", "s02_plant_analysis"));
    stages = runStage(stages, "s03 control design",       @() evalin("base", "s03_control_design"));
    stages = runStage(stages, "s04 MPPT comparison",      @() evalin("base", "s04_mppt_comparison"));

    if ~opts.SkipBenchmark
        stages = runStage(stages, "s05 dynamic benchmark", @() evalin("base", "s05_dynamic_benchmark"));
    end

    if ~opts.SkipSwitched
        addpath(fullfile(root, "simulink"));
        stages = runStage(stages, "s06 switched validation", @() evalin("base", "run_switched_validation"));
        stages = runStage(stages, "s07 model diagram", @() export_model_diagram());
    end

    nPass = NaN; nTest = NaN;
    if ~opts.SkipTests
        t0 = tic;
        try
            r = runtests(fullfile(here, "tests"));
            nPass = sum([r.Passed]);
            nTest = numel(r);
            st = "PASS";
            if nPass < nTest
                st = "FAIL";
            end
        catch err
            st = "ERROR: " + string(err.message);
        end
        stages(end+1) = struct("name", "unit tests", "status", st, "seconds", toc(t0));
    end

    summary = struct();
    summary.stages = struct2table(stages);
    summary.totalSeconds = toc(tAll);
    summary.testsPassed = nPass;
    summary.testsTotal  = nTest;

    fprintf("\n================ run_all summary ================\n");
    disp(summary.stages);
    if ~isnan(nTest)
        fprintf("unit tests: %d / %d passed\n", nPass, nTest);
    end
    fprintf("total wall time: %.1f s\n", summary.totalSeconds);
    fprintf("figures in %s\n", fullfile(root, "results", "figures"));
end

function stages = runStage(stages, name, fn)
    fprintf("\n>>> %s\n", name);
    t0 = tic;
    try
        fn();
        st = "OK";
    catch err
        st = "ERROR: " + string(err.message);
        fprintf("!!! %s failed: %s\n", name, err.message);
    end
    stages(end+1) = struct("name", name, "status", st, "seconds", toc(t0));
end
