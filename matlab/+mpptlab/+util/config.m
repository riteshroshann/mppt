function cfg = config(opts)

    arguments
        opts.Module (1,1) string = "KC200GT"
        opts.NsMod  (1,1) double = 6
        opts.NpStr  (1,1) double = 2
        opts.Vdc    (1,1) double = 400
        opts.fsw    (1,1) double = 20e3
        opts.L      (1,1) double = 1.5e-3
        opts.Cpv    (1,1) double = 100e-6
        opts.Co     (1,1) double = 470e-6
        opts.RL     (1,1) double = 0.15
        opts.fci    (1,1) double = 2000
        opts.fcv    (1,1) double = 250
    end

    cfg = struct();
    cfg.datasheet = mpptlab.pv.datasheet(opts.Module);
    [cfg.ref, cfg.fit] = mpptlab.pv.extractParams(cfg.datasheet);

    cfg.pv = mpptlab.pv.PVArray(cfg.ref, ...
        NsMod = opts.NsMod, NpStr = opts.NpStr, ...
        Name = sprintf("%ds%dp %s", opts.NsMod, opts.NpStr, cfg.datasheet.Name));

    cfg.boost = mpptlab.conv.Boost( ...
        L = opts.L, Cpv = opts.Cpv, Co = opts.Co, RL = opts.RL, ...
        Vdc = opts.Vdc, fsw = opts.fsw);

    cfg.gains = mpptlab.ctrl.designCascade(cfg.boost, cfg.pv, fci = opts.fci, fcv = opts.fcv);
    cfg.stc   = cfg.pv.operatingSummary();
    cfg.NsMod = opts.NsMod;
    cfg.NpStr = opts.NpStr;
end
