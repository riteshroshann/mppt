function file = savefig(fig, name, opts)

    arguments
        fig
        name (1,1) string
        opts.Width  (1,1) double = 9.0
        opts.Height (1,1) double = 6.0
        opts.Formats (1,:) string = ["png" "pdf"]
    end

    root = mpptlab.util.projectRoot();
    dest = fullfile(root, "results", "figures");
    if ~isfolder(dest)
        mkdir(dest);
    end

    fig.Color = "w";
    fig.Units = "inches";
    fig.Position(3:4) = [opts.Width opts.Height];
    fig.PaperUnits = "inches";
    fig.PaperSize = [opts.Width opts.Height];
    fig.PaperPosition = [0 0 opts.Width opts.Height];

    file = strings(0, 1);
    for f = opts.Formats
        target = fullfile(dest, name + "." + f);
        exportgraphics(fig, target, Resolution = 200);
        file(end+1) = target;
    end
end
