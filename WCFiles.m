/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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
#import "WCAccountsController.h"
#import "WCAdministration.h"
#import "WCErrorQueue.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCPublicChatController.h"
#import "WCTransfers.h"

#define WCFilesFiles						@"WCFilesFiles"
#define WCFilesDirectories					@"WCFilesDirectories"
#define WCFilesReceivedFiles				@"WCFilesReceivedFiles"

#define WCFilesQuickLookTextExtensions		@"c cc cgi conf css diff h in java log m patch pem php pl plist pod rb rtf s sh status strings tcl text txt xml"
#define WCFilesQuickLookHTMLExtensions		@"htm html shtm shtml svg"
#define WCFilesQuickLookImageExtensions		@"bmp eps jpg jpeg tif tiff gif pct pict pdf png"


NSString * const							WCFilePboardType = @"WCFilePboardType";
NSString * const							WCPlacePboardType = @"WCPlacePboardType";


@interface WCFiles(Private)

- (id)_initFilesWithConnection:(WCServerConnection *)connection file:(WCFile *)file selectFile:(WCFile *)selectFile;

- (void)_themeDidChange;

- (void)_validate;
- (void)_validatePermissions;

- (BOOL)_canPreviewFile:(WCFile *)file;

- (WCFile *)_selectedSource;
- (WCServerConnection *)_selectedConnection;
- (NSArray *)_selectedFiles;

- (NSMutableDictionary *)_filesForConnection:(WCServerConnection *)connection;
- (NSMutableDictionary *)_directoriesForConnection:(WCServerConnection *)connection;
- (WCFile *)_existingFileForFile:(WCFile *)file;
- (WCFile *)_existingParentFileForFile:(WCFile *)file;
- (void)_removeDirectoryAtPath:(NSString *)path connection:(WCServerConnection *)connection;
- (NSMutableArray *)_receivedFilesForConnection:(WCServerConnection *)connection message:(WIP7Message *)message;
- (void)_removeReceivedFilesForConnection:(WCServerConnection *)connection message:(WIP7Message *)message;

- (BOOL)_existingDirectoryTreeIsWritableForFile:(WCFile *)file;
- (BOOL)_existingDirectoryTreeIsReadableForFile:(WCFile *)file;

- (void)_addConnections;
- (void)_addConnection:(WCServerConnection *)connection;
- (void)_addPlaces;
- (void)_revalidatePlacesForConnection:(WCServerConnection *)connection;
- (void)_invalidatePlacesForConnection:(WCServerConnection *)connection;
- (void)_revalidateFiles:(NSArray *)files;

- (NSUInteger)_selectedStyle;
- (void)_selectStyle:(NSUInteger)style;

- (void)_changeCurrentDirectory:(WCFile *)file reselectFiles:(BOOL)reselectFiles;
- (void)_loadFilesAtDirectory:(WCFile *)file reselectFiles:(BOOL)reselectFiles;
- (void)_reloadFilesAtDirectory:(WCFile *)file;
- (void)_reloadFilesAtDirectory:(WCFile *)file reselectFiles:(BOOL)reselectFiles;
- (void)_subscribeToDirectory:(WCFile *)file;
- (void)_unsubscribeFromDirectory:(WCFile *)file;

- (void)_openFile:(WCFile *)file overrideNewWindow:(BOOL)override;
- (void)_reloadStatus;
- (void)_reselectFiles;
- (void)_sortFiles;
- (SEL)_sortSelector;

@end


@implementation WCFiles(Private)

- (id)_initFilesWithConnection:(WCServerConnection *)connection file:(WCFile *)file selectFile:(WCFile *)selectFile {
	NSUInteger		i;
	
	self = [super initWithWindowNibName:@"Files"];

	_files				= [[NSMutableDictionary alloc] init];
	_servers			= [[NSMutableArray alloc] init];
	_places				= [[NSMutableArray alloc] init];
	_initialDirectory	= [file retain];
	_quickLookFiles		= [[NSMutableArray alloc] init];
	_selectFiles		= [[NSMutableArray alloc] init];
	
	if(selectFile) {
		[_selectFiles addObject:selectFile];
		
		_selectFilesWhenOpening = YES;
	}
	
	[_files setObject:[NSDictionary dictionaryWithObjectsAndKeys:
							[NSMutableDictionary dictionary],
								WCFilesFiles,
							[NSMutableDictionary dictionary],
								WCFilesDirectories,
							[NSMutableDictionary dictionary],
								WCFilesReceivedFiles,
							NULL]
			   forKey:[connection identifier]];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	_quickLookPanelClass = NSClassFromString(@"QLPreviewPanel");

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(selectedThemeDidChange:)
			   name:WCSelectedThemeDidChangeNotification];

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
		   selector:@selector(serverConnectionServerInfoDidChange:)
			   name:WCServerConnectionServerInfoDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverConnectionPrivilegesDidChange:)
			   name:WCServerConnectionPrivilegesDidChangeNotification];
	
	[self _addPlaces];
	[self _addConnections];

	[[[_files objectForKey:[connection identifier]] objectForKey:WCFilesFiles] setObject:file forKey:[file path]];
	
	[self window];
	
	i = [_servers indexOfObject:connection];
	
	if(i != NSNotFound)
		[_sourceOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:i + 1] byExtendingSelection:NO];
	
	[_filesTreeView setRootPath:[file path]];

	[self showWindow:self];
	[self retain];

	return self;
}



#pragma mark -

- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [WCSettings themeWithIdentifier:[WCSettings objectForKey:WCTheme]];
	
	[_filesOutlineView setUsesAlternatingRowBackgroundColors:[theme boolForKey:WCThemesFileListAlternateRows]];
}



#pragma mark -

- (void)_validate {
	NSEnumerator			*enumerator;
	NSArray					*files;
	WCServerConnection		*connection;
	WCAccount				*account;
	WCFile					*file;
	BOOL					connected, quickLook, writable, readable;
	
	connection	= [self _selectedConnection];
	connected	= [connection isConnected];
	account		= [connection account];
	writable	= [self _existingDirectoryTreeIsWritableForFile:_currentDirectory];
	readable	= [self _existingDirectoryTreeIsReadableForFile:_currentDirectory];
	files		= [self _selectedFiles];

	switch([files count]) {
		case 0:
			[_downloadButton setEnabled:NO];
			[_quickLookButton setEnabled:NO];
			[_infoButton setEnabled:NO];
			[_deleteButton setEnabled:NO];
			break;

		case 1:
			file = [files objectAtIndex:0];

			[_downloadButton setEnabled:([account transferDownloadFiles] && connected)];
			[_deleteButton setEnabled:(([account fileDeleteFiles] || writable) && connected)];
			[_infoButton setEnabled:([account fileGetInfo] && connected)];
			[_quickLookButton setEnabled:([account transferDownloadFiles] &&
										  connected &&
										  [self _canPreviewFile:file])];
			break;

		default:
			[_downloadButton setEnabled:([account transferDownloadFiles] && connected)];
			
			quickLook = ([account transferDownloadFiles] && connected);
			
			if(quickLook) {
				enumerator = [files objectEnumerator];
				
				while((file = [enumerator nextObject])) {
					if(![self _canPreviewFile:file]) {
						quickLook = NO;
						
						break;
					}
				}
			}
			
			[_quickLookButton setEnabled:quickLook];
			[_deleteButton setEnabled:(([account fileDeleteFiles] || writable) && connected)];
			[_infoButton setEnabled:(([account fileGetInfo] || readable) && connected)];
			break;
	}

	[[_historyControl cell] setEnabled:NO forSegment:0];
	[[_historyControl cell] setEnabled:NO forSegment:1];
//	[[_historyControl cell] setEnabled:(_type == WCFilesStyleList && _historyPosition > 0 && connected) forSegment:0];
//	[[_historyControl cell] setEnabled:(_type == WCFilesStyleList && _historyPosition + 1 < [_history count] && connected) forSegment:1];

//	[_uploadButton setEnabled:([self _validateUpload] && connected)];
	[_uploadButton setEnabled:YES];
	[_createFolderButton setEnabled:(([account fileCreateDirectories] || writable) && connected)];
	[_reloadButton setEnabled:connected];
}



- (void)_validatePermissions {
	BOOL			setPermissions, dropBox;
	
	setPermissions	= [[[self _selectedConnection] account] fileSetPermissions];
	dropBox			= ([_typePopUpButton tagOfSelectedItem] == WCFileDropBox);
	
	[_ownerPopUpButton setEnabled:(dropBox && setPermissions)];
	[_ownerPermissionsPopUpButton setEnabled:(dropBox && setPermissions)];
	[_groupPopUpButton setEnabled:(dropBox && setPermissions)];
	[_groupPermissionsPopUpButton setEnabled:(dropBox && setPermissions)];
	[_everyonePermissionsPopUpButton setEnabled:(dropBox && setPermissions)];
}



#pragma mark -

- (BOOL)_canPreviewFile:(WCFile *)file {
	if([file isFolder])
		return NO;
	
	if(!_quickLookPanelClass)
		return NO;
	
	if([file totalSize] > 250 * 1024)
		return NO;
	
	return YES;
}



#pragma mark -

- (WCFile *)_selectedSource {
	id			item;
	
	item = [_sourceOutlineView itemAtRow:[_sourceOutlineView selectedRow]];
	
	if([item isKindOfClass:[WCFile class]]) {
		return item;
	}
	else if([item isKindOfClass:[NSString class]]) {
		return [WCFile fileWithRootDirectoryForConnection:
			[[[WCPublicChat publicChat] chatControllerForConnectionIdentifier:item] connection]];
	}
	
	return NULL;
}



- (WCServerConnection *)_selectedConnection {
	id			item;
	
	item = [_sourceOutlineView itemAtRow:[_sourceOutlineView selectedRow]];
	
	if([item isKindOfClass:[WCFile class]])
		return [(WCFile *) item connection];
	else if([item isKindOfClass:[NSString class]])
		return [[[WCPublicChat publicChat] chatControllerForConnectionIdentifier:item] connection];
	
	return NULL;
}



- (NSArray *)_selectedFiles {
	NSEnumerator			*enumerator;
	NSMutableDictionary		*files;
	NSMutableArray			*selectedFiles;
	NSIndexSet				*indexes;
	NSString				*path;
	WCFile					*file;
	NSUInteger				index;
	
	selectedFiles = [NSMutableArray array];
	
	if([self _selectedStyle] == WCFilesStyleList) {
		indexes		= [_filesOutlineView selectedRowIndexes];
		index		= [indexes firstIndex];
		
		while(index != NSNotFound) {
			[selectedFiles addObject:[_filesOutlineView itemAtRow:index]];
			
			index = [indexes indexGreaterThanIndex:index];
		}
	} else {
		files		= [self _filesForConnection:[self _selectedConnection]];
		enumerator	= [[_filesTreeView selectedPaths] objectEnumerator];
		
		while((path = [enumerator nextObject])) {
			file = [files objectForKey:path];
			
			if(file)
				[selectedFiles addObject:file];
		}
	}
	
	return selectedFiles;
}



#pragma mark -

- (NSMutableDictionary *)_filesForConnection:(WCServerConnection *)connection {
	return [[_files objectForKey:[connection identifier]] objectForKey:WCFilesFiles];
}



- (NSMutableDictionary *)_directoriesForConnection:(WCServerConnection *)connection {
	return [[_files objectForKey:[connection identifier]] objectForKey:WCFilesDirectories];
}



- (WCFile *)_existingFileForFile:(WCFile *)file {
	WCFile		*existingFile;
	
	existingFile = [[self _filesForConnection:[file connection]] objectForKey:[file path]];
	
	return existingFile ? existingFile : file;
}



- (WCFile *)_existingParentFileForFile:(WCFile *)file {
	if(!file || [[file path] isEqualToString:@"/"])
		return NULL;
	
	return [self _existingFileForFile:[WCFile fileWithDirectory:[[file path] stringByDeletingLastPathComponent]
													 connection:[file connection]]];
}



- (void)_removeDirectoryAtPath:(NSString *)path connection:(WCServerConnection *)connection {
	NSMutableDictionary		*directories;
	
	directories = [self _directoriesForConnection:connection];
	
	[directories removeObjectForKey:path];
}



- (NSMutableArray *)_receivedFilesForConnection:(WCServerConnection *)connection message:(WIP7Message *)message {
	NSMutableArray			*receivedFiles;
	NSNumber				*messageID;
	
	messageID		= [message numberForName:@"wired.transaction"];
	receivedFiles	= [[[_files objectForKey:[connection identifier]] objectForKey:WCFilesReceivedFiles] objectForKey:messageID];
	
	if(!receivedFiles) {
		receivedFiles = [NSMutableArray array];

		[[[_files objectForKey:[connection identifier]] objectForKey:WCFilesReceivedFiles] setObject:receivedFiles forKey:messageID];
	}
	
	return receivedFiles;
}



- (void)_removeReceivedFilesForConnection:(WCServerConnection *)connection message:(WIP7Message *)message {
	NSNumber		*messageID;

	messageID = [message numberForName:@"wired.transaction"];

	[[[_files objectForKey:[connection identifier]] objectForKey:WCFilesReceivedFiles] removeObjectForKey:messageID];
}



#pragma mark -

- (BOOL)_existingDirectoryTreeIsWritableForFile:(WCFile *)file {
	WCFile		*parentFile;
	
	parentFile = file;
	
	do {
		if([parentFile isWritable])
			return YES;
	} while((parentFile = [self _existingParentFileForFile:parentFile]));
	
	return NO;
}



- (BOOL)_existingDirectoryTreeIsReadableForFile:(WCFile *)file {
	WCFile		*parentFile;
	
	parentFile = file;
	
	do {
		if([parentFile isReadable])
			return YES;
	} while((parentFile = [self _existingParentFileForFile:parentFile]));
	
	return NO;
}



#pragma mark -

- (void)_addConnections {
	NSEnumerator				*enumerator;
	WCPublicChatController		*chatController;
	WCServerConnection			*connection;
	
	enumerator = [[[WCPublicChat publicChat] chatControllers] objectEnumerator];
	
	while((chatController = [enumerator nextObject])) {
		connection = [chatController connection];
		
		[self _addConnection:connection];
		[self _revalidatePlacesForConnection:connection];
		
		[_servers addObject:connection];
	}
	
	[_sourceOutlineView reloadData];
}



- (void)_addConnection:(WCServerConnection *)connection {
	[connection addObserver:self selector:@selector(wiredFileDirectoryChanged:) messageName:@"wired.file.directory_changed"];
}



- (void)_addPlaces {
	NSData		*data;
	
	data = [WCSettings objectForKey:WCPlaces];
	
	if(data)
		[_places addObjectsFromArray:[NSKeyedUnarchiver unarchiveObjectWithData:data]];
}



- (void)_revalidatePlacesForConnection:(WCServerConnection *)connection {
	NSEnumerator		*enumerator;
	WCFile				*place;

	enumerator = [_places objectEnumerator];
	
	while((place = [enumerator nextObject])) {
		if([place belongsToConnection:connection])
			[place setConnection:connection];
	}
}



- (void)_invalidatePlacesForConnection:(WCServerConnection *)connection {
	NSEnumerator		*enumerator;
	WCFile				*place;

	enumerator = [_places objectEnumerator];
	
	while((place = [enumerator nextObject])) {
		if([place connection] == connection)
			[place setConnection:NULL];
	}
}



- (void)_revalidateFiles:(NSArray *)files {
	NSEnumerator			*enumerator;
	WCFile					*file;
	WCServerConnection		*connection;
	NSUInteger				i, count;
	
	enumerator = [files objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		count = [_servers count];
		
		for(i = 0; i < count; i++) {
			connection = [_servers objectAtIndex:i];
			
			if([file belongsToConnection:connection])
				[file setConnection:connection];
		}
	}
}



#pragma mark -

- (NSUInteger)_selectedStyle {
	return [[_styleControl cell] tagForSegment:[_styleControl selectedSegment]];
}



- (void)_selectStyle:(NSUInteger)style {
	if(style == WCFilesStyleList) {
		[_filesTabView selectTabViewItemWithIdentifier:@"List"];
		[[self window] makeFirstResponder:_filesOutlineView];
	} else {
		[_filesTabView selectTabViewItemWithIdentifier:@"Tree"];

		if(_currentDirectory)
			[_filesTreeView selectPath:[_currentDirectory path]];
	}
}



#pragma mark -

- (void)_changeCurrentDirectory:(WCFile *)file reselectFiles:(BOOL)reselectFiles {
	if(_initialDirectory) {
		file = [[_initialDirectory retain] autorelease];
		
		[_initialDirectory release];
		_initialDirectory = NULL;
	}
	
	file = [self _existingFileForFile:file];
	
	if(!file)
		return;
	
	if(_currentDirectory) {
		if([file isEqual:_currentDirectory])
			return;
	
		[self _unsubscribeFromDirectory:_currentDirectory];
	}
	
	[file retain];
	[_currentDirectory release];
	
	_currentDirectory = file;
	
	[[self window] setTitle:NSLS(@"Files", @"Files window title") withSubtitle:[_currentDirectory path]];
	
	[_filesTreeView selectPath:[_currentDirectory path]];

	[self _loadFilesAtDirectory:file
				  reselectFiles:_selectFilesWhenOpening ? _selectFilesWhenOpening : reselectFiles];
	[self _subscribeToDirectory:_currentDirectory];
	
	[self _validate];
}



- (void)_loadFilesAtDirectory:(WCFile *)file reselectFiles:(BOOL)reselectFiles {
	NSMutableArray			*directory;
	WCServerConnection		*connection;
	
	connection		= [file connection];
	directory		= [[self _directoriesForConnection:connection] objectForKey:[file path]];
	
	if(directory) {
		if([_selectFiles count] == 0)
			[_selectFiles setArray:[self _selectedFiles]];
		
		[_filesOutlineView reloadData];
		[_filesTreeView reloadData];
		
		[self _reloadStatus];
		
		if(reselectFiles)
			[self _reselectFiles];
		else
			[_selectFiles removeAllObjects];
	} else {
		[self _reloadFilesAtDirectory:file reselectFiles:reselectFiles];
	}
	
	_selectFilesWhenOpening = NO;
}



- (void)_reloadFilesAtDirectory:(WCFile *)file {
	[self _reloadFilesAtDirectory:file reselectFiles:YES];
}



- (void)_reloadFilesAtDirectory:(WCFile *)file reselectFiles:(BOOL)reselectFiles {
	NSMutableDictionary		*files, *directories;
	NSMutableArray			*directory;
	WIP7Message				*message;
	WCServerConnection		*connection;
	
	if([_selectFiles count] == 0)
		[_selectFiles setArray:[self _selectedFiles]];
	
	connection		= [file connection];
	directory		= [[self _directoriesForConnection:connection] objectForKey:[file path]];
	
	[directory removeAllObjects];
	
	[_filesTreeView reloadData];
	[_filesOutlineView reloadData];

	[_progressIndicator startAnimation:self];
	
	if(!reselectFiles)
		[_selectFiles removeAllObjects];
	
	files			= [self _filesForConnection:connection];
	directories		= [self _directoriesForConnection:connection];
		
	if(!files || !directories) {
		files			= [[NSMutableDictionary alloc] init];
		directories		= [[NSMutableDictionary alloc] init];

		[_files setObject:[NSDictionary dictionaryWithObjectsAndKeys: files, WCFilesFiles, directories, WCFilesDirectories, NULL]
				   forKey:[connection identifier]];

		[directories release];
		[files release];
	}
		
	directory = [directories objectForKey:[file path]];
		
	if(!directory) {
		directory = [[NSMutableArray alloc] init];
		[directories setObject:directory forKey:[file path]];
		[directory release];
	}
	
	message = [WIP7Message messageWithName:@"wired.file.list_directory" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[connection sendMessage:message fromObserver:self selector:@selector(wiredFileListPathReply:)];
}



- (void)_subscribeToDirectory:(WCFile *)file {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.file.subscribe_directory" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[[file connection] sendMessage:message fromObserver:self selector:@selector(wiredFileSubscribeDirectoryReply:)];
}



- (void)_unsubscribeFromDirectory:(WCFile *)file {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.file.unsubscribe_directory" spec:WCP7Spec];
	[message setString:[file path] forName:@"wired.file.path"];
	[[file connection] sendMessage:message fromObserver:self selector:@selector(wiredFileUnsubscribeDirectoryReply:)];
}



#pragma mark -

- (void)_openFile:(WCFile *)file overrideNewWindow:(BOOL)override {
	BOOL	optionKey, newWindows;

	optionKey = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	newWindows = [WCSettings boolForKey:WCOpenFoldersInNewWindows];

	switch([file type]) {
		case WCFileDirectory:
		case WCFileUploads:
		case WCFileDropBox:
			if(override || (newWindows && !optionKey) || (!newWindows && optionKey))
				[WCFiles filesWithConnection:[file connection] file:file];
			else
				[self _changeCurrentDirectory:file reselectFiles:YES];
			break;

		case WCFileFile:
			[[WCTransfers transfers] downloadFile:file];
			break;
	}
}



- (void)_reloadStatus {
	NSEnumerator			*enumerator;
	NSMutableArray			*directory;
	WCFile					*file;
	WIFileOffset			size = 0;

	directory		= [[self _directoriesForConnection:[_currentDirectory connection]] objectForKey:[_currentDirectory path]];
	enumerator		= [directory objectEnumerator];

	while((file = [enumerator nextObject]))
		if([file type] == WCFileFile)
			size += [file totalSize];

	[_statusTextField setStringValue:[NSSWF:
		NSLS(@"%lu %@, %@ total, %@ available", @"Files info (count, 'item(s)', size, available)"),
		[directory count],
		[directory count] == 1
			? NSLS(@"item", @"Item singular")
			: NSLS(@"items", @"Item plural"),
		[NSString humanReadableStringForSizeInBytes:size],
		[NSString humanReadableStringForSizeInBytes:[_currentDirectory freeSpace]]]];
}



- (void)_reselectFiles {
	NSEnumerator			*enumerator;
	NSMutableArray			*directory;
	NSMutableIndexSet		*indexes;
	WCFile					*file;
	NSUInteger				index;
	
	if([_selectFiles count] > 0) {
		directory		= [[self _directoriesForConnection:[self _selectedConnection]] objectForKey:[_currentDirectory path]];
		indexes			= [NSMutableIndexSet indexSet];
		enumerator		= [_selectFiles objectEnumerator];
		
		while((file = [enumerator nextObject])) {
			index = [directory indexOfObject:file];
			
			if(index != NSNotFound)
				[indexes addIndex:index];
		}
		
		if([indexes count] > 0) {
			[_filesOutlineView selectRowIndexes:indexes byExtendingSelection:NO];
			[_filesOutlineView scrollRowToVisible:[indexes firstIndex]];
		}
		
		[_filesTreeView selectPath:[[_selectFiles objectAtIndex:0] path]];
		
		[_selectFiles removeAllObjects];
	}
}



- (void)_sortFiles {
	NSEnumerator			*enumerator;
	NSMutableArray			*directory;
	WISortOrder				sortOrder;
	SEL						selector;

	selector		= [self _sortSelector];
	sortOrder		= [_filesOutlineView sortOrder];
	enumerator		= [[self _directoriesForConnection:[self _selectedConnection]] objectEnumerator];
	
	while((directory = [enumerator nextObject])) {
		[directory sortUsingSelector:selector];
		
		if(sortOrder == WISortDescending)
			[directory reverse];
	}
}



- (SEL)_sortSelector {
	NSTableColumn		*tableColumn;

	tableColumn = [_filesOutlineView highlightedTableColumn];
	
	if(tableColumn == _nameTableColumn)
		return @selector(compareName:);
	else if(tableColumn == _kindTableColumn)
		return @selector(compareKind:);
	else if(tableColumn == _createdTableColumn)
		return @selector(compareCreationDate:);
	else if(tableColumn == _modifiedTableColumn)
		return @selector(compareModificationDate:);
	else if(tableColumn == _sizeTableColumn)
		return @selector(compareSize:);
	
	return @selector(compareName:);
}

@end



@implementation WCFiles

+ (id)filesWithConnection:(WCServerConnection *)connection file:(WCFile *)file {
	return [[[self alloc] _initFilesWithConnection:connection file:file selectFile:NULL] autorelease];
}



+ (id)filesWithConnection:(WCServerConnection *)connection file:(WCFile *)file selectFile:(WCFile *)selectFile {
	return [[[self alloc] _initFilesWithConnection:connection file:file selectFile:selectFile] autorelease];
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_errorQueue release];
	
	[_files release];
	[_servers release];
	[_places release];
	[_quickLookFiles release];
	[_selectFiles release];
	[_initialDirectory release];
	
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSInvocation		*invocation;
	NSUInteger			style;

	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Files"];

	_errorQueue = [[WCErrorQueue alloc] initWithWindow:[self window]];
	
	if([_sourceOutlineView respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
		style = 1; // NSTableViewSelectionHighlightStyleSourceList
		
		invocation = [NSInvocation invocationWithTarget:_sourceOutlineView action:@selector(setSelectionHighlightStyle:)];
		[invocation setArgument:&style atIndex:2];
		[invocation invoke];
	}
	
	[_sourceOutlineView registerForDraggedTypes:[NSArray arrayWithObjects:WCFilePboardType, WCPlacePboardType, NSFilenamesPboardType, NULL]];
	[_sourceOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	[_sourceOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];

	[_filesOutlineView setTarget:self];
	[_filesOutlineView setDoubleAction:@selector(open:)];
	[_filesOutlineView setEscapeAction:@selector(deselectAll:)];
	[_filesOutlineView setSpaceAction:@selector(quickLook:)];
	[_filesOutlineView setAllowsUserCustomization:YES];
	[_filesOutlineView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[_filesOutlineView setDefaultTableColumnIdentifiers:
		[NSArray arrayWithObjects:@"Name", @"Size", NULL]];
	[_filesOutlineView setAutosaveName:@"Files"];
    [_filesOutlineView setAutosaveTableColumns:YES];
	[_filesOutlineView registerForDraggedTypes:[NSArray arrayWithObjects:WCFilePboardType, NSFilenamesPboardType, NULL]];
	[_filesOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	[_filesOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	
	[_filesTreeView setTarget:self];
	[_filesTreeView setDoubleAction:@selector(open:)];
	[_filesTreeView setSpaceAction:@selector(quickLook:)];
	[_filesTreeView registerForDraggedTypes:[NSArray arrayWithObjects:WCFilePboardType, NSFilenamesPboardType, NULL]];
	[_filesTreeView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	[_filesTreeView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];

	[_styleControl selectSegmentWithTag:[WCSettings integerForKey:WCFilesStyle]];
	
	[self _selectStyle:[self _selectedStyle]];
	[self _reloadStatus];
	[self _themeDidChange];
	[self _validate];
	
	[_sourceOutlineView reloadData];
	[_filesOutlineView reloadData];
	[_filesTreeView reloadData];

	[_sourceOutlineView expandItem:[NSNumber numberWithInteger:0]];
	[_sourceOutlineView expandItem:[NSNumber numberWithInteger:1]];
}



- (void)selectedThemeDidChange:(NSNotification *)notification {
	[self _themeDidChange];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;
	
	[self _revalidatePlacesForConnection:connection];
	
	if(![connection isReconnecting]) {
		[_servers addObject:connection];
		
		[_sourceOutlineView reloadData];
	}

	[self _addConnection:connection];
	[self _validate];
	[self _subscribeToDirectory:_currentDirectory];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;
	
	[self _invalidatePlacesForConnection:connection];
	
	[connection removeObserver:self];
	
	[self _validate];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	WCServerConnection		*connection;

	connection = [notification object];

	if(![connection isKindOfClass:[WCServerConnection class]])
		return;
	
	[self _invalidatePlacesForConnection:connection];

	[_servers removeObject:connection];
	[_sourceOutlineView reloadData];
	
	[connection removeObserver:self];
	
	[self _validate];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[_sourceOutlineView reloadData];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _validate];
}



- (void)wiredFileDirectoryChanged:(WIP7Message *)message {
	if([[message stringForName:@"wired.file.path"] isEqualToString:[_currentDirectory path]])
		[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:_currentDirectory afterDelay:0.1];
}



- (void)wiredFileListPathReply:(WIP7Message *)message {
	NSEnumerator			*enumerator;
	NSMutableDictionary		*files;
	NSMutableArray			*receivedFiles, *directory;
	NSString				*path;
	WCServerConnection		*connection;
	WCFile					*file, *receivedFile;
	WIP7UInt64				free;
	
	connection = [message contextInfo];

	if([[message name] isEqualToString:@"wired.file.file_list"]) {
		file			= [WCFile fileWithMessage:message connection:connection];
		receivedFiles	= [self _receivedFilesForConnection:connection message:message];
		
		[receivedFiles addObject:file];
	}
	else if([[message name] isEqualToString:@"wired.file.file_list.done"]) {
		[_progressIndicator stopAnimation:self];
		
		path			= [message stringForName:@"wired.file.path"];
		files			= [self _filesForConnection:connection];
		file			= [files objectForKey:path];
		directory		= [[self _directoriesForConnection:connection] objectForKey:path];
		receivedFiles	= [self _receivedFilesForConnection:connection message:message];
		enumerator		= [receivedFiles objectEnumerator];
		
		[directory removeAllObjects];
		
		while((receivedFile = [enumerator nextObject])) {
			[files setObject:receivedFile forKey:[receivedFile path]];
			[directory addObject:receivedFile];
		}
		
		[self _removeReceivedFilesForConnection:connection message:message];
		
		[directory sortUsingSelector:[self _sortSelector]];
		
		if([_filesOutlineView sortOrder] == WISortDescending)
			[directory reverse];

		[_filesOutlineView reloadData];
		[_filesTreeView reloadData];
		
		[message getUInt64:&free forName:@"wired.file.available"];
		
		[file setFreeSpace:free];
		
		[self _reloadStatus];
		[self _reselectFiles];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_progressIndicator stopAnimation:self];
		
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
	}
}



- (void)wiredFileSubscribeDirectoryReply:(WIP7Message *)message {
	WCServerConnection		*connection;
	WCError					*error;
	
	connection = [message contextInfo];
	
	if([[message name] isEqualToString:@"wired.okay"]) {
		[connection removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		error = [WCError errorWithWiredMessage:message];
		
		if([error code] != WCWiredProtocolAlreadySubscribed)
			[_errorQueue showError:error];
		
		[connection removeObserver:self message:message];
	}
}



- (void)wiredFileUnsubscribeDirectoryReply:(WIP7Message *)message {
	WCServerConnection		*connection;
	
	connection = [message contextInfo];
	
	if([[message name] isEqualToString:@"wired.okay"]) {
		[connection removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[connection removeObserver:self message:message];
	}
}



- (void)wiredFileCreateDirectoryReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredFileDeleteReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredFileMoveReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];

		[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:_currentDirectory afterDelay:0.1];
	}
}



- (void)wiredFileLinkReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredFilePreviewFileReply:(WIP7Message *)message {
	NSEnumerator			*enumerator;
	NSString				*path;
	NSURL					*url;
	WCServerConnection		*connection;
	WCFile					*file;
	id						quickLookPanel;
	
	connection = [message contextInfo];
	
	if([[message name] isEqualToString:@"wired.file.preview"]) {
		path			= [message stringForName:@"wired.file.path"];
		enumerator		= [_quickLookFiles objectEnumerator];
		
		while((file = [enumerator nextObject])) {
			if([[file path] isEqualToString:path]) {
				url = [NSURL fileURLWithPath:[NSFileManager temporaryPathWithFilename:[path lastPathComponent]]];
				
				[[message dataForName:@"wired.file.preview"] writeToURL:url atomically:YES];
				
				[file setPreviewItemURL:url];
				
				break;
			}
		}
		
		if(file) {
			quickLookPanel = [_quickLookPanelClass performSelector:@selector(sharedPreviewPanel)];
			
			if([quickLookPanel respondsToSelector:@selector(refreshCurrentPreviewItem)])
				[quickLookPanel performSelector:@selector(refreshCurrentPreviewItem)];
		}
		
		[connection removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[connection removeObserver:self message:message];
	}
}



- (void)controlTextDidChange:(NSNotification *)notification {
	NSControl		*control;
	WCFileType		type;
	
	control = [notification object];
	
	if(control == _nameTextField) {
		type = [WCFile folderTypeForString:[_nameTextField stringValue]];
		
		if(type != WCFileDirectory) {
			[_typePopUpButton selectItemWithTag:type];
			
			[self _validatePermissions];
		}
	}
}



#pragma mark -

- (IBAction)open:(id)sender {
	NSEnumerator	*enumerator;
	NSArray			*files;
	WCFile			*file;
	NSUInteger		style;
	
	if([_filesOutlineView clickedHeader])
		return;

	style		= [self _selectedStyle];
	files		= [self _selectedFiles];
	enumerator	= [files objectEnumerator];
	
	while((file = [enumerator nextObject]))
		[self _openFile:file overrideNewWindow:(style == WCFilesStyleTree || [files count] > 1)];
}



- (IBAction)deselectAll:(id)sender {
	[_filesOutlineView deselectAll:self];
}



- (IBAction)enclosingFolder:(id)sender {
	WCFile		*file;
	
	if(![[_currentDirectory path] isEqualToString:@"/"]) {
		[_selectFiles addObject:_currentDirectory];
		
		file = [self _existingParentFileForFile:_currentDirectory];
		
		[self _openFile:file overrideNewWindow:([self _selectedStyle] == WCFilesStyleTree)];
	}
}



#pragma mark -

- (IBAction)history:(id)sender {
}



- (IBAction)style:(id)sender {
	NSUInteger		style;
	
	style = [self _selectedStyle];
	
	[self _selectStyle:style];
	[self _loadFilesAtDirectory:_currentDirectory reselectFiles:NO];
	
	[WCSettings setInteger:style forKey:WCFilesStyle];
}



- (IBAction)download:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;

	enumerator = [[self _selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject]))
		[[WCTransfers transfers] downloadFile:file];
}



- (IBAction)upload:(id)sender {
	NSOpenPanel		*openPanel;

	openPanel = [NSOpenPanel openPanel];

	[openPanel setCanChooseDirectories:[[[self _selectedConnection] account] transferUploadDirectories]];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];

	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:NULL
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(uploadOpenPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)uploadOpenPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void  *)contextInfo {
	NSEnumerator	*enumerator;
	NSArray			*files;
	NSString		*path;

	if(returnCode == NSOKButton) {
		files = [openPanel filenames];
		enumerator = [[files sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];

		while((path = [enumerator nextObject]))
			[[WCTransfers transfers] uploadPath:path toFolder:_currentDirectory];
	}
}



- (IBAction)getInfo:(id)sender {
	NSEnumerator		*enumerator;
	NSArray				*files;
	WCFile				*file;
	
	files = [self _selectedFiles];
	
	if([[NSApp currentEvent] alternateKeyModifier]) {
		enumerator = [files objectEnumerator];
		
		while((file = [enumerator nextObject]))
			[WCFileInfo fileInfoWithConnection:[file connection] file:file];
	} else {
		file = [files objectAtIndex:0];
		
		[WCFileInfo fileInfoWithConnection:[file connection] files:files];
	}
}



- (IBAction)quickLook:(id)sender {
	NSEnumerator	*enumerator;
	WIP7Message		*message;
	WCFile			*file;
	id				quickLookPanel;
	
	if(![_quickLookButton isEnabled] || !_quickLookPanelClass)
		return;
	
	[_quickLookFiles removeAllObjects];

	enumerator = [[self _selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject])) {
		if(![file previewItemURL]) {
			message = [WIP7Message messageWithName:@"wired.file.preview_file" spec:WCP7Spec];
			[message setString:[file path] forName:@"wired.file.path"];
			[[file connection] sendMessage:message fromObserver:self selector:@selector(wiredFilePreviewFileReply:)];
		}

		[_quickLookFiles addObject:file];
	}

	quickLookPanel = [_quickLookPanelClass performSelector:@selector(sharedPreviewPanel)];
	
	if([quickLookPanel isVisible])
		[quickLookPanel orderOut:self];
	else
		[quickLookPanel makeKeyAndOrderFront:self];

	if([quickLookPanel respondsToSelector:@selector(reloadData)])
		[quickLookPanel reloadData];
}



- (IBAction)createFolder:(id)sender {
	NSEnumerator		*enumerator;
	NSArray				*array;
	NSMenuItem			*item;
	WCServerConnection	*connection;
	
	connection = [self _selectedConnection];
	
	if(![[_typePopUpButton lastItem] image]) {
		enumerator = [[_typePopUpButton itemArray] objectEnumerator];
		
		while((item = [enumerator nextObject]))
			[item setImage:[WCFile iconForFolderType:[item tag] width:16.0]];
	}
	
	[_nameTextField setStringValue:NSLS(@"Untitled", @"New folder name")];
	[_nameTextField selectText:self];
	[_typePopUpButton selectItemWithTag:WCFileDirectory];
	
	[self _validatePermissions];
	
	[_ownerPopUpButton removeAllItems];
	[_ownerPopUpButton addItem:[NSMenuItem itemWithTitle:NSLS(@"None", @"Create folder owner popup title") tag:1]];
	
	array = [[[connection administration] accountsController] userNames];
	
	if([array count] > 0) {
		[_ownerPopUpButton addItem:[NSMenuItem separatorItem]];
		[_ownerPopUpButton addItemsWithTitles:array];
		[_ownerPopUpButton selectItemWithTitle:[[connection URL] user]];
	}
	
	[_ownerPermissionsPopUpButton selectItemWithTag:WCFileOwnerRead | WCFileOwnerWrite];
	
	[_groupPopUpButton removeAllItems];
	[_groupPopUpButton addItem:[NSMenuItem itemWithTitle:NSLS(@"None", @"Create folder group popup title") tag:1]];
	
	array = [[[connection administration] accountsController] groupNames];
	
	if([array count] > 0) {
		[_groupPopUpButton addItem:[NSMenuItem separatorItem]];
		[_groupPopUpButton addItemsWithTitles:array];
	}
	
	[_groupPopUpButton selectItemAtIndex:0];
	[_groupPermissionsPopUpButton selectItemWithTag:0];

	[_everyonePermissionsPopUpButton selectItemWithTag:WCFileEveryoneWrite];
	
	[NSApp beginSheet:_createFolderPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(createFolderSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)createFolderSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*path, *owner, *group;
	WIP7Message		*message;
	NSUInteger		ownerPermissions, groupPermissions, everyonePermissions;
	WCFileType		type;

	[_createFolderPanel close];

	if(returnCode == NSAlertDefaultReturn) {
		path = [[_currentDirectory path] stringByAppendingPathComponent:[_nameTextField stringValue]];
		
		message = [WIP7Message messageWithName:@"wired.file.create_directory" spec:WCP7Spec];
		[message setString:path forName:@"wired.file.path"];
		
		type = [_typePopUpButton tagOfSelectedItem];

		if(type != WCFileDirectory)
			[message setEnum:type forName:@"wired.file.type"];
		
		if(type == WCFileDropBox) {
			owner					= ([_ownerPopUpButton tagOfSelectedItem] == 0) ? [_ownerPopUpButton titleOfSelectedItem] : @"";
			ownerPermissions		= [_ownerPermissionsPopUpButton tagOfSelectedItem];
			group					= ([_groupPopUpButton tagOfSelectedItem] == 0) ? [_groupPopUpButton titleOfSelectedItem] : @"";
			groupPermissions		= [_groupPermissionsPopUpButton tagOfSelectedItem];
			everyonePermissions		= [_everyonePermissionsPopUpButton tagOfSelectedItem];
			
			[message setString:owner forName:@"wired.file.owner"];
			[message setBool:(ownerPermissions & WCFileOwnerRead) forName:@"wired.file.owner.read"];
			[message setBool:(ownerPermissions & WCFileOwnerWrite) forName:@"wired.file.owner.write"];
			[message setString:group forName:@"wired.file.group"];
			[message setBool:(groupPermissions & WCFileGroupRead) forName:@"wired.file.group.read"];
			[message setBool:(groupPermissions & WCFileGroupWrite) forName:@"wired.file.group.write"];
			[message setBool:(everyonePermissions & WCFileEveryoneRead) forName:@"wired.file.everyone.read"];
			[message setBool:(everyonePermissions & WCFileEveryoneWrite) forName:@"wired.file.everyone.write"];
		}
		
		[[self _selectedConnection] sendMessage:message fromObserver:self selector:@selector(wiredFileCreateDirectoryReply:)];
	}
}



- (IBAction)type:(id)sender {
	[self _validatePermissions];
}



- (IBAction)reloadFiles:(id)sender {
	[self _reloadFilesAtDirectory:_currentDirectory];
}



- (IBAction)deleteFiles:(id)sender {
	NSAlert			*alert;
	NSArray			*files;
	NSString		*title;
	
	if(![_deleteButton isEnabled])
		return;

	files = [self _selectedFiles];

	if([files count] == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete file dialog title (filename)"),
			[[files objectAtIndex:0] name]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu items?", @"Delete file dialog title (count)"),
			[files count]];
	}

	alert = [[NSAlert alloc] init];
	[alert setMessageText:title];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete file dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete file button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete file button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteSheetDidEnd:returnCode:contextInfo:)
						contextInfo:NULL];
	[alert release];
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	NSArray			*files;
	NSString		*path;
	WIP7Message		*message;
	WCFile			*file;

	if(returnCode == NSAlertFirstButtonReturn) {
		files		= [self _selectedFiles];
		enumerator	= [files objectEnumerator];

		if([self _selectedStyle] == WCFilesStyleTree) {
			file = [files objectAtIndex:0];
			path = [[file path] stringByDeletingLastPathComponent];
			
			[self _changeCurrentDirectory:[WCFile fileWithDirectory:path connection:[file connection]] reselectFiles:YES];
		}

		while((file = [enumerator nextObject])) {
			message = [WIP7Message messageWithName:@"wired.file.delete" spec:WCP7Spec];
			[message setString:[file path] forName:@"wired.file.path"];
			[[file connection] sendMessage:message fromObserver:self selector:@selector(wiredFileDeleteReply:)];
		}
	}
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	NSMutableDictionary		*directories;
	NSMutableArray			*directory;
	
	if(outlineView == _sourceOutlineView) {
		if(!item)
			return 2;
		
		if([item isKindOfClass:[NSNumber class]]) {
			if([item unsignedIntegerValue] == 0)
				return [_servers count];
			else
				return [_places count];
		}
	}
	else if(outlineView == _filesOutlineView) {
		directories = [self _directoriesForConnection:[self _selectedConnection]];
		
		if(!item)
			directory = [directories objectForKey:[_currentDirectory path]];
		else
			directory = [directories objectForKey:[item path]];
		
		return [directory count];
	}
	
	return 0;
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	NSMutableDictionary		*directories;
	NSMutableArray			*directory;
	
	if(outlineView == _sourceOutlineView) {
		if(!item)
			return [NSNumber numberWithInteger:index];
		
		if([item isKindOfClass:[NSNumber class]]) {
			if([item unsignedIntegerValue] == 0)
				return [[_servers objectAtIndex:index] identifier];
			else
				return [_places objectAtIndex:index];
		}
	}
	else if(outlineView == _filesOutlineView) {
		directories = [self _directoriesForConnection:[self _selectedConnection]];
		
		if(!item)
			directory = [directories objectForKey:[_currentDirectory path]];
		else
			directory = [directories objectForKey:[item path]];
		
		return [directory objectAtIndex:index];
	}
	
	return NULL;
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSDictionary			*attributes;
	NSString				*label;
	WCServerConnection		*connection;
	WCFile					*file;
	
	if(outlineView == _sourceOutlineView) {
		if([item isKindOfClass:[NSNumber class]]) {
			if([item unsignedIntegerValue] == 0)
				label = NSLS(@"Servers", @"Files header");
			else
				label = NSLS(@"Places", @"Files header");
			
			attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSColor colorWithCalibratedRed:96.0 / 255.0 green:110.0 / 255.0 blue:128.0 / 255.0 alpha:1.0],
					NSForegroundColorAttributeName,
				[NSFont boldSystemFontOfSize:11.0],
					NSFontAttributeName,
				NULL];
			
			return [NSAttributedString attributedStringWithString:[label uppercaseString] attributes:attributes];
		}
		else if([item isKindOfClass:[WCFile class]]) {
			connection = [(WCFile *) item connection];
			
			if(connection && [connection isConnected]) {
				attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSColor blackColor],
						NSForegroundColorAttributeName,
					[NSFont systemFontOfSize:11.0],
						NSFontAttributeName,
					NULL];
			} else {
				attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					[NSColor colorWithCalibratedRed:96.0 / 255.0 green:110.0 / 255.0 blue:128.0 / 255.0 alpha:1.0],
						NSForegroundColorAttributeName,
					[NSFont systemFontOfSize:11.0],
						NSFontAttributeName,
					NULL];
			}
			
			return [NSAttributedString attributedStringWithString:[item name] attributes:attributes];
		}
		else if([item isKindOfClass:[NSString class]]) {
			connection = [[[WCPublicChat publicChat] chatControllerForConnectionIdentifier:item] connection];
			
			return [connection name];
		}
	}
	else if(outlineView == _filesOutlineView) {
		file = item;
		
		if(tableColumn == _nameTableColumn)
			return [file name];
		else if(tableColumn == _kindTableColumn)
			return [file kind];
		else if(tableColumn == _createdTableColumn)
			return [_dateFormatter stringFromDate:[file creationDate]];
		else if(tableColumn == _modifiedTableColumn)
			return [_dateFormatter stringFromDate:[file modificationDate]];
		else if(tableColumn == _sizeTableColumn)
			return [file humanReadableSize];
		else if(tableColumn == _serverTableColumn)
			return [[file connection] name];
	}

	return NULL;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	if(outlineView == _sourceOutlineView)
		return [item isKindOfClass:[NSNumber class]];
	else if(outlineView == _filesOutlineView)
		return [item isFolder];
	
	return NO;
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(outlineView == _sourceOutlineView) {
		if([item isKindOfClass:[NSNumber class]])
			[cell setImage:NULL];
		else if([item isKindOfClass:[WCFile class]])
			[cell setImage:[item iconWithWidth:16.0]];
		else if([item isKindOfClass:[NSString class]])
			[cell setImage:NULL];
		
		[cell setVerticalTextOffset:3.0];
	}
	else if(outlineView == _filesOutlineView) {
		if(tableColumn == _nameTableColumn)
			[cell setImage:[item iconWithWidth:16.0]];
	}
}



- (NSColor *)outlineView:(NSOutlineView *)outlineView labelColorByItem:(id)item {
	if(outlineView == _filesOutlineView)
		return [item labelColor];
	
	return NULL;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	if(outlineView == _sourceOutlineView) {
		if([item isKindOfClass:[NSNumber class]])
			return NO;
		
		if([item isKindOfClass:[WCFile class]])
			return ([(WCFile *) item connection] != NULL && [[(WCFile *) item connection] isConnected]);
	}
	
	return YES;
}



- (void)outlineViewItemDidExpand:(NSNotification *)notification {
	WCFile		*file;
	
	if([notification object] == _filesOutlineView) {
		file = [[notification userInfo] objectForKey:@"NSObject"];
		
		[self _loadFilesAtDirectory:file reselectFiles:NO];
	}
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	NSOutlineView		*outlineView;
	
	outlineView = [notification object];
	
	if(outlineView == _sourceOutlineView)
		[self _changeCurrentDirectory:[self _selectedSource] reselectFiles:NO];
	else if(outlineView == _filesOutlineView)
		[self _validate];
}



- (void)outlineView:(NSOutlineView *)outlineView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_filesOutlineView setHighlightedTableColumn:tableColumn];
	[self _sortFiles];
	[_filesOutlineView reloadData];
	
	[self _validate];
}



- (NSString *)outlineView:(NSOutlineView *)outlineView stringValueByItem:(id)item {
	if(outlineView == _filesOutlineView)
		return [(WCFile *) item name];
	
	return NULL;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	NSEnumerator		*enumerator;
	WCFile				*file;
	id					item;
	
	enumerator = [items objectEnumerator];

	if(outlineView == _sourceOutlineView) {
		while((item = [enumerator nextObject])) {
			if(![item isKindOfClass:[WCFile class]])
				return NO;
		}
		
		[pasteboard declareTypes:[NSArray arrayWithObject:WCPlacePboardType] owner:NULL];
		[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:items] forType:WCPlacePboardType];
		
		return YES;
	}
	else if(outlineView == _filesOutlineView) {
		while((file = [enumerator nextObject])) {
			if(![file connection] || ![[file connection] isConnected])
				return NO;
		}
		
		[pasteboard declareTypes:[NSArray arrayWithObjects:WCFilePboardType, NSFilesPromisePboardType, NULL] owner:NULL];
		[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:items] forType:WCFilePboardType];
	    [pasteboard setPropertyList:[NSArray arrayWithObject:NSFileTypeForHFSTypeCode('\0\0\0\0')] forType:NSFilesPromisePboardType];
		
		return YES;
	}
	
	return NO;
}



- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
	NSEnumerator		*enumerator;
	NSPasteboard		*pasteboard;
	NSEvent				*event;
	NSArray				*types, *sources;
	WCFile				*sourceFile, *destinationFile;
	BOOL				copy, link;

	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	event		= [NSApp currentEvent];
	link		= ([event alternateKeyModifier] && [event commandKeyModifier]);

	if(outlineView == _sourceOutlineView) {
		if([types containsObject:WCFilePboardType]) {
			if(!item)
				return NSDragOperationNone;
			
			sources		= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
			enumerator	= [sources reverseObjectEnumerator];
			
			if([item isKindOfClass:[NSNumber class]]) {
				if([item unsignedIntegerValue] != 0) {
					while((sourceFile = [enumerator nextObject])) {
						if(![sourceFile isFolder])
							return NSDragOperationNone;
					}
					
					return NSDragOperationCopy;
				}
			}
			else if([item isKindOfClass:[NSString class]] || [item isKindOfClass:[WCFile class]]) {
				if([item isKindOfClass:[NSString class]]) {
					destinationFile = [WCFile fileWithRootDirectoryForConnection:
						[[[WCPublicChat publicChat] chatControllerForConnectionIdentifier:item] connection]];
				} else {
					destinationFile = item;
				}
				
				if(![destinationFile connection] || ![[destinationFile connection] isConnected])
					return NSDragOperationNone;
				
				copy = NO;
				
				while((sourceFile = [enumerator nextObject])) {
					if([sourceFile connection] == [destinationFile connection])
						return NSDragOperationNone;
					
					if([sourceFile volume] != [destinationFile volume])
						copy = YES;
				
					if([[[sourceFile path] stringByDeletingLastPathComponent] isEqualToString:[destinationFile path]])
						return NSDragOperationNone;
				}
				
				if(link)
					return NSDragOperationLink;
				else if(copy)
					return NSDragOperationCopy;
				else
					return NSDragOperationMove;
			}

			return NSDragOperationNone;
		}
		else if([types containsObject:WCPlacePboardType]) {
			if([item isKindOfClass:[NSNumber class]] && [item unsignedIntegerValue] == 1 && index >= 0) {
				[_sourceOutlineView setDropRow:-1 dropOperation:NSDragOperationMove];
				
				return NSDragOperationMove;
			}
			
			return NSDragOperationNone;
		}
		else if([types containsObject:NSFilenamesPboardType]) {
			return NSDragOperationCopy;
		}
	}
	else if(outlineView == _filesOutlineView) {
		destinationFile = item ? item : _currentDirectory;
		
		if(index >= 0) {
			destinationFile = _currentDirectory;
			
			[_filesOutlineView setDropItem:NULL dropChildIndex:NSOutlineViewDropOnItemIndex];
		}
		
		if(![destinationFile isFolder]) {
			destinationFile = [self _existingParentFileForFile:destinationFile];
			
			if(destinationFile == _currentDirectory)
				[_filesOutlineView setDropItem:NULL dropChildIndex:NSOutlineViewDropOnItemIndex];
			else
				[_filesOutlineView setDropItem:destinationFile dropChildIndex:NSOutlineViewDropOnItemIndex];
		}
		
		if([types containsObject:WCFilePboardType]) {
			sources		= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
			enumerator	= [sources reverseObjectEnumerator];
			copy		= NO;
			
			while((sourceFile = [enumerator nextObject])) {
				if([sourceFile connection] == [destinationFile connection])
					return NSDragOperationNone;
				
				if([sourceFile volume] != [destinationFile volume])
					copy = YES;
				
				if([[[sourceFile path] stringByDeletingLastPathComponent] isEqualToString:[destinationFile path]])
					return NSDragOperationNone;
			}
			
			if(link)
				return NSDragOperationLink;
			else if(copy)
				return NSDragOperationCopy;
			else
				return NSDragOperationMove;
		}
		else if([types containsObject:NSFilenamesPboardType]) {
			return NSDragOperationCopy;
		}
	}
	
	return NSDragOperationNone;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	NSPasteboard		*pasteboard;
	NSEnumerator		*enumerator;
	NSEvent				*event;
	NSArray				*types, *sources;
	NSString			*destinationPath, *sourcePath;
	WIP7Message			*message;
	WCFile				*sourceFile, *destinationFile, *parentFile;
	NSUInteger			oldIndex;
	BOOL				link;
	
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	event		= [NSApp currentEvent];
	link		= ([event alternateKeyModifier] && [event commandKeyModifier]);
	
	if(outlineView == _sourceOutlineView) {
		if([types containsObject:WCFilePboardType]) {
			sources		= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
			enumerator	= [sources reverseObjectEnumerator];
			
			if([item isKindOfClass:[NSNumber class]]) {
				[self _revalidateFiles:sources];
				
				while((sourceFile = [enumerator nextObject])) {
					if([sourceFile isFolder])
						[_places insertObject:sourceFile atIndex:index];
				}
				
				[WCSettings setObject:[NSKeyedArchiver archivedDataWithRootObject:_places] forKey:WCPlaces];
			}
			else if([item isKindOfClass:[NSString class]] || [item isKindOfClass:[WCFile class]]) {
				if([item isKindOfClass:[NSString class]]) {
					destinationFile = [WCFile fileWithRootDirectoryForConnection:
						[[[WCPublicChat publicChat] chatControllerForConnectionIdentifier:item] connection]];
				} else {
					destinationFile = item;
				}

				destinationPath = [destinationFile path];
				
				[self _revalidateFiles:sources];
				
				if(!link) {
					[self _removeDirectoryAtPath:destinationPath connection:[destinationFile connection]];
					[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:destinationFile afterDelay:0.1];
				}
				
				while((sourceFile = [enumerator nextObject])) {
					parentFile = [self _existingParentFileForFile:sourceFile];
					
					[self _removeDirectoryAtPath:[parentFile path] connection:[parentFile connection]];
					[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:parentFile afterDelay:0.1];
					
					message = [WIP7Message messageWithName:link ? @"wired.file.link" : @"wired.file.move" spec:WCP7Spec];
					[message setString:[sourceFile path] forName:@"wired.file.path"];
					[message setString:[destinationPath stringByAppendingPathComponent:[sourceFile name]] forName:@"wired.file.new_path"];
					[[destinationFile connection] sendMessage:message fromObserver:self selector:@selector(wiredFileMoveReply:)];
				}
				
				[_filesOutlineView reloadData];
			}
			
			[_sourceOutlineView reloadData];
			
			return YES;
		}
		else if([types containsObject:WCPlacePboardType]) {
			sources		= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCPlacePboardType]];
			enumerator	= [sources reverseObjectEnumerator];
			
			while((sourceFile = [enumerator nextObject])) {
				oldIndex = [_places indexOfObject:sourceFile];
				
				[_places moveObjectAtIndex:oldIndex toIndex:index];
			}
			
			[_sourceOutlineView reloadData];
			
			[self _revalidateFiles:sources];
			
			return YES;
		}
		else if([types containsObject:NSFilenamesPboardType]) {
			return NO;
		}
	}
	else if(outlineView == _filesOutlineView) {
		destinationFile = item ? item : _currentDirectory;
		destinationPath = [destinationFile path];

		if([types containsObject:WCFilePboardType]) {
			sources			= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
			enumerator		= [sources reverseObjectEnumerator];
			
			[self _revalidateFiles:sources];

			if(!link) {
				[self _removeDirectoryAtPath:destinationPath connection:[destinationFile connection]];
				[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:destinationFile afterDelay:0.1];
			}
			
			while((sourceFile = [enumerator nextObject])) {
				parentFile = [self _existingParentFileForFile:sourceFile];
				
				[self _removeDirectoryAtPath:[parentFile path] connection:[parentFile connection]];
				[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:parentFile afterDelay:0.1];
				
				message = [WIP7Message messageWithName:link ? @"wired.file.link" : @"wired.file.move" spec:WCP7Spec];
				[message setString:[sourceFile path] forName:@"wired.file.path"];
				[message setString:[destinationPath stringByAppendingPathComponent:[sourceFile name]] forName:@"wired.file.new_path"];
				[[destinationFile connection] sendMessage:message fromObserver:self selector:@selector(wiredFileMoveReply:)];
			}
				
			[_filesOutlineView reloadData];
			
			return YES;
		}
		else if([types containsObject:NSFilenamesPboardType]) {
			sources			= [pasteboard propertyListForType:NSFilenamesPboardType];
			enumerator		= [[sources sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];
			
			while((sourcePath = [enumerator nextObject])) {
				if(![[WCTransfers transfers] uploadPath:sourcePath toFolder:destinationFile])
					return NO;
			}
			
			return YES;
		}
	}
	
	return NO;
}


- (void)outlineView:(NSOutlineView *)outlineView removeItems:(NSArray *)items {
	NSEnumerator		*enumerator;
	id					item;
	NSUInteger			index;
	
	if(outlineView == _sourceOutlineView) {
		[self _revalidateFiles:items];
		
		enumerator = [items objectEnumerator];
		
		while((item = [enumerator nextObject])) {
			index = [_places indexOfObject:item];
			
			if(index != NSNotFound)
				[_places removeObjectAtIndex:index];
		}
		
		[WCSettings setObject:[NSKeyedArchiver archivedDataWithRootObject:_places] forKey:WCPlaces];

		[_sourceOutlineView reloadData];
	}
}



- (void)outlineViewShouldCopyInfo:(NSOutlineView *)outlineView {
	NSEnumerator		*enumerator;
	NSMutableString		*string;
	NSPasteboard		*pasteboard;
	WCFile				*file;
	
	string			= [NSMutableString string];
	enumerator		= [[self _selectedFiles] objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([string length] > 0)
			[string appendString:@"\n"];
		
		[string appendString:[file name]];
	}
	
	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, WCFilePboardType, NULL] owner:NULL];
	[pasteboard setString:string forType:NSStringPboardType];
}



- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedItems:(NSArray *)items {
	NSEnumerator		*enumerator;
	NSMutableArray		*names;
	WCFile				*file;
	
	names		= [NSMutableArray array];
	enumerator	= [items objectEnumerator];
	
	while((file = [enumerator nextObject])) {
		if([[WCTransfers transfers] downloadFile:file toFolder:[destination path]])
			[names addObject:[file name]];
	}
	
	return names;
}



#pragma mark -

- (NSUInteger)treeView:(WITreeView *)tree numberOfItemsForPath:(NSString *)path {
	NSMutableArray		*directory;
	
	directory = [[self _directoriesForConnection:[self _selectedConnection]] objectForKey:path];
	
	return [directory count];
}



- (NSString *)treeView:(WITreeView *)tree nameForRow:(NSUInteger)row inPath:(NSString *)path {
	NSMutableArray		*directory;
	WCFile				*file;
	
	directory	= [[self _directoriesForConnection:[self _selectedConnection]] objectForKey:path];
	file		= [directory objectAtIndex:row];
	
	return [file name];
}



- (BOOL)treeView:(WITreeView *)tree isPathExpandable:(NSString *)path {
	WCFile			*file;
	
	file = [[self _filesForConnection:[self _selectedConnection]] objectForKey:path];
	
	return [file isFolder];
}



- (NSDictionary *)treeView:(WITreeView *)tree attributesForPath:(NSString *)path {
	WCFile			*file;
	
	file = [[self _filesForConnection:[self _selectedConnection]] objectForKey:path];

	return [NSDictionary dictionaryWithObjectsAndKeys:
		[file iconWithWidth:128.0],								WIFileIcon,
		[NSNumber numberWithUnsignedLongLong:[file totalSize]],	WIFileSize,
		[file kind],											WIFileKind,
		[file creationDate],									WIFileCreationDate,
		[file modificationDate],								WIFileModificationDate,
		NULL];
}



- (void)treeView:(WITreeView *)tree changedPath:(NSString *)path {
	WCFile			*file;
	
	if([self _selectedStyle] == WCFilesStyleTree) {
		file = [[self _filesForConnection:[self _selectedConnection]] objectForKey:path];
		
		if(![file isFolder]) {
			file = [self _existingFileForFile:[WCFile fileWithDirectory:[[file path] stringByDeletingLastPathComponent]
															 connection:[file connection]]];
		}
		
		[self _changeCurrentDirectory:file reselectFiles:YES];
		[self _validate];
	}
}



- (void)treeView:(WITreeView *)tree willDisplayCell:(id)cell forPath:(NSString *)path {
	WCFile			*file;
	
	file = [[self _filesForConnection:[self _selectedConnection]] objectForKey:path];
	
	[cell setImage:[file iconWithWidth:16.0]];
}



- (NSColor *)treeView:(WITreeView *)treeView labelColorForPath:(NSString *)path {
	WCFile			*file;
	
	file = [[self _filesForConnection:[self _selectedConnection]] objectForKey:path];
	
	return [file labelColor];
}



- (BOOL)treeView:(WITreeView *)treeView writePaths:(NSArray *)paths toPasteboard:(NSPasteboard *)pasteboard {
	NSEnumerator			*enumerator;
	NSMutableDictionary		*files;
	NSMutableArray			*sources;
	NSString				*path;
	WCFile					*file;
	
	files		= [self _filesForConnection:[self _selectedConnection]];
	sources		= [NSMutableArray array];
	enumerator	= [paths objectEnumerator];
	
	while((path = [enumerator nextObject])) {
		file = [files objectForKey:path];
		
		if(!file || ![file connection] || ![[file connection] isConnected])
			return NO;
		
		[sources addObject:file];
	}
	
	[pasteboard declareTypes:[NSArray arrayWithObjects:WCFilePboardType, NSFilesPromisePboardType, NULL] owner:NULL];
	[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:sources] forType:WCFilePboardType];
    [pasteboard setPropertyList:[NSArray arrayWithObject:NSFileTypeForHFSTypeCode('\0\0\0\0')] forType:NSFilesPromisePboardType];
	
	return YES;
}



- (NSDragOperation)treeView:(WITreeView *)treeView validateDrop:(id <NSDraggingInfo>)info proposedPath:(NSString *)path {
	NSPasteboard		*pasteboard;
	NSEnumerator		*enumerator;
	NSEvent				*event;
	NSArray				*types, *sources;
	NSString			*destinationPath;
	WCFile				*sourceFile, *destinationFile;
	BOOL				link, copy;
	
	pasteboard			= [info draggingPasteboard];
	types				= [pasteboard types];
	event				= [NSApp currentEvent];
	destinationPath		= path;
	link				= ([event alternateKeyModifier] && [event commandKeyModifier]);
	
	if([types containsObject:WCFilePboardType]) {
		destinationFile		= [[self _filesForConnection:[self _selectedConnection]] objectForKey:destinationPath];
		sources				= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
		enumerator			= [sources reverseObjectEnumerator];
		
		if(!destinationFile)
			return NSDragOperationNone;
		
		[self _revalidateFiles:sources];

		copy = NO;
		
		while((sourceFile = [enumerator nextObject])) {
			if([sourceFile connection] != [destinationFile connection])
				return NSDragOperationNone;
			
			if([sourceFile volume] != [destinationFile volume])
				copy = YES;
			
			if([[[sourceFile path] stringByDeletingLastPathComponent] isEqualToString:[destinationFile path]])
				return NSDragOperationNone;
		}
		
		if(link)
			return NSDragOperationLink;
		else if(copy)
			return NSDragOperationCopy;
		else
			return NSDragOperationMove;
	}
	else if([types containsObject:NSFilenamesPboardType]) {
		return NSDragOperationCopy;
	}

	return NSDragOperationNone;
}




- (BOOL)treeView:(WITreeView *)treeView acceptDrop:(id <NSDraggingInfo>)info path:(NSString *)path {
	NSPasteboard		*pasteboard;
	NSEnumerator		*enumerator;
	NSEvent				*event;
	NSArray				*types, *sources;
	NSString			*destinationPath, *sourcePath;
	WIP7Message			*message;
	WCFile				*sourceFile, *destinationFile, *parentFile;
	BOOL				link;
	
	pasteboard			= [info draggingPasteboard];
	types				= [pasteboard types];
	event				= [NSApp currentEvent];
	destinationPath		= path;
	destinationFile		= [[self _filesForConnection:[self _selectedConnection]] objectForKey:destinationPath];
	link				= ([event alternateKeyModifier] && [event commandKeyModifier]);

	if([types containsObject:WCFilePboardType]) {
		sources			= [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
		enumerator		= [sources reverseObjectEnumerator];
		
		if(!destinationFile)
			return NO;
		
		[self _revalidateFiles:sources];
		
		if(!link) {
			[self _removeDirectoryAtPath:destinationPath connection:[destinationFile connection]];
			[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:destinationFile afterDelay:0.1];
		}
		
		while((sourceFile = [enumerator nextObject])) {
			parentFile = [self _existingParentFileForFile:sourceFile];
			
			[self _removeDirectoryAtPath:[parentFile path] connection:[destinationFile connection]];
			[self performSelectorOnce:@selector(_reloadFilesAtDirectory:) withObject:parentFile afterDelay:0.1];
			
			message = [WIP7Message messageWithName:link ? @"wired.file.link" : @"wired.file.move" spec:WCP7Spec];
			[message setString:[sourceFile path] forName:@"wired.file.path"];
			[message setString:[destinationPath stringByAppendingPathComponent:[sourceFile name]] forName:@"wired.file.new_path"];
			[[destinationFile connection] sendMessage:message fromObserver:self selector:@selector(wiredFileMoveReply:)];
		}
		
		[_filesTreeView reloadData];
		
		return YES;
	}
	else if([types containsObject:NSFilenamesPboardType]) {
		sources			= [pasteboard propertyListForType:NSFilenamesPboardType];
		enumerator		= [[sources sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];
		
		while((sourcePath = [enumerator nextObject])) {
			if(![[WCTransfers transfers] uploadPath:sourcePath toFolder:destinationFile])
				return NO;
		}
		
		return YES;
	}
	
	return NO;
}



- (void)treeViewShouldCopyInfo:(WITreeView *)treeView {
	[self performSelector:@selector(outlineViewShouldCopyInfo:) withObject:NULL];
}



- (NSArray *)treeView:(WITreeView *)treeView namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedPaths:(NSArray *)paths {
	NSEnumerator			*enumerator;
	NSMutableDictionary		*files;
	NSMutableArray			*names;
	NSString				*path;
	WCFile					*file;
	
	files		= [self _filesForConnection:[self _selectedConnection]];
	names		= [NSMutableArray array];
	enumerator	= [paths objectEnumerator];
	
	while((path = [enumerator nextObject])) {
		file = [files objectForKey:path];
		
		if(!file || ![file connection] || ![[file connection] isConnected])
			continue;
		
		if([[WCTransfers transfers] downloadFile:file toFolder:[destination path]])
			[names addObject:[file name]];
	}
	
	return names;
}



#pragma mark -

- (BOOL)acceptsPreviewPanelControl:(id /*QLPreviewPanel **/)panel {
    return YES;
}



- (void)beginPreviewPanelControl:(id /*QLPreviewPanel **/)panel {
    [panel setDelegate:self];
    [panel setDataSource:self];
}



- (void)endPreviewPanelControl:(id /*QLPreviewPanel **/) panel {
}



- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id /*QLPreviewPanel **/)panel {
	return [_quickLookFiles count];
}



- (id /*id <QLPreviewItem>*/)previewPanel:(id /*QLPreviewPanel **/)panel previewItemAtIndex:(NSInteger)index {
	return [_quickLookFiles objectAtIndex:index];
}



- (NSRect)previewPanel:(id /*QLPreviewPanel **/)panel sourceFrameOnScreenForPreviewItem:(id /*id <QLPreviewItem>*/)item {
	NSMutableArray	*directory;
	NSRect			frame;
	NSUInteger		index;
	NSInteger		row;
	
	if([self _selectedStyle] == WCFilesStyleList) {
		row = [_filesOutlineView rowForItem:item];
		
		if(row >= 0) {
			frame				= [_filesOutlineView convertRect:[_filesOutlineView frameOfCellAtColumn:0 row:row] toView:NULL];
			frame.origin		= [[self window] convertBaseToScreen:frame.origin];

			return NSMakeRect(frame.origin.x, frame.origin.y, frame.size.height, frame.size.height);
		}
	} else {
		directory = [[self _directoriesForConnection:[(WCFile *) item connection]]
			objectForKey:[[item path] stringByDeletingLastPathComponent]];
		
		if(directory) {
			index = [directory indexOfObject:item];
			
			if(index != NSNotFound) {
				frame			= [_filesTreeView convertRect:[_filesTreeView frameOfRow:index inPath:[item path]] toView:NULL];
				frame.origin	= [[self window] convertBaseToScreen:frame.origin];

				return NSMakeRect(frame.origin.x, frame.origin.y, frame.size.height, frame.size.height);
			}
		}
	}

	return NSZeroRect;
}

@end
