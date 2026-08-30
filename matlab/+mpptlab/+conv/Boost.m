classdef Boost < handle

    properties
        L    (1,1) double {mustBePositive} = 1.5e-3
        Cpv  (1,1) double {mustBePositive} = 100e-6
        Co   (1,1) double {mustBePositive} = 470e-6
        RL   (1,1) double {mustBeNonnegative} = 0.15
        Vdc  (1,1) double {mustBePositive} = 400
        fsw  (1,1) double {mustBePositive} = 20e3
        dMin (1,1) double = 0.02
        dMax (1,1) double = 0.95
        Name (1,1) string = "PV-side boost"
    end

    methods
        function obj = Boost(opts)
            arguments
                opts.L    (1,1) double = 1.5e-3
                opts.Cpv  (1,1) double = 100e-6
                opts.Co   (1,1) double = 470e-6
                opts.RL   (1,1) double = 0.15
                opts.Vdc  (1,1) double = 400
                opts.fsw  (1,1) double = 20e3
                opts.dMin (1,1) double = 0.02
                opts.dMax (1,1) double = 0.95
                opts.Name (1,1) string = "PV-side boost"
            end
            f = fieldnames(opts);
            for k = 1:numel(f)
                obj.(f{k}) = opts.(f{k});
            end
        end

        function [dx, ipv] = derivatives(obj, x, d, pv, p, Iguess)
            arguments
                obj
                x  (2,1) double
                d  (1,1) double
                pv (1,1) mpptlab.pv.PVArray
                p  struct = pv.params()
                Iguess double = []
            end
            vpv = max(x(1), 0);
            iL  = x(2);
            d   = min(max(d, obj.dMin), obj.dMax);

            ipv = pv.current(vpv, p, Iguess);
            dx  = [ (ipv - iL) / obj.Cpv
                    (vpv - (1 - d) * obj.Vdc - iL * obj.RL) / obj.L ];
        end

        function d = dutyFor(obj, pv, V, p)
            arguments
                obj
                pv (1,1) mpptlab.pv.PVArray
                V  double
                p  struct = pv.params()
            end
            I = pv.current(V, p);
            d = 1 - (V - I * obj.RL) / obj.Vdc;
        end

        function op = operatingPoint(obj, pv, V, p)
            arguments
                obj
                pv (1,1) mpptlab.pv.PVArray
                V  (1,1) double
                p  struct = pv.params()
            end
            I = pv.current(V, p);
            g = pv.slopeAt(V, I, p);

            op = struct();
            op.V     = V;
            op.I     = I;
            op.P     = V * I;
            op.g     = g;
            op.rd    = -1 / g;
            op.dPdV  = I + V * g;
            op.D     = obj.dutyFor(pv, V, p);
            op.iLRipple = V * op.D / (obj.fsw * obj.L);
            op.ccmRatio = I / max(op.iLRipple / 2, eps);
            op.vpvRipple = op.iLRipple / (8 * obj.fsw * obj.Cpv);
            op.G     = pv.G;
            op.TcC   = pv.Tc - 273.15;
        end

        function [sys, op] = linearize(obj, pv, V, p)
            arguments
                obj
                pv (1,1) mpptlab.pv.PVArray
                V  (1,1) double
                p  struct = pv.params()
            end
            op = obj.operatingPoint(pv, V, p);

            A = [ op.g / obj.Cpv, -1 / obj.Cpv
                  1 / obj.L,      -obj.RL / obj.L ];
            B = [ 0; obj.Vdc / obj.L ];
            C = [ 1,        0
                  0,        1
                  op.dPdV,  0 ];
            D = zeros(3, 1);

            sys = ss(A, B, C, D);
            sys.StateName  = ["vpv" "iL"];
            sys.InputName  = "duty";
            sys.OutputName = ["vpv" "iL" "ppv"];
            sys.UserData   = op;
        end

        function q = modalProperties(obj, op)
            arguments
                obj
                op struct
            end
            wn   = sqrt((1 - op.g * obj.RL) / (obj.L * obj.Cpv));
            twz  = obj.RL / obj.L - op.g / obj.Cpv;
            q = struct( ...
                "wn",     wn, ...
                "fn",     wn / (2 * pi), ...
                "zeta",   twz / (2 * wn), ...
                "dcGain", -obj.Vdc / (1 - op.g * obj.RL));
        end

        function [sysArr, ops] = envelope(obj, pv, Glist, TcList, opts)
            arguments
                obj
                pv (1,1) mpptlab.pv.PVArray
                Glist  (1,:) double
                TcList (1,:) double = pv.Tc
                opts.At (1,1) string = "mpp"
                opts.VFrac (1,:) double = 1
            end
            G0 = pv.G; T0 = pv.Tc;
            cleaner = onCleanup(@() setBack(pv, G0, T0));

            sysArr = [];
            ops    = struct([]);
            n      = 0;
            for T = TcList
                for G = Glist
                    pv.G = G; pv.Tc = T;
                    p = pv.params();
                    switch opts.At
                        case "mpp"
                            Vset = pv.mpp(p);
                        case "vocfrac"
                            Vset = opts.VFrac * pv.voc(p);
                        otherwise
                            error("mpptlab:conv:badEnvelopeMode", ...
                                "At must be 'mpp' or 'vocfrac'.");
                    end
                    for V = Vset
                        n = n + 1;
                        [s, o] = obj.linearize(pv, V, p);
                        if isempty(sysArr)
                            sysArr = s;
                        else
                            sysArr(:, :, n) = s; %#ok<AGROW>
                        end
                        o.modal = obj.modalProperties(o);
                        if isempty(ops)
                            ops = o;
                        else
                            ops(n) = o; %#ok<AGROW>
                        end
                    end
                end
            end
        end

        function t = envelopeTable(~, ops)
            f = @(fld) arrayfun(@(o) o.(fld), ops(:));
            m = @(fld) arrayfun(@(o) o.modal.(fld), ops(:));
            t = table(f("G"), f("TcC"), f("V"), f("I"), f("P"), f("D"), ...
                      f("rd"), m("fn"), m("zeta"), m("dcGain"), ...
                      f("iLRipple"), f("ccmRatio"), ...
                VariableNames = ["G" "TcC" "Vop" "Iop" "Pop" "D" "rd" ...
                                 "fn" "zeta" "dcGain" "iLRipple" "ccmRatio"]);
        end
    end

    methods (Static)
        function [obj, spec] = design(pv, opts)
            arguments
                pv (1,1) mpptlab.pv.PVArray
                opts.Vdc         (1,1) double = 400
                opts.fsw         (1,1) double = 20e3
                opts.RippleFrac  (1,1) double = 0.20
                opts.VpvRipple   (1,1) double = 0.25
                opts.RL          (1,1) double = 0.15
                opts.Co          (1,1) double = 470e-6
            end
            p = pv.params();
            [Vmp, Imp, Pmp] = pv.mpp(p);

            D  = 1 - Vmp / opts.Vdc;
            dI = opts.RippleFrac * Imp;
            L  = Vmp * D / (opts.fsw * dI);
            C  = dI / (8 * opts.fsw * opts.VpvRipple);

            obj = mpptlab.conv.Boost( ...
                L = L, Cpv = C, Co = opts.Co, RL = opts.RL, ...
                Vdc = opts.Vdc, fsw = opts.fsw);

            spec = struct("Vmp", Vmp, "Imp", Imp, "Pmp", Pmp, "D", D, ...
                "dIL", dI, "L", L, "Cpv", C, ...
                "fLC", 1 / (2 * pi * sqrt(L * C)), ...
                "fsw", opts.fsw, "Vdc", opts.Vdc);
        end
    end
end

function setBack(pv, G, T)
    pv.G = G;
    pv.Tc = T;
end
