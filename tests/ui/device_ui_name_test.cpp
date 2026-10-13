#include <gtest/gtest.h>

#include "framework/ui/uimanager.h"

// UIManager::loadDeviceUI() loads OS/device-specific .otui variants by
// appending the platform short name after the file's base name. Only a final
// extension may be dropped, and the directory part must survive untouched:
// '/modules/foo.v2/window' -> '/modules/foo.v2/window.windows', never
// '/modules/foo.windows'.

TEST(DeviceUIName, KeepsBarenameBehavior)
{
    // Historical behavior for caller-relative barenames must not change.
    EXPECT_EQ("window.windows", UIManager::getDeviceUIName("window", "windows"));
}

TEST(DeviceUIName, StripsExtensionFromBarename)
{
    EXPECT_EQ("window.phone", UIManager::getDeviceUIName("window.otui", "phone"));
}

TEST(DeviceUIName, IgnoresDotsInDirectoryNames)
{
    EXPECT_EQ("/modules/foo.v2/window.windows",
              UIManager::getDeviceUIName("/modules/foo.v2/window", "windows"));
}

TEST(DeviceUIName, StripsOnlyFinalExtensionFromDottedBasename)
{
    EXPECT_EQ("/modules/example/window.dark.windows",
              UIManager::getDeviceUIName("/modules/example/window.dark.otui", "windows"));
}

TEST(DeviceUIName, PreservesAbsoluteDirectoryWithExtension)
{
    EXPECT_EQ("/modules/game_shop/shop.macos",
              UIManager::getDeviceUIName("/modules/game_shop/shop.otui", "macos"));
}
