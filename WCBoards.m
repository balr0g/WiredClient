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

- (void)_themeDidChange;
- (void)_validate;
- (void)_getBoardsForConnection:(WCServerConnection *)connection;

- (WCBoard *)_selectedBoard;
- (WCBoardThread *)_selectedThread;

- (void)_reloadLocationsAndSelectBoard:(WCBoard *)board;
- (void)_addLocationsForChildrenOfBoard:(WCBoard *)board level:(NSUInteger)level;

- (void)_reloadThread;
- (NSString *)_HTMLStringForPost:(WCBoardPost *)post;

@end


@implementation WCBoards(Private)

- (void)_themeDidChange {
}



- (void)_validate {
	WCBoard					*board;
	WCServerConnection		*connection;
	
	board			= [self _selectedBoard];
	connection		= [board connection];
	
	[_addBoardButton setEnabled:([_boardLocationPopUpButton numberOfItems] > 0)];
	[_deleteBoardButton setEnabled:(board != NULL && [board isModifiable] && [connection isConnected] /* && [[connection account] boardDeleteBoards]*/)];
	
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
	NSMutableString		*string;
	
	string = [_postTemplate mutableCopy];

	[string replaceOccurrencesOfString:@"<? from ?>" withString:[NSSWF:NSLS(@"%@ (%@)", @"Post from (nick, login)"), [post nick], [post login]]];
	[string replaceOccurrencesOfString:@"<? subject ?>" withString:[post subject]];
	[string replaceOccurrencesOfString:@"<? date ?>" withString:[_dateFormatter stringFromDate:[post postDate]]];
	[string replaceOccurrencesOfString:@"<? body ?>" withString:[post text]];
	[string replaceOccurrencesOfString:@"<? postid ?>" withString:[post postID]];
	[string replaceOccurrencesOfString:@"<? replydisabled ?>" withString:@""];
	[string replaceOccurrencesOfString:@"<? editdisabled ?>" withString:@""];
	[string replaceOccurrencesOfString:@"<? deletedisabled ?>" withString:@""];
	[string replaceOccurrencesOfString:@"<? replystring ?>" withString:NSLS(@"Reply", @"Reply post button title")];
	[string replaceOccurrencesOfString:@"<? editstring ?>" withString:NSLS(@"Edit", @"Edit post button title")];
	[string replaceOccurrencesOfString:@"<? deletestring ?>" withString:NSLS(@"Delete", @"Delete post button title")];

	return [string autorelease];
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



- (void)windowDidBecomeKey:(NSNotification *)notification {
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"NewThread"]) {
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
		@"NewThread",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
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
	[connection addObserver:self selector:@selector(wiredBoardPostAdded:) messageName:@"wired.board.post_added"];
	[connection addObserver:self selector:@selector(wiredBoardPostEdited:) messageName:@"wired.board.post_edited"];
	[connection addObserver:self selector:@selector(wiredBoardPostDeleted:) messageName:@"wired.board.post_deleted"];
	[connection addObserver:self selector:@selector(wiredBoardThreadMoved:) messageName:@"wired.board.thread_moved"];
	
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
			
			if(!thread) {
				thread = [WCBoardThread threadWithThreadID:[post threadID] connection:connection];
				
				[board addThread:thread];
			}
			
			post = [WCBoardPost postWithMessage:message connection:connection];

			[thread addPost:post];
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



- (void)wiredBoardAddBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardAddBoardReply: message = %@", message);
}



- (void)wiredBoardRenameBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardRenameBoardReply: message = %@", message);
}



- (void)wiredBoardMoveBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardMoveBoardReply: message = %@", message);
}



- (void)wiredBoardDeleteBoardReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardDeleteBoardReply: message = %@", message);
}



- (void)wiredBoardPostAdded:(WIP7Message *)message {
	NSLog(@"wiredBoardPostAdded: message = %@", message);
}



- (void)wiredBoardPostEdited:(WIP7Message *)message {
	NSLog(@"wiredBoardPostEdited: message = %@", message);
}



- (void)wiredBoardPostDeleted:(WIP7Message *)message {
	NSLog(@"wiredBoardPostDeleted: message = %@", message);
}



- (void)wiredBoardAddPostReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardAddPostReply: message = %@", message);
}



- (void)wiredBoardEditPostReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardEditPostReply: message = %@", message);
}



- (void)wiredBoardDeletePostReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardDeletePostReply: message = %@", message);
}



- (void)wiredBoardThreadMoved:(WIP7Message *)message {
	NSLog(@"wiredBoardThreadMoved: message = %@", message);
}



- (void)wiredBoardMoveThreadReply:(WIP7Message *)message {
	// handle error
	NSLog(@"wiredBoardMoveThreadReply: message = %@", message);
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
	
	[_newPostPanel makeFirstResponder:_postTextView];
	
	[NSApp beginSheet:_newPostPanel
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
	
	[_newPostPanel close];
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
	
	[_newPostPanel makeFirstResponder:_postTextView];
	
	[NSApp beginSheet:_newPostPanel
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
	
	[_newPostPanel close];
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



- (IBAction)newThread:(id)sender {
	WCBoard			*board;
	
	board = [self _selectedBoard];
	
	if(!board)
		return;
	
	[_postSubjectTextField setStringValue:@""];
	[_postTextView setString:@""];
	[_postButton setTitle:NSLS(@"Create", @"New thread button title")];
	
	[_newPostPanel makeFirstResponder:_postSubjectTextField];
	
	[NSApp beginSheet:_newPostPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(newThreadPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[board retain]];
}



- (void)newThreadPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	WCBoard			*board = contextInfo;
	
	if(returnCode == NSOKButton) {
		message = [WIP7Message messageWithName:@"wired.board.add_post" spec:WCP7Spec];
		[message setString:[board path] forName:@"wired.board.board"];
		[message setString:[_postSubjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[_postTextView string] forName:@"wired.board.text"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardAddPostReply:)];
	}

	[_newPostPanel close];
	[board release];
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
	
	thread = [[self _selectedBoard] threadAtIndex:row];
	
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
//	[self _sortMessages];
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
	thread	= [board threadAtIndex:[indexes firstIndex]];
	
	[pasteboard declareTypes:[NSArray arrayWithObject:WCThreadPboardType] owner:NULL];
	[pasteboard setPropertyList:[NSArray arrayWithObjects:[board path], [thread threadID], NULL] forType:WCThreadPboardType];

	return YES;
}

@end
