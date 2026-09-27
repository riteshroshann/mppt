clear; clc; close all;
startup_mpptlab();

cfg = mpptlab.util.config();
pv  = cfg.pv;
s   = mpptlab.util.style();

fprintf("=== s01  PV characterisation ===\n");
fprintf("Module   : %s\n", cfg.datasheet.Name);
fprintf("Array    : %s\n", pv.Name);
fprintf("Fit error: max %.3g %% across the five datasheet constraints\n", cfg.fit.maxAbsErrorPct);
disp(cfg.fit.table);

fprintf("\nExtracted reference parameters (module level)\n");
fprintf("  Iph = %10.5f A\n  I0  = %10.4e A\n  Rs  = %10.5f ohm\n  Rsh = %10.4f ohm\n  a   = %10.5f V  (n = %.4f)\n", ...
    cfg.ref.IphRef, cfg.ref.I0Ref, cfg.ref.RsRef, cfg.ref.RshRef, cfg.ref.aRef, cfg.ref.n);

Glist = [200 400 600 800 1000];
Tlist = [15 25 45 65];
Cg = mpptlab.util.seq(numel(Glist));
Ct = mpptlab.util.seq(numel(Tlist));

fig = mpptlab.util.newfig();
tl = tiledlayout(fig, 2, 2, TileSpacing = "compact", Padding = "compact");

ax1 = nexttile(tl); hold(ax1, "on");
ax2 = nexttile(tl); hold(ax2, "on");
pv.Tc = 298.15;
mppG = zeros(numel(Glist), 3);
for k = 1:numel(Glist)
    pv.G = Glist(k);
    t = pv.curve(500);
    plot(ax1, t.V, t.I, Color = Cg(k,:), LineWidth = s.LineWidth);
    plot(ax2, t.V, t.P, Color = Cg(k,:), LineWidth = s.LineWidth);
    [vm, im, pm] = pv.mpp();
    mppG(k,:) = [vm im pm];
end
plot(ax1, mppG(:,1), mppG(:,2), "o", Color = s.Ink, MarkerFaceColor = "w", ...
    MarkerSize = s.MarkerSize, LineWidth = 1.2);
plot(ax2, mppG(:,1), mppG(:,3), "o", Color = s.Ink, MarkerFaceColor = "w", ...
    MarkerSize = s.MarkerSize, LineWidth = 1.2);
mpptlab.util.finish(ax1, XLabel = "array voltage (V)", YLabel = "array current (A)", ...
    Title = "I-V at 25 °C", Legend = [compose("%g W/m^2", Glist), "MPP"], LegendLocation = "southwest");
mpptlab.util.finish(ax2, XLabel = "array voltage (V)", YLabel = "array power (W)", ...
    Title = "P-V at 25 °C", Legend = [compose("%g W/m^2", Glist), "MPP"], LegendLocation = "northwest");

ax3 = nexttile(tl); hold(ax3, "on");
pv.G = 1000;
mppT = zeros(numel(Tlist), 3);
for k = 1:numel(Tlist)
    pv.Tc = 273.15 + Tlist(k);
    t = pv.curve(500);
    plot(ax3, t.V, t.P, Color = Ct(k,:), LineWidth = s.LineWidth);
    [vm, im, pm] = pv.mpp();
    mppT(k,:) = [vm im pm];
end
plot(ax3, mppT(:,1), mppT(:,3), "o", Color = s.Ink, MarkerFaceColor = "w", ...
    MarkerSize = s.MarkerSize, LineWidth = 1.2);
mpptlab.util.finish(ax3, XLabel = "array voltage (V)", YLabel = "array power (W)", ...
    Title = "P-V at 1000 W/m^2", Legend = [compose("%g °C", Tlist), "MPP"], LegendLocation = "northwest");

ax4 = nexttile(tl); hold(ax4, "on");
pv.Tc = 298.15;
for k = 1:numel(Glist)
    pv.G = Glist(k);
    p = pv.params();
    Voc = pv.voc(p);
    V = linspace(0.02 * Voc, 0.995 * Voc, 400);
    rd = pv.dynamicResistance(V, p);
    plot(ax4, V, rd, Color = Cg(k,:), LineWidth = s.LineWidth);
end
plot(ax4, mppG(:,1), mppG(:,1) ./ mppG(:,2), "o", Color = s.Ink, ...
    MarkerFaceColor = "w", MarkerSize = s.MarkerSize, LineWidth = 1.2);
mpptlab.util.finish(ax4, XLabel = "array voltage (V)", YLabel = "r_d = -dV/dI (\Omega)", ...
    Title = "Dynamic resistance sets the plant gain", ...
    Legend = [compose("%g W/m^2", Glist), "r_d at MPP"], LegendLocation = "southwest", YScale = "log");

ylim(ax1, [0 inf]); ylim(ax2, [0 inf]); ylim(ax3, [0 inf]);
xlim(ax3, [0 210]);

mpptlab.util.savefig(fig, "s01_pv_characteristics", Width = 11, Height = 8);

pv.Tc = 298.15;
rows = [];
for k = 1:numel(Glist)
    pv.G = Glist(k);
    q = pv.operatingSummary();
    rows = [rows; q.G, q.Vmp, q.Imp, q.Pmp, q.Voc, q.Isc, q.FF, q.rdMpp];
end
T = array2table(rows, VariableNames = ["G" "Vmp" "Imp" "Pmp" "Voc" "Isc" "FF" "rd_mpp"]);
fprintf("\nArray operating points at 25 degC\n");
disp(T);

root = mpptlab.util.projectRoot();
save(fullfile(root, "results", "data", "s01_pv.mat"), "cfg", "T", "mppG", "mppT");
fprintf("\nSaved figure and results/data/s01_pv.mat\n");
