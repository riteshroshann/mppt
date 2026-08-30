classdef PI < handle

    properties
        Kp   (1,1) double = 0
        Ki   (1,1) double = 0
        Ts   (1,1) double {mustBePositive} = 5e-5
        uMin (1,1) double = -inf
        uMax (1,1) double = inf
        Kaw  (1,1) double {mustBeNonnegative} = 0
        Name (1,1) string = "PI"
    end

    properties (SetAccess = private)
        Integrator (1,1) double = 0
        LastOutput (1,1) double = 0
    end

    methods
        function obj = PI(opts)
            arguments
                opts.Kp   (1,1) double = 0
                opts.Ki   (1,1) double = 0
                opts.Ts   (1,1) double = 5e-5
                opts.uMin (1,1) double = -inf
                opts.uMax (1,1) double = inf
                opts.Kaw  (1,1) double = -1
                opts.Name (1,1) string = "PI"
            end
            obj.Kp = opts.Kp;
            obj.Ki = opts.Ki;
            obj.Ts = opts.Ts;
            obj.uMin = opts.uMin;
            obj.uMax = opts.uMax;
            obj.Name = opts.Name;
            if opts.Kaw < 0
                obj.Kaw = defaultKaw(obj.Kp, obj.Ki);
            else
                obj.Kaw = opts.Kaw;
            end
        end

        function reset(obj, u0, e0)
            arguments
                obj
                u0 (1,1) double = 0
                e0 (1,1) double = 0
            end
            obj.Integrator = u0 - obj.Kp * e0;
            obj.LastOutput = u0;
        end

        function u = step(obj, e)
            raw = obj.Kp * e + obj.Integrator;
            u   = min(max(raw, obj.uMin), obj.uMax);
            obj.Integrator = obj.Integrator + obj.Ts * (obj.Ki * e + obj.Kaw * (u - raw));
            obj.LastOutput = u;
        end

        function C = transfer(obj)
            C = tf([obj.Kp obj.Ki], [1 0]);
        end
    end
end

function k = defaultKaw(Kp, Ki)
    if Kp > 0
        k = Ki / Kp;
    else
        k = 0;
    end
end
