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

@interface WCEvent : WIObject {
@public
	NSString					*_formattedTime;
	
	NSDate						*_time;
	NSString					*_nick;
	NSString					*_login;
	NSString					*_ip;
	NSString					*_message;
}

+ (WCEvent *)eventWithMessage:(WIP7Message *)message;

- (NSComparisonResult)compareTime:(WCEvent *)event;
- (NSComparisonResult)compareNick:(WCEvent *)event;
- (NSComparisonResult)compareLogin:(WCEvent *)event;
- (NSComparisonResult)compareIP:(WCEvent *)event;
- (NSComparisonResult)compareMessage:(WCEvent *)event;

@end


@implementation WCEvent

+ (WCEvent *)eventWithMessage:(WIP7Message *)message {
	WCEvent		*event;
	
	event = [[self alloc] init];
	
	event->_time			= [[message dateForName:@"wired.events.time"] retain];
	event->_nick			= [[message stringForName:@"wired.user.nick"] retain];
	event->_login			= [[message stringForName:@"wired.user.login"] retain];
	event->_ip				= [[message stringForName:@"wired.user.ip"] retain];
	event->_message			= [[message stringForName:@"wired.events.string"] retain];
	
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
		message = [WIP7Message messageWithName:@"wired.events.get_events" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredEventsGetEventsReply:)];
		
		message = [WIP7Message messageWithName:@"wired.events.subscribe" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredEventsSubscribeReply:)];
		
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
	[[_administration connection] addObserver:self selector:@selector(wiredEventsEvent:) messageName:@"wired.events.event"];
	
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



- (void)wiredEventsGetEventsReply:(WIP7Message *)message {
	WCEvent			*event;
	NSUInteger		i, count;
	
	if([[message name] isEqualToString:@"wired.events.list"]) {
		event					= [WCEvent eventWithMessage:message];
		event->_formattedTime	= [[_dateFormatter stringFromDate:event->_time] retain];
		
		[_listedEvents addObject:event];
	}
	else if([[message name] isEqualToString:@"wired.events.list.done"]) {
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



- (void)wiredEventsSubscribeReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.okay"]) {
		[[_administration connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
		
		[[_administration connection] removeObserver:self message:message];
	}
}



- (void)wiredEventsEvent:(WIP7Message *)message {
	WCEvent			*event;
	
	event					= [WCEvent eventWithMessage:message];
	event->_formattedTime	= [[_dateFormatter stringFromDate:event->_time] retain];
	
	[_allEvents addObject:event];
	[_receivedEvents addObject:event];
	
	if([_receivedEvents count] > 20)
		[self _refreshReceivedEvents];
	else
		[self performSelectorOnce:@selector(_refreshReceivedEvents) afterDelay:0.1];
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
