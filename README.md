# Antenna Designer (yagiyagi)

An interactive Flutter application for exploring and comparing common amateur
radio antenna designs. Adjust the physical parameters of an antenna on the
left and watch its radiation patterns and impedance behaviour update live on
the right.

## Supported antenna types

Select the antenna type from the pull-down at the top of the left panel:

| Type | Key parameters | Model highlights |
| --- | --- | --- |
| **Yagi-Uda antenna** | Element count (2–12), spacing, diameter, reflector/director length, taper, feed system (split dipole / folded dipole / gamma match) | Empirical gain vs. boom geometry, front/back ratio, parasitic-coupling feedpoint resistance |
| **Dipole antenna** | Length factor, diameter, height above ground | Classic figure-8 azimuth, ground-reflection elevation lobes, image-antenna resistance vs. height |
| **Loop antenna** | Circumference, wire diameter, shape (circular / square quad), height above ground | Full-wave loop (~3.3 dBi), ~100–120 Ω feedpoint (75 Ω coax friendly) |
| **Waveguide antenna (cantenna)** | Can diameter, probe distance/length, frequency up to 6 GHz | TE11/TM01 cutoff behaviour, guide wavelength, probe placement (λg/4), aperture gain, below-cutoff SWR wall |
| **Quarter-wave vertical / ground plane** | Length factor, radiator diameter, radial count, radial droop, soil quality | Radiation vs. ground-loss resistance and the efficiency that falls out of it, real-ground takeoff angle, 36 Ω flat → 50 Ω drooping radials |
| **Small transmitting (magnetic) loop** | Loop and conductor diameter, conductor material, capacitor type, power | Milliohm radiation resistance against skin-effect and capacitor loss, tuning capacitance, capacitor voltage, Q in the hundreds and a 2:1 window a few kHz wide |
| **Log-periodic dipole array** | Band edges, τ, σ, element diameter, boom feeder Z₀ | Carrel geometry and input resistance, Cebik-style optimum-σ ridge, impedance ripple with period ln(1/τ), full element table |
| **Parabolic dish** | Diameter, f/D, edge taper, surface RMS error, blockage | Illumination/spillover efficiency by direct integration of a cos^n feed, Ruze surface loss, real circular-aperture pattern with Bessel sidelobe rings |
| **Axial-mode helix** | Turns, circumference, pitch angle, ground plane, winding sense, matching | Kraus gain/beamwidth/impedance, circular polarisation and axial ratio, the 0.75–1.33 λ axial-mode window that gives it its bandwidth |
| **Microstrip patch** | Substrate (εr, tanδ), thickness, width factor, feed method | Standard transmission-line design equations, Q budget (radiation / dielectric / conductor / surface wave) that sets both efficiency and bandwidth, inset distance for a 50 Ω match |
| **Moxon rectangle** | Wire diameter, tip-gap trim, height above ground | Full A–E dimension set, ~50 Ω feedpoint with no matching network, and a front-to-back ratio that lives or dies on the tip gap |
| **Pyramidal horn** | Standard waveguide (WR-1500…WR-137), aperture a₁/b₁, axial length | E- and H-plane quadratic phase errors s and t by numerical aperture integration, landing on the classic 0.51 efficiency at the optimum |
| **Two-element phased verticals** | Spacing, phase, current ratio, radials, soil | Steerable cardioid/broadside/endfire patterns, numerically integrated array gain, and the two very different drive-point impedances mutual coupling produces |
| **Corner reflector** | Apex angle (45–180°), apex spacing, panel size, grid rod spacing | Exact image expansion for corners that divide 180°, gain referred to the driven element's input resistance, feedpoint swing with apex spacing |

## What the plots show

- **Horizontal (azimuth) gain pattern** — polar plot, 0 dB outer ring down to
  −40 dB, forward direction pointing right.
- **Elevation gain pattern** — polar plot in the vertical plane; shows
  ground-reflection lobes for dipole/loop/Moxon when a height above ground is
  set, and real-ground takeoff angles for the vertical and phased array.
- **Impedance & SWR vs frequency** — SWR (orange, left axis), resistance R
  (blue) and reactance X (teal, right axis, ohms), with a dashed 2:1
  reference line. The swept span follows the design: ±12 % by default, a
  fraction of a percent for a magnetic loop, and the whole design decade plus
  its roll-off for a log-periodic.

The left settings column and the right plot column each have their own
independent scroll bar, so the app stays usable on smaller laptop screens.

> **Note:** the models are simplified parametric approximations intended for
> exploration and intuition-building, not final engineering. Verify real
> designs in NEC/4nec2 or a similar full-wave solver before cutting metal.

## Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.35 or newer
  (developed against Flutter 3.44, Dart 3.12)
- For desktop builds: the usual platform toolchain (Xcode on macOS,
  Visual Studio on Windows, clang/GTK on Linux)

## Run the app

```bash
flutter pub get

# Desktop
flutter run -d macos      # or: windows / linux

# Browser
flutter run -d chrome

# Headless web server (any browser, fixed port)
flutter run -d web-server --web-port=7100
# then open http://localhost:7100/
```

There is also an npm bridge for environments that expect a `dev` script:

```bash
npm run dev -- --web-port=7100   # equivalent to flutter run -d web-server
```

## Build release binaries

```bash
flutter build web --release     # static site in build/web
flutter build macos --release   # build/macos/Build/Products/Release
flutter build windows --release
flutter build linux --release
```

## Tests and static analysis

```bash
flutter analyze
flutter test
```

The widget tests cover rendering of the settings panels and plots, the
independent scroll views, and switching between every antenna type.
`test/models_test.dart` checks the models themselves against published
numbers — Bessel and Ci/Si values, mutual impedance between half-wave
dipoles, the 0.51 aperture efficiency of an optimum horn, the textbook
dimensions of an FR-4 patch, and so on.

## Project layout

```
lib/
  main.dart            App shell, antenna-type selector, layout
  antenna_design.dart  AntennaDesign interface, shared impedance/SWR helpers,
                       and the numerics the models share: Bessel functions,
                       sine/cosine integrals, mutual impedance, numeric
                       directivity and beamwidth
  ui_kit.dart          Shared settings widgets (cards, sliders, readouts)
  panels.dart          Barrel export for lib/panels/
  panels/              One settings panel per antenna type
  <name>_model.dart    One parametric model per antenna type
  plots.dart           Custom painters: polar gain plots, impedance/SWR chart
test/
  widget_test.dart     Widget tests
  models_test.dart     Model physics and numerics tests
```

## Adding a new antenna type

1. Create `lib/<name>_model.dart` with a parameters class and a design class
   that extends `AntennaDesign` (see `antenna_design.dart`). Only
   `impedanceAt` and the gain/pattern members are required; `swrAt`,
   `centerSwr`, `bandwidth2to1MHz`, `polarization` and the plot sweep range
   have sensible defaults to override as needed.
2. Add a value to the `AntennaType` enum, plus its `label` and `shortLabel`.
3. Create `lib/panels/<name>_panel.dart` exporting
   `List<Widget> <name>Cards(params, design, update)` and add it to
   `lib/panels.dart`.
4. In `main.dart`: hold a parameters instance and add a branch to the `_d`
   and `_typeCards` switches. Both are exhaustive, so the compiler will
   point at anything missed.
5. Add a widget test that selects the new type and checks its panels, and
   model tests for whatever the model claims to get right.

The plots and summaries work automatically through the `AntennaDesign`
interface.
