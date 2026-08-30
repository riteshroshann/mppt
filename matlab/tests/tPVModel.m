classdef tPVModel < matlab.unittest.TestCase

    properties
        ref
        ds
        arr
    end

    methods (TestClassSetup)
        function build(tc)
            tc.ds  = mpptlab.pv.datasheet("KC200GT");
            tc.ref = mpptlab.pv.extractParams(tc.ds);
            tc.arr = mpptlab.pv.PVArray(tc.ref);
        end
    end

    methods (Test)
        function reproducesDatasheet(tc)
            [~, d] = mpptlab.pv.extractParams(tc.ds);
            tc.verifyLessThan(d.maxAbsErrorPct, 1e-6);
        end

        function shortCircuitAndOpenCircuit(tc)
            p = tc.arr.params();
            tc.verifyEqual(tc.arr.isc(p), tc.ds.Isc, RelTol = 1e-8);
            tc.verifyEqual(tc.arr.voc(p), tc.ds.Voc, RelTol = 1e-8);
            tc.verifyEqual(tc.arr.current(tc.ds.Voc, p), 0, AbsTol = 1e-8);
        end

        function mppSatisfiesStationarity(tc)
            p = tc.arr.params();
            [Vmp, Imp, Pmp] = tc.arr.mpp(p);
            tc.verifyEqual(tc.arr.dPdV(Vmp, p), 0, AbsTol = 1e-6);
            tc.verifyEqual(Pmp, Vmp * Imp, RelTol = 1e-12);
            tc.verifyEqual(Pmp, tc.ds.Pmax, RelTol = 1e-6);
        end

        function residualIsZeroOnTheCurve(tc)
            p = tc.arr.params();
            V = linspace(0, tc.arr.voc(p), 200);
            I = tc.arr.current(V, p);
            f = mpptlab.pv.PVArray.residual(V, I, p);
            tc.verifyLessThan(max(abs(f)), 1e-9);
        end

        function analyticSlopeMatchesFiniteDifference(tc)
            p  = tc.arr.params();
            Voc = tc.arr.voc(p);
            V  = linspace(0.05 * Voc, 0.97 * Voc, 40);
            h  = 1e-5 * Voc;
            gA = tc.arr.dIdV(V, p);
            gN = (tc.arr.current(V + h, p) - tc.arr.current(V - h, p)) / (2 * h);
            tc.verifyLessThan(max(abs(gA - gN) ./ abs(gN)), 1e-5);
        end

        function currentDecreasesWithVoltage(tc)
            p = tc.arr.params();
            V = linspace(0, tc.arr.voc(p), 300);
            I = tc.arr.current(V, p);
            tc.verifyTrue(all(diff(I) <= 1e-9));
        end

        function powerIncreasesWithIrradiance(tc)
            a = mpptlab.pv.PVArray(tc.ref);
            P = zeros(1, 5);
            G = [200 400 600 800 1000];
            for k = 1:5
                a.G = G(k);
                [~, ~, P(k)] = a.mpp();
            end
            tc.verifyTrue(all(diff(P) > 0));
        end

        function voltageFallsWithTemperature(tc)
            a = mpptlab.pv.PVArray(tc.ref);
            T = 273.15 + [15 25 45 65];
            V = zeros(1, 4);
            for k = 1:4
                a.Tc = T(k);
                V(k) = a.voc();
            end
            tc.verifyTrue(all(diff(V) < 0));
            beta = (V(end) - V(1)) / (T(end) - T(1));
            tc.verifyEqual(beta, tc.ds.betaVoc, RelTol = 0.05);
        end

        function arrayScalesWithTopology(tc)
            one = mpptlab.pv.PVArray(tc.ref);
            big = mpptlab.pv.PVArray(tc.ref, NsMod = 6, NpStr = 2);
            [v1, i1, p1] = one.mpp();
            [v6, i6, p6] = big.mpp();
            tc.verifyEqual(v6, 6 * v1, RelTol = 1e-6);
            tc.verifyEqual(i6, 2 * i1, RelTol = 1e-6);
            tc.verifyEqual(p6, 12 * p1, RelTol = 1e-6);
        end

        function dynamicResistanceEqualsVmpOverImpAtMpp(tc)
            p = tc.arr.params();
            [Vmp, Imp] = tc.arr.mpp(p);
            rd = tc.arr.dynamicResistance(Vmp, p);
            tc.verifyEqual(rd, Vmp / Imp, RelTol = 1e-4);
        end

        function handlesZeroIrradiance(tc)
            a = mpptlab.pv.PVArray(tc.ref, G = 0);
            tc.verifyGreaterThanOrEqual(a.voc(), 0);
            tc.verifyLessThan(a.isc(), 0.05);
        end
    end
end
