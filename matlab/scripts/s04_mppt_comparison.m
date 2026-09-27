clear; clc; close all;
startup_mpptlab();

cfg = mpptlab.util.config();
pv  = cfg.pv; bc = cfg.boost; K = cfg.gains;
s   = mpptlab.util.style();

fprintf("=== s04  MPPT algorithm comparison ===\n");

names = ["P&O" "P&O adaptive" "IncCond" "ESC"];
prof  = mpptlab.bench.irradiance("step", G0 = 1000, G1 = 500, StepTime = 1.0, Duration = 2.5);
fprintf("Profile: %s\n\n", prof.Name);

runs = cell(1, numel(names));
rows = [];
for k = 1:numel(names)
    tr = mpptlab.bench.trackerSet(names(k), Tmppt = 20e-3, Step = 1.5);
    o  = mpptlab.bench.simulate(pv, bc, tr{1}, K, prof, ...
        V0 = 157.8, ScoreFrom = 0.2, RecordEvery = 10);
    runs{k} = o;
    tail = o.vpv(o.t > 2.2);
    m = o.metrics;
    rows = [rows; 100*m.etaMppt, m.rmsTrackErrorV, max(tail)-min(tail), ...
            m.maxPowerDeficit, o.WallTime];
    fprintf("%-14s eta = %7.4f %%   rms err = %6.2f V   ripple = %5.2f V   worst deficit = %7.1f W\n", ...
        names(k), 100*m.etaMppt, m.rmsTrackErrorV, max(tail)-min(tail), m.maxPowerDeficit);
end
Tcmp = array2table(rows, VariableNames = ["eta_pct" "rmsErrV" "rippleV" "maxDeficitW" "wallS"], ...
    RowNames = cellstr(names));

fig = mpptlab.util.newfig();
tl  = tiledlayout(fig, 2, 2, TileSpacing = "compact", Padding = "compact");

axA = nexttile(tl); hold(axA, "on");
plot(axA, runs{1}.t, runs{1}.Vmpp, Color = s.Reference, LineStyle = "--", LineWidth = 1.4);
for k = 1:numel(names)
    plot(axA, runs{k}.t, runs{k}.vpv, Color = s.Cat(k,:), LineWidth = s.LineWidth);
end
xlim(axA, [0.9 2.0]);
mpptlab.util.finish(axA, XLabel = "time (s)", YLabel = "v_{pv} (V)", ...
    Title = "Tracking through a 1000 to 500 W/m^2 step", ...
    Legend = ["true V_{mp}", names], LegendLocation = "southeast");

axB = nexttile(tl); hold(axB, "on");
plot(axB, runs{1}.t, runs{1}.Pmpp, Color = s.Reference, LineStyle = "--", LineWidth = 1.4);
for k = 1:numel(names)
    plot(axB, runs{k}.t, runs{k}.ppv, Color = s.Cat(k,:), LineWidth = s.LineWidth);
end
xlim(axB, [0.95 1.4]);
mpptlab.util.finish(axB, XLabel = "time (s)", YLabel = "array power (W)", ...
    Title = "Power recovery after the step", ...
    Legend = ["available P_{mp}", names], LegendLocation = "northeast");

axC = nexttile(tl); hold(axC, "on");
plot(axC, runs{1}.t, runs{1}.Vmpp, Color = s.Reference, LineStyle = "--", LineWidth = 1.4);
for k = 1:numel(names)
    plot(axC, runs{k}.t, runs{k}.vpv, Color = s.Cat(k,:), LineWidth = s.LineWidth);
end
xlim(axC, [2.2 2.5]);
mpptlab.util.finish(axC, XLabel = "time (s)", YLabel = "v_{pv} (V)", ...
    Title = "Steady-state behaviour at 500 W/m^2", ...
    Legend = ["true V_{mp}", names], LegendLocation = "southeast");

fprintf("\n--- P&O step-size trade-off at constant 1000 W/m^2 (start 120 V) ---\n");
steps = [0.5 1 1.5 2 3 4 6];
sweep = zeros(numel(steps), 3);
profC = mpptlab.bench.irradiance("constant", G0 = 1000, Duration = 3.0);
for k = 1:numel(steps)
    po = mpptlab.mppt.PandO(Ts = 20e-3, Step = steps(k));
    o  = mpptlab.bench.simulate(pv, bc, po, K, profC, V0 = 120, ...
        ScoreFrom = 2.0, RecordEvery = 20);
    tail  = o.vpv(o.t > 2.5);
    band  = 1.5 * steps(k);
    first = find(abs(o.vpv - o.Vmpp) <= band, 1, "first");
    tAcq  = o.t(first);
    sweep(k,:) = [100*o.metrics.etaMppt, max(tail)-min(tail), tAcq];
    fprintf("step = %4.1f V : steady eta = %7.4f %%  ripple = %5.2f V  acquisition = %5.3f s\n", ...
        steps(k), sweep(k,1), sweep(k,2), sweep(k,3));
end

axD = nexttile(tl); hold(axD, "on");
plot(axD, sweep(:,3), sweep(:,1), "-o", Color = s.Cat(1,:), LineWidth = s.LineWidth, ...
    MarkerFaceColor = "w", MarkerSize = s.MarkerSize);
for k = 1:numel(steps)
    text(axD, sweep(k,3), sweep(k,1), sprintf("  %.1f V", steps(k)), ...
        Color = s.Muted, FontSize = s.FontSize - 1, VerticalAlignment = "top");
end
mpptlab.util.finish(axD, XLabel = "acquisition time from 120 V (s)", ...
    YLabel = "steady-state MPPT efficiency (%)", ...
    Title = "P&O step size: a speed against accuracy frontier");

mpptlab.util.savefig(fig, "s04_mppt_comparison", Width = 11, Height = 8);

fprintf("\nSummary\n");
disp(Tcmp);

Tsweep = array2table([steps(:) sweep], ...
    VariableNames = ["stepV" "eta_pct" "rippleV" "acquisitionS"]);
root = mpptlab.util.projectRoot();
save(fullfile(root, "results", "data", "s04_mppt.mat"), "Tcmp", "Tsweep", "names");
fprintf("\nSaved figure and results/data/s04_mppt.mat\n");
