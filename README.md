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

## What the plots show

- **Horizontal (azimuth) gain pattern** — polar plot, 0 dB outer ring down to
  −40 dB, forward direction pointing right.
- **Elevation gain pattern** — polar plot in the vertical plane; shows
  ground-reflection lobes for dipole/loop when a height above ground is set.
- **Impedance & SWR vs frequency** — SWR (orange, left axis), resistance R
  (blue) and reactance X (teal, right axis, ohms) across ±12 % of the centre
  frequency, with a dashed 2:1 reference line.

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
independent scroll views, and switching between all four antenna types.

## Project layout

```
lib/
  main.dart            App shell, antenna-type selector, settings panels, layout
  antenna_design.dart  AntennaDesign interface + shared impedance/SWR helpers
  yagi_model.dart      Yagi-Uda parametric model
  dipole_model.dart    Half-wave dipole model
  loop_model.dart      Full-wave loop model
  cantenna_model.dart  Open-ended circular waveguide (cantenna) model
  plots.dart           Custom painters: polar gain plots, impedance/SWR chart
test/
  widget_test.dart     Widget tests
```

## Adding a new antenna type

1. Create `lib/<name>_model.dart` with a parameters class and a design class
   that implements `AntennaDesign` (see `antenna_design.dart`).
2. Add a value to the `AntennaType` enum and its label.
3. In `main.dart`: hold a parameters instance, add a branch to the `_d`
   getter, the AppBar label switch, and a `<name>Cards` list for the left
   settings column.
4. Add a widget test that selects the new type and checks its panels.

The plots and summaries work automatically through the `AntennaDesign`
interface.
