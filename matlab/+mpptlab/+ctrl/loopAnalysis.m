function R = loopAnalysis(bc, pv, K, opts)

    arguments
        bc (1,1) mpptlab.conv.Boost
        pv (1,1) mpptlab.pv.PVArray
        K  struct
        opts.Glist  (1,:) double = [200 400 600 800 1000]
        opts.TcList (1,:) double = 298.15
        opts.At     (1,1) string = "mpp"
        opts.VFrac  (1,:) double = 1
        opts.SingleLoopKp (1,1) double = 0
        opts.SingleLoopKi (1,1) double = 0
    end

    s  = tf("s");
    Ci = K.KpI + K.KiI / s;
    Cv = K.KpV + K.KiV / s;

    doSingle = opts.SingleLoopKp > 0 || opts.SingleLoopKi > 0;
    if doSingle
        Cs = opts.SingleLoopKp + opts.SingleLoopKi / s;
    end

    G0 = pv.G; T0 = pv.Tc;
    restore = onCleanup(@() resetPV(pv, G0, T0));

    rows = struct([]);
    n = 0;
    for T = opts.TcList
        for G = opts.Glist
            pv.G = G; pv.Tc = T;
            p = pv.params();
            switch opts.At
                case "mpp"
                    Vset = pv.mpp(p);
                case "vocfrac"
                    Vset = opts.VFrac * pv.voc(p);
                otherwise
                    error("mpptlab:ctrl:badMode", "At must be 'mpp' or 'vocfrac'.");
            end

            for V = Vset
                n = n + 1;
                [sys, op] = bc.linearize(pv, V, p);
                Gvd = tf(sys(1));
                Gid = tf(sys(2));

                Li = Ci * Gid;
                [gmI, pmI, ~, wcI] = margin(Li);

                GvFromIref = series(feedback(Ci, Gid), Gvd);
                Lv = -Cv * GvFromIref;
                [gmV, pmV, ~, wcV] = margin(Lv);

                Tcl = feedback(Lv, 1);
                clPoles = pole(minreal(Tcl, [], false));
                stable  = all(real(clPoles) < 0);

                r = struct( ...
                    "G", G, "TcC", T - 273.15, "V", V, "rd", op.rd, ...
                    "zetaPlant", modalZeta(bc, op), ...
                    "gmI_dB", 20*log10(gmI), "pmI_deg", pmI, "fcI", wcI/(2*pi), ...
                    "gmV_dB", 20*log10(gmV), "pmV_deg", pmV, "fcV", wcV/(2*pi), ...
                    "stable", stable);

                if doSingle
                    Ls  = -Cs * Gvd;
                    ams = allmargin(Ls);
                    r.pmS_deg  = minAbsOrNan(ams.PhaseMargin);
                    r.fcS      = minOrNan(ams.PMFrequency) / (2*pi);
                    r.nCrossS  = numel(ams.PMFrequency);
                    r.peakLs   = peakGainDb(Ls);
                    r.stableS  = ams.Stable;
                end

                if isempty(rows)
                    rows = r;
                else
                    rows(n) = r;
                end
            end
        end
    end

    R = struct();
    R.rows  = rows;
    R.table = struct2table(rows);
    R.Ci    = Ci;
    R.Cv    = Cv;
    R.worstPmI = min(R.table.pmI_deg);
    R.worstPmV = min(R.table.pmV_deg);
    R.allStable = all(R.table.stable);
    if doSingle
        R.Cs = Cs;
        R.worstPmS = min(R.table.pmS_deg);
        R.allStableSingle = all(R.table.stableS);
    end
end

function z = modalZeta(bc, op)
    q = bc.modalProperties(op);
    z = q.zeta;
end

function v = minOrNan(x)
    if isempty(x)
        v = NaN;
    else
        v = min(x);
    end
end

function v = minAbsOrNan(x)
    if isempty(x)
        v = NaN;
    else
        [~, k] = min(abs(x));
        v = x(k);
    end
end

function g = peakGainDb(L)
    w = logspace(0, 6, 4000);
    m = squeeze(bode(L, w));
    g = 20 * log10(max(m));
end

function resetPV(pv, G, T)
    pv.G = G;
    pv.Tc = T;
end
