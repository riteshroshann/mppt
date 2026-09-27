function files = export_model_diagram(opts)

    arguments
        opts.Name (1,1) string = "mppt_boost_switched"
        opts.Rebuild (1,1) logical = false
    end

    here = fileparts(mfilename("fullpath"));
    addpath(fullfile(fileparts(here), "matlab"));
    startup_mpptlab();
    addpath(here);

    mdl = char(opts.Name);
    slx = fullfile(here, [mdl '.slx']);
    if opts.Rebuild || exist(slx, "file") ~= 2
        build_mppt_model(Name = opts.Name, Save = true);
    elseif ~bdIsLoaded(mdl)
        load_system(slx);
    end

    root = mpptlab.util.projectRoot();
    dest = fullfile(root, "results", "figures");
    if ~isfolder(dest)
        mkdir(dest);
    end

    files = strings(0, 1);
    for ext = ["png" "pdf"]
        target = fullfile(dest, "s07_simulink_model." + ext);
        print(['-s' mdl], "-d" + ext, "-r200", target);
        files(end+1) = target;
    end

    fprintf("Exported block diagram of %s to:\n", mdl);
    fprintf("  %s\n", files);
end
