#pragma once
#include "const.h"

struct Device
{
    Device() = default;
    Device(const DeviceType t, const OperatingSystem o) : type(t), os(o) {}
    DeviceType type{ DeviceUnknown };
    OperatingSystem os{ OsUnknown };

    bool operator==(const Device& rhs) const { return type == rhs.type && os == rhs.os; }
};
