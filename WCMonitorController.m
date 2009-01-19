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
#import "WCMonitorCell.h"
#import "WCMonitorController.h"
#import "WCServerConnection.h"
#import "WCTransfer.h"
#import "WCUser.h"
#import "WCUserCell.h"
#import "WCUserInfo.h"

@interface WCMonitorController(Private)

- (void)_reloadUsers;
- (void)_requestUsers;
- (BOOL)_filterIncludesUser:(WCUser *)user;
- (void)_reloadFilter;

- (WCUser *)_userAtIndex:(NSUInteger)index;
- (WCUser *)_selectedUser;

@end


@implementation WCMonitorController(Private)

- (void)_reloadUsers {
	if([[_administration window] isVisible] && [_administration selectedController] == self)
		[self _requestUsers];
}



- (void)_requestUsers {
	WIP7Message		*message;
	
	if([[_administration connection] isConnected] && [[[_administration connection] account] userGetUsers]) {
		[_allUsers removeAllObjects];
		
		message = [WIP7Message messageWithName:@"wired.user.get_users" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredUserGetUsersReply:)];
		
		[self performSelectorOnce:@selector(_reloadUsers) afterDelay:1.0];
	}
}



- (BOOL)_filterIncludesUser:(WCUser *)user {
	BOOL		passed;
	
	if([_allFilterButton state] != NSOnState) {
		passed = NO;
		
		if([_downloadingFilterButton state] == NSOnState && [[user transfer] isKindOfClass:[WCDownloadTransfer class]])
			passed = YES;
		else if([_uploadingFilterButton state] == NSOnState && [[user transfer] isKindOfClass:[WCUploadTransfer class]])
			passed = YES;
	
		if(!passed)
			return NO;
	}
	
	if(_userFilter && ![[user nick] containsSubstring:_userFilter])
		return NO;
	
	return YES;
}



- (void)_reloadFilter {
	WCUser			*user;
	NSUInteger		i, count;
	
	[_shownUsers removeAllObjects];
	
	count = [_allUsers count];
	
	for(i = 0; i < count; i++) {
		user = [_allUsers objectAtIndex:i];
		
		if([self _filterIncludesUser:user])
			[_shownUsers addObject:user];
	}
}



#pragma mark -

- (WCUser *)_userAtIndex:(NSUInteger)index {
	return [_shownUsers objectAtIndex:index];
}



- (WCUser *)_selectedUser {
	NSInteger		row;
	
	row = [_usersTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [self _userAtIndex:row];
}

@end



@implementation WCMonitorController

- (id)init {
	self = [super init];
	
	_allUsers = [[NSMutableArray alloc] init];
	_shownUsers = [[NSMutableArray alloc] init];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterNormalNaturalLanguageStyle];

	return self;
}



- (void)dealloc {
	[_allUsers release];
	[_shownUsers release];
	
	[_dateFormatter release];
	[_userFilter release];
	
	[super dealloc];
}



#pragma mark -

- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _requestUsers];
}



- (void)wiredUserGetUsersReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.user.user_list"]) {
		[_allUsers addObject:[WCUser userWithMessage:message connection:[_administration connection]]];
	}
	else if([[message name] isEqualToString:@"wired.user.user_list.done"]) {
		[self _reloadFilter];
		
		[_usersTableView reloadData];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
	}
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	WCAccount	*account;
	SEL			selector;
	BOOL		connected;
	
	selector	= [item action];
	account		= [[_administration connection] account];
	connected	= [[_administration connection] isConnected];
	
	if(selector == @selector(getInfo:))
		return ([account userGetInfo] && connected);
	
	return YES;
}



#pragma mark -

- (void)controllerWindowDidBecomeKey {
	[self _requestUsers];
}



- (void)controllerDidSelect {
	[self _requestUsers];

	[[_administration window] makeFirstResponder:_usersTableView];
}



#pragma mark -

- (IBAction)all:(id)sender {
	[_downloadingFilterButton setState:NSOffState];
	[_uploadingFilterButton setState:NSOffState];
	
	[self _reloadFilter];

	[_usersTableView reloadData];
}



- (IBAction)downloading:(id)sender {
	[_allFilterButton setState:NSOffState];
	
	[self _reloadFilter];
	
	[_usersTableView reloadData];
}



- (IBAction)uploading:(id)sender {
	[_allFilterButton setState:NSOffState];

	[self _reloadFilter];
	
	[_usersTableView reloadData];
}



- (IBAction)search:(id)sender {
	[_userFilter release];
	
	if([[_filterSearchField stringValue] length] > 0)
		_userFilter = [[_filterSearchField stringValue] retain];
	else
		_userFilter = NULL;
	
	[self _reloadFilter];
	
	[_usersTableView reloadData];
}



- (IBAction)getInfo:(id)sender {
	[WCUserInfo userInfoWithConnection:[_administration connection] user:[self _selectedUser]];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownUsers count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString		*status;
	NSDate			*date;
	WCUser			*user;
	
	user = [self _userAtIndex:row];
	
	if(tableColumn == _iconTableColumn)
		return [user iconWithIdleTint:YES];
	else if(tableColumn == _nickTableColumn) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[user nick],		WCUserCellNickKey,
			[user status],		WCUserCellStatusKey,
			NULL];
	}
	else if(tableColumn == _statusTableColumn) {
		if([user transfer]) {
			return [NSDictionary dictionaryWithObject:[user transfer] forKey:WCMonitorCellTransferKey];
		} else {
			date = [user idleDate];
			status = [NSSWF:NSLS(@"Idle %@, since %@", @"Monitor idle status (time counter, time string)"),
				[NSString humanReadableStringForTimeInterval:[[NSDate date] timeIntervalSinceDate:date]],
				[_dateFormatter stringFromDate:date]];
		
			return [NSDictionary dictionaryWithObject:status forKey:WCMonitorCellStatusKey];
		}
	}
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	WCUser		*user;

	if(column == _nickTableColumn) {
		user = [_shownUsers objectAtIndex:row];

		[cell setTextColor:[user color]];
		[cell setIgnored:[user isIgnored]];
	}
}

@end
