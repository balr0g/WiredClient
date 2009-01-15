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
#import "WCSourceSplitView.h"

#define WCBoardPboardType				@"WCBoardPboardType"
#define WCThreadPboardType				@"WCThreadPboardType"


@interface WCBoards(Private)

- (void)_validate;
- (void)_themeDidChange;

- (void)_getBoardsForConnection:(WCServerConnection *)connection;

- (WCBoardThread *)_threadAtIndex:(NSUInteger)index;
- (WCBoard *)_selectedBoard;
- (WCBoardThread *)_selectedThread;

- (void)_selectThread:(WCBoardThread *)thread;
- (SEL)_sortSelector;

- (void)_reloadThread;
- (NSString *)_HTMLStringForPost:(WCBoardPost *)post;

- (void)_reloadLocationsAndSelectBoard:(WCBoard *)board;
- (void)_addLocationsForChildrenOfBoard:(WCBoard *)board level:(NSUInteger)level;

@end


@implementation WCBoards(Private)

- (void)_validate {
	WCServerConnection		*connection;
	WCBoard					*board;
	WCBoardThread			*thread;
	
	board			= [self _selectedBoard];
	thread			= [self _selectedThread];
	connection		= [board connection];
	
	[_addBoardButton setEnabled:([_boardLocationPopUpButton numberOfItems] > 0)];
	[_deleteBoardButton setEnabled:(board != NULL && [board isModifiable] && [connection isConnected] /* && [[connection account] boardDeleteBoards]*/)];
	
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_themeDidChange {
}



#pragma mark -

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

- (WCBoardThread *)_threadAtIndex:(NSUInteger)index {
	WCBoard			*board;
	NSUInteger		i;
	
	board = [self _selectedBoard];
	
	if(!board)
		return NULL;
	
	i = ([_threadsTableView sortOrder] == WISortDescending)
		? [board numberOfThreads] - index - 1
		: index;
	
	return [board threadAtIndex:i];
}



- (NSUInteger)_indexOfThread:(WCBoardThread *)thread {
	WCBoard			*board;
	NSUInteger		index;
	
	board = [self _selectedBoard];
	
	if(!board)
		return NSNotFound;
	
	index = [board indexOfThread:thread];
	
	if(index == NSNotFound)
		return NSNotFound;
	
	return ([_threadsTableView sortOrder] == WISortDescending)
		? [board numberOfThreads] - index - 1
		: index;
}



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
	
	return [self _threadAtIndex:row];
}



#pragma mark -

- (void)_selectThread:(WCBoardThread *)thread {
	NSUInteger		index;
	
	index = [self _indexOfThread:thread];

	if(index != NSNotFound) {
		[_threadsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[_threadsTableView scrollRowToVisible:index];
	}
}



- (SEL)_sortSelector {
	NSTableColumn	*tableColumn;
	
	tableColumn = [_threadsTableView highlightedTableColumn];
	
	if(tableColumn == _subjectTableColumn)
		return @selector(compareSubject:);
	else if(tableColumn == _nickTableColumn)
		return @selector(compareNick:);
	else if(tableColumn == _timeTableColumn)
		return @selector(compareDate:);

	return @selector(compareDate:);
}



#pragma mark -

- (void)_reloadThread {
	NSEnumerator		*enumerator;
	NSMutableString		*html;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	thread = [self _selectedThread];
	
	html = [NSMutableString stringWithString:_headerTemplate];
	
	if(thread) {
		enumerator = [[thread posts] objectEnumerator];
		
		while((post = [enumerator nextObject]))
			[html appendString:[self _HTMLStringForPost:post]];
	}
	
	[html appendString:_footerTemplate];
	
	[[_threadWebView mainFrame] loadHTMLString:html baseURL:NULL];
}



- (NSString *)_HTMLStringForPost:(WCBoardPost *)post {
	NSMutableString		*string, *text;
	
	text = [[[post text] mutableCopy] autorelease];
	
	[text replaceOccurrencesOfString:@"\n" withString:@"<br />"];

	string = [[_postTemplate mutableCopy] autorelease];

	[string replaceOccurrencesOfString:@"<? from ?>" withString:[NSSWF:NSLS(@"%@ (%@)", @"Post from (nick, login)"), [post nick], [post login]]];
	[string replaceOccurrencesOfString:@"<? subject ?>" withString:[post subject]];
	[string replaceOccurrencesOfString:@"<? date ?>" withString:[_dateFormatter stringFromDate:[post postDate]]];
	[string replaceOccurrencesOfString:@"<? body ?>" withString:text];
	[string replaceOccurrencesOfString:@"<? postid ?>" withString:[post postID]];
	[string replaceOccurrencesOfString:@"<? replydisabled ?>" withString:@""];
	[string replaceOccurrencesOfString:@"<? editdisabled ?>" withString:@""];
	[string replaceOccurrencesOfString:@"<? deletedisabled ?>" withString:@""];
	[string replaceOccurrencesOfString:@"<? replystring ?>" withString:NSLS(@"Reply", @"Reply post button title")];
	[string replaceOccurrencesOfString:@"<? editstring ?>" withString:NSLS(@"Edit", @"Edit post button title")];
	[string replaceOccurrencesOfString:@"<? deletestring ?>" withString:NSLS(@"Delete", @"Delete post button title")];
	
	return string;
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

@end


@implementation WCBoards

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
	if(selector == @selector(replyToPostWithID:) ||
	   selector == @selector(deletePostWithID:) ||
	   selector == @selector(editPostWithID:))
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
	
	[_headerTemplate replaceOccurrencesOfString:@"<? fromstring ?>" withString:NSLS(@"From", @"Post header")];
	[_headerTemplate replaceOccurrencesOfString:@"<? subjectstring ?>" withString:NSLS(@"Subject", @"Post header")];
	[_headerTemplate replaceOccurrencesOfString:@"<? datestring ?>" withString:NSLS(@"Date", @"Post header")];
	
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
	
	[_boardsOutlineView registerForDraggedTypes:[NSArray arrayWithObjects:WCBoardPboardType, WCThreadPboardType, NULL]];

	[[_boardTableColumn dataCell] setVerticalTextOffset:3.0];

	[_threadsTableView setDefaultHighlightedTableColumnIdentifier:@"Time"];
	[_threadsTableView setDefaultSortOrder:WISortAscending];
	[_threadsTableView setAllowsUserCustomization:YES];
	[_threadsTableView setAutosaveName:@"Threads"];
    [_threadsTableView setAutosaveTableColumns:YES];
	[_threadsTableView setDoubleAction:@selector(reply:)];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _themeDidChange];
	[self _validate];
	
	[super windowDidLoad];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"AddThread"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Add Thread", @"Add thread toolbar item")
												content:[NSImage imageNamed:@"AddThread"]
												 target:self
												 action:@selector(addThread:)];
	}
	else if([identifier isEqualToString:@"DeleteThread"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Delete Thread", @"Delete thread toolbar item")
												content:[NSImage imageNamed:@"DeleteThread"]
												 target:self
												 action:@selector(deleteThread:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"AddThread",
		@"DeleteThread",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		@"AddThread",
		@"DeleteThread",
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
	[connection addObserver:self selector:@selector(wiredBoardThreadDeleted:) messageName:@"wired.board.thread_deleted"];
	[connection addObserver:self selector:@selector(wiredBoardThreadMoved:) messageName:@"wired.board.thread_moved"];
	[connection addObserver:self selector:@selector(wiredBoardPostAdded:) messageName:@"wired.board.post_added"];
	[connection addObserver:self selector:@selector(wiredBoardPostEdited:) messageName:@"wired.board.post_edited"];
	[connection addObserver:self selector:@selector(wiredBoardPostDeleted:) messageName:@"wired.board.post_deleted"];
	
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
		[self _validate];
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
			post		= [WCBoardPost postWithMessage:message connection:connection];
			thread		= [board threadWithID:[post threadID]];
			
			if(thread) {
				[thread addPost:post];
			} else {
				thread = [WCBoardThread threadWithPost:post connection:connection];
				
				[board addThread:thread sortedUsingSelector:[self _sortSelector]];
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
	[self _validate];
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
	[self _validate];
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
	[self _validate];
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
	[self _validate];
}



- (void)wiredBoardThreadDeleted:(WIP7Message *)message {
	WCServerConnection	*connection;
	WCBoard				*board;
	WCBoardThread		*thread, *selectedThread;
	
	connection		= [message contextInfo];
	board			= [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.board"]];
	thread			= [board threadWithID:[message UUIDForName:@"wired.board.thread"]];
	
	if(board == [self _selectedBoard])
		selectedThread = [self _selectedThread];
	else
		selectedThread = NULL;
	
	[board removeThread:thread];
	
	if(board == [self _selectedBoard]) {
		[_threadsTableView reloadData];

		[self _reloadThread];
		
		if(selectedThread)
			[self _selectThread:selectedThread];
	}
}



- (void)wiredBoardThreadMoved:(WIP7Message *)message {
	WCServerConnection	*connection;
	WCBoard				*oldBoard, *newBoard;
	WCBoardThread		*thread, *selectedThread;
	
	connection		= [message contextInfo];
	oldBoard		= [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.board"]];
	newBoard		= [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.new_board"]];
	thread			= [oldBoard threadWithID:[message UUIDForName:@"wired.board.thread"]];
	
	if(oldBoard == [self _selectedBoard] || newBoard == [self _selectedBoard])
		selectedThread = [self _selectedThread];
	else
		selectedThread = NULL;
	
	[thread retain];
	[oldBoard removeThread:thread];
	[newBoard addThread:thread sortedUsingSelector:[self _sortSelector]];
	[thread release];
	
	if(oldBoard == [self _selectedBoard] || newBoard == [self _selectedBoard]) {
		[_threadsTableView reloadData];

		[self _reloadThread];
		
		if(selectedThread)
			[self _selectThread:selectedThread];
	}
}



- (void)wiredBoardPostAdded:(WIP7Message *)message {
	WCServerConnection	*connection;
	WCBoard				*board;
	WCBoardThread		*thread, *selectedThread;
	WCBoardPost			*post;
	
	connection		= [message contextInfo];
	post			= [WCBoardPost postWithMessage:message connection:connection];
	board			= [[_boards boardForConnection:connection] boardForPath:[post board]];

	if(board == [self _selectedBoard])
		selectedThread = [self _selectedThread];
	else
		selectedThread = NULL;
	
	thread = [board threadWithID:[post threadID]];
	
	if(thread) {
		[thread addPost:post];
	} else {
		thread = [WCBoardThread threadWithPost:post connection:connection];
		
		[board addThread:thread sortedUsingSelector:[self _sortSelector]];
	}
	
	if(board == [self _selectedBoard]) {
		[_threadsTableView reloadData];
		
		if(thread == selectedThread)
			[self _reloadThread];
		else if(selectedThread)
			[self _selectThread:selectedThread];
	}
}



- (void)wiredBoardPostEdited:(WIP7Message *)message {
	NSString			*subject, *text;
	NSDate				*editDate;
	WCServerConnection	*connection;
	WCBoard				*board;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	connection		= [message contextInfo];
	board			= [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.board"]];
	thread			= [board threadWithID:[message UUIDForName:@"wired.board.thread"]];
	post			= [thread postWithID:[message UUIDForName:@"wired.board.post"]];
	editDate		= [message dateForName:@"wired.board.edit_date"];
	subject			= [message stringForName:@"wired.board.subject"];
	text			= [message stringForName:@"wired.board.text"];
	
	[post setEditDate:editDate];
	[post setSubject:subject];
	[post setText:text];
	
	if(thread == [self _selectedThread]) {
		[_threadsTableView reloadData];

		[self _reloadThread];
	}
}



- (void)wiredBoardPostDeleted:(WIP7Message *)message {
	WCServerConnection	*connection;
	WCBoard				*board;
	WCBoardThread		*thread, *selectedThread;
	WCBoardPost			*post;
	
	connection		= [message contextInfo];
	board			= [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.board"]];
	thread			= [board threadWithID:[message UUIDForName:@"wired.board.thread"]];
	post			= [thread postWithID:[message UUIDForName:@"wired.board.post"]];
	
	if(board == [self _selectedBoard])
		selectedThread = [self _selectedThread];
	else
		selectedThread = NULL;
	
	[thread removePost:post];
	
	if([thread numberOfPosts] == 0)
		[board removeThread:thread];
	
	if(board == [self _selectedBoard]) {
		[_threadsTableView reloadData];

		[self _reloadThread];
		
		if(selectedThread)
			[self _selectThread:selectedThread];
	}
}



- (void)wiredBoardAddBoardReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardRenameBoardReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardMoveBoardReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardDeleteBoardReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardAddThreadReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardMoveThreadReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardDeleteThreadReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardAddPostReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardEditPostReply:(WIP7Message *)message {
	// handle error
}



- (void)wiredBoardDeletePostReply:(WIP7Message *)message {
	// handle error
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



- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	return proposedMax - 120.0;
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	return proposedMin + 120.0;
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return NO;
}



- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	BOOL		value = NO;
	
	if(selector == @selector(insertNewline:)) {
		if([[NSApp currentEvent] character] == NSEnterCharacter) {
			[self submitSheet:textView];
			
			value = YES;
		}
	}
	
	return value;
}



- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
	[windowObject setValue:self forKey:@"Boards"];
}



- (NSArray *)webView:(WebView *)webView contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
	return NULL;
}



#pragma mark -

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCAccount		*account;
	WCBoard			*board;
	WCBoardThread	*thread;
	SEL				selector;
	BOOL			connected;
	
	selector	= [item action];
	board		= [self _selectedBoard];
	thread		= [self _selectedThread];
	account		= [[board connection] account];
	connected	= [[board connection] isConnected];
	
	if(selector == @selector(addThread:))
		return (board != NULL);
	else if(selector == @selector(deleteThread:))
		return (board != NULL && thread != NULL);
	
	return YES;
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	WCAccount	*account;
	WCBoard		*board;
	SEL			selector;
	BOOL		connected;
	
	selector	= [item action];
	board		= [self _selectedBoard];
	account		= [[board connection] account];
	connected	= [[board connection] isConnected];
	
	if(selector == @selector(renameBoard:))
		return (board != NULL && [board isModifiable] && connected /* && [account boardRenameBoards]*/);
	
	return YES;
}



#pragma mark -

- (void)replyToPostWithID:(NSString *)postID {
	NSString			*subject;
	WCBoard				*board;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	board	= [self _selectedBoard];
	thread	= [self _selectedThread];
	post	= [thread postWithID:postID];
	
	if(!post)
		return;
	
	subject	= [post subject];
	
	if(![subject hasPrefix:@"Re: "])
		subject = [@"Re: " stringByAppendingString:subject];
	
	[_postSubjectTextField setStringValue:subject];
	[_postTextView setString:@""];
	[_postButton setTitle:NSLS(@"Reply", @"Reply post button title")];
	
	[_postPanel makeFirstResponder:_postTextView];
	
	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(replyPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[[NSArray alloc] initWithObjects:board, thread, NULL]];
}



- (void)replyPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSArray			*array = contextInfo;
	WIP7Message		*message;
	WCBoard			*board = [array objectAtIndex:0];
	WCBoardThread	*thread = [array objectAtIndex:1];
	
	if(returnCode == NSOKButton) {
		message = [WIP7Message messageWithName:@"wired.board.add_post" spec:WCP7Spec];
		[message setString:[board path] forName:@"wired.board.board"];
		[message setUUID:[thread threadID] forName:@"wired.board.thread"];
		[message setString:[_postSubjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[_postTextView string] forName:@"wired.board.text"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardAddPostReply:)];
	}
	
	[_postPanel close];
	[array release];
}



- (void)editPostWithID:(NSString *)postID {
	WCBoard				*board;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	board	= [self _selectedBoard];
	thread	= [self _selectedThread];
	post	= [thread postWithID:postID];
	
	if(!post)
		return;
	
	[_postSubjectTextField setStringValue:[post subject]];
	[_postTextView setString:[post text]];
	[_postButton setTitle:NSLS(@"Edit", @"Edit post button title")];
	
	[_postPanel makeFirstResponder:_postTextView];
	
	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(editPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[[NSArray alloc] initWithObjects:board, thread, post, NULL]];
}



- (void)editPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSArray			*array = contextInfo;
	WIP7Message		*message;
	WCBoard			*board = [array objectAtIndex:0];
	WCBoardThread	*thread = [array objectAtIndex:1];
	WCBoardPost		*post = [array objectAtIndex:2];
	
	if(returnCode == NSOKButton) {
		message = [WIP7Message messageWithName:@"wired.board.edit_post" spec:WCP7Spec];
		[message setString:[board path] forName:@"wired.board.board"];
		[message setUUID:[thread threadID] forName:@"wired.board.thread"];
		[message setUUID:[post postID] forName:@"wired.board.post"];
		[message setString:[_postSubjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[_postTextView string] forName:@"wired.board.text"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardEditPostReply:)];
	}
	
	[_postPanel close];
	[array release];
}



- (void)deletePostWithID:(NSString *)postID {
	NSAlert				*alert;
	WCBoard				*board;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	board	= [self _selectedBoard];
	thread	= [self _selectedThread];
	post	= [thread postWithID:postID];
	
	if(!post)
		return;
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete the post \u201c%@\u201d?", @"Delete post dialog title"), [post subject]]];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete post dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete post button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete post button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deletePostAlertDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSArray alloc] initWithObjects:board, thread, post, NULL]];
}



- (void)deletePostAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSArray			*array = contextInfo;
	WIP7Message		*message;
	WCBoard			*board = [array objectAtIndex:0];
	WCBoardThread	*thread = [array objectAtIndex:1];
	WCBoardPost		*post = [array objectAtIndex:2];
	
	if(returnCode == NSAlertFirstButtonReturn) {
		if([[board connection] isConnected]) {
			message = [WIP7Message messageWithName:@"wired.board.delete_post" spec:WCP7Spec];
			[message setString:[board path] forName:@"wired.board.board"];
			[message setUUID:[thread threadID] forName:@"wired.board.thread"];
			[message setUUID:[post postID] forName:@"wired.board.post"];
			[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardDeletePostReply:)];
		}
	}
	
	[array release];
}



#pragma mark -

- (IBAction)addBoard:(id)sender {
	[self _reloadLocationsAndSelectBoard:[self _selectedBoard]];
	
	[_boardPanel makeFirstResponder:_boardNameTextField];
	
	[NSApp beginSheet:_boardPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addBoardPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)addBoardPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
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
	
	[_boardPanel close];
}



- (IBAction)deleteBoard:(id)sender {
	NSAlert		*alert;
	WCBoard		*board;
	
	board = [self _selectedBoard];
	
	if(![board isModifiable])
		return;
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete the board \u201c%@\u201d?", @"Delete board dialog title"), [board name]]];
	[alert setInformativeText:NSLS(@"All child boards and posts of this board will also be deleted. This cannot be undone.", @"Delete board dialog description")];
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



- (IBAction)renameBoard:(id)sender {
	[_boardsOutlineView editColumn:0 row:[_boardsOutlineView selectedRow] withEvent:NULL select:YES];
}



- (IBAction)addThread:(id)sender {
	WCBoard			*board;
	
	board = [self _selectedBoard];
	
	if(!board)
		return;
	
	[_postSubjectTextField setStringValue:@""];
	[_postTextView setString:@""];
	[_postButton setTitle:NSLS(@"Create", @"New thread button title")];
	
	[_postPanel makeFirstResponder:_postSubjectTextField];
	
	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addThreadPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[board retain]];
}



- (void)addThreadPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	WCBoard			*board = contextInfo;
	
	if(returnCode == NSOKButton) {
		message = [WIP7Message messageWithName:@"wired.board.add_thread" spec:WCP7Spec];
		[message setString:[board path] forName:@"wired.board.board"];
		[message setString:[_postSubjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[_postTextView string] forName:@"wired.board.text"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardAddThreadReply:)];
	}

	[_postPanel close];
	[board release];
}



- (IBAction)deleteThread:(id)sender {
	NSAlert				*alert;
	WCBoard				*board;
	WCBoardThread		*thread;
	
	board	= [self _selectedBoard];
	thread	= [self _selectedThread];
	
	if(!thread)
		return;
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete the thread \u201c%@\u201d?", @"Delete thread dialog title"), [[thread postAtIndex:0] subject]]];
	[alert setInformativeText:NSLS(@"All posts in the thread will be deleted as well. This cannot be undone.", @"Delete thread dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete thread button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete thread button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteThreadAlertDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSArray alloc] initWithObjects:board, thread, NULL]];
}



- (void)deleteThreadAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSArray			*array = contextInfo;
	WIP7Message		*message;
	WCBoard			*board = [array objectAtIndex:0];
	WCBoardThread	*thread = [array objectAtIndex:1];
	
	if(returnCode == NSAlertFirstButtonReturn) {
		if([[board connection] isConnected]) {
			message = [WIP7Message messageWithName:@"wired.board.delete_thread" spec:WCP7Spec];
			[message setString:[board path] forName:@"wired.board.board"];
			[message setUUID:[thread threadID] forName:@"wired.board.thread"];
			[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardDeleteThreadReply:)];
		}
	}
	
	[array release];
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
	
	[self _validate];
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
	WCBoard				*newBoard = item, *oldBoard;

	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	
	if([types containsObject:WCBoardPboardType]) {
		array		= [pasteboard propertyListForType:WCBoardPboardType];
		oldPath		= [array objectAtIndex:0];
		oldName		= [array objectAtIndex:1];
		oldBoard	= [[_boards boardForConnection:[newBoard connection]] boardForPath:oldPath];
		rootPath	= [[newBoard path] isEqualToString:@"/"] ? @"" : [newBoard path];
		newPath		= [rootPath stringByAppendingPathComponent:oldName];
		
		if(!newBoard || !oldBoard || [oldPath isEqualToString:newPath] || [newPath hasPrefix:oldPath] || index >= 0)
			return NSDragOperationNone;
		
		return NSDragOperationMove;
	}
	else if([types containsObject:WCThreadPboardType]) {
		array		= [pasteboard propertyListForType:WCThreadPboardType];
		oldPath		= [array objectAtIndex:0];
		oldBoard	= [[_boards boardForConnection:[newBoard connection]] boardForPath:oldPath];
		rootPath	= [[newBoard path] isEqualToString:@"/"] ? @"" : [newBoard path];
		newPath		= [newBoard path];
		
		if(!oldBoard || [oldPath isEqualToString:newPath] || index >= 0)
			return NSDragOperationNone;
		
		return NSDragOperationMove;
	}
	
	return NSDragOperationNone;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	NSPasteboard		*pasteboard;
	NSArray				*types, *array;
	NSString			*oldPath, *oldName, *newPath, *rootPath, *threadID;
	WIP7Message			*message;
	WCBoard				*newBoard = item, *oldBoard;
	WCBoardThread		*thread;
	
	pasteboard	= [info draggingPasteboard];
	types		= [pasteboard types];
	
	if([types containsObject:WCBoardPboardType]) {
		array		= [pasteboard propertyListForType:WCBoardPboardType];
		oldPath		= [array objectAtIndex:0];
		oldName		= [array objectAtIndex:1];
		rootPath	= [[newBoard path] isEqualToString:@"/"] ? @"" : [newBoard path];
		newPath		= [rootPath stringByAppendingPathComponent:oldName];
		
		message = [WIP7Message messageWithName:@"wired.board.move_board" spec:WCP7Spec];
		[message setString:oldPath forName:@"wired.board.board"];
		[message setString:newPath forName:@"wired.board.new_board"];
		[[newBoard connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardMoveBoardReply:)];
		
		return YES;
	}
	else if([types containsObject:WCThreadPboardType]) {
		array		= [pasteboard propertyListForType:WCThreadPboardType];
		oldPath		= [array objectAtIndex:0];
		threadID	= [array objectAtIndex:1];
		oldBoard	= [[_boards boardForConnection:[newBoard connection]] boardForPath:oldPath];
		thread		= [oldBoard threadWithID:threadID];
		
		message = [WIP7Message messageWithName:@"wired.board.move_thread" spec:WCP7Spec];
		[message setString:[oldBoard path] forName:@"wired.board.board"];
		[message setUUID:[thread threadID] forName:@"wired.board.thread"];
		[message setString:[newBoard path] forName:@"wired.board.new_board"];
		[[newBoard connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardMoveThreadReply:)];
		
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
	
	thread = [self _threadAtIndex:row];
	
	if(tableColumn == _subjectTableColumn)
		return [[thread postAtIndex:0] subject];
	else if(tableColumn == _nickTableColumn)
		return [[thread postAtIndex:0] nick];
	else if(tableColumn == _timeTableColumn)
		return [_dateFormatter stringFromDate:[[thread postAtIndex:0] postDate]];
	
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
	[_threadsTableView setHighlightedTableColumn:tableColumn];
	[[self _selectedBoard] sortThreadsUsingSelector:[self _sortSelector]];
	[_threadsTableView reloadData];

	[self _reloadThread];
	[self _validate];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _reloadThread];
	[self _validate];
}



- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	WCBoard				*board;
	WCBoardThread		*thread;
	
	board	= [self _selectedBoard];
	thread	= [self _threadAtIndex:[indexes firstIndex]];
	
	[pasteboard declareTypes:[NSArray arrayWithObject:WCThreadPboardType] owner:NULL];
	[pasteboard setPropertyList:[NSArray arrayWithObjects:[board path], [thread threadID], NULL] forType:WCThreadPboardType];

	return YES;
}

@end
