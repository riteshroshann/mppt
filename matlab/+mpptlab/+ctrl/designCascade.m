function K = designCascade(bc, pv, opts)

    arguments
        bc (1,1) mpptlab.conv.Boost
        pv (1,1) mpptlab.pv.PVArray
        opts.fci       (1,1) double = 2000
        opts.fcv       (1,1) double = 250
        opts.ZeroRatioI(1,1) double = 10
        opts.ZeroRatioV(1,1) double = 5
        opts.Ts        (1,1) double = 0
    end

    wci = 2 * pi * opts.fci;
    wcv = 2 * pi * opts.fcv;

    KpI = bc.L * wci / bc.Vdc;
    KiI = KpI * wci / opts.ZeroRatioI;

    KpV = bc.Cpv * wcv;
    KiV = KpV * wcv / opts.ZeroRatioV;

    Ts = opts.Ts;
    if Ts <= 0
        Ts = 1 / bc.fsw;
    end

    p = pv.params();
    Vmp = pv.mpp(p);
    op  = bc.operatingPoint(pv, Vmp, p);

    K = struct();
    K.fci = opts.fci;
    K.fcv = opts.fcv;
    K.Ts  = Ts;
    K.KpI = KpI;
    K.KiI = KiI;
    K.KpV = KpV;
    K.KiV = KiV;
    K.wci = wci;
    K.wcv = wcv;
    K.designPoint = op;
    K.separationRatio = opts.fci / opts.fcv;
    K.switchingMargin = bc.fsw / opts.fci;
end
