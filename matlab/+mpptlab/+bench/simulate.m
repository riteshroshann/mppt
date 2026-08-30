function out = simulate(pv, bc, tracker, K, prof, opts)

    arguments
        pv      (1,1) mpptlab.pv.PVArray
        bc      (1,1) mpptlab.conv.Boost
        tracker (1,1) mpptlab.mppt.Tracker
        K       struct
        prof    struct
        opts.Duration     (1,1) double = 0
        opts.PlantStep    (1,1) double = 0
        opts.RecordEvery  (1,1) double = 10
        opts.V0           (1,1) double = -1
        opts.ILmax        (1,1) double = 0
        opts.ScoreFrom    (1,1) double = 0
        opts.Verbose      (1,1) logical = false
    end

    tEnd = opts.Duration;
    if tEnd <= 0
        tEnd = prof.Duration;
    end

    h = opts.PlantStep;
    if h <= 0
        h = 1 / (2 * bc.fsw);
    end
    Tctrl  = 1 / bc.fsw;
    nCtrl  = max(round(Tctrl / h), 1);
    nMppt  = max(round(tracker.Ts / h), 1);
    nSteps = ceil(tEnd / h);

    ILmax = opts.ILmax;
    if ILmax <= 0
        pv.G = 1000; pv.Tc = prof.T(0);
        ILmax = 1.5 * pv.isc();
    end

    Ci = mpptlab.ctrl.PI(Kp = K.KpI, Ki = K.KiI, Ts = Tctrl, ...
        uMin = bc.dMin, uMax = bc.dMax, Name = "current");
    Cv = mpptlab.ctrl.PI(Kp = K.KpV, Ki = K.KiV, Ts = Tctrl, ...
        uMin = 0, uMax = ILmax, Name = "voltage");

    [PmppOf, VmppOf] = buildReference(pv, prof, tEnd);

    G0 = prof.G(0);
    T0 = prof.T(0);
    pv.G = G0; pv.Tc = T0;
    V0 = opts.V0;
    if V0 <= 0
        V0 = VmppOf(G0);
    end

    x = [V0; pv.current(V0)];
    tracker.reset(V0);
    Vref = tracker.Vref;
    Cv.reset(x(2), x(1) - Vref);
    Ci.reset(bc.dutyFor(pv, x(1)), 0);
    d     = Ci.LastOutput;
    iLref = Cv.LastOutput;

    nRec = floor(nSteps / opts.RecordEvery) + 1;
    rec  = struct( ...
        "t",    zeros(nRec, 1), "vpv",  zeros(nRec, 1), "iL", zeros(nRec, 1), ...
        "ipv",  zeros(nRec, 1), "ppv",  zeros(nRec, 1), "vref", zeros(nRec, 1), ...
        "duty", zeros(nRec, 1), "G",    zeros(nRec, 1), "Pmpp", zeros(nRec, 1), ...
        "Vmpp", zeros(nRec, 1), "iLref", zeros(nRec, 1));
    kRec = 0;

    ipvGuess = x(2);
    tic
    for n = 0:nSteps - 1
        t = n * h;
        G = prof.G(t);
        T = prof.T(t);
        pv.G = G; pv.Tc = T;
        p = pv.params();

        if mod(n, nCtrl) == 0
            iLref = Cv.step(x(1) - Vref);
            d     = Ci.step(iLref - x(2));
        end

        if mod(n, nMppt) == 0
            ipvNow = pv.current(x(1), p, ipvGuess);
            Vref   = tracker.update(x(1), ipvNow, t);
        end

        if mod(n, opts.RecordEvery) == 0
            kRec = kRec + 1;
            ipvNow = pv.current(x(1), p, ipvGuess);
            rec.t(kRec)     = t;
            rec.vpv(kRec)   = x(1);
            rec.iL(kRec)    = x(2);
            rec.ipv(kRec)   = ipvNow;
            rec.ppv(kRec)   = x(1) * ipvNow;
            rec.vref(kRec)  = Vref;
            rec.duty(kRec)  = d;
            rec.G(kRec)     = G;
            rec.Pmpp(kRec)  = PmppOf(G);
            rec.Vmpp(kRec)  = VmppOf(G);
            rec.iLref(kRec) = iLref;
        end

        [k1, i1] = bc.derivatives(x,             d, pv, p, ipvGuess);
        k2 = bc.derivatives(x + 0.5 * h * k1,    d, pv, p, i1);
        k3 = bc.derivatives(x + 0.5 * h * k2,    d, pv, p, i1);
        k4 = bc.derivatives(x + h * k3,          d, pv, p, i1);
        x  = x + (h / 6) * (k1 + 2 * k2 + 2 * k3 + k4);
        x(1) = max(x(1), 0.1);
        ipvGuess = i1;
    end
    wall = toc;

    f = fieldnames(rec);
    for j = 1:numel(f)
        rec.(f{j}) = rec.(f{j})(1:kRec);
    end

    out = rec;
    out.Tracker  = tracker.Name;
    out.Profile  = prof.Name;
    out.WallTime = wall;
    out.PlantStep = h;
    out.metrics  = scoreRun(rec, opts.ScoreFrom);

    if opts.Verbose
        fprintf("%-12s %-40s eta = %6.3f %%  (%.1f s wall)\n", ...
            tracker.Name, prof.Name, 100 * out.metrics.etaMppt, wall);
    end
end

function [PmppOf, VmppOf] = buildReference(pv, prof, tEnd)
    tg = linspace(0, tEnd, 2000);
    Gs = arrayfun(@(t) prof.G(t), tg);
    Ts = arrayfun(@(t) prof.T(t), tg);

    if max(Ts) - min(Ts) > 1e-9
        error("mpptlab:bench:varyingTemperature", ...
            "simulate currently supports a constant cell temperature profile.");
    end

    Ggrid = linspace(max(min(Gs) - 20, 1), max(Gs) + 20, 240);
    Pg = zeros(size(Ggrid));
    Vg = zeros(size(Ggrid));

    G0 = pv.G; T0 = pv.Tc;
    pv.Tc = Ts(1);
    for k = 1:numel(Ggrid)
        pv.G = Ggrid(k);
        [Vg(k), ~, Pg(k)] = pv.mpp();
    end
    pv.G = G0; pv.Tc = T0;

    PmppOf = @(G) interp1(Ggrid, Pg, min(max(G, Ggrid(1)), Ggrid(end)), "pchip");
    VmppOf = @(G) interp1(Ggrid, Vg, min(max(G, Ggrid(1)), Ggrid(end)), "pchip");
end

function m = scoreRun(rec, tFrom)
    keep = rec.t >= tFrom;
    t  = rec.t(keep);
    P  = rec.ppv(keep);
    Pm = rec.Pmpp(keep);

    Eharvest = trapz(t, P);
    Eideal   = trapz(t, Pm);

    m = struct();
    m.etaMppt   = Eharvest / Eideal;
    m.Eharvest  = Eharvest;
    m.Eideal    = Eideal;
    m.window    = [t(1) t(end)];
    m.meanPower = Eharvest / (t(end) - t(1));
    m.rmsTrackErrorV = sqrt(mean((rec.vpv(keep) - rec.Vmpp(keep)).^2));
    m.maxPowerDeficit = max(Pm - P);
end
