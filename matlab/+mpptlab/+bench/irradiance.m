function prof = irradiance(kind, opts)

    arguments
        kind (1,1) string
        opts.G0        (1,1) double = 1000
        opts.G1        (1,1) double = 500
        opts.Glow      (1,1) double = 300
        opts.Ghigh     (1,1) double = 1000
        opts.StepTime  (1,1) double = 0.5
        opts.Slope     (1,1) double = 100
        opts.Dwell     (1,1) double = 2.0
        opts.Cycles    (1,1) double = 2
        opts.Settle    (1,1) double = 1.0
        opts.TcC       (1,1) double = 25
        opts.Duration  (1,1) double = 0
    end

    TcK = 273.15 + opts.TcC;
    Tfun = @(t) TcK * ones(size(t));

    switch lower(kind)
        case "constant"
            prof = pack("constant G = " + opts.G0, ...
                @(t) opts.G0 * ones(size(t)), Tfun, ...
                pickDuration(opts.Duration, 2));

        case "step"
            dur = pickDuration(opts.Duration, opts.StepTime + 2);
            prof = pack(sprintf("step %g -> %g W/m^2", opts.G0, opts.G1), ...
                @(t) opts.G0 + (opts.G1 - opts.G0) * (t >= opts.StepTime), ...
                Tfun, dur);

        case "ramp"
            tR  = abs(opts.G1 - opts.G0) / opts.Slope;
            dur = pickDuration(opts.Duration, opts.StepTime + tR + 2);
            prof = pack(sprintf("ramp %g -> %g at %g W/m^2/s", ...
                opts.G0, opts.G1, opts.Slope), ...
                @(t) rampFun(t, opts.G0, opts.G1, opts.StepTime, tR), Tfun, dur);

        case {"trapezoid", "en50530"}
            tR  = abs(opts.Ghigh - opts.Glow) / opts.Slope;
            per = 2 * (tR + opts.Dwell);
            dur = pickDuration(opts.Duration, opts.Settle + opts.Cycles * per);
            prof = pack(sprintf("EN50530-style %g<->%g at %g W/m^2/s", ...
                opts.Glow, opts.Ghigh, opts.Slope), ...
                @(t) trapFun(t, opts.Glow, opts.Ghigh, tR, opts.Dwell, opts.Settle), ...
                Tfun, dur);
            prof.RampTime = tR;
            prof.Period   = per;

        otherwise
            error("mpptlab:bench:unknownProfile", ...
                "Unknown profile '%s'. Use constant, step, ramp, or trapezoid.", kind);
    end

    prof.Slope  = opts.Slope;
    prof.TcC    = opts.TcC;
    prof.Settle = opts.Settle;
end

function p = pack(name, G, T, dur)
    p = struct("Name", string(name), "G", G, "T", T, "Duration", dur);
end

function d = pickDuration(requested, fallback)
    if requested > 0
        d = requested;
    else
        d = fallback;
    end
end

function G = rampFun(t, G0, G1, t0, tR)
    x = (t - t0) / max(tR, eps);
    x = min(max(x, 0), 1);
    G = G0 + (G1 - G0) .* x;
end

function G = trapFun(t, Glow, Ghigh, tR, dwell, settle)
    per = 2 * (tR + dwell);
    tau = mod(max(t - settle, 0), per);

    G = zeros(size(t));
    up   = tau < tR;
    hi   = tau >= tR & tau < tR + dwell;
    down = tau >= tR + dwell & tau < 2 * tR + dwell;
    lo   = tau >= 2 * tR + dwell;

    G(up)   = Glow + (Ghigh - Glow) .* (tau(up) / tR);
    G(hi)   = Ghigh;
    G(down) = Ghigh - (Ghigh - Glow) .* ((tau(down) - tR - dwell) / tR);
    G(lo)   = Glow;

    G(t < settle) = Glow;
end
