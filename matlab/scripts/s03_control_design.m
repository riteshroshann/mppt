clear; clc; close all;
startup_mpptlab();

cfg = mpptlab.util.config();
pv  = cfg.pv;
bc  = cfg.boost;
K   = cfg.gains;
s   = mpptlab.util.style();

fprintf("=== s03  Cascaded control design ===\n");
fprintf("Inner current loop : fc = %.0f Hz, Kp = %.5f, Ki = %.2f\n", K.fci, K.KpI, K.KiI);
fprintf("Outer voltage loop : fc = %.0f Hz, Kp = %.5f, Ki = %.2f\n", K.fcv, K.KpV, K.KiV);
fprintf("Timescale separation: inner/outer = %.1f, fsw/inner = %.1f\n\n", ...
    K.separationRatio, K.switchingMargin);

[KpS, KiS, infoS] = mpptlab.ctrl.designSingleLoopPI(bc, pv, fc = 130, ZeroRatio = 5);
fprintf("Single-loop PI baseline (nominal design at STC MPP, target fc = 130 Hz)\n");
fprintf("  Kp = %.4e, Ki = %.4e, zero at %.1f Hz\n", KpS, KiS, infoS.zeroHz);
fprintf("  achieved: %d gain crossovers at [%s] Hz, min PM = %.1f deg\n\n", ...
    infoS.crossovers, join(compose("%.0f", infoS.crossoverHz(:)'), ", "), infoS.achievedPM);

Rg = mpptlab.ctrl.loopAnalysis(bc, pv, K, Glist = [200 400 600 800 1000], ...
    SingleLoopKp = KpS, SingleLoopKi = KiS);
Rv = mpptlab.ctrl.loopAnalysis(bc, pv, K, Glist = 1000, At = "vocfrac", ...
    VFrac = [0.35 0.45 0.55 0.65 0.70 0.75 0.80 0.85 0.90 0.95], ...
    SingleLoopKp = KpS, SingleLoopKi = KiS);

fprintf("Margins at the MPP across irradiance\n");
disp(Rg.table(:, ["G" "rd" "zetaPlant" "pmI_deg" "fcI" "pmV_deg" "fcV" "pmS_deg" "nCrossS" "stableS"]));
fprintf("\nMargins across the I-V curve at G = 1000\n");
disp(Rv.table(:, ["V" "rd" "zetaPlant" "pmI_deg" "pmV_deg" "fcV" "pmS_deg" "nCrossS" "peakLs"]));

fprintf("\nCascade   : worst inner PM %.1f deg, worst outer PM %.1f deg\n", ...
    min([Rg.worstPmI Rv.worstPmI]), min([Rg.worstPmV Rv.worstPmV]));
fprintf("Single PI : worst PM %.1f deg\n", min([Rg.worstPmS Rv.worstPmS]));

pv.G = 1000; pv.Tc = 298.15;
p   = pv.params();
Voc = pv.voc(p);
Vmp = pv.mpp(p);
Vset = [0.35 0.55 0.70 Vmp/Voc 0.88] * Voc;
Cv  = mpptlab.util.seq(numel(Vset));
w   = 2 * pi * logspace(0, 4.3, 800);
sv  = tf("s");
Ci  = K.KpI + K.KiI / sv;
Cvo = K.KpV + K.KiV / sv;
Cs  = KpS + KiS / sv;

fig = mpptlab.util.newfig();
tl  = tiledlayout(fig, 2, 2, TileSpacing = "compact", Padding = "compact");

axA = nexttile(tl); hold(axA, "on");
axB = nexttile(tl); hold(axB, "on");
for k = 1:numel(Vset)
    sys = bc.linearize(pv, Vset(k), p);
    Ls  = -Cs * tf(sys(1));
    Lv  = -Cvo * series(feedback(Ci, tf(sys(2))), tf(sys(1)));
    plot(axA, w/(2*pi), 20*log10(squeeze(bode(Ls, w))), Color = Cv(k,:), LineWidth = s.LineWidth);
    plot(axB, w/(2*pi), 20*log10(squeeze(bode(Lv, w))), Color = Cv(k,:), LineWidth = s.LineWidth);
end
yline(axA, 0, Color = s.Reference, LineStyle = "--");
yline(axB, 0, Color = s.Reference, LineStyle = "--");
mpptlab.util.finish(axA, XLabel = "frequency (Hz)", YLabel = "|L| (dB)", ...
    Title = "Single-loop PI: resonance forces extra crossings", ...
    Legend = compose("%.0f V", Vset(:)'), LegendLocation = "southwest", XScale = "log");
mpptlab.util.finish(axB, XLabel = "frequency (Hz)", YLabel = "|L| (dB)", ...
    Title = "Cascade outer loop: single clean crossing", XScale = "log");

axC = nexttile(tl); hold(axC, "on");
plot(axC, Rv.table.V, Rv.table.pmS_deg, "-o", Color = s.Cat(2,:), ...
    LineWidth = s.LineWidth, MarkerFaceColor = "w", MarkerSize = s.MarkerSize);
plot(axC, Rv.table.V, Rv.table.pmV_deg, "-o", Color = s.Cat(1,:), ...
    LineWidth = s.LineWidth, MarkerFaceColor = "w", MarkerSize = s.MarkerSize);
yline(axC, 45, Color = s.Reference, LineStyle = "--");
text(axC, min(Rv.table.V), 50, "  45° design floor", Color = s.Muted, FontSize = s.FontSize - 1);
xline(axC, Vmp, Color = s.Reference, LineStyle = ":");
mpptlab.util.finish(axC, XLabel = "operating voltage (V)", YLabel = "phase margin (deg)", ...
    Title = "Robustness across the operating range", ...
    Legend = ["single-loop PI" "cascade outer loop"], LegendLocation = "northwest");

axD = nexttile(tl); hold(axD, "on");
tsim = linspace(0, 0.06, 1200);
for k = 1:numel(Vset)
    sys = bc.linearize(pv, Vset(k), p);
    Lv  = -Cvo * series(feedback(Ci, tf(sys(2))), tf(sys(1)));
    Tcl = feedback(Lv, 1);
    plot(axD, tsim*1e3, step(Tcl, tsim), Color = Cv(k,:), LineWidth = s.LineWidth);
end
yline(axD, 1, Color = s.Reference, LineStyle = "--");
mpptlab.util.finish(axD, XLabel = "time (ms)", YLabel = "normalised v_{pv} response", ...
    Title = "Closed-loop reference step, cascade", ...
    Legend = compose("%.0f V", Vset(:)'), LegendLocation = "southeast");

mpptlab.util.savefig(fig, "s03_control_design", Width = 11, Height = 8);

root = mpptlab.util.projectRoot();
Tg = Rg.table; Tv = Rv.table;
save(fullfile(root, "results", "data", "s03_control.mat"), "Tg", "Tv", "K", "KpS", "KiS");
fprintf("\nSaved figure and results/data/s03_control.mat\n");
