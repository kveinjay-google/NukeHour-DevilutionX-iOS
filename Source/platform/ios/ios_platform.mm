#include "ios_platform.h"

#include "diablo.h"
#include "engine/demomode.h"
#include "utils/display.h"
#include "utils/log.hpp"
#include "utils/ui_fwd.h"

#ifdef USE_SDL3
#include <SDL3/SDL.h>
#else
#include <SDL.h>
#endif

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#ifndef USE_SDL1

namespace devilution {
namespace {

id AudioInterruptionObserver = nil;
id AudioRouteObserver = nil;

void SetAudioSessionActive(bool active)
{
	NSError *error = nil;
	AVAudioSessionSetActiveOptions options = active ? 0 : AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation;
	if (![[AVAudioSession sharedInstance] setActive:active withOptions:options error:&error] && error != nil) {
		LogVerbose("iOS AVAudioSession setActive({}) failed: {}", active, error.localizedDescription.UTF8String);
	}
}

void ConfigureAudioSession()
{
	NSError *error = nil;
	AVAudioSession *session = [AVAudioSession sharedInstance];
	if (![session setCategory:AVAudioSessionCategoryAmbient
	              withOptions:AVAudioSessionCategoryOptionMixWithOthers
	                    error:&error]) {
		LogError("iOS AVAudioSession category failed: {}", error.localizedDescription.UTF8String);
		return;
	}
	SetAudioSessionActive(true);

	if (AudioInterruptionObserver == nil) {
		AudioInterruptionObserver = [[NSNotificationCenter defaultCenter]
		    addObserverForName:AVAudioSessionInterruptionNotification
		                object:session
		                 queue:[NSOperationQueue mainQueue]
		            usingBlock:^(NSNotification *notification) {
			            const NSInteger type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
			            if (type == AVAudioSessionInterruptionTypeEnded) {
				            ConfigureAudioSession();
			            }
		            }];
	}
	if (AudioRouteObserver == nil) {
		AudioRouteObserver = [[NSNotificationCenter defaultCenter]
		    addObserverForName:AVAudioSessionRouteChangeNotification
		                object:session
		                 queue:[NSOperationQueue mainQueue]
		            usingBlock:^(NSNotification *) {
			            SetAudioSessionActive(true);
		            }];
	}
}

} // namespace

void IOSPlatformOnSdlInit()
{
	SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
	SDL_SetHint(SDL_HINT_RENDER_DRIVER, "metal");
	SDL_SetHint(SDL_HINT_AUDIO_CATEGORY, "ambient");
#if TARGET_OS_SIMULATOR
	// Host CoreAudio can hang SDL's AudioQueue thread in this Simulator environment.
	SDL_SetHint(SDL_HINT_AUDIODRIVER, "dummy");
#endif
#ifdef SDL_HINT_IOS_HIDE_HOME_INDICATOR
	SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "1");
#endif
	// Do not activate AVAudioSession before SDL opens the audio device.
	// SDL's CoreAudio backend waits on a semaphore that never fires if the
	// session is already active on the main thread (iOS Simulator deadlock).
}

void IOSAudioSessionDidOpen()
{
	ConfigureAudioSession();
}

void IOSLogRendererAndDisplay()
{
	const char *driver = SDL_GetCurrentVideoDriver();
	Log("iOS video driver: {}", driver != nullptr ? driver : "(null)");

	if (renderer != nullptr) {
		SDL_RendererInfo info;
		if (SDL_GetRendererInfo(renderer, &info) == 0) {
			Log("iOS renderer: {} flags=0x{:x} max_texture={}x{}",
			    info.name != nullptr ? info.name : "(null)",
			    info.flags,
			    info.max_texture_width,
			    info.max_texture_height);
		}
		int outputW = 0;
		int outputH = 0;
		SDL_GetRendererOutputSize(renderer, &outputW, &outputH);
		Log("iOS drawable: {}x{}", outputW, outputH);
	}

	if (ghMainWnd != nullptr) {
		int w = 0;
		int h = 0;
		SDL_GetWindowSize(ghMainWnd, &w, &h);
		Log("iOS window points: {}x{}", w, h);
	}

	const IOSSafeArea inset = GetIOSSafeAreaLogical();
	Log("iOS safe area (logical px): L={} T={} R={} B={}", inset.left, inset.top, inset.right, inset.bottom);
}

void IOSHandleSdlEvent(const SDL_Event &event)
{
	switch (event.type) {
	case SDL_APP_WILLENTERBACKGROUND:
	case SDL_APP_DIDENTERBACKGROUND:
		LogVerbose("iOS entering background");
		SetAudioSessionActive(false);
		if (!demo::IsRunning()) {
			diablo_focus_pause();
		}
		break;
	case SDL_APP_WILLENTERFOREGROUND:
	case SDL_APP_DIDENTERFOREGROUND:
		LogVerbose("iOS entered foreground");
		ConfigureAudioSession();
		if (!demo::IsRunning()) {
			diablo_focus_unpause();
		}
		if (renderer != nullptr && ghMainWnd != nullptr) {
			ReinitializeRenderer();
		}
		break;
	case SDL_APP_LOWMEMORY:
		Log("iOS memory warning: dropping no persistent state");
		break;
	case SDL_APP_TERMINATING:
		LogVerbose("iOS terminating");
		break;
	default:
		break;
	}
}

bool IOSIsAppLifecycleEvent(const SDL_Event &event)
{
	switch (event.type) {
	case SDL_APP_WILLENTERBACKGROUND:
	case SDL_APP_DIDENTERBACKGROUND:
	case SDL_APP_WILLENTERFOREGROUND:
	case SDL_APP_DIDENTERFOREGROUND:
	case SDL_APP_LOWMEMORY:
	case SDL_APP_TERMINATING:
		return true;
	default:
		return false;
	}
}

IOSSafeArea GetIOSSafeAreaLogical()
{
	IOSSafeArea result;
	UIWindow *window = nil;
	if (@available(iOS 13.0, *)) {
		for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
			for (UIWindow *candidate in scene.windows) {
				if (candidate.isKeyWindow || window == nil) {
					window = candidate;
				}
			}
		}
	}
	if (window == nil) {
		for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
			if (![scene isKindOfClass:[UIWindowScene class]]) {
				continue;
			}
			UIWindowScene *windowScene = (UIWindowScene *)scene;
			if (windowScene.windows.count > 0) {
				window = windowScene.windows.firstObject;
				break;
			}
		}
	}
	if (window == nil) {
		return result;
	}

	const CGRect bounds = window.bounds;
	if (bounds.size.width <= 0 || bounds.size.height <= 0 || gnScreenWidth == 0 || gnScreenHeight == 0) {
		return result;
	}

	const UIEdgeInsets insets = window.safeAreaInsets;
	result.left = static_cast<int>(insets.left / bounds.size.width * gnScreenWidth + 0.5);
	result.right = static_cast<int>(insets.right / bounds.size.width * gnScreenWidth + 0.5);
	result.top = static_cast<int>(insets.top / bounds.size.height * gnScreenHeight + 0.5);
	result.bottom = static_cast<int>(insets.bottom / bounds.size.height * gnScreenHeight + 0.5);
	return result;
}

} // namespace devilution

#endif
