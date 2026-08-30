function fig = newfig(opts)

    arguments
        opts.Visible (1,1) matlab.lang.OnOffSwitchState = "off"
    end

    fig = figure(Visible = opts.Visible, Color = "w");
    try
        theme(fig, "light");
    catch
    end
    set(fig, "InvertHardcopy", "off");
end
