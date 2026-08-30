classdef PandO < mpptlab.mppt.Tracker

    properties
        Step      (1,1) double {mustBePositive} = 1.0
        Adaptive  (1,1) logical = false
        StepMin   (1,1) double {mustBePositive} = 0.1
        StepMax   (1,1) double {mustBePositive} = 4.0
        AdaptGain (1,1) double {mustBePositive} = 0.05
        PowerDeadband (1,1) double {mustBeNonnegative} = 0
    end

    properties (SetAccess = private)
        Pprev (1,1) double = NaN
        Vprev (1,1) double = NaN
        Dir   (1,1) double = 1
        LastStep (1,1) double = 0
    end

    methods
        function obj = PandO(opts)
            arguments
                opts.Ts       (1,1) double = 1e-3
                opts.Step     (1,1) double = 1.0
                opts.Adaptive (1,1) logical = false
                opts.StepMin  (1,1) double = 0.1
                opts.StepMax  (1,1) double = 4.0
                opts.AdaptGain(1,1) double = 0.05
                opts.PowerDeadband (1,1) double = 0
                opts.Vmin     (1,1) double = 20
                opts.Vmax     (1,1) double = 1e4
                opts.Name     (1,1) string = "P&O"
            end
            f = fieldnames(opts);
            for k = 1:numel(f)
                obj.(f{k}) = opts.(f{k});
            end
        end
    end

    methods (Access = protected)
        function onReset(obj, ~)
            obj.Pprev = NaN;
            obj.Vprev = NaN;
            obj.Dir   = 1;
            obj.LastStep = 0;
        end

        function v = advance(obj, V, I, ~)
            P = V * I;

            if isnan(obj.Pprev)
                obj.Pprev = P;
                obj.Vprev = V;
                obj.LastStep = obj.Dir * obj.Step;
                v = obj.Vref + obj.LastStep;
                return
            end

            dP = P - obj.Pprev;
            dV = V - obj.Vprev;

            if abs(dP) <= obj.PowerDeadband
                v = obj.Vref;
                obj.Pprev = P;
                obj.Vprev = V;
                obj.LastStep = 0;
                return
            end

            if dP < 0
                obj.Dir = -obj.Dir;
            end

            if obj.Adaptive
                if abs(dV) > 1e-9
                    slope = abs(dP / dV);
                else
                    slope = 0;
                end
                stepSize = min(max(obj.AdaptGain * slope, obj.StepMin), obj.StepMax);
            else
                stepSize = obj.Step;
            end

            obj.LastStep = obj.Dir * stepSize;
            v = obj.Vref + obj.LastStep;

            obj.Pprev = P;
            obj.Vprev = V;
        end
    end
end
