#pragma once

#ifdef __cplusplus

#ifdef USE_SDL3
#include <SDL3/SDL_events.h>
#else
#include <SDL.h>
#endif

namespace devilution {

struct IOSSafeArea {
	int left = 0;
	int top = 0;
	int right = 0;
	int bottom = 0;
};

void IOSPlatformOnSdlInit();
void IOSAudioSessionDidOpen();
void IOSLogRendererAndDisplay();
void IOSHandleSdlEvent(const SDL_Event &event);
[[nodiscard]] bool IOSIsAppLifecycleEvent(const SDL_Event &event);
[[nodiscard]] IOSSafeArea GetIOSSafeAreaLogical();

} // namespace devilution

#endif
