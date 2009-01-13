/* $Id$ */

/*
 *  Copyright (c) 2008 Axel Andersson
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
#import "WCBoard.h"
#import "WCBoards.h"
#import "WCBoardPost.h"
#import "WCBoardThread.h"
#import "WCPreferences.h"
#import "WCServerConnection.h"

#define WCBoardPboardType				@"WCBoardPboardType"


@interface WCBoards(Private)

- (void)_themeDidChange;
- (void)_validate;
- (void)_getBoardsForConnection:(WCServerConnection *)connection;

- (WCBoard *)_selectedBoard;
- (WCBoardThread *)_selectedThread;

- (void)_reloadLocationsAndSelectBoard:(WCBoard *)board;
- (void)_addLocationsForChildrenOfBoard:(WCBoard *)board level:(NSUInteger)level;

- (NSString *)_HTMLStringForPost:(WCBoardPost *)post;

@end


@implementation WCBoards(Private)

- (void)_themeDidChange {
}



- (void)_validate {
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_getBoardsForConnection:(WCServerConnection *)connection {
	WIP7Message		*message;
	WCBoard			*board;
	
	if(YES /*[[connection account] boardReadBoard]*/) {
		board = [_boards boardForConnection:connection];
		
		[board removeAllBoards];
		[board removeAllThreads];

		[_boardsOutlineView reloadData];

		message = [WIP7Message messageWithName:@"wired.board.get_boards" spec:WCP7Spec];
		[connection sendMessage:message fromObserver:self selector:@selector(wiredBoardGetBoardsReply:)];

		message = [WIP7Message messageWithName:@"wired.board.get_posts" spec:WCP7Spec];
		[connection sendMessage:message fromObserver:self selector:@selector(wiredBoardGetPostsReply:)];
	}
}



#pragma mark -

- (WCBoard *)_selectedBoard {
	NSInteger		row;
	
	row = [_boardsOutlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_boardsOutlineView itemAtRow:row];
}



- (WCBoardThread *)_selectedThread {
	WCBoard			*board;
	NSInteger		row;
	
	board = [self _selectedBoard];
	
	if(!board)
		return NULL;
	
	row = [_threadsTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [board threadAtIndex:row];
}



#pragma mark -

- (void)_reloadLocationsAndSelectBoard:(WCBoard *)board {
	[_boardLocationPopUpButton removeAllItems];
	
	[self _addLocationsForChildrenOfBoard:_boards level:0];
	
	if(board)
		[_boardLocationPopUpButton selectItemWithRepresentedObject:board];
	else
		[_boardLocationPopUpButton selectItemAtIndex:0];
}



- (void)_addLocationsForChildrenOfBoard:(WCBoard *)board level:(NSUInteger)level {
	NSEnumerator		*enumerator;
	NSMenuItem			*item;
	WCBoard				*childBoard;
	
	enumerator = [[board boards] objectEnumerator];
	
	while((childBoard = [enumerator nextObject])) {
		item = [NSMenuItem itemWithTitle:[childBoard name]];
		[item setRepresentedObject:childBoard];
		[item setIndentationLevel:level];
		
		[_boardLocationPopUpButton addItem:item];
		
		[self _addLocationsForChildrenOfBoard:childBoard level:level + 1];
	}
}



#pragma mark -

- (NSString *)_HTMLStringForPost:(WCBoardPost *)post {
	NSMutableString		*string;
	
	string = [_postTemplate mutableCopy];

	[string replaceOccurrencesOfString:@"<? from ?>" withString:@"morris"];
	[string replaceOccurrencesOfString:@"<? subject ?>" withString:[post subject]];
	[string replaceOccurrencesOfString:@"<? date ?>" withString:[_dateFormatter stringFromDate:[post postDate]]];
	[string replaceOccurrencesOfString:@"<? body ?>" withString:[post text]];
	[string replaceOccurrencesOfString:@"<? postid ?>" withString:[post postID]];
	[string replaceOccurrencesOfString:@"<? deletestring ?>" withString:@"Delete"];
	
	return [string autorelease];
}

@end


@implementation WCBoards

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
	if(selector == @selector(deletePostWithID:))
		return NO;

	return YES;
}



#pragma mark -

+ (id)boards {
	static WCBoards   *sharedBoards;
	
	if(!sharedBoards)
		sharedBoards = [[self alloc] init];
	
	return sharedBoards;
}



#pragma mark -

- (id)init {
	self = [super initWithWindowNibName:@"Boards"];
	
	_boards				= [[WCBoard rootBoard] retain];
	_receivedBoards		= [[NSMutableSet alloc] init];
	
	_headerTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"header" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_footerTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"footer" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_postTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"post" ofType:@"html"]
															encoding:NSUTF8StringEncoding
															   error:NULL];
	
	[_headerTemplate replaceOccurrencesOfString:@"<? fromstring ?>" withString:@"From"];
	[_headerTemplate replaceOccurrencesOfString:@"<? subjectstring ?>" withString:@"Subject"];
	[_headerTemplate replaceOccurrencesOfString:@"<? datestring ?>" withString:@"Date"];
	
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
	
	[self window];

	return self;
}



- (void)dealloc {
	[_boards release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Boards"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Boards"];

	[_boardsSplitView setAutosaveName:@"Boards"];
	[_threadsSplitView setAutosaveName:@"Threads"];
	
	[_boardsOutlineView registerForDraggedTypes:[NSArray arrayWithObject:WCBoardPboardType]];

	[_threadsTableView setAutosaveName:@"Threads"];
//	[_threadsTableView setDoubleAction:@selector(reply:)];
//	[_threadsTableView setAllowsUserCustomization:YES];
	[_threadsTableView setDefaultHighlightedTableColumnIdentifier:@"Time"];
	[_threadsTableView setDefaultSortOrder:WISortAscending];
	
	[[_threadWebView windowScriptObject] setValue:self forKey:@"Boards"];

	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _themeDidChange];
	
	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"NewBoard"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"New Board", @"New board toolbar item")
												content:[NSImage imageNamed:@"NewBoard"]
												 target:self
												 action:@selector(newBoard:)];
	}
	else if([identifier isEqualToString:@"DeleteBoard"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Delete Board", @"Delete board toolbar item")
												content:[NSImage imageNamed:@"DeleteBoard"]
												 target:self
												 action:@selector(deleteBoard:)];
	}
	else if([identifier isEqualToString:@"NewThread"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"New Thread", @"New thread toolbar item")
												content:[NSImage imageNamed:@"NewThread"]
												 target:self
												 action:@selector(newThread:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"NewBoard",
		@"DeleteBoard",
		NSToolbarSpaceItemIdentifier,
		@"NewThread",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		@"NewBoard",
		@"DeleteBoard",
		@"NewThread",
		NULL];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	WCServerConnection		*connection;
	WCBoard					*board;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;
	
	[_boards revalidateForConnection:connection];

	board = [_boards boardForConnection:connection];
	
	if(!board)
		[_boards addBoard:[WCBoard boardWithConnection:connection]];

	[connection addObserver:self selector:@selector(wiredBoardBoardAdded:) messageName:@"wired.board.board_added"];
	[connection addObserver:self selector:@selector(wiredBoardBoardRenamed:) messageName:@"wired.board.board_renamed"];
	[connection addObserver:self selector:@selector(wiredBoardBoardMoved:) messageName:@"wired.board.board_moved"];
	[connection addObserver:self selector:@selector(wiredBoardBoardDeleted:) messageName:@"wired.board.board_deleted"];

	[self _validate];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;
	
	[_boards invalidateForConnection:connection];

	[connection removeObserver:self];
	
	[self _validate];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	WCServerConnection		*connection;

	connection = [notification object];

	if(![connection isKindOfClass:[WCServerConnection class]])
		return;
	
	[_boards invalidateForConnection:[notification object]];
	
	if([connection URL])
		[_receivedBoards removeObject:[connection URL]];

	[connection removeObserver:self];

	[self _validate];
}




- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	WCServerConnection		*connection;
	WCBoard					*board;
	
	connection = [notification object];
	board = [_boards boardForConnection:connection];
	
	[board setName:[connection name]];
	
	[_boardsOutlineView reloadData];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];
	
	if(![_receivedBoards containsObject:[connection URL]])
		[self _getBoardsForConnection:connection];
}



- (void)wiredBoardGetBoardsReply:(WIP7Message *)message {
	WCServerConnection	*connection;
	WCBoard				*board, *parent;
	
	if([[message name] isEqualToString:@"wired.board.board_list"]) {
		connection	= [message contextInfo];
		board		= [WCBoard boardWithMessage:message connection:connection];
		parent		= [[_boards boardForConnection:connection] boardForPath:[board path]];
		
		[parent addBoard:board];
	}
	else if([[message name] isEqualToString:@"wired.board.board_list.done"]) {
		[_boardsOutlineView reloadData];

		[_boardsOutlineView expandItem:NULL expandChildren:YES];
	
		[self _reloadLocationsAndSelectBoard:NULL];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		// handle error
	}
}



- (void)wiredBoardGetPostsReply:(WIP7Message *)message {
	WCServerConnection		*connection;
	WCBoard					*board;
	WCBoardThread			*thread;
	WCBoardPost				*post;
	
	connection = [message contextInfo];
	
	if([[message name] isEqualToString:@"wired.board.post_list"]) {
		board = [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.board"]];
		
		if(board) {
			thread = [board threadWithID:[message UUIDForName:@"wired.board.thread"]];
			
			if(thread) {
				post = [WCBoardPost postWithMessage:message connection:connection];
				
				[thread addPost:post];
			} else {
				thread = [WCBoardThread threadWithMessage:message connection:connection];
				
				[board addThread:thread];
			}
		}
	}
	else if([[message name] isEqualToString:@"wired.board.post_list.done"]) {
		[_receivedBoards addObject:[connection URL]];

		[_threadsTableView reloadData];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		// handle error
	}
}



- (void)wiredBoardBoardAdded:(WIP7Message *)message {
	WCServerConnection	*connection;
	WCBoard				*board, *parent;
	
	connection	= [message contextInfo];
	board		= [WCBoard boardWithMessage:message connection:connection];
	parent		= [[_boards boardForConnection:connection] boardForPath:[board path]];
		
	[parent addBoard:board];

	[_boardsOutlineView reloadData];
	[_boardsOutlineView expandItem:parent];
	
	[self _reloadLocationsAndSelectBoard:[_boardLocationPopUpButton representedObjectOfSelectedItem]];
}



- (void)wiredBoardBoardRenamed:(WIP7Message *)message {
	NSString			*oldPath, *newPath;
	WCServerConnection	*connection;
	WCBoard				*board;
	
	connection	= [message contextInfo];
	oldPath		= [message stringForName:@"wired.board.board"];
	newPath		= [message stringForName:@"wired.board.new_board"];
	board		= [[_boards boardForConnection:connection] boardForPath:oldPath];
	
	[board setPath:newPath];
	[board setName:[newPath lastPathComponent]];
	
	[_boardsOutlineView reloadData];
	
	[self _reloadLocationsAndSelectBoard:[_boardLocationPopUpButton representedObjectOfSelectedItem]];
}



- (void)wiredBoardBoardMoved:(WIP7Message *)message {
	NSString			*oldPath, *newPath;
	WCServerConnection	*connection;
	WCBoard				*board, *oldParent, *newParent;
	
	connection	= [message contextInfo];
	oldPath		= [message stringForName:@"wired.board.board"];
	newPath		= [message stringForName:@"wired.board.new_board"];
	board		= [[_boards boardForConnection:connection] boardForPath:oldPath];
	oldParent	= [[_boards boardForConnection:connection] boardForPath:[oldPath stringByDeletingLastPathComponent]];
	newParent	= [[_boards boardForConnection:connection] boardForPath:[newPath stringByDeletingLastPathComponent]];
	
	[board setPath:newPath];
	[board setName:[newPath lastPathComponent]];
	
	[board retain];
	[oldParent removeBoard:board];
	[newParent addBoard:board];
	[board release];
	
	[_boardsOutlineView reloadData];
	[_boardsOutlineView expandItem:newParent];
	
	[self _reloadLocationsAndSelectBoard:[_boardLocationPopUpButton representedObjectOfSelectedItem]];
}



- (void)wiredBoardBoardDeleted:(WIP7Message *)message {
	NSString			*path;
	WCServerConnection	*connection;
	WCBoard				*parent;
	
	connection	= [message contextInfo];
	path		= [message stringForName:@"wired.board.board"];
	parent		= [[_boards boardForConnection:connection] boardForPath:[path stringByDeletingLastPathComponent]];
	
	[parent removeBoard:[[_boards boardForConnection:connection] boardForPath:path]];
	
	[_boardsOutlineView reloadData];
	
	[self _reloadLocationsAndSelectBoard:[_boardLocationPopUpButton representedObjectOfSelectedItem]];
}



- (void)wiredBoardAddBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"message = %@", message);
}



- (void)wiredBoardRenameBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"message = %@", message);
}



- (void)wiredBoardMoveBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"message = %@", message);
}



- (void)wiredBoardDeleteBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"message = %@", message);
}



- (void)selectedThemeDidChange:(NSNotification *)notification {
	[self _themeDidChange];
}



- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
	NSSize		size, topSize, bottomSize, leftSize, rightSize;
	
	if(splitView == _boardsSplitView) {
		size = [_boardsSplitView frame].size;
		leftSize = [_boardsView frame].size;
		leftSize.height = size.height;
		rightSize.height = size.height;
		rightSize.width = size.width - [_boardsSplitView dividerThickness] - leftSize.width;
		
		[_boardsView setFrameSize:leftSize];
		[_threadsView setFrameSize:rightSize];
	}
	else if(splitView == _threadsSplitView) {
		size = [_threadsSplitView frame].size;
		topSize = [_threadListView frame].size;
		topSize.width = size.width;
		bottomSize.width = size.width;
		bottomSize.height = size.height - [_threadsSplitView dividerThickness] - topSize.height;
		
		[_threadListView setFrameSize:topSize];
		[_threadView setFrameSize:bottomSize];
	}
	
	[splitView adjustSubviews];
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return YES;
}



#pragma mark -

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCAccount	*account;
	WCBoard		*board;
	SEL			selector;
	BOOL		connected;
	
	selector	= [item action];
	board		= [self _selectedBoard];
	account		= [[board connection] account];
	connected	= [[board connection] isConnected];
	
	if(selector == @selector(deleteBoard:))
		return (board != NULL && /*[account boardDeleteBoards] &&*/ connected && [board isModifiable]);
	else if(selector == @selector(newThread:))
		return (board != NULL && /*[account boardCreateThreads] &&*/ connected);
	
	return YES;
}



#pragma mark -

- (BOOL)deletePostWithID:(NSString *)postID {
	NSLog(@"delete %@", postID);
	
	return YES;
}



#pragma mark -

- (IBAction)newBoard:(id)sender {
	[self _reloadLocationsAndSelectBoard:[self _selectedBoard]];
	
	[_newBoardPanel makeFirstResponder:_boardNameTextField];
	
	[NSApp beginSheet:_newBoardPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(newBoardPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)newBoardPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*path;
	WIP7Message		*message;
	WCBoard			*board;
	
	if(returnCode == NSOKButton) {
		board = [_boardLocationPopUpButton representedObjectOfSelectedItem];
		
		if(board && [[board connection] isConnected] && [[_boardNameTextField stringValue] length] > 0) {
			message = [WIP7Message messageWithName:@"wired.board.add_board" spec:WCP7Spec];
			
			if([[board path] isEqualToString:@"/"])
				path = [_boardNameTextField stringValue];
			else
				path = [[board path] stringByAppendingPathComponent:[_boardNameTextField stringValue]];
			
			[message setString:path forName:@"wired.board.board"];

			[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardAddBoardReply:)];
		}
	}
	
	[_newBoardPanel close];
}



- (IBAction)deleteBoard:(id)sender {
	NSAlert		*alert;
	WCBoard		*board;
	
	board = [self _selectedBoard];
	
	if(![board isModifiable])
		return;
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete the board \u201c%@\u201d?", @"Delete board dialog title"), [board name]]];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete board dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete board button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete board button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteBoardAlertDidEnd:returnCode:contextInfo:)
						contextInfo:[board retain]];
}



- (void)deleteBoardAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	WCBoard			*board = contextInfo;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		if([[board connection] isConnected]) {
			message = [WIP7Message messageWithName:@"wired.board.delete_board" spec:WCP7Spec];
			[message setString:[board path] forName:@"wired.board.board"];
			[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardDeleteBoardReply:)];
		}
	}
	
	[board release];
}



- (IBAction)newThread:(id)sender {
	[NSApp beginSheet:_newThreadPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(newThreadPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)newThreadPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton) {
	}

	[_newThreadPanel close];
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		item = _boards;
	
	return [item numberOfBoards];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(!item)
		item = _boards;
	
	return [item boardAtIndex:index];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	return [item name];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
/*	NSImage			*image = NULL;
	NSUInteger		count = 0;
	
	if([item isKindOfClass:[NSString class]]) {
		image = _conversationIcon;

		if([_titles indexOfObject:item] == 0)
			count = [[self _unreadMessagesOfClass:[WCPrivateMessage class]] count];
		else if([_titles indexOfObject:item] == 1)
			count = [[self _unreadMessagesOfClass:[WCBroadcastMessage class]] count];
	}
	else if([item isKindOfClass:[WCConversation class]]) {
		count = [[self _messagesForConversation:item unreadOnly:YES] count];
		image = NULL;
	}	

	if(count > 0)
		[cell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	else
		[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	
	[cell setImage:image];*/
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return [item isExpandable];
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	[_threadsTableView reloadData];
	[_threadsTableView deselectAll:self];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	WCServerConnection		*connection;
	WCBoard					*board = item;
	
	connection = [board connection];
	
	return ([board isModifiable] && [connection isConnected]/* && [[connection account] boardRenameBoards]*/);
}



- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSString		*oldPath, *newPath;
	WCBoard			*board = item;
	WIP7Message		*message;
	
	board		= item;
	oldPath		= [item path];
	newPath		= [[[item path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:object];
	
	if(![oldPath isEqualToString:newPath]) {
		message = [WIP7Message messageWithName:@"wired.board.rename_board" spec:WCP7Spec];
		[message setString:oldPath forName:@"wired.board.board"];
		[message setString:newPath forName:@"wired.board.new_board"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardRenameBoardReply:)];
	}
}



- (BOOL)outlineView:(NSOutlineView *)tableView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCBoard			*board;
	
	board = [items objectAtIndex:0];
	
	[pasteboard declareTypes:[NSArray arrayWithObject:WCBoardPboardType] owner:NULL];
	[pasteboard setPropertyList:[NSArray arrayWithObjects:[board path], [board name], NULL] forType:WCBoardPboardType];
	
	return YES;
}



- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
	NSPasteboard		*pasteboard;
	NSArray				*types, *array;
	NSString			*oldPath, *oldName, *newPath, *rootPath;
	WCBoard				*board = item;

	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	
	if([types containsObject:WCBoardPboardType]) {
		array		= [pasteboard propertyListForType:WCBoardPboardType];
		oldPath		= [array objectAtIndex:0];
		oldName		= [array objectAtIndex:1];
		rootPath	= [[board path] isEqualToString:@"/"] ? @"" : [board path];
		newPath		= [rootPath stringByAppendingPathComponent:oldName];
		
		if(!board || [oldPath isEqualToString:newPath] || [newPath hasPrefix:oldPath])
			return NSDragOperationNone;
		
		return NSDragOperationMove;
	}
	
	return NSDragOperationNone;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	NSPasteboard		*pasteboard;
	NSArray				*types, *array;
	NSString			*oldPath, *oldName, *newPath, *rootPath;
	WIP7Message			*message;
	WCBoard				*board = item;
	
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	
	if([types containsObject:WCBoardPboardType]) {
		array		= [pasteboard propertyListForType:WCBoardPboardType];
		oldPath		= [array objectAtIndex:0];
		oldName		= [array objectAtIndex:1];
		rootPath	= [[board path] isEqualToString:@"/"] ? @"" : [board path];
		newPath		= [rootPath stringByAppendingPathComponent:oldName];
		
		message = [WIP7Message messageWithName:@"wired.board.move_board" spec:WCP7Spec];
		[message setString:oldPath forName:@"wired.board.board"];
		[message setString:newPath forName:@"wired.board.new_board"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardMoveBoardReply:)];
		
		return YES;
	}
	
	return NO;
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [[self _selectedBoard] numberOfThreads];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCBoardThread		*thread;
	
	thread = [[self _selectedBoard] threadAtIndex:row];
	
	if(tableColumn == _subjectTableColumn)
		return [thread subject];
	else if(tableColumn == _nickTableColumn)
		return [thread nick];
	else if(tableColumn == _timeTableColumn)
		return [_dateFormatter stringFromDate:[thread postDate]];
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
/*	WCMessage		*message;
	
	message = [self _messageAtIndex:row];
	
	if(![message isRead])
		[cell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	else
		[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];*/
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
/*	[_messagesTableView setHighlightedTableColumn:tableColumn];
	[self _sortMessages];
	[_messagesTableView reloadData];
	[[_messagesTableView delegate] tableViewSelectionDidChange:NULL];*/
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	NSEnumerator		*enumerator;
	NSMutableString		*html;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	thread = [self _selectedThread];
	html = [NSMutableString stringWithString:_headerTemplate];
	
	if(thread) {
		[html appendString:[self _HTMLStringForPost:thread]];
		
		enumerator = [[thread posts] objectEnumerator];
		
		while((post = [enumerator nextObject]))
			[html appendString:[self _HTMLStringForPost:post]];
	}
	
	[html appendString:_footerTemplate];
	
	[[_threadWebView mainFrame] loadHTMLString:html baseURL:NULL];
	
	[self _validate];
}

@end
