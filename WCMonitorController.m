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
#import "WCMonitorCell.h"
#import "WCMonitorController.h"
#import "WCServerConnection.h"
#import "WCTransfer.h"
#import "WCUser.h"
#import "WCUserCell.h"
#import "WCUserInfo.h"

@interface WCMonitorController(Private)

- (void)_validate;
- (BOOL)_validateGetInfo;
- (BOOL)_validateDisconnect;

- (void)_reloadUsers;
- (void)_requestUsers;
- (BOOL)_filterIncludesUser:(WCUser *)user;
- (void)_reloadFilter;

- (WCUser *)_userAtIndex:(NSUInteger)index;
- (WCUser *)_selectedUser;

@end


@implementation WCMonitorController(Private)

- (void)_validate {
	[_disconnectButton setEnabled:[self _validateDisconnect]];
}



- (BOOL)_validateGetInfo {
	return ([self _selectedUser] != NULL &&
			[[_administration connection] isConnected] &&
			[[[_administration connection] account] userGetInfo]);
}



- (BOOL)_validateDisconnect {
	return ([self _selectedUser] != NULL &&
			[[_administration connection] isConnected] &&
			[[[_administration connection] account] userDisconnectUsers]);
}



#pragma mark -

- (void)_reloadUsers {
	if([[_administration window] isVisible] && [_administration selectedController] == self)
		[self _requestUsers];
}



- (void)_requestUsers {
	WIP7Message		*message;
	
	if([[_administration connection] isConnected] && [[[_administration connection] account] userGetUsers]) {
		message = [WIP7Message messageWithName:@"wired.user.get_users" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredUserGetUsersReply:)];
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
	
	_listedUsers	= [[NSMutableArray alloc] init];
	_allUsers		= [[NSMutableArray alloc] init];
	_shownUsers		= [[NSMutableArray alloc] init];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterNormalNaturalLanguageStyle];

	return self;
}



- (void)dealloc {
	[_listedUsers release];
	[_allUsers release];
	[_shownUsers release];
	
	[_dateFormatter release];
	[_userFilter release];
	
	[super dealloc];
}



#pragma mark -

- (void)themeDidChange:(NSDictionary *)theme {
	[_usersTableView setUsesAlternatingRowBackgroundColors:[[theme objectForKey:WCThemesMonitorAlternateRows] boolValue]];
	
	switch([[theme objectForKey:WCThemesMonitorIconSize] integerValue]) {
		case WCThemesMonitorIconSizeLarge:
			[_usersTableView setRowHeight:46.0];
			
			[_iconTableColumn setWidth:[_iconTableColumn maxWidth]];
			[[_nickTableColumn dataCell] setControlSize:NSRegularControlSize];
			[[_statusTableColumn dataCell] setControlSize:NSRegularControlSize];
			break;

		case WCThemesMonitorIconSizeSmall:
			[_usersTableView setRowHeight:17.0];

			[_iconTableColumn setWidth:[_iconTableColumn minWidth]];
			[[_nickTableColumn dataCell] setControlSize:NSSmallControlSize];
			[[_statusTableColumn dataCell] setControlSize:NSSmallControlSize];
			break;
	}
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _validate];
	[self _reloadUsers];
}



- (void)wiredUserGetUsersReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.user.user_list"]) {
		[_listedUsers addObject:[WCUser userWithMessage:message connection:[_administration connection]]];
	}
	else if([[message name] isEqualToString:@"wired.user.user_list.done"]) {
		[_allUsers setArray:_listedUsers];
		[_listedUsers removeAllObjects];
		
		[self _reloadFilter];
		
		[_usersTableView reloadData];
		
		[self performSelectorOnce:@selector(_reloadUsers) afterDelay:1.0];
		
		[[_administration connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
		
		[[_administration connection] removeObserver:self message:message];
	}
}



- (void)wiredUserDisconnectUserReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.okay"]) {
		[[_administration connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
		
		[[_administration connection] removeObserver:self message:message];
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
		return [self _validateGetInfo];
	else if(selector == @selector(disconnect:))
		return [self _validateDisconnect];
	
	return YES;
}



#pragma mark -

- (void)controllerWindowDidBecomeKey {
	[self _reloadUsers];
}



- (void)controllerDidSelect {
	[self _reloadUsers];

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
	[_uploadingFilterButton setState:NSOffState];
	
	[self _reloadFilter];
	
	[_usersTableView reloadData];
}



- (IBAction)uploading:(id)sender {
	[_allFilterButton setState:NSOffState];
	[_downloadingFilterButton setState:NSOffState];

	[self _reloadFilter];
	
	[_usersTableView reloadData];
}



- (IBAction)disconnect:(id)sender {
	if(![self _validateDisconnect])
		return;
	
	[NSApp beginSheet:_disconnectMessagePanel
	   modalForWindow:[_administration window]
		modalDelegate:self
	   didEndSelector:@selector(disconnectSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[self _selectedUser] retain]];
}



- (void)disconnectSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	WCUser			*user = contextInfo;

	if(returnCode == NSOKButton) {
		message = [WIP7Message messageWithName:@"wired.user.disconnect_user" spec:WCP7Spec];
		[message setUInt32:[user userID] forName:@"wired.user.id"];
		[message setString:[_disconnectMessageTextField stringValue] forName:@"wired.user.disconnect_message"];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredUserDisconnectUserReply:)];
	}

	[user release];
	
	[_disconnectMessagePanel close];
	[_disconnectMessageTextField setStringValue:@""];
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
	if(![self _validateGetInfo])
		return;
	
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



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _validate];
}

@end
