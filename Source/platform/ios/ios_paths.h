#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/** Documents directory. Persistent and Files/Finder visible. Used for imported MPQs. */
char *IOSGetDocumentsPath();

/** Application Support/diasurgical/devilution/. Persistent. Used for saves. */
char *IOSGetPrefPath();

/** Same location as PrefPath. Used for diablo.ini. */
char *IOSGetConfigPath();

#ifdef __cplusplus
}
#endif
