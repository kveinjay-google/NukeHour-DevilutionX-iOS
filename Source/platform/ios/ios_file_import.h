#pragma once

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	/** Stay until DIABDAT.MPQ or spawn.mpq is present, or the user quits. */
	IOSImportGatePlayable = 0,
	/** Stay until hellfire.mpq is present, or the user quits. */
	IOSImportGateHellfire = 1,
	/** Settings: user can import extras and dismiss with Back. */
	IOSImportGateOptional = 2,
} IOSImportGate;

/**
 * Full-screen two-panel import UI (landscape). Returns false if the user quit
 * while a required archive was still missing.
 */
bool IOSPresentImportScreen(IOSImportGate gate);

/** Blocking OK alert. */
void IOSShowNotice(const char *title, const char *message, const char *okButton);

/**
 * Presents the iOS document picker so the user can import MPQ archives
 * into the app Documents directory. Returns true if at least one recognized
 * archive was imported.
 */
bool IOSPromptAndImportGameData(void);

#ifdef __cplusplus
}
#endif
