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
#import "WCCache.h"
#import "WCFile.h"
#import "WCFileInfo.h"
#import "WCFiles.h"
#import "WCFilesController.h"
#import "WCFilesBrowserCell.h"
#import "WCPreferences.h"
#import "WCPreview.h"
#import "WCServerConnection.h"
#import "WCTransfers.h"

@interface WCFiles(Private)

- (id)_initFilesWithConnection:(WCServerConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath;

- (void)_setCurrentPath:(WCFile *)path;
- (WCFile *)_currentPath;
- (void)_setSelectPath:(NSString *)path;
- (NSString *)_selectPath;
- (WCFile *)_selectedFile;
- (NSArray *)_selectedFiles;

- (void)_update;
- (void)_updateStatus;
- (void)_updateMenu;
- (void)_updateFiles;
- (void)_sortFiles;
- (void)_showList;
- (void)_showBrowser;
- (void)_makeFirstResponder;
- (void)_setDirectory:(WCFile *)path;
- (void)_changeDirectory:(WCFile *)path;
- (void)_openFile:(WCFile *)file overrideNewWindow:(BOOL)override;
- (void)_reloadFiles;
- (void)_subscribe;
- (void)_unsubscribe;

- (NSDragOperation)_validateDrop:(id <NSDraggingInfo>)info inPath:(WCFile *)path onFile:(WCFile *)file dropOperation:(NSTableViewDropOperation)dropOperation;
- (BOOL)_acceptDrop:(id <NSDraggingInfo>)info inDestination:(WCFile *)destination;

- (BOOL)_validateUpload;

@end


@implementation WCFiles(Private)

- (id)_initFilesWithConnection:(WCServerConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath {
	self = [super initWithWindowNibName:@"Files" connection:connection singleton:NO];

	_type			= [WCSettings integerForKey:WCFilesStyle];
	_rootPath		= [path retain];
	_listPath		= [path retain];
	_browserPath	= [path retain];
	_history		= [[NSMutableArray alloc] init];
	_allFiles		= [[NSMutableDictionary alloc] init];
	_browserFiles	= [[NSMutableDictionary alloc] init];
	
	[_history addObject:_listPath];
	
	[self _setSelectPath:selectPath];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChangeNotification];

	[[self connection] addObserver:self selector:@selector(wiredFileDirectoryChanged:) messageName:@"wired.file.directory_changed"];

	[self window];
	[self _update];
	[self showWindow:self];

	return self;
}



#pragma mark -

- (void)_setCurrentPath:(WCFile *)path {
	[path retain];
	
	if(_type == WCFilesStyleList) {
		[_listPath release];
		_listPath = path;
	}
	else if(_type == WCFilesStyleBrowser) {
		[_browserPath release];
		_browserPath = path;
	}
}



- (WCFile *)_currentPath {
	if(_type == WCFilesStyleList)
		return _listPath;
	else if(_type == WCFilesStyleBrowser)
		return _browserPath;
	
	return NULL;
}



- (void)_setSelectPath:(NSString *)path {
	[path retain];
	[_selectPath release];
	
	_selectPath = path;
}



- (NSString *)_selectPath {
	return _selectPath;
}



- (WCFile *)_selectedFile {
	if(_type == WCFilesStyleList)
		return [_filesController selectedFile];
	else if(_type == WCFilesStyleBrowser)
		return [[_filesBrowser selectedCell] representedObject];
	
	return NULL;
}



- (NSArray *)_selectedFiles {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	id					cell;

	if(_type == WCFilesStyleList) {
		return [_filesController selectedFiles];
	}
	else if(_type == WCFilesStyleBrowser) {
		array = [NSMutableArray array];
		enumerator = [[_filesBrowser selectedCells] objectEnumerator];
		
		while((cell = [enumerator nextObject]))
			[array addObject:[cell representedObject]];
		
		return array;
	}
	
	return NULL;
}


#pragma mark -

- (void)_update {
	[_filesBrowser setNeedsDisplay:YES];
	
	[_filesController update];
}



- (void)_updateStatus {
	if([self _validateUpload])
		[_filesController updateStatusWithFree:[[self _currentPath] free]];
	else
		[_filesController updateStatus];
}



- (void)_updateMenu {
	NSMutableArray	*components;
	NSString		*path;
	NSMenuItem		*item;
	NSUInteger		i, count, items;

	components = [NSMutableArray array];
	path = [[self _currentPath] path];

	while([path length] > 0) {
		[components addObject:path];

		if([path isEqualToString:@"/"])
			break;

		path = [path stringByDeletingLastPathComponent];
	}

	count = [components count];
	items = [_titleBarMenu numberOfItems];

	for(i = 0; i < count; i++) {
		if(i < items) {
			if([[[_titleBarMenu itemAtIndex:i] title] isEqualToString:[components objectAtIndex:i]]) {
				continue;
			} else {
				[_titleBarMenu removeItemAtIndex:i];
				items--;
			}
		}

		item = [[NSMenuItem alloc] initWithTitle:[[components objectAtIndex:i] lastPathComponent]
										  action:@selector(openMenuItem:)
								   keyEquivalent:@""];
		[item setRepresentedObject:[components objectAtIndex:i]];
		[item setImage:[NSImage imageNamed:@"Folder16"]];

		[_titleBarMenu insertItem:item atIndex:i];
		items++;
		[item release];
	}

	while(items > count) {
		[_titleBarMenu removeItemAtIndex:count];

		items--;
	}
}



- (void)_updateFiles {
	[self _sortFiles];
	[self _updateStatus];

	[_filesController showFiles];

	[_filesBrowser reloadColumn:[_filesBrowser lastColumn]];
	[[_filesBrowser matrixInColumn:[_filesBrowser lastColumn]] setMenu:[_filesBrowser menu]];

	if([self _selectPath])
		[_filesController selectFileWithName:[[self _selectPath] lastPathComponent]];
	
	[_progressIndicator stopAnimation:self];
	
	[self _makeFirstResponder];
}



- (void)_sortFiles {
	[_filesController sortFiles];
	
	[[_browserFiles objectForKey:[[self _currentPath] path]] sortUsingSelector:@selector(compareName:)];
}



- (void)_showList {
	_type = WCFilesStyleList;

	[[_filesController filesTableView] sizeToFit];
	[_filesTabView selectTabViewItemWithIdentifier:@"List"];
	
	if(_listPath)
		[self _changeDirectory:_listPath];
	
	[self validate];

	[WCSettings setInt:_type forKey:WCFilesStyle];

	[self _makeFirstResponder];
}



- (void)_showBrowser {
	_type = WCFilesStyleBrowser;

	[_filesTabView selectTabViewItemWithIdentifier:@"Browser"];
	
	if(_browserPath)
		[self _changeDirectory:_browserPath];
	
	[self validate];

	[WCSettings setInt:_type forKey:WCFilesStyle];

	[self _makeFirstResponder];
}



- (void)_makeFirstResponder {
	NSInteger		column;
	
	switch(_type) {
		case WCFilesStyleList:
			[[self window] makeFirstResponder:[_filesController filesTableView]];
			break;
			
		case WCFilesStyleBrowser:
			column = [_filesBrowser selectedColumn];
			
			if(column < 0)
				column = [_filesBrowser lastColumn];
				
			[[self window] makeFirstResponder:[_filesBrowser matrixInColumn:column]];
			break;
	}
}



- (void)_setDirectory:(WCFile *)path {
	[self _setCurrentPath:path];

	[self validate];
	[self _updateStatus];

	[self _updateMenu];
	
	[[self window] setTitle:[[self _currentPath] path] withSubtitle:[[self connection] name]];
}



- (void)_changeDirectory:(WCFile *)file {
	NSArray				*files;
	WIP7Message			*message;
	WIFileOffset		free;
	
	[_allFiles removeAllObjects];
	[_browserFiles removeObjectForKey:[file path]];
	
	[_filesController setFiles:[NSArray array]];
	[_filesController showFiles];
	
	[_filesBrowser reloadColumn:[_filesBrowser lastColumn]];
	
	[self _updateStatus];
	
	[_progressIndicator startAnimation:self];

	if(_subscribed)
		[self _unsubscribe];
	
	[self _setDirectory:file];
	
	if((files = [[[self connection] cache] filesForPath:[file path] free:&free])) {
		[_filesController setFiles:files];
		[_browserFiles setObject:[[files mutableCopy] autorelease] forKey:[file path]];
		
		[file setFree:free];
		
		[self _updateFiles];
	} else {
		message = [WIP7Message messageWithName:@"wired.file.list_directory" spec:WCP7Spec];
		[message setString:[file path] forName:@"wired.file.path"];
		[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredFileListPathReply:)];
	}

	[self _subscribe];
	
	_subscribed = YES;
}



- (void)_openFile:(WCFile *)file overrideNewWindow:(BOOL)override {
	BOOL	optionKey, newWindows;

	optionKey = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
	newWindows = [WCSettings boolForKey:WCOpenFoldersInNewWindows];

	switch([file type]) {
		case WCFileDirectory:
		case WCFileUploads:
		case WCFileDropBox:
			if(override || (newWindows && !optionKey) || (!newWindows && optionKey)) {
				[WCFiles filesWithConnection:[self connection] path:file];
			} else {
				if(![[self _currentPath] isEqual:file]) {
					[_history removeObjectsInRange:
						NSMakeRange(_historyPosition + 1, [_history count] - _historyPosition - 1)];

					[_history addObject:file];
					_historyPosition = [_history count] - 1;
					
					[self _setSelectPath:NULL];
					[self _changeDirectory:file];
					[self validate];
				}
			}
			break;

		case WCFileFile:
			[[WCTransfers transfers] downloadFile:file];
			break;
	}
}



- (void)_reloadFiles {
	[self _setSelectPath:[[self _selectedFile] path]];
	
	[[[self connection] cache] removeFilesForPath:[[self _currentPath] path]];
	
	[self _changeDirectory:[self _currentPath]];
	[self validate];
}



- (void)_subscribe {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.file.subscribe_directory" spec:WCP7Spec];
	[message setString:[[self _currentPath] path] forName:@"wired.file.path"];
	[[self connection] sendMessage:message];
}



- (void)_unsubscribe {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.file.unsubscribe_directory" spec:WCP7Spec];
	[message setString:[[self _currentPath] path] forName:@"wired.file.path"];
	[[self connection] sendMessage:message];
}



#pragma mark -

- (NSDragOperation)_validateDrop:(id <NSDraggingInfo>)info inPath:(WCFile *)path onFile:(WCFile *)file dropOperation:(NSTableViewDropOperation)dropOperation {
	NSPasteboard		*pasteboard;
	NSArray				*types;
	NSEvent				*event;
	WCFile				*destination;
	NSDragOperation		operation;
	
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	operation	= NSDragOperationNone;
	destination	= file ? file : path;
	event		= [NSApp currentEvent];
	
	if([types containsObject:NSFilenamesPboardType]) {
		if(![[[self connection] account] transferUploadFiles])
			return NSDragOperationNone;

		if((file && [file isFolder] && ![file isUploadsFolder]) || (!file && ![path isUploadsFolder])) {
			if(![[[self connection] account] transferUploadAnywhere])
				return NSDragOperationNone;
		}
		
		if(file && [file isUploadsFolder] && dropOperation == NSTableViewDropAbove) {
			if(![path isUploadsFolder]) {
				if(![[[self connection] account] transferUploadAnywhere])
					return NSDragOperationNone;
			}
		}
		
		operation = NSDragOperationCopy;
	}
	else if([types containsObject:WCFilePboardType]) {
		if([event alternateKeyModifier] && [event commandKeyModifier]) {
			if(![[[self connection] account] fileCreateLinks])
				return NSDragOperationNone;
			
			operation = NSDragOperationLink;
		} else {
			if(![[[self connection] account] fileMoveFiles])
				return NSDragOperationNone;
			
			operation = NSDragOperationMove;
		}
	}
	
	return operation;
}



- (BOOL)_acceptDrop:(id <NSDraggingInfo>)info inDestination:(WCFile *)destination {
	NSEnumerator		*enumerator;
	NSPasteboard		*pasteboard;
	NSEvent				*event;
	NSArray				*types, *sources;
	NSString			*path, *sourceDirectory = NULL, *destinationDirectory = NULL, *destinationPath;
	WIP7Message			*message;
	WCFile				*source;
	BOOL				result = NO;

	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	
	[destination retain];

	if([types containsObject:WCFilePboardType]) {
		sources = [NSKeyedUnarchiver unarchiveObjectWithData:[pasteboard dataForType:WCFilePboardType]];
		enumerator = [sources objectEnumerator];
		
		while((source = [enumerator nextObject])) {
			sourceDirectory = [[source path] stringByDeletingLastPathComponent];
			destinationDirectory = [destination path];
			event = [NSApp currentEvent];

			if([event alternateKeyModifier] && [event commandKeyModifier]) {
				destinationPath = [[destination path] stringByAppendingPathComponent:[source name]];

				if([sourceDirectory isEqualToString:destinationDirectory])
					destinationPath = [destinationPath stringByAppendingString:@" alias"];

				message = [WIP7Message messageWithName:@"wired.file.link" spec:WCP7Spec];
				[message setString:[source path] forName:@"wired.file.path"];
				[message setString:destinationPath forName:@"wired.file.new_path"];
				[[self connection] sendMessage:message];
				
				result = YES;
			} else {
				if(![sourceDirectory isEqualToString:destinationDirectory]) {
					destinationPath = [[destination path] stringByAppendingPathComponent:[source name]];
					
					message = [WIP7Message messageWithName:@"wired.file.move" spec:WCP7Spec];
					[message setString:[source path] forName:@"wired.file.path"];
					[message setString:destinationPath forName:@"wired.file.new_path"];
					[[self connection] sendMessage:message];
					
					result = YES;
				}
			}
		}
	}
	else if([types containsObject:NSFilenamesPboardType]) {
		sources = [pasteboard propertyListForType:NSFilenamesPboardType];
		enumerator = [[sources sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];

		while((path = [enumerator nextObject]))
			[[WCTransfers transfers] uploadPath:path toFolder:destination];

		result = YES;
	}
	
	[destination release];
	
	return result;
}



#pragma mark -

- (BOOL)_validateUpload {
	WCAccount		*account;
	WCFileType		type;
	
	account = [[self connection] account];
	type = [[self _currentPath] type];

	return ([account transferUploadAnywhere] ||
		   ([account transferUploadFiles] && (type == WCFileUploads || type == WCFileDropBox)));
}

@end


@implementation WCFiles

+ (id)filesWithConnection:(WCServerConnection *)connection path:(WCFile *)path {
	return [[[self alloc] _initFilesWithConnection:connection path:path selectPath:NULL] autorelease];
}



+ (id)filesWithConnection:(WCServerConnection *)connection path:(WCFile *)path selectPath:(NSString *)selectPath {
	return [[[self alloc] _initFilesWithConnection:connection path:path selectPath:selectPath] autorelease];
}



- (void)dealloc {
	[_history release];
	[_allFiles release];
	[_browserFiles release];
	
	[_listPath release];
	[_browserPath release];
	[_selectPath release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSArray		*types;
	
	[super windowDidLoad];

	types = [NSArray arrayWithObjects:WCFilePboardType, NSFilenamesPboardType, NULL];

	[_filesBrowser setCellClass:[WCFilesBrowserCell class]];
	[_filesBrowser setMatrixClass:[WIMatrix class]];

	if([_filesBrowser respondsToSelector:@selector(setDraggingSourceOperationMask:forLocal:)]) {
		[(NSTableView *) _filesBrowser setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
		[(NSTableView *) _filesBrowser setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
	}

	[_filesBrowser setTarget:self];
	[_filesBrowser setAction:@selector(browserDidSingleClick:)];
	[_filesBrowser setDoubleAction:@selector(open:)];
	[_filesBrowser setColumnsAutosaveName:@"Files"];
	[_filesBrowser registerForDraggedTypes:types];
	[_filesBrowser loadColumnZero];

	[[_filesController filesTableView] registerForDraggedTypes:types];
	[[_filesController filesTableView] setDoubleAction:@selector(open:)];
	[[_filesController filesTableView] setDeleteAction:@selector(deleteFiles:)];
	[[_filesController filesTableView] setBackAction:@selector(back:)];
	[[_filesController filesTableView] setForwardAction:@selector(forward:)];
	
	[_titleBarMenu removeAllItems];

	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Files"];

	[[self window] setTitle:[[self _currentPath] path] withSubtitle:[[self connection] name]];

	if(_type == WCFilesStyleList) 
		[self _showList];
	else if(_type == WCFilesStyleBrowser) 
		[self _showBrowser];
	
	[_styleControl selectSegmentWithTag:_type];
}



- (void)windowWillClose:(NSNotification *)notification {
	if(_subscribed)
		[self _unsubscribe];
}



- (NSMenu *)windowTitleBarMenu:(WIWindow *)window {
	return _titleBarMenu;
}



- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)defaultFrame {
	NSRect		frame;
	
	frame = [[self window] frame];
	frame.origin.y = defaultFrame.origin.y;
	frame.size.height = defaultFrame.size.height;
	
	return frame;
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[super windowTemplateShouldLoad:windowTemplate];

	[[_filesController filesTableView] setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCFilesTableView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[[_filesController filesTableView] propertiesDictionary] forKey:@"WCFilesTableView"];
	
	[super windowTemplateShouldSave:windowTemplate];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	[self validate];
	
	[self _subscribe];
	
	_subscribed = YES;

	[super linkConnectionLoggedIn:notification];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	[self validate];

	_subscribed = NO;
	
	[super linkConnectionDidClose:notification];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	[self validate];
	
	_subscribed = NO;
	
	[super linkConnectionDidTerminate:notification];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	[[self window] setTitle:[[self _currentPath] path] withSubtitle:[[self connection] name]];
	
	[super serverConnectionServerInfoDidChange:notification];
}



- (void)wiredFileListPathReply:(WIP7Message *)message {
	WCFile			*file;
	WIP7UInt64		free;

	if([[message name] isEqualToString:@"wired.file.list"]) {
		file = [WCFile fileWithMessage:message connection:[self connection]];
		
		if(![[[file path] stringByDeletingLastPathComponent] isEqualToString:[[self _currentPath] path]])
			return;
		
		[_allFiles setObject:file forKey:[file name]];
	}
	else if([[message name] isEqualToString:@"wired.file.list.done"]) {
		[message getUInt64:&free forName:@"wired.file.available"];

		[[self _currentPath] setFree:free];
		
		[_filesController setFiles:[_allFiles allValues]];
		
		[_browserFiles setObject:[[[_allFiles allValues] mutableCopy] autorelease]
						  forKey:[[self _currentPath] path]];
		
		[[[self connection] cache] setFiles:[[[_allFiles allValues] mutableCopy] autorelease]
									   free:[[self _currentPath] free]
									forPath:[[self _currentPath] path]];
		
		[self _updateFiles];
	}
}



- (void)wiredFileDirectoryChanged:(WIP7Message *)message {
	if([[message stringForName:@"wired.file.path"] isEqualToString:[[self _currentPath] path]])
		[self _reloadFiles];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)controlTextDidChange:(NSNotification *)notification {
	NSControl		*control;
	
	control = [notification object];
	
	if(control == _createFolderTextField) {
		[_createFolderPopUpButton selectItemWithTag:
			[WCFile folderTypeForString:[_createFolderTextField stringValue]]];
	}
}



#pragma mark -

- (void)validate {
	NSEnumerator	*enumerator;
	NSArray			*files;
	WCAccount		*account;
	WCFile			*file;
	BOOL			connected, preview;
	
	connected	= [[self connection] isConnected];
	account		= [[self connection] account];
	files		= [self _selectedFiles];

	switch([files count]) {
		case 0:
			[_downloadButton setEnabled:NO];
			[_previewButton setEnabled:NO];
			[_infoButton setEnabled:NO];
			[_deleteButton setEnabled:NO];
			break;

		case 1:
			file = [files objectAtIndex:0];

			[_downloadButton setEnabled:([account transferDownloadFiles] && connected)];
			[_deleteButton setEnabled:([account fileDeleteFiles] && connected)];
			[_infoButton setEnabled:connected];
			[_previewButton setEnabled:(connected && [account transferDownloadFiles] && ![file isFolder] && [WCPreview canInitWithExtension:[file extension]])];
			break;

		default:
			[_downloadButton setEnabled:([account transferDownloadFiles] && connected)];
			
			preview = ([account transferDownloadFiles] && connected);
			
			if(preview) {
				enumerator = [files objectEnumerator];
				
				while((file = [enumerator nextObject])) {
					if([file isFolder] || ![WCPreview canInitWithExtension:[file extension]]) {
						preview = NO;
						
						break;
					}
				}
			}
			
			[_previewButton setEnabled:preview];
			[_deleteButton setEnabled:([account fileDeleteFiles] && connected)];
			[_infoButton setEnabled:connected];
			break;
	}

	[[_historyControl cell] setEnabled:(_type == WCFilesStyleList && _historyPosition > 0 && connected) forSegment:0];
	[[_historyControl cell] setEnabled:(_type == WCFilesStyleList && _historyPosition + 1 < [_history count] && connected) forSegment:1];

	[_uploadButton setEnabled:([self _validateUpload] && connected)];
	[_createFolderButton setEnabled:([account fileCreateDirectories] && connected)];
	[_reloadButton setEnabled:connected];
	
	[super validate];
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	BOOL	connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(download:))
		return ([[[self connection] account] transferDownloadFiles] && connected);
	else if(selector == @selector(getInfo:))
		return ([self _selectedFile] != NULL && connected);
	else if(selector == @selector(newFolder:))
		return ([[[self connection] account] fileCreateDirectories] && connected);
	else if(selector == @selector(deleteFiles:))
		return ([[[self connection] account] fileDeleteFiles] && connected);

	return [super validateMenuItem:item];
}



- (void)submitSheet:(id)sender {
	BOOL	valid = YES;
	
	if([sender window] == _createFolderPanel)
		valid = ([[_createFolderTextField stringValue] length] > 0);
	
	if(valid)
		[super submitSheet:sender];
}



#pragma mark -

- (IBAction)open:(id)sender {
	NSEnumerator	*enumerator;
	NSArray			*files;
	WCFile			*file;
	
	if(![[self connection] isConnected])
		return;

	files = [self _selectedFiles];
	enumerator = [files objectEnumerator];

	while((file = [enumerator nextObject]))
		[self _openFile:file overrideNewWindow:(_type == WCFilesStyleBrowser || [files count] > 1)];
}



- (IBAction)openMenuItem:(id)sender {
	WCFile		*file;
	
	if(![[self connection] isConnected])
		return;
	
	file = [WCFile fileWithDirectory:[sender representedObject] connection:[self connection]];

	if(![file isEqual:[self _currentPath]])
		[self _openFile:file overrideNewWindow:NO];
}



- (IBAction)up:(id)sender {
	WCFile		*file;
	
	if([[[self _currentPath] path] isEqualToString:@"/"])
		return;
	
	file = [WCFile fileWithDirectory:[[[self _currentPath] path] stringByDeletingLastPathComponent] connection:[self connection]];

	[self _openFile:file overrideNewWindow:NO];
}



- (IBAction)down:(id)sender {
	NSEnumerator	*enumerator;
	NSArray			*files;
	WCFile			*file;
	NSInteger		count;

	files = [self _selectedFiles];
	count = [files count];
	enumerator = [files objectEnumerator];

	while((file = [enumerator nextObject]))
		[self _openFile:file overrideNewWindow:(count > 1)];
}



- (IBAction)back:(id)sender {
	if([[_historyControl cell] isEnabledForSegment:0]) {
		[self _setSelectPath:[[self _currentPath] path]];
		[self _changeDirectory:[_history objectAtIndex:--_historyPosition]];
		[self validate];
	}
}



- (IBAction)forward:(id)sender {
	if([[_historyControl cell] isEnabledForSegment:1]) {
		[self _setSelectPath:NULL];
		[self _changeDirectory:[_history objectAtIndex:++_historyPosition]];
		[self validate];
	}
}



- (IBAction)history:(id)sender {
	if([_styleControl selectedSegment] == 0)
		[self back:self];
	else
		[self forward:self];
}



- (IBAction)style:(id)sender {
	if([[_styleControl cell] tagForSegment:[_styleControl selectedSegment]] == WCFilesStyleList)
		[self _showList];
	else
		[self _showBrowser];
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

	[openPanel setCanChooseDirectories:[[[self connection] account] transferUploadDirectories]];
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
			[[WCTransfers transfers] uploadPath:path toFolder:[self _currentPath]];
	}
}



- (IBAction)getInfo:(id)sender {
	NSEnumerator		*enumerator;
	WCFile				*file;
	
	if([[NSApp currentEvent] alternateKeyModifier]) {
		enumerator = [[self _selectedFiles] objectEnumerator];
		
		while((file = [enumerator nextObject]))
			[WCFileInfo fileInfoWithConnection:[self connection] file:file];
	} else {
		[WCFileInfo fileInfoWithConnection:[self connection] files:[self _selectedFiles]];
	}
}



- (IBAction)preview:(id)sender {
	NSEnumerator	*enumerator;
	WCFile			*file;

	enumerator = [[self _selectedFiles] objectEnumerator];

	while((file = [enumerator nextObject]))
		[[WCTransfers transfers] previewFile:file];
}



- (IBAction)createFolder:(id)sender {
	NSEnumerator		*enumerator;
	NSMenuItem			*item;
	
	if(![[_createFolderPopUpButton lastItem] image]) {
		enumerator = [[_createFolderPopUpButton itemArray] objectEnumerator];
		
		while((item = [enumerator nextObject]))
			[item setImage:[WCFile iconForFolderType:[item tag] width:16.0]];
	}
	
	[_createFolderTextField setStringValue:NSLS(@"Untitled", @"New folder name")];
	[_createFolderTextField selectText:self];
	[_createFolderPopUpButton selectItemWithTag:WCFileDirectory];
	
	[NSApp beginSheet:_createFolderPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(createFolderSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)createFolderSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*path;
	WIP7Message		*message;
	WCFileType		type;

	[_createFolderPanel close];

	if(returnCode == NSAlertDefaultReturn) {
		path = [[[self _currentPath] path] stringByAppendingPathComponent:[_createFolderTextField stringValue]];
		
		message = [WIP7Message messageWithName:@"wired.file.create_directory" spec:WCP7Spec];
		[message setString:path forName:@"wired.file.path"];
		
		type = [_createFolderPopUpButton tagOfSelectedItem];

		if(type != WCFileDirectory)
			[message setEnum:type forName:@"wired.file.type"];
		
		[[self connection] sendMessage:message];
	}
}



- (IBAction)reloadFiles:(id)sender {
	[self _reloadFiles];
}



- (IBAction)deleteFiles:(id)sender {
	NSString	*title;
	NSUInteger	count;

	if(![[self connection] isConnected])
		return;

	count = [[self _selectedFiles] count];

	if(count == 0)
		return;

	if(count == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete file dialog title (filename)"),
			[[self _selectedFile] name]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu items?", @"Delete file dialog title (count)"),
			count];
	}

	NSBeginAlertSheet(title,
					  NSLS(@"Delete", @"Delete file button title"),
					  NSLS(@"Cancel", @"Delete file button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete file dialog description"));
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	WIP7Message		*message;
	WCFile			*file;
	NSString		*path;

	if(returnCode == NSAlertDefaultReturn) {
		enumerator = [[self _selectedFiles] objectEnumerator];

		if(_type == WCFilesStyleBrowser) {
			path = [[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser path]] stringByDeletingLastPathComponent];
			
			[self _changeDirectory:[WCFile fileWithDirectory:path connection:[self connection]]];
			
			[_filesBrowser setPath:path];
		}

		while((file = [enumerator nextObject])) {
			message = [WIP7Message messageWithName:@"wired.file.delete" spec:WCP7Spec];
			[message setString:[file path] forName:@"wired.file.path"];
			[[self connection] sendMessage:message];
		}
	}
}



#pragma mark -

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)proposedRow proposedDropOperation:(NSTableViewDropOperation)proposedOperation {
	WCFile				*file, *path;
	NSDragOperation		operation;

	file		= (proposedRow >= 0) ? [_filesController fileAtIndex:proposedRow] : NULL;
	path		= [self _currentPath];
	operation	= [self _validateDrop:info inPath:path onFile:file dropOperation:proposedOperation];

	if(operation != NSDragOperationNone) {
		if((file && [file type] == WCFileFile) || proposedOperation == NSTableViewDropAbove)
			[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
	}
	
	return operation;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	WCFile		*destination;
	
	destination = (row >= 0) ? [_filesController fileAtIndex:row] : [self _currentPath];
	
	return [self _acceptDrop:info inDestination:destination];
}



- (NSArray *)tableView:(NSTableView *)tableView namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedRowsWithIndexes:(NSIndexSet *)indexes {
	NSMutableArray		*array;
	WCFile				*file;
	NSUInteger			index;
	
	array = [NSMutableArray array];
	index = [indexes firstIndex];
	
	while(index != NSNotFound) {
		file = [_filesController fileAtIndex:index];

		if([[WCTransfers transfers] downloadFile:file toFolder:[destination path]])
			[array addObject:[file name]];

		index = [indexes indexGreaterThanIndex:index];
    }
	
	return array;
}



#pragma mark -

- (NSInteger)browser:(NSBrowser *)browser numberOfRowsInColumn:(NSInteger)column {
	return [[_browserFiles objectForKey:[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:column]]] count];
}



- (void)browser:(NSBrowser *)browser willDisplayCell:(id)cell atRow:(NSInteger)row column:(NSInteger)column {
	WCFile		*file;
	
	file = [[_browserFiles objectForKey:[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:column]]] objectAtIndex:row];
	[cell setLeaf:![file isFolder]];
	[cell setStringValue:[file name]];
	[cell setIcon:[file iconWithWidth:16.0]];
	[cell setRepresentedObject:file];
}



- (void)browserDidSingleClick:(id)sender {
	WCFile		*file;
	
	if(![[self connection] isConnected])
		return;

	[self validate];
	
	file = [[_filesBrowser selectedCell] representedObject];
	
	if(!file)
		return;

	if(![file isFolder]) {
		file = [WCFile fileWithPath:[[file path] stringByDeletingLastPathComponent] type:[file type] connection:[self connection]];
		
		if(![[file path] isEqualToString:[[self _currentPath] path]]) {
			[self _setDirectory:file];
			[self _updateStatus];
		}
	} else {
		if(![[file path] isEqualToString:[[self _currentPath] path]])
			[self _changeDirectory:file];
	}
}



- (BOOL)browser:(NSBrowser *)browser writeRowsWithIndexes:(NSIndexSet *)indexes inColumn:(NSInteger)column toPasteboard:(NSPasteboard *)pasteboard {
	NSMutableArray		*sources;
	NSMutableString		*string;
	NSArray				*files;
	WCFile				*file;
	NSUInteger			index;
	
	files		= [_browserFiles objectForKey:[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:column]]];
	sources		= [NSMutableArray array];
	string		= [NSMutableString string];
	index		= [indexes firstIndex];
	
	while(index != NSNotFound) {
		file = [files objectAtIndex:index];
		
		if([string length] > 0)
			[string appendString:@"\n"];
		
		[string appendString:[file path]];
		[sources addObject:file];

		index = [indexes indexGreaterThanIndex:index];
    }
	
	[pasteboard declareTypes:[NSArray arrayWithObjects:
		WCFilePboardType, NSStringPboardType, NSFilesPromisePboardType, NULL] owner:NULL];
	[pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:sources] forType:WCFilePboardType];
	[pasteboard setString:string forType:NSStringPboardType];
	[pasteboard setPropertyList:[NSArray arrayWithObject:NSFileTypeForHFSTypeCode('\0\0\0\0')] forType:NSFilesPromisePboardType];
	
	return YES;
}



- (BOOL)browser:(NSBrowser *)browser canDragRowsWithIndexes:(NSIndexSet *)indexes inColumn:(NSInteger)column withEvent:(NSEvent *)event {
	return YES;
}



- (NSDragOperation)browser:(NSBrowser *)browser validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger *)proposedRow column:(NSInteger *)proposedColumn dropOperation:(NSTableViewDropOperation *)dropOperation { /* NSBrowserDropOperation */
	NSArray				*files;
	NSString			*path;
	WCFile				*file;
	NSDragOperation		operation;
	
	if(*proposedColumn < 0)
		return NSDragOperationNone;
	
	path		= [[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:*proposedColumn]];
	files		= [_browserFiles objectForKey:path];
	
	if((NSUInteger) *proposedRow >= [files count])
		*proposedRow = -1;

	file		= (*proposedRow >= 0) ? [files objectAtIndex:*proposedRow] : NULL;
	operation	= [self _validateDrop:info inPath:[WCFile fileWithDirectory:path connection:[self connection]] onFile:file dropOperation:*dropOperation];
	
	if(operation != NSDragOperationNone) {
		if((file && [file type] == WCFileFile) || *dropOperation == NSTableViewDropAbove /* NSBrowserDropAbove */) {
			*proposedRow = -1;
			*dropOperation = NSTableViewDropOn; // NSBrowserDropOn
		}
	}
	
	return operation;
}



- (BOOL)browser:(NSBrowser *)browser acceptDrop:(id <NSDraggingInfo>)info atRow:(NSInteger)row column:(NSInteger)column dropOperation:(NSTableViewDropOperation)dropOperation { /* NSBrowserDropOperation */
	NSString		*path;
	WCFile			*destination;
	
	path = [[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:column]];
	
	if(row >= 0)
		destination = [[_browserFiles objectForKey:path] objectAtIndex:row];
	else
		destination = [WCFile fileWithDirectory:path connection:[self connection]];

	return [self _acceptDrop:info inDestination:destination];
}



- (NSArray *)browser:(NSBrowser *)browser namesOfPromisedFilesDroppedAtDestination:(NSURL *)destination forDraggedRowsWithIndexes:(NSIndexSet *)indexes inColumn:(NSInteger)column {
	NSMutableArray		*array;
	NSArray				*files;
	WCFile				*file;
	NSUInteger			index;
	
	files = [_browserFiles objectForKey:[[_rootPath path] stringByAppendingPathComponent:[_filesBrowser pathToColumn:column]]];
	array = [NSMutableArray array];
	index = [indexes firstIndex];
	
	while(index != NSNotFound) {
		file = [files objectAtIndex:index];

		if([[WCTransfers transfers] downloadFile:file toFolder:[destination path]])
			[array addObject:[file name]];

		index = [indexes indexGreaterThanIndex:index];
    }
	
	return array;
}

@end
