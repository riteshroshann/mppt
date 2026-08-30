clear; clc; close all;

here = fileparts(mfilename("fullpath"));
addpath(fullfile(fileparts(here), "matlab"));
startup_mpptlab();
addpath(here);

cfg = mpptlab.util.config();
pv  = cfg.pv; bc = cfg.boost; K = cfg.gains;
s   = mpptlab.util.style();

fprintf("=== Switched Simscape model: build and validation ===\n");

mdl = build_mppt_model(Save = true);
fprintf("Built and saved %s.slx\n\n", mdl);

Cpv = bc.Cpv;  Co = bc.Co;  Lboost = bc.L;  RL = bc.RL;  Vdc = bc.Vdc;
Tsw = 1 / bc.fsw;  Tctrl = Tsw;
Rds_on = 5e-3;  G_off = 1e-8;
Vf_diode = 0.7;  Ron_diode = 10e-3;
Tcell  = 298.15;

IphRef = cfg.ref.IphRef;  I0Ref = cfg.ref.I0Ref;   RsRef = cfg.ref.RsRef;
RshRef = cfg.ref.RshRef;  aRef  = cfg.ref.aRef;    alphaIscPV = cfg.ref.alphaIsc;
EgRef  = cfg.ref.EgRef;   NsMod = cfg.NsMod;       NpStr = cfg.NpStr;

pv.G = 1000; pv.Tc = Tcell;
p = pv.params();
[Vmp, Imp, Pmp] = pv.mpp(p);
opAn = bc.operatingPoint(pv, Vmp, p);

fprintf("--- Test 1: open-loop fixed duty, switched vs averaged ---\n");
Vpv0 = Vmp;  IL0 = Imp;
dFixed   = opAn.D;
ctrlMode = -1;
kvec = [K.KpI; K.KiI; K.KpV; K.KiV; Tctrl; bc.dMin; bc.dMax; 40; ...
        round(20e-3/Tctrl); 1.5; Vmp; 20; 250; dFixed; IL0];
Tstop = 0.10;
Gts = timeseries([1000; 1000], [0; Tstop]);

out1 = sim(mdl);
[t1, v1, i1, ip1] = unpackLogs(out1);
w  = t1 > 0.8 * Tstop;
vAvg = mean(v1(w));  iAvg = mean(i1(w));
vRip = max(v1(w)) - min(v1(w));  iRip = max(i1(w)) - min(i1(w));

fprintf("duty held at %.4f\n", dFixed);
fprintf("                       switched      averaged/analytic    error\n");
fprintf("  v_pv mean   (V)   %10.3f  %15.3f   %8.3f %%\n", vAvg, Vmp, 100*(vAvg-Vmp)/Vmp);
fprintf("  i_L  mean   (A)   %10.3f  %15.3f   %8.3f %%\n", iAvg, Imp, 100*(iAvg-Imp)/Imp);
fprintf("  i_L  ripple (A)   %10.3f  %15.3f   %8.3f %%\n", iRip, opAn.iLRipple, ...
    100*(iRip-opAn.iLRipple)/opAn.iLRipple);
fprintf("  v_pv ripple (V)   %10.4f  %15.4f\n", vRip, opAn.vpvRipple);
fprintf("  P_pv mean   (W)   %10.2f  %15.2f\n", mean(v1(w).*ip1(w)), Pmp);

fprintf("\n--- Test 2: closed loop with P&O through an irradiance step ---\n");
Tstop = 1.2;
Gts = timeseries([1000; 1000; 500; 500], [0; 0.5; 0.5001; Tstop]);
ctrlMode = 1;
Vpv0 = Vmp;  IL0 = Imp;
kvec(14) = opAn.D;  kvec(15) = IL0;

tic; out2 = sim(mdl); wall = toc;
[t2, v2, i2, ip2, d2, vr2, g2] = unpackLogs(out2);
fprintf("simulated %.2f s of switched circuit in %.1f s wall\n", Tstop, wall);

Ggrid = linspace(400, 1100, 120);
Pgrid = zeros(size(Ggrid));
for k = 1:numel(Ggrid)
    pv.G = Ggrid(k);
    [~, ~, Pgrid(k)] = pv.mpp();
end
g2c   = min(max(g2, Ggrid(1)), Ggrid(end));
Pmpp2 = interp1(Ggrid, Pgrid, g2c, "pchip");

fprintf("samples = %d | logged G range = [%.1f, %.1f] W/m^2\n", numel(t2), min(g2), max(g2));
fprintf("harvested = [%.1f, %.1f] W | available = [%.1f, %.1f] W\n", ...
    min(v2.*ip2), max(v2.*ip2), min(Pmpp2), max(Pmpp2));

keep = t2 > 0.10;
eta = trapz(t2(keep), v2(keep).*ip2(keep)) / trapz(t2(keep), Pmpp2(keep));
fprintf("switched-circuit MPPT efficiency (t > 100 ms): %.4f %%\n", 100*eta);

fig = mpptlab.util.newfig();
tl  = tiledlayout(fig, 2, 2, TileSpacing = "compact", Padding = "compact");

axA = nexttile(tl); hold(axA, "on");
plot(axA, t1*1e3, i1, Color = s.Cat(1,:), LineWidth = 1.0);
yline(axA, Imp, Color = s.Reference, LineStyle = "--", LineWidth = 1.4);
xlim(axA, [90 95]);
mpptlab.util.finish(axA, XLabel = "time (ms)", YLabel = "inductor current (A)", ...
    Title = "Switching ripple at fixed duty", ...
    Legend = ["switched circuit" "averaged model"], LegendLocation = "southeast");

axB = nexttile(tl); hold(axB, "on");
plot(axB, t1*1e3, v1, Color = s.Cat(1,:), LineWidth = 1.0);
yline(axB, Vmp, Color = s.Reference, LineStyle = "--", LineWidth = 1.4);
xlim(axB, [90 95]);
mpptlab.util.finish(axB, XLabel = "time (ms)", YLabel = "v_{pv} (V)", ...
    Title = "PV voltage ripple across C_{pv}", ...
    Legend = ["switched circuit" "averaged model"], LegendLocation = "southeast");

axC = nexttile(tl); hold(axC, "on");
plot(axC, t2, v2, Color = s.Cat(1,:), LineWidth = 1.0);
plot(axC, t2, vr2, Color = s.Cat(2,:), LineWidth = 1.4);
ylim(axC, [120 180]);
mpptlab.util.finish(axC, XLabel = "time (s)", YLabel = "voltage (V)", ...
    Title = "Closed-loop P&O on the switched circuit", ...
    Legend = ["v_{pv} (switched)" "MPPT reference"], LegendLocation = "southeast");

axD = nexttile(tl); hold(axD, "on");
plot(axD, t2, Pmpp2, Color = s.Reference, LineStyle = "--", LineWidth = 1.4);
plot(axD, t2, v2.*ip2, Color = s.Cat(1,:), LineWidth = 1.0);
mpptlab.util.finish(axD, XLabel = "time (s)", YLabel = "PV power (W)", ...
    Title = "Harvested power versus the available maximum", ...
    Legend = ["available P_{mp}" "harvested"], LegendLocation = "east");

mpptlab.util.savefig(fig, "s06_switched_validation", Width = 11, Height = 8);

root = mpptlab.util.projectRoot();
validation = struct("vAvg", vAvg, "vRef", Vmp, "iAvg", iAvg, "iRef", Imp, ...
    "iRipple", iRip, "iRippleAnalytic", opAn.iLRipple, ...
    "vRipple", vRip, "vRippleAnalytic", opAn.vpvRipple, ...
    "etaSwitched", eta, "duty", dFixed);
save(fullfile(root, "results", "data", "s06_switched.mat"), "validation");
fprintf("\nSaved figure and results/data/s06_switched.mat\n");

function [t, v, i, ip, d, vr, g] = unpackLogs(out)
    v  = out.vpv.signals.values(:);
    t  = out.vpv.time(:);
    i  = interp1(out.iL.time(:),   out.iL.signals.values(:),   t, "linear", "extrap");
    ip = interp1(out.ipv.time(:),  out.ipv.signals.values(:),  t, "linear", "extrap");
    if nargout > 4
        d  = interp1(out.duty.time(:), out.duty.signals.values(:), t, "previous", "extrap");
        vr = interp1(out.vref.time(:), out.vref.signals.values(:), t, "previous", "extrap");
        g  = interp1(out.Girr.time(:), out.Girr.signals.values(:), t, "linear", "extrap");
    end
end
