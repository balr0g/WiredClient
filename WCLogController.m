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
#import "WCAdministration.h"
#import "WCLogController.h"
#import "WCServerConnection.h"

@interface WCLogEntry : WIObject {
@public
	WCLogLevel						_level;
	NSString						*_time;
	NSString						*_message;
}

@end


@implementation WCLogEntry

- (void)dealloc {
	[_time release];
	[_message release];
	
	[super dealloc];
}

@end



@interface WCLogController(Private)

- (WCLogEntry *)_entryAtIndex:(NSUInteger)index;
- (BOOL)_filterIncludesEntry:(WCLogEntry *)entry;
- (void)_reloadFilter;

@end


@implementation WCLogController(Private)

- (WCLogEntry *)_entryAtIndex:(NSUInteger)index {
	NSUInteger		i;
	
	i = ([_logTableView sortOrder] == WISortDescending)
		? [_shownEntries count] - index - 1
		: index;
	
	return [_shownEntries objectAtIndex:i];
}



- (BOOL)_filterIncludesEntry:(WCLogEntry *)entry {
	BOOL		passed;
	
	if([_allFilterButton state] != NSOnState) {
		passed = NO;
		
		if([_infoFilterButton state] == NSOnState && entry->_level == WCLogInfo)
			passed = YES;
		else if([_warningsFilterButton state] == NSOnState && entry->_level == WCLogWarning)
			passed = YES;
		else if([_errorsFilterButton state] == NSOnState && entry->_level == WCLogError)
			passed = YES;
	
		if(!passed)
			return NO;
	}
	
	if(_messageFilter && ![entry->_message containsSubstring:_messageFilter])
		return NO;
	
	return YES;
}



- (void)_reloadFilter {
	WCLogEntry		*entry;
	NSUInteger		i, count;
	
	[_shownEntries removeAllObjects];
	
	count = [_allEntries count];
	
	for(i = 0; i < count; i++) {
		entry = [_allEntries objectAtIndex:i];
		
		if([self _filterIncludesEntry:entry])
			[_shownEntries addObject:entry];
	}
	
	[_logTableView reloadData];
}

@end



@implementation WCLogController

- (id)init {
	self = [super init];
	
	_allEntries = [[NSMutableArray alloc] init];
	_shownEntries = [[NSMutableArray alloc] init];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];

	return self;
}



- (void)dealloc {
	[_allEntries release];
	[_shownEntries release];
	[_dateFormatter release];
	[_messageFilter release];
	
	[super dealloc];
}



#pragma mark -

- (void)awakeFromNib {
	[_logTableView setHighlightedTableColumn:_timeTableColumn sortOrder:WISortAscending];
}



#pragma mark -

- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	_subscribed = NO;
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	WIP7Message		*message;
	
	if([[[_administration connection] account] logViewLog]) {
		if(!_subscribed) {
			message = [WIP7Message messageWithName:@"wired.log.subscribe" spec:WCP7Spec];
			[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredLogSubscribeReply:)];

			_subscribed = YES;
		}
	} else {
		_subscribed = NO;
	}
}



- (void)wiredLogSubscribeReply:(WIP7Message *)message {
	WCLogEntry		*entry;
	
	if([[message name] isEqualToString:@"wired.log.message"]) {
		entry = [[WCLogEntry alloc] init];

		[message getEnum:&entry->_level forName:@"wired.log.level"];
		entry->_message = [[message stringForName:@"wired.log.message"] retain];
		entry->_time = [[_dateFormatter stringFromDate:[message dateForName:@"wired.log.time"]] retain];
		
		[_allEntries addObject:entry];
		[entry release];
		
		if([self _filterIncludesEntry:entry]) {
			[_shownEntries addObject:entry];
			[_logTableView reloadData];
		}
	} else {
		// error
	}
}



#pragma mark -

- (void)controllerDidSelect {
	[[_administration window] makeFirstResponder:_logTableView];
}



#pragma mark -

- (IBAction)all:(id)sender {
	[_infoFilterButton setState:NSOffState];
	[_warningsFilterButton setState:NSOffState];
	[_errorsFilterButton setState:NSOffState];
	
	[self _reloadFilter];
}



- (IBAction)info:(id)sender {
	[_allFilterButton setState:NSOffState];

	[self _reloadFilter];
}



- (IBAction)warnings:(id)sender {
	[_allFilterButton setState:NSOffState];
	
	[self _reloadFilter];
}



- (IBAction)errors:(id)sender {
	[_allFilterButton setState:NSOffState];

	[self _reloadFilter];
}



- (IBAction)search:(id)sender {
	[_messageFilter release];
	
	if([[_filterSearchField stringValue] length] > 0)
		_messageFilter = [[_filterSearchField stringValue] retain];
	else
		_messageFilter = NULL;
	
	[self _reloadFilter];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownEntries count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCLogEntry		*entry;
	
	entry = [self _entryAtIndex:row];
	
	if(tableColumn == _timeTableColumn)
		return entry->_time;
	else if(tableColumn == _imageTableColumn) {
		switch(entry->_level) {
			case WCLogDebug:		return [NSImage imageNamed:@"LogDebug"];		break;
			case WCLogInfo:			return [NSImage imageNamed:@"LogInfo"];			break;
			case WCLogWarning:		return [NSImage imageNamed:@"LogWarning"];		break;
			case WCLogError:		return [NSImage imageNamed:@"LogError"];		break;
		}
	}
	else if(tableColumn == _messageTableColumn)
		return entry->_message;

	return NULL;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard		*pasteboard;
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	WCLogEntry			*entry;
	NSUInteger			index;
	
	array		= [NSMutableArray array];
	indexes		= [_logTableView selectedRowIndexes];
	index		= [indexes firstIndex];
	
	while(index != NSNotFound) {
		entry = [self _entryAtIndex:index];
		
		[array addObject:[NSSWF:@"%@\t%@", entry->_time, entry->_message]];
		
		index = [indexes indexGreaterThanIndex:index];
    }

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:NULL];
	[pasteboard setString:[array componentsJoinedByString:@"\n"] forType:NSStringPboardType];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	if(tableColumn == _timeTableColumn) {
		[_logTableView setHighlightedTableColumn:tableColumn];
		[_logTableView reloadData];
	}
}

@end
