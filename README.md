# Solar Panel MPPT as a Control Problem

Feedback control of a photovoltaic array so it operates near maximum power
despite changing irradiance. MATLAB models and control analysis, plus a switched
Simscape circuit.

Requires MATLAB R2025a with Control System Toolbox, Simulink, Simscape and
Optimization Toolbox. Simscape Electrical is not needed.

## Run it

Open `SolarMPPT.prj` in MATLAB, then:

```matlab
verify_install               % check the setup works
run_all                      % full pipeline, ~11 min
runtests('matlab/tests')     % 27 unit tests
```

Individual studies: `s01_pv_characterisation`, `s02_plant_analysis`,
`s03_control_design`, `s04_mppt_comparison`, `s05_dynamic_benchmark`.

Switched circuit:

```matlab
setup_workspace("step")      % load parameters and open the model, then press Run
plot_last_run                % chart the result
```

## Layout

```
matlab/+mpptlab/    pv, conv, ctrl, mppt, bench, util
matlab/scripts/     s01..s05 analysis scripts
matlab/tests/       27 unit tests
simulink/           switched Simscape model, built by build_mppt_model.m
results/            generated figures and data
docs/report/        Solar_MPPT_Control_Report.pdf
```

## Results

Three-layer control hierarchy: inner current loop at 2 kHz, PV voltage loop at
250 Hz, MPPT at 50 Hz.

- Five-parameter PV model matches the KC200GT datasheet to machine precision.
- Plant damping varies 44x across the I-V curve. A single PI loop degrades to
  1.5 degrees phase margin; the cascade holds above 85 degrees everywhere.
- The duty-to-power gain is zero at the maximum power point, which is why MPPT
  must estimate a gradient rather than regulate a value.
- Extremum seeking holds 99.85 % on EN 50530 ramps at every rate; the
  hill-climbers fall to 99.46 %.
- Switched circuit agrees with the averaged model to 0.23 % in voltage.

Full detail in `docs/report/Solar_MPPT_Control_Report.pdf` (93 pages).
