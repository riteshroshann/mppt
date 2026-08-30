function [Kp, Ki, info] = designSingleLoopPI(bc, pv, opts)

    arguments
        bc (1,1) mpptlab.conv.Boost
        pv (1,1) mpptlab.pv.PVArray
        opts.fc        (1,1) double = 130
        opts.ZeroRatio (1,1) double = 5
        opts.V         (1,1) double = -1
    end

    p = pv.params();
    V = opts.V;
    if V <= 0
        V = pv.mpp(p);
    end

    sys = bc.linearize(pv, V, p);
    Gp  = -tf(sys(1));

    wc = 2 * pi * opts.fc;
    wi = wc / opts.ZeroRatio;

    [m, ph] = bode(Gp, wc);
    m  = squeeze(m);
    ph = squeeze(ph);

    Kp = 1 / (m * sqrt(1 + (wi / wc)^2));
    Ki = Kp * wi;

    s = tf("s");
    L = (Kp + Ki / s) * Gp;
    am = allmargin(L);

    info = struct( ...
        "fc",           opts.fc, ...
        "V",            V, ...
        "plantMag",     m, ...
        "plantPhase",   ph, ...
        "zeroHz",       wi / (2 * pi), ...
        "achievedPM",   minOrNan(am.PhaseMargin), ...
        "crossovers",   numel(am.PMFrequency), ...
        "crossoverHz",  am.PMFrequency / (2 * pi), ...
        "stable",       am.Stable);
end

function v = minOrNan(x)
    if isempty(x)
        v = NaN;
    else
        v = min(x);
    end
end
