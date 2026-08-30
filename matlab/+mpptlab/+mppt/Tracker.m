classdef (Abstract) Tracker < handle

    properties
        Ts   (1,1) double {mustBePositive} = 1e-3
        Vmin (1,1) double = 20
        Vmax (1,1) double = 1e4
        Name (1,1) string = "tracker"
    end

    properties (SetAccess = protected)
        Vref (1,1) double = 0
        Nupdates (1,1) double = 0
    end

    methods (Abstract, Access = protected)
        v = advance(obj, V, I, t)
    end

    methods
        function reset(obj, V0)
            arguments
                obj
                V0 (1,1) double
            end
            obj.Vref = obj.clampRef(V0);
            obj.Nupdates = 0;
            obj.onReset(V0);
        end

        function v = update(obj, V, I, t)
            v = obj.advance(V, I, t);
            obj.Vref = obj.clampRef(v);
            obj.Nupdates = obj.Nupdates + 1;
            v = obj.Vref;
        end

        function v = clampRef(obj, v)
            v = min(max(v, obj.Vmin), obj.Vmax);
        end
    end

    methods (Access = protected)
        function onReset(~, ~)
        end
    end
end
