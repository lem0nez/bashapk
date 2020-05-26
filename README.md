![License](https://img.shields.io/github/license/lem0nez/bashapk?style=flat-square)
![Size](https://img.shields.io/github/repo-size/lem0nez/bashapk?style=flat-square)

# BashAPK
This repository contains various Bash scripts for simplified editing of
decompiled Android applications.

#### imgoptim
Optimizes all **PNG** (using `optipng`) and **JPEG** (using `jpegoptim`) files
from the specified directories recursively. It uses lossless optimization
options and calculates total freed space. You can disable calculations to speed
up optimization process.

#### patchapk
With this script you can apply some of the following patches:
- `rm-langs` removes unused languages (only `values` folders). You can change
  pattern of the language code that should be keeped by editing the `KEEP_LANG`
  variable inside the patch script. By default it's `en`.
- `rm-debug-info` removes debugging information from the Smali code to reduce
  size of compiled DEX-file.
- `rm-dummies` removes unnecessary "dummy" items from the app resources
  generated by the [ApkTool](https://github.com/iBotPeaches/Apktool).
- `no-ads` disables ads. Original realisation by Maximoff
  [here](https://github.com/Maximoff/ApkEditor-Patches).
- `no-analytics` disables analytic reports.
- `no-billing` disables the billing service for the app to reduce memory usage.

#### rmdupes
Removes duplicate files from the specified directories. For example, if you have
the following resource folders:
```
drawable-hdpi
drawable-xhdpi
drawable-xxhdpi
```
and your screen have the **XHDPI** density, then the following command:
```
rmdupes drawable-xhdpi drawable-xxhdpi drawable-hdpi
```
will delete all founded duplicate graphics, starts with the second folder. How
to prioritize directories sequence of APK resources you can read
[here](https://developer.android.com/guide/topics/resources/providing-resources#AlternativeResources).
