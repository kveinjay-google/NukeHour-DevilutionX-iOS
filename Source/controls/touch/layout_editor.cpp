#ifndef USE_SDL1

#include "controls/touch/layout_editor.h"

#include <algorithm>
#include <cmath>

#ifdef USE_SDL3
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_mouse.h>
#else
#include <SDL.h>
#endif

#include "DiabloUI/diabloui.h"
#include "controls/input.h"
#include "controls/touch/gamepad.h"
#include "controls/touch/renderers.h"
#include "diablo.h"
#include "engine/circle.hpp"
#include "engine/displacement.hpp"
#include "engine/point.hpp"
#include "engine/rectangle.hpp"
#include "engine/render/primitive_render.hpp"
#include "engine/render/text_render.hpp"
#include "engine/surface.hpp"
#include "options.h"
#include "utils/display.h"
#include "utils/language.h"
#include "utils/sdl_compat.h"
#include "utils/ui_fwd.h"
#ifdef __IPHONEOS__
#include "platform/ios/ios_platform.h"
#endif

namespace devilution {
namespace {

enum class LayoutGroup : uint8_t {
	None,
	Left,
	Right,
	Menu,
	Reset,
	Done,
};

bool editorOpen = false;
bool restorePauseOnClose = false;
LayoutGroup dragGroup = LayoutGroup::None;
Point dragOrigin;
Point dragStartPad;
Point dragStartActions;
Point dragStartMenu;
SDL_FingerID dragFinger = 0;

Rectangle ResetButtonRect()
{
	return { { 16, 10 }, { 150, 44 } };
}

Rectangle DoneButtonRect()
{
	return { { 178, 10 }, { 150, 44 } };
}

Point ScaleFinger(float x, float y)
{
	return {
		static_cast<int>(std::round(x * gnScreenWidth)),
		static_cast<int>(std::round(y * gnScreenHeight))
	};
}

Point EventToScreen(const SDL_Event &event)
{
	if (event.type == SDL_EVENT_FINGER_DOWN || event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_MOTION)
		return ScaleFinger(event.tfinger.x, event.tfinger.y);
	if (event.type == SDL_EVENT_MOUSE_MOTION)
		return { SDLC_EventMotionIntX(event), SDLC_EventMotionIntY(event) };
	return { SDLC_EventButtonIntX(event), SDLC_EventButtonIntY(event) };
}

SDL_FingerID EventFinger(const SDL_Event &event)
{
	if (event.type == SDL_EVENT_FINGER_DOWN || event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_MOTION) {
#ifdef USE_SDL3
		return event.tfinger.fingerID;
#else
		return event.tfinger.fingerId;
#endif
	}
	return 0;
}

bool HitCircle(const Circle &circle, Point p)
{
	const int r = std::max(circle.radius + 12, 36);
	const Displacement d = p - circle.position;
	return d.deltaX * d.deltaX + d.deltaY * d.deltaY <= r * r;
}

LayoutGroup HitTest(Point p)
{
	if (ResetButtonRect().contains(p))
		return LayoutGroup::Reset;
	if (DoneButtonRect().contains(p))
		return LayoutGroup::Done;

	VirtualGamepad &pad = VirtualGamepadState;
	if (HitCircle(pad.directionPad.area, p)
	    || HitCircle(pad.standButton.area, p)
	    || HitCircle(pad.healthButton.area, p)
	    || HitCircle(pad.manaButton.area, p))
		return LayoutGroup::Left;
	if (HitCircle(pad.primaryActionButton.area, p)
	    || HitCircle(pad.secondaryActionButton.area, p)
	    || HitCircle(pad.spellActionButton.area, p)
	    || HitCircle(pad.cancelButton.area, p))
		return LayoutGroup::Right;
	if (pad.menuPanel.area.contains(p)
	    || pad.menuPanel.labelsButton.contains(p)
	    || pad.menuPanel.charButton.contains(p)
	    || pad.menuPanel.questsButton.contains(p)
	    || pad.menuPanel.inventoryButton.contains(p)
	    || pad.menuPanel.mapButton.contains(p))
		return LayoutGroup::Menu;
	return LayoutGroup::None;
}

void ShiftCircle(Circle &circle, Displacement d)
{
	circle.position += d;
}

void ShiftRect(Rectangle &rect, Displacement d)
{
	rect.position += d;
}

void MoveLeftCluster(Displacement d)
{
	VirtualGamepad &pad = VirtualGamepadState;
	ShiftCircle(pad.directionPad.area, d);
	pad.directionPad.position = pad.directionPad.area.position;
	ShiftCircle(pad.standButton.area, d);
	ShiftCircle(pad.healthButton.area, d);
	ShiftCircle(pad.manaButton.area, d);
}

void MoveRightCluster(Displacement d)
{
	VirtualGamepad &pad = VirtualGamepadState;
	ShiftCircle(pad.primaryActionButton.area, d);
	ShiftCircle(pad.secondaryActionButton.area, d);
	ShiftCircle(pad.spellActionButton.area, d);
	ShiftCircle(pad.cancelButton.area, d);
}

void MoveMenuCluster(Displacement d)
{
	VirtualGamepad &pad = VirtualGamepadState;
	ShiftRect(pad.menuPanel.area, d);
	ShiftRect(pad.menuPanel.labelsButton.area, d);
	ShiftRect(pad.menuPanel.charButton.area, d);
	ShiftRect(pad.menuPanel.questsButton.area, d);
	ShiftRect(pad.menuPanel.inventoryButton.area, d);
	ShiftRect(pad.menuPanel.mapButton.area, d);
}

Point ClampPoint(Point p, int margin)
{
	p.x = std::clamp(p.x, margin, static_cast<int>(gnScreenWidth) - margin);
	p.y = std::clamp(p.y, margin, static_cast<int>(gnScreenHeight) - margin);
	return p;
}

void SaveLayoutFromCurrentPositions()
{
	ControllerOptions &controller = GetOptions().Controller;
	controller.virtualGamepadCustomLayout = true;
	const float w = static_cast<float>(std::max(1, static_cast<int>(gnScreenWidth)));
	const float h = static_cast<float>(std::max(1, static_cast<int>(gnScreenHeight)));
	controller.virtualGamepadPadX = VirtualGamepadState.directionPad.area.position.x / w;
	controller.virtualGamepadPadY = VirtualGamepadState.directionPad.area.position.y / h;
	const Point actions {
		(VirtualGamepadState.primaryActionButton.area.position.x
		    + VirtualGamepadState.spellActionButton.area.position.x)
		    / 2,
		(VirtualGamepadState.secondaryActionButton.area.position.y
		    + VirtualGamepadState.cancelButton.area.position.y)
		    / 2
	};
	controller.virtualGamepadActionsX = actions.x / w;
	controller.virtualGamepadActionsY = actions.y / h;
	controller.virtualGamepadMenuX = VirtualGamepadState.menuPanel.area.position.x / w;
	controller.virtualGamepadMenuY = VirtualGamepadState.menuPanel.area.position.y / h;
}

void DrawEditorButton(const Surface &out, const Rectangle &rect, std::string_view label, bool highlight)
{
	DrawHalfTransparentRectTo(out, rect.position.x, rect.position.y, rect.size.width, rect.size.height);
	DrawString(out, label, rect, { .flags = UiFlags::AlignCenter | UiFlags::VerticalCenter | UiFlags::FontSize24 | (highlight ? UiFlags::ColorUiGold : UiFlags::ColorUiSilver) });
}

bool HandlePress(Point p, SDL_FingerID finger)
{
	const LayoutGroup hit = HitTest(p);
	if (hit == LayoutGroup::None)
		return false;
	if (hit == LayoutGroup::Reset) {
		ResetVirtualGamepadLayout();
		return true;
	}
	if (hit == LayoutGroup::Done) {
		SaveLayoutFromCurrentPositions();
		CloseVirtualGamepadLayoutEditor();
		return true;
	}

	dragGroup = hit;
	dragFinger = finger;
	dragOrigin = p;
	dragStartPad = VirtualGamepadState.directionPad.area.position;
	dragStartActions = {
		(VirtualGamepadState.primaryActionButton.area.position.x
		    + VirtualGamepadState.spellActionButton.area.position.x)
		    / 2,
		(VirtualGamepadState.secondaryActionButton.area.position.y
		    + VirtualGamepadState.cancelButton.area.position.y)
		    / 2
	};
	dragStartMenu = VirtualGamepadState.menuPanel.area.position;
	return true;
}

bool HandleMove(Point p, SDL_FingerID finger)
{
	if (dragGroup == LayoutGroup::None || (finger != 0 && finger != dragFinger))
		return dragGroup != LayoutGroup::None;
	const Displacement delta = p - dragOrigin;
	if (dragGroup == LayoutGroup::Left) {
		const Point target = ClampPoint(dragStartPad + delta, VirtualGamepadState.directionPad.area.radius + 8);
		MoveLeftCluster(target - VirtualGamepadState.directionPad.area.position);
	} else if (dragGroup == LayoutGroup::Right) {
		const Point target = ClampPoint(dragStartActions + delta, VirtualGamepadState.primaryActionButton.area.radius + 8);
		const Point current {
			(VirtualGamepadState.primaryActionButton.area.position.x
			    + VirtualGamepadState.spellActionButton.area.position.x)
			    / 2,
			(VirtualGamepadState.secondaryActionButton.area.position.y
			    + VirtualGamepadState.cancelButton.area.position.y)
			    / 2
		};
		MoveRightCluster(target - current);
	} else if (dragGroup == LayoutGroup::Menu) {
		const Point target = ClampPoint(dragStartMenu + delta, 8);
		MoveMenuCluster(target - VirtualGamepadState.menuPanel.area.position);
	}
	return true;
}

bool HandleRelease(SDL_FingerID finger)
{
	if (dragGroup == LayoutGroup::None || (finger != 0 && finger != dragFinger))
		return false;
	dragGroup = LayoutGroup::None;
	dragFinger = 0;
	return true;
}

} // namespace

bool IsVirtualGamepadLayoutEditorOpen()
{
	return editorOpen;
}

void StartVirtualGamepadLayoutEditor()
{
	editorOpen = true;
	dragGroup = LayoutGroup::None;
	InitializeVirtualGamepad();
	ActivateVirtualGamepad();
}

void StartVirtualGamepadLayoutEditorFromGame()
{
	restorePauseOnClose = true;
	PauseMode = 2;
	StartVirtualGamepadLayoutEditor();
}

void CloseVirtualGamepadLayoutEditor()
{
	editorOpen = false;
	dragGroup = LayoutGroup::None;
	if (restorePauseOnClose) {
		PauseMode = 0;
		restorePauseOnClose = false;
	}
	SaveOptions();
}

void ResetVirtualGamepadLayout()
{
	GetOptions().Controller.virtualGamepadCustomLayout = false;
	InitializeVirtualGamepad();
}

void ApplyVirtualGamepadLayout()
{
	const ControllerOptions &controller = GetOptions().Controller;
	if (!controller.virtualGamepadCustomLayout)
		return;
	if (gnScreenWidth == 0 || gnScreenHeight == 0)
		return;

	const Point padTarget {
		static_cast<int>(std::lround(controller.virtualGamepadPadX * gnScreenWidth)),
		static_cast<int>(std::lround(controller.virtualGamepadPadY * gnScreenHeight))
	};
	MoveLeftCluster(ClampPoint(padTarget, VirtualGamepadState.directionPad.area.radius + 8) - VirtualGamepadState.directionPad.area.position);

	const Point actionsTarget {
		static_cast<int>(std::lround(controller.virtualGamepadActionsX * gnScreenWidth)),
		static_cast<int>(std::lround(controller.virtualGamepadActionsY * gnScreenHeight))
	};
	const Point actionsCurrent {
		(VirtualGamepadState.primaryActionButton.area.position.x
		    + VirtualGamepadState.spellActionButton.area.position.x)
		    / 2,
		(VirtualGamepadState.secondaryActionButton.area.position.y
		    + VirtualGamepadState.cancelButton.area.position.y)
		    / 2
	};
	MoveRightCluster(ClampPoint(actionsTarget, VirtualGamepadState.primaryActionButton.area.radius + 8) - actionsCurrent);

	const Point menuTarget {
		static_cast<int>(std::lround(controller.virtualGamepadMenuX * gnScreenWidth)),
		static_cast<int>(std::lround(controller.virtualGamepadMenuY * gnScreenHeight))
	};
	MoveMenuCluster(ClampPoint(menuTarget, 8) - VirtualGamepadState.menuPanel.area.position);
}

bool HandleVirtualGamepadLayoutEditorEvent(const SDL_Event &event)
{
	if (!editorOpen)
		return false;

	switch (event.type) {
	case SDL_EVENT_FINGER_DOWN:
		return HandlePress(EventToScreen(event), EventFinger(event));
	case SDL_EVENT_FINGER_MOTION:
		return HandleMove(EventToScreen(event), EventFinger(event));
	case SDL_EVENT_FINGER_UP:
		return HandleRelease(EventFinger(event));
	case SDL_EVENT_MOUSE_BUTTON_DOWN:
		if (event.button.button != SDL_BUTTON_LEFT || event.button.which == SDL_TOUCH_MOUSEID)
			return false;
		return HandlePress(EventToScreen(event), 0);
	case SDL_EVENT_MOUSE_MOTION:
		if (event.motion.which == SDL_TOUCH_MOUSEID)
			return false;
		return HandleMove(EventToScreen(event), 0);
	case SDL_EVENT_MOUSE_BUTTON_UP:
		if (event.button.button != SDL_BUTTON_LEFT || event.button.which == SDL_TOUCH_MOUSEID)
			return false;
		return HandleRelease(0);
	default:
		return false;
	}
}

void RenderVirtualGamepadLayoutEditor(const Surface &out)
{
	if (!editorOpen)
		return;

	DrawEditorButton(out, ResetButtonRect(), _("Reset"), dragGroup == LayoutGroup::Reset);
	DrawEditorButton(out, DoneButtonRect(), _("Done"), dragGroup == LayoutGroup::Done);
	DrawString(out, _("Drag the stick, buttons, or menu to reposition them."),
	    { { 16, 58 }, { gnScreenWidth - 32, 40 } },
	    { .flags = UiFlags::FontSize12 | UiFlags::ColorUiSilver | UiFlags::AlignCenter });
}

void RunVirtualGamepadLayoutEditor()
{
	InitVirtualGamepadGFX();
#ifndef USE_SDL1
	if (renderer != nullptr)
		InitVirtualGamepadTextures(*renderer);
#endif
	StartVirtualGamepadLayoutEditor();

	while (editorOpen) {
		SDL_Event event;
		while (PollEvent(&event)) {
			if (!SDLC_ConvertEventToRenderCoordinates(renderer, &event)) {
				SDL_ClearError();
			}
#ifdef __IPHONEOS__
			if (IOSIsAppLifecycleEvent(event)) {
				IOSHandleSdlEvent(event);
				continue;
			}
#endif
			if (event.type == SDL_EVENT_QUIT) {
				CloseVirtualGamepadLayoutEditor();
				break;
			}
			HandleVirtualGamepadLayoutEditorEvent(event);
		}

		UiClearScreen();
		RenderVirtualGamepadLayoutEditor(Surface(DiabloUiSurface()));
		UiFadeIn();
	}
}

} // namespace devilution

#endif
