classdef IncCond < mpptlab.mppt.Tracker

    properties
        Step      (1,1) double {mustBePositive} = 1.0
        Adaptive  (1,1) logical = false
        StepMin   (1,1) double {mustBePositive} = 0.1
        StepMax   (1,1) double {mustBePositive} = 4.0
        AdaptGain (1,1) double {mustBePositive} = 0.5
        Tol       (1,1) double {mustBeNonnegative} = 1e-3
    end

    properties (SetAccess = private)
        Vprev (1,1) double = NaN
        Iprev (1,1) double = NaN
    end

    methods
        function obj = IncCond(opts)
            arguments
                opts.Ts       (1,1) double = 1e-3
                opts.Step     (1,1) double = 1.0
                opts.Adaptive (1,1) logical = false
                opts.StepMin  (1,1) double = 0.1
                opts.StepMax  (1,1) double = 4.0
                opts.AdaptGain(1,1) double = 0.5
                opts.Tol      (1,1) double = 1e-3
                opts.Vmin     (1,1) double = 20
                opts.Vmax     (1,1) double = 1e4
                opts.Name     (1,1) string = "IncCond"
            end
            f = fieldnames(opts);
            for k = 1:numel(f)
                obj.(f{k}) = opts.(f{k});
            end
        end
    end

    methods (Access = protected)
        function onReset(obj, ~)
            obj.Vprev = NaN;
            obj.Iprev = NaN;
        end

        function v = advance(obj, V, I, ~)
            if isnan(obj.Vprev)
                obj.Vprev = V;
                obj.Iprev = I;
                v = obj.Vref + obj.Step;
                return
            end

            dV = V - obj.Vprev;
            dI = I - obj.Iprev;
            obj.Vprev = V;
            obj.Iprev = I;

            if abs(V) < 1e-9
                v = obj.Vref;
                return
            end

            if abs(dV) < 1e-9
                if abs(dI) < obj.Tol
                    v = obj.Vref;
                else
                    v = obj.Vref + sign(dI) * obj.stepFrom(V, I, dI, dV);
                end
                return
            end

            resid = dI / dV + I / V;

            if abs(resid) < obj.Tol
                v = obj.Vref;
                return
            end

            v = obj.Vref + sign(resid) * obj.stepFrom(V, I, dI, dV);
        end

        function s = stepFrom(obj, V, I, dI, dV)
            if ~obj.Adaptive
                s = obj.Step;
                return
            end
            if abs(dV) > 1e-9
                dPdV = I + V * (dI / dV);
            else
                dPdV = 0;
            end
            s = min(max(obj.AdaptGain * abs(dPdV), obj.StepMin), obj.StepMax);
        end
    end
end
