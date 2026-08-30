function finish(ax, opts)

    arguments
        ax
        opts.XLabel (1,1) string = ""
        opts.YLabel (1,1) string = ""
        opts.Title  (1,1) string = ""
        opts.Legend (1,:) string = string.empty
        opts.LegendLocation (1,1) string = "best"
        opts.XScale (1,1) string = "linear"
        opts.YScale (1,1) string = "linear"
    end

    s = mpptlab.util.style();
    for a = reshape(ax, 1, [])
        grid(a, "on");
        a.Color = "w";
        a.GridColor = s.Grid;
        a.GridAlpha = 0.9;
        a.MinorGridColor = s.Grid;
        a.MinorGridAlpha = 0.5;
        a.Box = "off";
        a.Toolbar = [];
        a.FontSize = s.FontSize;
        a.XColor = s.Muted;
        a.YColor = s.Muted;
        a.LineWidth = 0.75;
        a.XScale = opts.XScale;
        a.YScale = opts.YScale;
        if opts.XLabel ~= "", xlabel(a, opts.XLabel, Color = s.Ink); end
        if opts.YLabel ~= "", ylabel(a, opts.YLabel, Color = s.Ink); end
        if opts.Title  ~= "", title(a, opts.Title, Color = s.Ink, FontWeight = "bold"); end
        if ~isempty(opts.Legend)
            lg = legend(a, opts.Legend, Location = opts.LegendLocation);
            lg.Box = "off";
            lg.TextColor = s.Ink;
            lg.Color = "w";
            lg.FontSize = s.FontSize - 1;
        end
    end
end
