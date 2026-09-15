#pragma once

#ifndef USE_SDL1

#ifdef USE_SDL3
#include <SDL3/SDL_events.h>
#else
#include <SDL.h>
#endif

#include "engine/surface.hpp"

namespace devilution {

bool IsVirtualGamepadLayoutEditorOpen();
void StartVirtualGamepadLayoutEditor();
void StartVirtualGamepadLayoutEditorFromGame();
void CloseVirtualGamepadLayoutEditor();
void ResetVirtualGamepadLayout();
void ApplyVirtualGamepadLayout();
bool HandleVirtualGamepadLayoutEditorEvent(const SDL_Event &event);
void RenderVirtualGamepadLayoutEditor(const Surface &out);
void RunVirtualGamepadLayoutEditor();

} // namespace devilution

#endif
