<?php
// CONFIG
$files_dir = "C:/UniServerZ/www/files"; // Directory where the files are located
$files_url = "http://localhost/files"; // Url where the client will download the files
$files_and_dirs = array("init.lua", "data", "modules", "mods");
$checksum_file = "checksums.txt";
$cache_key = hash('sha256', realpath($files_dir) ?: $files_dir);
$cache_file = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'otclient-' . $cache_key . '-' . $checksum_file;
$checksum_update_interval = 60; // seconds
$binaries = array(
    "WIN32-WGL" => "otclient_x64.exe",
    "WIN32-EGL" => "otclient_x64.exe",
    "WIN32-WGL-GCC" => "otclient_x64.exe",
    "WIN32-EGL-GCC" => "otclient_x64.exe",
    "X11-GLX" => "otclient_linux",
    "X11-EGL" => "otclient_linux",
    "ANDROID-EGL" => "", // we can't update android binary
    "ANDROID64-EGL" => "" // we can't update android binary
);
// CONFIG END

/**
 * Send a JSON error response and stop execution.
 *
 * @param string $error Human-readable error message.
 * @return never
 */
function sendError($error)
{
    echo (json_encode(array("error" => $error)));
    die();
}

/**
 * Read the checksum cache only when it is still within the freshness window.
 *
 * Stale or unreadable caches return null so the caller rebuilds them instead
 * of serving outdated checksums to clients.
 *
 * @param string $cache_file Absolute path to the JSON cache file.
 * @param int    $interval   Maximum accepted cache age in seconds.
 * @return array|null Decoded cache map, or null when missing, stale or invalid.
 */
function readFreshCache($cache_file, $interval)
{
    if (!file_exists($cache_file)) {
        return null;
    }
    if (filemtime($cache_file) + $interval <= time()) {
        return null;
    }
    $cache = json_decode(file_get_contents($cache_file), true);
    return is_array($cache) && $cache ? $cache : null;
}

$data = json_decode(file_get_contents("php://input"));
if (!$data || !is_object($data)) {
    sendError("Invalid input data");
}

$version = $data->version ?? 0; // APP_VERSION from init.lua
$build = $data->build ?? ""; // 2.4, 2.4.1, 2.5, etc
$os = $data->os ?? "unknown"; // android, windows, mac, linux, unknown
$platform = $data->platform ?? ""; // WIN32-WGL, X11-GLX, ANDROID-EGL, etc
$args = $data->args ?? []; // custom args when calling Updater.check()
if (!is_string($platform)) {
    sendError("Invalid platform");
}
$binary = $binaries[$platform] ?? "";

$dir = realpath($files_dir);
if (!$dir || !is_dir($dir)) {
    sendError("Server configuration error: files directory not found");
}

$cache = readFreshCache($cache_file, $checksum_update_interval);
if (!$cache) { // update cache
    // File locking to prevent race conditions
    $lock_file = $cache_file . ".lock";
    $lock = fopen($lock_file, "w");
    if (!$lock) {
        sendError("Server error: could not create lock file");
    }
    
    try {
        if (!flock($lock, LOCK_EX | LOCK_NB)) {
            // Another process is updating cache, wait and use existing cache
            usleep(100000); // 100ms
            $cache = readFreshCache($cache_file, $checksum_update_interval);
            if (!$cache) {
                // Wait for the lock if cache still not available
                if (!flock($lock, LOCK_EX)) {
                    sendError("Server error: could not acquire cache lock");
                }
                // Re-check cache after acquiring lock
                $cache = readFreshCache($cache_file, $checksum_update_interval);
            }
        }

        if (!$cache) {
            $rii = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
            $cache = array();
            foreach ($rii as $file) {
                if (!$file->isFile())
                    continue;
                // Strip only the leading files directory so nested paths that
                // repeat the same string are preserved.
                $path = substr($file->getPathname(), strlen($dir));
                $path = str_replace(DIRECTORY_SEPARATOR, '/', $path);
                $checksum = hash_file("crc32b", $file->getPathname());

                if ($checksum !== false && $checksum !== "") {
                    $parsed_checksum = ltrim($checksum, '0');
                    if ($parsed_checksum === '') {
                        $parsed_checksum = '0';
                    }
                    $cache[$path] = $parsed_checksum;
                }
            }
            file_put_contents($cache_file . ".tmp", json_encode($cache));
            rename($cache_file . ".tmp", $cache_file);
        }
    } finally {
        // Release lock and close handle - always executes
        flock($lock, LOCK_UN);
        fclose($lock);
    }
}
$ret = array("url" => $files_url, "files" => array(), "keepFiles" => false);
$binary_file = null;
$binary_checksum = null;

foreach ($cache as $file => $checksum) {
    $base = trim(explode("/", ltrim($file, "/"))[0]);
    if (in_array($base, $files_and_dirs)) {
        $ret["files"][$file] = $checksum;
    }

    // A bare executable name is only valid at the update root. Selecting by
    // basename anywhere in the tree can mistake an addon/module for the client.
    if (!empty($binary)) {
        $relative = ltrim($file, "/");
        $configured_binary = str_replace("\\", "/", trim($binary));
        $relative = str_replace("\\", "/", $relative);
        $matches = strpos($configured_binary, "/") !== false
            ? $relative === ltrim($configured_binary, "/")
            : $relative === $configured_binary;
        if ($matches) {
            $binary_file = $file;
            $binary_checksum = $checksum;
        }
    }
}

if ($binary_file !== null) {
    $ret["binary"] = array("file" => $binary_file, "checksum" => $binary_checksum);
}

$body = json_encode($ret, JSON_PRETTY_PRINT);
header("Content-Type: application/json");
header("Content-Length: " . strlen($body));
header("X-Content-Type-Options: nosniff");
header("Cache-Control: no-store");
echo ($body);
