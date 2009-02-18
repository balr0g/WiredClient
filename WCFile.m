/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import "WCCache.h"
#import "WCFile.h"

@interface WCFile(Private)

- (id)_initWithPath:(NSString *)path type:(WCFileType)type connection:(WCServerConnection *)connection;
- (id)_initWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection;

@end


@implementation WCFile(Private)

- (id)_initWithPath:(NSString *)path type:(WCFileType)type connection:(WCServerConnection *)connection {
	self = [super initWithConnection:connection];
	
	_path = [path retain];
	_type = type;
	
	return self;
}



- (id)_initWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	WIP7UInt64		size;
	WIP7Enum		type;
	WIP7Bool		link, executable, value;
	
	self = [super initWithConnection:connection];
	
	[message getEnum:&type forName:@"wired.file.type"];
	[message getUInt64:&size forName:@"wired.file.size"];
	[message getBool:&link forName:@"wired.file.link"];
	[message getBool:&executable forName:@"wired.file.executable"];

	_type				= type;
	_size				= size;
	_creationDate		= [[message dateForName:@"wired.file.creation_time"] retain];
	_modificationDate	= [[message dateForName:@"wired.file.modification_time"] retain];
	_comment			= [[message stringForName:@"wired.file.comment"] retain];
	_path				= [[message stringForName:@"wired.file.path"] retain];
	_link				= link;
	_executable			= executable;
	
	_owner = [[message stringForName:@"wired.file.owner"] retain];
	
	if(!_owner)
		_owner = @"";
	
	if([message getBool:&value forName:@"wired.file.owner.read"] && value)
		_ownerPermissions |= WCFileRead;

	if([message getBool:&value forName:@"wired.file.owner.write"] && value)
		_ownerPermissions |= WCFileWrite;
	
	_group = [[message stringForName:@"wired.file.group"] retain];
	
	if(!_group)
		_group = @"";
	
	if([message getBool:&value forName:@"wired.file.group.read"] && value)
		_groupPermissions |= WCFileRead;

	if([message getBool:&value forName:@"wired.file.group.write"] && value)
		_groupPermissions |= WCFileWrite;
	
	if([message getBool:&value forName:@"wired.file.everyone.read"] && value)
		_everyonePermissions |= WCFileRead;

	if([message getBool:&value forName:@"wired.file.everyone.write"] && value)
		_everyonePermissions |= WCFileWrite;
	
	return self;
}

@end


@implementation WCFile

+ (NSInteger)version {
	return 1;
}



#pragma mark -

+ (NSImage *)iconForFolderType:(WCFileType)type width:(CGFloat)width {
	static NSImage		*folderImage;
	static NSImage		*folderImage32, *folderImage16, *folderImage12;
	static NSImage		*uploadsImage32, *uploadsImage16, *uploadsImage12;
	static NSImage		*dropBoxImage32, *dropBoxImage16, *dropBoxImage12;
	NSEnumerator		*enumerator;
	NSImageRep			*representation, *folderRepresentation;
	NSImage				*image = NULL, *badgeImage;
	
	if(!folderImage)
		folderImage = [[NSImage imageNamed:@"Folder"] retain];

	switch(type) {
		case WCFileDirectory:
			if(width == 32.0)
				image = folderImage32;
			else if(width == 16.0)
				image = folderImage16;
			else if(width == 12.0)
				image = folderImage12;
			
			if(!image) {
				image = [[NSImage alloc] initWithSize:NSMakeSize(width, width)];
				[folderImage setSize:[image size]];
				
				folderRepresentation	= NULL;
				enumerator				= [[folderImage representations] objectEnumerator];
				
				while((representation = [enumerator nextObject])) {
					if([representation size].width >= width)
						folderRepresentation = representation;
				}
				
				if(folderRepresentation)
					[image addRepresentation:folderRepresentation];
				
				if(width == 32.0)
					folderImage32 = image;
				else if(width == 16.0)
					folderImage16 = image;
				else if(width == 12.0)
					folderImage12 = image;
			}
			break;
		
		case WCFileUploads:
			if(width == 32.0)
				image = uploadsImage32;
			else if(width == 16.0)
				image = uploadsImage16;
			else if(width == 12.0)
				image = uploadsImage12;
			
			if(!image) {
				[folderImage setSize:NSMakeSize(width, width)];
				badgeImage = [[[NSImage imageNamed:@"UploadsBadge"] copy] autorelease];
				[badgeImage setSize:[folderImage size]];
				image = [[folderImage imageBySuperimposingImage:badgeImage] retain];
				
				if(width == 32.0)
					uploadsImage32 = image;
				else if(width == 16.0)
					uploadsImage16 = image;
				else if(width == 12.0)
					uploadsImage12 = image;
			}
			break;

		case WCFileDropBox:
			if(width == 32.0)
				image = dropBoxImage32;
			else if(width == 16.0)
				image = dropBoxImage16;
			else if(width == 12.0)
				image = dropBoxImage12;
			
			if(!image) {
				[folderImage setSize:NSMakeSize(width, width)];
				badgeImage = [[[NSImage imageNamed:@"DropBoxBadge"] copy] autorelease];
				[badgeImage setSize:[folderImage size]];
				image = [[folderImage imageBySuperimposingImage:badgeImage] retain];
				
				if(width == 32.0)
					dropBoxImage32 = image;
				else if(width == 16.0)
					dropBoxImage16 = image;
				else if(width == 12.0)
					dropBoxImage12 = image;
			}
			break;

		case WCFileFile:
			break;
	}
	
	return image;
}



+ (NSString *)kindForFolderType:(WCFileType)type {
	static NSString		*folder, *uploads, *dropbox;
	
	switch(type) {
		case WCFileDirectory:
			if(!folder)
				LSCopyKindStringForTypeInfo('fold', kLSUnknownCreator, NULL, (CFStringRef *) &folder);
			
			return folder;
			break;
			
		case WCFileUploads:
			if(!uploads)
				uploads = [NSLS(@"Uploads Folder", @"Uploads folder kind") retain];

			return uploads;
			break;
			
		case WCFileDropBox:
			if(!dropbox)
				dropbox = [NSLS(@"Drop Box Folder", @"Drop box folder kind") retain];

			return dropbox;
			break;

		case WCFileFile:
		default:
			return NULL;
			break;
	}
		
	return NULL;
}



+ (WCFileType)folderTypeForString:(NSString *)string {
	static NSString		*uploads, *dropbox;
	NSRange				range;
	
	if(!uploads) {
		uploads = [NSLS(@"upload", @"Short uploads folder kind") retain];
		dropbox = [NSLS(@"drop box", @"Short drop box folder kind") retain];
	}
	
	range = [string rangeOfString:uploads options:NSCaseInsensitiveSearch];

	if(range.location != NSNotFound)
		return WCFileUploads;

	range = [string rangeOfString:dropbox options:NSCaseInsensitiveSearch];

	if(range.location != NSNotFound)
		return WCFileDropBox;
		
	return WCFileDirectory;
}



#pragma mark -

+ (id)fileWithRootDirectoryForConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithPath:@"/" type:WCFileDirectory connection:connection] autorelease];
}



+ (id)fileWithDirectory:(NSString *)path connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithPath:path type:WCFileDirectory connection:connection] autorelease];
}



+ (id)fileWithFile:(NSString *)path connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithPath:path type:WCFileFile connection:connection] autorelease];
}



+ (id)fileWithPath:(NSString *)path type:(WCFileType)type connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithPath:path type:type connection:connection] autorelease];
}



+ (id)fileWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection {
	return [[[self alloc] _initWithMessage:message connection:connection] autorelease];
}



#pragma mark -

- (id)init {
	self = [super init];
	
	_icons = [[NSMutableDictionary alloc] init];
	
	return self;
}



- (void)dealloc {
	[_path release];
	[_modificationDate release];
	[_comment release];

	[_name release];
	[_extension release];
	[_kind release];
	[_icons release];
	
	[super dealloc];
}



#pragma mark -

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
	
	if(!self)
		return NULL;
	
    if([coder decodeIntForKey:@"WCFileVersion"] != [[self class] version]) {
        [self release];
		
        return NULL;
    }
	
	_type					= [coder decodeIntForKey:@"WCFileType"];
	_size					= [coder decodeInt64ForKey:@"WCFileSize"];
	_free					= [coder decodeInt64ForKey:@"WCFileFree"];
	_path					= [[coder decodeObjectForKey:@"WCFilePath"] retain];
	_creationDate			= [[coder decodeObjectForKey:@"WCFileCreationDate"] retain];
	_modificationDate		= [[coder decodeObjectForKey:@"WCFileModificationDate"] retain];
	_comment				= [[coder decodeObjectForKey:@"WCFileComment"] retain];
	_link					= [coder decodeBoolForKey:@"WCFileLink"];
	_executable				= [coder decodeBoolForKey:@"WCFileExecutable"];
	_owner					= [[coder decodeObjectForKey:@"WCFileOwner"] retain];
	_ownerPermissions		= [coder decodeIntForKey:@"WCFileOwnerPermission"];
	_group					= [[coder decodeObjectForKey:@"WCFileGroup"] retain];
	_groupPermissions		= [coder decodeIntForKey:@"WCFileGroupPermissions"];
	_everyonePermissions	= [coder decodeIntForKey:@"WCFileEveryonePermissions"];
	
	_localPath				= [[coder decodeObjectForKey:@"WCFileLocalPath"] retain];
	_transferred			= [coder decodeInt64ForKey:@"WCFileTransferred"];

	return self;
}



- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:[[self class] version] forKey:@"WCFileVersion"];
	
	[coder encodeInt:_type forKey:@"WCFileType"];
	[coder encodeInt64:_size forKey:@"WCFileSize"];
	[coder encodeInt64:_free forKey:@"WCFileFree"];
	[coder encodeObject:_path forKey:@"WCFilePath"];
	[coder encodeObject:_creationDate forKey:@"WCFileCreationDate"];
	[coder encodeObject:_modificationDate forKey:@"WCFileModificationDate"];
	[coder encodeObject:_comment forKey:@"WCFileComment"];
	[coder encodeBool:_link forKey:@"WCFileLink"];
	[coder encodeBool:_executable forKey:@"WCFileExecutable"];
	[coder encodeObject:_owner forKey:@"WCFileOwner"];
	[coder encodeInt:_ownerPermissions forKey:@"WCFileOwnerPermissions"];
	[coder encodeObject:_group forKey:@"WCFileGroup"];
	[coder encodeInt:_groupPermissions forKey:@"WCFileGroupPermissions"];
	[coder encodeInt:_everyonePermissions forKey:@"WCFileEveryonePermissions"];

	[coder encodeObject:_localPath forKey:@"WCFileLocalPath"];
	[coder encodeInt:_transferred forKey:@"WCFileTransferred"];

	[super encodeWithCoder:coder];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	WCFile		*file;
	
	file = [[[self class] allocWithZone:zone] init];

	file->_type				= _type;
	file->_size				= _size;
	file->_free				= _free;
	file->_path				= [_path copy];
	file->_modificationDate	= [_modificationDate copy];
	file->_comment			= [_comment copy];

	return file;
}



- (BOOL)isEqual:(id)object {
	if(_connection == [(WCFile *) object connection])
		return [_path isEqualToString:[object path]];
	
	return NO;
}



- (NSUInteger)hash {
	return [_path hash] + [_connection hash];
}



- (NSString *)description {
	return [NSSWF:@"<%@ %p>{path = %@, type = %d}",
		[self className],
		self,
		[self path],
		[self type]];
}



#pragma mark -

- (WCFileType)type {
	return _type;
}



- (NSString *)path {
	return _path;
}



- (NSDate *)creationDate {
	return _creationDate;
}



- (NSDate *)modificationDate {
	return _modificationDate;
}



- (NSString *)comment {
	return _comment;
}



- (NSString *)name {
	if(!_name)
		_name = [[[self path] lastPathComponent] retain];
	
	return _name;
}



- (NSString *)extension {
	if(!_extension)
		_extension = [[[self path] pathExtension] retain];
	
	return _extension;
}



- (NSString *)kind {
	if(!_kind) {
		if([self isLink]) {
			_kind = [NSLS(@"Alias", @"Alias kind") retain];
		}
		else if([self isExecutable]) {
			_kind = [NSLS(@"Executable File", @"Executable kind") retain];
		}
		else if([self isFolder]) {
			_kind = [[[self class] kindForFolderType:[self type]] retain];
		}
		else {
			LSCopyKindStringForTypeInfo(kLSUnknownType,
										kLSUnknownCreator,
										(CFStringRef) [self extension],
										(CFStringRef *) &_kind);
		}
	}
		
	return _kind;
}



- (BOOL)isFolder {
	return ([self type] != WCFileFile);
}



- (BOOL)isUploadsFolder {
	return ([self type] == WCFileUploads || [self type] == WCFileDropBox);
}



- (BOOL)isLink {
	return _link;
}



- (BOOL)isExecutable {
	return (_executable && [[self extension] length] == 0);
}



- (NSString *)owner {
	return _owner;
}



- (NSUInteger)ownerPermissions {
	return _ownerPermissions;
}



- (NSString *)group {
	return _group;
}



- (NSUInteger)groupPermissions {
	return _groupPermissions;
}



- (NSUInteger)everyonePermissions {
	return _everyonePermissions;
}



- (NSImage *)iconWithWidth:(CGFloat)width {
	NSImage		*icon, *badgeImage;
	NSString	*extension;
	
	icon = [_icons objectForKey:[NSNumber numberWithFloat:width]];
	
	if(!icon) {
		if([self isFolder]) {
			icon = [[self class] iconForFolderType:[self type] width:width];
		}
		else if([self isExecutable]) {
			icon = [[[NSImage imageNamed:@"Executable"] copy] autorelease];
			[icon setSize:NSMakeSize(width, width)];
		}
		else {
			extension = [self extension];
			icon = [[WCCache cache] fileIconForExtension:extension];
			
			if(!icon) {
				icon = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
				[[WCCache cache] setFileIcon:icon forExtension:extension];
			}
			
			icon = [[icon copy] autorelease];
			[icon setSize:NSMakeSize(width, width)];
		}

		if([self isLink]) {
			badgeImage = [[[NSImage imageNamed:@"AliasBadge"] copy] autorelease];
			icon = [icon imageBySuperimposingImage:badgeImage];
		}
		
		[_icons setObject:icon forKey:[NSNumber numberWithFloat:width]];
	}
	
	return icon;
}



#pragma mark -

- (void)setSize:(WIFileOffset)size {
	_size = size;
}



- (WIFileOffset)size {
	return _size;
}



- (void)setFree:(WIFileOffset)free {
	_free = free;
}



- (WIFileOffset)free {
	return _free;
}



- (void)setLocalPath:(NSString *)path {
	[path retain];
	[_localPath release];

	_localPath = path;
}



- (NSString *)localPath {
	return _localPath;
}



- (void)setTransferred:(WIFileOffset)transferred {
	_transferred = transferred;
}



- (WIFileOffset)transferred {
	return _transferred;
}



#pragma mark -

- (NSComparisonResult)compareName:(WCFile *)file {
	return [[self name] compare:[file name] options:NSCaseInsensitiveSearch | NSNumericSearch];
}



- (NSComparisonResult)compareKind:(WCFile *)file {
	NSComparisonResult		result;

	result = [[self kind] compare:[file kind] options:NSCaseInsensitiveSearch];

	if(result == NSOrderedSame)
		result = [self compareName:file];

	return result;
}



- (NSComparisonResult)compareModificationDate:(WCFile *)file {
	NSComparisonResult		result;

	result = [[self modificationDate] compare:[file modificationDate]];

	if(result == NSOrderedSame)
		result = [self compareName:file];

	return result;
}



- (NSComparisonResult)compareSize:(WCFile *)file {
	if([self type] == WCFileFile && [file type] != WCFileFile)
		return NSOrderedAscending;
	else if([self type] != WCFileFile && [file type] == WCFileFile)
		return NSOrderedDescending;

	if([self size] > [file size])
		return NSOrderedAscending;
	else if([self size] < [file size])
		return NSOrderedDescending;

	return [self compareName:file];
}

@end
