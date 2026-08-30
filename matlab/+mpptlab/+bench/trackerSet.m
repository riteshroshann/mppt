function set = trackerSet(names, opts)

    arguments
        names (1,:) string = ["P&O" "P&O adaptive" "IncCond" "ESC"]
        opts.Tmppt (1,1) double = 20e-3
        opts.Step  (1,1) double = 1.5
        opts.EscTs (1,1) double = 2e-4
        opts.EscGain (1,1) double = 20
        opts.EscAmplitude (1,1) double = 3.0
        opts.EscDitherHz (1,1) double = 25
    end

    set = cell(1, numel(names));
    for k = 1:numel(names)
        switch names(k)
            case "P&O"
                set{k} = mpptlab.mppt.PandO(Ts = opts.Tmppt, Step = opts.Step, Name = "P&O");
            case "P&O adaptive"
                set{k} = mpptlab.mppt.PandO(Ts = opts.Tmppt, Adaptive = true, ...
                    StepMin = 0.25, StepMax = 6, AdaptGain = 0.06, Name = "P&O adaptive");
            case "IncCond"
                set{k} = mpptlab.mppt.IncCond(Ts = opts.Tmppt, Step = opts.Step, ...
                    Tol = 2e-3, Name = "IncCond");
            case "IncCond adaptive"
                set{k} = mpptlab.mppt.IncCond(Ts = opts.Tmppt, Adaptive = true, ...
                    StepMin = 0.25, StepMax = 6, AdaptGain = 0.06, Tol = 2e-3, ...
                    Name = "IncCond adaptive");
            case "ESC"
                set{k} = mpptlab.mppt.ESC(Ts = opts.EscTs, Gain = opts.EscGain, ...
                    Amplitude = opts.EscAmplitude, DitherHz = opts.EscDitherHz, ...
                    WashoutHz = 5, LowpassHz = 5, Name = "ESC");
            otherwise
                error("mpptlab:bench:unknownTracker", "Unknown tracker '%s'.", names(k));
        end
    end
end
