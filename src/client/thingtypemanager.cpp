/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "thingtypemanager.h"

#include <nlohmann/json.hpp>

#ifdef FRAMEWORK_EDITOR
#include <algorithm>
#include <array>
#include <cctype>
#include <exception>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <limits>
#include <map>
#include <set>
#include <string_view>
#endif

#include "game.h"
#include "spriteappearances.h"
#include "thingtype.h"
#include "framework/core/filestream.h"
#include "framework/core/resourcemanager.h"
#include "framework/graphics/apngloader.h"
#include "framework/graphics/image.h"
#include "framework/otml/otmldocument.h"
#include "framework/util/crypt.h"
#ifdef FRAMEWORK_PROTOBUF
#include <appearances.pb.h>
#include <staticdata.pb.h>
#endif

#ifdef FRAMEWORK_EDITOR
#include "itemtype.h"
#include "creatures.h"
#include <framework/core/binarytree.h>
#endif


ThingTypeManager g_things;

#if defined(FRAMEWORK_EDITOR) && defined(FRAMEWORK_PROTOBUF)
namespace {

using AppearanceBank = google::protobuf::RepeatedPtrField<appearances::Appearance>;
constexpr uint32_t DEFAULT_ANIMATION_FRAME_DURATION_MS = 100;

const AppearanceBank* getAppearanceBank(const appearances::Appearances& library, const int category)
{
    switch (category) {
        case ThingCategoryItem: return &library.object();
        case ThingCategoryCreature: return &library.outfit();
        case ThingCategoryEffect: return &library.effect();
        case ThingCategoryMissile: return &library.missile();
        default: throw stdext::exception("invalid appearance category");
    }
}

AppearanceBank* getAppearanceBank(appearances::Appearances& library, const int category)
{
    switch (category) {
        case ThingCategoryItem: return library.mutable_object();
        case ThingCategoryCreature: return library.mutable_outfit();
        case ThingCategoryEffect: return library.mutable_effect();
        case ThingCategoryMissile: return library.mutable_missile();
        default: throw stdext::exception("invalid appearance category");
    }
}

std::filesystem::path getAppearanceEditorFile(const std::string& catalogPath, const int version)
{
    namespace fs = std::filesystem;
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance editing is supported only for client versions 15.x");

    std::error_code error;
    const auto writeRoot = fs::canonical(g_resources.getWriteDir(), error);
    if (error)
        throw stdext::exception("unable to resolve the writable directory: {}", error.message());

    const auto package = writeRoot / "sprite-editor" / "data" / "things" / std::to_string(version);
    const auto catalog = package / "catalog-content.json";
    const auto ensureNoSymlinks = [&](const fs::path& target) {
        const auto relative = target.lexically_relative(writeRoot);
        if (relative.empty() || relative.is_absolute() || *relative.begin() == "..")
            throw stdext::exception("appearance editor path is outside the writable directory");

        auto current = writeRoot;
        for (const auto& part : relative) {
            current /= part;
            error.clear();
            const auto status = fs::symlink_status(current, error);
            if (error == std::errc::no_such_file_or_directory)
                continue;
            if (error)
                throw stdext::exception("unable to validate appearance editor path: {}", error.message());
            if (fs::is_symlink(status))
                throw stdext::exception("appearance work copies cannot contain symbolic links");
        }
    };

    ensureNoSymlinks(catalog);
    error.clear();
    if (!fs::is_regular_file(catalog, error) || error)
        throw stdext::exception("the active appearance catalog is not a regular file");
    const auto resolvedCatalog = fs::canonical(catalog, error);
    if (error)
        throw stdext::exception("unable to resolve the appearance catalog: {}", error.message());
    const auto activeCatalog = fs::canonical(g_resources.getRealPath(catalogPath), error);
    if (error || resolvedCatalog != activeCatalog)
        throw stdext::exception("appearance editing is allowed only for the active work copy");

    std::ifstream catalogStream(catalog, std::ios::binary);
    if (!catalogStream)
        throw stdext::exception("unable to read the work copy catalog");
    const auto document = nlohmann::json::parse(catalogStream);

    std::string appearanceFile;
    for (const auto& entry : document) {
        if (entry.value("type", std::string{}) == "appearances") {
            appearanceFile = entry.at("file").get<std::string>();
            break;
        }
    }
    if (appearanceFile.empty())
        throw stdext::exception("the work copy catalog does not contain an appearances file");

    auto relativeFile = fs::path(appearanceFile).lexically_normal();
    if (relativeFile.empty() || relativeFile.is_absolute() || relativeFile.has_root_name() || relativeFile.has_root_directory())
        throw stdext::exception("invalid appearances file path in work copy catalog");
    for (const auto& part : relativeFile) {
        if (part == ".." || part == ".")
            throw stdext::exception("invalid appearances file path in work copy catalog");
    }

    const auto target = package / relativeFile;
    ensureNoSymlinks(target);
    error.clear();
    if (!fs::is_regular_file(target, error) || error)
        throw stdext::exception("the work copy appearances file is missing or invalid");
    return target;
}

appearances::Appearance* findAppearance(appearances::Appearances& library, const int category, const int id)
{
    for (auto& appearance : *getAppearanceBank(library, category)) {
        if (appearance.id() == static_cast<uint32_t>(id))
            return &appearance;
    }
    return nullptr;
}

const appearances::Appearance* findAppearance(const appearances::Appearances& library, const int category, const int id)
{
    for (const auto& appearance : *getAppearanceBank(library, category)) {
        if (appearance.id() == static_cast<uint32_t>(id))
            return &appearance;
    }
    return nullptr;
}

std::string getAppearanceEnumLabel(const google::protobuf::EnumDescriptor* descriptor,
                                   const google::protobuf::EnumValueDescriptor* value)
{
    std::string label(value->name());
    const std::string prefix = std::string(descriptor->name()) + "_";
    if (label.starts_with(prefix))
        label.erase(0, prefix.size());

    bool capitalize = true;
    for (auto& character : label) {
        if (character == '_') {
            character = ' ';
            capitalize = true;
        } else {
            character = capitalize ? static_cast<char>(std::toupper(static_cast<unsigned char>(character)))
                                   : static_cast<char>(std::tolower(static_cast<unsigned char>(character)));
            capitalize = false;
        }
    }
    return label;
}

nlohmann::json getAppearanceEnumOptions(const google::protobuf::EnumDescriptor* descriptor)
{
    nlohmann::json options = nlohmann::json::array();
    for (int index = 0; index < descriptor->value_count(); ++index) {
        const auto* option = descriptor->value(index);
        options.push_back({ { "label", getAppearanceEnumLabel(descriptor, option) }, { "value", option->number() } });
    }
    return options;
}

void collectAppearanceFields(const google::protobuf::Message& message, const std::string& prefix,
                             nlohmann::json& booleans, nlohmann::json& values, nlohmann::json& textValues,
                             nlohmann::json& enumOptions, nlohmann::json& multiValues,
                             nlohmann::json& unsetValues)
{
    const auto* descriptor = message.GetDescriptor();
    const auto* reflection = message.GetReflection();
    for (int index = 0; index < descriptor->field_count(); ++index) {
        const auto* field = descriptor->field(index);
        const auto fieldName = std::string(field->name());
        const auto name = prefix.empty() ? fieldName : prefix + "." + fieldName;
        if (field->is_repeated()) {
            if (field->cpp_type() == google::protobuf::FieldDescriptor::CPPTYPE_ENUM) {
                auto& fieldValues = multiValues[name] = nlohmann::json::array();
                for (int itemIndex = 0; itemIndex < reflection->FieldSize(message, field); ++itemIndex)
                    fieldValues.push_back(reflection->GetRepeatedEnumValue(message, field, itemIndex));
                enumOptions[name] = getAppearanceEnumOptions(field->enum_type());
            }
            continue;
        }
        if (field->cpp_type() == google::protobuf::FieldDescriptor::CPPTYPE_MESSAGE) {
            collectAppearanceFields(reflection->GetMessage(message, field), name, booleans, values,
                                    textValues, enumOptions, multiValues, unsetValues);
            continue;
        }

        switch (field->cpp_type()) {
            case google::protobuf::FieldDescriptor::CPPTYPE_BOOL:
                booleans[name] = reflection->GetBool(message, field);
                break;
            case google::protobuf::FieldDescriptor::CPPTYPE_INT32:
                values[name] = reflection->GetInt32(message, field);
                if (field->has_presence() && !reflection->HasField(message, field))
                    unsetValues[name] = true;
                break;
            case google::protobuf::FieldDescriptor::CPPTYPE_INT64:
                values[name] = reflection->GetInt64(message, field);
                if (field->has_presence() && !reflection->HasField(message, field))
                    unsetValues[name] = true;
                break;
            case google::protobuf::FieldDescriptor::CPPTYPE_UINT32:
                values[name] = reflection->GetUInt32(message, field);
                if (field->has_presence() && !reflection->HasField(message, field))
                    unsetValues[name] = true;
                break;
            case google::protobuf::FieldDescriptor::CPPTYPE_UINT64:
                values[name] = reflection->GetUInt64(message, field);
                if (field->has_presence() && !reflection->HasField(message, field))
                    unsetValues[name] = true;
                break;
            case google::protobuf::FieldDescriptor::CPPTYPE_ENUM:
                values[name] = field->has_presence() && !reflection->HasField(message, field)
                    ? nlohmann::json(nullptr) : nlohmann::json(reflection->GetEnumValue(message, field));
                enumOptions[name] = getAppearanceEnumOptions(field->enum_type());
                break;
            case google::protobuf::FieldDescriptor::CPPTYPE_STRING:
                textValues[name] = reflection->GetString(message, field);
                break;
            default:
                break;
        }
    }
}

void setAppearanceScalar(google::protobuf::Message& message, const std::string& path, const nlohmann::json& value)
{
    const auto separator = path.find('.');
    const auto* descriptor = message.GetDescriptor();
    const auto* field = descriptor->FindFieldByName(path.substr(0, separator));
    if (!field || field->is_repeated())
        throw stdext::exception("unknown appearance property '{}'", path);

    auto* reflection = message.GetReflection();
    if (separator != std::string::npos) {
        if (field->cpp_type() != google::protobuf::FieldDescriptor::CPPTYPE_MESSAGE)
            throw stdext::exception("invalid appearance property path");
        auto* nested = reflection->MutableMessage(&message, field);
        setAppearanceScalar(*nested, path.substr(separator + 1), value);
        std::vector<const google::protobuf::FieldDescriptor*> presentFields;
        nested->GetReflection()->ListFields(*nested, &presentFields);
        if (presentFields.empty())
            reflection->ClearField(&message, field);
        return;
    }

    if (value.is_number_integer() && value.get<int64_t>() == std::numeric_limits<int32_t>::min()) {
        reflection->ClearField(&message, field);
        return;
    }

    switch (field->cpp_type()) {
        case google::protobuf::FieldDescriptor::CPPTYPE_BOOL:
            if (!value.is_boolean()) throw stdext::exception("appearance flag '{}' must be boolean", path);
            reflection->SetBool(&message, field, value.get<bool>());
            return;
        case google::protobuf::FieldDescriptor::CPPTYPE_INT32:
            if (!value.is_number_integer()) throw stdext::exception("appearance value '{}' must be an integer", path);
            if (value.get<int64_t>() < std::numeric_limits<int32_t>::min() || value.get<int64_t>() > std::numeric_limits<int32_t>::max())
                throw stdext::exception("appearance value '{}' is out of range", path);
            reflection->SetInt32(&message, field, value.get<int32_t>());
            return;
        case google::protobuf::FieldDescriptor::CPPTYPE_INT64:
            if (!value.is_number_integer()) throw stdext::exception("appearance value '{}' must be an integer", path);
            reflection->SetInt64(&message, field, value.get<int64_t>());
            return;
        case google::protobuf::FieldDescriptor::CPPTYPE_UINT32:
            if (!value.is_number_unsigned() && (!value.is_number_integer() || value.get<int64_t>() < 0))
                throw stdext::exception("appearance value '{}' must be a non-negative integer", path);
            if (value.get<uint64_t>() > std::numeric_limits<uint32_t>::max())
                throw stdext::exception("appearance value '{}' is out of range", path);
            reflection->SetUInt32(&message, field, value.get<uint32_t>());
            return;
        case google::protobuf::FieldDescriptor::CPPTYPE_UINT64:
            if (!value.is_number_unsigned() && (!value.is_number_integer() || value.get<int64_t>() < 0))
                throw stdext::exception("appearance value '{}' must be a non-negative integer", path);
            reflection->SetUInt64(&message, field, value.get<uint64_t>());
            return;
        case google::protobuf::FieldDescriptor::CPPTYPE_ENUM: {
            if (!value.is_number_integer()) throw stdext::exception("appearance enum '{}' must be an integer", path);
            const auto number = value.get<int32_t>();
            if (number == std::numeric_limits<int32_t>::min()) {
                reflection->ClearField(&message, field);
                return;
            }
            const auto* enumValue = field->enum_type()->FindValueByNumber(number);
            if (!enumValue) throw stdext::exception("unknown value for appearance enum '{}'", path);
            reflection->SetEnum(&message, field, enumValue);
            return;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_STRING:
            if (!value.is_string()) throw stdext::exception("appearance value '{}' must be text", path);
            if (value.get_ref<const std::string&>().size() > 128)
                throw stdext::exception("appearance value '{}' is too long", path);
            if (value.get_ref<const std::string&>().empty())
                reflection->ClearField(&message, field);
            else
                reflection->SetString(&message, field, value.get<std::string>());
            return;
        default:
            throw stdext::exception("appearance property '{}' is not an editable scalar", path);
    }
}

void setAppearanceEnumList(google::protobuf::Message& message, const std::string& path, const nlohmann::json& values)
{
    const auto separator = path.find('.');
    const auto* field = message.GetDescriptor()->FindFieldByName(path.substr(0, separator));
    if (!field)
        throw stdext::exception("unknown appearance property '{}'", path);
    auto* reflection = message.GetReflection();
    if (separator != std::string::npos) {
        if (field->is_repeated() || field->cpp_type() != google::protobuf::FieldDescriptor::CPPTYPE_MESSAGE)
            throw stdext::exception("invalid appearance property path");
        auto* nested = reflection->MutableMessage(&message, field);
        setAppearanceEnumList(*nested, path.substr(separator + 1), values);
        std::vector<const google::protobuf::FieldDescriptor*> presentFields;
        nested->GetReflection()->ListFields(*nested, &presentFields);
        if (presentFields.empty())
            reflection->ClearField(&message, field);
        return;
    }
    if (!field->is_repeated() || field->cpp_type() != google::protobuf::FieldDescriptor::CPPTYPE_ENUM || !values.is_array())
        throw stdext::exception("appearance property '{}' must be a list of enum values", path);
    if (values.size() > 32)
        throw stdext::exception("appearance property '{}' contains too many values", path);

    std::set<int> uniqueValues;
    for (const auto& value : values) {
        if (!value.is_number_integer())
            throw stdext::exception("appearance property '{}' contains a non-integer enum value", path);
        const int number = value.get<int>();
        const auto* enumValue = field->enum_type()->FindValueByNumber(number);
        if (!enumValue)
            throw stdext::exception("appearance property '{}' contains an unknown enum value", path);
        uniqueValues.insert(number);
    }

    reflection->ClearField(&message, field);
    for (const auto number : uniqueValues)
        reflection->AddEnum(&message, field, field->enum_type()->FindValueByNumber(number));
}

void readAppearancesFile(const std::filesystem::path& path, appearances::Appearances& library)
{
    std::ifstream stream(path, std::ios::binary);
    if (!stream || !library.ParseFromIstream(&stream))
        throw stdext::exception("could not parse the work copy appearances file");
}

void writeAppearancesFile(const std::filesystem::path& path, const appearances::Appearances& library)
{
    namespace fs = std::filesystem;
    const auto temporary = fs::path(path.string() + ".sprite-editor.tmp");
    const auto backup = fs::path(path.string() + ".sprite-editor.bak");
    std::error_code error;
    for (const auto& candidate : { temporary, backup }) {
        const auto status = fs::symlink_status(candidate, error);
        if (!error && fs::is_symlink(status))
            throw stdext::exception("appearance work copy contains an unsafe temporary path");
        if (error == std::errc::no_such_file_or_directory)
            error.clear();
        else if (error)
            throw stdext::exception("unable to validate appearance temporary path: {}", error.message());
    }
    if (fs::exists(backup, error)) {
        if (!fs::exists(path, error)) {
            fs::rename(backup, path, error);
            if (error) throw stdext::exception("could not recover the previous appearances file: {}", error.message());
        } else {
            fs::remove(backup, error);
        }
    }
    error.clear();
    fs::remove(temporary, error);
    std::ofstream stream(temporary, std::ios::binary | std::ios::trunc);
    if (!stream || !library.SerializeToOstream(&stream))
        throw stdext::exception("could not write the temporary appearances file");
    stream.flush();
    if (!stream)
        throw stdext::exception("could not flush the temporary appearances file");
    stream.close();

    appearances::Appearances verification;
    readAppearancesFile(temporary, verification);

    error.clear();
    fs::rename(path, backup, error);
    if (error)
        throw stdext::exception("could not stage the previous appearances file: {}", error.message());
    fs::rename(temporary, path, error);
    if (error) {
        std::error_code rollbackError;
        fs::rename(backup, path, rollbackError);
        throw stdext::exception("could not replace the appearances file: {}", error.message());
    }
    fs::remove(backup, error);
}

bool isBundlePathWithin(const std::filesystem::path& root, const std::filesystem::path& path)
{
    const auto relative = path.lexically_relative(root);
    return !relative.empty() && relative != "." && !relative.is_absolute() && *relative.begin() != "..";
}

std::filesystem::path getBundleFile(const std::filesystem::path& root, const std::string& relativeFile)
{
    namespace fs = std::filesystem;
    auto relative = fs::path(relativeFile).lexically_normal();
    if (relative.empty() || relative.is_absolute() || relative.has_root_name() || relative.has_root_directory())
        throw stdext::exception("appearance bundle contains an invalid file path");
    for (const auto& part : relative) {
        if (part == ".." || part == ".")
            throw stdext::exception("appearance bundle contains an invalid file path");
    }

    auto current = root;
    std::error_code error;
    for (const auto& part : relative) {
        current /= part;
        const auto status = fs::symlink_status(current, error);
        if (error == std::errc::no_such_file_or_directory)
            throw stdext::exception("appearance bundle is missing a required file");
        if (error)
            throw stdext::exception("unable to inspect an appearance bundle file: {}", error.message());
        if (fs::is_symlink(status))
            throw stdext::exception("appearance bundles cannot contain symbolic links");
    }
    if (!isBundlePathWithin(root, current) || !fs::is_regular_file(current))
        throw stdext::exception("appearance bundle contains a missing or unsupported file");
    return current;
}

std::string getAppearanceCategoryName(const int category)
{
    switch (category) {
        case ThingCategoryItem: return "objects";
        case ThingCategoryCreature: return "outfits";
        case ThingCategoryEffect: return "effects";
        case ThingCategoryMissile: return "missiles";
        default: throw stdext::exception("invalid appearance category");
    }
}

std::string readFileText(const std::filesystem::path& path)
{
    std::ifstream stream(path, std::ios::binary);
    if (!stream)
        throw stdext::exception("unable to read the asset catalog before appearance import");
    return { std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>() };
}

void restoreFileSnapshot(const std::filesystem::path& path, const std::string& contents)
{
    namespace fs = std::filesystem;
    const fs::path temporary(path.string() + ".bundle-rollback.tmp");
    const fs::path backup(path.string() + ".bundle-rollback.bak");
    std::error_code error;
    for (const auto& candidate : { temporary, backup }) {
        const auto status = fs::symlink_status(candidate, error);
        if (!error && fs::is_symlink(status))
            throw stdext::exception("appearance import rollback found an unsafe temporary path");
        if (error == std::errc::no_such_file_or_directory)
            error.clear();
        else if (error)
            throw stdext::exception("unable to validate appearance import rollback path: {}", error.message());
    }
    fs::remove(backup, error);
    if (error)
        throw stdext::exception("unable to clear the previous appearance rollback file: {}", error.message());

    {
        std::ofstream stream(temporary, std::ios::binary | std::ios::trunc);
        if (!stream)
            throw stdext::exception("unable to stage the asset catalog rollback");
        stream.write(contents.data(), static_cast<std::streamsize>(contents.size()));
        stream.flush();
        if (!stream)
            throw stdext::exception("unable to write the asset catalog rollback");
    }

    fs::rename(path, backup, error);
    if (error)
        throw stdext::exception("unable to stage the asset catalog rollback: {}", error.message());
    fs::rename(temporary, path, error);
    if (error) {
        std::error_code rollbackError;
        fs::rename(backup, path, rollbackError);
        throw stdext::exception("unable to restore the asset catalog: {}", error.message());
    }
    fs::remove(backup, error);
}

}
#endif

#ifdef FRAMEWORK_EDITOR
void ThingTypeManager::invalidateTextureCache()
{
    for (auto& category : m_thingTypes) {
        for (const auto& thingType : category) {
            if (thingType)
                thingType->unload();
        }
    }
}

std::string ThingTypeManager::getAppearanceEditorData(const int version, const int category, const int id)
{
#ifdef FRAMEWORK_PROTOBUF
    if (id < 1)
        throw stdext::exception("appearance ID must be positive");
    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    const auto* appearance = findAppearance(library, category, id);
    if (!appearance)
        throw stdext::exception("appearance {} was not found", id);

    nlohmann::json result = {
        { "bools", nlohmann::json::object() },
        { "values", nlohmann::json::object() },
        { "textValues", nlohmann::json::object() },
        { "enumOptions", nlohmann::json::object() },
        { "multiValues", nlohmann::json::object() },
        { "unsetValues", nlohmann::json::object() }
    };
    if (category == ThingCategoryItem)
        collectAppearanceFields(appearance->flags(), "", result["bools"], result["values"], result["textValues"],
                                result["enumOptions"], result["multiValues"], result["unsetValues"]);
    result["name"] = appearance->name();
    result["description"] = appearance->description();
    result["frameGroups"] = nlohmann::json::array();
    for (int index = 0; index < appearance->frame_group_size(); ++index) {
        const auto& frameGroup = appearance->frame_group(index);
        const auto& spriteInfo = frameGroup.sprite_info();
        const auto& animation = spriteInfo.animation();
        const uint32_t layers = std::max<uint32_t>(1, spriteInfo.layers());
        const uint32_t patternWidth = std::max<uint32_t>(1, spriteInfo.pattern_width());
        const uint32_t patternHeight = std::max<uint32_t>(1, spriteInfo.pattern_height());
        const uint32_t patternDepth = std::max<uint32_t>(1, spriteInfo.pattern_depth());
        const uint32_t spritesPerPhase = layers * patternWidth * patternHeight * patternDepth;
        const uint32_t spritePhases = std::max<uint32_t>(1, spriteInfo.sprite_id_size() / spritesPerPhase);

        nlohmann::json group = {
            { "index", index },
            { "type", frameGroup.has_fixed_frame_group() ? frameGroup.fixed_frame_group() : -1 },
            { "id", frameGroup.has_id() ? frameGroup.id() : -1 },
            { "layers", layers },
            { "patternWidth", patternWidth },
            { "patternHeight", patternHeight },
            { "patternDepth", patternDepth },
            { "phaseCount", animation.sprite_phase_size() > 0 ? animation.sprite_phase_size() : spritePhases },
            { "sprites", nlohmann::json::array() },
            { "animation", {
                { "enabled", spriteInfo.has_animation() },
                { "defaultStartPhase", animation.default_start_phase() },
                { "randomStartPhase", animation.random_start_phase() },
                { "synchronized", animation.synchronized() },
                { "loopType", animation.loop_type() },
                { "loopCount", animation.loop_count() },
                { "phases", nlohmann::json::array() }
            } }
        };
        for (const auto spriteId : spriteInfo.sprite_id())
            group["sprites"].push_back(spriteId);
        for (const auto& phase : animation.sprite_phase()) {
            group["animation"]["phases"].push_back({
                { "durationMin", phase.duration_min() },
                { "durationMax", phase.duration_max() }
            });
        }
        result["frameGroups"].push_back(std::move(group));
    }
    return result.dump();
#else
    throw stdext::exception("protobuf support is required to edit appearances");
#endif
}

std::string ThingTypeManager::getAppearanceEditorSnapshot(const int version, const int category, const int id)
{
#ifdef FRAMEWORK_PROTOBUF
    if (id < 1)
        throw stdext::exception("appearance ID must be positive");
    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    const auto* appearance = findAppearance(library, category, id);
    if (!appearance)
        throw stdext::exception("appearance {} was not found", id);
    std::string serialized;
    if (!appearance->SerializeToString(&serialized))
        throw stdext::exception("could not save the appearance state for asset history");
    return g_crypt.base64Encode(serialized);
#else
    throw stdext::exception("protobuf support is required to edit appearances");
#endif
}

bool ThingTypeManager::restoreAppearanceEditorSnapshot(const int version, const int category, const int id,
                                                        const bool present, const std::string& snapshot)
{
#ifdef FRAMEWORK_PROTOBUF
    if (version < 1500 || version >= 1600 || id < 1)
        throw stdext::exception("appearance history restore is supported only for valid 15.x IDs");
    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    auto* bank = getAppearanceBank(library, category);
    int existingIndex = -1;
    for (int index = 0; index < bank->size(); ++index) {
        if (bank->Get(index).id() == static_cast<uint32_t>(id)) {
            existingIndex = index;
            break;
        }
    }

    if (!present) {
        if (existingIndex < 0)
            return false;
        bank->DeleteSubrange(existingIndex, 1);
    } else {
        if (snapshot.empty() || snapshot.size() > 8 * 1024 * 1024)
            throw stdext::exception("the saved appearance state is missing or too large");
        const auto decoded = g_crypt.base64Decode(snapshot);
        appearances::Appearance restored;
        if (!restored.ParseFromArray(decoded.data(), static_cast<int>(decoded.size())) ||
            restored.id() != static_cast<uint32_t>(id))
            throw stdext::exception("the saved appearance state is invalid or belongs to another ID");
        if (existingIndex < 0)
            *bank->Add() = std::move(restored);
        else
            bank->Mutable(existingIndex)->CopyFrom(restored);
    }

    writeAppearancesFile(path, library);
    return true;
#else
    throw stdext::exception("protobuf support is required to restore appearance history");
#endif
}

bool ThingTypeManager::saveAppearanceEditorData(const int version, const int category, const int id, const std::string& changes)
{
#ifdef FRAMEWORK_PROTOBUF
    if (id < 1)
        throw stdext::exception("appearance ID must be positive");
    const auto updates = nlohmann::json::parse(changes);
    if (!updates.is_object())
        throw stdext::exception("appearance changes must be an object");

    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    auto* appearance = findAppearance(library, category, id);
    if (!appearance)
        throw stdext::exception("appearance {} was not found", id);

    const auto strings = updates.find("strings");
    if (strings != updates.end()) {
        if (!strings->is_object())
            throw stdext::exception("appearance changes section 'strings' must be an object");
        for (const auto* field : { "name", "description" }) {
            const auto it = strings->find(field);
            if (it == strings->end())
                continue;
            if (!it->is_string())
                throw stdext::exception("appearance field '{}' must be text", field);
            const auto value = it->get<std::string>();
            const size_t maximumLength = std::string_view(field) == "name" ? 128 : 512;
            if (value.size() > maximumLength)
                throw stdext::exception("appearance field '{}' is too long", field);
            if (std::string_view(field) == "name")
                appearance->set_name(value);
            else
                appearance->set_description(value);
        }
    }

    for (const auto* section : { "bools", "values" }) {
        const auto it = updates.find(section);
        if (it == updates.end())
            continue;
        if (!it->is_object())
            throw stdext::exception("appearance changes section '{}' must be an object", section);
        if (category != ThingCategoryItem) {
            if (!it->empty())
                throw stdext::exception("appearance flags and values can only be edited for objects");
            continue;
        }

        auto* flags = appearance->mutable_flags();
        for (auto field = it->begin(); field != it->end(); ++field) {
            if (field.key() == "clothes.slot") {
                const auto& slotValue = field.value();
                if (!slotValue.is_number_unsigned() && (!slotValue.is_number_integer() || slotValue.get<int64_t>() < 0))
                    throw stdext::exception("appearance equipment slot must be between 0 and 10");
                const auto slot = slotValue.get<uint64_t>();
                if (slot > 10)
                    throw stdext::exception("appearance equipment slot must be between 0 and 10");
                if (slot == 0) {
                    const auto* clothesField = flags->GetDescriptor()->FindFieldByName("clothes");
                    if (!clothesField || clothesField->cpp_type() != google::protobuf::FieldDescriptor::CPPTYPE_MESSAGE)
                        throw stdext::exception("appearance equipment slot field is unavailable");
                    flags->GetReflection()->ClearField(flags, clothesField);
                    continue;
                }
            }
            setAppearanceScalar(*flags, field.key(), field.value());
        }
    }

    for (const auto* section : { "textValues", "multiValues" }) {
        const auto it = updates.find(section);
        if (it == updates.end())
            continue;
        if (!it->is_object())
            throw stdext::exception("appearance changes section '{}' must be an object", section);
        if (category != ThingCategoryItem) {
            if (!it->empty())
                throw stdext::exception("appearance flags and values can only be edited for objects");
            continue;
        }

        auto* flags = appearance->mutable_flags();
        for (auto field = it->begin(); field != it->end(); ++field) {
            if (section == std::string_view("textValues"))
                setAppearanceScalar(*flags, field.key(), field.value());
            else
                setAppearanceEnumList(*flags, field.key(), field.value());
        }
    }

    const auto animationChanges = updates.find("animation");
    if (animationChanges != updates.end()) {
        if (!animationChanges->is_object())
            throw stdext::exception("appearance changes section 'animation' must be an object");
        const auto groups = animationChanges->find("groups");
        if (groups != animationChanges->end()) {
            if (!groups->is_object())
                throw stdext::exception("appearance animation groups must be an object");
            for (auto groupChange = groups->begin(); groupChange != groups->end(); ++groupChange) {
                size_t parsedLength = 0;
                const int groupIndex = std::stoi(groupChange.key(), &parsedLength);
                if (parsedLength != groupChange.key().size() || groupIndex < 0 || groupIndex >= appearance->frame_group_size())
                    throw stdext::exception("invalid appearance animation frame group");
                if (!groupChange->is_object())
                    throw stdext::exception("appearance animation group changes must be an object");

                auto* spriteInfo = appearance->mutable_frame_group(groupIndex)->mutable_sprite_info();
                uint64_t spritesPerPhase = 1;
                const auto multiplySpriteDimension = [&](const uint32_t dimension) {
                    const auto maximumSpriteCount = static_cast<uint64_t>(std::numeric_limits<int>::max());
                    if (dimension == 0 || spritesPerPhase > maximumSpriteCount / dimension)
                        throw stdext::exception("appearance frame group dimensions are too large");
                    spritesPerPhase *= dimension;
                };
                multiplySpriteDimension(std::max<uint32_t>(1, spriteInfo->layers()));
                multiplySpriteDimension(std::max<uint32_t>(1, spriteInfo->pattern_width()));
                multiplySpriteDimension(std::max<uint32_t>(1, spriteInfo->pattern_height()));
                multiplySpriteDimension(std::max<uint32_t>(1, spriteInfo->pattern_depth()));

                const auto* currentAnimation = &spriteInfo->animation();
                const bool hadAnimation = spriteInfo->has_animation();
                const uint64_t currentPhaseCount = currentAnimation->sprite_phase_size() > 0
                    ? currentAnimation->sprite_phase_size()
                    : std::max<uint64_t>(1, spriteInfo->sprite_id_size() / spritesPerPhase);
                if (spriteInfo->sprite_id_size() != currentPhaseCount * spritesPerPhase)
                    throw stdext::exception("appearance frame group has inconsistent sprite and animation frames");

                uint64_t requestedPhaseCount = currentPhaseCount;
                const auto phaseCountChange = groupChange->find("phaseCount");
                if (phaseCountChange != groupChange->end()) {
                    if ((!phaseCountChange->is_number_unsigned() && !phaseCountChange->is_number_integer()) ||
                        (phaseCountChange->is_number_integer() && phaseCountChange->get<int64_t>() < 1))
                        throw stdext::exception("animation frame count must be a positive integer");
                    requestedPhaseCount = phaseCountChange->get<uint64_t>();
                    if (requestedPhaseCount == 0 ||
                        requestedPhaseCount > static_cast<uint64_t>(std::numeric_limits<int>::max()) / spritesPerPhase)
                        throw stdext::exception("animation frame count is too large for this appearance");
                }

                if (requestedPhaseCount > currentPhaseCount) {
                    for (uint64_t phase = currentPhaseCount; phase < requestedPhaseCount; ++phase) {
                        const auto sourceStart = static_cast<int>((phase - 1) * spritesPerPhase);
                        for (uint64_t sprite = 0; sprite < spritesPerPhase; ++sprite) {
                            const auto spriteId = spriteInfo->sprite_id(sourceStart + static_cast<int>(sprite));
                            spriteInfo->add_sprite_id(spriteId);
                        }
                    }
                } else if (requestedPhaseCount < currentPhaseCount) {
                    auto* spriteIds = spriteInfo->mutable_sprite_id();
                    const auto remainingSpriteCount = static_cast<int>(requestedPhaseCount * spritesPerPhase);
                    while (spriteIds->size() > remainingSpriteCount)
                        spriteIds->RemoveLast();
                }

                const bool frameCountChanged = requestedPhaseCount != currentPhaseCount;
                if (requestedPhaseCount == 1 && frameCountChanged) {
                    spriteInfo->clear_animation();
                } else if (requestedPhaseCount > 1 && frameCountChanged) {
                    auto* resizedAnimation = spriteInfo->mutable_animation();
                    if (!hadAnimation)
                        resizedAnimation->set_loop_type(appearances::ANIMATION_LOOP_TYPE_INFINITE);
                    while (resizedAnimation->sprite_phase_size() > static_cast<int>(requestedPhaseCount))
                        resizedAnimation->mutable_sprite_phase()->RemoveLast();
                    while (resizedAnimation->sprite_phase_size() < static_cast<int>(requestedPhaseCount)) {
                        auto* phase = resizedAnimation->add_sprite_phase();
                        phase->set_duration_min(DEFAULT_ANIMATION_FRAME_DURATION_MS);
                        phase->set_duration_max(DEFAULT_ANIMATION_FRAME_DURATION_MS);
                    }
                    if (resizedAnimation->default_start_phase() >= requestedPhaseCount)
                        resizedAnimation->set_default_start_phase(0);
                }

                if (!spriteInfo->has_animation()) {
                    if (groupChange->contains("defaultStartPhase") || groupChange->contains("loopCount") ||
                        groupChange->contains("randomStartPhase") || groupChange->contains("synchronized") ||
                        groupChange->contains("loopType") || groupChange->contains("phases"))
                        throw stdext::exception("appearance frame group has no animation data");
                    continue;
                }
                auto* animation = spriteInfo->mutable_animation();
                const auto setUint32 = [&](const char* field, const auto& setter) {
                    const auto value = groupChange->find(field);
                    if (value == groupChange->end())
                        return;
                    if ((!value->is_number_unsigned() && !value->is_number_integer()) ||
                        (value->is_number_integer() && value->get<int64_t>() < 0) ||
                        value->get<uint64_t>() > std::numeric_limits<uint32_t>::max())
                        throw stdext::exception("animation field '{}' must be a 32-bit unsigned integer", field);
                    setter(value->get<uint32_t>());
                };
                const auto setBool = [&](const char* field, const auto& setter) {
                    const auto value = groupChange->find(field);
                    if (value == groupChange->end())
                        return;
                    if (!value->is_boolean())
                        throw stdext::exception("animation field '{}' must be boolean", field);
                    setter(value->get<bool>());
                };

                setUint32("defaultStartPhase", [&](const uint32_t value) { animation->set_default_start_phase(value); });
                setUint32("loopCount", [&](const uint32_t value) { animation->set_loop_count(value); });
                setBool("randomStartPhase", [&](const bool value) { animation->set_random_start_phase(value); });
                setBool("synchronized", [&](const bool value) { animation->set_synchronized(value); });
                const uint64_t phaseCount = animation->sprite_phase_size() > 0
                    ? animation->sprite_phase_size()
                    : std::max<uint64_t>(1, spriteInfo->sprite_id_size() / spritesPerPhase);
                if (animation->default_start_phase() >= phaseCount)
                    throw stdext::exception("default animation phase is outside the frame group");

                const auto loopType = groupChange->find("loopType");
                if (loopType != groupChange->end()) {
                    if (!loopType->is_number_integer())
                        throw stdext::exception("animation loop type must be an integer");
                    const int value = loopType->get<int>();
                    if (value != -1 && value != 0 && value != 1)
                        throw stdext::exception("unknown appearance animation loop type");
                    animation->set_loop_type(static_cast<appearances::ANIMATION_LOOP_TYPE>(value));
                }

                const auto phaseChanges = groupChange->find("phases");
                if (phaseChanges != groupChange->end()) {
                    if (!phaseChanges->is_object())
                        throw stdext::exception("appearance animation phases must be an object");
                    for (auto phaseChange = phaseChanges->begin(); phaseChange != phaseChanges->end(); ++phaseChange) {
                        size_t parsedLength = 0;
                        const int phaseIndex = std::stoi(phaseChange.key(), &parsedLength);
                        if (parsedLength != phaseChange.key().size() || phaseIndex < 0 || phaseIndex >= animation->sprite_phase_size())
                            throw stdext::exception("invalid appearance animation phase");
                        if (!phaseChange->is_object())
                            throw stdext::exception("appearance animation phase changes must be an object");

                        auto* phase = animation->mutable_sprite_phase(phaseIndex);
                        const auto setDuration = [&](const char* field, const auto& setter, const uint32_t current) {
                            const auto value = phaseChange->find(field);
                            if (value == phaseChange->end())
                                return current;
                            if ((!value->is_number_unsigned() && !value->is_number_integer()) ||
                                (value->is_number_integer() && value->get<int64_t>() < 0) ||
                                value->get<uint64_t>() > std::numeric_limits<uint32_t>::max())
                                throw stdext::exception("animation duration '{}' must be a 32-bit unsigned integer", field);
                            const auto duration = value->get<uint32_t>();
                            setter(duration);
                            return duration;
                        };
                        const uint32_t durationMin = setDuration("durationMin", [&](const uint32_t value) { phase->set_duration_min(value); }, phase->duration_min());
                        const uint32_t durationMax = setDuration("durationMax", [&](const uint32_t value) { phase->set_duration_max(value); }, phase->duration_max());
                        if (durationMin > durationMax)
                            throw stdext::exception("minimum animation duration cannot exceed maximum duration");
                    }
                }
            }
        }
    }

    writeAppearancesFile(path, library);
    return true;
#else
    throw stdext::exception("protobuf support is required to edit appearances");
#endif
}

bool ThingTypeManager::replaceAppearanceSprite(const int version, const int category, const int appearanceId,
                                               const int frameGroupIndex, const int spriteIndex, const int spriteId)
{
#ifdef FRAMEWORK_PROTOBUF
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance sprite replacement is supported only for client versions 15.x");
    if (appearanceId < 1 || frameGroupIndex < 0 || spriteIndex < 0 || spriteId < 1)
        throw stdext::exception("invalid appearance sprite replacement request");
    const auto replacementSheet = g_spriteAppearances.getSheetBySpriteId(spriteId, false);
    if (!replacementSheet)
        throw stdext::exception("sprite {} is not part of the active work copy", spriteId);

    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    auto* appearance = findAppearance(library, category, appearanceId);
    if (!appearance)
        throw stdext::exception("appearance {} was not found", appearanceId);
    if (frameGroupIndex >= appearance->frame_group_size())
        throw stdext::exception("appearance frame group is outside the selected appearance");

    auto* spriteIds = appearance->mutable_frame_group(frameGroupIndex)->mutable_sprite_info();
    if (spriteIndex >= spriteIds->sprite_id_size())
        throw stdext::exception("sprite position is outside the selected frame group");
    const auto currentSheet = g_spriteAppearances.getSheetBySpriteId(spriteIds->sprite_id(spriteIndex), false);
    if (currentSheet && (currentSheet->getSpriteSize().width() != replacementSheet->getSpriteSize().width() ||
                         currentSheet->getSpriteSize().height() != replacementSheet->getSpriteSize().height()))
        throw stdext::exception("replacement sprite dimensions must match the selected frame");
    spriteIds->set_sprite_id(spriteIndex, static_cast<uint32_t>(spriteId));

    writeAppearancesFile(path, library);
    return true;
#else
    throw stdext::exception("protobuf support is required to replace appearance sprites");
#endif
}

int ThingTypeManager::createAppearanceFromSprite(const int version, const int category, const int spriteId)
{
#ifdef FRAMEWORK_PROTOBUF
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance creation is supported only for client versions 15.x");
    if (spriteId < 1)
        throw stdext::exception("enter a valid sprite ID");
    if (!g_spriteAppearances.getSheetBySpriteId(spriteId, false))
        throw stdext::exception("sprite {} is not part of the active work copy", spriteId);

    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    auto* bank = getAppearanceBank(library, category);
    uint32_t maximumId = 0;
    for (const auto& appearance : *bank)
        maximumId = std::max(maximumId, appearance.id());
    if (maximumId >= std::numeric_limits<uint16_t>::max())
        throw stdext::exception("the selected appearance category has no available 15.x IDs");

    const uint32_t id = maximumId + 1;
    auto* appearance = bank->Add();
    appearance->set_id(id);
    auto* frameGroup = appearance->mutable_frame_group()->Add();
    frameGroup->set_fixed_frame_group(category == ThingCategoryCreature
        ? appearances::FIXED_FRAME_GROUP_OUTFIT_IDLE
        : appearances::FIXED_FRAME_GROUP_OBJECT_INITIAL);
    frameGroup->set_id(0);
    auto* spriteInfo = frameGroup->mutable_sprite_info();
    spriteInfo->set_pattern_width(1);
    spriteInfo->set_pattern_height(1);
    spriteInfo->set_pattern_depth(1);
    spriteInfo->set_layers(1);
    spriteInfo->add_sprite_id(static_cast<uint32_t>(spriteId));

    writeAppearancesFile(path, library);
    return static_cast<int>(id);
#else
    throw stdext::exception("protobuf support is required to create appearances");
#endif
}

int ThingTypeManager::duplicateAppearance(const int version, const int category, const int sourceId)
{
#ifdef FRAMEWORK_PROTOBUF
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance duplication is supported only for client versions 15.x");
    if (sourceId < 1)
        throw stdext::exception("appearance ID must be positive");

    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    const auto* source = findAppearance(library, category, sourceId);
    if (!source)
        throw stdext::exception("appearance {} was not found", sourceId);
    const appearances::Appearance sourceCopy = *source;
    auto* bank = getAppearanceBank(library, category);

    uint32_t maximumId = 0;
    for (const auto& appearance : *bank)
        maximumId = std::max(maximumId, appearance.id());
    if (maximumId >= std::numeric_limits<uint16_t>::max())
        throw stdext::exception("the selected appearance category has no available 15.x IDs");

    const uint32_t id = maximumId + 1;
    auto* duplicate = bank->Add();
    duplicate->CopyFrom(sourceCopy);
    duplicate->set_id(id);
    writeAppearancesFile(path, library);
    return static_cast<int>(id);
#else
    throw stdext::exception("protobuf support is required to duplicate appearances");
#endif
}

bool ThingTypeManager::deleteAppearance(const int version, const int category, const int id)
{
#ifdef FRAMEWORK_PROTOBUF
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance deletion is supported only for client versions 15.x");
    if (id < 1)
        throw stdext::exception("appearance ID must be positive");

    const auto path = getAppearanceEditorFile(m_catalogContentPath, version);
    appearances::Appearances library;
    readAppearancesFile(path, library);
    auto* bank = getAppearanceBank(library, category);
    for (int index = 0; index < bank->size(); ++index) {
        if (bank->Get(index).id() != static_cast<uint32_t>(id))
            continue;

        bank->DeleteSubrange(index, 1);
        writeAppearancesFile(path, library);
        return true;
    }
    throw stdext::exception("appearance {} was not found", id);
#else
    throw stdext::exception("protobuf support is required to delete appearances");
#endif
}

std::string ThingTypeManager::exportAppearanceBundle(const int version, const int category, const int id,
                                                     const std::string& destination)
{
#ifdef FRAMEWORK_PROTOBUF
    namespace fs = std::filesystem;
    if (version < 1500 || version >= 1600 || id < 1)
        throw stdext::exception("appearance bundle export is supported for 15.x appearances only");
    if (destination.empty() || !fs::path(destination).is_absolute())
        throw stdext::exception("choose an absolute destination folder for the appearance bundle");

    const auto appearanceFile = getAppearanceEditorFile(m_catalogContentPath, version);
    const auto sourcePackage = fs::weakly_canonical(appearanceFile.parent_path());
    std::error_code error;
    const auto parent = fs::canonical(fs::path(destination), error);
    if (error || !fs::is_directory(parent))
        throw stdext::exception("the appearance bundle destination must be an existing folder");

    appearances::Appearances library;
    readAppearancesFile(appearanceFile, library);
    const auto* selectedAppearance = findAppearance(library, category, id);
    if (!selectedAppearance)
        throw stdext::exception("appearance {} was not found", id);
    const appearances::Appearance appearance = *selectedAppearance;

    std::set<uint32_t> spriteIds;
    for (const auto& frameGroup : appearance.frame_group()) {
        if (!frameGroup.has_sprite_info())
            throw stdext::exception("the appearance contains a frame group without sprite data");
        for (const auto spriteId : frameGroup.sprite_info().sprite_id()) {
            if (spriteId == 0)
                throw stdext::exception("the appearance contains an invalid sprite ID");
            spriteIds.insert(spriteId);
        }
    }
    if (spriteIds.empty() || spriteIds.size() > 256)
        throw stdext::exception("appearance bundles require between 1 and 256 referenced sprites");

    const auto bundleName = fmt::format("appearance-{}-{}", getAppearanceCategoryName(category), id);
    const auto target = parent / bundleName;
    const auto temporary = parent / (bundleName + ".sprite-editor.tmp");
    if (isBundlePathWithin(sourcePackage, target) || isBundlePathWithin(target, sourcePackage))
        throw stdext::exception("export the appearance bundle outside the active work copy");
    if (fs::exists(target) || fs::exists(temporary))
        throw stdext::exception("an appearance bundle already exists at the destination; it will not be overwritten");

    try {
        fs::create_directories(temporary / "sprites");
        nlohmann::json manifest = {
            { "format", "otclient-appearance-bundle" },
            { "formatVersion", 1 },
            { "clientVersion", version },
            { "category", category },
            { "appearanceId", id },
            { "appearanceFile", "appearance.pb" },
            { "sprites", nlohmann::json::array() }
        };

        for (const auto spriteId : spriteIds) {
            const auto sheet = g_spriteAppearances.getSheetBySpriteId(static_cast<int>(spriteId), false);
            const auto image = g_spriteAppearances.getSpriteImage(static_cast<int>(spriteId));
            if (!sheet || !image)
                throw stdext::exception("sprite {} is missing from the active work copy", spriteId);
            const auto fileName = fmt::format("sprites/{}.png", spriteId);
            std::stringstream pngData;
            save_png(pngData, image->getSize().width(), image->getSize().height(), 4, image->getPixelData());
            const auto pngBytes = pngData.str();
            std::ofstream pngFile(temporary / fileName, std::ios::binary | std::ios::trunc);
            if (!pngFile)
                throw stdext::exception("unable to create an exported sprite PNG");
            pngFile.write(pngBytes.data(), static_cast<std::streamsize>(pngBytes.size()));
            pngFile.flush();
            if (!pngFile)
                throw stdext::exception("unable to finish writing an exported sprite PNG");
            manifest["sprites"].push_back({
                { "id", spriteId },
                { "file", fileName },
                { "width", image->getSize().width() },
                { "height", image->getSize().height() }
            });
        }

        {
            std::ofstream stream(temporary / "appearance.pb", std::ios::binary | std::ios::trunc);
            if (!stream || !appearance.SerializeToOstream(&stream))
                throw stdext::exception("unable to write the appearance data file");
            stream.flush();
            if (!stream)
                throw stdext::exception("unable to finish writing the appearance data file");
        }
        {
            std::ofstream stream(temporary / "manifest.json", std::ios::binary | std::ios::trunc);
            if (!stream)
                throw stdext::exception("unable to write the appearance bundle manifest");
            stream << manifest.dump(2);
            stream.flush();
            if (!stream)
                throw stdext::exception("unable to finish writing the appearance bundle manifest");
        }

        appearances::Appearance verifiedAppearance;
        std::ifstream appearanceStream(temporary / "appearance.pb", std::ios::binary);
        if (!appearanceStream || !verifiedAppearance.ParseFromIstream(&appearanceStream) ||
            verifiedAppearance.id() != appearance.id())
            throw stdext::exception("appearance bundle verification failed");
        for (const auto& sprite : manifest.at("sprites")) {
            const auto png = temporary / sprite.at("file").get<std::string>();
            if (!fs::is_regular_file(png) || fs::file_size(png) == 0)
                throw stdext::exception("appearance bundle is missing an exported sprite image");
        }
        fs::rename(temporary, target);
    } catch (...) {
        fs::remove_all(temporary, error);
        throw;
    }

    return target.generic_string();
#else
    throw stdext::exception("protobuf support is required to export appearance bundles");
#endif
}

std::string ThingTypeManager::exportAppearanceBundles(const int version, const int category,
                                                      const std::string& appearanceIds,
                                                      const std::string& destination)
{
#ifdef FRAMEWORK_PROTOBUF
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance bundle export is supported for 15.x appearances only");
    const auto ids = nlohmann::json::parse(appearanceIds);
    if (!ids.is_array() || ids.empty() || ids.size() > 8)
        throw stdext::exception("select between 1 and 8 appearances for a batch bundle export");
    std::set<int> uniqueIds;
    std::vector<int> orderedIds;
    for (const auto& id : ids) {
        if (!id.is_number_integer() || id.get<int>() < 1 || !uniqueIds.insert(id.get<int>()).second)
            throw stdext::exception("appearance bundle export IDs must be unique positive integers");
        orderedIds.push_back(id.get<int>());
    }

    nlohmann::json result = {
        { "exported", 0 },
        { "failed", 0 },
        { "items", nlohmann::json::array() },
        { "failures", nlohmann::json::array() }
    };
    for (const int id : orderedIds) {
        try {
            const auto path = exportAppearanceBundle(version, category, id, destination);
            result["items"].push_back({ { "id", id }, { "path", path } });
            result["exported"] = result["exported"].get<int>() + 1;
        } catch (const std::exception& exception) {
            result["failures"].push_back({ { "id", id }, { "error", exception.what() } });
            result["failed"] = result["failed"].get<int>() + 1;
        }
    }
    return result.dump();
#else
    throw stdext::exception("protobuf support is required to export appearance bundles");
#endif
}

std::string ThingTypeManager::importAppearanceBundle(const int version, const std::string& bundleDirectory)
{
#ifdef FRAMEWORK_PROTOBUF
    namespace fs = std::filesystem;
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance bundle import is supported only for client versions 15.x");
    const fs::path requestedBundle(bundleDirectory);
    if (bundleDirectory.empty() || !requestedBundle.is_absolute())
        throw stdext::exception("choose an absolute appearance bundle folder");
    std::error_code error;
    const auto rootStatus = fs::symlink_status(requestedBundle, error);
    if (error || fs::is_symlink(rootStatus) || !fs::is_directory(rootStatus))
        throw stdext::exception("the selected appearance bundle folder is invalid");
    const auto root = fs::canonical(requestedBundle, error);
    if (error)
        throw stdext::exception("unable to resolve the appearance bundle folder: {}", error.message());

    const auto manifestPath = getBundleFile(root, "manifest.json");
    if (fs::file_size(manifestPath) > 1024 * 1024)
        throw stdext::exception("appearance bundle manifest is too large");
    std::ifstream manifestStream(manifestPath, std::ios::binary);
    nlohmann::json manifest = nlohmann::json::parse(manifestStream);
    if (!manifest.is_object() || manifest.value("format", std::string{}) != "otclient-appearance-bundle" ||
        manifest.value("formatVersion", 0) != 1)
        throw stdext::exception("the selected folder is not a supported OTClient appearance bundle");

    const int sourceVersion = manifest.value("clientVersion", 0);
    const int category = manifest.value("category", -1);
    const int sourceId = manifest.value("appearanceId", 0);
    if (sourceVersion < 1500 || sourceVersion >= 1600 || sourceId < 1)
        throw stdext::exception("appearance bundle metadata is invalid");
    getAppearanceCategoryName(category);
    if (manifest.value("appearanceFile", std::string{}) != "appearance.pb")
        throw stdext::exception("appearance bundle references an unsupported appearance data file");

    const auto appearancePath = getBundleFile(root, "appearance.pb");
    if (fs::file_size(appearancePath) > 32 * 1024 * 1024)
        throw stdext::exception("appearance bundle data is too large");
    appearances::Appearance appearance;
    std::ifstream appearanceStream(appearancePath, std::ios::binary);
    if (!appearanceStream || !appearance.ParseFromIstream(&appearanceStream) || appearance.id() != sourceId ||
        appearance.frame_group_size() < 1 || appearance.frame_group_size() > 32)
        throw stdext::exception("appearance bundle data is invalid or does not match its manifest");

    std::set<uint32_t> referencedSpriteIds;
    size_t totalSpriteReferences = 0;
    for (const auto& frameGroup : appearance.frame_group()) {
        if (!frameGroup.has_sprite_info() || frameGroup.sprite_info().sprite_id_size() < 1)
            throw stdext::exception("appearance bundle contains a frame group without sprites");
        totalSpriteReferences += static_cast<size_t>(frameGroup.sprite_info().sprite_id_size());
        if (totalSpriteReferences > 8192)
            throw stdext::exception("appearance bundle contains too many sprite references");
        for (const auto spriteId : frameGroup.sprite_info().sprite_id()) {
            if (spriteId == 0)
                throw stdext::exception("appearance bundle contains an invalid sprite ID");
            referencedSpriteIds.insert(spriteId);
        }
    }
    const auto spriteEntries = manifest.find("sprites");
    if (spriteEntries == manifest.end() || !spriteEntries->is_array() || spriteEntries->empty() ||
        spriteEntries->size() > 256 || spriteEntries->size() != referencedSpriteIds.size())
        throw stdext::exception("appearance bundle sprite inventory does not match the appearance data");

    std::map<uint32_t, std::string> spriteFiles;
    std::set<std::string> listedFiles;
    for (const auto& entry : *spriteEntries) {
        if (!entry.is_object() || !entry.contains("id") || !entry.contains("file") ||
            !entry.contains("width") || !entry.contains("height"))
            throw stdext::exception("appearance bundle contains incomplete sprite metadata");
        const auto spriteId = entry.at("id").get<uint32_t>();
        const auto file = entry.at("file").get<std::string>();
        if (!referencedSpriteIds.contains(spriteId) || spriteFiles.contains(spriteId) ||
            !file.starts_with("sprites/") || fs::path(file).extension() != ".png" ||
            !listedFiles.insert(fs::path(file).filename().string()).second)
            throw stdext::exception("appearance bundle contains a duplicate or unrelated sprite file");
        const auto imagePath = getBundleFile(root, file);
        std::ifstream imageStream(imagePath, std::ios::binary);
        std::array<uint8_t, 24> pngHeader{};
        imageStream.read(reinterpret_cast<char*>(pngHeader.data()), pngHeader.size());
        const uint32_t width = (static_cast<uint32_t>(pngHeader[16]) << 24) |
            (static_cast<uint32_t>(pngHeader[17]) << 16) | (static_cast<uint32_t>(pngHeader[18]) << 8) | pngHeader[19];
        const uint32_t height = (static_cast<uint32_t>(pngHeader[20]) << 24) |
            (static_cast<uint32_t>(pngHeader[21]) << 16) | (static_cast<uint32_t>(pngHeader[22]) << 8) | pngHeader[23];
        if (!imageStream || pngHeader[0] != 137 || pngHeader[1] != 80 || pngHeader[2] != 78 ||
            pngHeader[3] != 71 || entry.at("width").get<uint32_t>() != width ||
            entry.at("height").get<uint32_t>() != height || width == 0 || height == 0 ||
            width > 384 || height > 384)
            throw stdext::exception("appearance bundle contains a sprite image with invalid dimensions");
        spriteFiles.emplace(spriteId, file);
    }

    const auto spriteFolder = root / "sprites";
    const auto spriteFolderStatus = fs::symlink_status(spriteFolder, error);
    if (error || fs::is_symlink(spriteFolderStatus) || !fs::is_directory(spriteFolderStatus))
        throw stdext::exception("appearance bundle sprite folder is missing or unsafe");
    std::set<std::string> actualFiles;
    for (const auto& entry : fs::directory_iterator(spriteFolder)) {
        const auto status = entry.symlink_status();
        if (fs::is_symlink(status) || !fs::is_regular_file(status) || entry.path().extension() != ".png")
            throw stdext::exception("appearance bundle sprite folder contains an unsupported file");
        actualFiles.insert(entry.path().filename().string());
    }
    if (actualFiles != listedFiles)
        throw stdext::exception("appearance bundle sprite files do not match its manifest");

    const auto appearanceFile = getAppearanceEditorFile(m_catalogContentPath, version);
    const auto spriteCatalogPath = appearanceFile.parent_path() / "catalog-content.json";
    const std::string originalCatalog = readFileText(spriteCatalogPath);
    const auto originalCatalogJson = nlohmann::json::parse(originalCatalog);
    std::set<std::string> originalSpriteFiles;
    for (const auto& entry : originalCatalogJson) {
        if (entry.is_object() && entry.value("type", std::string{}) == "sprite" && entry.contains("file"))
            originalSpriteFiles.insert(entry.at("file").get<std::string>());
    }
    appearances::Appearances library;
    readAppearancesFile(appearanceFile, library);
    auto* bank = getAppearanceBank(library, category);
    uint32_t maximumId = 0;
    for (const auto& existing : *bank)
        maximumId = std::max(maximumId, existing.id());
    if (maximumId >= std::numeric_limits<uint16_t>::max())
        throw stdext::exception("the selected appearance category has no available 15.x IDs");

    std::map<uint32_t, uint32_t> remappedIds;
    bool spriteImportSucceeded = false;
    bool appearanceSaved = false;
    const uint32_t newId = maximumId + 1;
    try {
        const auto importedResponse = g_spriteAppearances.importSpritesFromDirectory(spriteFolder.generic_string(), version);
        spriteImportSucceeded = true;
        const auto imported = nlohmann::json::parse(importedResponse);
        if (!imported.is_object() || imported.value("imported", 0) != spriteEntries->size() ||
            !imported.contains("items") || !imported.at("items").is_array())
            throw stdext::exception("appearance bundle sprite import returned an invalid result");
        for (const auto& item : imported.at("items")) {
            const auto fileName = item.at("file").get<std::string>();
            const auto fileIt = std::find_if(spriteFiles.begin(), spriteFiles.end(), [&](const auto& value) {
                return fs::path(value.second).filename() == fileName;
            });
            if (fileIt == spriteFiles.end() || !item.contains("id"))
                throw stdext::exception("appearance bundle sprite IDs could not be remapped");
            remappedIds[fileIt->first] = item.at("id").get<uint32_t>();
        }
        if (remappedIds.size() != spriteFiles.size())
            throw stdext::exception("appearance bundle sprite IDs could not be remapped");

        appearance.set_id(newId);
        for (auto& frameGroup : *appearance.mutable_frame_group()) {
            auto* spriteInfo = frameGroup.mutable_sprite_info();
            for (int index = 0; index < spriteInfo->sprite_id_size(); ++index) {
                const auto oldId = spriteInfo->sprite_id(index);
                const auto replacement = remappedIds.find(oldId);
                if (replacement == remappedIds.end())
                    throw stdext::exception("appearance bundle references a sprite that was not imported");
                spriteInfo->set_sprite_id(index, replacement->second);
            }
        }
        bank->Add()->Swap(&appearance);
        writeAppearancesFile(appearanceFile, library);
        appearanceSaved = true;
    } catch (...) {
        const auto importError = std::current_exception();
        if (spriteImportSucceeded && !appearanceSaved) {
            try {
                const auto updatedCatalog = nlohmann::json::parse(readFileText(spriteCatalogPath));
                std::vector<fs::path> newSpriteSheets;
                const auto package = appearanceFile.parent_path();
                for (const auto& entry : updatedCatalog) {
                    if (!entry.is_object() || entry.value("type", std::string{}) != "sprite" || !entry.contains("file"))
                        continue;
                    const auto relative = fs::path(entry.at("file").get<std::string>());
                    if (relative.has_parent_path() || relative.filename() != relative ||
                        originalSpriteFiles.contains(relative.generic_string()) ||
                        !relative.filename().string().starts_with("sprite-editor-"))
                        continue;
                    newSpriteSheets.push_back(package / relative);
                }
                restoreFileSnapshot(spriteCatalogPath, originalCatalog);
                for (const auto& sheet : newSpriteSheets)
                    fs::remove(sheet, error);
            } catch (const std::exception& rollbackError) {
                try {
                    std::rethrow_exception(importError);
                } catch (const std::exception& importException) {
                    throw stdext::exception("appearance import failed: {}; sprite rollback also failed: {}",
                        importException.what(), rollbackError.what());
                }
            }
        }
        std::rethrow_exception(importError);
    }
    invalidateTextureCache();
    return nlohmann::json({
        { "category", category },
        { "id", newId },
        { "sprites", remappedIds.size() }
    }).dump();
#else
    throw stdext::exception("protobuf support is required to import appearance bundles");
#endif
}

std::string ThingTypeManager::importAppearanceBundlesFromDirectory(const int version, const std::string& directory)
{
#ifdef FRAMEWORK_PROTOBUF
    namespace fs = std::filesystem;
    if (version < 1500 || version >= 1600)
        throw stdext::exception("appearance bundle import is supported only for client versions 15.x");
    const fs::path requestedDirectory(directory);
    if (directory.empty() || !requestedDirectory.is_absolute())
        throw stdext::exception("choose an absolute folder containing appearance bundles");
    std::error_code error;
    const auto status = fs::symlink_status(requestedDirectory, error);
    if (error || fs::is_symlink(status) || !fs::is_directory(status))
        throw stdext::exception("the selected appearance bundle folder is invalid");

    const auto root = fs::canonical(requestedDirectory, error);
    if (error)
        throw stdext::exception("unable to resolve the selected folder: {}", error.message());
    if (fs::is_regular_file(root / "manifest.json")) {
        const auto importedResponse = importAppearanceBundle(version, root.generic_string());
        const auto imported = nlohmann::json::parse(importedResponse);
        return nlohmann::json({
            { "imported", 1 },
            { "failed", 0 },
            { "items", nlohmann::json::array({ {
                { "bundle", root.filename().string() },
                { "category", imported.at("category") },
                { "id", imported.at("id") },
                { "sprites", imported.at("sprites") }
            } }) },
            { "failures", nlohmann::json::array() }
        }).dump();
    }

    std::vector<fs::path> bundles;
    for (const fs::directory_entry& entry : fs::directory_iterator(root)) {
        const auto entryStatus = entry.symlink_status();
        if (fs::is_symlink(entryStatus) || !fs::is_directory(entryStatus))
            continue;
        if (fs::exists(entry.path() / "manifest.json"))
            bundles.push_back(entry.path());
    }
    std::ranges::sort(bundles, [](const fs::path& left, const fs::path& right) {
        return left.filename().string() < right.filename().string();
    });
    constexpr size_t MAX_BUNDLE_IMPORTS = 64;
    if (bundles.empty())
        throw stdext::exception("the selected folder contains no appearance bundle folders");
    if (bundles.size() > MAX_BUNDLE_IMPORTS)
        throw stdext::exception("select a folder with no more than {} appearance bundles", MAX_BUNDLE_IMPORTS);

    nlohmann::json result = {
        { "imported", 0 },
        { "failed", 0 },
        { "items", nlohmann::json::array() },
        { "failures", nlohmann::json::array() }
    };
    for (const auto& bundle : bundles) {
        try {
            const auto importedResponse = importAppearanceBundle(version, bundle.generic_string());
            const auto imported = nlohmann::json::parse(importedResponse);
            result["items"].push_back({
                { "bundle", bundle.filename().string() },
                { "category", imported.at("category") },
                { "id", imported.at("id") },
                { "sprites", imported.at("sprites") }
            });
            result["imported"] = result["imported"].get<int>() + 1;
        } catch (const std::exception& exception) {
            result["failures"].push_back({
                { "bundle", bundle.filename().string() },
                { "error", exception.what() }
            });
            result["failed"] = result["failed"].get<int>() + 1;
        }
    }
    return result.dump();
#else
    throw stdext::exception("protobuf support is required to import appearance bundles");
#endif
}
#endif

const nlohmann::json& ThingTypeManager::getCatalogContent(const std::string& file)
{
    const auto path = g_resources.resolvePath(g_resources.guessFilePath(file + "catalog-content", "json"));
    if (path != m_catalogContentPath || !m_catalogContent) {
        m_catalogContent = std::make_unique<nlohmann::json>(nlohmann::json::parse(g_resources.readFileContents(path)));
        m_catalogContentPath = path;
    }

    return *m_catalogContent;
}

void ThingTypeManager::clearCatalogContent()
{
    m_catalogContentPath.clear();
    m_catalogContent.reset();
}

void ThingTypeManager::init()
{
    m_nullThingType = std::make_shared<ThingType>();
    for (auto& m_thingType : m_thingTypes)
        m_thingType.resize(1, m_nullThingType);
#ifdef FRAMEWORK_EDITOR
    m_nullItemType = std::make_shared<ItemType>();
    m_itemTypes.resize(1, m_nullItemType);
#endif
}

void ThingTypeManager::terminate()
{
    for (auto& m_thingType : m_thingTypes)
        m_thingType.clear();

    m_nullThingType = nullptr;
    m_proficienciesFile.clear();
    m_proficiencyThingsCache.clear();
    m_proficiencyThingsCacheDirty = true;
    clearCatalogContent();

#ifdef FRAMEWORK_EDITOR
    m_itemTypes.clear();
    m_reverseItemTypes.clear();
    m_nullItemType = nullptr;
#endif
}

bool ThingTypeManager::loadDat(std::string file)
{
    m_datLoaded = false;
    m_datSignature = 0;
    m_contentRevision = 0;
    try {
        file = g_resources.guessFilePath(file, "dat");

        const auto& fin = g_resources.openFile(file);
        fin->cache(true);

        m_datSignature = fin->getU32();
        m_contentRevision = static_cast<uint16_t>(m_datSignature);

        for (auto& thingType : m_thingTypes) {
            const int count = fin->getU16() + 1;
            thingType.clear();
            thingType.resize(count, m_nullThingType);
        }

        for (int category = -1; ++category < ThingLastCategory;) {
            const uint16_t firstId = category == ThingCategoryItem ? 100 : 1;

            for (uint16_t id = firstId - 1, s = m_thingTypes[category].size(); ++id < s;) {
                const auto& type = std::make_shared<ThingType>();
                type->unserialize(id, static_cast<ThingCategory>(category), fin);
                m_thingTypes[category][id] = type;
            }
        }

        m_datLoaded = true;
        g_lua.callGlobalField("g_things", "onLoadDat", file);
        return true;
    } catch (const stdext::exception& e) {
        g_logger.error("Failed to read dat '{}': {}'", file, e.what());
        return false;
    }
}

bool ThingTypeManager::loadOtml(std::string file)
{
    try {
        file = g_resources.guessFilePath(file, "otml");

        const auto& doc = OTMLDocument::parse(file);
        for (const auto& node : doc->children()) {
            ThingCategory category;
            if (node->tag() == "creatures")
                category = ThingCategoryCreature;
            else if (node->tag() == "items")
                category = ThingCategoryItem;
            else if (node->tag() == "effects")
                category = ThingCategoryEffect;
            else if (node->tag() == "missiles")
                category = ThingCategoryMissile;
            else {
                throw OTMLException(node, "not a valid thing category");
            }

            for (const auto& node2 : node->children()) {
                const auto id = stdext::safe_cast<uint16_t>(node2->tag());
                const auto& type = getThingType(id, category);
                if (!type)
                    throw OTMLException(node2, "thing not found");
                type->unserializeOtml(node2);
            }
        }
        return true;
    } catch (const std::exception& e) {
        g_logger.error("Failed to read dat otml '{}': {}'", file, e.what());
        return false;
    }
}

bool ThingTypeManager::loadAppearances(const std::string& file)
{
#ifdef FRAMEWORK_PROTOBUF
    m_catalogContent.reset();
    try {
        try {
            m_assetIdentifier = g_resources.readFileContents(g_resources.resolvePath(g_resources.guessFilePath(file + "assets", "json.sha256")));
        } catch (const std::exception& e) {
            m_assetIdentifier = "appearancesHash";
            g_logger.warning("Cannot load asset hash identifier from assets.json.sha256: {}", e.what());
        }

        if (!g_game.getFeature(Otc::GameLoadSprInsteadProtobuf)) {
            g_spriteAppearances.unload();
            int spritesCount = 0;
            std::string appearancesFile;
            const auto& document = getCatalogContent(file);
            for (const auto& obj : document) {
                const auto& type = obj["type"];
                if (type == "appearances") {
                    appearancesFile = obj["file"];
                } else if (type == "sprite") {
                    int lastSpriteId = obj["lastspriteid"].get<int>();
                    const auto& sheet = std::make_shared<SpriteSheet>(obj["firstspriteid"].get<int>(), lastSpriteId, static_cast<SpriteLayout>(obj["spritetype"].get<int>()), obj["file"].get<std::string>());
                    const int spritesPerSheet = sheet->getSpritesPerSheet();
                    const int maxSpriteId = sheet->firstId + spritesPerSheet - 1;
                    if (lastSpriteId > maxSpriteId) {
                        g_logger.debug("Sprite sheet '{}' lastspriteid {} exceeds capacity {}, clamping to {}", sheet->file, lastSpriteId, maxSpriteId, maxSpriteId);
                        lastSpriteId = maxSpriteId;
                        sheet->lastId = maxSpriteId;
                    }
                    g_spriteAppearances.addSpriteSheet(sheet);
                    spritesCount = std::max<int>(spritesCount, lastSpriteId);
                }
            }
            g_spriteAppearances.setSpritesCount(spritesCount + 1);
            g_spriteAppearances.setPath(file);
            // load appearances.dat
            std::stringstream fin;
            g_resources.readFileStream(g_resources.resolvePath(fmt::format("{}{}", file, appearancesFile)), fin);
            auto appearancesLib = appearances::Appearances();
            if (!appearancesLib.ParseFromIstream(&fin)) {
                throw stdext::exception("Couldn't parse appearances lib.");
            }
            for (int category = ThingCategoryItem; category < ThingLastCategory; ++category) {
                const google::protobuf::RepeatedPtrField<appearances::Appearance>* appearances = nullptr;
                switch (category) {
                    case ThingCategoryItem: appearances = &appearancesLib.object(); break;
                    case ThingCategoryCreature: appearances = &appearancesLib.outfit(); break;
                    case ThingCategoryEffect: appearances = &appearancesLib.effect(); break;
                    case ThingCategoryMissile: appearances = &appearancesLib.missile(); break;
                    default: return false;
                }
                // fix for custom asserts, where ids are not sorted.
                uint32_t lastAppearanceId = 0;
                for (const auto& appearance : *appearances) {
                    if (appearance.id() > lastAppearanceId)
                        lastAppearanceId = appearance.id();
                }
                auto& things = m_thingTypes[category];
                things.clear();
                things.resize(lastAppearanceId + 1, m_nullThingType);
                for (const auto& appearance : *appearances) {
                    const auto& type = std::make_shared<ThingType>();
                    const uint16_t id = appearance.id();
                    type->unserializeAppearance(id, static_cast<ThingCategory>(category), appearance);
                    m_thingTypes[category][id] = type;
                }
            }
            m_datLoaded = true;
            m_proficiencyThingsCacheDirty = true;
        } else {
            std::stringstream datFileStream;
            auto appearancesLib = appearances::Appearances();
            g_resources.readFileStream(g_resources.resolvePath(g_resources.guessFilePath(file, "dat")), datFileStream);
            if (!appearancesLib.ParseFromIstream(&datFileStream)) {
                throw stdext::exception("Couldn't parse appearances.dat.");
            }
            for (const auto& appearance : appearancesLib.object()) {
                const uint16_t id = appearance.id();
                if (auto* type = getRawThingType(id, ThingCategoryItem)) {
                    type->applyAppearanceFlags(appearance.flags());
                }
            }
        }
        return true;
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (Appearances): {}", file, e.what());
        return false;
    }
#else
    g_logger.error("Protobuf not supported in this build. Enable FRAMEWORK_PROTOBUF");
    return false;
#endif
}

#ifdef FRAMEWORK_PROTOBUF
namespace {
    using RaceBank = google::protobuf::RepeatedPtrField<staticdata::Creature>;

    void loadCreatureBank(RaceList& otcRaceList, const RaceBank& protobufRaceList, bool boss) {
        for (const auto& protobufRace : protobufRaceList) {
            // add race to vector
            RaceType otcRaceType = RaceType();
            otcRaceType.raceId = protobufRace.raceid();
            otcRaceType.name = protobufRace.name();
            otcRaceType.hasCategory = protobufRace.has_category();
            otcRaceType.category = protobufRace.category();
            otcRaceType.boss = boss;

            Outfit otcOutfit;
            const auto& protobufOutfit = protobufRace.outfit();
            if (protobufOutfit.lookitem() != 0) {
                otcOutfit.setAuxId(static_cast<uint16_t>(protobufOutfit.lookitem()));
            } else {
                otcOutfit.setId(static_cast<uint16_t>(protobufOutfit.looktype()));
                otcOutfit.setAddons(static_cast<uint8_t>(protobufOutfit.lookaddons()));
                if (protobufOutfit.has_colors()) {
                    const auto& pbColors = protobufOutfit.colors();
                    otcOutfit.setHead(static_cast<uint8_t>(pbColors.head()));
                    otcOutfit.setBody(static_cast<uint8_t>(pbColors.body()));
                    otcOutfit.setLegs(static_cast<uint8_t>(pbColors.legs()));
                    otcOutfit.setFeet(static_cast<uint8_t>(pbColors.feet()));
                }
            }

            otcRaceType.outfit = std::move(otcOutfit);
            otcRaceList.emplace_back(std::move(otcRaceType));
        }
    }
}

bool ThingTypeManager::loadStaticData(const std::string& file)
{
    try {
        std::string staticDataFile;

        const auto& document = getCatalogContent(file);
        for (const auto& obj : document) {
            const auto& type = obj["type"];
            if (type == "staticdata") {
                staticDataFile = obj["file"];
            }
        }

        // load staticdata.dat
        std::stringstream datFileStream;
        g_resources.readFileStream(g_resources.resolvePath(fmt::format("{}{}", file, staticDataFile)), datFileStream);
        auto staticDataLib = staticdata::Staticdata();
        if (!staticDataLib.ParseFromIstream(&datFileStream)) {
            throw stdext::exception("Couldn't parse staticdata lib.");
        }

        // if reload, start again
        m_monsterRaces.clear();

        const auto& raceBank = staticDataLib.monsters();
        const auto& bossBank = staticDataLib.bosses();
        m_monsterRaces.reserve(static_cast<size_t>(raceBank.size()) + bossBank.size());

        // load monsters and bosses
        // note: aside from compatibility with the QT client,
        // there is no need to have monsters and bosses
        // in separate data banks
        loadCreatureBank(m_monsterRaces, raceBank, false);
        loadCreatureBank(m_monsterRaces, bossBank, true);
        return true;
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (StaticData): {}", file, e.what());
        return false;
    }

    return false;
}
#else
bool ThingTypeManager::loadStaticData(const std::string& file)
{
    g_logger.error("Protobuf not supported in this build. Enable FRAMEWORK_PROTOBUF");
    return false;
}
#endif

bool ThingTypeManager::resolveProficienciesFile(const std::string& file)
{
    m_proficienciesFile.clear();

    if (!g_game.getFeature(Otc::GameProficiency)) {
        return false;
    }

    try {
        std::string proficienciesFile;

        const auto& document = getCatalogContent(file);
        for (const auto& obj : document) {
            const auto& type = obj["type"];
            if (type == "proficiencies") {
                proficienciesFile = obj["file"];
            }
        }

        if (proficienciesFile.empty()) {
            return false;
        }

        const auto proficienciesPath = fmt::format("{}{}", file, proficienciesFile);
        if (!g_resources.fileExists(proficienciesPath)) {
            return false;
        }

        m_proficienciesFile = proficienciesPath;
        return true;
    } catch (const std::exception&) {
        m_proficienciesFile.clear();
        return false;
    }
}

const ThingTypeList& ThingTypeManager::getThingTypes(const ThingCategory category)
{
    if (category < ThingLastCategory)
        return m_thingTypes[category];

    throw Exception("invalid thing type category {}", category);
}

const ThingTypePtr& ThingTypeManager::getThingType(const uint16_t id, const ThingCategory category)
{
    if (category >= ThingLastCategory || id >= m_thingTypes[category].size()) {
        g_logger.error("Invalid thing type client id {} in category {}", id, static_cast<uint8_t>(category));
        return m_nullThingType;
    }
    return m_thingTypes[category][id];
}

ThingType* ThingTypeManager::getRawThingType(uint16_t id, ThingCategory category) {
    if (category >= ThingLastCategory || id >= m_thingTypes[category].size()) {
        g_logger.error("Invalid thing type client id {} in category {}", id, static_cast<uint8_t>(category));
        return nullptr;
    }
    return m_thingTypes[category][id].get();
}

ThingTypeList ThingTypeManager::findThingTypeByAttr(const ThingAttr attr, const ThingCategory category)
{
    ThingTypeList ret;
    for (const auto& type : m_thingTypes[category])
        if (type->hasAttr(attr))
            ret.emplace_back(type);
    return ret;
}

void ThingTypeManager::buildProficiencyCache()
{
    m_proficiencyThingsCache.clear();
    for (const auto& type : m_thingTypes[ThingCategoryItem]) {
        if (type && type->getProficiencyId() > 0) {
            m_proficiencyThingsCache.emplace_back(type);
        }
    }
    m_proficiencyThingsCacheDirty = false;
}

const ThingTypeList& ThingTypeManager::getProficiencyThings()
{
    if (m_proficiencyThingsCacheDirty) {
        buildProficiencyCache();
    }
    return m_proficiencyThingsCache;
}

std::string ThingTypeManager::getCyclopediaItemName(uint16_t id)
{
    const auto& type = getThingType(id, ThingCategoryItem);
    if (type->isNull()) return "";
    if (!type->getMarketData().name.empty()) return type->getMarketData().name;
    return type->getName();
}

std::string ThingTypeManager::getProficienciesFile()
{
    if (!g_game.getFeature(Otc::GameProficiency)) {
        return "";
    }

    if (!m_proficienciesFile.empty() && g_resources.fileExists(m_proficienciesFile)) {
        return m_proficienciesFile;
    }

    return "";
}

const RaceType& ThingTypeManager::getRaceData(uint32_t raceId)
{
    for (const auto& raceData : m_monsterRaces) {
        if (raceData.raceId == raceId) {
            return raceData;
        }
    }

    return emptyRaceType;
}

RaceList ThingTypeManager::getRacesByName(const std::string& searchString)
{
    RaceList result;
    for (const auto& race : m_monsterRaces) {
        if (race.name.find(searchString) != std::string::npos) {
            result.push_back(race);
        }
    }
    return result;
}

#ifdef FRAMEWORK_EDITOR
void ThingTypeManager::parseItemType(uint16_t serverId, pugi::xml_node node)
{
    bool s;
    int d;

    if (g_game.getClientVersion() < 960) {
        s = serverId > 20000 && serverId < 20100;
        d = 20000;
    } else {
        s = serverId > 30000 && serverId < 30100;
        d = 30000;
    }

    ItemTypePtr itemType;
    if (s) {
        serverId -= d;
        itemType = std::make_shared<ItemType>();
        itemType->setServerId(serverId);
        addItemType(itemType);
    } else
        itemType = getItemType(serverId);

    itemType->setName(node.attribute("name").as_string());
    for (auto attrib : node.children()) {
        std::string key = attrib.attribute("key").as_string();
        if (key.empty())
            continue;

        stdext::tolower(key);
        if (key == "description")
            itemType->setDesc(attrib.attribute("value").as_string());
        else if (key == "weapontype")
            itemType->setCategory(ItemCategoryWeapon);
        else if (key == "ammotype")
            itemType->setCategory(ItemCategoryAmmunition);
        else if (key == "armor")
            itemType->setCategory(ItemCategoryArmor);
        else if (key == "charges")
            itemType->setCategory(ItemCategoryCharges);
        else if (key == "type") {
            std::string value = attrib.attribute("value").as_string();
            stdext::tolower(value);

            if (value == "key")
                itemType->setCategory(ItemCategoryKey);
            else if (value == "magicfield")
                itemType->setCategory(ItemCategoryMagicField);
            else if (value == "teleport")
                itemType->setCategory(ItemCategoryTeleport);
            else if (value == "door")
                itemType->setCategory(ItemCategoryDoor);
        }
    }
}

void ThingTypeManager::addItemType(const ItemTypePtr& itemType)
{
    const uint16_t id = itemType->getServerId();
    if (unlikely(id >= m_itemTypes.size()))
        m_itemTypes.resize(id + 1, m_nullItemType);
    m_itemTypes[id] = itemType;
}

const ItemTypePtr& ThingTypeManager::findItemTypeByClientId(uint16_t id)
{
    if (id == 0 || id >= m_reverseItemTypes.size())
        return m_nullItemType;

    if (m_reverseItemTypes[id])
        return m_reverseItemTypes[id];
    return m_nullItemType;
}

const ItemTypePtr& ThingTypeManager::findItemTypeByName(const std::string& name)
{
    for (const ItemTypePtr& it : m_itemTypes)
        if (it->getName() == name)
            return it;
    return m_nullItemType;
}

ItemTypeList ThingTypeManager::findItemTypesByName(const std::string& name)
{
    ItemTypeList ret;
    for (const ItemTypePtr& it : m_itemTypes)
        if (it->getName() == name)
            ret.emplace_back(it);
    return ret;
}

ItemTypeList ThingTypeManager::findItemTypesByString(const std::string& name)
{
    ItemTypeList ret;
    for (const ItemTypePtr& it : m_itemTypes)
        if (it->getName().find(name) != std::string::npos)
            ret.emplace_back(it);
    return ret;
}

const ItemTypePtr& ThingTypeManager::getItemType(uint16_t id)
{
    if (id >= m_itemTypes.size() || m_itemTypes[id] == m_nullItemType) {
        g_logger.error("Invalid thing type, server id: {}", id);
        return m_nullItemType;
    }
    return m_itemTypes[id];
}

ItemTypeList ThingTypeManager::findItemTypeByCategory(ItemCategory category)
{
    ItemTypeList ret;
    for (const ItemTypePtr& type : m_itemTypes)
        if (type->getCategory() == category)
            ret.emplace_back(type);
    return ret;
}

void ThingTypeManager::saveDat(const std::string& fileName)
{
    if (!m_datLoaded)
        throw Exception("failed to save, dat is not loaded");

    try {
        const auto& fin = g_resources.createFile(fileName);
        if (!fin)
            throw Exception("failed to open file '{}' for write", fileName);

        fin->cache();

        fin->addU32(m_datSignature);

        for (const auto& m_thingType : m_thingTypes)
            fin->addU16(m_thingType.size() - 1);

        for (int category = 0; category < ThingLastCategory; ++category) {
            uint16_t firstId = 1;
            if (category == ThingCategoryItem)
                firstId = 100;

            for (uint16_t id = firstId; id < m_thingTypes[category].size(); ++id)
                m_thingTypes[category][id]->serialize(fin);
        }

        fin->flush();
        fin->close();
    } catch (const std::exception& e) {
        g_logger.error("Failed to save '{}': {}", fileName, e.what());
    }
}

void ThingTypeManager::loadOtb(const std::string& file)
{
    try {
        const auto& fin = g_resources.openFile(file);
        fin->cache();

        uint32_t signature = fin->getU32();
        if (signature != 0)
            throw Exception("invalid otb file");

        const auto& root = fin->getBinaryTree();
        root->skip(1); // otb first byte is always 0

        signature = root->getU32();
        if (signature != 0)
            throw Exception("invalid otb file");

        if (const uint8_t rootAttr = root->getU8(); rootAttr == 0x01) { // OTB_ROOT_ATTR_VERSION
            if (const uint16_t size = root->getU16(); size != 4 + 4 + 4 + 128)
                throw Exception("invalid otb root attr version size");

            m_otbMajorVersion = root->getU32();
            m_otbMinorVersion = root->getU32();
            root->skip(4); // buildNumber
            root->skip(128); // description
        }

        const BinaryTreeVec children = root->getChildren();
        m_reverseItemTypes.clear();
        m_itemTypes.resize(children.size() + 1, m_nullItemType);
        m_reverseItemTypes.resize(children.size() + 1, m_nullItemType);

        for (const auto& node : children) {
            const auto& itemType = std::make_shared<ItemType>();
            itemType->unserialize(node);
            addItemType(itemType);

            const uint16_t clientId = itemType->getClientId();
            if (unlikely(clientId >= m_reverseItemTypes.size()))
                m_reverseItemTypes.resize(clientId + 1);
            m_reverseItemTypes[clientId] = itemType;
        }

        m_otbLoaded = true;
        g_lua.callGlobalField("g_things", "onLoadOtb", file);
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (OTB file): {}", file, e.what());
    }
}

void ThingTypeManager::loadXml(const std::string& file)
{
    try {
        if (!isOtbLoaded())
            throw Exception("OTB must be loaded before XML");

        pugi::xml_document doc;
        pugi::xml_parse_result result = doc.load_file(file.c_str());
        if (!result)
            throw Exception("failed to parse '{}': '{}'", file, result.description());

        pugi::xml_node root = doc.child("items");
        if (root.empty())
            throw Exception("invalid root tag name");

        for (pugi::xml_node element = root.first_child(); element; element = element.next_sibling()) {
            if (element.name() != std::string("item"))
                continue;

            const auto id = element.attribute("id").as_uint();
            if (id != 0) {
                std::vector<std::string> s_ids = stdext::split(element.attribute("id").as_string(), ";");
                for (const std::string& s : s_ids) {
                    std::vector<int32_t> ids = stdext::split<int32_t>(s, "-");
                    if (ids.size() > 1) {
                        int32_t i = ids[0];
                        while (i <= ids[1])
                            parseItemType(++i, element);
                    } else
                        parseItemType(atoi(s.c_str()), element);
                }
            } else {
                std::vector<int32_t> begin = stdext::split<int32_t>(element.attribute("fromid").as_string(), ";");
                std::vector<int32_t> end = stdext::split<int32_t>(element.attribute("toid").as_string(), ";");
                if (begin[0] && begin.size() == end.size()) {
                    const size_t size = begin.size();
                    for (size_t i = 0; i < size; ++i)
                        while (begin[i] <= end[i])
                            parseItemType(++begin[i], element);
                }
            }
        }

        m_xmlLoaded = true;
        g_logger.debug("Items.xml read successfully.");
    } catch (const std::exception& e) {
        g_logger.error("Failed to load '{}' (XML file): {}", file, e.what());
    }
}

#endif

/* vim: set ts=4 sw=4 et: */
