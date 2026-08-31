# libbox
[![](https://jitpack.io/v/singbox-android/libbox.svg)](https://jitpack.io/#singbox-android/libbox)

Android library for sing-box.

## 📦 Downloads

`libbox.aar` is distributed via [GitHub Releases](https://github.com/singbox-android/libbox/releases) instead of being committed to the repository (it exceeds GitHub's 100MB file size limit).

Gradle/JitPack consumers are unaffected — the build script automatically downloads the missing `libbox.aar` from the matching release during build:

```groovy
implementation 'com.github.singbox-android:libbox:1.14.0'
```

> For maintainers: upload the new `libbox.aar` as a release asset (tag name = `build.gradle` version) **before** tagging a new version.

## <img src="https://sing-box.sagernet.org/assets/icon.svg" width="24"  align="center" /> sing-box
https://github.com/SagerNet/sing-box

## 🔗 Related Projects

**[Clash Sing](https://github.com/clash-sing/clash_sing)**: A high-performance cross-platform proxy client developed with Flutter and powered by sing-box, featuring Clash config support.

**[flutter_sing_box](https://github.com/clash-sing/flutter_sing_box)**: The specialize Flutter plugin for sing-box integration, providing efficient kernel communication.

