function [ref, diag] = extractParams(ds, opts)

    arguments
        ds struct
        opts.EgRef      (1,1) double = 1.121
        opts.nSeeds     (1,:) double = [1.0 1.2 1.5 1.8 0.8 2.0]
        opts.Display    (1,1) string = "off"
        opts.Tolerance  (1,1) double = 1e-10
    end

    Tr  = mpptlab.pv.PVArray.Tref;
    kB  = mpptlab.pv.PVArray.kB;
    qe  = mpptlab.pv.PVArray.qe;

    Voc = ds.Voc;  Isc = ds.Isc;
    Vmp = ds.Vmp;  Imp = ds.Imp;
    Ns  = ds.Ns;
    aOf = @(n) n * Ns * kB * Tr / qe;

    scale = [Isc Isc Isc Isc abs(ds.betaVoc)];

    best = struct("resnorm", inf);
    for n0 = opts.nSeeds
        a0    = aOf(n0);
        Iph0  = Isc;
        I00   = Isc / expm1(Voc / a0);
        Rs0   = 0.05 * Voc / Isc;
        Rsh0  = 100  * Voc / Isc;
        x0    = [Iph0; log(I00); log(Rs0); log(Rsh0); n0];

        [x, resnorm, ok] = solveSystem(@residuals, x0, opts);
        if ok && resnorm < best.resnorm
            best = struct("x", x, "resnorm", resnorm, "seed", n0);
        end
    end

    if ~isfinite(best.resnorm)
        error("mpptlab:pv:extractionFailed", ...
            "Five-parameter extraction did not converge for module '%s'.", ds.Name);
    end

    [Iph, I0, Rs, Rsh, n] = unpack(best.x);

    ref = struct( ...
        "IphRef",   Iph, ...
        "I0Ref",    I0, ...
        "RsRef",    Rs, ...
        "RshRef",   Rsh, ...
        "aRef",     aOf(n), ...
        "n",        n, ...
        "Ns",       Ns, ...
        "alphaIsc", ds.alphaIsc, ...
        "EgRef",    opts.EgRef, ...
        "Module",   string(ds.Name));

    diag = validate(ref, ds);
    diag.resnorm = best.resnorm;
    diag.seed    = best.seed;

    function [Iph, I0, Rs, Rsh, n] = unpack(x)
        Iph = x(1);
        I0  = exp(x(2));
        Rs  = exp(x(3));
        Rsh = exp(x(4));
        n   = x(5);
    end

    function r = residuals(x)
        [Iph, I0, Rs, Rsh, n] = unpack(x);
        a = aOf(n);

        r = zeros(5, 1);
        r(1) = Iph - I0 * expm1(Isc * Rs / a) - Isc * Rs / Rsh - Isc;
        r(2) = Iph - I0 * expm1(Voc / a) - Voc / Rsh;

        vd   = Vmp + Imp * Rs;
        r(3) = Iph - I0 * expm1(vd / a) - vd / Rsh - Imp;

        gd   = I0 / a * exp(vd / a);
        dIdV = -(gd + 1 / Rsh) / (1 + Rs * gd + Rs / Rsh);
        r(4) = Imp + Vmp * dIdV;

        r(5) = dVocdT(Iph, I0, Rs, Rsh, a) - ds.betaVoc;

        r = r(:) ./ scale(:);
    end

    function b = dVocdT(Iph, I0, Rs, Rsh, a)
        refT = struct( ...
            "IphRef", Iph, "I0Ref", I0, "RsRef", Rs, "RshRef", Rsh, ...
            "aRef", a, "alphaIsc", ds.alphaIsc, "EgRef", opts.EgRef);
        dT = 10;
        b  = (vocAt(refT, Tr + dT) - vocAt(refT, Tr - dT)) / (2 * dT);
    end

    function v = vocAt(refT, T)
        m = mpptlab.pv.PVArray.translate(refT, mpptlab.pv.PVArray.Gref, T);
        v = mpptlab.pv.PVArray.vocFrom(m);
    end
end

function [x, resnorm, ok] = solveSystem(fun, x0, opts)
    x = x0; resnorm = inf; ok = false;
    if exist("fsolve", "file") == 2
        o = optimoptions("fsolve", ...
            "Display", opts.Display, ...
            "FunctionTolerance", opts.Tolerance, ...
            "StepTolerance", 1e-14, ...
            "MaxFunctionEvaluations", 20000, ...
            "MaxIterations", 3000, ...
            "Algorithm", "levenberg-marquardt");
        try
            [x, fv, flag] = fsolve(fun, x0, o);
            resnorm = norm(fv);
            ok = flag > 0 && resnorm < 1e-6;
        catch
            ok = false;
        end
    end
    if ~ok
        try
            o2 = optimset("Display", "off", "TolX", 1e-14, "TolFun", 1e-16, ...
                "MaxFunEvals", 2e5, "MaxIter", 2e5);
            x  = fminsearch(@(z) sum(fun(z).^2), x0, o2);
            resnorm = norm(fun(x));
            ok = resnorm < 1e-6;
        catch
            ok = false;
        end
    end
end

function d = validate(ref, ds)
    arr = mpptlab.pv.PVArray(ref);
    p   = arr.params();

    VocM = arr.voc(p);
    IscM = arr.isc(p);
    [VmpM, ImpM, PmpM] = arr.mpp(p);

    dT   = 10;
    arrT = mpptlab.pv.PVArray(ref);
    arrT.Tc = mpptlab.pv.PVArray.Tref + dT;  VocHi = arrT.voc();
    arrT.Tc = mpptlab.pv.PVArray.Tref - dT;  VocLo = arrT.voc();
    betaM = (VocHi - VocLo) / (2 * dT);

    d = struct();
    d.table = table( ...
        ["Voc (V)"; "Isc (A)"; "Vmp (V)"; "Imp (A)"; "Pmp (W)"; "betaVoc (V/K)"], ...
        [ds.Voc; ds.Isc; ds.Vmp; ds.Imp; ds.Pmax; ds.betaVoc], ...
        [VocM; IscM; VmpM; ImpM; PmpM; betaM], ...
        VariableNames = ["Quantity" "Datasheet" "Model"]);
    d.table.ErrorPct = 100 * (d.table.Model - d.table.Datasheet) ./ d.table.Datasheet;
    d.maxAbsErrorPct = max(abs(d.table.ErrorPct));
end
