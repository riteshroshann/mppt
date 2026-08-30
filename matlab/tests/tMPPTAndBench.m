classdef tMPPTAndBench < matlab.unittest.TestCase

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
        function trapezoidProfileHitsBothPlateaus(tc)
            prof = mpptlab.bench.irradiance("trapezoid", Glow = 300, Ghigh = 1000, ...
                Slope = 100, Dwell = 1, Cycles = 1, Settle = 1);
            t = linspace(0, prof.Duration, 4000);
            G = arrayfun(@(x) prof.G(x), t);
            tc.verifyEqual(min(G), 300, AbsTol = 1);
            tc.verifyEqual(max(G), 1000, AbsTol = 1);
            tc.verifyEqual(prof.G(0), 300, AbsTol = 1e-9);
            tc.verifyLessThan(max(abs(diff(G) ./ diff(t))), 110);
        end

        function stepProfileSwitchesAtTheRightTime(tc)
            prof = mpptlab.bench.irradiance("step", G0 = 1000, G1 = 500, ...
                StepTime = 0.5, Duration = 1);
            tc.verifyEqual(prof.G(0.4), 1000, AbsTol = 1e-9);
            tc.verifyEqual(prof.G(0.6), 500,  AbsTol = 1e-9);
        end

        function closedLoopHoldsAFixedReference(tc)
            prof = mpptlab.bench.irradiance("constant", G0 = 1000, Duration = 0.15);
            frozen = mpptlab.mppt.PandO(Ts = 1e9, Step = 1e-12);
            o = mpptlab.bench.simulate(tc.pv, tc.bc, frozen, tc.K, prof, ...
                V0 = 145, RecordEvery = 20);
            tc.verifyEqual(o.vpv(end), 145, AbsTol = 0.05);

            tc.pv.G = 1000;
            tc.verifyEqual(o.iL(end), tc.pv.current(145), AbsTol = 0.05);
        end

        function pandOLimitCycleIsTwiceTheStep(tc)
            prof = mpptlab.bench.irradiance("constant", G0 = 1000, Duration = 2.0);
            for step = [1.0 2.0]
                po = mpptlab.mppt.PandO(Ts = 20e-3, Step = step);
                o  = mpptlab.bench.simulate(tc.pv, tc.bc, po, tc.K, prof, ...
                    V0 = 157.8, RecordEvery = 20);
                tail = o.vpv(o.t > 1.5);
                tc.verifyEqual(max(tail) - min(tail), 2 * step, RelTol = 0.06);
            end
        end

        function trackersFindTheMaximumPowerPoint(tc)
            prof = mpptlab.bench.irradiance("constant", G0 = 800, Duration = 2.5);
            tc.pv.G = 800;
            Vmp = tc.pv.mpp();
            names = ["P&O" "IncCond" "ESC"];
            for n = names
                tr = mpptlab.bench.trackerSet(n, Tmppt = 20e-3, Step = 1.5);
                o  = mpptlab.bench.simulate(tc.pv, tc.bc, tr{1}, tc.K, prof, ...
                    V0 = 120, ScoreFrom = 2.0, RecordEvery = 20);
                tail = mean(o.vpv(o.t > 2.0));
                tc.verifyEqual(tail, Vmp, ...
                    "Tracker " + n + " did not settle near the MPP", AbsTol = 8);
                tc.verifyGreaterThan(o.metrics.etaMppt, 0.99);
            end
        end

        function efficiencyIsBoundedByOne(tc)
            prof = mpptlab.bench.irradiance("constant", G0 = 600, Duration = 1.0);
            po = mpptlab.mppt.PandO(Ts = 20e-3, Step = 1.5);
            o  = mpptlab.bench.simulate(tc.pv, tc.bc, po, tc.K, prof, ...
                V0 = 155, ScoreFrom = 0.5, RecordEvery = 20);
            tc.verifyLessThanOrEqual(o.metrics.etaMppt, 1 + 1e-6);
            tc.verifyGreaterThan(o.metrics.etaMppt, 0.95);
        end

        function integratorStepConvergenceIsAcceptable(tc)
            prof = mpptlab.bench.irradiance("constant", G0 = 1000, Duration = 0.6);
            po1 = mpptlab.mppt.PandO(Ts = 20e-3, Step = 1.5);
            po2 = mpptlab.mppt.PandO(Ts = 20e-3, Step = 1.5);
            oFine   = mpptlab.bench.simulate(tc.pv, tc.bc, po1, tc.K, prof, ...
                V0 = 140, PlantStep = 1/(4*tc.bc.fsw), RecordEvery = 40);
            oCoarse = mpptlab.bench.simulate(tc.pv, tc.bc, po2, tc.K, prof, ...
                V0 = 140, PlantStep = 1/tc.bc.fsw, RecordEvery = 10);
            tc.verifyEqual(oCoarse.vpv(end), oFine.vpv(end), AbsTol = 0.5);
        end
    end
end
