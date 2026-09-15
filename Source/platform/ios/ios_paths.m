#import <Foundation/Foundation.h>

#include "ios_paths.h"

#include <string.h>
#include <stdlib.h>

static char *IOSCopyPath(NSString *path)
{
	if (path == nil) {
		return NULL;
	}
	if (![path hasSuffix:@"/"]) {
		path = [path stringByAppendingString:@"/"];
	}
	const char *base = [path fileSystemRepresentation];
	char *copy = malloc(strlen(base) + 1);
	if (copy == NULL) {
		return NULL;
	}
	strcpy(copy, base);
	return copy;
}

static NSString *IOSFirstSearchPath(NSSearchPathDirectory directory)
{
	NSArray *array = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
	if ([array count] == 0) {
		return nil;
	}
	return array[0];
}

static void IOSEnsureDirectory(NSString *path)
{
	[[NSFileManager defaultManager] createDirectoryAtPath:path
	                          withIntermediateDirectories:YES
	                                           attributes:nil
	                                                error:nil];
}

static void IOSMigrateFileIfNeeded(NSString *fromPath, NSString *toPath)
{
	NSFileManager *fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:fromPath] || [fm fileExistsAtPath:toPath]) {
		return;
	}
	[fm copyItemAtPath:fromPath toPath:toPath error:nil];
}

static NSString *IOSSupportDirectory()
{
	NSString *root = IOSFirstSearchPath(NSApplicationSupportDirectory);
	if (root == nil) {
		return nil;
	}
	NSString *support = [root stringByAppendingPathComponent:@"diasurgical/devilution"];
	IOSEnsureDirectory(support);
	return support;
}

static void IOSMigrateSavesAndConfig(NSString *documents, NSString *support)
{
	if (documents == nil || support == nil) {
		return;
	}

	IOSMigrateFileIfNeeded(
	    [documents stringByAppendingPathComponent:@"diablo.ini"],
	    [support stringByAppendingPathComponent:@"diablo.ini"]);

	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documents error:nil];
	for (NSString *file in files) {
		NSString *ext = file.pathExtension.lowercaseString;
		if (![ext isEqualToString:@"sv"] && ![ext isEqualToString:@"hsv"]) {
			continue;
		}
		IOSMigrateFileIfNeeded(
		    [documents stringByAppendingPathComponent:file],
		    [support stringByAppendingPathComponent:file]);
	}
}

char *IOSGetDocumentsPath()
{
	@autoreleasepool {
		NSString *documents = IOSFirstSearchPath(NSDocumentDirectory);
		if (documents == nil) {
			return strdup("");
		}
		IOSEnsureDirectory(documents);
		return IOSCopyPath(documents);
	}
}

char *IOSGetPrefPath()
{
	@autoreleasepool {
		NSString *support = IOSSupportDirectory();
		if (support == nil) {
			return IOSGetDocumentsPath();
		}
		IOSMigrateSavesAndConfig(IOSFirstSearchPath(NSDocumentDirectory), support);
		return IOSCopyPath(support);
	}
}

char *IOSGetConfigPath()
{
	return IOSGetPrefPath();
}
