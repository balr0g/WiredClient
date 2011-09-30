/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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
#import "WCApplicationController.h"
#import "WCBoard.h"
#import "WCBoardPost.h"
#import "WCBoards.h"
#import "WCBoardsButtonCell.h"
#import "WCBoardThread.h"
#import "WCBoardThreadController.h"
#import "WCChatController.h"
#import "WCErrorQueue.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCPreferences.h"
#import "WCServerConnection.h"
#import "WCSourceSplitView.h"

#define WCBoardPboardType									@"WCBoardPboardType"
#define WCThreadPboardType									@"WCThreadPboardType"


NSString * const WCBoardsDidChangeUnreadCountNotification	= @"WCBoardsDidChangeUnreadCountNotification";


@interface WCBoards(Private)

- (void)_validate;
- (BOOL)_validateAddThread;
- (BOOL)_validateDeleteThread;
- (BOOL)_validateMarkAsRead;
- (BOOL)_validateMarkAsUnread;

- (void)_themeDidChange;

- (void)_getBoardsForConnection:(WCServerConnection *)connection;
- (void)_saveBoards;
- (void)_updateSelectedBoard;

- (WCBoardThread *)_threadAtIndex:(NSUInteger)index;
- (WCBoard *)_selectedBoard;
- (WCBoardThread *)_selectedThread;
- (NSArray *)_selectedThreads;

- (BOOL)_isUnreadThread:(WCBoardThread *)thread;
- (void)_saveReadIDs;

- (void)_reloadFilters;
- (void)_saveFilters;

- (void)_reloadThread;
- (void)_selectThread:(WCBoardThread *)thread;
- (void)_reselectThread:(WCBoardThread *)thread;
- (void)_markThreads:(NSArray *)threads asUnread:(BOOL)unread;
- (void)_markBoard:(WCBoard *)board asUnread:(BOOL)unread;
- (SEL)_sortSelector;

- (NSString *)_plainTextForPostText:(NSString *)text;
- (NSString *)_BBCodeTextForPostText:(NSString *)text;
- (void)_insertBBCodeWithStartTag:(NSString *)startTag endTag:(NSString *)endTag;
- (NSAttributedString *)_attributedPostString;

- (void)_reloadBoardListsSelectingBoard:(WCBoard *)board;
- (void)_reloadBoardListsWithChildrenOfBoard:(WCBoard *)board level:(NSUInteger)level;
- (void)_updatePermissions;

@end


@implementation WCBoards(Private)

- (void)_validate {
	WCServerConnection		*connection;
	WCBoard					*board;
	
	board			= [self _selectedBoard];
	connection		= [board connection];
	
	if([board isKindOfClass:[WCSmartBoard class]]) {
		[_deleteBoardButton setEnabled:YES];
	} else {
		[_deleteBoardButton setEnabled:(board != NULL &&
										![board isRootBoard] &&
										[connection isConnected] &&
										[[connection account] boardDeleteBoards])];
	}
	
	[[[self window] toolbar] validateVisibleItems];
}



- (BOOL)_validateAddThread {
	WCServerConnection		*connection;
	WCUserAccount			*account;
	WCBoard					*board;
	
	board		= [self _selectedBoard];
	connection	= [board connection];
	account		= [connection account];

	return (board != NULL &&
			connection != NULL && [connection isConnected] &&
			[board isWritable] &&
			[account boardAddThreads]);
}



- (BOOL)_validateDeleteThread {
	NSEnumerator			*enumerator;
	NSArray					*threads;
	WCServerConnection		*connection;
	WCUserAccount			*account;
	WCBoard					*board;
	WCBoardThread			*thread;
	BOOL					delete;
	
	board		= [self _selectedBoard];
	threads		= [self _selectedThreads];
	connection	= [board connection];
	account		= [connection account];
	
	if([account boardDeleteAllThreadsAndPosts]) {
		delete = YES;
	}
	else if([account boardDeleteOwnThreadsAndPosts]) {
		delete			= YES;
		enumerator		= [threads objectEnumerator];
		
		while((thread = [enumerator nextObject])) {
			if(![thread isOwnThread])
				delete = NO;
		}
	}
	else {
		delete = NO;
	}

	return (board != NULL &&
			[threads count] > 0 &&
			connection != NULL && [connection isConnected] &&
			[board isWritable] &&
			delete);
}



- (BOOL)_validatePostReply {
	WCServerConnection		*connection;
	WCUserAccount			*account;
	WCBoard					*board;
	
	board		= [self _selectedBoard];
	connection	= [board connection];
	account		= [connection account];

	return (board != NULL &&
			[[self _selectedThreads] count] == 1 &&
			connection != NULL && [connection isConnected] &&
			[board isWritable] &&
			[account boardAddPosts]);
}



- (BOOL)_validateMarkAsRead {
	NSEnumerator		*enumerator;
	NSArray				*threads;
	WCBoard				*board;
	WCBoardThread		*thread;
	NSUInteger			unread = 0;
	
	board		= [self _selectedBoard];
	threads		= [self _selectedThreads];
	
	if([threads count] > 0) {
		enumerator = [threads objectEnumerator];
		
		while((thread = [enumerator nextObject])) {
			if([thread isUnread])
				unread++;
		}
	} else {
		unread = [board numberOfUnreadThreadsForConnection:NULL includeChildBoards:YES];
	}
	
	return (unread > 0);
}



- (BOOL)_validateMarkAsUnread {
	NSEnumerator		*enumerator;
	NSArray				*threads;
	WCBoard				*board;
	WCBoardThread		*thread;
	
	board		= [self _selectedBoard];
	threads		= [self _selectedThreads];
	
	if([threads count] > 0) {
		enumerator = [threads objectEnumerator];
		
		while((thread = [enumerator nextObject])) {
			if(![thread isUnread])
				return YES;
		}
	} else {
		if([board numberOfThreadsIncludingChildBoards:YES] > [board numberOfUnreadThreadsForConnection:NULL includeChildBoards:YES])
			return YES;
	}
	
	return NO;
}



#pragma mark -

- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [[WCSettings settings] themeWithIdentifier:[[WCSettings settings] objectForKey:WCTheme]];
	
	[_threadController setFont:WIFontFromString([theme objectForKey:WCThemesBoardsFont])];
	[_threadController setTextColor:WIColorFromString([theme objectForKey:WCThemesBoardsTextColor])];
	[_threadController setBackgroundColor:WIColorFromString([theme objectForKey:WCThemesBoardsBackgroundColor])];
	
	[_threadController reloadDataAndScrollToCurrentPosition];
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

		message = [WIP7Message messageWithName:@"wired.board.get_threads" spec:WCP7Spec];
		[connection sendMessage:message fromObserver:self selector:@selector(wiredBoardGetThreadsReply:)];
		
		message = [WIP7Message messageWithName:@"wired.board.subscribe_boards" spec:WCP7Spec];
		[connection sendMessage:message fromObserver:self selector:@selector(wiredBoardSubscribeBoardsReply:)];
	}
}



- (void)_saveBoards {
	NSArray		*boards;
	
	boards = [_boards boardsWithExpansionStatus:NO];
	
	[[WCSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:boards] forKey:WCCollapsedBoards];
}



- (void)_updateSelectedBoard {
	NSEnumerator		*enumerator;
	WCBoardThread		*thread;
	id					item;
	NSInteger			row;
	
	enumerator = [[_selectedBoard threads] objectEnumerator];
	
	while((thread = [enumerator nextObject]))
		[[thread goToLatestReplyButton] removeFromSuperview];
		
	[_selectedBoard release];
	_selectedBoard = NULL;

	if(_searching) {
		_selectedBoard = [_searchBoard retain];
	} else {
		row = [_boardsOutlineView selectedRow];
		
		if(row >= 0) {
			item = [_boardsOutlineView itemAtRow:row];
			
			if([item isRootBoard]) {
				[_boardsOutlineView deselectAll:self];
			} else {
				[item retain];
				[_selectedBoard release];
				
				_selectedBoard = item;
			}
		}
	}
		
	if([_selectedBoard isKindOfClass:[WCSmartBoard class]]) {
		[_selectedBoard removeAllThreads];
		[_selectedBoard addThreads:[_boards threadsMatchingFilter:[_selectedBoard filter] includeChildBoards:YES]];
	}
	
	[_selectedBoard sortThreadsUsingSelector:[self _sortSelector]];
	
	[_threadsTableView reloadData];
	[_threadsTableView deselectAll:self];
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
	
	if(i >= [board numberOfThreads])
		return NULL;
	
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
	NSArray		*threads;
	
	threads = [self _selectedThreads];
	
	if([threads count] != 1)
		return NULL;
	
	return [threads objectAtIndex:0];
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



#pragma mark -

- (BOOL)_isUnreadThread:(WCBoardThread *)thread {
	if(![_readIDs containsObject:[thread threadID]]) {
		if([thread latestReplyID])
			return ![_readIDs containsObject:[thread latestReplyID]];
		else
			return YES;
	}
	
	return NO;
}



- (void)_saveReadIDs {
	[[WCSettings settings] setObject:[_readIDs allObjects] forKey:WCReadBoardPosts];
}



#pragma mark -

- (void)_reloadFilters {
	NSEnumerator		*enumerator;
	WCBoard				*selectedBoard;
	WCBoardThread		*selectedThread;
	id					board;
	
	selectedBoard	= [self _selectedBoard];
	selectedThread	= [self _selectedThread];
	enumerator		= [[_smartBoards boards] objectEnumerator];
	
	while((board = [enumerator nextObject])) {
		if([board isKindOfClass:[WCSmartBoard class]]) {
			if(board != selectedBoard)
				[board removeAllThreads];
			
			[board addThreads:[_boards threadsMatchingFilter:[board filter] includeChildBoards:YES]];
			[board sortThreadsUsingSelector:[self _sortSelector]];
			
			if(board == selectedBoard) {
				[_threadsTableView reloadData];

				[self _reselectThread:selectedThread];
			}
		}
	}
	
	[_boardsOutlineView setNeedsDisplay:YES];
}



- (void)_saveFilters {
	NSEnumerator			*enumerator;
	NSMutableArray			*filters;
	WCBoardThreadFilter		*filter;
	id						board;
	
	filters		= [NSMutableArray array];
	enumerator	= [[_smartBoards boards] objectEnumerator];
	
	while((board = [enumerator nextObject])) {
		if([board isKindOfClass:[WCSmartBoard class]]) {
			filter = [board filter];
			[filter setName:[board name]];
			[filters addObject:filter];
		}
	}
	
	[[WCSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:filters] forKey:WCBoardFilters];
}



#pragma mark -

- (void)_reloadThread {
	WIP7Message			*message;
	WCBoard				*board;
	WCBoardThread		*thread;
	
	board		= [self _selectedBoard];
	thread		= [self _selectedThread];
	
	if(thread) {
		if(![thread isLoaded]) {
			[thread removeAllPosts];
			
			message = [WIP7Message messageWithName:@"wired.board.get_thread" spec:WCP7Spec];
			[message setUUID:[thread threadID] forName:@"wired.board.thread"];
			[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardGetThreadReply:)];
		}
		
		[_threadController setBoard:board];
		[_threadController setThread:thread];
		
		if([thread isLoaded])
			[_threadController reloadData];
	} else {
		[_threadController setBoard:NULL];
		[_threadController setThread:NULL];
		[_threadController reloadData];
	}
}



- (void)_selectThread:(WCBoardThread *)thread {
	WCBoard			*board;
	NSInteger		row;
	
	board = [_boardsByThreadID objectForKey:[thread threadID]];
	
	if(board) {
		row = [_boardsOutlineView rowForItem:board];
		
		if(row >= 0) {
			[_boardsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			
			[self _reselectThread:thread];
		}
	}
}



- (void)_reselectThread:(WCBoardThread *)thread {
	NSUInteger		index;
	
	index = [self _indexOfThread:thread];

	if(index != NSNotFound) {
		[_threadsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[_threadsTableView scrollRowToVisible:index];
	} else {
		[_threadsTableView deselectAll:self];
	}
}



- (void)_markThreads:(NSArray *)threads asUnread:(BOOL)unread {
	NSEnumerator		*enumerator, *postEnumerator;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	enumerator = [threads objectEnumerator];
	
	while((thread = [enumerator nextObject])) {
		if([thread isUnread] != unread)
			[thread setUnread:unread];
		
		postEnumerator = [[thread posts] objectEnumerator];
		
		while((post = [postEnumerator nextObject])) {
			if([post isUnread] != unread) {
				[post setUnread:unread];

				if(unread)
					[_readIDs removeObject:[post postID]];
				else
					[_readIDs addObject:[post postID]];
			}
		}
	}
}



- (void)_markBoard:(WCBoard *)board asUnread:(BOOL)unread {
	NSEnumerator		*enumerator;
	WCBoard				*eachBoard;
	
	[self _markThreads:[board threads] asUnread:unread];

	enumerator = [[board boards] objectEnumerator];
	
	while((eachBoard = [enumerator nextObject])) {
		[self _markThreads:[eachBoard threads] asUnread:unread];
		[self _markBoard:eachBoard asUnread:unread];
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
	else if(tableColumn == _repliesTableColumn)
		return @selector(compareNumberOfReplies:);
	else if(tableColumn == _threadTimeTableColumn)
		return @selector(compareDate:);
	else if(tableColumn == _postTimeTableColumn)
		return @selector(compareLatestReplyDate:);

	return @selector(compareLatestReplyDate:);
}



#pragma mark -

- (NSString *)_plainTextForPostText:(NSString *)text {
	NSMutableString		*string;
	
	string = [[text mutableCopy] autorelease];
	
	while([string replaceOccurrencesOfRegex:@"\\[img\\].*?\\[/img\\]" withString:@"" options:RKLCaseless | RKLMultiline] > 0)
		;
	
	while([string replaceOccurrencesOfRegex:@"\\[.+?\\](.*?)\\[/.+?\\]" withString:@"$1" options:RKLCaseless | RKLMultiline] > 0)
		;
	
	return string;
}



- (NSString *)_BBCodeTextForPostText:(NSString *)text {
	NSMutableString		*string;
	
	string = [[text mutableCopy] autorelease];
	
	[string replaceOccurrencesOfRegex:[NSSWF:@"(^|\\s)(%@)(\\.|,|:|\\?|!)?(\\s|$)", [WCChatController URLRegex]]
						   withString:@"$1[url]$2[/url]$3$4"
							  options:RKLCaseless | RKLMultiline];
	
	[string replaceOccurrencesOfRegex:[NSSWF:@"(^|\\s)(%@)(\\.|,|:|\\?|!)?(\\s|$)", [WCChatController schemelessURLRegex]]
						   withString:@"$1[url]http://$2[/url]$3$4"
							  options:RKLCaseless | RKLMultiline];
	
	[string replaceOccurrencesOfRegex:[NSSWF:@"(^|\\s)(%@)(\\.|,|:|\\?|!)?(\\s|$)", [WCChatController mailtoURLRegex]]
						   withString:@"$1[email]$2[/email]$3$4"
							  options:RKLCaseless | RKLMultiline];
	
	return string;
}



- (void)_insertBBCodeWithStartTag:(NSString *)startTag endTag:(NSString *)endTag {
	NSTextStorage	*textStorage;
	NSString		*string;
	NSRange			range;
	
	range			= [_postTextView selectedRange];
	textStorage		= [_postTextView textStorage];
	string			= [NSSWF:@"%@%@%@", startTag, [[textStorage string] substringWithRange:range], endTag];

	if([_postTextView shouldChangeTextInRange:range replacementString:string]) {
		[textStorage replaceCharactersInRange:range withString:string];
		[_postTextView didChangeText];
	}
	
	range.location += [startTag length];

	[_postTextView setSelectedRange:range];
}



- (NSAttributedString *)_attributedPostString {
	NSMutableAttributedString	*attributedString;
	NSTextAttachment			*attachment;
	NSFileWrapper				*fileWrapper;
	NSBitmapImageRep			*imageRep;
	NSDictionary				*attributes;
	NSData						*data;
	NSString					*string, *mimeType;
	NSRange						range;
	WITextAttachment			*newAttachment;
	NSUInteger					i, length;
	
	attributedString	= [[[_postTextView textStorage] mutableCopy] autorelease];
	length				= [attributedString length];
		
	for(i = 0; i < length; i++) {
		attributes = [attributedString attributesAtIndex:i effectiveRange:&range];
		attachment = [attributes objectForKey:NSAttachmentAttributeName];
		
		if(attachment) {
			if(![attachment isKindOfClass:[WITextAttachment class]]) {
				fileWrapper		= [attachment fileWrapper];
				data			= [fileWrapper regularFileContents];
				imageRep		= [NSBitmapImageRep imageRepWithData:data];
				
				if(imageRep) {
					if([[[fileWrapper preferredFilename] pathExtension] isEqualToString:@"gif"]) {
						mimeType = @"image/gif";
					} else {
						data = [imageRep representationUsingType:NSPNGFileType properties:NULL];
						mimeType = @"image/png";
					}
					
					string = [NSSWF:@"[img]data:%@;base64,%@[/img]", mimeType, [data base64EncodedString]];
					
					if([string length] < 512 * 1024) {
						newAttachment = [[WITextAttachment alloc] initWithFileWrapper:fileWrapper string:string];
						
						[attributedString removeAttribute:NSAttachmentAttributeName range:range];
						[attributedString addAttribute:NSAttachmentAttributeName value:newAttachment range:range];
						
						[newAttachment release];
					}
				}
			}
		}
	}
	
	return attributedString;
}



#pragma mark -

- (void)_reloadBoardListsSelectingBoard:(WCBoard *)board {
	NSInteger		index;
	
	if(!board)
		board = [_boardLocationPopUpButton representedObjectOfSelectedItem];
	
	[_boardLocationPopUpButton removeAllItems];
	[_boardFilterComboBox removeAllItems];
	[_postLocationPopUpButton removeAllItems];
	
	[self _reloadBoardListsWithChildrenOfBoard:_boards level:0];
	
	index = board ? [_boardLocationPopUpButton indexOfItemWithRepresentedObject:board] : 0;
	
	[_boardLocationPopUpButton selectItemAtIndex:index < 0 ? 0 : index];
	[_postLocationPopUpButton selectItemAtIndex:index < 0 ? 0 : index];
}



- (void)_reloadBoardListsWithChildrenOfBoard:(WCBoard *)board level:(NSUInteger)level {
	NSEnumerator		*enumerator;
	NSMenuItem			*item;
	WCBoard				*childBoard;
	
	enumerator = [[board boards] objectEnumerator];
	
	while((childBoard = [enumerator nextObject])) {
		if([childBoard connection]) {
			item = [NSMenuItem itemWithTitle:[childBoard name]];
			[item setRepresentedObject:childBoard];
			[item setIndentationLevel:level];

			if(![childBoard isRootBoard])
				[item setImage:[NSImage imageNamed:@"Board"]];
			
			[_boardLocationPopUpButton addItem:item];
			[_postLocationPopUpButton addItem:[[item copy] autorelease]];
			
			if(![childBoard isRootBoard])
				[_boardFilterComboBox addItemWithObjectValue:[childBoard name]];
			
			[self _reloadBoardListsWithChildrenOfBoard:childBoard level:level + 1];
		}
	}
}



- (void)_updatePermissions {
	NSEnumerator	*enumerator;
	NSArray			*array;
	NSString		*selectedOwner, *selectedGroup;
	NSMenuItem		*item;
	WCBoard			*board;

	board = [_boardLocationPopUpButton representedObjectOfSelectedItem];

	selectedOwner = [_addOwnerPopUpButton titleOfSelectedItem];
	
	[_addOwnerPopUpButton removeAllItems];
	[_addOwnerPopUpButton addItem:[NSMenuItem itemWithTitle:NSLS(@"None", @"Create board owner popup title") tag:1]];
	
	array = [[[[board connection] administration] accountsController] userNames];
	
	if(array) {
		if([array count] > 0) {
			[_addOwnerPopUpButton addItem:[NSMenuItem separatorItem]];
			[_addOwnerPopUpButton addItemsWithTitles:array];

			if(selectedOwner && [_addOwnerPopUpButton indexOfItemWithTitle:selectedOwner] != -1)
				[_addOwnerPopUpButton selectItemWithTitle:selectedOwner];
			else
				[_addOwnerPopUpButton selectItemWithTitle:[[[board connection] URL] user]];
		}
		
		[_permissionsProgressIndicator stopAnimation:self];
	} else {
		[_permissionsProgressIndicator startAnimation:self];
	}
	
	[_setOwnerPopUpButton removeAllItems];
	
	enumerator = [[_addOwnerPopUpButton itemArray] objectEnumerator];
	
	while((item = [enumerator nextObject]))
		[_setOwnerPopUpButton addItem:[[item copy] autorelease]];

	[_setOwnerPopUpButton selectItemAtIndex:[_addOwnerPopUpButton indexOfSelectedItem]];
	
	selectedGroup = [_addGroupPopUpButton titleOfSelectedItem];
	
	[_addGroupPopUpButton removeAllItems];
	[_addGroupPopUpButton addItem:[NSMenuItem itemWithTitle:NSLS(@"None", @"Create board group popup title") tag:1]];
	
	array = [[[[board connection] administration] accountsController] groupNames];
	
	if(array) {
		if([array count] > 0) {
			[_addGroupPopUpButton addItem:[NSMenuItem separatorItem]];
			[_addGroupPopUpButton addItemsWithTitles:array];

			if(selectedGroup && [_addGroupPopUpButton indexOfItemWithTitle:selectedGroup] != -1)
				[_addGroupPopUpButton selectItemWithTitle:selectedGroup];
			else
				[_addGroupPopUpButton selectItemAtIndex:0];
		}
		
		[_permissionsProgressIndicator stopAnimation:self];
	} else {
		[_permissionsProgressIndicator startAnimation:self];
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
	if(selector == @selector(replyToThread) ||
	   selector == @selector(replyToPostWithID:) ||
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
	NSEnumerator			*enumerator;
	NSData					*data;
	WCBoardThreadFilter		*filter;
	WCSmartBoard			*smartBoard;
	
	self = [super initWithWindowNibName:@"Boards"];
	
	_boards					= [[WCBoard rootBoard] retain];
	_searchBoard			= [[WCSearchBoard rootBoard] retain];
	_receivedBoards			= [[NSMutableSet alloc] init];
	_readIDs				= [[NSMutableSet alloc] initWithArray:[[WCSettings settings] objectForKey:WCReadBoardPosts]];
	_boardsByThreadID		= [[NSMutableDictionary alloc] init];

	_smartBoards = [[WCBoard rootBoardWithName:NSLS(@"Smart Boards", @"Smart boards title")] retain];
	[_smartBoards setSorting:1];

	data = [[WCSettings settings] objectForKey:WCCollapsedBoards];
	
	if(data)
		_collapsedBoards = [[NSKeyedUnarchiver unarchiveObjectWithData:data] retain];
	
	data = [[WCSettings settings] objectForKey:WCBoardFilters];
	
	if(data) {
		enumerator = [[NSKeyedUnarchiver unarchiveObjectWithData:data] objectEnumerator];
		
		while((filter = [enumerator nextObject])) {
			smartBoard = [WCSmartBoard smartBoard];
			[smartBoard setName:[filter name]];
			[smartBoard setFilter:filter];
			[_smartBoards addBoard:smartBoard];
		
			if([_smartBoards numberOfBoards] == 1)
				[_boards addBoard:_smartBoards];
		}
	}
	
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
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(accountsControllerAccountsDidChange:)
			   name:WCAccountsControllerAccountsDidChangeNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(boardsDidChangeUnreadCount:)
			   name:WCBoardsDidChangeUnreadCountNotification];

	[self window];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_errorQueue release];
	
	[_boards release];
	[_selectedBoard release];
	[_searchBoard release];
	
	[_boardsByThreadID release];
	
	[_collapsedBoards release];
	
	[_dateFormatter release];
	
	[_receivedBoards release];
	[_readIDs release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar			*toolbar;
	NSInvocation		*invocation;
	NSUInteger			style;
	
	[_postTextView registerForDraggedTypes:[NSArray arrayWithObject:WCFilePboardType]];

	_errorQueue = [[WCErrorQueue alloc] initWithWindow:[self window]];
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Boards"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Boards"];
	
	[_boardsSplitView setAutosaveName:@"Boards"];
	[_threadsSplitView setAutosaveName:@"Threads"];
	
	[_boardsOutlineView registerForDraggedTypes:[NSArray arrayWithObjects:WCBoardPboardType, WCThreadPboardType, NULL]];
	[_boardsOutlineView setTarget:self];
	[_boardsOutlineView setDeleteAction:@selector(deleteBoard:)];
	[_boardsOutlineView expandItem:_smartBoards];
	
	[[_boardTableColumn dataCell] setVerticalTextOffset:3.0];
	[[_unreadBoardTableColumn dataCell] setImageAlignment:NSImageAlignRight];
	
	if([_boardsOutlineView respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
		style = 1; // NSTableViewSelectionHighlightStyleSourceList
	
		invocation = [NSInvocation invocationWithTarget:_boardsOutlineView action:@selector(setSelectionHighlightStyle:)];
		[invocation setArgument:&style atIndex:2];
		[invocation invoke];
	}
	
	[_threadsTableView setDefaultTableColumnIdentifiers:
		[NSArray arrayWithObjects:@"Unread", @"Subject", @"Nick", @"Replies", @"Time", @"PostTime", NULL]];
	[_threadsTableView setDefaultHighlightedTableColumnIdentifier:@"Time"];
	[_threadsTableView setDefaultSortOrder:WISortAscending];
	[_threadsTableView setAllowsUserCustomization:YES];
	[_threadsTableView setAutosaveName:@"Threads"];
    [_threadsTableView setAutosaveTableColumns:YES];
	[_threadsTableView setTarget:self];
	[_threadsTableView setDeleteAction:@selector(deleteThread:)];
	
	[[_unreadThreadTableColumn headerCell] setImage:[NSImage imageNamed:@"UnreadHeader"]];
	
	[_postTextView setContinuousSpellCheckingEnabled:[[WCSettings settings] boolForKey:WCBoardPostContinuousSpellChecking]];
	
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
	NSMutableSet		*readIDs;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	thread = [self _selectedThread];
	
	if(thread) {
		readIDs			= [NSMutableSet set];
		enumerator		= [[thread posts] objectEnumerator];
		
		while((post = [enumerator nextObject])) {
			[post setUnread:NO];
			
			[readIDs addObject:[post postID]];
		}
		
		[thread setUnread:NO];
		
		if([readIDs count] > 0)
			[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification object:readIDs];
	}
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	NSSearchField		*searchField;
	
	if([identifier isEqualToString:@"AddThread"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"New Thread", @"New thread toolbar item")
												content:[NSImage imageNamed:@"NewThread"]
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
	else if([identifier isEqualToString:@"PostReply"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Post Reply", @"Post reply toolbar item")
												content:[NSImage imageNamed:@"PostReply"]
												 target:self
												 action:@selector(postReply:)];
	}
	else if([identifier isEqualToString:@"MarkAsRead"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Mark As Read", @"Mark as read toolbar item")
												content:[NSImage imageNamed:@"MarkAsRead"]
												 target:self
												 action:@selector(markAsRead:)];
	}
	else if([identifier isEqualToString:@"MarkAllAsRead"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Mark All As Read", @"Mark all as read toolbar item")
												content:[NSImage imageNamed:@"MarkAllAsRead"]
												 target:self
												 action:@selector(markAllAsRead:)];
	}
	else if([identifier isEqualToString:@"Search"]) {
		searchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(0.0, 0.0, 300.0, 22.0)] autorelease];
		
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Search", @"Search board toolbar item")
												content:searchField
												 target:self
												 action:@selector(search:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"AddThread",
		@"DeleteThread",
		NSToolbarSpaceItemIdentifier,
		@"PostReply",
		NSToolbarSpaceItemIdentifier,
		@"MarkAsRead",
		@"MarkAllAsRead",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Search",
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
		@"PostReply",
		@"MarkAsRead",
		@"MarkAllAsRead",
		@"Search",
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
	
	if(board)
		[_boards removeBoard:board];
	
	[_boards addBoard:[WCBoard boardWithConnection:connection]];
	
	[_boardsOutlineView reloadData];
	
	[self _updateSelectedBoard];
	
	[_receivedBoards removeObject:[connection URL]];

	[connection addObserver:self selector:@selector(wiredBoardBoardAdded:) messageName:@"wired.board.board_added"];
	[connection addObserver:self selector:@selector(wiredBoardBoardRenamed:) messageName:@"wired.board.board_renamed"];
	[connection addObserver:self selector:@selector(wiredBoardBoardMoved:) messageName:@"wired.board.board_moved"];
	[connection addObserver:self selector:@selector(wiredBoardBoardDeleted:) messageName:@"wired.board.board_deleted"];
	[connection addObserver:self selector:@selector(wiredBoardBoardInfoChanged:) messageName:@"wired.board.board_info_changed"];
	[connection addObserver:self selector:@selector(wiredBoardThreadAdded:) messageName:@"wired.board.thread_added"];
	[connection addObserver:self selector:@selector(wiredBoardThreadChanged:) messageName:@"wired.board.thread_changed"];
	[connection addObserver:self selector:@selector(wiredBoardThreadDeleted:) messageName:@"wired.board.thread_deleted"];
	[connection addObserver:self selector:@selector(wiredBoardThreadMoved:) messageName:@"wired.board.thread_moved"];
	
	[self _validate];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	WCServerConnection		*connection;
	WCBoard					*board;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;

	board = [_boards boardForConnection:connection];
	
	if(board) {
		[_boards removeBoard:board];
		
		[_boardsOutlineView reloadData];
		
		[self _updateSelectedBoard];
	}
	
	[_boards invalidateForConnection:connection];
	
	[connection removeObserver:self];
	
	[self _validate];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	WCServerConnection		*connection;
	WCBoard					*board;

	connection = [notification object];

	if(![connection isKindOfClass:[WCServerConnection class]])
		return;
	
	board = [_boards boardForConnection:connection];
	
	if(board) {
		[_boards removeBoard:board];
		
		[_boardsOutlineView reloadData];
		
		[self _updateSelectedBoard];
	}
	
	[_boards invalidateForConnection:[notification object]];
	
	[connection removeObserver:self];

	[self _validate];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
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
	
	[_threadController reloadDataAndScrollToCurrentPosition];
}



- (void)accountsControllerAccountsDidChange:(NSNotification *)notification {
	[self _updatePermissions];
}



- (void)boardsDidChangeUnreadCount:(NSNotification *)notification {
	NSSet		*readIDs;
	
	readIDs = [notification object];
	
	if(readIDs)
		[_readIDs addObjectsFromArray:[readIDs allObjects]];
	
	[self _saveReadIDs];
	[self _reloadFilters];

	[_boardsOutlineView setNeedsDisplay:YES];
	[_threadsTableView setNeedsDisplay:YES];
	
	[_boardsOutlineView reloadData];
}



- (void)wiredBoardGetBoardsReply:(WIP7Message *)message {
	NSEnumerator		*enumerator;
	WCServerConnection	*connection;
	WCBoard				*board, *parent, *collapsedBoard, *childBoard;
	NSInteger			row;
	
	connection = [message contextInfo];

	if([[message name] isEqualToString:@"wired.board.board_list"]) {
		board		= [WCBoard boardWithMessage:message connection:connection];
		parent		= [[_boards boardForConnection:connection] boardForPath:[board path]];
		
		[parent addBoard:board];
	}
	else if([[message name] isEqualToString:@"wired.board.board_list.done"]) {
		_expandingBoards = YES;
		
		board = [_boards boardForConnection:connection];
		
		[_boardsOutlineView reloadData];
		[_boardsOutlineView expandItem:board expandChildren:YES];
		
		enumerator = [_collapsedBoards reverseObjectEnumerator];
		
		while((collapsedBoard = [enumerator nextObject])) {
			if([collapsedBoard belongsToConnection:connection]) {
				childBoard = [board boardForPath:[collapsedBoard path]];
				
				[_boardsOutlineView collapseItem:childBoard];
			}
		}
		
		_expandingBoards = NO;
	
		[self _reloadBoardListsSelectingBoard:NULL];
		[self _validate];
		
		if(![self _selectedBoard] && [[board boards] count] > 0) {
			row = [_boardsOutlineView rowForItem:[board boardAtIndex:0]];
			
			if(row >= 0)
				[_boardsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		}
		
		[connection removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[connection removeObserver:self message:message];
	}
}



- (void)wiredBoardGetThreadsReply:(WIP7Message *)message {
	WCServerConnection		*connection;
	WCBoard					*board;
	WCBoardThread			*thread;
	
	connection = [message contextInfo];
	
	if([[message name] isEqualToString:@"wired.board.thread_list"]) {
		board = [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.board"]];
		
		if(board) {
			thread = [WCBoardThread threadWithMessage:message connection:connection];
			
			[thread setUnread:[self _isUnreadThread:thread]];
			
			[board addThread:thread sortedUsingSelector:[self _sortSelector]];
			
			[_boardsByThreadID setObject:board forKey:[thread threadID]];
		}
	}
	else if([[message name] isEqualToString:@"wired.board.thread_list.done"]) {
		[_receivedBoards addObject:[connection URL]];
	
		[_boardsOutlineView setNeedsDisplay:YES];
		[_threadsTableView reloadData];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
		
		[connection removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[connection removeObserver:self message:message];
	}
}



- (void)wiredBoardGetThreadReply:(WIP7Message *)message {
	NSString				*threadID;
	WCServerConnection		*connection;
	WCBoard					*board;
	WCBoardThread			*thread;
	WCBoardPost				*post;
	
	connection = [message contextInfo];
	
	if([[message name] isEqualToString:@"wired.board.thread"]) {
		threadID	= [message UUIDForName:@"wired.board.thread"];
		board		= [_boardsByThreadID objectForKey:threadID];
		thread		= [board threadWithID:threadID];
		
		if(thread) {
			[thread setText:[message stringForName:@"wired.board.text"]];
			[thread setIcon:[[message dataForName:@"wired.user.icon"] base64EncodedString]];
		}
	}
	else if([[message name] isEqualToString:@"wired.board.post_list"]) {
		threadID	= [message UUIDForName:@"wired.board.thread"];
		board		= [_boardsByThreadID objectForKey:threadID];
		thread		= [board threadWithID:threadID];
		
		if(thread) {
			post = [WCBoardPost postWithMessage:message connection:connection];
			
			[post setUnread:![_readIDs containsObject:[post postID]]];
			
			[thread addPost:post];
		}
	}
	else if([[message name] isEqualToString:@"wired.board.post_list.done"]) {
		threadID	= [message UUIDForName:@"wired.board.thread"];
		board		= [_boardsByThreadID objectForKey:threadID];
		thread		= [board threadWithID:threadID];
		
		if(thread) {
			[thread setLoaded:YES];
			
			if(thread == [_threadController thread])
				[_threadController reloadDataAndScrollToCurrentPosition];
		}
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_errorQueue showError:[WCError errorWithWiredMessage:message]];
		
		[connection removeObserver:self message:message];
	}
}



- (void)wiredBoardSubscribeBoardsReply:(WIP7Message *)message {
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
		
		[_threadController reloadDataAndScrollToCurrentPosition];
	}
	
	[self _reloadBoardListsSelectingBoard:NULL];
	[self _validate];
}



- (void)wiredBoardBoardRenamed:(WIP7Message *)message {
	NSString			*oldPath, *newPath;
	WCServerConnection	*connection;
	WCBoard				*board, *selectedBoard;
	WCBoardThread		*selectedThread;
	NSUInteger			index;
	
	connection		= [message contextInfo];
	oldPath			= [message stringForName:@"wired.board.board"];
	newPath			= [message stringForName:@"wired.board.new_board"];
	board			= [[_boards boardForConnection:connection] boardForPath:oldPath];
	selectedBoard	= [self _selectedBoard];
	selectedThread	= [self _selectedThread];
	
	[board setPath:newPath];
	[board setName:[newPath lastPathComponent]];
	
	[_boards sortBoardsUsingSelector:@selector(compareBoard:) includeChildBoards:YES];
	
	[_boardsOutlineView reloadData];
	
	if(selectedBoard) {
		index = [_boardsOutlineView rowForItem:selectedBoard];
		
		[_boardsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		
		if(selectedThread)
			[self _reselectThread:selectedThread];
		
		[_threadController reloadDataAndScrollToCurrentPosition];
	}
	
	[self _reloadBoardListsSelectingBoard:NULL];
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
	
	[self _updateSelectedBoard];
	[self _reloadBoardListsSelectingBoard:NULL];
	[self _validate];
}



- (void)wiredBoardBoardDeleted:(WIP7Message *)message {
	NSString				*path;
	WCServerConnection		*connection;
	WCBoard					*parent;
	
	connection	= [message contextInfo];
	path		= [message stringForName:@"wired.board.board"];
	parent		= [[_boards boardForConnection:connection] boardForPath:[path stringByDeletingLastPathComponent]];
	
	[parent removeBoard:[[_boards boardForConnection:connection] boardForPath:path]];
	
	[_boardsOutlineView reloadData];
	
	[self _updateSelectedBoard];
	[self _reloadBoardListsSelectingBoard:NULL];
	[self _validate];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
}



- (void)wiredBoardBoardInfoChanged:(WIP7Message *)message {
	NSString				*path;
	WCServerConnection		*connection;
	WCBoard					*board;
	WIP7Bool				readable, writable;
	
	connection		= [message contextInfo];
	path			= [message stringForName:@"wired.board.board"];
	
	[message getBool:&readable forName:@"wired.board.readable"];
	[message getBool:&writable forName:@"wired.board.writable"];
	
	board = [[_boards boardForConnection:connection] boardForPath:path];
	
	[board setWritable:writable];
	[board setReadable:readable];

	[self _validate];
}



- (void)wiredBoardThreadAdded:(WIP7Message *)message {
	WCServerConnection		*connection;
	WCBoard					*board;
	WCBoardThread			*thread;
	
	connection		= [message contextInfo];
	board			= [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.board"]];
	
	if(board) {
		thread = [WCBoardThread threadWithMessage:message connection:connection];
		
		[thread setUnread:[self _isUnreadThread:thread]];
		
		[board addThread:thread sortedUsingSelector:[self _sortSelector]];
		
		[_boardsByThreadID setObject:board forKey:[thread threadID]];
		
		[_boardsOutlineView setNeedsDisplay:YES];
		[_threadsTableView reloadData];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
	}
}



- (void)wiredBoardThreadChanged:(WIP7Message *)message {
	NSString			*threadID;
	WCBoard				*board;
	WCBoardThread		*thread;
	WIP7UInt32			replies;
	
	threadID	= [message UUIDForName:@"wired.board.thread"];
	board		= [_boardsByThreadID objectForKey:threadID];
	thread		= [board threadWithID:threadID];
	
	if(thread) {
		[message getUInt32:&replies forName:@"wired.board.replies"];
		
		[thread setSubject:[message stringForName:@"wired.board.subject"]];
		[thread setEditDate:[message dateForName:@"wired.board.edit_date"]];
		[thread setLatestReplyID:[message UUIDForName:@"wired.board.latest_reply"]];
		[thread setLatestReplyDate:[message dateForName:@"wired.board.latest_reply_date"]];
		[thread setNumberOfReplies:replies];

		[thread setUnread:[self _isUnreadThread:thread]];
		[thread setLoaded:NO];
		
		if(thread == [_threadController thread])
			[self _reloadThread];
		
		[_threadsTableView reloadData];
	}
}



- (void)wiredBoardThreadDeleted:(WIP7Message *)message {
	NSString			*threadID;
	WCServerConnection	*connection;
	WCBoard				*board;
	WCBoardThread		*thread, *selectedThread;
	
	connection		= [message contextInfo];
	threadID		= [message UUIDForName:@"wired.board.thread"];
	board			= [_boardsByThreadID objectForKey:threadID];
	thread			= [board threadWithID:threadID];

	if(board == [self _selectedBoard])
		selectedThread = [self _selectedThread];
	else
		selectedThread = NULL;
	
	[board removeThread:thread];
	[_boardsByThreadID removeObjectForKey:threadID];
	
	if(board == [self _selectedBoard]) {
		[_threadsTableView reloadData];
		
		if(selectedThread)
			[self _reselectThread:selectedThread];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
}



- (void)wiredBoardThreadMoved:(WIP7Message *)message {
	NSString			*threadID;
	WCServerConnection	*connection;
	WCBoard				*oldBoard, *newBoard;
	WCBoardThread		*thread, *selectedThread;
	
	connection		= [message contextInfo];
	threadID		= [message UUIDForName:@"wired.board.thread"];
	oldBoard		= [[[_boardsByThreadID objectForKey:threadID] retain] autorelease];
	thread			= [[[oldBoard threadWithID:threadID] retain] autorelease];
	
	if(thread) {
		if(oldBoard == [self _selectedBoard] || newBoard == [self _selectedBoard])
			selectedThread = [self _selectedThread];
		else
			selectedThread = NULL;
		
		newBoard = [[_boards boardForConnection:connection] boardForPath:[message stringForName:@"wired.board.new_board"]];
		
		[oldBoard removeThread:thread];
		[newBoard addThread:thread sortedUsingSelector:[self _sortSelector]];
		
		[_boardsByThreadID setObject:newBoard forKey:threadID];
		
		if(oldBoard == [self _selectedBoard] || newBoard == [self _selectedBoard]) {
			[_threadsTableView reloadData];
			
			if(selectedThread)
				[self _reselectThread:selectedThread];
			
			[_threadController reloadDataAndScrollToCurrentPosition];
		}
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



- (void)wiredBoardEditThreadReply:(WIP7Message *)message {
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



#pragma mark -

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	SEL			selector;

	selector = [item action];
	
	if(selector == @selector(addThread:))
		return [self _validateAddThread];
	else if(selector == @selector(deleteThread:))
		return [self _validateDeleteThread];
	else if(selector == @selector(postReply:))
		return [self _validatePostReply];
	else if(selector == @selector(markAsRead:))
		return [self _validateMarkAsRead];
	else if(selector == @selector(markAllAsRead:))
		return ([_boards numberOfUnreadThreadsForConnection:NULL includeChildBoards:YES] > 0);
	
	return YES;
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	WCAccount		*account;
	WCBoard			*board;
	SEL				selector;
	BOOL			connected;
	
	selector	= [item action];
	board		= [self _selectedBoard];
	account		= [[board connection] account];
	connected	= [[board connection] isConnected];
	
	if(selector == @selector(addBoard:))
		return ([_boardLocationPopUpButton numberOfItems] > 0);
	else if(selector == @selector(renameBoard:))
		return (board != NULL && ![board isRootBoard] && connected && [account boardRenameBoards]);
	else if(selector == @selector(changePermissions:)) // TODO
		return (board != NULL && ![board isRootBoard] && connected && [account boardGetBoardInfo]);
	else if(selector == @selector(editSmartBoard:))
		return [board isKindOfClass:[WCSmartBoard class]];
	else if(selector == @selector(markAsRead:))
		return [self _validateMarkAsRead];
	else if(selector == @selector(markAsUnread:))
		return [self _validateMarkAsUnread];
	else if(selector == @selector(newDocument:))
		return [self _validateAddThread];
	else if(selector == @selector(deleteDocument:))
		return [self _validateDeleteThread];
	else if(selector == @selector(saveDocument:))
		return ([self _selectedThread] != NULL);
	
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
	else if([sender window] == _smartBoardPanel)
		valid = ([[_smartBoardNameTextField stringValue] length] > 0);
	
	if(valid)
		[super submitSheet:sender];
}



#pragma mark -

- (NSString *)newDocumentMenuItemTitle {
	return NSLS(@"New Thread\u2026", "New menu item");
}



- (NSString *)deleteDocumentMenuItemTitle {
	return NSLS(@"Delete Thread\u2026", "Delete menu item");
}



- (NSString *)reloadDocumentMenuItemTitle {
	return NSLS(@"Reload", @"Reload menu item");
}



- (NSString *)saveDocumentMenuItemTitle {
	return NSLS(@"Save Thread\u2026", @"Save menu item");
}



#pragma mark -

- (BOOL)showNextUnreadThread {
	WCBoardThread	*thread;
	NSRect			rect;
	
	if([[[self window] firstResponder] isKindOfClass:[NSTextView class]])
		return NO;

	rect = [[[[[[_threadController threadWebView] mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y += 0.9 * rect.size.height;
	
	if([[[[[_threadController threadWebView] mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return YES;
	
	thread = [_boards nextUnreadThreadStartingAtBoard:[self _selectedBoard]
											   thread:[self _selectedThread]
									forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];
	
	if(!thread) {
		thread = [_boards nextUnreadThreadStartingAtBoard:NULL
												   thread:NULL
										forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];
	}
	
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

	rect = [[[[[[_threadController threadWebView] mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y -= 0.9 * rect.size.height;
	
	if([[[[[_threadController threadWebView] mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return YES;
	
	thread = [_boards previousUnreadThreadStartingAtBoard:[self _selectedBoard]
												   thread:[self _selectedThread]
										forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];
	
	if(!thread) {
		thread = [_boards previousUnreadThreadStartingAtBoard:NULL
													   thread:NULL
											forwardsInThreads:([_threadsTableView sortOrder] == WISortAscending)];
	}

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

- (void)replyToThread { 
	WCBoard				*board; 
	WCBoardThread		*thread; 
	
	board		= [self _selectedBoard]; 
	thread		= [self _selectedThread]; 
	
	[self _reloadBoardListsSelectingBoard:board]; 
	
	[_postLocationPopUpButton setEnabled:NO];
	[_subjectTextField setEnabled:NO];
	[_subjectTextField setStringValue:[thread subject]];
	[_postTextView setTypingAttributes:[NSDictionary dictionary]];
	[_postTextView setString:@""];
	[_postButton setTitle:NSLS(@"Reply", @"Reply post button title")];
	
	[_postPanel makeFirstResponder:_postTextView];
	
	[NSApp beginSheet:_postPanel 
	   modalForWindow:[self window] 
		modalDelegate:self 
	   didEndSelector:@selector(replyPanelDidEnd:returnCode:contextInfo:) 
		  contextInfo:[[NSArray alloc] initWithObjects:board, thread, NULL]]; 
} 



- (void)replyToPostWithID:(NSString *)postID {
	NSString					*text;
	WCBoard						*board;
	WCBoardThread				*thread;
	WCBoardPost					*post;
	NSView <WebDocumentView>	*document;
	
	board		= [self _selectedBoard];
	thread		= [self _selectedThread];
	post		= [thread postWithID:postID];
	
	if(!post)
		return;
	
	document = [[[[_threadController threadWebView] mainFrame] frameView] documentView];
	
	if([document conformsToProtocol:@protocol(WebDocumentText)])
		text = [(NSView <WebDocumentText> *) document selectedString];
	else
		text = @"";
	
	if([text length] == 0)
		text = [post text];
	
	[self _reloadBoardListsSelectingBoard:board];

	[_postLocationPopUpButton setEnabled:NO];
	[_subjectTextField setEnabled:NO];
	[_subjectTextField setStringValue:[thread subject]];
	[_postTextView setAttributedString:[NSAttributedString attributedStringWithString:[NSSWF:@"[quote=%@]%@[/quote]\n\n", [post nick], text]]];
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
	NSString		*string;
	WIP7Message		*message;
	WCBoard			*board = [array objectAtIndex:0];
	WCBoardThread	*thread = [array objectAtIndex:1];
	
	if(returnCode == NSOKButton) {
		string = [WCChatController stringByDecomposingSmileyAttributesInAttributedString:[self _attributedPostString]];

		message = [WIP7Message messageWithName:@"wired.board.add_post" spec:WCP7Spec];
		[message setUUID:[thread threadID] forName:@"wired.board.thread"];
		[message setString:[_subjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[self _BBCodeTextForPostText:string] forName:@"wired.board.text"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardAddPostReply:)];
	}
	
	[_postPanel close];
	[array release];
	
	[[WCSettings settings] setBool:[_postTextView isContinuousSpellCheckingEnabled] forKey:WCBoardPostContinuousSpellChecking];
}



- (void)editPostWithID:(NSString *)postID {
	WCBoard				*board;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	board		= [self _selectedBoard];
	thread		= [self _selectedThread];
	
	if([postID isEqualToString:[thread threadID]])
		post = NULL;
	else
		post = [thread postWithID:postID];
	
	[self _reloadBoardListsSelectingBoard:board];

	[_postLocationPopUpButton setEnabled:(post == NULL && [[[board connection] account] boardMoveThreads])];
	[_subjectTextField setEnabled:(post == NULL)];
	[_subjectTextField setStringValue:[thread subject]];
	[_postTextView setAttributedString:[NSAttributedString attributedStringWithString:(post == NULL) ? [thread text] : [post text]]];
	[_postButton setTitle:NSLS(@"Edit", @"Edit post button title")];
	
	[_postPanel makeFirstResponder:_postTextView];
	
	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(editPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[[NSArray alloc] initWithObjects:board, thread, post, NULL]];
}



- (void)editPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSArray				*array = contextInfo;
	NSString			*string;
	WIP7Message			*message;
	WCBoard				*board = [array objectAtIndex:0], *newBoard;
	WCBoardThread		*thread = [array objectAtIndex:1];
	WCBoardPost			*post = ([array count] > 2) ? [array objectAtIndex:2] : NULL;
	
	if(returnCode == NSOKButton) {
		if([[board connection] isConnected]) {
			string = [WCChatController stringByDecomposingSmileyAttributesInAttributedString:[self _attributedPostString]];
			
			if(post) {
				message = [WIP7Message messageWithName:@"wired.board.edit_post" spec:WCP7Spec];
				[message setUUID:[post postID] forName:@"wired.board.post"];
				[message setString:[_subjectTextField stringValue] forName:@"wired.board.subject"];
				[message setString:[self _BBCodeTextForPostText:string] forName:@"wired.board.text"];
				[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardEditPostReply:)];
			} else {
				message = [WIP7Message messageWithName:@"wired.board.edit_thread" spec:WCP7Spec];
				[message setUUID:[thread threadID] forName:@"wired.board.thread"];
				[message setString:[_subjectTextField stringValue] forName:@"wired.board.subject"];
				[message setString:[self _BBCodeTextForPostText:string] forName:@"wired.board.text"];
				[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardEditThreadReply:)];
			}
			
			newBoard = [_postLocationPopUpButton representedObjectOfSelectedItem];
			
			if(![board isEqual:newBoard] && [[[board connection] account] boardMoveBoards]) {
				message = [WIP7Message messageWithName:@"wired.board.move_thread" spec:WCP7Spec];
				[message setString:[board path] forName:@"wired.board.board"];
				[message setUUID:[thread threadID] forName:@"wired.board.thread"];
				[message setString:[newBoard path] forName:@"wired.board.new_board"];
				[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardMoveThreadReply:)];
			}
		}
	}
	
	[_postPanel close];
	[array release];
	
	[[WCSettings settings] setBool:[_postTextView isContinuousSpellCheckingEnabled] forKey:WCBoardPostContinuousSpellChecking];
}



- (void)deletePostWithID:(NSString *)postID {
	NSAlert				*alert;
	WCBoard				*board;
	WCBoardThread		*thread;
	WCBoardPost			*post;
	
	board		= [self _selectedBoard];
	thread		= [self _selectedThread];

	if([postID isEqualToString:[thread threadID]])
		post = NULL;
	else
		post = [thread postWithID:postID];
	
	alert = [[[NSAlert alloc] init] autorelease];
	
	if(post) {
		[alert setMessageText:NSLS(@"Are you sure you want to delete this post?",
								   @"Delete post dialog title")];
		[alert setInformativeText:NSLS(@"This cannot be undone.",
									   @"Delete post dialog description")];
	} else {
		[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete the thread \u201c%@\u201d?",
										  @"Delete post dialog title"), [thread subject]]];
		[alert setInformativeText:NSLS(@"All posts in the thread will be deleted as well. This cannot be undone.",
									   @"Delete thread dialog description")];
	}
	
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete post button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete post button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deletePostAlertDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSArray alloc] initWithObjects:board, thread, post, NULL]];
}



- (void)deletePostAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSArray				*array = contextInfo;
	WIP7Message			*message;
	WCBoard				*board = [array objectAtIndex:0];
	WCBoardThread		*thread = [array objectAtIndex:1];
	WCBoardPost			*post = ([array count] > 2) ? [array objectAtIndex:2] : NULL;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		if([[board connection] isConnected]) {
			if(post) {
				message = [WIP7Message messageWithName:@"wired.board.delete_post" spec:WCP7Spec];
				[message setUUID:[post postID] forName:@"wired.board.post"];
				[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardDeletePostReply:)];
			} else {
				message = [WIP7Message messageWithName:@"wired.board.delete_thread" spec:WCP7Spec];
				[message setUUID:[thread threadID] forName:@"wired.board.thread"];
				[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardDeleteThreadReply:)];
			}
		}
	}
	
	[array release];
}



#pragma mark -

- (IBAction)newDocument:(id)sender {
	[self addThread:sender];
}



- (IBAction)deleteDocument:(id)sender {
	[self deleteThread:sender];
}



- (IBAction)saveDocument:(id)sender {
	[self saveThread:sender];
}



- (IBAction)addBoard:(id)sender {
	[self _reloadBoardListsSelectingBoard:[self _selectedBoard]];
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
		board = [_boardLocationPopUpButton representedObjectOfSelectedItem];
		
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



- (IBAction)addSmartBoard:(id)sender {
	[_smartBoardNameTextField setStringValue:NSLS(@"Untitled", @"Smart board name")];
	[_boardFilterComboBox setStringValue:@""];
	[_subjectFilterTextField setStringValue:@""];
	[_textFilterTextField setStringValue:@""];
	[_nickFilterTextField setStringValue:@""];
	[_unreadFilterButton setState:NSOffState];
	
	[self _reloadBoardListsSelectingBoard:[self _selectedBoard]];

	[NSApp beginSheet:_smartBoardPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addSmartBoardPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)addSmartBoardPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WCSmartBoard				*smartBoard;
	WCBoardThreadFilter			*filter;
	
	if(returnCode == NSOKButton) {
		filter = [WCBoardThreadFilter filter];

		[filter setBoard:[_boardFilterComboBox stringValue]];
		[filter setSubject:[_subjectFilterTextField stringValue]];
		[filter setText:[_textFilterTextField stringValue]];
		[filter setNick:[_nickFilterTextField stringValue]];
		[filter setUnread:[_unreadFilterButton state]];
		
		smartBoard = [WCSmartBoard smartBoard];
		[smartBoard setName:[_smartBoardNameTextField stringValue]];
		[smartBoard setFilter:filter];
		
		[_smartBoards addBoard:smartBoard];
		
		if([_smartBoards numberOfBoards] == 1)
			[_boards addBoard:_smartBoards];
		
		[_boardsOutlineView reloadData];
		[_boardsOutlineView expandItem:_smartBoards];
		
		[self _saveFilters];
		[self _reloadFilters];
	}
	
	[_smartBoardPanel close];
}



- (IBAction)editSmartBoard:(id)sender {
	WCBoardThreadFilter		*filter;
	id						board;
	
	board	= [self _selectedBoard];
	filter	= [board filter];
	
	[_smartBoardNameTextField setStringValue:[board name]];
	[_boardFilterComboBox setStringValue:[filter board]];
	[_subjectFilterTextField setStringValue:[filter subject]];
	[_textFilterTextField setStringValue:[filter text]];
	[_nickFilterTextField setStringValue:[filter nick]];
	[_unreadFilterButton setState:[filter unread]];
	
	[self _reloadBoardListsSelectingBoard:[self _selectedBoard]];

	[NSApp beginSheet:_smartBoardPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(editSmartBoardPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[board retain]];
}



- (void)editSmartBoardPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WCSmartBoard			*smartBoard = contextInfo;
	WCBoardThreadFilter		*filter;

	if(returnCode == NSOKButton) {
		filter = [smartBoard filter];
		
		[filter setBoard:[_boardFilterComboBox stringValue]];
		[filter setSubject:[_subjectFilterTextField stringValue]];
		[filter setText:[_textFilterTextField stringValue]];
		[filter setNick:[_nickFilterTextField stringValue]];
		[filter setUnread:[_unreadFilterButton state]];
		
		[smartBoard setName:[_smartBoardNameTextField stringValue]];
		
		[self _saveFilters];
		[self _reloadFilters];
	}
	
	[_smartBoardPanel close];
	[smartBoard release];
}



- (IBAction)deleteBoard:(id)sender {
	NSAlert		*alert;
	WCBoard		*board;
	
	board = [self _selectedBoard];
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete the board \u201c%@\u201d?", @"Delete board dialog title"), [board name]]];
	
	if([board isKindOfClass:[WCSmartBoard class]])
		[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete board dialog description")];
	else
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
		if([board isKindOfClass:[WCSmartBoard class]]) {
			[_smartBoards removeBoard:board];
			
			if([_smartBoards numberOfBoards] == 0)
				[_boards removeBoard:_smartBoards];

			[_boardsOutlineView reloadData];
			[_boardsOutlineView deselectAll:self];
			
			[self _updateSelectedBoard];
			[self _saveFilters];
		} else {
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
/*	WCBoard		*board;
	
	[self _reloadBoardListsSelectingBoard:[self _selectedBoard]];
	[self _updatePermissions];
	
	board = [self _selectedBoard];
	
	if([[board owner] length] > 0 && [_setOwnerPopUpButton indexOfItemWithTitle:[board owner]] != -1)
		[_setOwnerPopUpButton selectItemWithTitle:[board owner]];
	else
		[_setOwnerPopUpButton selectItemAtIndex:0];

	if([[board group] length] > 0 && [_setGroupPopUpButton indexOfItemWithTitle:[board group]] != -1)
		[_setGroupPopUpButton selectItemWithTitle:[board group]];
	else
		[_setGroupPopUpButton selectItemAtIndex:0];

	[_setOwnerPermissionsPopUpButton selectItemWithTag:[board permissions] & (WCBoardOwnerWrite | WCBoardOwnerRead)];
	[_setGroupPermissionsPopUpButton selectItemWithTag:[board permissions] & (WCBoardGroupWrite | WCBoardGroupRead)];
	[_setEveryonePermissionsPopUpButton selectItemWithTag:[board permissions] & (WCBoardEveryoneWrite | WCBoardEveryoneRead)];

	[NSApp beginSheet:_setPermissionsPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(changePermissionsPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:[board retain]];*/
}



- (void)changePermissionsPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
/*	NSString		*owner, *group;
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
	[_setPermissionsPanel close];*/
}



- (IBAction)location:(id)sender {
	[self _updatePermissions];
}



- (IBAction)addThread:(id)sender {
	WCBoard			*board;
	
	board = [self _selectedBoard];
	
	if(!board)
		return;
	
	[self _reloadBoardListsSelectingBoard:board];

	[_postLocationPopUpButton setEnabled:YES];
	[_subjectTextField setEnabled:YES];
	[_subjectTextField setStringValue:@""];
	[_postTextView setString:@""];
	[_postButton setTitle:NSLS(@"Create", @"New thread button title")];
	
	[_postPanel makeFirstResponder:_subjectTextField];
	
	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(addThreadPanelDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)addThreadPanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*string;
	WIP7Message		*message;
	WCBoard			*board;
	
	if(returnCode == NSOKButton) {
		board		= [_postLocationPopUpButton representedObjectOfSelectedItem];
		string		= [WCChatController stringByDecomposingSmileyAttributesInAttributedString:[self _attributedPostString]];

		message = [WIP7Message messageWithName:@"wired.board.add_thread" spec:WCP7Spec];
		[message setString:[board path] forName:@"wired.board.board"];
		[message setString:[_subjectTextField stringValue] forName:@"wired.board.subject"];
		[message setString:[self _BBCodeTextForPostText:string] forName:@"wired.board.text"];
		[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardAddThreadReply:)];
	}

	[_postPanel close];
	
	[[WCSettings settings] setBool:[_postTextView isContinuousSpellCheckingEnabled] forKey:WCBoardPostContinuousSpellChecking];
}



- (IBAction)deleteThread:(id)sender {
	NSAlert			*alert;
	NSArray			*threads;
	NSString		*title, *description;
	WCBoard			*board;
	NSUInteger		count;
	
	board		= [self _selectedBoard];
	threads		= [self _selectedThreads];
	
	if(!threads)
		return;

	count = [threads count];

	if(count == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete the thread \u201c%@\u201d?", @"Delete thread dialog title (filename)"),
			[[threads objectAtIndex:0] subject]];
		description = NSLS(@"All posts in the thread will be deleted as well. This cannot be undone.", @"Delete thread dialog description");
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu threads?", @"Delete thread dialog title (count)"),
			count];
		description = NSLS(@"All posts in the threads will be deleted as well. This cannot be undone.", @"Delete thread dialog description");
	}
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:title];
	[alert setInformativeText:description];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete thread button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete thread button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteThreadAlertDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSArray alloc] initWithObjects:board, threads, NULL]];
}



- (void)deleteThreadAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	NSArray			*array = contextInfo;
	NSArray			*threads = [array objectAtIndex:1];
	WIP7Message		*message;
	WCBoard			*board = [array objectAtIndex:0];
	WCBoardThread	*thread;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		if([[board connection] isConnected]) {
			enumerator = [threads objectEnumerator];
			
			while((thread = [enumerator nextObject])) {
				if([thread isUnread])
					[thread setUnread:NO];
				
				message = [WIP7Message messageWithName:@"wired.board.delete_thread" spec:WCP7Spec];
				[message setString:[board path] forName:@"wired.board.board"];
				[message setUUID:[thread threadID] forName:@"wired.board.thread"];
				[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardDeleteThreadReply:)];
			}
			
			[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
		}
	}
	
	[array release];
}



- (IBAction)saveThread:(id)sender {
	NSSavePanel				*savePanel;
	WCBoardThread			*thread;
	
	thread = [self _selectedThread];
	
	if(!thread)
		return;

	savePanel = [NSSavePanel savePanel];
	[savePanel setRequiredFileType:@"html"];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel beginSheetForDirectory:NULL
								 file:[[thread subject] stringByAppendingPathExtension:@"html"]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(saveThreadPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:[thread retain]];
}



- (void)saveThreadPanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString			*html;
	WCBoardThread		*thread = contextInfo;
	
	if(returnCode == NSOKButton) {
		html = [_threadController HTMLString];
		
		[[html dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[savePanel filename] atomically:YES];
	}
	
	[thread release];
}



- (IBAction)postReply:(id)sender {
	[self replyToThread];
}



- (IBAction)markAsRead:(id)sender {
	NSArray		*threads;
	
	threads = [self _selectedThreads];
	
	if([threads count] == 0)
		[self _markBoard:[self _selectedBoard] asUnread:NO];
	else
		[self _markThreads:threads asUnread:NO];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
}



- (IBAction)markAllAsRead:(id)sender {
	[self _markBoard:_boards asUnread:NO];
	   
	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
}



- (IBAction)markAsUnread:(id)sender {
	NSArray		*threads;
	
	threads = [self _selectedThreads];
	
	if([threads count] == 0)
		[self _markBoard:[self _selectedBoard] asUnread:YES];
	else
		[self _markThreads:threads asUnread:YES];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
}



- (IBAction)search:(id)sender {
	NSString				*string;
	WCBoardThreadFilter		*filter;
	
	[_searchBoard removeAllThreads];
	
	string = [sender stringValue];
	
	if([string length] > 0) {
		filter = [WCBoardThreadFilter filter];
		[filter setText:string];
		[filter setSubject:string];

		[_searchBoard setFilter:filter];
	
		_searching = YES;
	} else {
		_searching = NO;
	}
	
	[self _updateSelectedBoard];
}



#pragma mark -

- (IBAction)goToLatestReply:(id)sender {
	WCBoardThread		*thread;
	NSUInteger			index;
	
	thread	= [self _threadAtIndex:[sender tag]];
	index	= [self _indexOfThread:thread];

	if(index != NSNotFound) {
		if([[_threadsTableView selectedRowIndexes] isEqualToIndexSet:[NSIndexSet indexSetWithIndex:index]])
			[_threadController reloadDataAndSelectPost:[[thread posts] lastObject]];
		else
			[_threadsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	}
}



#pragma mark -

- (IBAction)bold:(id)sender {
	[self _insertBBCodeWithStartTag:@"[b]" endTag:@"[/b]"];
}



- (IBAction)italic:(id)sender {
	[self _insertBBCodeWithStartTag:@"[i]" endTag:@"[/i]"];
}



- (IBAction)underline:(id)sender {
	[self _insertBBCodeWithStartTag:@"[u]" endTag:@"[/u]"];
}



- (IBAction)color:(id)sender {
	NSString	*color;
	NSInteger	tag;
	
	tag		= [sender tagOfSelectedItem];
	color	= [NSSWF:@"#%02X%02X%02X", (tag & 0xFF0000) >> 16, (tag & 0x00FF00) >> 8, (tag & 0x0000FF)];
	
	[self _insertBBCodeWithStartTag:[NSSWF:@"[color=%@]", color] endTag:@"[/color]"];
}



- (IBAction)center:(id)sender {
	[self _insertBBCodeWithStartTag:@"[center]" endTag:@"[/center]"];
}



- (IBAction)quote:(id)sender {
	[self _insertBBCodeWithStartTag:@"[quote]" endTag:@"[/quote]"];
}



- (IBAction)code:(id)sender {
	[self _insertBBCodeWithStartTag:@"[code]" endTag:@"[/code]"];
}



- (IBAction)url:(id)sender {
	NSRange		range;
	
	[self _insertBBCodeWithStartTag:@"[url=]" endTag:@"[/url]"];
	
	range = [_postTextView selectedRange];

	range.location	-= 1;
	range.length	= 0;
	
	[_postTextView setSelectedRange:range];
}



- (IBAction)image:(id)sender {
	[self _insertBBCodeWithStartTag:@"[img]" endTag:@"[/img]"];
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
	NSDictionary	*attributes;
	NSString		*label;
	NSUInteger		count;
	
	if(tableColumn == _boardTableColumn) {
		label = [item name];
		
		if([item isRootBoard]) {
			attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSColor colorWithCalibratedRed:96.0 / 255.0 green:110.0 / 255.0 blue:128.0 / 255.0 alpha:1.0],
					NSForegroundColorAttributeName,
				[NSFont boldSystemFontOfSize:11.0],
					NSFontAttributeName,
				NULL];
			
			return [NSAttributedString attributedStringWithString:[label uppercaseString] attributes:attributes];
		} else {
			return label;
		}
	}
	else if(tableColumn == _unreadBoardTableColumn) {
		count = [item numberOfUnreadThreadsForConnection:NULL includeChildBoards:![item isExpanded]];
		
		return [NSImage imageWithPillForCount:count
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
		
		if([item isRootBoard])
			[cell setImage:NULL];
		else if([item isKindOfClass:[WCSmartBoard class]])
			[cell setImage:[NSImage imageNamed:@"SmartBoard"]];
		else
			[cell setImage:[NSImage imageNamed:@"Board"]];
	}
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return [item isExpandable];
}



- (void)outlineViewItemDidExpand:(NSNotification *)notification {
	id		item;
	
	item = [[notification userInfo] objectForKey:@"NSObject"];
	
	[item setExpanded:YES];
	
	if(!_expandingBoards)
		[self _saveBoards];
}



- (void)outlineViewItemDidCollapse:(NSNotification *)notification {
	id		item;
	
	item = [[notification userInfo] objectForKey:@"NSObject"];
	
	[item setExpanded:NO];
	
	if(!_expandingBoards)
		[self _saveBoards];
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	[self _updateSelectedBoard];
	[self _validate];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	return ![item isRootBoard];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	WCServerConnection		*connection;
	WCBoard					*board = item;
	
	if([board isKindOfClass:[WCSmartBoard class]])
		return YES;
	
	connection = [board connection];
	
	return (![board isRootBoard] && [connection isConnected] && [[connection account] boardRenameBoards]);
}



- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSString		*oldPath, *newPath;
	WCBoard			*board = item;
	WIP7Message		*message;
	
	if([board isKindOfClass:[WCSmartBoard class]]) {
		[board setName:object];
		
		[self _saveFilters];
	} else {
		oldPath		= [item path];
		newPath		= [[[item path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:object];
		
		if(![oldPath isEqualToString:newPath]) {
			message = [WIP7Message messageWithName:@"wired.board.rename_board" spec:WCP7Spec];
			[message setString:oldPath forName:@"wired.board.board"];
			[message setString:newPath forName:@"wired.board.new_board"];
			[[board connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardRenameBoardReply:)];
		}
	}
}



- (BOOL)outlineView:(NSOutlineView *)tableView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCBoard			*board;
	
	board = [items objectAtIndex:0];
	
	if([board isRootBoard] || [board isKindOfClass:[WCSmartBoard class]])
		return NO;
	
	if(![[[board connection] account] boardMoveBoards])
		return NO;
	
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
	
	if([newBoard isKindOfClass:[WCSmartBoard class]] || index >= 0)
		return NSDragOperationNone;
	
	if([types containsObject:WCBoardPboardType]) {
		array		= [pasteboard propertyListForType:WCBoardPboardType];
		oldPath		= [array objectAtIndex:0];
		oldName		= [array objectAtIndex:1];
		oldBoard	= [[_boards boardForConnection:[newBoard connection]] boardForPath:oldPath];
		rootPath	= [[newBoard path] isEqualToString:@"/"] ? @"" : [newBoard path];
		newPath		= [rootPath stringByAppendingPathComponent:oldName];
		
		if(!newBoard || [newPath hasPrefix:oldPath] || !oldBoard  || [oldPath isEqualToString:newPath])
			return NSDragOperationNone;
		
		return NSDragOperationMove;
	}
	else if([types containsObject:WCThreadPboardType]) {
		array		= [pasteboard propertyListForType:WCThreadPboardType];
		oldPath		= [array objectAtIndex:0];
		oldBoard	= [[_boards boardForConnection:[newBoard connection]] boardForPath:oldPath];
		newPath		= [newBoard path];
		
		if(!oldBoard || [oldPath isEqualToString:newPath] || ![oldBoard isWritable] || ![newBoard isWritable])
			return NSDragOperationNone;
		
		return NSDragOperationMove;
	}
	
	return NSDragOperationNone;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
	NSPasteboard		*pasteboard;
	NSEnumerator		*enumerator;
	NSArray				*types, *array;
	NSString			*oldPath, *oldName, *newPath, *rootPath, *threadID;
	WIP7Message			*message;
	WCBoard				*newBoard = item, *oldBoard;
	
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
		oldBoard	= [[_boards boardForConnection:[newBoard connection]] boardForPath:oldPath];
		enumerator	= [[array subarrayFromIndex:1] objectEnumerator];
		
		while((threadID = [enumerator nextObject])) {
			message = [WIP7Message messageWithName:@"wired.board.move_thread" spec:WCP7Spec];
			[message setString:[oldBoard path] forName:@"wired.board.board"];
			[message setUUID:threadID forName:@"wired.board.thread"];
			[message setString:[newBoard path] forName:@"wired.board.new_board"];
			[[newBoard connection] sendMessage:message fromObserver:self selector:@selector(wiredBoardMoveThreadReply:)];
		}
		
		return YES;
	}
	
	return NO;
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [[self _selectedBoard] numberOfThreads];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSButton			*button;
	WCBoardThread		*thread;
	
	thread = [self _threadAtIndex:row];
	
	if(tableColumn == _unreadThreadTableColumn)
		return [thread isUnread] ? [NSImage imageNamed:@"UnreadThread"] : NULL;
	if(tableColumn == _subjectTableColumn)
		return [thread subject];
	else if(tableColumn == _nickTableColumn)
		return [thread nick];
	else if(tableColumn == _repliesTableColumn)
		return [NSNumber numberWithUnsignedInteger:[thread numberOfReplies]];
	else if(tableColumn == _threadTimeTableColumn)
		return [_dateFormatter stringFromDate:[thread postDate]];
	else if(tableColumn == _postTimeTableColumn) {
		if([thread latestReplyDate]) {
			button = [thread goToLatestReplyButton];
			
			[button setTarget:self];
			[button setAction:@selector(goToLatestReply:)];
			[button setTag:row];
			
			return [NSDictionary dictionaryWithObjectsAndKeys:
				[_dateFormatter stringFromDate:[thread latestReplyDate]],
					WCBoardsButtonCellValueKey,
				button,
					WCBoardsButtonCellButtonKey,
				NULL];
		} else {
			return NULL;
		}
	}
	
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
	NSMutableArray		*threads;
	WCBoard				*board;
	NSUInteger			index;
	
	board = [self _selectedBoard];
	
	if(![[[board connection] account] boardMoveThreads])
		return NO;

	threads = [NSMutableArray array];
	
	[threads addObject:[[self _selectedBoard] path]];
	
	index = [indexes firstIndex];
	
	while(index != NSNotFound) {
		[threads addObject:[[self _threadAtIndex:index] threadID]];
		
		index = [indexes indexGreaterThanIndex:index];
	}

	[pasteboard declareTypes:[NSArray arrayWithObject:WCThreadPboardType] owner:NULL];
	[pasteboard setPropertyList:threads forType:WCThreadPboardType];
	
	return YES;
}

@end
