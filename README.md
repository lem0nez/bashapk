![License](https://img.shields.io/github/license/lem0nez/bashapk?style=flat-square)
![Size](https://img.shields.io/github/repo-size/lem0nez/bashapk?style=flat-square)

# BashAPK
This repository contains various Bash scripts that simplify editing of
decompiled Android applications. The main goal is make easier to create “light”
version of applications. Supported tools are
[Apktool](https://github.com/iBotPeaches/Apktool) and
[MT Manager](https://binmt.cc/doc/en).

## rmdupes
Removes duplicate files from specified directories. For example, if you have
following resource folders:
```
drawable-hdpi
drawable-xhdpi
drawable-xxhdpi
```
and your screen has the **XHDPI** density, then following command:
```
rmdupes drawable-xhdpi drawable-xxhdpi drawable-hdpi
```
will delete all found duplicate graphics, starting from the second folder. You
can also pass a directory of the decompiled by MT Manager `resources.arsc` file
(`--arsc` option) to delete corresponding paths from XML files.

How to prioritize directories sequence of resources you can read
[here](https://developer.android.com/guide/topics/resources/providing-resources#AlternativeResources).

## rmdupes-arsc
Removes duplicate resources from specified XML files. For instance, if you have
following XML files, that decompiled by MT Manager:
```
style.xml
style-v21.xml
style-v28.xml
```
and your Android version is **5.1** (API 22), then to delete unnecessary
duplicate resources you should use the following command:
```
rmdupes-arsc style-v21.xml style.xml style-v28.xml
```
The same logic, but for the Apktool's files hierarchy:
```
rmdupes-arsc values-v21/styles.xml values/styles.xml values-v28/styles.xml
```

## imgoptim
Optimizes all specified **PNG**, **JPEG** and **WebP** images (using `optipng`,
`jpegoptim` and `cwebp`), or images from specified directories recursively. It
uses lossless optimization options (with maximum compression parameters) and
calculates total freed space. You can disable calculations to speed up
optimization process. Example of use:
```
imgoptim --list ../optimized-files.list assets/image.webp res/
```

## patchapk
With this script you can apply some of the following patches (in the square
brackets noted which directories and files a patch requires):
- `no-ads` _[`smali*/`, `res/layout*/`]_. Disable ads. Original implementation
  by Maximoff [here](https://github.com/Maximoff/ApkEditor-Patches).
- `no-analytics` _[`smali*/`, `AndroidManifest.xml`]_. Disable analytic reports.
- `no-billing` _[`smali*/`, `AndroidManifest.xml`]_. Disable the billing service
  to reduce RAM usage by an application.
- `rm-debug-info` _[`smali*/`]_. Remove debug information from Smali code to
  reduce size of compiled DEX file.

For Apktool only:
- `rm-langs` _[`res/values-*/`]_. Remove unused languages. You can change
  pattern of the language code that will be kept by editing the `KEEP_LANG`
  variable inside the patch script. By default it's `en`.
- `rm-dummies` _[`res/values*/`]_. Remove unnecessary “dummy” items (generated
  by Apktool) from application resources.

All XML files must be decompiled. When working with files that decompiled by MT
Manager, it's will be better to pass the `--use-xmlstarlet` option to improve
matching of XML elements.
