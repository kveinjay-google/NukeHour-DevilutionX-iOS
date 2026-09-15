#include <algorithm>
#include <cmath>
#include <string>

#ifdef USE_SDL3
#include <SDL3/SDL_timer.h>
#include <SDL3/SDL_video.h>
#else
#include <SDL.h>
#endif

#include "control/control.hpp"
#include "controls/control_mode.hpp"
#include "controls/touch/event_handlers.h"
#include "controls/touch/gamepad.h"
#include "controls/touch/layout_editor.h"
#include "options.h"
#include "quests.h"
#include "engine/render/primitive_render.hpp"
#include "engine/render/text_render.hpp"
#include "utils/display.h"
#include "utils/ui_fwd.h"
#ifdef __IPHONEOS__
#include "platform/ios/ios_platform.h"
#endif

namespace devilution {

VirtualGamepad VirtualGamepadState;

namespace {

int roundToInt(float value)
{
	return static_cast<int>(round(value));
}

std::string hintText;
Point hintAnchor { 0, 0 };
uint32_t hintExpireAt = 0;

} // namespace

void InitializeVirtualGamepad()
{
	const float sqrt2 = sqrtf(2.0F);

	const int screenPixels = std::min(gnScreenWidth, gnScreenHeight);
	int inputMargin = screenPixels / 10;
	int menuButtonWidth = screenPixels / 10;
	int directionPadSize = screenPixels / 4;
	int padButtonSize = roundToInt(1.1F * screenPixels / 10);
	int padButtonSpacing = inputMargin / 3;

#ifdef USE_SDL3
	const float dpi = SDL_GetWindowDisplayScale(ghMainWnd);
#else
	float dpi = 0.0F;
	float hdpi;
	float vdpi;
	const int displayIndex = SDL_GetWindowDisplayIndex(ghMainWnd);
	if (SDL_GetDisplayDPI(displayIndex, nullptr, &hdpi, &vdpi) == 0) {
		int clientWidth;
		int clientHeight;
		if (renderer != nullptr)
			SDL_GetRendererOutputSize(renderer, &clientWidth, &clientHeight);
		else
			SDL_GetWindowSize(ghMainWnd, &clientWidth, &clientHeight);

		hdpi *= static_cast<float>(gnScreenWidth) / clientWidth;
		vdpi *= static_cast<float>(gnScreenHeight) / clientHeight;

		dpi = std::min(hdpi, vdpi);
	}
#endif

	if (dpi != 0.0F) {
		inputMargin = roundToInt(0.25F * dpi);
		menuButtonWidth = roundToInt(0.2F * dpi);
		directionPadSize = roundToInt(dpi);
		padButtonSize = roundToInt(0.3F * dpi);
		padButtonSpacing = roundToInt(0.1F * dpi);
	}
#ifdef __IPHONEOS__
	// Leave more of the original 640x128 HUD visible; the virtual stick
	// and action cluster sit above that bar instead of on top of it.
	directionPadSize = roundToInt(0.82F * directionPadSize);
	padButtonSize = roundToInt(0.88F * padButtonSize);
	padButtonSpacing = std::max(8, roundToInt(0.9F * padButtonSpacing));
	inputMargin = std::max(12, roundToInt(0.8F * inputMargin));
#endif

	const int menuPanelTopMargin = 8;
	const int menuPanelButtonSpacing = 4;
	const Size menuPanelButtonSize = { 64, 62 };
	constexpr int MenuPanelArtWidth = 467;
	constexpr int MenuPanelArtHeight = 162;
	const int menuColumnWidth = menuPanelButtonSpacing + menuPanelButtonSize.width;
	const int menuHitHeight = menuPanelButtonSize.height + 40;
	const int rightMarginMenuButton5 = menuColumnWidth;
	const int rightMarginMenuButton4 = rightMarginMenuButton5 + menuColumnWidth;
	const int rightMarginMenuButton3 = rightMarginMenuButton4 + menuColumnWidth;
	const int rightMarginMenuButton2 = rightMarginMenuButton3 + menuColumnWidth;
	const int rightMarginMenuButton1 = rightMarginMenuButton2 + menuColumnWidth;

	const int padButtonAreaWidth = roundToInt(sqrt2 * (padButtonSize + padButtonSpacing));

	const int padButtonRight = gnScreenWidth - inputMargin - (padButtonSize / 2);
	const int padButtonLeft = padButtonRight - padButtonAreaWidth;
	const int padButtonBottom = gnScreenHeight - inputMargin - (padButtonSize / 2);
	const int padButtonTop = padButtonBottom - padButtonAreaWidth;

	const auto placeMenuButton = [&](Rectangle &area, int rightMargin) {
		area.position.x = gnScreenWidth - rightMargin * menuButtonWidth / menuPanelButtonSize.width;
		area.position.y = menuPanelTopMargin * menuButtonWidth / menuPanelButtonSize.width;
		area.size.width = menuColumnWidth * menuButtonWidth / menuPanelButtonSize.width;
		area.size.height = menuHitHeight * menuButtonWidth / menuPanelButtonSize.width;
	};

	placeMenuButton(VirtualGamepadState.menuPanel.labelsButton.area, rightMarginMenuButton1);
	placeMenuButton(VirtualGamepadState.menuPanel.charButton.area, rightMarginMenuButton2);
	placeMenuButton(VirtualGamepadState.menuPanel.questsButton.area, rightMarginMenuButton3);
	placeMenuButton(VirtualGamepadState.menuPanel.inventoryButton.area, rightMarginMenuButton4);
	placeMenuButton(VirtualGamepadState.menuPanel.mapButton.area, rightMarginMenuButton5);

	Rectangle &labelsButtonArea = VirtualGamepadState.menuPanel.labelsButton.area;
	Rectangle &charButtonArea = VirtualGamepadState.menuPanel.charButton.area;
	Rectangle &questsButtonArea = VirtualGamepadState.menuPanel.questsButton.area;
	Rectangle &inventoryButtonArea = VirtualGamepadState.menuPanel.inventoryButton.area;
	Rectangle &mapButtonArea = VirtualGamepadState.menuPanel.mapButton.area;

	Rectangle &menuPanelArea = VirtualGamepadState.menuPanel.area;
	menuPanelArea.position.x = gnScreenWidth - MenuPanelArtWidth * menuButtonWidth / menuPanelButtonSize.width;
	menuPanelArea.position.y = 0;
	menuPanelArea.size.width = MenuPanelArtWidth * menuButtonWidth / menuPanelButtonSize.width;
	menuPanelArea.size.height = MenuPanelArtHeight * menuButtonWidth / menuPanelButtonSize.width;

	VirtualDirectionPad &directionPad = VirtualGamepadState.directionPad;
	Circle &directionPadArea = directionPad.area;
	directionPadArea.position.x = inputMargin + directionPadSize / 2;
	directionPadArea.position.y = gnScreenHeight - inputMargin - directionPadSize / 2;
	directionPadArea.radius = directionPadSize / 2;
	directionPad.position = directionPadArea.position;

	const int standButtonDiagonalOffset = directionPadArea.radius + (padButtonSpacing / 2) + (padButtonSize / 2);
	const int standButtonOffset = roundToInt(standButtonDiagonalOffset / sqrt2);
	Circle &standButtonArea = VirtualGamepadState.standButton.area;
	standButtonArea.position.x = directionPadArea.position.x - standButtonOffset;
	standButtonArea.position.y = directionPadArea.position.y + standButtonOffset;
	standButtonArea.radius = padButtonSize / 2;
	VirtualGamepadState.standButton.hitSlop = std::max(8, padButtonSize / 5);

	Circle &primaryActionButtonArea = VirtualGamepadState.primaryActionButton.area;
	primaryActionButtonArea.position.x = padButtonRight;
	primaryActionButtonArea.position.y = (padButtonTop + padButtonBottom) / 2;
	primaryActionButtonArea.radius = padButtonSize / 2;

	Circle &secondaryActionButtonArea = VirtualGamepadState.secondaryActionButton.area;
	secondaryActionButtonArea.position.x = (padButtonLeft + padButtonRight) / 2;
	secondaryActionButtonArea.position.y = padButtonTop;
	secondaryActionButtonArea.radius = padButtonSize / 2;

	Circle &spellActionButtonArea = VirtualGamepadState.spellActionButton.area;
	spellActionButtonArea.position.x = padButtonLeft;
	spellActionButtonArea.position.y = (padButtonTop + padButtonBottom) / 2;
	spellActionButtonArea.radius = padButtonSize / 2;

	Circle &cancelButtonArea = VirtualGamepadState.cancelButton.area;
	cancelButtonArea.position.x = (padButtonLeft + padButtonRight) / 2;
	cancelButtonArea.position.y = padButtonBottom;
	cancelButtonArea.radius = padButtonSize / 2;

	VirtualPadButton &healthButton = VirtualGamepadState.healthButton;
	Circle &healthButtonArea = healthButton.area;
	healthButtonArea.position.x = directionPad.area.position.x - (padButtonSize + padButtonSpacing) / 2;
	healthButtonArea.position.y = directionPad.area.position.y - (directionPadSize + padButtonSize + padButtonSpacing) / 2;
	healthButtonArea.radius = padButtonSize / 2;
	healthButton.isUsable = []() { return !CharFlag && !QuestLogIsOpen; };

	VirtualPadButton &manaButton = VirtualGamepadState.manaButton;
	Circle &manaButtonArea = manaButton.area;
	manaButtonArea.position.x = directionPad.area.position.x + (padButtonSize + padButtonSpacing) / 2;
	manaButtonArea.position.y = directionPad.area.position.y - (directionPadSize + padButtonSize + padButtonSpacing) / 2;
	manaButtonArea.radius = padButtonSize / 2;
	manaButton.isUsable = []() { return !CharFlag && !QuestLogIsOpen; };

#ifdef __IPHONEOS__
	const IOSSafeArea inset = GetIOSSafeAreaLogical();
	const auto shiftCircle = [](Circle &circle, int dx, int dy) {
		circle.position.x += dx;
		circle.position.y += dy;
	};
	const auto shiftRect = [](Rectangle &rect, int dx, int dy) {
		rect.position.x += dx;
		rect.position.y += dy;
	};

	const int menuNudgeX = inset.right + std::max(16, menuButtonWidth / 2);
	const int menuNudgeY = inset.top + std::max(10, menuButtonWidth / 4);
	shiftRect(labelsButtonArea, -menuNudgeX, menuNudgeY);
	shiftRect(charButtonArea, -menuNudgeX, menuNudgeY);
	shiftRect(questsButtonArea, -menuNudgeX, menuNudgeY);
	shiftRect(inventoryButtonArea, -menuNudgeX, menuNudgeY);
	shiftRect(mapButtonArea, -menuNudgeX, menuNudgeY);
	shiftRect(menuPanelArea, -menuNudgeX, menuNudgeY);

	shiftCircle(directionPadArea, inset.left, -inset.bottom);
	directionPad.position = directionPadArea.position;
	shiftCircle(standButtonArea, inset.left, -inset.bottom);
	shiftCircle(healthButtonArea, inset.left, -inset.bottom);
	shiftCircle(manaButtonArea, inset.left, -inset.bottom);

	shiftCircle(primaryActionButtonArea, -inset.right, -inset.bottom);
	shiftCircle(secondaryActionButtonArea, -inset.right, -inset.bottom);
	shiftCircle(spellActionButtonArea, -inset.right, -inset.bottom);
	shiftCircle(cancelButtonArea, -inset.right, -inset.bottom);
	directionPad.position = directionPadArea.position;
#endif
#ifndef USE_SDL1
	ApplyVirtualGamepadLayout();
#endif
#ifdef __IPHONEOS__
	{
		const auto shiftCircle = [](Circle &circle, int dy) {
			circle.position.y += dy;
		};
		const int hudTop = GetMainPanel().position.y;
		const int gap = std::max(6, inputMargin / 5);
		const auto circleBottom = [](const Circle &circle) {
			return circle.position.y + circle.radius;
		};
		const int lowest = std::max({
		    circleBottom(VirtualGamepadState.directionPad.area),
		    circleBottom(VirtualGamepadState.standButton.area),
		    circleBottom(VirtualGamepadState.healthButton.area),
		    circleBottom(VirtualGamepadState.manaButton.area),
		    circleBottom(VirtualGamepadState.primaryActionButton.area),
		    circleBottom(VirtualGamepadState.secondaryActionButton.area),
		    circleBottom(VirtualGamepadState.spellActionButton.area),
		    circleBottom(VirtualGamepadState.cancelButton.area),
		});
		const int overlap = lowest - (hudTop - gap);
		if (overlap > 0) {
			shiftCircle(VirtualGamepadState.directionPad.area, -overlap);
			shiftCircle(VirtualGamepadState.standButton.area, -overlap);
			shiftCircle(VirtualGamepadState.healthButton.area, -overlap);
			shiftCircle(VirtualGamepadState.manaButton.area, -overlap);
			shiftCircle(VirtualGamepadState.primaryActionButton.area, -overlap);
			shiftCircle(VirtualGamepadState.secondaryActionButton.area, -overlap);
			shiftCircle(VirtualGamepadState.spellActionButton.area, -overlap);
			shiftCircle(VirtualGamepadState.cancelButton.area, -overlap);
			VirtualGamepadState.directionPad.position = VirtualGamepadState.directionPad.area.position;
		}
	}
#endif
}

void ActivateVirtualGamepad()
{
	VirtualGamepadState.isActive = true;
}

void DeactivateVirtualGamepad()
{
	VirtualGamepadState.Deactivate();
	DeactivateTouchEventHandlers();
	hintText.clear();
	hintExpireAt = 0;
}

void ShowVirtualGamepadHint(std::string_view text, Point anchor)
{
	hintText.assign(text.data(), text.size());
	hintAnchor = anchor;
	hintExpireAt = SDL_GetTicks() + 2500;
}

void RenderVirtualGamepadHint(const Surface &out)
{
	if (hintText.empty())
		return;
	if (IsVirtualGamepadLayoutEditorOpen() || SDL_GetTicks() >= hintExpireAt) {
		hintText.clear();
		return;
	}

	constexpr GameFontTables Font = GameFont24;
	const int textWidth = GetLineWidth(hintText, Font);
	const int textHeight = GetLineHeight(hintText, Font);
	const int padX = 14;
	const int padY = 6;
	const int width = textWidth + padX * 2;
	const int height = textHeight + padY * 2;
	int x = hintAnchor.x - width / 2;
	int y = hintAnchor.y;
	x = std::clamp(x, 8, std::max(8, gnScreenWidth - width - 8));
	y = std::clamp(y, 8, std::max(8, gnScreenHeight - height - 8));

	DrawHalfTransparentRectTo(out, x, y, width, height);
	DrawString(out, hintText, { { x, y }, { width, height } },
	    { .flags = UiFlags::AlignCenter | UiFlags::VerticalCenter | UiFlags::FontSize24 | UiFlags::ColorUiGold | UiFlags::Outlined });
}

#ifndef USE_SDL1
bool ShouldRenderVirtualGamepad()
{
	switch (*GetOptions().Controller.virtualGamepad) {
	case VirtualGamepadVisibility::Always:
		return true;
	case VirtualGamepadVisibility::Hidden:
		return IsVirtualGamepadLayoutEditorOpen();
	case VirtualGamepadVisibility::Auto:
	default:
		return ControlMode == ControlTypes::VirtualGamepad || IsVirtualGamepadLayoutEditorOpen();
	}
}
#endif

void VirtualGamepad::Deactivate()
{
	isActive = false;

	menuPanel.Deactivate();
	directionPad.Deactivate();
	standButton.Deactivate();

	primaryActionButton.Deactivate();
	secondaryActionButton.Deactivate();
	spellActionButton.Deactivate();
	cancelButton.Deactivate();

	healthButton.Deactivate();
	manaButton.Deactivate();
}

void VirtualMenuPanel::Deactivate()
{
	labelsButton.Deactivate();
	charButton.Deactivate();
	questsButton.Deactivate();
	inventoryButton.Deactivate();
	mapButton.Deactivate();
}

bool VirtualDirectionPad::canActivate(Point point) const
{
	const Displacement diff = point - area.position;
	const int radius = std::max(area.radius + 24, area.radius * 3 / 2);
	return diff.deltaX * diff.deltaX + diff.deltaY * diff.deltaY <= radius * radius;
}

void VirtualDirectionPad::BeginTouch(Point touchCoordinates)
{
	dragOrigin = touchCoordinates;
	position = area.position;
	isUpPressed = false;
	isDownPressed = false;
	isLeftPressed = false;
	isRightPressed = false;
}

void VirtualDirectionPad::UpdatePosition(Point touchCoordinates)
{
	const Displacement drag = touchCoordinates - dragOrigin;
	const float dist = sqrtf(static_cast<float>((drag.deltaX * drag.deltaX) + (drag.deltaY * drag.deltaY)));
	const int maxRadius = std::max(1, area.radius);
	const int deadzone = std::max(10, maxRadius * 12 / 100);

	if (dist > static_cast<float>(maxRadius) && dist > 0.0F) {
		position.x = area.position.x + roundToInt(static_cast<float>(drag.deltaX) * static_cast<float>(maxRadius) / dist);
		position.y = area.position.y + roundToInt(static_cast<float>(drag.deltaY) * static_cast<float>(maxRadius) / dist);
	} else {
		position.x = area.position.x + drag.deltaX;
		position.y = area.position.y + drag.deltaY;
	}

	isUpPressed = false;
	isDownPressed = false;
	isLeftPressed = false;
	isRightPressed = false;
	if (dist < static_cast<float>(deadzone))
		return;

	const float absX = fabsf(static_cast<float>(drag.deltaX));
	const float absY = fabsf(static_cast<float>(drag.deltaY));
	constexpr float DiagonalCutoff = 0.41421356F; // tan(22.5°)
	if (absX == 0.0F) {
		if (drag.deltaY < 0)
			isUpPressed = true;
		else
			isDownPressed = true;
		return;
	}

	const float ratio = absY / absX;
	if (ratio <= DiagonalCutoff) {
		if (drag.deltaX > 0)
			isRightPressed = true;
		else
			isLeftPressed = true;
		return;
	}
	if (ratio >= 1.0F / DiagonalCutoff) {
		if (drag.deltaY < 0)
			isUpPressed = true;
		else
			isDownPressed = true;
		return;
	}

	if (drag.deltaX > 0)
		isRightPressed = true;
	else
		isLeftPressed = true;
	if (drag.deltaY < 0)
		isUpPressed = true;
	else
		isDownPressed = true;
}

void VirtualDirectionPad::Deactivate()
{
	dragOrigin = area.position;
	position = area.position;
	isUpPressed = false;
	isDownPressed = false;
	isLeftPressed = false;
	isRightPressed = false;
}

void VirtualButton::Deactivate()
{
	isHeld = false;
	didStateChange = false;
}

} // namespace devilution
