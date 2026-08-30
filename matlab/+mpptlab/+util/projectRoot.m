function root = projectRoot()

    here = fileparts(mfilename("fullpath"));
    root = fileparts(fileparts(fileparts(here)));
end
