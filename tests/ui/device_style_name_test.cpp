#include <gtest/gtest.h>

#include "framework/ui/uimanager.h"

// UIManager::importStyle(fl, true) loads OS/device-specific style variants by
// prefixing the platform short name to the style's base name. The variant must
// live next to the base style, so the directory part of `fl` has to be
// preserved: '/modules/example/foo' -> '/modules/example/windows.foo', never
// 'windows./modules/example/foo'.

TEST(DeviceStyleName, KeepsBarenameBehavior)
{
    // Historical behavior for caller-relative barenames must not change.
    EXPECT_EQ("windows.foo", UIManager::getDeviceStyleName("foo", "windows"));
}

TEST(DeviceStyleName, StripsExtensionFromBarename)
{
    EXPECT_EQ("phone.foo", UIManager::getDeviceStyleName("foo.otui", "phone"));
}

TEST(DeviceStyleName, PreservesAbsoluteDirectory)
{
    EXPECT_EQ("/modules/example/windows.foo",
              UIManager::getDeviceStyleName("/modules/example/foo", "windows"));
}

TEST(DeviceStyleName, PreservesAbsoluteDirectoryWithExtension)
{
    EXPECT_EQ("/modules/game_shop/macos.shop",
              UIManager::getDeviceStyleName("/modules/game_shop/shop.otui", "macos"));
}

TEST(DeviceStyleName, PreservesRelativeSubdirectory)
{
    EXPECT_EQ("styles/phone.foo",
              UIManager::getDeviceStyleName("styles/foo.otui", "phone"));
}

TEST(DeviceStyleName, IgnoresDotsInDirectoryNames)
{
    EXPECT_EQ("/mods/v1.2/windows.foo",
              UIManager::getDeviceStyleName("/mods/v1.2/foo.otui", "windows"));
}
