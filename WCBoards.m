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
#import "WCAccounts.h"
#import "WCApplicationController.h"
#import "WCBoard.h"
#import "WCBoards.h"
#import "WCBoardPost.h"
#import "WCBoardThread.h"
#import "WCChatController.h"
#import "WCErrorQueue.h"
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
- (NSArray *)_selectedThreads;
- (void)_savePosts;

- (void)_selectThread:(WCBoardThread *)thread;
- (void)_reselectThread:(WCBoardThread *)thread;
- (void)_markSelectedThreadsAsUnread:(BOOL)unread;
- (SEL)_sortSelector;

- (void)_reloadThread;
- (NSString *)_HTMLStringForPost:(WCBoardPost *)post;
- (NSString *)_textForPostText:(NSString *)text;

- (void)_reloadLocationsAndSelectBoard:(WCBoard *)board;
- (void)_addLocationsForChildrenOfBoard:(WCBoard *)board level:(NSUInteger)level;
- (void)_updatePermissions;

@end


@implementation WCBoards(Private)

- (void)_validate {
	WCServerConnection		*connection;
	WCBoard					*board;
	WCBoardThread			*thread;
	
	board			= [self _selectedBoard];
	thread			= [self _selectedThread];
	connection		= [board connection];
	
	[_addBoardButton setEnabled:([_locationPopUpButton numberOfItems] > 0)];
	[_deleteBoardButton setEnabled:(board != NULL && [board isModifiable] && [connection isConnected] && [[connection account] boardDeleteBoards])];
	
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [WCSettings themeWithIdentifier:[WCSettings objectForKey:WCTheme]];
	
	[_threadFont release];
	_threadFont = [WIFontFromString([theme objectForKey:WCThemesBoardsFont]) retain];

	[_threadColor release];
	_threadColor = [WIColorFromString([theme objectForKey:WCThemesBoardsTextColor]) retain];

	[_backgroundColor release];
	_backgroundColor = [WIColorFromString([theme objectForKey:WCThemesBoardsBackgroundColor]) retain];
	
	[self _reloadThread];
}



#pragma mark -

- (void)_getBoardsForConnection:(WCServerConnection *)connection {
	WIP7Message		*message;
	WCBoard			*board;
	
	if([[connection account] boardReadBoards]) {
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
	return _selectedBoard;
}



- (WCBoardThread *)_selectedThread {
	NSInteger		row;
	
	row = [_threadsTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [self _threadAtIndex:row];
}



- (NSArray *)_selectedThreads {
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	NSUInteger			index;
	
	array	= [NSMutableArray array];
	indexes	= [_threadsTableView selectedRowIndexes];
	index	= [indexes firstIndex];
	
	while(index != NSNotFound) {
		[array addObject:[self _threadAtIndex:index]];
		
		index = [indexes indexGreaterThanIndex:index];
	}
	
	return array;
}



- (void)_savePosts {
	[WCSettings setObject:[_readPosts allObjects] forKey:WCReadBoardPosts];
}



#pragma mark -

- (void)_selectThread:(WCBoardThread *)thread {
	WCBoard			*board;
	NSInteger		row;
	
	board = [thread board];
	row = [_boardsOutlineView rowForItem:board];
	
	if(row < 0)
		return;
	
	[_boardsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	
	[self _reselectThread:thread];
}



- (void)_reselectThread:(WCBoardThread *)thread {
	NSUInteger		index;
	
	index = [self _indexOfThread:thread];

	if(index != NSNotFound) {
		[_threadsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[_threadsTableView scrollRowToVisible:index];
	}
}



- (void)_markSelectedThreadsAsUnread:(BOOL)unread {
	NSEnumerator		*enumerator, *postEnumerator;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	BOOL				changedUnread = NO;
	
	enumerator = [[self _selectedThreads] objectEnumerator];
	
	while((thread = [enumerator nextObject])) {
		if([thread isUnread] != unread) {
			[thread setUnread:unread];
			
			changedUnread = YES;
		}
		
		postEnumerator = [[thread posts] objectEnumerator];
		
		while((post = [postEnumerator nextObject])) {
			if([post isUnread] != unread) {
				[post setUnread:unread];

				if(unread)
					[_readPosts removeObject:[post postID]];
				else
					[_readPosts addObject:[post postID]];
				
				changedUnread = YES;
			}
		}
	}

	if(changedUnread) {
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
	
		[self _savePosts];
		
		[_boardsOutlineView setNeedsDisplay:YES];
	}
}



- (SEL)_sortSelector {
	NSTableColumn	*tableColumn;
	
	tableColumn = [_threadsTableView highlightedTableColumn];
	
	if(tableColumn == _unreadThreadTableColumn)
		return @selector(compareUnread:);
	else if(tableColumn == _subjectTableColumn)
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
	NSArray				*threads;
	NSMutableString		*html;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	BOOL				changedUnread = NO, isKeyWindow;
	
	html = [NSMutableString stringWithString:_headerTemplate];
	
	[html replaceOccurrencesOfString:@"<? fontname ?>" withString:[_threadFont fontName]];
	[html replaceOccurrencesOfString:@"<? fontsize ?>" withString:[NSSWF:@"%.0fpx", [_threadFont pointSize]]];
	[html replaceOccurrencesOfString:@"<? textcolor ?>" withString:[NSSWF:@"#%.6x", [_threadColor HTMLValue]]];
	[html replaceOccurrencesOfString:@"<? backgroundcolor ?>" withString:[NSSWF:@"#%.6x", [_backgroundColor HTMLValue]]];

	threads = [self _selectedThreads];
	
	if([threads count] == 1) {
		isKeyWindow		= ([NSApp keyWindow] == [self window]);
		thread			= [threads objectAtIndex:0];
		enumerator		= [[thread posts] objectEnumerator];
		
		while((post = [enumerator nextObject])) {
			[html appendString:[self _HTMLStringForPost:post]];
			
			if([post isUnread] && isKeyWindow) {
				[post setUnread:NO];
				[_readPosts addObject:[post postID]];
				
				changedUnread = YES;
			}
		}
		
		if([thread isUnread] && isKeyWindow) {
			[thread setUnread:NO];
			
			changedUnread = YES;
		}
	}
	
	[html appendString:_footerTemplate];
	
	[[_threadWebView mainFrame] loadHTMLString:html baseURL:[NSURL fileURLWithPath:[[self bundle] resourcePath]]];
	
	if(changedUnread) {
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
		
		[self _savePosts];
		
		[_boardsOutlineView setNeedsDisplay:YES];
		[_threadsTableView setNeedsDisplay:YES];
	}
}



- (NSString *)_HTMLStringForPost:(WCBoardPost *)post {
	NSEnumerator		*enumerator;
	NSDictionary		*theme;
	NSMutableString		*string, *text, *regex;
	NSString			*smiley, *path;
	WCAccount			*account;
	
	theme		= [[post connection] theme];
	account		= [[post connection] account];
	text		= [[[post text] mutableCopy] autorelease];
	
	[text replaceOccurrencesOfString:@"&" withString:@"&#38;"];
	[text replaceOccurrencesOfString:@"<" withString:@"&#60;"];
	[text replaceOccurrencesOfString:@">" withString:@"&#62;"];
	[text replaceOccurrencesOfString:@"\"" withString:@"&#34;"];
	[text replaceOccurrencesOfString:@"\'" withString:@"&#39;"];
	[text replaceOccurrencesOfString:@"\n" withString:@"\n<br />\n"];

	[text replaceOccurrencesOfRegex:@"\\[code\\](.+?)\\[/code\\]" withString:@"<blockquote><pre>$1</pre></blockquote>" options:RKLCaseless];
	
	while([text replaceOccurrencesOfRegex:@"<pre>(.*?)\\[+(.*?)</pre>" withString:@"<pre>$1&#91;$2</pre>" options:RKLCaseless] > 0)
		;
	
	while([text replaceOccurrencesOfRegex:@"<pre>(.*?)\\]+(.*?)</pre>" withString:@"<pre>$1&#93;$2</pre>" options:RKLCaseless] > 0)
		;
	
	if([theme boolForKey:WCThemesShowSmileys]) {
		enumerator = [[[WCApplicationController sharedController] allSmileys] objectEnumerator];
		
		while((smiley = [enumerator nextObject])) {
			path	= [[WCApplicationController sharedController] pathForSmiley:smiley];
			regex	= [[smiley mutableCopy] autorelease];
			
			[regex replaceOccurrencesOfString:@"." withString:@"\\."];
			[regex replaceOccurrencesOfString:@"*" withString:@"\\*"];
			[regex replaceOccurrencesOfString:@"+" withString:@"\\+"];
			[regex replaceOccurrencesOfString:@"^" withString:@"\\^"];
			[regex replaceOccurrencesOfString:@"$" withString:@"\\$"];
			[regex replaceOccurrencesOfString:@"(" withString:@"\\("];
			[regex replaceOccurrencesOfString:@")" withString:@"\\)"];
			[regex replaceOccurrencesOfString:@"[" withString:@"\\["];
			[regex replaceOccurrencesOfString:@"]" withString:@"\\]"];
			
			[text replaceOccurrencesOfRegex:[NSSWF:@"(^|\\s)%@(\\s|$)", regex]
								 withString:[NSSWF:@"$1<img src=\"%@\" alt=\"%@\" />$2", path, smiley]];
		}
	}
	
	[text replaceOccurrencesOfRegex:@"\\[b\\](.+?)\\[/b\\]" withString:@"<b>$1</b>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[u\\](.+?)\\[/u\\]" withString:@"<u>$1</u>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[i\\](.+?)\\[/i\\]" withString:@"<i>$1</i>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[color=(.+?)\\](.+?)\\[/color\\]" withString:@"<span style=\"color: $1\">$2</span>" options:RKLCaseless];
	
	[text replaceOccurrencesOfRegex:@"\\[url=(.+?)\\](.+?)\\[/url\\]" withString:@"<a href=\"$1\">$2</a>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[url](.+?)\\[/url\\]" withString:@"<a href=\"$1\">$1</a>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[email=(.+?)\\](.+?)\\[/email\\]" withString:@"<a href=\"mailto:$1\">$2</a>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[email](.+?)\\[/email\\]" withString:@"<a href=\"mailto:$1\">$1</a>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:@"\\[img](.+?)\\[/img\\]" withString:@"<img src=\"$1\" alt=\"$1\" />" options:RKLCaseless];

	[text replaceOccurrencesOfRegex:@"\\[quote=(.+?)\\](.+?)\\[/quote\\]"
						 withString:[NSSWF:@"<blockquote><b>%@</b><br />$2</blockquote>", NSLS(@"$1 wrote:", @"Board quote (nick)")]
							options:RKLCaseless];

	[text replaceOccurrencesOfRegex:@"\\[quote\\](.+?)\\[/quote\\]" withString:@"<blockquote>$1</blockquote>" options:RKLCaseless];
	
	string = [[_postTemplate mutableCopy] autorelease];

	[string replaceOccurrencesOfString:@"<? from ?>" withString:[NSSWF:NSLS(@"%@ (%@)", @"Post from (nick, login)"), [post nick], [post login]]];

	[string replaceOccurrencesOfString:@"<? subject ?>" withString:[post subject]];
	
	if([post isUnread])
		[string replaceOccurrencesOfString:@"<? unreadimage ?>" withString:@"<img class=\"postunread\" src=\"UnreadPost.png\" />"];
	else
		[string replaceOccurrencesOfString:@"<? unreadimage ?>" withString:@""];
	
	[string replaceOccurrencesOfString:@"<? postdate ?>" withString:[_dateFormatter stringFromDate:[post postDate]]];
	
	if([post editDate])
		[string replaceOccurrencesOfString:@"<? editdate ?>" withString:[_dateFormatter stringFromDate:[post editDate]]];
	else
		[string replaceOccurrencesOfString:@"<div class=\"posteditdate\"><? editdate ?></div>" withString:@""];
	
	[string replaceOccurrencesOfString:@"<? body ?>" withString:text];
	[string replaceOccurrencesOfString:@"<? postid ?>" withString:[post postID]];
	
	if([account boardAddPosts])
		[string replaceOccurrencesOfString:@"<? replydisabled ?>" withString:@""];
	else
		[string replaceOccurrencesOfString:@"<? replydisabled ?>" withString:@"disabled=\"disabled\""];
		
	if([account boardEditAllPosts] || ([account boardEditOwnPosts] && [[[[post connection] URL] user] isEqualToString:[post login]]))
		[string replaceOccurrencesOfString:@"<? editdisabled ?>" withString:@""];
	else
		[string replaceOccurrencesOfString:@"<? editdisabled ?>" withString:@"disabled=\"disabled\""];

	if([account boardDeletePosts])
		[string replaceOccurrencesOfString:@"<? deletedisabled ?>" withString:@""];
	else
		[string replaceOccurrencesOfString:@"<? deletedisabled ?>" withString:@"disabled=\"disabled\""];

	[string replaceOccurrencesOfString:@"<? replystring ?>" withString:NSLS(@"Reply", @"Reply post button title")];
	[string replaceOccurrencesOfString:@"<? editstring ?>" withString:NSLS(@"Edit", @"Edit post button title")];
	[string replaceOccurrencesOfString:@"<? deletestring ?>" withString:NSLS(@"Delete", @"Delete post button title")];
	
	return string;
}



- (NSString *)_textForPostText:(NSString *)text {
	NSMutableString		*string;
	
	string = [[text mutableCopy] autorelease];
	
	[string replaceOccurrencesOfRegex:[WCChatController URLRegex] withString:@"[url]$1[/url]" options:RKLCaseless];
	[string replaceOccurrencesOfRegex:[WCChatController schemelessURLRegex] withString:@"[url]$1[/url]" options:RKLCaseless];
	[string replaceOccurrencesOfRegex:[WCChatController mailtoURLRegex] withString:@"[email]$1[/email]" options:RKLCaseless];
	
	return string;
}



#pragma mark -

- (void)_reloadLocationsAndSelectBoard:(WCBoard *)board {
	[_locationPopUpButton removeAllItems];
	
	[self _addLocationsForChildrenOfBoard:_boards level:0];
	
	if(board)
		[_locationPopUpButton selectItemWithRepresentedObject:board];
	else
		[_locationPopUpButton selectItemAtIndex:0];
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
		
		[_locationPopUpButton addItem:item];
		
		[self _addLocationsForChildrenOfBoard:childBoard level:level + 1];
	}
}



- (void)_updatePermissions {
	NSEnumerator	*enumerator;
	NSArray			*array;
	NSString		*selectedOwner, *selectedGroup;
	NSMenuItem		*item;
	WCBoard			*board;
	
	board = [_locationPopUpButton representedObjectOfSelectedItem];
	
	selectedOwner = [_addOwnerPopUpButton titleOfSelectedItem];
	
	[_addOwnerPopUpButton removeAllItems];
	[_addOwnerPopUpButton addItem:[NSMenuItem itemWithTitle:NSLS(@"None", @"Create board owner popup title") tag:1]];
	
	array = [[[board connection] accounts] userNames];
	
	if([array count] > 0) {
		[_addOwnerPopUpButton addItem:[NSMenuItem separatorItem]];
		[_addOwnerPopUpButton addItemsWithTitles:array];

		if(selectedOwner && [_addOwnerPopUpButton indexOfItemWithTitle:selectedOwner] != -1)
			[_addOwnerPopUpButton selectItemWithTitle:selectedOwner];
		else
			[_addOwnerPopUpButton selectItemWithTitle:[[[board connection] URL] user]];
	}
	
	[_setOwnerPopUpButton removeAllItems];
	
	enumerator = [[_addOwnerPopUpButton itemArray] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[_setOwnerPopUpButton addItem:[[item copy] autorelease]];

	[_setOwnerPopUpButton selectItemAtIndex:[_addOwnerPopUpButton indexOfSelectedItem]];
	
	selectedGroup = [_addGroupPopUpButton titleOfSelectedItem];
	
	[_addGroupPopUpButton removeAllItems];
	[_addGroupPopUpButton addItem:[NSMenuItem itemWithTitle:NSLS(@"None", @"Create board group popup title") tag:1]];
	
	array = [[[board connection] accounts] groupNames];
	
	if([array count] > 0) {
		[_addGroupPopUpButton addItem:[NSMenuItem separatorItem]];
		[_addGroupPopUpButton addItemsWithTitles:array];

		if(selectedGroup && [_addGroupPopUpButton indexOfItemWithTitle:selectedGroup] != -1)
			[_addGroupPopUpButton selectItemWithTitle:selectedGroup];
		else
			[_addGroupPopUpButton selectItemAtIndex:0];
	}
	
	[_setGroupPopUpButton removeAllItems];
	
	enumerator = [[_addGroupPopUpButton itemArray] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[_setGroupPopUpButton addItem:[[item copy] autorelease]];

	[_setGroupPopUpButton selectItemAtIndex:[_addGroupPopUpButton indexOfSelectedItem]];
	
	[_addGroupPermissionsPopUpButton selectItemWithTag:0];
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
	_readPosts			= [[NSMutableSet alloc] initWithArray:[WCSettings objectForKey:WCReadBoardPosts]];
	
	_headerTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"PostHeader" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_footerTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"PostFooter" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_postTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"Post" ofType:@"html"]
															encoding:NSUTF8StringEncoding
															   error:NULL];
	
	[_headerTemplate replaceOccurrencesOfString:@"<? fromstring ?>" withString:NSLS(@"From", @"Post header")];
	[_headerTemplate replaceOccurrencesOfString:@"<? subjectstring ?>" withString:NSLS(@"Subject", @"Post header")];
	[_headerTemplate replaceOccurrencesOfString:@"<? postdatestring ?>" withString:NSLS(@"Post Date", @"Post header")];
	[_headerTemplate replaceOccurrencesOfString:@"<? editdatestring ?>" withString:NSLS(@"Edit Date", @"Post header")];
	
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_errorQueue release];
	
	[_boards release];
	[_selectedBoard release];
	
	[_threadFont release];
	[_threadColor release];
	[_backgroundColor release];
	[_dateFormatter release];
	
	[_headerTemplate release];
	[_footerTemplate release];
	[_postTemplate release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;
	NSInvocation	*invocation;
	NSUInteger		style;
	
	_errorQueue = [[WCErrorQueue alloc] initWithWindow:[self window]];
	
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
	[[_unreadBoardTableColumn dataCell] setImageAlignment:NSImageAlignRight];
	
	if([_boardsOutlineView respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
		style = 1; // NSTableViewSelectionHighlightStyleSourceList
	
		invocation = [NSInvocation invocationWithTarget:_boardsOutlineView action:@selector(setSelectionHighlightStyle:)];
		[invocation setArgument:&style atIndex:2];
		[invocation invoke];
	}

	[_threadsTableView setDefaultHighlightedTableColumnIdentifier:@"Time"];
	[_threadsTableView setDefaultSortOrder:WISortAscending];
	[_threadsTableView setAllowsUserCustomization:YES];
	[_threadsTableView setAutosaveName:@"Threads"];
    [_threadsTableView setAutosaveTableColumns:YES];
	
	[[_unreadThreadTableColumn headerCell] setImage:[NSImage imageNamed:@"UnreadHeader"]];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _themeDidChange];
	[self _validate];
	
	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSWindow *)window {
	NSEnumerator		*enumerator;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	BOOL				changedUnread = NO;
	
	thread = [self _selectedThread];
	
	if(thread) {
		enumerator = [[thread posts] objectEnumerator];
		
		while((post = [enumerator nextObject])) {
			if([post isUnread]) {
				[post setUnread:NO];
				
				changedUnread = YES;
			}
		}
		
		if([thread isUnread]) {
			[thread setUnread:NO];
			
			changedUnread = YES;
		}
		
		if(changedUnread) {
			[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
			
			[self _savePosts];
			
			[_boardsOutlineView setNeedsDisplay:YES];
		}
	}
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
	[connection addObserver:self selector:@selector(wiredBoardPermissionsChanged:) messageName:@"wired.board.permissions_changed"];
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
	
	[self _reloadThread];
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
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
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
			
			if(![_readPosts containsObject:[post postID]])
				[post setUnread:YES];
			
			if(thread) {
				[thread addPost:post];
				
				if([post isUnread])
					[thread setUnread:YES];
			} else {
				thread = [WCBoardThread threadWithPost:post connection:connection];
				
				[board addThread:thread sortedUsingSelector:[self _sortSelector]];
				[thread setBoard:board];
			}
		}
	}
	else if([[message name] isEqualToString:@"wired.board.post_list.done"]) {
		[_receivedBoards addObject:[connection URL]];

		[_threadsTableView reloadData];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
	}
}



- (void)wiredBoardBoardAdded:(WIP7Message *)message {
	WCServerConnection	*connection;
	WCBoard				*board, *parent, *selectedBoard;
	WCBoardThread		*selectedThread;
	NSUInteger			index;
	
	connection		= [message contextInfo];
	board			= [WCBoard boardWithMessage:message connection:connection];
	parent			= [[_boards boardForConnection:connection] boardForPath:[board path]];
	selectedBoard	= [self _selectedBoard];
	selectedThread	= [self _selectedThread];
	
	[parent addBoard:board];

	[_boardsOutlineView reloadData];
	[_boardsOutlineView expandItem:parent];
	
	if(selectedBoard) {
		index = [_boardsOutlineView rowForItem:selectedBoard];
		
		[_boardsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		
		if(selectedThread)
			[self _reselectThread:selectedThread];
		
		[self _reloadThread];
	}
	
	[self _reloadLocationsAndSelectBoard:[_locationPopUpButton representedObjectOfSelectedItem]];
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
	
	[self _reloadLocationsAndSelectBoard:[_locationPopUpButton representedObjectOfSelectedItem]];
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
	
	[self _reloadLocationsAndSelectBoard:[_locationPopUpButton representedObjectOfSelectedItem]];
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
	
	[self _reloadLocationsAndSelectBoard:[_locationPopUpButton representedObjectOfSelectedItem]];
	[self _validate];
}



- (void)wiredBoardPermissionsChanged:(WIP7Message *)message {
	NSString			*path;
	WCServerConnection	*connection;
	WCBoard				*board;
	NSUInteger			permissions;
	WIP7Bool			value;
	
	connection	= [message contextInfo];
	path		= [message stringForName:@"wired.board.board"];
	board		= [[_boards boardForConnection:connection] boardForPath:path];
	
	[board setOwner:[message stringForName:@"wired.board.owner"]];
	[board setGroup:[message stringForName:@"wired.board.group"]];
	
	permissions = 0;
	
	if([message getBool:&value forName:@"wired.board.owner.read"] && value)
		permissions |= WCBoardOwnerRead;
	
	if([message getBool:&value forName:@"wired.board.owner.write"] && value)
		permissions |= WCBoardOwnerWrite;
	
	if([message getBool:&value forName:@"wired.board.group.read"] && value)
		permissions |= WCBoardGroupRead;
	
	if([message getBool:&value forName:@"wired.board.group.write"] && value)
		permissions |= WCBoardGroupWrite;
	
	if([message getBool:&value forName:@"wired.board.everyone.read"] && value)
		permissions |= WCBoardEveryoneRead;
	
	if([message getBool:&value forName:@"wired.board.everyone.write"] && value)
		permissions |= WCBoardEveryoneWrite;
	
	[board setPermissions:permissions];

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
		
		if(selectedThread)
			[self _reselectThread:selectedThread];
		
		[self _reloadThread];
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
	[thread setBoard:newBoard];
	[thread release];
	
	if(oldBoard == [self _selectedBoard] || newBoard == [self _selectedBoard]) {
		[_threadsTableView reloadData];
		
		if(selectedThread)
			[self _reselectThread:selectedThread];
		
		[self _reloadThread];
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
	
	[post setUnread:YES];

	if(board == [self _selectedBoard])
		selectedThread = [self _selectedThread];
	else
		selectedThread = NULL;
	
	thread = [board threadWithID:[post threadID]];
	
	if(thread) {
		[thread addPost:post];
		[thread setUnread:YES];
	} else {
		thread = [WCBoardThread threadWithPost:post connection:connection];
		
		[board addThread:thread sortedUsingSelector:[self _sortSelector]];
		[thread setBoard:board];
	}
	
	if(board == [self _selectedBoard]) {
		[_threadsTableView reloadData];
		
		if(thread == selectedThread)
			[self _reloadThread];
		else if(selectedThread)
			[self _reselectThread:selectedThread];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
	
	[connection triggerEvent:WCEventsBoardPostReceived info1:[post nick] info2:[post text]];
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
	
	[post setUnread:YES];
	[thread setUnread:YES];

	[_readPosts removeObject:[post postID]];

	[self _savePosts];
	
	[_boardsOutlineView setNeedsDisplay:YES];
	[_threadsTableView setNeedsDisplay:YES];
	
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
	
	[post retain];
	
	[thread removePost:post];
	
	if([thread numberOfPosts] == 0) {
		[board removeThread:thread];
	} else {
		[_readPosts removeObject:[post postID]];

		[self _savePosts];

		if(![thread numberOfUnreadPosts] == 0) {
			[thread setUnread:NO];
			
			[_boardsOutlineView setNeedsDisplay:YES];
			[_threadsTableView setNeedsDisplay:YES];
		}
	}
			
	[post release];
	
	if(board == [self _selectedBoard]) {
		[_threadsTableView reloadData];

		[self _reloadThread];
		
		if(selectedThread)
			[self _reselectThread:selectedThread];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
}



- (void)wiredBoardAddBoardReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardRenameBoardReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardMoveBoardReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardDeleteBoardReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardSetPermissionsReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardAddThreadReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardMoveThreadReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardDeleteThreadReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardAddPostReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardEditPostReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredBoardDeletePostReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
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



- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)action request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
	if([[action objectForKey:WebActionNavigationTypeKey] unsignedIntegerValue] == WebNavigationTypeOther) {
		[listener use];
	} else {
		[listener ignore];
		
		[[NSWorkspace sharedWorkspace] openURL:[action objectForKey:WebActionOriginalURLKey]];
	}
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
		return (board != NULL && [account boardAddThreads]);
	else if(selector == @selector(deleteThread:))
		return (board != NULL && thread != NULL && [account boardDeleteThreads]);
	
	return YES;
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
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
	
	if(selector == @selector(renameBoard:))
		return (board != NULL && [board isModifiable] && connected && [account boardRenameBoards]);
	else if(selector == @selector(changePermissions:))
		return (board != NULL && [board isModifiable] && connected && [account boardSetPermissions]);
	else if(selector == @selector(markAsRead:) || @selector(markAsUnread:))
		return (board != NULL && thread != NULL);
	
	return YES;
}



#pragma mark -

- (void)submitSheet:(id)sender {
	BOOL	valid = YES;
	
	if([sender window] == _addBoardPanel)
		valid = ([[_nameTextField stringValue] length] > 0 && [_addOwnerPermissionsPopUpButton tagOfSelectedItem] > 0);
	else if([sender window] == _setPermissionsPanel)
		valid = ([_setOwnerPermissionsPopUpButton tagOfSelectedItem] > 0);
	else if([sender window] == _postPanel)
		valid = ([[_subjectTextField stringValue] length] > 0 && [[_postTextView string] length] > 0);
	
	if(valid)
		[super submitSheet:sender];
}



#pragma mark -

- (BOOL)showNextUnreadThread {
	WCBoardThread	*thread;
	NSRect			rect;
	
	if([[[self window] firstResponder] isKindOfClass:[NSTextView class]])
		return NO;

	rect = [[[[[_threadWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y += 0.9 * rect.size.height;
	
	if([[[[_threadWebView mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return YES;
	
	thread = [_boards nextUnreadThreadStartingAtBoard:[self _selectedBoard]
											   thread:[self _selectedThread]
									forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];
	
	if(!thread)
		thread = [_boards nextUnreadThreadStartingAtBoard:NULL thread:NULL forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];
	
	if(thread) {
		[[self window] makeFirstResponder:_threadsTableView];
		
		[self _selectThread:thread];
		
		return YES;
	}
	
	return NO;
}



- (BOOL)showPreviousUnreadThread {
	WCBoardThread	*thread;
	NSRect			rect;
	
	if([[[self window] firstResponder] isKindOfClass:[NSTextView class]])
		return NO;

	rect = [[[[[_threadWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y -= 0.9 * rect.size.height;
	
	if([[[[_threadWebView mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return YES;
	
	thread = [_boards previousUnreadThreadStartingAtBoard:[self _selectedBoard]
												   thread:[self _selectedThread]
										forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];
	
	if(!thread)
		thread = [_boards previousUnreadThreadStartingAtBoard:NULL thread:NULL forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];

	if(thread) {
		[[self window] makeFirstResponder:_threadsTableView];
		
		[self _selectThread:thread];
		
		return YES;
	}
	
	return NO;
}



- (NSUInteger)numberOfUnreadThreads {
	return [_boards numberOfUnreadThreadsForConnection:NULL includeChildBoards:YES];
}



- (NSUInteger)numberOfUnreadThreadsForConnection:(WCServerConnection *)connection {
	return [_boards numberOfUnreadThreadsForConnection:connection includeChildBoards:YES];
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
	
	[_subjectTextField setStringValue:subject];
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
		[message setString:[_subjectTextField stringValue] forName:@"wired.board.subject"];
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
	
	[_subjectTextField setStringValue:[post subject]];
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
		[message setString:[_subjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[self _textForPostText:[_postTextView string]] forName:@"wired.board.text"];
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
	[self _updatePermissions];
	
	[_addOwnerPermissionsPopUpButton selectItemWithTag:WCBoardOwnerRead | WCBoardOwnerWrite];
	[_addGroupPermissionsPopUpButton selectItemWithTag:0];
	[_addEveryonePermissionsPopUpButton selectItemWithTag:WCBoardEveryoneRead | WCBoardEveryoneWrite];

	[_addBoardPanel makeFirstResponder:_nameTextField];

	[NSApp beginSheet:_addBoardPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addBoardPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)addBoardPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*path, *owner, *group;
	WIP7Message		*message;
	WCBoard			*board;
	NSUInteger		ownerPermissions, groupPermissions, everyonePermissions;
	
	if(returnCode == NSOKButton) {
		board = [_locationPopUpButton representedObjectOfSelectedItem];
		
		if(board && [[board connection] isConnected] && [[_nameTextField stringValue] length] > 0) {
			message = [WIP7Message messageWithName:@"wired.board.add_board" spec:WCP7Spec];
			
			if([[board path] isEqualToString:@"/"])
				path = [_nameTextField stringValue];
			else
				path = [[board path] stringByAppendingPathComponent:[_nameTextField stringValue]];
			
			[message setString:path forName:@"wired.board.board"];

			owner					= ([_addOwnerPopUpButton tagOfSelectedItem] == 0) ? [_addOwnerPopUpButton titleOfSelectedItem] : @"";
			ownerPermissions		= [_addOwnerPermissionsPopUpButton tagOfSelectedItem];
			group					= ([_addGroupPopUpButton tagOfSelectedItem] == 0) ? [_addGroupPopUpButton titleOfSelectedItem] : @"";
			groupPermissions		= [_addGroupPermissionsPopUpButton tagOfSelectedItem];
			everyonePermissions		= [_addEveryonePermissionsPopUpButton tagOfSelectedItem];
			
			[message setString:owner forName:@"wired.board.owner"];
			[message setBool:(ownerPermissions & WCBoardOwnerRead) forName:@"wired.board.owner.read"];
			[message setBool:(ownerPermissions & WCBoardOwnerWrite) forName:@"wired.board.owner.write"];
			[message setString:group forName:@"wired.board.group"];
			[message setBool:(groupPermissions & WCBoardGroupRead) forName:@"wired.board.group.read"];
			[message setBool:(groupPermissions & WCBoardGroupWrite) forName:@"wired.board.group.write"];
			[message setBool:(everyonePermissions & WCBoardEveryoneRead) forName:@"wired.board.everyone.read"];
			[message setBool:(everyonePermissions & WCBoardEveryoneWrite) forName:@"wired.board.everyone.write"];

			[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardAddBoardReply:)];
		}
	}
	
	[_addBoardPanel close];
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



- (IBAction)changePermissions:(id)sender {
	WCBoard		*board;
	
	[self _updatePermissions];
	
	board = [self _selectedBoard];
	
	if([[board owner] length] > 0 && [_setOwnerPopUpButton indexOfItemWithTitle:[board owner]] != -1)
		[_setOwnerPopUpButton selectItemWithTitle:[board owner]];
	else
		[_setOwnerPopUpButton selectItemAtIndex:0];

	[_setOwnerPermissionsPopUpButton selectItemWithTag:([board permissions]) & (WCBoardOwnerWrite | WCBoardOwnerRead)];

	if([[board group] length] > 0 && [_setGroupPopUpButton indexOfItemWithTitle:[board group]] != -1)
		[_setGroupPopUpButton selectItemWithTitle:[board group]];
	else
		[_setGroupPopUpButton selectItemAtIndex:0];

	[_setGroupPermissionsPopUpButton selectItemWithTag:([board permissions]) & (WCBoardGroupWrite | WCBoardGroupRead)];

	[_setEveryonePermissionsPopUpButton selectItemWithTag:([board permissions]) & (WCBoardEveryoneWrite | WCBoardEveryoneRead)];

	[NSApp beginSheet:_setPermissionsPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(changePermissionsPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[board retain]];
}



- (void)changePermissionsPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*owner, *group;
	WIP7Message		*message;
	WCBoard			*board = contextInfo;
	NSUInteger		ownerPermissions, groupPermissions, everyonePermissions;
	
	if(returnCode == NSOKButton) {
		owner					= ([_setOwnerPopUpButton tagOfSelectedItem] == 0) ? [_setOwnerPopUpButton titleOfSelectedItem] : @"";
		ownerPermissions		= [_setOwnerPermissionsPopUpButton tagOfSelectedItem];
		group					= ([_setGroupPopUpButton tagOfSelectedItem] == 0) ? [_setGroupPopUpButton titleOfSelectedItem] : @"";
		groupPermissions		= [_setGroupPermissionsPopUpButton tagOfSelectedItem];
		everyonePermissions		= [_setEveryonePermissionsPopUpButton tagOfSelectedItem];

		message = [WIP7Message messageWithName:@"wired.board.set_permissions" spec:WCP7Spec];
		[message setString:[board path] forName:@"wired.board.board"];
		[message setString:owner forName:@"wired.board.owner"];
		[message setBool:(ownerPermissions & WCBoardOwnerRead) forName:@"wired.board.owner.read"];
		[message setBool:(ownerPermissions & WCBoardOwnerWrite) forName:@"wired.board.owner.write"];
		[message setString:group forName:@"wired.board.group"];
		[message setBool:(groupPermissions & WCBoardGroupRead) forName:@"wired.board.group.read"];
		[message setBool:(groupPermissions & WCBoardGroupWrite) forName:@"wired.board.group.write"];
		[message setBool:(everyonePermissions & WCBoardEveryoneRead) forName:@"wired.board.everyone.read"];
		[message setBool:(everyonePermissions & WCBoardEveryoneWrite) forName:@"wired.board.everyone.write"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardSetPermissionsReply:)];
	}
	
	[board release];
	[_setPermissionsPanel close];
}



- (IBAction)location:(id)sender {
	[self _updatePermissions];
}



- (IBAction)addThread:(id)sender {
	WCBoard			*board;
	
	board = [self _selectedBoard];
	
	if(!board)
		return;
	
	[_subjectTextField setStringValue:@""];
	[_postTextView setString:@""];
	[_postButton setTitle:NSLS(@"Create", @"New thread button title")];
	
	[_postPanel makeFirstResponder:_subjectTextField];
	
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
		[message setString:[_subjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[self _textForPostText:[_postTextView string]] forName:@"wired.board.text"];
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



- (IBAction)markAsRead:(id)sender {
	[self _markSelectedThreadsAsUnread:NO];
}



- (IBAction)markAsUnread:(id)sender {
	[self _markSelectedThreadsAsUnread:YES];
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
	if(tableColumn == _boardTableColumn) {
		return [item name];
	}
	else if(tableColumn == _unreadBoardTableColumn) {
		return [NSImage imageWithPillForCount:[item numberOfUnreadThreadsForConnection:NULL includeChildBoards:NO]
							   inActiveWindow:([NSApp keyWindow] == [self window])
								onSelectedRow:([_boardsOutlineView rowForItem:item] == [_boardsOutlineView selectedRow])];
	}
	
	return NULL;
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _boardTableColumn) {
		if([item numberOfUnreadThreadsForConnection:NULL includeChildBoards:NO] > 0)
			[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
		else
			[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
	}
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return [item isExpandable];
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	WCBoard			*board;
	NSInteger		row;
	
	row = [_boardsOutlineView selectedRow];
	
	if(row < 0) {
		[_selectedBoard release];
		_selectedBoard = NULL;
	} else {
		board = [_boardsOutlineView itemAtRow:row];
		
		[board retain];
		[_selectedBoard release];
		
		_selectedBoard = board;
	}
	
	[[self _selectedBoard] sortThreadsUsingSelector:[self _sortSelector]];
	
	[_threadsTableView reloadData];
	[_threadsTableView deselectAll:self];
	
	[self _validate];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	WCServerConnection		*connection;
	WCBoard					*board = item;
	
	connection = [board connection];
	
	return ([board isModifiable] && [connection isConnected] && [[connection account] boardRenameBoards]);
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
	
	if(tableColumn == _unreadThreadTableColumn)
		return [thread isUnread] ? [NSImage imageNamed:@"UnreadThread"] : NULL;
	if(tableColumn == _subjectTableColumn)
		return [[thread postAtIndex:0] subject];
	else if(tableColumn == _nickTableColumn)
		return [[thread postAtIndex:0] nick];
	else if(tableColumn == _timeTableColumn)
		return [_dateFormatter stringFromDate:[[thread postAtIndex:0] postDate]];
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCBoardThread		*thread;
	
	thread = [self _threadAtIndex:row];
	
	if([thread isUnread])
		[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
	else
		[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
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
