function plot_last_run()

    names = ["vpv" "iL" "ipv" "duty" "vref" "Girr"];
    src = "";

    if evalin("base", "exist('out','var')") == 1
        o = evalin("base", "out");
        if all(arrayfun(@(n) isprop(o, n) || isfield(o, n), names))
            src = "out";
        end
    end
    if src == "" && all(arrayfun( ...
            @(n) evalin("base", "exist('" + n + "','var')") == 1, names))
        src = "base";
    end
    if src == ""
        error("mpptlab:plot:noData", ...
            ["No logged signals found. Run the model first, either with the " ...
             "green Run button or by typing  out = sim('mppt_boost_switched')."]);
    end

    if src == "out"
        g = @(n) o.(n);
    else
        g = @(n) evalin("base", n);
    end
    vpv  = g("vpv");   iL   = g("iL");    ipv = g("ipv");
    duty = g("duty");  vref = g("vref");  G   = g("Girr");

    t  = vpv.time(:);
    V  = vpv.signals.values(:);
    I  = interp1(iL.time(:),   iL.signals.values(:),   t, "linear", "extrap");
    Ip = interp1(ipv.time(:),  ipv.signals.values(:),  t, "linear", "extrap");
    D  = interp1(duty.time(:), duty.signals.values(:), t, "previous", "extrap");
    Vr = interp1(vref.time(:), vref.signals.values(:), t, "previous", "extrap");
    Gi = interp1(G.time(:),    G.signals.values(:),    t, "linear", "extrap");

    s = mpptlab.util.style();
    fig = figure(Color = "w");
    try, theme(fig, "light"); catch, end
    tl = tiledlayout(fig, 2, 2, TileSpacing = "compact", Padding = "compact");

    ax1 = nexttile(tl); hold(ax1, "on");
    plot(ax1, t, V,  Color = s.Cat(1,:), LineWidth = 1.0);
    plot(ax1, t, Vr, Color = s.Cat(2,:), LineWidth = 1.4);
    mpptlab.util.finish(ax1, XLabel = "time (s)", YLabel = "voltage (V)", ...
        Title = "PV voltage and MPPT reference", ...
        Legend = ["v_{pv} (switched)" "MPPT reference"], LegendLocation = "southeast");

    ax2 = nexttile(tl); hold(ax2, "on");
    plot(ax2, t, V .* Ip, Color = s.Cat(1,:), LineWidth = 1.0);
    mpptlab.util.finish(ax2, XLabel = "time (s)", YLabel = "PV power (W)", ...
        Title = "Harvested power");

    ax3 = nexttile(tl); hold(ax3, "on");
    plot(ax3, t, I, Color = s.Cat(3,:), LineWidth = 0.8);
    mpptlab.util.finish(ax3, XLabel = "time (s)", YLabel = "inductor current (A)", ...
        Title = "Inductor current with 20 kHz ripple");

    ax4 = nexttile(tl); hold(ax4, "on");
    yyaxisDisabled = true;
    plot(ax4, t, Gi, Color = s.Reference, LineWidth = 1.4);
    mpptlab.util.finish(ax4, XLabel = "time (s)", YLabel = "irradiance (W/m^2)", ...
        Title = "Applied irradiance profile");

    fprintf("\nRun summary\n");
    fprintf("  duration        : %.3f s\n", t(end));
    fprintf("  mean PV power   : %.1f W\n", mean(V .* Ip));
    fprintf("  final v_pv      : %.2f V\n", V(end));
    fprintf("  final duty      : %.4f\n", D(end));
    fprintf("  irradiance range: %.0f to %.0f W/m^2\n\n", min(Gi), max(Gi));
end
