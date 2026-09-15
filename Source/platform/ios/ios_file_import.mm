#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include "ios_file_import.h"
#include "ios_paths.h"

#include <algorithm>
#include <cctype>
#include <string>

#include <SDL.h>

#include "config.h"

namespace {

constexpr const char *KnownArchiveNames[] = {
    "diabdat.mpq",
    "DIABDAT.MPQ",
    "spawn.mpq",
    "hellfire.mpq",
    "hfmonk.mpq",
    "hfmusic.mpq",
    "hfvoice.mpq",
    "fonts.mpq",
    "devilutionx.mpq",
};

std::string LowerCopy(std::string value)
{
	std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
		return static_cast<char>(std::tolower(c));
	});
	return value;
}

NSString *NSStringFromUtf8(const char *text)
{
	if (text == nullptr || text[0] == '\0') {
		return @"";
	}
	NSString *value = [NSString stringWithUTF8String:text];
	return value != nil ? value : @"";
}

// Native import UI is Chinese even when the game falls back to English
// because CJK bitmap fonts are missing. UIKit can render system fonts.

UIColor *DXColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a = 1)
{
	return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

NSString *DocumentsDirectory()
{
	char *path = IOSGetDocumentsPath();
	if (path == nullptr || path[0] == '\0') {
		free(path);
		return nil;
	}
	NSString *documents = [NSString stringWithUTF8String:path];
	free(path);
	if ([documents hasSuffix:@"/"]) {
		documents = [documents substringToIndex:documents.length - 1];
	}
	return documents;
}

bool DocumentsHasFile(NSString *name)
{
	NSString *documents = DocumentsDirectory();
	if (documents == nil) {
		return false;
	}
	return [[NSFileManager defaultManager] fileExistsAtPath:[documents stringByAppendingPathComponent:name]];
}

bool HasMpqHeader(NSURL *url)
{
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL:url error:nil];
	if (handle == nil) {
		return false;
	}
	NSData *header = [handle readDataOfLength:4];
	[handle closeFile];
	if ([header length] < 4) {
		return false;
	}
	const unsigned char *bytes = static_cast<const unsigned char *>([header bytes]);
	return bytes[0] == 'M' && bytes[1] == 'P' && bytes[2] == 'Q' && (bytes[3] == 0x1A || bytes[3] == 0x1B);
}

NSString *CanonicalFileName(NSString *original)
{
	std::string lower = LowerCopy(std::string([original UTF8String] ? [original UTF8String] : ""));
	if (lower == "diabdat.mpq") {
		return @"DIABDAT.MPQ";
	}
	for (const char *name : KnownArchiveNames) {
		if (lower == LowerCopy(name)) {
			return [NSString stringWithUTF8String:name];
		}
	}
	if ([original.pathExtension.lowercaseString isEqualToString:@"mpq"]) {
		return original.lastPathComponent;
	}
	return [original.lastPathComponent stringByAppendingPathExtension:@"mpq"];
}

bool CopyArchive(NSURL *source, NSString *documents)
{
	BOOL scoped = [source startAccessingSecurityScopedResource];
	@try {
		if (!HasMpqHeader(source)) {
			NSLog(@"DevilutionX: rejected %@ (not an MPQ archive)", source.lastPathComponent);
			return false;
		}
		NSString *name = CanonicalFileName(source.lastPathComponent);
		NSString *destinationPath = [documents stringByAppendingPathComponent:name];
		NSURL *destination = [NSURL fileURLWithPath:destinationPath];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSError *error = nil;
		if ([fm fileExistsAtPath:destinationPath]) {
			[fm removeItemAtURL:destination error:&error];
			if (error != nil) {
				NSLog(@"DevilutionX: failed to replace %@: %@", name, error);
				return false;
			}
		}
		if (![fm copyItemAtURL:source toURL:destination error:&error]) {
			NSLog(@"DevilutionX: failed to import %@: %@", name, error);
			return false;
		}
		NSLog(@"DevilutionX: imported %@", name);
		return true;
	} @finally {
		if (scoped) {
			[source stopAccessingSecurityScopedResource];
		}
	}
}

UIViewController *TopViewController()
{
	UIWindow *window = nil;
	if (@available(iOS 13.0, *)) {
		for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
			if (scene.activationState != UISceneActivationStateForegroundActive) {
				continue;
			}
			for (UIWindow *candidate in scene.windows) {
				if (candidate.isKeyWindow) {
					window = candidate;
					break;
				}
			}
			if (window != nil) {
				break;
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
	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController != nil) {
		controller = controller.presentedViewController;
	}
	return controller;
}

void PumpRunLoop()
{
	[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	SDL_PumpEvents();
}

void WaitUntilDismissed(UIViewController *host)
{
	while (host != nil && host.presentedViewController != nil) {
		PumpRunLoop();
	}
}

void ConfigurePopover(UIViewController *presented, UIViewController *host)
{
	UIPopoverPresentationController *popover = presented.popoverPresentationController;
	if (popover == nil || host.view == nil) {
		return;
	}
	popover.sourceView = host.view;
	const CGRect bounds = host.view.bounds;
	popover.sourceRect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1, 1);
	popover.permittedArrowDirections = 0;
}

void RunOnMainThread(void (^block)(void))
{
	if ([NSThread isMainThread]) {
		block();
	} else {
		dispatch_sync(dispatch_get_main_queue(), block);
	}
}

bool HasDiabdat()
{
	return DocumentsHasFile(@"DIABDAT.MPQ") || DocumentsHasFile(@"diabdat.mpq");
}

bool HasSpawn()
{
	return DocumentsHasFile(@"spawn.mpq") || DocumentsHasFile(@"SPAWN.MPQ");
}

bool HasPlayableGameData()
{
	return HasDiabdat() || HasSpawn();
}

bool HasHellfire()
{
	return DocumentsHasFile(@"hellfire.mpq") || DocumentsHasFile(@"hellfire.MPQ");
}

bool GateSatisfied(IOSImportGate gate)
{
	switch (gate) {
	case IOSImportGatePlayable:
		return HasPlayableGameData();
	case IOSImportGateHellfire:
		return HasHellfire();
	case IOSImportGateOptional:
		return true;
	}
	return true;
}

UIButton *DXPanelButton(NSString *title, BOOL prominent)
{
	UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
	config.title = title;
	config.baseForegroundColor = UIColor.whiteColor;
	config.baseBackgroundColor = prominent ? DXColor(0.20, 0.22, 0.27) : DXColor(0.14, 0.16, 0.20);
	config.background.strokeColor = DXColor(1, 1, 1, 0.10);
	config.background.strokeWidth = 1;
	config.cornerStyle = UIButtonConfigurationCornerStyleMedium;
	config.contentInsets = NSDirectionalEdgeInsetsMake(12, 16, 12, 16);
	config.titleLineBreakMode = NSLineBreakByTruncatingTail;
	config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *incoming) {
		NSMutableDictionary<NSAttributedStringKey, id> *attrs = [incoming mutableCopy];
		attrs[NSFontAttributeName] = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
		return attrs;
	};
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	button.configuration = config;
	button.translatesAutoresizingMaskIntoConstraints = NO;
	return button;
}

UIView *DXCardView()
{
	UIView *card = [[UIView alloc] init];
	card.translatesAutoresizingMaskIntoConstraints = NO;
	card.backgroundColor = DXColor(0.105, 0.118, 0.145);
	card.layer.cornerRadius = 18;
	card.layer.borderWidth = 1.0;
	card.layer.borderColor = DXColor(0.78, 0.38, 0.22, 0.90).CGColor;
	card.layer.masksToBounds = YES;
	return card;
}

} // namespace

@interface DXImportScreenController : UIViewController <UIDocumentPickerDelegate>
@property (nonatomic, assign) IOSImportGate gate;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL userQuit;
@property (nonatomic, assign) BOOL pickerFinished;
@property (nonatomic, assign) BOOL importedAny;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation DXImportScreenController

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = UIColor.blackColor;

	UIView *left = DXCardView();
	UIView *right = DXCardView();
	[self.view addSubview:left];
	[self.view addSubview:right];

	UILabel *leftTitle = [self sectionTitle:@"导入正版游戏资源"];
	UILabel *leftBody = [self bodyLabel:@"请选择您合法拥有的《暗黑破坏神》游戏文件。应用不会下载或附带官方资源。"];
	self.statusLabel = [self bodyLabel:@""];
	self.statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
	[self refreshStatus];

	UIButton *selectButton = DXPanelButton(@"选择正版游戏文件", YES);
	UIButton *licenseButton = DXPanelButton(@"查看许可证", NO);
	UIButton *retryButton = DXPanelButton(@"重试", NO);
	[selectButton addTarget:self action:@selector(selectFiles) forControlEvents:UIControlEventTouchUpInside];
	[licenseButton addTarget:self action:@selector(showLicense) forControlEvents:UIControlEventTouchUpInside];
	[retryButton addTarget:self action:@selector(retryOrContinue) forControlEvents:UIControlEventTouchUpInside];

	UIStackView *leftButtons = [[UIStackView alloc] initWithArrangedSubviews:@[licenseButton, retryButton]];
	leftButtons.axis = UILayoutConstraintAxisHorizontal;
	leftButtons.spacing = 10;
	leftButtons.distribution = UIStackViewDistributionFillEqually;
	leftButtons.translatesAutoresizingMaskIntoConstraints = NO;

	UIView *leftInner = [[UIView alloc] init];
	leftInner.translatesAutoresizingMaskIntoConstraints = NO;
	[left addSubview:leftInner];
	[leftInner addSubview:leftTitle];
	[leftInner addSubview:leftBody];
	[leftInner addSubview:self.statusLabel];
	[leftInner addSubview:selectButton];
	[leftInner addSubview:leftButtons];

	UILabel *rightTitle = [self sectionTitle:@"重要声明"];
	UITextView *legal = [[UITextView alloc] init];
	legal.translatesAutoresizingMaskIntoConstraints = NO;
	legal.editable = NO;
	legal.selectable = YES;
	legal.backgroundColor = UIColor.clearColor;
	legal.textColor = DXColor(0.78, 0.81, 0.85);
	legal.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightRegular];
	legal.text = @"本应用由 Nuke Hour（nukehour.com）发布，并非官方 DevilutionX 项目提供、认可或支持。暴雪娱乐未认可且不支持本产品。Nuke Hour 与暴雪娱乐、Microsoft、Battle.net 或官方 DevilutionX 项目不存在隶属、赞助、授权或官方合作关系。\n"
	              "\n"
	              "本应用不包含任何第三方专有游戏文件。用户必须从自己合法购买并拥有的正版游戏副本中手动导入所需文件。《暗黑破坏神》和《暗黑破坏神：地狱火》仍归其权利人所有。文中出现这些名称，仅用于识别需要导入的文件。\n"
	              "\n"
	              "本应用完全免费。任何声称所售副本是 Nuke Hour 或 DevilutionX 官方预授权版本的行为均属虚假宣传；如已付款，请向销售平台举报并申请退款。\n"
	              "\n"
	              "请仅从官方网站 nukehour.com 下载本应用。该网站不提供《暗黑破坏神》游戏文件。完整版请从 GOG.com 或 Battle.net 购买，或使用原版光盘。官方曾经免费发放的只有共享版试玩数据（spawn.mpq）。\n"
	              "\n"
	              "《暗黑破坏神》、《地狱火》及相关商标归其权利人所有。Apple、macOS、iOS 和 iPadOS 是 Apple Inc. 的商标。\n"
	              "\n"
	              "游戏引擎基于 DevilutionX。本移植由 Nuke Hour 修改，源代码在 nukehour.com 按 Sustainable Use License 公开。";
	legal.textContainerInset = UIEdgeInsetsZero;
	legal.textContainer.lineFragmentPadding = 0;
	legal.showsVerticalScrollIndicator = YES;

	UIButton *siteButton = DXPanelButton(@"官方网站 · nukehour.com", NO);
	[siteButton addTarget:self action:@selector(openWebsite) forControlEvents:UIControlEventTouchUpInside];

	UIView *rightInner = [[UIView alloc] init];
	rightInner.translatesAutoresizingMaskIntoConstraints = NO;
	[right addSubview:rightInner];
	[rightInner addSubview:rightTitle];
	[rightInner addSubview:legal];
	[rightInner addSubview:siteButton];

	UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeSystem];
	dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
	NSString *dismissTitle = (self.gate == IOSImportGateOptional) ? @"返回" : @"退出";
	[dismissButton setTitle:dismissTitle forState:UIControlStateNormal];
	[dismissButton setTitleColor:DXColor(0.85, 0.86, 0.88) forState:UIControlStateNormal];
	dismissButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
	[dismissButton addTarget:self action:@selector(dismissTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:dismissButton];

	UILabel *version = [[UILabel alloc] init];
	version.translatesAutoresizingMaskIntoConstraints = NO;
	version.text = [NSString stringWithFormat:@"NUKE HOUR · %s", PROJECT_VERSION];
	version.textColor = DXColor(0.45, 0.47, 0.50);
	version.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
	version.textAlignment = NSTextAlignmentRight;
	[self.view addSubview:version];

	UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
	[NSLayoutConstraint activateConstraints:@[
		[left.topAnchor constraintEqualToAnchor:safe.topAnchor constant:28],
		[left.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
		[left.bottomAnchor constraintEqualToAnchor:version.topAnchor constant:-10],
		[right.topAnchor constraintEqualToAnchor:left.topAnchor],
		[right.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
		[right.bottomAnchor constraintEqualToAnchor:left.bottomAnchor],
		[right.leadingAnchor constraintEqualToAnchor:left.trailingAnchor constant:16],
		[left.widthAnchor constraintEqualToAnchor:right.widthAnchor],

		[leftInner.topAnchor constraintEqualToAnchor:left.topAnchor constant:22],
		[leftInner.leadingAnchor constraintEqualToAnchor:left.leadingAnchor constant:22],
		[leftInner.trailingAnchor constraintEqualToAnchor:left.trailingAnchor constant:-22],
		[leftInner.bottomAnchor constraintEqualToAnchor:left.bottomAnchor constant:-22],
		[leftTitle.topAnchor constraintEqualToAnchor:leftInner.topAnchor],
		[leftTitle.leadingAnchor constraintEqualToAnchor:leftInner.leadingAnchor],
		[leftTitle.trailingAnchor constraintEqualToAnchor:leftInner.trailingAnchor],
		[leftBody.topAnchor constraintEqualToAnchor:leftTitle.bottomAnchor constant:10],
		[leftBody.leadingAnchor constraintEqualToAnchor:leftInner.leadingAnchor],
		[leftBody.trailingAnchor constraintEqualToAnchor:leftInner.trailingAnchor],
		[self.statusLabel.topAnchor constraintEqualToAnchor:leftBody.bottomAnchor constant:12],
		[self.statusLabel.leadingAnchor constraintEqualToAnchor:leftInner.leadingAnchor],
		[self.statusLabel.trailingAnchor constraintEqualToAnchor:leftInner.trailingAnchor],
		[selectButton.leadingAnchor constraintEqualToAnchor:leftInner.leadingAnchor],
		[selectButton.trailingAnchor constraintEqualToAnchor:leftInner.trailingAnchor],
		[selectButton.heightAnchor constraintGreaterThanOrEqualToConstant:48],
		[leftButtons.topAnchor constraintEqualToAnchor:selectButton.bottomAnchor constant:10],
		[leftButtons.leadingAnchor constraintEqualToAnchor:leftInner.leadingAnchor],
		[leftButtons.trailingAnchor constraintEqualToAnchor:leftInner.trailingAnchor],
		[leftButtons.bottomAnchor constraintEqualToAnchor:leftInner.bottomAnchor],
		[leftButtons.heightAnchor constraintEqualToConstant:46],
		[selectButton.topAnchor constraintGreaterThanOrEqualToAnchor:self.statusLabel.bottomAnchor constant:16],

		[rightInner.topAnchor constraintEqualToAnchor:right.topAnchor constant:22],
		[rightInner.leadingAnchor constraintEqualToAnchor:right.leadingAnchor constant:22],
		[rightInner.trailingAnchor constraintEqualToAnchor:right.trailingAnchor constant:-22],
		[rightInner.bottomAnchor constraintEqualToAnchor:right.bottomAnchor constant:-22],
		[rightTitle.topAnchor constraintEqualToAnchor:rightInner.topAnchor],
		[rightTitle.leadingAnchor constraintEqualToAnchor:rightInner.leadingAnchor],
		[rightTitle.trailingAnchor constraintEqualToAnchor:rightInner.trailingAnchor],
		[legal.topAnchor constraintEqualToAnchor:rightTitle.bottomAnchor constant:10],
		[legal.leadingAnchor constraintEqualToAnchor:rightInner.leadingAnchor],
		[legal.trailingAnchor constraintEqualToAnchor:rightInner.trailingAnchor],
		[siteButton.topAnchor constraintEqualToAnchor:legal.bottomAnchor constant:12],
		[siteButton.leadingAnchor constraintEqualToAnchor:rightInner.leadingAnchor],
		[siteButton.trailingAnchor constraintEqualToAnchor:rightInner.trailingAnchor],
		[siteButton.bottomAnchor constraintEqualToAnchor:rightInner.bottomAnchor],
		[siteButton.heightAnchor constraintGreaterThanOrEqualToConstant:48],

		[dismissButton.topAnchor constraintEqualToAnchor:safe.topAnchor constant:4],
		[dismissButton.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
		[version.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
		[version.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-6],
	]];
}

- (UILabel *)sectionTitle:(NSString *)text
{
	UILabel *label = [[UILabel alloc] init];
	label.translatesAutoresizingMaskIntoConstraints = NO;
	label.text = text;
	label.textColor = DXColor(0.91, 0.72, 0.28);
	label.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
	label.numberOfLines = 1;
	return label;
}

- (UILabel *)bodyLabel:(NSString *)text
{
	UILabel *label = [[UILabel alloc] init];
	label.translatesAutoresizingMaskIntoConstraints = NO;
	label.text = text;
	label.textColor = DXColor(0.78, 0.81, 0.85);
	label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
	label.numberOfLines = 0;
	return label;
}

- (void)appendStatus:(NSMutableAttributedString *)target title:(NSString *)title value:(NSString *)value imported:(BOOL)imported
{
	if (target.length > 0) {
		[target appendAttributedString:[[NSAttributedString alloc] initWithString:@"  " attributes:@{
			NSFontAttributeName : [UIFont systemFontOfSize:15 weight:UIFontWeightRegular],
			NSForegroundColorAttributeName : DXColor(0.78, 0.81, 0.85),
		}]];
	}
	UIColor *valueColor = imported ? DXColor(0.47, 0.80, 0.58) : DXColor(0.55, 0.58, 0.62);
	[target appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@：", title] attributes:@{
		NSFontAttributeName : [UIFont systemFontOfSize:15 weight:UIFontWeightRegular],
		NSForegroundColorAttributeName : DXColor(0.78, 0.81, 0.85),
	}]];
	[target appendAttributedString:[[NSAttributedString alloc] initWithString:value attributes:@{
		NSFontAttributeName : [UIFont systemFontOfSize:15 weight:UIFontWeightRegular],
		NSForegroundColorAttributeName : valueColor,
	}]];
}

- (void)refreshStatus
{
	NSMutableAttributedString *status = [[NSMutableAttributedString alloc] init];
	NSString *baseValue = @"未导入";
	BOOL baseImported = NO;
	if (HasDiabdat()) {
		baseValue = @"完整版";
		baseImported = YES;
	} else if (HasSpawn()) {
		baseValue = @"共享版";
		baseImported = YES;
	}
	[self appendStatus:status title:@"基础游戏" value:baseValue imported:baseImported];
	[self appendStatus:status title:@"地狱火" value:HasHellfire() ? @"已导入" : @"未导入" imported:HasHellfire()];
	const BOOL monk = DocumentsHasFile(@"hfmonk.mpq");
	const BOOL music = DocumentsHasFile(@"hfmusic.mpq");
	const BOOL voice = DocumentsHasFile(@"hfvoice.mpq");
	[self appendStatus:status title:@"武僧" value:monk ? @"已导入" : @"未导入" imported:monk];
	[self appendStatus:status title:@"音乐" value:music ? @"已导入" : @"未导入" imported:music];
	[self appendStatus:status title:@"语音" value:voice ? @"已导入" : @"未导入" imported:voice];
	self.statusLabel.attributedText = status;
}

- (NSArray<UTType *> *)archiveTypes
{
	NSMutableArray<UTType *> *types = [NSMutableArray array];
	UTType *declared = [UTType typeWithIdentifier:@"com.diasurgical.mpq"];
	if (declared != nil) {
		[types addObject:declared];
	}
	UTType *mpq = [UTType typeWithFilenameExtension:@"mpq"];
	if (mpq != nil) {
		[types addObject:mpq];
	}
	[types addObject:UTTypeData];
	[types addObject:UTTypeItem];
	return types;
}

- (void)selectFiles
{
	self.pickerFinished = NO;
	UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:[self archiveTypes] asCopy:YES];
	picker.delegate = self;
	picker.allowsMultipleSelection = YES;
	picker.shouldShowFileExtensions = YES;
	ConfigurePopover(picker, self);
	[self presentViewController:picker animated:YES completion:nil];
	while (!self.pickerFinished) {
		PumpRunLoop();
	}
	WaitUntilDismissed(self);
	[self refreshStatus];
}

- (void)retryOrContinue
{
	[self refreshStatus];
	if (self.gate == IOSImportGateOptional) {
		return;
	}
	if (GateSatisfied(self.gate)) {
		self.userQuit = NO;
		self.finished = YES;
	}
}

- (void)dismissTapped
{
	if (self.gate == IOSImportGateOptional) {
		self.userQuit = NO;
		self.finished = YES;
		return;
	}
	self.userQuit = !GateSatisfied(self.gate);
	self.finished = YES;
}

- (void)showLicense
{
	UIViewController *license = [[UIViewController alloc] init];
	license.view.backgroundColor = DXColor(0.07, 0.08, 0.10);
	license.navigationItem.title = @"查看许可证";
	license.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"好" style:UIBarButtonItemStyleDone target:self action:@selector(closeLicense)];

	UITextView *text = [[UITextView alloc] init];
	text.translatesAutoresizingMaskIntoConstraints = NO;
	text.editable = NO;
	text.backgroundColor = UIColor.clearColor;
	text.textColor = DXColor(0.85, 0.86, 0.88);
	text.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
	text.text = @"本软件已经由 Nuke Hour 修改。\n"
	             "官方网站与源代码：https://nukehour.com\n"
	             "\n"
	             "Sustainable Use License\n"
	             "\n"
	             "你可以将本软件用于个人或非商业用途，也可以免费分发非商业副本。\n"
	             "\n"
	             "本应用不包含《暗黑破坏神》或地狱火资料片。请从你购买的正版副本中导入 MPQ（DIABDAT.MPQ 或 spawn.mpq，以及可选的地狱火文件）。\n"
	             "\n"
	             "引擎基于 DevilutionX。原始许可见官方网站 nukehour.com 公布的源代码。";
	[license.view addSubview:text];
	[NSLayoutConstraint activateConstraints:@[
		[text.topAnchor constraintEqualToAnchor:license.view.safeAreaLayoutGuide.topAnchor constant:12],
		[text.leadingAnchor constraintEqualToAnchor:license.view.safeAreaLayoutGuide.leadingAnchor constant:16],
		[text.trailingAnchor constraintEqualToAnchor:license.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
		[text.bottomAnchor constraintEqualToAnchor:license.view.bottomAnchor],
	]];

	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:license];
	nav.modalPresentationStyle = UIModalPresentationFormSheet;
	[self presentViewController:nav animated:YES completion:nil];
}

- (void)closeLicense
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openWebsite
{
	NSURL *url = [NSURL URLWithString:@"https://nukehour.com"];
	if (url != nil) {
		[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
	}
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	NSString *documents = DocumentsDirectory();
	if (documents != nil) {
		for (NSURL *url in urls) {
			if (CopyArchive(url, documents)) {
				self.importedAny = YES;
			}
		}
	}
	self.pickerFinished = YES;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
	self.pickerFinished = YES;
}

@end

@interface DXFileImportController : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL importedAny;
@end

@implementation DXFileImportController

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	NSString *documents = DocumentsDirectory();
	if (documents == nil) {
		self.finished = YES;
		return;
	}
	for (NSURL *url in urls) {
		if (CopyArchive(url, documents)) {
			self.importedAny = YES;
		}
	}
	self.finished = YES;
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
	self.finished = YES;
}

@end

bool IOSPresentImportScreen(IOSImportGate gate)
{
	__block bool success = GateSatisfied(gate);
	if (gate != IOSImportGateOptional && success) {
		return true;
	}

	RunOnMainThread(^{
		UIViewController *host = TopViewController();
		if (host == nil) {
			NSLog(@"DevilutionX: no view controller available for import screen");
			return;
		}

		DXImportScreenController *screen = [[DXImportScreenController alloc] init];
		screen.gate = gate;
		screen.modalPresentationStyle = UIModalPresentationOverFullScreen;
		screen.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
		[host presentViewController:screen animated:YES completion:nil];
		while (!screen.finished) {
			PumpRunLoop();
		}
		success = !screen.userQuit && (gate == IOSImportGateOptional || GateSatisfied(gate));
		[screen dismissViewControllerAnimated:YES completion:nil];
		WaitUntilDismissed(host);
	});
	return success;
}

void IOSShowNotice(const char *title, const char *message, const char *okButton)
{
	RunOnMainThread(^{
		UIViewController *host = TopViewController();
		if (host == nil) {
			NSLog(@"DevilutionX: no view controller available for notice");
			return;
		}

		__block BOOL finished = NO;
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSStringFromUtf8(title)
		                                                               message:NSStringFromUtf8(message)
		                                                        preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:NSStringFromUtf8(okButton)
		                                          style:UIAlertActionStyleDefault
		                                        handler:^(UIAlertAction *) {
			                                        finished = YES;
		                                        }]];
		[host presentViewController:alert animated:YES completion:nil];
		while (!finished) {
			PumpRunLoop();
		}
		WaitUntilDismissed(host);
	});
}

bool IOSPromptAndImportGameData(void)
{
	__block bool imported = false;
	RunOnMainThread(^{
		NSString *documents = DocumentsDirectory();
		if (documents == nil) {
			return;
		}

		NSMutableArray<UTType *> *types = [NSMutableArray array];
		UTType *declared = [UTType typeWithIdentifier:@"com.diasurgical.mpq"];
		if (declared != nil) {
			[types addObject:declared];
		}
		UTType *mpq = [UTType typeWithFilenameExtension:@"mpq"];
		if (mpq != nil) {
			[types addObject:mpq];
		}
		[types addObject:UTTypeData];
		[types addObject:UTTypeItem];

		DXFileImportController *delegate = [DXFileImportController new];
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
		picker.delegate = delegate;
		picker.allowsMultipleSelection = YES;
		picker.shouldShowFileExtensions = YES;

		UIViewController *host = TopViewController();
		if (host == nil) {
			NSLog(@"DevilutionX: no view controller available for document picker");
			return;
		}

		ConfigurePopover(picker, host);
		[host presentViewController:picker animated:YES completion:nil];

		while (!delegate.finished) {
			PumpRunLoop();
		}
		WaitUntilDismissed(host);
		imported = delegate.importedAny;
		(void)delegate;
	});
	return imported;
}
