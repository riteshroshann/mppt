classdef PVArray < handle

    properties (SetAccess = public)
        IphRef   (1,1) double {mustBePositive} = 8.21
        I0Ref    (1,1) double {mustBePositive} = 2.2e-10
        RsRef    (1,1) double {mustBeNonnegative} = 0.221
        RshRef   (1,1) double {mustBePositive} = 415.4
        aRef     (1,1) double {mustBePositive} = 1.5

        Ns       (1,1) double {mustBePositive} = 54
        alphaIsc (1,1) double = 3.18e-3
        EgRef    (1,1) double {mustBePositive} = 1.121

        NsMod    (1,1) double {mustBePositive, mustBeInteger} = 1
        NpStr    (1,1) double {mustBePositive, mustBeInteger} = 1

        G        (1,1) double {mustBeNonnegative} = 1000
        Tc       (1,1) double {mustBePositive}    = 298.15

        Name     (1,1) string = "PV array"
    end

    properties (Constant)
        Gref  = 1000
        Tref  = 298.15
        kB_eV = 8.617333262e-5
        kB    = 1.380649e-23
        qe    = 1.602176634e-19
        Gmin  = 1.0
    end

    methods
        function obj = PVArray(params, opts)
            arguments
                params struct = struct()
                opts.NsMod (1,1) double = 1
                opts.NpStr (1,1) double = 1
                opts.G     (1,1) double = 1000
                opts.Tc    (1,1) double = 298.15
                opts.Name  (1,1) string = "PV array"
            end
            fn = ["IphRef" "I0Ref" "RsRef" "RshRef" "aRef" "Ns" "alphaIsc" "EgRef"];
            for f = fn
                if isfield(params, f)
                    obj.(f) = params.(f);
                end
            end
            obj.NsMod = opts.NsMod;
            obj.NpStr = opts.NpStr;
            obj.G     = opts.G;
            obj.Tc    = opts.Tc;
            obj.Name  = opts.Name;
        end

        function p = params(obj)
            ref = struct( ...
                "IphRef",   obj.IphRef, ...
                "I0Ref",    obj.I0Ref, ...
                "RsRef",    obj.RsRef, ...
                "RshRef",   obj.RshRef, ...
                "aRef",     obj.aRef, ...
                "alphaIsc", obj.alphaIsc, ...
                "EgRef",    obj.EgRef);
            m = mpptlab.pv.PVArray.translate(ref, obj.G, obj.Tc);

            p.a   = m.a   * obj.NsMod;
            p.Iph = m.Iph * obj.NpStr;
            p.I0  = m.I0  * obj.NpStr;
            p.Rs  = m.Rs  * obj.NsMod / obj.NpStr;
            p.Rsh = m.Rsh * obj.NsMod / obj.NpStr;
        end

        function I = current(obj, V, p)
            arguments
                obj
                V double
                p struct = obj.params()
            end
            I = zeros(size(V));
            [f, df] = obj.residual(V, I, p);
            maxStep = 2 * p.Iph + 1;
            tol     = 1e-11 * max(1, p.Iph);
            for it = 1:60
                if all(abs(f) < tol, "all")
                    break
                end
                step = min(max(f ./ df, -maxStep), maxStep);
                Itry = I - step;
                fTry = obj.residual(V, Itry, p);
                for bt = 1:40
                    bad = abs(fTry) > abs(f);
                    if ~any(bad, "all"), break; end
                    step(bad) = step(bad) / 2;
                    Itry = I - step;
                    fTry = obj.residual(V, Itry, p);
                end
                I = Itry;
                [f, df] = obj.residual(V, I, p);
            end
        end

        function P = power(obj, V, p)
            arguments
                obj
                V double
                p struct = obj.params()
            end
            P = V .* obj.current(V, p);
        end

        function [g, I] = dIdV(obj, V, p)
            arguments
                obj
                V double
                p struct = obj.params()
            end
            I = obj.current(V, p);
            g = obj.slopeAt(V, I, p);
        end

        function [s, I] = dPdV(obj, V, p)
            arguments
                obj
                V double
                p struct = obj.params()
            end
            [g, I] = obj.dIdV(V, p);
            s = I + V .* g;
        end

        function [rd, I] = dynamicResistance(obj, V, p)
            arguments
                obj
                V double
                p struct = obj.params()
            end
            [g, I] = obj.dIdV(V, p);
            rd = -1 ./ g;
        end

        function V = voc(obj, p)
            arguments
                obj
                p struct = obj.params()
            end
            V = mpptlab.pv.PVArray.vocFrom(p);
        end

        function I = isc(obj, p)
            arguments
                obj
                p struct = obj.params()
            end
            I = obj.current(0, p);
        end

        function [Vmp, Imp, Pmp] = mpp(obj, p)
            arguments
                obj
                p struct = obj.params()
            end
            Voc = obj.voc(p);
            if Voc <= 0
                [Vmp, Imp, Pmp] = deal(0, 0, 0); return
            end
            Vg = linspace(1e-6, Voc, 400);
            Pg = obj.power(Vg, p);
            [~, k] = max(Pg);
            lo  = Vg(max(k - 1, 1));
            hi  = Vg(min(k + 1, numel(Vg)));
            if obj.dPdV(lo, p) > 0 && obj.dPdV(hi, p) < 0
                Vmp = fzero(@(v) obj.dPdV(v, p), [lo, hi]);
            else
                Vmp = Vg(k);
            end
            Imp = obj.current(Vmp, p);
            Pmp = Vmp * Imp;
        end

        function s = operatingSummary(obj)
            p = obj.params();
            [Vmp, Imp, Pmp] = obj.mpp(p);
            Voc = obj.voc(p);
            Isc = obj.isc(p);
            s = struct( ...
                "G",     obj.G, ...
                "TcC",   obj.Tc - 273.15, ...
                "Voc",   Voc, ...
                "Isc",   Isc, ...
                "Vmp",   Vmp, ...
                "Imp",   Imp, ...
                "Pmp",   Pmp, ...
                "FF",    Pmp / (Voc * Isc), ...
                "rdMpp", Vmp / Imp);
        end

        function t = curve(obj, n)
            arguments
                obj
                n (1,1) double {mustBePositive, mustBeInteger} = 400
            end
            p = obj.params();
            V = linspace(0, obj.voc(p), n)';
            I = obj.current(V, p);
            t = table(V, I, V .* I, obj.slopeAt(V, I, p), ...
                VariableNames = ["V" "I" "P" "dIdV"]);
        end
    end

    methods (Static)
        function m = translate(ref, G, T)
            Tr   = mpptlab.pv.PVArray.Tref;
            Gr   = mpptlab.pv.PVArray.Gref;
            kEV  = mpptlab.pv.PVArray.kB_eV;
            Geff = max(G, mpptlab.pv.PVArray.Gmin);

            m.a   = ref.aRef * T / Tr;
            m.Iph = (Geff / Gr) * (ref.IphRef + ref.alphaIsc * (T - Tr));
            Eg    = ref.EgRef * (1 - 2.677e-4 * (T - Tr));
            m.I0  = ref.I0Ref * (T / Tr)^3 * ...
                    exp(ref.EgRef / (kEV * Tr) - Eg / (kEV * T));
            m.Rsh = ref.RshRef * (Gr / Geff);
            m.Rs  = ref.RsRef;
        end

        function V = vocFrom(p)
            if p.Iph <= 0
                V = 0; return
            end
            Vub = p.a * log(p.Iph / p.I0 + 1);
            g   = @(v) p.Iph - p.I0 * expm1(v / p.a) - v / p.Rsh;
            V   = fzero(g, [0, Vub]);
        end

        function [f, df] = residual(V, I, p)
            x  = min((V + I * p.Rs) / p.a, 700);
            em = expm1(x);
            f  = p.Iph - p.I0 .* em - (V + I * p.Rs) / p.Rsh - I;
            if nargout > 1
                df = -p.I0 * p.Rs / p.a .* (em + 1) - p.Rs / p.Rsh - 1;
            end
        end

        function g = slopeAt(V, I, p)
            x  = min((V + I * p.Rs) / p.a, 700);
            gd = p.I0 / p.a .* exp(x);
            g  = -(gd + 1 / p.Rsh) ./ (1 + p.Rs * gd + p.Rs / p.Rsh);
        end
    end
end
