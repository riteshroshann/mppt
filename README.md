# Solar Panel Maximum Power Point Tracking as a Control Problem

Feedback control of a photovoltaic array so that it operates near its maximum
power point despite changing irradiance and cell temperature.

The project treats MPPT as a **three-layer control hierarchy** rather than as an
isolated search algorithm:

| Layer | Job | Bandwidth |
|---|---|---|
| Inner loop | regulate inductor current | 2 kHz |
| Outer loop | regulate PV terminal voltage to a reference | 250 Hz |
| MPPT layer | move that reference to the power maximum | 50 Hz (20 ms) |

---

## What is here

```
matlab/
  +mpptlab/
    +pv/      PVArray, extractParams, datasheet     five-parameter PV model
    +conv/    Boost                                 averaged converter + linearisation
    +ctrl/    designCascade, loopAnalysis, PI       control design and margin analysis
    +mppt/    PandO, IncCond, ESC, Tracker          MPPT algorithms
    +bench/   simulate, irradiance, trackerSet      closed-loop benchmark harness
    +util/    config, style, figure helpers
  scripts/    s01 .. s05 analysis scripts
  tests/      27 unit tests
  run_all.m   runs everything end to end
simulink/
  +pvsrc/pv_module.ssc      PV array as a native Simscape component
  build_mppt_model.m        builds the switched circuit model from scratch
  run_switched_validation.m switched vs averaged cross-check, closed-loop run
results/figures             generated figures
results/data                generated .mat results
docs/report                 LaTeX source + Solar_MPPT_Control_Report.pdf
```

## Requirements

MATLAB R2025a with Control System Toolbox, Simulink, Simscape and Optimization
Toolbox. No Simscape Electrical is required: the PV array is implemented as a
custom Simscape component and the converter uses Foundation Library electrical
blocks only.

## Running it

```matlab
cd matlab
startup_mpptlab
run_all                      % everything, roughly 12 minutes
```

Individual pieces:

```matlab
s01_pv_characterisation      % I-V and P-V families, dynamic resistance
s02_plant_analysis           % small-signal plant across the operating envelope
s03_control_design           % cascade vs single-loop margins
s04_mppt_comparison          % algorithm comparison, step-size trade-off
s05_dynamic_benchmark        % EN 50530-style ramps, a few minutes
runtests('tests')            % 27 unit tests
```

Switched circuit model:

```matlab
cd simulink
run_switched_validation      % builds the .slx, validates, runs closed loop
export_model_diagram         % block diagram image
```

## Report

`docs/report/Solar_MPPT_Control_Report.pdf` is a 93-page report covering the
project statement, a literature review, theory, methodology, all modelling and
control results, the physical model with hardware requirements, and an appendix
of 16 propositions with full derivations. Rebuild it with `docs/report/build.sh`.

## Headline results

**PV model.** The five reference parameters are identified by simultaneously
closing on short-circuit current, open-circuit voltage, the maximum power point,
the slope condition at that point, and the open-circuit temperature coefficient.
For the Kyocera KC200GT the residual is at machine precision:

| Quantity | Datasheet | Model | Error |
|---|---|---|---|
| Voc | 32.90 V | 32.90 V | 0 |
| Isc | 8.21 A | 8.21 A | 0 |
| Vmp | 26.30 V | 26.30 V | -1.4e-14 % |
| Imp | 7.61 A | 7.61 A | 0 |
| Pmp | 200.14 W | 200.14 W | 0 |
| beta_Voc | -0.12301 V/K | -0.12301 V/K | 1.1e-14 % |

**The plant is strongly operating-point dependent.** Across the I-V curve at
1000 W/m^2 the resonant frequency barely moves (411 to 427 Hz) but the damping
ratio varies by a factor of 44, from 0.023 on the current-source branch to 1.03
on the voltage-source branch.

**A single PI loop on PV voltage is not adequate.** Against the 43 dB LC
resonance peak it produces three gain crossovers and its phase margin collapses
to 1.5 degrees on the current-source branch. The cascade holds above 85 degrees
everywhere, because at the inner crossover the plant looks like Vdc/(L*s)
regardless of where on the I-V curve the array sits.

**The duty-to-power gain vanishes at the optimum.** The linearised gain from
duty ratio to PV power equals dP/dV, which is exactly zero at the maximum power
point and changes sign across it. This is why power cannot be used directly as a
feedback error signal, and why MPPT must be an extremum-seeking outer layer.

**Algorithm comparison** on EN 50530-style trapezoidal ramps between 300 and
1000 W/m^2:

| Tracker | 25 W/m^2/s | 50 | 100 | 200 |
|---|---|---|---|---|
| P&O | 99.95 | 99.93 | 99.87 | 99.48 |
| P&O adaptive | 99.84 | 98.73 | 93.14 | 99.65 |
| IncCond | 99.95 | 99.93 | 99.87 | 99.46 |
| Extremum seeking | 99.85 | 99.85 | 99.85 | 99.85 |

Extremum seeking is essentially flat against ramp rate, with a worst
instantaneous shortfall of 8 W against 116 to 129 W for the hill-climbers. The
naive variable-step P&O is *less* robust than fixed-step: on a rising ramp the
irradiance contributes more to dP than the perturbation does, the algorithm
mis-attributes the sign, and the enlarged step turns that into a runaway
excursion down to 90 V.

**Switched circuit agrees with the averaged model.** At fixed duty 0.6112:

| Quantity | Switched Simscape | Averaged | Error |
|---|---|---|---|
| v_pv mean | 158.169 V | 157.800 V | 0.234 % |
| i_L mean | 15.198 A | 15.220 A | -0.145 % |
| i_L ripple | 3.176 A | 3.215 A | -1.23 % |
| P_pv mean | 2401.60 W | 2401.72 W | -0.005 % |

Closed-loop P&O on the switched circuit through a 1000 to 500 W/m^2 step reaches
99.93 % MPPT efficiency.

## System under study

Kyocera KC200GT modules, 6 in series by 2 strings in parallel: 2402 W, 157.8 V
and 15.22 A at the maximum power point under standard test conditions. A boost
converter with L = 1.5 mH, Cpv = 100 uF, RL = 0.15 ohm, switching at 20 kHz into
a stiff 400 V DC bus.
