classdef ESC < mpptlab.mppt.Tracker

    properties
        DitherHz  (1,1) double {mustBePositive} = 25
        Amplitude (1,1) double {mustBePositive} = 3.0
        Gain      (1,1) double = 20
        WashoutHz (1,1) double {mustBePositive} = 5
        LowpassHz (1,1) double {mustBePositive} = 5
        SlewMax   (1,1) double {mustBePositive} = 400
    end

    properties (SetAccess = private)
        Vhat  (1,1) double = 0
        DcEst (1,1) double = 0
        Grad  (1,1) double = 0
        Primed (1,1) logical = false
    end

    methods
        function obj = ESC(opts)
            arguments
                opts.Ts        (1,1) double = 2e-4
                opts.DitherHz  (1,1) double = 25
                opts.Amplitude (1,1) double = 3.0
                opts.Gain      (1,1) double = 20
                opts.WashoutHz (1,1) double = 5
                opts.LowpassHz (1,1) double = 5
                opts.SlewMax   (1,1) double = 400
                opts.Vmin      (1,1) double = 20
                opts.Vmax      (1,1) double = 1e4
                opts.Name      (1,1) string = "ESC"
            end
            f = fieldnames(opts);
            for k = 1:numel(f)
                obj.(f{k}) = opts.(f{k});
            end
        end

        function g = gradientEstimate(obj)
            g = obj.Grad;
        end
    end

    methods (Access = protected)
        function onReset(obj, V0)
            obj.Vhat   = V0;
            obj.DcEst  = 0;
            obj.Grad   = 0;
            obj.Primed = false;
        end

        function v = advance(obj, V, I, t)
            P  = V * I;
            wh = 2 * pi * obj.WashoutHz;
            wl = 2 * pi * obj.LowpassHz;
            w  = 2 * pi * obj.DitherHz;

            if ~obj.Primed
                obj.DcEst  = P;
                obj.Primed = true;
            end

            obj.DcEst = obj.DcEst + obj.Ts * wh * (P - obj.DcEst);
            xi        = P - obj.DcEst;

            demod    = xi * sin(w * t);
            obj.Grad = obj.Grad + obj.Ts * wl * (demod - obj.Grad);

            rate = obj.Gain * obj.Grad;
            rate = min(max(rate, -obj.SlewMax), obj.SlewMax);
            obj.Vhat = obj.Vhat + obj.Ts * rate;
            obj.Vhat = min(max(obj.Vhat, obj.Vmin), obj.Vmax);

            v = obj.Vhat + obj.Amplitude * sin(w * (t + obj.Ts));
        end
    end
end
