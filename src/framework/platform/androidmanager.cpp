/*
 * Copyright (c) 2010-2014 OTClient <https://github.com/edubart/otclient>
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
#ifdef ANDROID

#include "androidmanager.h"
#include <framework/global.h>
#include <framework/core/unzipper.h>
#include <framework/core/resourcemanager.h>
#include <framework/sound/soundmanager.h>
#include <physfs.h>
#include <filesystem>
#include <android/log.h>
#define ALOG(...) __android_log_print(ANDROID_LOG_INFO, "OTClientMobile", __VA_ARGS__)

AndroidManager g_androidManager;

AndroidManager::~AndroidManager() {
    JNIEnv* env = getJNIEnv();
    env->DeleteGlobalRef(m_androidManagerJObject);
}

void AndroidManager::setAndroidApp(android_app* app) {
    m_app = app;
}

void AndroidManager::setAndroidManager(JNIEnv* env, jobject androidManager) {
    JNIEnv* jniEnv = getJNIEnv();
    jclass androidManagerJClass = jniEnv->GetObjectClass(androidManager);
    m_androidManagerJObject = jniEnv->NewGlobalRef(androidManager);
    m_midShowSoftKeyboard = jniEnv->GetMethodID(androidManagerJClass, "showSoftKeyboard", "()V");
    m_midHideSoftKeyboard = jniEnv->GetMethodID(androidManagerJClass, "hideSoftKeyboard", "()V");
    m_midGetDisplayDensity = jniEnv->GetMethodID(androidManagerJClass, "getDisplayDensity", "()F");
    m_midShowInputPreview = jniEnv->GetMethodID(androidManagerJClass, "showInputPreview", "(Ljava/lang/String;)V");
    m_midUpdateInputPreview = jniEnv->GetMethodID(androidManagerJClass, "updateInputPreview", "(Ljava/lang/String;)V");
    m_midHideInputPreview = jniEnv->GetMethodID(androidManagerJClass, "hideInputPreview", "()V");
    jniEnv->DeleteLocalRef(androidManagerJClass);
}

void AndroidManager::showKeyboardSoft() {
    JNIEnv* env = getJNIEnv();
    env->CallVoidMethod(m_androidManagerJObject, m_midShowSoftKeyboard);
}

void AndroidManager::hideKeyboard() {
    JNIEnv* env = getJNIEnv();
    env->CallVoidMethod(m_androidManagerJObject, m_midHideSoftKeyboard);
}

namespace {
    jstring latin1ToJString(JNIEnv* env, const std::string& text) {
        std::u16string utf16;
        utf16.reserve(text.size());
        for (unsigned char c : text) {
            utf16.push_back(static_cast<char16_t>(c));
        }
        return env->NewString(reinterpret_cast<const jchar*>(utf16.data()), static_cast<jsize>(utf16.size()));
    }
}

void AndroidManager::showInputPreview(const std::string& text) {
    JNIEnv* env = getJNIEnv();
    jstring jText = latin1ToJString(env, text);
    env->CallVoidMethod(m_androidManagerJObject, m_midShowInputPreview, jText);
    env->DeleteLocalRef(jText);
}

void AndroidManager::updateInputPreview(const std::string& text) {
    JNIEnv* env = getJNIEnv();
    jstring jText = latin1ToJString(env, text);
    env->CallVoidMethod(m_androidManagerJObject, m_midUpdateInputPreview, jText);
    env->DeleteLocalRef(jText);
}

void AndroidManager::hideInputPreview() {
    JNIEnv* env = getJNIEnv();
    env->CallVoidMethod(m_androidManagerJObject, m_midHideInputPreview);
}

void AndroidManager::unZipAssetData() {
    std::string destZip = getAppBaseDir() + "/data.zip";

    // If data.zip already exists on disk, skip copying from assets
    if (std::filesystem::exists(destZip)) {
        return;
    }

    // Use AASSET_MODE_STREAMING to avoid loading the entire large file into
    // contiguous RAM (AASSET_MODE_BUFFER's AAsset_getBuffer can return NULL
    // for files >~50MB, causing a crash on fwrite).
    AAsset* dataAsset = AAssetManager_open(
            m_app->activity->assetManager,
            "data.zip",
            AASSET_MODE_STREAMING);

    if (!dataAsset) {
        g_logger.fatal("Failed to open data.zip from Android assets");
        return;
    }

    FILE* out = fopen(destZip.c_str(), "wb");
    if (!out) {
        AAsset_close(dataAsset);
        g_logger.fatal("Failed to write data.zip to internal storage");
        return;
    }

    char buf[65536];
    int bytesRead;
    while ((bytesRead = AAsset_read(dataAsset, buf, sizeof(buf))) > 0) {
        fwrite(buf, 1, static_cast<size_t>(bytesRead), out);
    }

    fclose(out);
    AAsset_close(dataAsset);
}

static void extractPhysFSDir(const std::string& virtualDir, const std::string& destRoot) {
    char** files = PHYSFS_enumerateFiles(virtualDir.c_str());
    if (!files) return;

    for (char** i = files; *i; i++) {
        std::string name = *i;
        std::string virtualPath = virtualDir.empty() ? name : virtualDir + "/" + name;
        std::string realPath = destRoot + virtualPath;

        PHYSFS_Stat stat;
        if (!PHYSFS_stat(virtualPath.c_str(), &stat)) continue;

        if (stat.filetype == PHYSFS_FILETYPE_DIRECTORY) {
            std::filesystem::create_directories(realPath);
            extractPhysFSDir(virtualPath, destRoot);
        } else if (stat.filetype == PHYSFS_FILETYPE_REGULAR) {
            std::filesystem::create_directories(std::filesystem::path(realPath).parent_path());
            PHYSFS_File* src = PHYSFS_openRead(virtualPath.c_str());
            if (!src) continue;
            FILE* dst = fopen(realPath.c_str(), "wb");
            if (dst) {
                char buf[8192];
                PHYSFS_sint64 n;
                while ((n = PHYSFS_readBytes(src, buf, sizeof(buf))) > 0)
                    fwrite(buf, 1, static_cast<size_t>(n), dst);
                fclose(dst);
            }
            PHYSFS_close(src);
        }
    }
    PHYSFS_freeList(files);
}

void AndroidManager::extractZipToFilesystem() {
    std::string destZip = getAppBaseDir() + "/data.zip";
    std::string destDir = getAppBaseDir() + "/";

    ALOG("extractZipToFilesystem: destZip=%s destDir=%s", destZip.c_str(), destDir.c_str());

    if (std::filesystem::exists(destDir + "init.lua")) {
        ALOG("extractZipToFilesystem: init.lua already exists, skipping extraction");
        return;
    }

    bool zipExists = std::filesystem::exists(destZip);
    ALOG("extractZipToFilesystem: data.zip exists=%d", (int)zipExists);

    if (!PHYSFS_mount(destZip.c_str(), nullptr, 0)) {
        ALOG("extractZipToFilesystem: PHYSFS_mount failed: %s", PHYSFS_getErrorByCode(PHYSFS_getLastErrorCode()));
        g_logger.fatal("Failed to mount data.zip for extraction");
        return;
    }

    ALOG("extractZipToFilesystem: mounted zip, starting extraction to %s", destDir.c_str());
    extractPhysFSDir("", destDir);
    ALOG("extractZipToFilesystem: extraction complete");

    PHYSFS_unmount(destZip.c_str());
}

std::string AndroidManager::getAppBaseDir() {
    return { m_app->activity->internalDataPath };
}

std::string AndroidManager::getStringFromJString(jstring text) {
    JNIEnv* env = getJNIEnv();

    const jchar* chars = env->GetStringChars(text, nullptr);
    const jsize length = env->GetStringLength(text);

    std::string result;
    result.reserve(length);

    for (jsize i = 0; i < length; ++i) {
        const jchar codePoint = chars[i];
        if (codePoint <= 0xFF) {
            result.push_back(static_cast<char>(codePoint));
        } else {
            // fallback for characters outside ISO-8859-1 range
            result.push_back('?');
        }
    }

    env->ReleaseStringChars(text, chars);

    return result;
}

float AndroidManager::getScreenDensity() {
    JNIEnv* jni = getJNIEnv();

    return jni->CallFloatMethod(m_androidManagerJObject, m_midGetDisplayDensity);
}

void AndroidManager::attachToAppMainThread() {
    getJNIEnv();
}

JNIEnv* AndroidManager::getJNIEnv() {
    JNIEnv *env;

    if (m_app->activity->vm->AttachCurrentThread(&env, nullptr) < 0) {
        g_logger.fatal("failed to attach current thread");
        return nullptr;
    }

    return env;
}

/*
 * Java JNI functions
*/
extern "C" {

void Java_com_otclient_AndroidManager_nativeInit(JNIEnv* env, jobject androidManager) {
    g_androidManager.setAndroidManager(env, androidManager);
}

void Java_com_otclient_AndroidManager_nativeSetAudioEnabled(JNIEnv*, jobject, jboolean enabled) {
    g_sounds.setAudioEnabled(enabled);
}

}

#endif
