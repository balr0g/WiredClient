/* $Id$ */

/*
 *  Copyright (c) 2009 Axel Andersson
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
#import "WCAdministration.h"
#import "WCEventsController.h"
#import "WCServerConnection.h"

enum _WCEventType {
	WCEventUsers				= 0,
	WCEventFiles,
	WCEventAccounts,
	WCEventMessages,
	WCEventBoards
};
typedef enum _WCEventType		WCEventType;


@interface WCEvent : WIObject {
@public
	WCEventType					_type;
	
	NSString					*_formattedTime;
	
	NSDate						*_time;
	NSString					*_nick;
	NSString					*_login;
	NSString					*_ip;
	NSString					*_message;
}

+ (WCEvent *)eventWithMessage:(WIP7Message *)message;

- (NSComparisonResult)compareType:(WCEvent *)event;
- (NSComparisonResult)compareTime:(WCEvent *)event;
- (NSComparisonResult)compareNick:(WCEvent *)event;
- (NSComparisonResult)compareLogin:(WCEvent *)event;
- (NSComparisonResult)compareIP:(WCEvent *)event;
- (NSComparisonResult)compareMessage:(WCEvent *)event;

@end


@implementation WCEvent

+ (WCEvent *)eventWithMessage:(WIP7Message *)message {
	NSArray			*parameters;
	NSString		*name, *string;
	WCEvent			*event;
	WCEventType		type;
	
	name			= [message enumNameForName:@"wired.event.event"];
	parameters		= [message listForName:@"wired.event.parameters"];
	
	if([name isEqualToString:@"wired.event.user.logged_in"] && [parameters count] >= 2) {
		type = WCEventUsers;
		string = [NSSWF:NSLS(@"Logged in using \u201c%@\u201d on \u201c%@\u201d", @"Event message (application, os)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.user.logged_out"]) {
		type = WCEventUsers;
		string = NSLS(@"Logged out", @"Event message");
	}
	else if([name isEqualToString:@"wired.event.user.login_failed"]) {
		type = WCEventUsers;
		string = NSLS(@"Login failed", @"Event message");
	}
	else if([name isEqualToString:@"wired.event.user.changed_nick"] && [parameters count] >= 2) {
		type = WCEventUsers;
		string = [NSSWF:NSLS(@"Changed nick from \u201c%@\u201d to \u201c%@\u201d", @"Event message (oldnick, newnick)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.user.got_info"] && [parameters count] >= 1) {
		type = WCEventUsers;
		string = [NSSWF:NSLS(@"Got info for \u201c%@\u201d", @"Event message (nick)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.listed_directory"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Listed \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.got_info"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Got info for \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.moved"] && [parameters count] >= 2) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Moved \u201c%@\u201d to \u201c%@\u201d", @"Event message (frompath, topath)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.file.linked"] && [parameters count] >= 2) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Linked \u201c%@\u201d to \u201c%@\u201d", @"Event message (frompath, topath)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.file.set_type"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Changed type for \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.set_comment"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Changed comment for \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.set_executable"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Changed executable mode for \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.set_permissions"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Changed permissions for \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.set_label"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Changed label for \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.deleted"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Deleted \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.created_directory"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Created \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.searched"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Searched for \u201c%@\u201d", @"Event message (query)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.file.previewed_file"] && [parameters count] >= 1) {
		type = WCEventFiles;
		string = [NSSWF:NSLS(@"Previewed \u201c%@\u201d", @"Event message (path)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.listed_users"]) {
		type = WCEventAccounts;
		string = NSLS(@"Listed users", @"Event message");
	}
	else if([name isEqualToString:@"wired.event.account.listed_groups"]) {
		type = WCEventAccounts;
		string = NSLS(@"Listed groups", @"Event message");
	}
	else if([name isEqualToString:@"wired.event.account.read_user"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Read user \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.read_group"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Read group \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.created_user"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Created user \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.created_group"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Created group \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.edited_user"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Edited user \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.edited_group"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Edited group \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.deleted_user"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Deleted user \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.account.deleted_group"] && [parameters count] >= 1) {
		type = WCEventAccounts;
		string = [NSSWF:NSLS(@"Deleted group \u201c%@\u201d", @"Event message (account)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.message.sent"] && [parameters count] >= 1) {
		type = WCEventMessages;
		string = [NSSWF:NSLS(@"Sent message to \u201c%@\u201d", @"Event message (nick)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.message.broadcasted"]) {
		type = WCEventMessages;
		string = NSLS(@"Sent broadcast", @"Event message");
	}
	else if([name isEqualToString:@"wired.event.board.added_board"] && [parameters count] >= 1) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Added \u201c%@\u201d", @"Event message (board)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.board.renamed_board"] && [parameters count] >= 2) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Renamed \u201c%@\u201d to \u201c%@\u201d", @"Event message (board)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.board.moved_board"] && [parameters count] >= 2) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Moved \u201c%@\u201d to \u201c%@\u201d", @"Event message (board)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.board.deleted_board"] && [parameters count] >= 1) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Deleted \u201c%@\u201d", @"Event message (board)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.board.set_permissions"] && [parameters count] >= 1) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Change permissions for \u201c%@\u201d", @"Event message (board)"),
			[parameters objectAtIndex:0]];
	}
	else if([name isEqualToString:@"wired.event.board.added_thread"] && [parameters count] >= 2) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Added \u201c%@\u201d in \u201c%@\u201d", @"Event message (board, subject)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.board.moved_thread"] && [parameters count] >= 3) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Moved \u201c%@\u201d from \u201c%@\u201d to \u201c%@\u201d", @"Event message (oldboard, newboard, subject)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1],
			[parameters objectAtIndex:2]];
	}
	else if([name isEqualToString:@"wired.event.board.deleted_thread"] && [parameters count] >= 2) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Deleted \u201c%@\u201d in \u201c%@\u201d", @"Event message (board, subject)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.board.added_post"] && [parameters count] >= 2) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Added \u201c%@\u201d in \u201c%@\u201d", @"Event message (board, subject)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.board.edited_post"] && [parameters count] >= 2) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Edited \u201c%@\u201d in \u201c%@\u201d", @"Event message (board, subject)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else if([name isEqualToString:@"wired.event.board.deleted_post"] && [parameters count] >= 2) {
		type = WCEventBoards;
		string = [NSSWF:NSLS(@"Deleted \u201c%@\u201d \u201c%@\u201d", @"Event message (board, subject)"),
			[parameters objectAtIndex:0],
			[parameters objectAtIndex:1]];
	}
	else {
		type = 0;
		string = NULL;
	}
	
	if(!string)
		return NULL;
	
	event				= [[self alloc] init];
	event->_type		= type;
	event->_message		= [string retain];
	event->_time		= [[message dateForName:@"wired.event.time"] retain];
	event->_nick		= [[message stringForName:@"wired.user.nick"] retain];
	event->_login		= [[message stringForName:@"wired.user.login"] retain];
	event->_ip			= [[message stringForName:@"wired.user.ip"] retain];
	
	return [event autorelease];
}



- (void)dealloc {
	[_formattedTime release];

	[_time release];
	[_nick release];
	[_login release];
	[_ip release];
	[_message release];
	
	[super dealloc];
}



#pragma mark -

- (NSComparisonResult)compareType:(WCEvent *)event {
	if(self->_type < event->_type)
		return NSOrderedAscending;
	else if(self->_type > event->_type)
		return NSOrderedDescending;
	
	return NSOrderedSame;
}



- (NSComparisonResult)compareTime:(WCEvent *)event {
	return [self->_time compare:event->_time];
}



- (NSComparisonResult)compareNick:(WCEvent *)event {
	NSComparisonResult	result;
	
	result = [self->_nick compare:event->_nick options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self compareTime:event];
	
	return result;
}



- (NSComparisonResult)compareLogin:(WCEvent *)event {
	NSComparisonResult	result;
	
	result = [self->_login compare:event->_login options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self compareTime:event];
	
	return result;
}



- (NSComparisonResult)compareIP:(WCEvent *)event {
	NSComparisonResult	result;
	
	result = [self->_ip compare:event->_ip options:NSCaseInsensitiveSearch | NSNumericSearch];
	
	if(result == NSOrderedSame)
		result = [self compareTime:event];
	
	return result;
}



- (NSComparisonResult)compareMessage:(WCEvent *)event {
	NSComparisonResult	result;
	
	result = [self->_message compare:event->_message options:NSCaseInsensitiveSearch];
	
	if(result == NSOrderedSame)
		result = [self compareTime:event];
	
	return result;
}

@end



@interface WCEventsController(Private)

- (WCEvent *)_eventAtIndex:(NSUInteger)index;
- (BOOL)_filterIncludesEvent:(WCEvent *)event;
- (void)_reloadFilter;
- (void)_refreshReceivedEvents;

- (void)_requestEvents;
- (void)_sortEvents;

@end


@implementation WCEventsController(Private)

- (WCEvent *)_eventAtIndex:(NSUInteger)index {
	NSUInteger		i;
	
	i = ([_eventsTableView sortOrder] == WISortDescending)
		? [_shownEvents count] - index - 1
		: index;
	
	return [_shownEvents objectAtIndex:i];
}



- (BOOL)_filterIncludesEvent:(WCEvent *)event {
	return YES;
}



- (void)_reloadFilter {
	WCEvent			*event;
	NSUInteger		i, count;
	
	[_shownEvents removeAllObjects];
	
	count = [_allEvents count];
	
	for(i = 0; i < count; i++) {
		event = [_allEvents objectAtIndex:i];
		
		if([self _filterIncludesEvent:event])
			[_shownEvents addObject:event];
	}
	
	[_eventsTableView reloadData];
}



- (void)_refreshReceivedEvents {
	WCEvent			*event;
	NSUInteger		i, count;
	
	count = [_receivedEvents count];
	
	for(i = 0; i < count; i++) {
		event = [_receivedEvents objectAtIndex:i];

		if([self _filterIncludesEvent:event])
			[_shownEvents addObject:event];
	}
	
	[_receivedEvents removeAllObjects];

	[_eventsTableView reloadData];
	[_eventsTableView scrollRowToVisible:[_shownEvents count] - 1];
}



#pragma mark -

- (void)_requestEvents {
	WIP7Message		*message;
	
	if(!_requested && [[_administration connection] isConnected] && [[[_administration connection] account] eventsViewEvents]) {
		message = [WIP7Message messageWithName:@"wired.event.get_events" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredEventGetEventsReply:)];
		
		message = [WIP7Message messageWithName:@"wired.event.subscribe" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredEventSubscribeReply:)];
		
		_requested = YES;
	}
}



- (void)_sortEvents {
	NSTableColumn   *tableColumn;

	tableColumn = [_eventsTableView highlightedTableColumn];
	
	if(tableColumn == _timeTableColumn)
		[_shownEvents sortUsingSelector:@selector(compareTime:)];
	else if(tableColumn == _nickTableColumn)
		[_shownEvents sortUsingSelector:@selector(compareNick:)];
	else if(tableColumn == _loginTableColumn)
		[_shownEvents sortUsingSelector:@selector(compareLogin:)];
	else if(tableColumn == _ipTableColumn)
		[_shownEvents sortUsingSelector:@selector(compareIP:)];
	else if(tableColumn == _imageTableColumn)
		[_shownEvents sortUsingSelector:@selector(compareType:)];
	else if(tableColumn == _messageTableColumn)
		[_shownEvents sortUsingSelector:@selector(compareMessage:)];
}

@end



@implementation WCEventsController

- (id)init {
	self = [super init];
	
	_allEvents			= [[NSMutableArray alloc] init];
	_listedEvents		= [[NSMutableArray alloc] init];
	_receivedEvents		= [[NSMutableArray alloc] init];
	_shownEvents		= [[NSMutableArray alloc] init];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];

	return self;
}



- (void)dealloc {
	[_allEvents release];
	[_listedEvents release];
	[_receivedEvents release];
	[_shownEvents release];
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[_administration connection] addObserver:self selector:@selector(wiredEventEvent:) messageName:@"wired.event.event"];
	
	[_eventsTableView setHighlightedTableColumn:_timeTableColumn sortOrder:WISortAscending];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	_requested = NO;
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	if([[[_administration connection] account] eventsViewEvents]) {
		if([[_administration window] isVisible] && [_administration selectedController] == self)
			[self _requestEvents];
	} else {
		_requested = NO;
	}
}



- (void)wiredEventGetEventsReply:(WIP7Message *)message {
	WCEvent			*event;
	NSUInteger		i, count;
	
	if([[message name] isEqualToString:@"wired.event.list"]) {
		event = [WCEvent eventWithMessage:message];
		
		if(event) {
			event->_formattedTime = [[_dateFormatter stringFromDate:event->_time] retain];
			
			[_listedEvents addObject:event];
		}
	}
	else if([[message name] isEqualToString:@"wired.event.list.done"]) {
		[_allEvents addObjectsFromArray:_listedEvents];
		
		count = [_listedEvents count];
		
		for(i = 0; i < count; i++) {
			event = [_listedEvents objectAtIndex:i];
			
			if([self _filterIncludesEvent:event])
				[_shownEvents addObject:event];
		}
		
		[_listedEvents removeAllObjects];
		
		[_eventsTableView reloadData];
		[_eventsTableView scrollRowToVisible:[_shownEvents count] - 1];
		
		[[_administration connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
		
		[[_administration connection] removeObserver:self message:message];
	}
}



- (void)wiredEventSubscribeReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.okay"]) {
		[[_administration connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
		
		[[_administration connection] removeObserver:self message:message];
	}
}



- (void)wiredEventEvent:(WIP7Message *)message {
	WCEvent			*event;
	
	event = [WCEvent eventWithMessage:message];
	
	if(event) {
		event->_formattedTime = [[_dateFormatter stringFromDate:event->_time] retain];
		
		[_allEvents addObject:event];
		[_receivedEvents addObject:event];
		
		if([_receivedEvents count] > 20)
			[self _refreshReceivedEvents];
		else
			[self performSelectorOnce:@selector(_refreshReceivedEvents) afterDelay:0.1];
	}
}



#pragma mark -

- (void)controllerDidSelect {
	[self _requestEvents];

	[[_administration window] makeFirstResponder:_eventsTableView];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownEvents count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCEvent			*event;
	
	event = [self _eventAtIndex:row];
	
	if(tableColumn == _timeTableColumn)
		return event->_formattedTime;
	else if(tableColumn == _nickTableColumn)
		return event->_nick;
	else if(tableColumn == _loginTableColumn)
		return event->_login;
	else if(tableColumn == _ipTableColumn)
		return event->_ip;
	else if(tableColumn == _imageTableColumn) {
		switch(event->_type) {
			case WCEventUsers:		return [NSImage imageNamed:@"EventsUsers"];		break;
			case WCEventFiles:		return [NSImage imageNamed:@"EventsFiles"];		break;
			case WCEventAccounts:	return [NSImage imageNamed:@"EventsAccounts"];	break;
			case WCEventMessages:	return [NSImage imageNamed:@"EventsMessages"];	break;
			case WCEventBoards:		return [NSImage imageNamed:@"EventsBoards"];	break;
		}
	}
	else if(tableColumn == _messageTableColumn)
		return event->_message;

	return NULL;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard		*pasteboard;
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	WCEvent				*event;
	NSUInteger			index;
	
	array		= [NSMutableArray array];
	indexes		= [_eventsTableView selectedRowIndexes];
	index		= [indexes firstIndex];
	
	while(index != NSNotFound) {
		event = [self _eventAtIndex:index];
		
		[array addObject:[NSSWF:@"%@\t%@\t%@\t%@\t%@",
			event->_formattedTime, event->_nick, event->_login, event->_ip, event->_message]];
		
		index = [indexes indexGreaterThanIndex:index];
    }

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:NULL];
	[pasteboard setString:[array componentsJoinedByString:@"\n"] forType:NSStringPboardType];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_eventsTableView setHighlightedTableColumn:tableColumn];
	[self _sortEvents];
	[_eventsTableView reloadData];
}

@end
