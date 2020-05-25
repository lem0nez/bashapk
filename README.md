![License](https://img.shields.io/github/license/lem0nez/bashapk?style=flat-square)
![Size](https://img.shields.io/github/repo-size/lem0nez/bashapk?style=flat-square)

# BashAPK
This repository contains various Bash scripts for simplified editing of
decompiled Android applications.

#### imgoptim
Optimizes all PNG (using `optipng`) and JPEG (using `jpegoptim`) files from the
specified directories recursively. It uses lossless optimization options and
calculates total freed space. You can disable calculations to speed up
optimization process.

#### patchapk
With this script you can apply some of the following patches:
- `rm-debug-info` removes debugging information from the `.smali`-files to
  reduce size of compiled DEX-file.
- `rm-ads` removes ads. Original realisation by Maximoff
  [here](https://github.com/Maximoff/ApkEditor-Patches).
- `rm-analytics` disables analytic reports.

#### rmdupes
Removes duplicate files from the specified directories. For example, if you have
this resource directories:
```
drawable-hdpi
drawable-xhdpi
drawable-xxhdpi
```
and your screen have the `XHDPI` density, then the following command:
```
rmdupes drawable-xhdpi drawable-xxhdpi drawable-hdpi
```
will delete all founded duplicate graphics, starts with the second folder. How
to prioritize directories sequence of APK resources you can read
[here](https://developer.android.com/guide/topics/resources/providing-resources#AlternativeResources).
