clear; clc; close all;
startup_mpptlab();

cfg = mpptlab.util.config();
pv  = cfg.pv; bc = cfg.boost; K = cfg.gains;
s   = mpptlab.util.style();
root = mpptlab.util.projectRoot();

fprintf("=== s05  Dynamic MPPT benchmark on EN 50530-style ramps ===\n");
fprintf("Trapezoidal irradiance between 300 and 1000 W/m^2, one up-down cycle per slope.\n");
fprintf("This script runs a few minutes; results are cached to results/data/s05_benchmark.mat\n\n");

names  = ["P&O" "P&O adaptive" "IncCond" "ESC"];
slopes = [25 50 100 200];

eta   = zeros(numel(names), numel(slopes));
deficit = zeros(numel(names), numel(slopes));
traces = cell(numel(names), 1);
traceSlope = 100;

for j = 1:numel(slopes)
    prof = mpptlab.bench.irradiance("trapezoid", Glow = 300, Ghigh = 1000, ...
        Slope = slopes(j), Dwell = 1.0, Cycles = 1, Settle = 1.0);
    for i = 1:numel(names)
        tr = mpptlab.bench.trackerSet(names(i), Tmppt = 20e-3, Step = 1.5);
        o  = mpptlab.bench.simulate(pv, bc, tr{1}, K, prof, ...
            V0 = -1, ScoreFrom = 1.0, PlantStep = 1/bc.fsw, RecordEvery = 20);
        eta(i,j) = 100 * o.metrics.etaMppt;
        deficit(i,j) = o.metrics.maxPowerDeficit;
        if slopes(j) == traceSlope
            traces{i} = o;
        end
        fprintf("slope %3d W/m^2/s | %-14s eta = %7.4f %%  (%.0f s sim, %.0f s wall)\n", ...
            slopes(j), names(i), eta(i,j), prof.Duration, o.WallTime);
    end
end

Teta = array2table(eta, VariableNames = compose("slope_%d", slopes), ...
    RowNames = cellstr(names));
fprintf("\nDynamic MPPT efficiency (%%)\n");
disp(Teta);

fig = mpptlab.util.newfig();
tl  = tiledlayout(fig, 2, 2, TileSpacing = "compact", Padding = "compact");

axA = nexttile(tl); hold(axA, "on");
for i = 1:numel(names)
    plot(axA, slopes, eta(i,:), "-o", Color = s.Cat(i,:), LineWidth = s.LineWidth, ...
        MarkerFaceColor = "w", MarkerSize = s.MarkerSize);
end
mpptlab.util.finish(axA, XLabel = "irradiance ramp rate (W/m^2/s)", ...
    YLabel = "dynamic MPPT efficiency (%)", ...
    Title = "Efficiency falls as the ramp outruns the tracker", ...
    Legend = names, LegendLocation = "southwest");

axB = nexttile(tl); hold(axB, "on");
tr0 = traces{1};
plot(axB, tr0.t, tr0.G, Color = s.Reference, LineWidth = s.LineWidth);
mpptlab.util.finish(axB, XLabel = "time (s)", YLabel = "irradiance (W/m^2)", ...
    Title = sprintf("Test profile at %d W/m^2/s", traceSlope));

axC = nexttile(tl); hold(axC, "on");
plot(axC, tr0.t, tr0.Vmpp, Color = s.Reference, LineStyle = "--", LineWidth = 1.4);
for i = 1:numel(names)
    plot(axC, traces{i}.t, traces{i}.vpv, Color = s.Cat(i,:), LineWidth = s.LineWidth);
end
mpptlab.util.finish(axC, XLabel = "time (s)", YLabel = "v_{pv} (V)", ...
    Title = "Voltage tracking through the ramp", ...
    Legend = ["true V_{mp}", names], LegendLocation = "southeast");

axD = nexttile(tl); hold(axD, "on");
for i = 1:numel(names)
    plot(axD, traces{i}.t, traces{i}.Pmpp - traces{i}.ppv, ...
        Color = s.Cat(i,:), LineWidth = s.LineWidth);
end
yline(axD, 0, Color = s.Reference, LineStyle = "--");
mpptlab.util.finish(axD, XLabel = "time (s)", YLabel = "power deficit P_{mp} - P (W)", ...
    Title = "Instantaneous harvest shortfall", Legend = names, LegendLocation = "northwest");

mpptlab.util.savefig(fig, "s05_dynamic_benchmark", Width = 11, Height = 8);

Tdef = array2table(deficit, VariableNames = compose("slope_%d", slopes), ...
    RowNames = cellstr(names));
fprintf("\nWorst instantaneous power deficit (W)\n");
disp(Tdef);

save(fullfile(root, "results", "data", "s05_benchmark.mat"), ...
    "Teta", "Tdef", "eta", "deficit", "slopes", "names");
fprintf("\nSaved figure and results/data/s05_benchmark.mat\n");
