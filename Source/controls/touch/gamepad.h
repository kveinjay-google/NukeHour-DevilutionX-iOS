#pragma once

#include <algorithm>
#include <functional>
#include <string_view>

#include "controls/controller_buttons.h"
#include "engine/circle.hpp"
#include "engine/point.hpp"
#include "engine/rectangle.hpp"
#include "engine/surface.hpp"

namespace devilution {

struct VirtualDirectionPad {
	Circle area;
	Point position;
	Point dragOrigin;
	bool isUpPressed { false };
	bool isDownPressed { false };
	bool isLeftPressed { false };
	bool isRightPressed { false };

	VirtualDirectionPad()
	    : area({ { 0, 0 }, 0 })
	    , position({ 0, 0 })
	    , dragOrigin({ 0, 0 })
	{
	}

	[[nodiscard]] bool canActivate(Point point) const;
	void BeginTouch(Point touchCoordinates);
	void UpdatePosition(Point touchCoordinates);
	void Deactivate();
};

struct VirtualButton {
	bool isHeld { false };
	bool didStateChange { false };
	std::function<bool()> isUsable;

	VirtualButton()
	    : isUsable([]() { return true; })
	{
	}

	virtual bool contains(Point point) = 0;
	void Deactivate();
};

struct VirtualMenuButton : VirtualButton {
	Rectangle area;

	VirtualMenuButton()
	    : area({ { 0, 0 }, { 0, 0 } })
	{
	}

	bool contains(Point point) override
	{
		const int padX = std::max(6, area.size.width / 4);
		const int padY = std::max(10, area.size.height / 3);
		return point.x >= area.position.x - padX
		    && point.x < area.position.x + area.size.width + padX
		    && point.y >= area.position.y - padY
		    && point.y < area.position.y + area.size.height + padY;
	}
};

struct VirtualPadButton : VirtualButton {
	Circle area;
	int hitSlop { 0 };

	VirtualPadButton()
	    : area({ { 0, 0 }, 0 })
	{
	}

	bool contains(Point point) override
	{
		const Displacement diff = point - area.position;
		const int radius = area.radius + hitSlop;
		return diff.deltaX * diff.deltaX + diff.deltaY * diff.deltaY <= radius * radius;
	}
};

struct VirtualMenuPanel {
	VirtualMenuButton labelsButton;
	VirtualMenuButton charButton;
	VirtualMenuButton questsButton;
	VirtualMenuButton inventoryButton;
	VirtualMenuButton mapButton;
	Rectangle area;

	VirtualMenuPanel()
	    : area({ { 0, 0 }, { 0, 0 } })
	{
	}

	void Deactivate();
};

struct VirtualGamepad {
	VirtualMenuPanel menuPanel;
	VirtualDirectionPad directionPad;
	VirtualPadButton standButton;

	VirtualPadButton primaryActionButton;
	VirtualPadButton secondaryActionButton;
	VirtualPadButton spellActionButton;
	VirtualPadButton cancelButton;

	VirtualPadButton healthButton;
	VirtualPadButton manaButton;

	bool isActive { false };

	VirtualGamepad() = default;

	void Deactivate();
};

void InitializeVirtualGamepad();
void ActivateVirtualGamepad();
void DeactivateVirtualGamepad();
void ShowVirtualGamepadHint(std::string_view text, Point anchor);
void RenderVirtualGamepadHint(const Surface &out);
#ifndef USE_SDL1
bool ShouldRenderVirtualGamepad();
#endif

extern VirtualGamepad VirtualGamepadState;

} // namespace devilution
