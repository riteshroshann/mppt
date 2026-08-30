function root = startup_mpptlab()

    here = fileparts(mfilename("fullpath"));
    root = fileparts(here);

    addpath(here);
    addpath(fullfile(here, "scripts"));
    addpath(fullfile(here, "tests"));

    if nargout == 0
        fprintf("mpptlab on path. Project root: %s\n", root);
        clear root
    end
end
