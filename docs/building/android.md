# OTClient Redemption

## Supported OS

- Windows 11

## 1. Install the required software

To compile for Android, you will need to download and install:
- [Git](https://git-scm.com/download/win)
- [Android Studio](https://developer.android.com/studio) (compiler)
- [vcpkg](https://github.com/Microsoft/vcpkg) (package manager)
- [Android Library](https://drive.google.com/file/d/1Uk-EnQG9svz_5YfuiMAGIViJsnDFttRy/view) (dependency)

## 2. Set up vcpkg

Make sure to follow full installation of `vcpkg`, per [Official Quickstart](https://github.com/Microsoft/vcpkg#quick-start) execute the following in _Powershell_:

```powershell
git clone https://github.com/Microsoft/vcpkg
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```

## 3. Download the source code and install vcpkg dependencies

```powershell
git clone --depth 1 https://github.com/opentibiabr/otclient.git
vcpkg install
```

## 4. Copy the Android Libraries
Extract the android libraries inside `android/app/libs` folder.

## 5. Copy `data.zip` to Android assets
Create a `data.zip` file containing the `init.lua`, `mods`, `modules`, `data` and add it to `android/app/src/main/assets`.

## 6. Create Environment Variables:
- `ANDROID_NDK_HOME` pointing to the Android NDK root folder (Ex.: `C:\Users\Administrator\AppData\Local\Android\Sdk\ndk\29.0.13599879`).
- `VCPKG_ROOT` pointing to the vcpkg folder.

## 7. Build

- Open Android Studio, click to open project and select the `otclient/android` folder.

- Wait Android Studio synchronize the project and download dependencies.

- Navigate through the menu, find "Build" and then "Generate Signed App Bundle or APK...".

- Select "APK" and proceed, create a new key, select it and proceed again.

- Select "Release" and proceed (Create).

- Now, just wait for the compilation to complete and you will have the .apk file in otclient-main/android/app/release, ready to play.

## 8. Video Tutorial (step by step)
- https://youtu.be/1HjtL_sF0GE
