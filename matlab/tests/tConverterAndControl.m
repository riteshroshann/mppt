classdef tConverterAndControl < matlab.unittest.TestCase

    properties
        cfg
        pv
        bc
        K
    end

    methods (TestClassSetup)
        function build(tc)
            tc.cfg = mpptlab.util.config();
            tc.pv  = tc.cfg.pv;
            tc.bc  = tc.cfg.boost;
            tc.K   = tc.cfg.gains;
        end
    end

    methods (Test)
        function operatingPointIsAnEquilibrium(tc)
            tc.pv.G = 800; tc.pv.Tc = 298.15;
            p = tc.pv.params();
            V = tc.pv.mpp(p);
            op = tc.bc.operatingPoint(tc.pv, V, p);
            dx = tc.bc.derivatives([op.V; op.I], op.D, tc.pv, p);
            tc.verifyLessThan(norm(dx), 1e-6);
        end

        function jacobianMatchesFiniteDifference(tc)
            tc.pv.G = 700; tc.pv.Tc = 273.15 + 40;
            p = tc.pv.params();
            V = tc.pv.mpp(p);
            [sys, op] = tc.bc.linearize(tc.pv, V, p);
            x0 = [op.V; op.I];

            An = zeros(2);
            for k = 1:2
                e = zeros(2,1);
                e(k) = 1e-6 * max(1, abs(x0(k)));
                An(:,k) = (tc.bc.derivatives(x0+e, op.D, tc.pv, p) - ...
                           tc.bc.derivatives(x0-e, op.D, tc.pv, p)) / (2*e(k));
            end
            h  = 1e-7;
            Bn = (tc.bc.derivatives(x0, op.D+h, tc.pv, p) - ...
                  tc.bc.derivatives(x0, op.D-h, tc.pv, p)) / (2*h);

            tc.verifyLessThan(max(abs(sys.A - An), [], "all") / max(abs(sys.A), [], "all"), 1e-6);
            tc.verifyLessThan(max(abs(sys.B - Bn)) / max(abs(sys.B)), 1e-6);
        end

        function powerOutputGainVanishesAtMpp(tc)
            tc.pv.G = 1000;
            p = tc.pv.params();
            Vmp = tc.pv.mpp(p);
            sys = tc.bc.linearize(tc.pv, Vmp, p);
            tc.verifyLessThan(abs(dcgain(tf(sys(3)))), 1e-6);
        end

        function powerGainChangesSignAcrossMpp(tc)
            tc.pv.G = 1000;
            p = tc.pv.params();
            Vmp = tc.pv.mpp(p);
            [~, opLo] = tc.bc.linearize(tc.pv, Vmp - 15, p);
            [~, opHi] = tc.bc.linearize(tc.pv, Vmp + 15, p);
            tc.verifyGreaterThan(opLo.dPdV, 0);
            tc.verifyLessThan(opHi.dPdV, 0);
        end

        function modalFormulaMatchesEigenvalues(tc)
            tc.pv.G = 500;
            p = tc.pv.params();
            V = tc.pv.mpp(p);
            [sys, op] = tc.bc.linearize(tc.pv, V, p);
            q = tc.bc.modalProperties(op);
            e = eig(sys.A);
            tc.verifyEqual(abs(e(1)), q.wn, RelTol = 1e-8);
            tc.verifyEqual(-real(e(1))/abs(e(1)), q.zeta, RelTol = 1e-8);
        end

        function dutyToVoltageGainIsNegative(tc)
            tc.pv.G = 1000;
            p = tc.pv.params();
            V = tc.pv.mpp(p);
            sys = tc.bc.linearize(tc.pv, V, p);
            tc.verifyLessThan(dcgain(tf(sys(1))), 0);
        end

        function cascadeIsRobustAcrossTheEnvelope(tc)
            R = mpptlab.ctrl.loopAnalysis(tc.bc, tc.pv, tc.K, ...
                Glist = [200 500 1000], At = "vocfrac", ...
                VFrac = [0.4 0.6 0.8 0.9]);
            tc.verifyTrue(R.allStable);
            tc.verifyGreaterThan(R.worstPmI, 45);
            tc.verifyGreaterThan(R.worstPmV, 45);
        end

        function singleLoopIsMuchLessRobustThanCascade(tc)
            [KpS, KiS] = mpptlab.ctrl.designSingleLoopPI(tc.bc, tc.pv, fc = 130);
            R = mpptlab.ctrl.loopAnalysis(tc.bc, tc.pv, tc.K, ...
                Glist = 1000, At = "vocfrac", VFrac = [0.35 0.55 0.8], ...
                SingleLoopKp = KpS, SingleLoopKi = KiS);
            tc.verifyLessThan(R.worstPmS, 10);
            tc.verifyGreaterThan(R.worstPmV, 45);
        end

        function ccmHoldsAtRatedIrradiance(tc)
            tc.pv.G = 1000;
            p = tc.pv.params();
            V = tc.pv.mpp(p);
            op = tc.bc.operatingPoint(tc.pv, V, p);
            tc.verifyGreaterThan(op.ccmRatio, 1);
        end
    end
end
