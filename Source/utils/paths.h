#pragma once

#include <string>

namespace devilution {

namespace paths {

const std::string &BasePath();
const std::string &PrefPath();
const std::string &ConfigPath();
const std::string &AssetsPath();
#ifdef __IPHONEOS__
const std::string &IOSDocumentsPath();
#endif

void SetBasePath(const std::string &path);
void SetPrefPath(const std::string &path);
void SetConfigPath(const std::string &path);
void SetAssetsPath(const std::string &path);

} // namespace paths

} // namespace devilution
