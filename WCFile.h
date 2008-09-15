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

#import "WCServerConnectionObject.h"

enum _WCFileType {
	WCFileFile,
	WCFileDirectory,
	WCFileUploads,
	WCFileDropBox
};
typedef enum _WCFileType			WCFileType;

enum _WCFilePermissions {
	WCFileWrite						= 2,
	WCFileRead						= 4
};
typedef enum _WCFilePermissions		WCFilePermissions;


@interface WCFile : WCServerConnectionObject <NSCoding> {
	WCFileType						_type;
	WIFileOffset					_size;
	WIFileOffset					_free;
	NSString						*_path;
	NSDate							*_creationDate;
	NSDate							*_modificationDate;
	NSString						*_comment;
	BOOL							_link;
	BOOL							_executable;
	NSString						*_owner;
	NSUInteger						_ownerPermissions;
	NSString						*_group;
	NSUInteger						_groupPermissions;
	NSUInteger						_everyonePermissions;

	NSString						*_name;
	NSString						*_extension;
	NSString						*_kind;
	NSMutableDictionary				*_icons;

	NSString						*_localPath;

@public
	WIFileOffset					_transferred;
}

+ (NSImage *)iconForFolderType:(WCFileType)type width:(CGFloat)width;
+ (NSString *)kindForFolderType:(WCFileType)type;
+ (WCFileType)folderTypeForString:(NSString *)string;

+ (id)fileWithRootDirectoryForConnection:(WCServerConnection *)connection;
+ (id)fileWithDirectory:(NSString *)path connection:(WCServerConnection *)connection;
+ (id)fileWithFile:(NSString *)path connection:(WCServerConnection *)connection;
+ (id)fileWithPath:(NSString *)path type:(WCFileType)type connection:(WCServerConnection *)connection;
+ (id)fileWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection;

- (WCFileType)type;
- (NSString *)path;
- (NSDate *)creationDate;
- (NSDate *)modificationDate;
- (NSString *)comment;
- (NSString *)name;
- (NSString *)extension;
- (NSString *)kind;
- (BOOL)isFolder;
- (BOOL)isUploadsFolder;
- (BOOL)isLink;
- (BOOL)isExecutable;
- (NSString *)owner;
- (NSUInteger)ownerPermissions;
- (NSString *)group;
- (NSUInteger)groupPermissions;
- (NSUInteger)everyonePermissions;
- (NSImage *)iconWithWidth:(CGFloat)width;

- (void)setSize:(WIFileOffset)size;
- (WIFileOffset)size;
- (void)setFree:(WIFileOffset)free;
- (WIFileOffset)free;
- (void)setLocalPath:(NSString *)localPath;
- (NSString *)localPath;
- (void)setTransferred:(WIFileOffset)transferred;
- (WIFileOffset)transferred;

- (NSComparisonResult)compareName:(WCFile *)file;
- (NSComparisonResult)compareKind:(WCFile *)file;
- (NSComparisonResult)compareModificationDate:(WCFile *)file;
- (NSComparisonResult)compareSize:(WCFile *)file;

@end
