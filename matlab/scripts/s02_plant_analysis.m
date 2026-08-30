clear; clc; close all;
startup_mpptlab();

cfg = mpptlab.util.config();
pv  = cfg.pv;
bc  = cfg.boost;
s   = mpptlab.util.style();

fprintf("=== s02  Small-signal plant analysis ===\n");
fprintf("Converter: L = %.2f mH, Cpv = %.0f uF, RL = %.2f ohm, Vdc = %.0f V, fsw = %.0f kHz\n", ...
    bc.L*1e3, bc.Cpv*1e6, bc.RL, bc.Vdc, bc.fsw/1e3);
fprintf("LC corner: %.1f Hz\n\n", 1/(2*pi*sqrt(bc.L*bc.Cpv)));

pv.G = 1000; pv.Tc = 298.15;
p    = pv.params();
Voc  = pv.voc(p);
Vmp  = pv.mpp(p);
Vset = [0.35 0.55 0.70 Vmp/Voc 0.88 0.95] * Voc;
labels = compose("%.0f V", Vset(:)');
Cv = mpptlab.util.seq(numel(Vset));

w = 2 * pi * logspace(0, 4.3, 800);

fig = mpptlab.util.newfig();
tl  = tiledlayout(fig, 2, 2, TileSpacing = "compact", Padding = "compact");

axA = nexttile(tl); hold(axA, "on");
axB = nexttile(tl); hold(axB, "on");
zetas = zeros(size(Vset));
for k = 1:numel(Vset)
    [sys, op] = bc.linearize(pv, Vset(k), p);
    zetas(k) = bc.modalProperties(op).zeta;
    [mag, ph] = bode(-tf(sys(1)), w);
    plot(axA, w/(2*pi), 20*log10(squeeze(mag)), Color = Cv(k,:), LineWidth = s.LineWidth);
    plot(axB, w/(2*pi), squeeze(ph), Color = Cv(k,:), LineWidth = s.LineWidth);
end
mpptlab.util.finish(axA, XLabel = "frequency (Hz)", YLabel = "|G_{vd}| (dB)", ...
    Title = "Duty to PV voltage, G = 1000 W/m^2", Legend = labels, ...
    LegendLocation = "southwest", XScale = "log");
mpptlab.util.finish(axB, XLabel = "frequency (Hz)", YLabel = "phase (deg)", ...
    Title = "Resonance peak grows as r_d grows", XScale = "log");

axC = nexttile(tl); hold(axC, "on");
for k = 1:numel(Vset)
    sys = bc.linearize(pv, Vset(k), p);
    mag = bode(tf(sys(2)), w);
    plot(axC, w/(2*pi), 20*log10(squeeze(mag)), Color = Cv(k,:), LineWidth = s.LineWidth);
end
mpptlab.util.finish(axC, XLabel = "frequency (Hz)", YLabel = "|G_{id}| (dB)", ...
    Title = "Duty to inductor current is nearly invariant", XScale = "log");

axD = nexttile(tl); hold(axD, "on");
Vg = linspace(0.2*Voc, 0.99*Voc, 300);
dc = zeros(size(Vg));
for k = 1:numel(Vg)
    [sys, op] = bc.linearize(pv, Vg(k), p);
    dc(k) = dcgain(tf(sys(3)));
end
plot(axD, Vg, dc, Color = s.Cat(1,:), LineWidth = s.LineWidth);
yline(axD, 0, Color = s.Reference, LineStyle = "--", LineWidth = 1.0);
xline(axD, Vmp, Color = s.Reference, LineStyle = ":", LineWidth = 1.2);
text(axD, Vmp, max(dc)*0.6, sprintf("  V_{mp} = %.1f V", Vmp), Color = s.Ink, FontSize = s.FontSize);
mpptlab.util.finish(axD, XLabel = "operating voltage (V)", YLabel = "dc gain, duty to power (W)", ...
    Title = "Loop gain on power vanishes and flips sign at the MPP");

mpptlab.util.savefig(fig, "s02_plant_frequency_response", Width = 11, Height = 8);

[~, ops] = bc.envelope(pv, [200 400 600 800 1000]);
Tenv = bc.envelopeTable(ops);
fprintf("Operating envelope at the MPP\n");
disp(Tenv);

Tcurve = table(Vset(:), Vset(:)/Voc, zetas(:), ...
    VariableNames = ["V" "V_over_Voc" "zeta"]);
fprintf("\nDamping across the I-V curve at G = 1000\n");
disp(Tcurve);
fprintf("Damping ratio varies by a factor of %.0f across the curve.\n", max(zetas)/min(zetas));

root = mpptlab.util.projectRoot();
save(fullfile(root, "results", "data", "s02_plant.mat"), "Tenv", "Tcurve", "Vg", "dc");
fprintf("\nSaved figure and results/data/s02_plant.mat\n");
