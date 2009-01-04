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

#import "WCAccount.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCFilesController.h"
#import "WCPreferences.h"
#import "WCSearch.h"
#import "WCServerConnection.h"
#import "WCTransfers.h"

#define WCSearchTypeAudioExtensions		@"aif aiff au mid midi mp3 mp4 wav"
#define WCSearchTypeImageExtensions		@"bmp ico eps jpg jpeg tif tiff gif pict pct png psd sgi tga"
#define WCSearchTypeMovieExtensions		@"avi dv flash mp4 mpg mpg4 mpeg mov rm swf wvm"


@interface WCSearch(Private)

+ (NSSet *)_audioFileTypes;
+ (NSSet *)_imageFileTypes;
+ (NSSet *)_movieFileTypes;

- (void)_validate;
- (void)_themeDidChange;
- (void)_reloadServersMenu;

@end


@implementation WCSearch(Private)

+ (NSSet *)_audioFileTypes {
	static NSMutableSet		*extensions;

	if(!extensions) {
		extensions = [[NSMutableSet alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeAudioExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeAudioExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSSet *)_imageFileTypes {
	static NSMutableSet		*extensions;

	if(!extensions) {
		extensions = [[NSMutableSet alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeImageExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeImageExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



+ (NSSet *)_movieFileTypes {
	static NSMutableSet		*extensions;

	if(!extensions) {
		extensions = [[NSMutableSet alloc] init];
		[extensions addObjectsFromArray:[[WCSearchTypeMovieExtensions lowercaseString]
			componentsSeparatedByString:@" "]];
		[extensions addObjectsFromArray:[[WCSearchTypeMovieExtensions uppercaseString]
			componentsSeparatedByString:@" "]];
	}

	return extensions;
}



#pragma mark -

- (void)_validate {
	[_searchButton setEnabled:([_connections count] > 0)];
}



- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [WCSettings themeWithIdentifier:[WCSettings objectForKey:WCTheme]];
	
	[_filesController themeDidChange:theme];
}



- (void)_reloadServersMenu {
	NSEnumerator		*enumerator;
	WCServerConnection	*connection;
	
	while([_serversPopUpButton numberOfItems] > 1)
		[_serversPopUpButton removeItemAtIndex:1];
	
	if([_connections count] > 0) {
		[_serversPopUpButton addItem:[NSMenuItem separatorItem]];
		
		enumerator = [_connections objectEnumerator];
		
		while((connection = [enumerator nextObject]))
			[[_serversPopUpButton menu] addItem:[NSMenuItem itemWithTitle:[connection name] representedObject:connection]];
	}
}

@end



@implementation WCSearch

+ (id)search {
	static WCSearch		*sharedSearch;
	
	if(!sharedSearch)
		sharedSearch = [[self alloc] init];
	
	return sharedSearch;
}



- (id)init {
	self = [super initWithWindowNibName:@"Search"];
	
	_files = [[NSMutableArray alloc] init];
	_receivedFiles = [[NSMutableArray alloc] init];
	_connections = [[NSMutableArray alloc] init];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionLoggedIn:)
			   name:WCLinkConnectionLoggedInNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidClose:)
			   name:WCLinkConnectionDidCloseNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidTerminate:)
			   name:WCLinkConnectionDidTerminateNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(selectedThemeDidChange:)
			   name:WCSelectedThemeDidChangeNotification];

	[self window];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_files release];
	[_receivedFiles release];
	[_connections release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Search"];

	[[_filesController filesTableView] setAutosaveName:@"Search"];
    [[_filesController filesTableView] setAutosaveTableColumns:YES];
	[[_filesController filesTableView] setDoubleAction:@selector(open:)];
	[[_filesController filesTableView] setDefaultTableColumnIdentifiers:
		[NSArray arrayWithObjects:@"Name", @"Server", @"Size", NULL]];

	[_filesController updateStatus];

	[self _themeDidChange];
	[self _validate];
}



- (void)wiredFileSearchListReply:(WIP7Message *)message {
	WCFile		*file;
	BOOL		add;

	if([[message name] isEqualToString:@"wired.file.search_list"]) {
		file = [WCFile fileWithMessage:message connection:[message contextInfo]];
		add = NO;

		switch(_searchType) {
			case WCSearchTypeAny:
				add = YES;
				break;

			case WCSearchTypeFolder:
				if([file type] != WCFileFile)
					add = YES;
				break;

			case WCSearchTypeDocument:
				if([file type] == WCFileFile)
					add = YES;
				break;

			case WCSearchTypeAudio:
				if([[[self class] _audioFileTypes] containsObject:[file extension]])
					add = YES;
				break;

			case WCSearchTypeImage:
				if([[[self class] _imageFileTypes] containsObject:[file extension]])
					add = YES;
				break;

			case WCSearchTypeMovie:
				if([[[self class] _movieFileTypes] containsObject:[file extension]])
					add = YES;
				break;
		}

		if(add) {
			[_receivedFiles addObject:file];

			if([_receivedFiles count] == 10) {
				[_files addObjectsFromArray:_receivedFiles];
				[_receivedFiles removeAllObjects];

				[_filesController setFiles:_files];
				[_filesController showFiles];
			}
		}
	}
	else if([[message name] isEqualToString:@"wired.file.search_list.done"]) {
		if(++_receivedReplies == _searchedConnections) {
			[_progressIndicator stopAnimation:self];
			[_files addObjectsFromArray:_receivedFiles];
			
			[_filesController setFiles:_files];
			[_filesController updateStatus];
			[_filesController showFiles];
		}
	}
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	NSEnumerator			*enumerator;
	WCServerConnection		*connection;
	WCFile					*file;

	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	connection = [notification object];
	enumerator = [_files objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([file belongsToConnection:connection])
			[file setConnection:connection];
	}
	
	[_connections addObject:connection];
	
	[self _validate];
	[self _reloadServersMenu];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	[_connections removeObject:[notification object]];

	[self _validate];
	[self _reloadServersMenu];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	NSEnumerator			*enumerator;
	WCServerConnection		*connection;
	WCFile					*file;
	
	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	connection = [notification object];
	enumerator = [_files objectEnumerator];

	while((file = [enumerator nextObject])) {
		if([file connection] == connection)
			[file setConnection:NULL];
	}

	[_connections removeObject:connection];
	
	[self _validate];
	[self _reloadServersMenu];
}



- (void)selectedThemeDidChange:(NSNotification *)notification {
	[self _themeDidChange];
}



#pragma mark -

- (void)validate {
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	WCServerConnection	*connection;
	WCFile				*file;
	SEL					selector;
	
	selector	= [item action];
	file		= [_filesController selectedFile];
	connection	= [file connection];
	
	if(selector == @selector(download:))
		return ([[connection account] transferDownloadFiles] && [connection isConnected]);
	else if(selector == @selector(getInfo:))
		return (file != NULL && [connection isConnected]);
	else if(selector == @selector(open:))
		return ([file isFolder] && [connection isConnected]);
	else if(selector == @selector(revealInFiles:))
		return (file != NULL && [connection isConnected]);
	
	return [super validateMenuItem:item];
}



#pragma mark -

- (void)showWindow:(id)sender { 
	[[self window] makeFirstResponder:_searchTextField]; 
	
	[super showWindow:sender]; 
} 



#pragma mark -

- (IBAction)search:(id)sender {
	NSEnumerator		*enumerator;
	WCServerConnection	*connection;
	WIP7Message			*message;
	
	if([[_searchTextField stringValue] length] == 0 || [_connections count] == 0)
		return;
	
	_searchType = [[_kindPopUpButton selectedItem] tag];

	[_receivedFiles removeAllObjects];
	[_files removeAllObjects];
	
	[_filesController setFiles:_files];
	[_filesController showFiles];
	[_filesController updateStatus];

	[_progressIndicator startAnimation:self];
	
	if([_serversPopUpButton selectedItem] == _allServersMenuItem) {
		enumerator = [_connections objectEnumerator];
		
		while((connection = [enumerator nextObject])) {
			message = [WIP7Message messageWithName:@"wired.file.search" spec:WCP7Spec];
			[message setString:[_searchTextField stringValue] forName:@"wired.file.query"];
			[connection sendMessage:message fromObserver:self selector:@selector(wiredFileSearchListReply:)];
		}

		_searchedConnections = [_connections count];
	} else {
		connection = [[_serversPopUpButton selectedItem] representedObject];
		
		message = [WIP7Message messageWithName:@"wired.file.search" spec:WCP7Spec];
		[message setString:[_searchTextField stringValue] forName:@"wired.file.query"];
		[connection sendMessage:message fromObserver:self selector:@selector(wiredFileSearchListReply:)];
		
		_searchedConnections = 1;
	}

	_receivedReplies = 0;
}



- (IBAction)open:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;
	
	enumerator = [[_filesController selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject])) {
		if([[file connection] isConnected]) {
			if([file isFolder])
				[WCFiles filesWithConnection:[file connection] path:file];
			else
				[[WCTransfers transfers] downloadFile:file];
		}
	}
}



- (IBAction)download:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;

	enumerator = [[_filesController selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject]))
		[[WCTransfers transfers] downloadFile:file];
}



- (IBAction)getInfo:(id)sender {
	NSEnumerator			*enumerator;
	NSMutableDictionary		*dictionary;
	NSMutableArray			*array;
	NSMutableSet			*connections;
	WCServerConnection		*connection;
	WCFile					*file;
	
	dictionary = [NSMutableDictionary dictionary];
	connections = [NSMutableSet set];
	connection = NULL;
	enumerator = [[_filesController selectedFiles] objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		connection = [file connection];
		array = [dictionary objectForKey:[connection uniqueIdentifier]];
		
		if(!array) {
			array = [NSMutableArray array];
			[dictionary setObject:array forKey:[connection uniqueIdentifier]];
		}
		
		[array addObject:file];
		[connections addObject:connection];
	}
	
	enumerator = [connections objectEnumerator];
	
	while((connection = [enumerator nextObject]))
		[WCFileInfo fileInfoWithConnection:connection files:[dictionary objectForKey:[connection uniqueIdentifier]]];
}



- (IBAction)revealInFiles:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file, *parentFile;

	enumerator = [[_filesController selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject])) {
		parentFile = [WCFile fileWithDirectory:[[file path] stringByDeletingLastPathComponent] connection:[file connection]];
		
		[WCFiles filesWithConnection:[file connection] path:parentFile selectPath:[file path]];
	}
}

@end
