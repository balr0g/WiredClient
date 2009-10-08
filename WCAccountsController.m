/* $Id$ */

/*
 *  Copyright (c) 2003-2009 Axel Andersson
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
#import "WCAccountsController.h"
#import "WCServerConnection.h"

#define	WCAccountsFieldCell					@"WCAccountsFieldCell"
#define	WCAccountsFieldSettings				@"WCAccountsFieldSettings"

@interface WCAccountsController(Private)

- (void)_validate;
- (BOOL)_validateAddAccount;
- (BOOL)_validateDeleteAccount;

- (void)_requestAccounts;

- (NSDictionary *)_settingForRow:(NSInteger)row;

- (BOOL)_verifyUnsavedAndSelectRow:(NSInteger)row;
- (void)_save;
- (BOOL)_canEditAccounts;

- (void)_readAccount:(WCAccount *)account;
- (void)_readAccounts:(NSArray *)accounts;
- (void)_readFromAccounts;
- (void)_validateForAccounts;
- (void)_writeToAccount:(WCAccount *)account;

- (WCAccount *)_accountAtIndex:(NSUInteger)index;
- (NSArray *)_selectedAccounts;
- (void)_reloadGroups;
- (void)_reloadSettings;

@end


@implementation WCAccountsController(Private)

- (void)_validate {
	WCAccount	*account;
	BOOL		save = NO;

	[_addButton setEnabled:[self _validateAddAccount]];
	[_deleteButton setEnabled:[self _validateDeleteAccount]];

	if(_touched && [[_administration connection] isConnected]) {
		account = [[_administration connection] account];
	
		if(_creating && ([account accountCreateUsers] || [account accountCreateGroups]))
			save = YES;
		else if(_editing && ([account accountEditUsers] || [account accountEditGroups]))
			save = YES;
	}

	[_saveButton setEnabled:save];
}



- (BOOL)_validateAddAccount {
	WCAccount		*account;
	
	if(![_administration connection] || ![[_administration connection] isConnected])
		return NO;
	
	account = [[_administration connection] account];

	return ([account accountCreateUsers] || [account accountCreateGroups]);
}



- (BOOL)_validateDeleteAccount {
	NSEnumerator	*enumerator;
	NSArray			*accounts;
	WCAccount		*account, *selectedAccount;
	
	if(![_administration connection] || ![[_administration connection] isConnected])
		return NO;
	
	accounts = [self _selectedAccounts];
	
	if([accounts count] == 0)
		return NO;
	
	account = [[_administration connection] account];
	
	if([account accountDeleteUsers] && [account accountDeleteGroups])
		return YES;

	if([account accountDeleteUsers] || [account accountDeleteGroups]) {
		enumerator = [accounts objectEnumerator];
		
		while((selectedAccount = [enumerator nextObject])) {
			if([selectedAccount isKindOfClass:[WCUserAccount class]] && ![account accountDeleteUsers])
				return NO;
			else if([selectedAccount isKindOfClass:[WCGroupAccount class]] && ![account accountDeleteGroups])
				return NO;
		}
		
		return YES;
	}
	
	return NO;
}



#pragma mark -

- (void)_requestAccounts {
	WIP7Message		*message;
	
	if(!_requested && [[_administration connection] isConnected] && [[[_administration connection] account] accountListAccounts]) {
		[_progressIndicator startAnimation:self];

		[_allAccounts removeAllObjects];
		[_shownAccounts removeAllObjects];

		[_accountsTableView reloadData];

		message = [WIP7Message messageWithName:@"wired.account.list_users" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];

		message = [WIP7Message messageWithName:@"wired.account.list_groups" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];
		
		message = [WIP7Message messageWithName:@"wired.account.subscribe_accounts" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountSubscribeAccountsReply:)];
		
		_requested = YES;
	}
}



- (void)_reloadAccounts {
	WIP7Message		*message;
	
	if([[_administration connection] isConnected] && [[[_administration connection] account] accountListAccounts]) {
		[_progressIndicator startAnimation:self];
		
		[_allAccounts removeAllObjects];
		[_shownAccounts removeAllObjects];
		
		[_accountsTableView reloadData];
		
		message = [WIP7Message messageWithName:@"wired.account.list_users" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];
		
		message = [WIP7Message messageWithName:@"wired.account.list_groups" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];
	}
}



#pragma mark -

- (NSDictionary *)_settingForRow:(NSInteger)row {
	return [_shownSettings objectAtIndex:row];
}



#pragma mark -

- (BOOL)_verifyUnsavedAndSelectRow:(NSInteger)row {
	NSAlert		*alert;
	NSString	*name;
	
	if(_touched) {
		name = [_nameTextField stringValue];
		
		if([name length] > 0) {
			alert = [[NSAlert alloc] init];
			[alert setMessageText:[NSSWF:NSLS(@"Save changes to the \u201c%@\u201d account?", @"Save account dialog title (name)"), name]];
			[alert setInformativeText:NSLS(@"If you don't save the changes, they will be lost.", @"Save account dialog description")];
			[alert addButtonWithTitle:NSLS(@"Save", @"Save account dialog button")];
			[alert addButtonWithTitle:NSLS(@"Cancel", @"Save account dialog button")];
			[alert addButtonWithTitle:NSLS(@"Don't Save", @"Save account dialog button")];
			[alert beginSheetModalForWindow:[_administration window]
							  modalDelegate:self
							 didEndSelector:@selector(saveSheetDidEnd:returnCode:contextInfo:)
								contextInfo:[[NSNumber alloc] initWithInteger:row]];
			[alert release];
		}
		
		return NO;
	}
	
	return YES;
}



- (void)_save {
	NSEnumerator		*enumerator;
	WCAccount			*account;
	BOOL				reload = YES;
	
	if(_creating) {
		if([_typePopUpButton selectedItem] == _userMenuItem)
			account = [WCUserAccount account];
		else
			account = [WCGroupAccount account];
		
		[account setValues:[[_accounts lastObject] values]];

		[self _writeToAccount:account];
		
		[[_administration connection] sendMessage:[account createAccountMessage]
									 fromObserver:self
										 selector:@selector(wiredAccountChangeAccountReply:)];

		[_selectAccounts removeAllObjects];
		[_selectAccounts addObject:account];
		
		reload = NO;
	} else {
		if([_accounts count] == 1) {
			account = [_accounts lastObject];
			
			[self _writeToAccount:account];
			
			[[_administration connection] sendMessage:[account editAccountMessage]
										 fromObserver:self
											 selector:@selector(wiredAccountChangeAccountReply:)];
			
			if(![[account newName] isEqualToString:[account name]])
				reload = NO;
		} else {
			enumerator = [_accounts objectEnumerator];
		
			while((account = [enumerator nextObject])) {
				[[_administration connection] sendMessage:[account editAccountMessage]
											 fromObserver:self
												 selector:@selector(wiredAccountChangeAccountReply:)];
			}
		}

		[_selectAccounts setArray:_accounts];
	}
	
	[_accounts removeAllObjects];
	
	_creating = NO;
	_editing = NO;
	_touched = NO;

	[self _validateForAccounts];
	[self _readFromAccounts];
	
	if(reload)
		[self _reloadAccounts];
	
	[[_administration window] setDocumentEdited:NO];

	[self _validate];
}



- (BOOL)_canEditAccounts {
	NSEnumerator	*enumerator;
	WCAccount		*account;
	BOOL			user, group, editable;
	
	user		= NO;
	group		= NO;
	enumerator	= [_accounts objectEnumerator];
	
	while((account = [enumerator nextObject])) {
		if([account isKindOfClass:[WCUserAccount class]] || (_creating && [_typePopUpButton selectedItem] == _userMenuItem))
			user = YES;
		else if([account isKindOfClass:[WCGroupAccount class]] || (_creating && [_typePopUpButton selectedItem] == _groupMenuItem))
			group = YES;
	}
	
	editable	= YES;
	account		= [[_administration connection] account];
	
	if(user) {
		if(_creating && ![account accountCreateUsers])
			editable = NO;
		else if(_editing && ![account accountEditUsers])
			editable = NO;
	}
	
	if(group) {
		if(_creating && ![account accountCreateGroups])
			editable = NO;
		else if(_editing && ![account accountEditGroups])
			editable = NO;
	}
	
	return editable;
}



#pragma mark -

- (void)_readAccount:(WCAccount *)account {
	WIP7Message		*message;
	
	if([account isKindOfClass:[WCUserAccount class]])
		message = [WIP7Message messageWithName:@"wired.account.read_user" spec:WCP7Spec];
	else
		message = [WIP7Message messageWithName:@"wired.account.read_group" spec:WCP7Spec];

	[message setString:[account name] forName:@"wired.account.name"];
	[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountReadAccountReply:)];
	
	[_progressIndicator startAnimation:self];
}



- (void)_readAccounts:(NSArray *)accounts {
	NSEnumerator	*enumerator;
	WCAccount		*account;
	
	[_accounts removeAllObjects];
	
	_requestedAccounts = [accounts count];
	
	enumerator = [accounts objectEnumerator];
	
	while((account = [enumerator nextObject]))
		[self _readAccount:account];
}



- (void)_readFromAccounts {
	NSEnumerator		*enumerator;
	NSDictionary		*section;
	WCAccount			*account;
	
	if([_accounts count] == 1) {
		account = [_accounts lastObject];

		if(_editing) {
			if([account isKindOfClass:[WCUserAccount class]]) {
				[_typePopUpButton selectItem:_userMenuItem];
				
				if([(WCUserAccount *) account fullName])
					[_fullNameTextField setStringValue:[(WCUserAccount *) account fullName]];
				else
					[_fullNameTextField setStringValue:@""];
				
				if([(WCUserAccount *) account password] && ![[(WCUserAccount *) account password] isEqualToString:[@"" SHA1]])
					[_passwordTextField setStringValue:[(WCUserAccount *) account password]];
				else
					[_passwordTextField setStringValue:@""];
				
				if([[(WCUserAccount *) account group] length] > 0)
					[_groupPopUpButton selectItemWithTitle:[(WCUserAccount *) account group]];
				else
					[_groupPopUpButton selectItem:_noneMenuItem];
				
				if([(WCUserAccount *) account groups])
					[_groupsTokenField setStringValue:[[(WCUserAccount *) account groups] componentsJoinedByString:@","]];
				else
					[_groupsTokenField setStringValue:@""];
		
				if([(WCUserAccount *) account loginDate] && ![[(WCUserAccount *) account loginDate] isAtBeginningOfAnyEpoch])
					[_loginTimeTextField setStringValue:[_dateFormatter stringFromDate:[(WCUserAccount *) account loginDate]]];
				else
					[_loginTimeTextField setStringValue:@""];
				
				[_downloadsTextField setStringValue:[NSSWF:NSLS(@"%u completed, %@ transferred", @"Account transfer stats (count, transferred"),
					[(WCUserAccount *) account downloads],
					[NSString humanReadableStringForSizeInBytes:[(WCUserAccount *) account downloadTransferred]]]];
				
				[_uploadsTextField setStringValue:[NSSWF:NSLS(@"%u completed, %@ transferred", @"Account transfer stats (count, transferred"),
					[(WCUserAccount *) account uploads],
					[NSString humanReadableStringForSizeInBytes:[(WCUserAccount *) account uploadTransferred]]]];
			}
			else if([account isKindOfClass:[WCGroupAccount class]]) {
				[_typePopUpButton selectItem:_groupMenuItem];
				[_fullNameTextField setStringValue:@""];
				[_passwordTextField setStringValue:@""];
				[_groupPopUpButton selectItem:_noneMenuItem];
				[_loginTimeTextField setStringValue:@""];
				[_downloadsTextField setStringValue:@""];
				[_uploadsTextField setStringValue:@""];
			}
			
			[_nameTextField setStringValue:[account name]];
			[_commentTextView setString:[account comment]];

			if([account creationDate] && ![[account creationDate] isAtBeginningOfAnyEpoch])
				[_creationTimeTextField setStringValue:[_dateFormatter stringFromDate:[account creationDate]]];
			else
				[_creationTimeTextField setStringValue:@""];

			if([account modificationDate] && ![[account modificationDate] isAtBeginningOfAnyEpoch])
				[_modificationTimeTextField setStringValue:[_dateFormatter stringFromDate:[account modificationDate]]];
			else
				[_modificationTimeTextField setStringValue:@""];

			if([account editedBy])
				[_editedByTextField setStringValue:[account editedBy]];
			else
				[_editedByTextField setStringValue:@""];
		}
	} else {
		[_typePopUpButton selectItem:_userMenuItem];
		[_nameTextField setStringValue:@""];
		[_fullNameTextField setStringValue:@""];
		[_passwordTextField setStringValue:@""];
		[_groupPopUpButton selectItem:_noneMenuItem];
		[_groupsTokenField setStringValue:@""];
		[_commentTextView setString:@""];
		[_creationTimeTextField setStringValue:@""];
		[_modificationTimeTextField setStringValue:@""];
		[_loginTimeTextField setStringValue:@""];
		[_editedByTextField setStringValue:@""];
		[_downloadsTextField setStringValue:@""];
		[_uploadsTextField setStringValue:@""];
	}
	
	[self _reloadSettings];
	
	[_settingsOutlineView reloadData];

	enumerator = [_shownSettings objectEnumerator];
	
	while((section = [enumerator nextObject]))
		[_settingsOutlineView expandItem:section];
}



- (void)_validateForAccounts {
	WCAccount	*account;
	BOOL		editable;
	
	[_userMenuItem setEnabled:[[[_administration connection] account] accountCreateUsers]];
	[_groupMenuItem setEnabled:[[[_administration connection] account] accountCreateGroups]];
	
	if([_accounts count] == 1) {
		account		= [_accounts lastObject];
		editable	= [self _canEditAccounts];
		
		[_typePopUpButton setEnabled:(_creating && editable)];
		[_nameTextField setEnabled:editable];
		
		if([account isKindOfClass:[WCUserAccount class]] || (_creating && [_typePopUpButton selectedItem] == _userMenuItem)) {
			[_fullNameTextField setEnabled:editable];
			[_passwordTextField setEnabled:editable];
			[_groupPopUpButton setEnabled:editable];
			[_groupsTokenField setEnabled:editable];
		}
		else if([account isKindOfClass:[WCGroupAccount class]] || (_creating && [_typePopUpButton selectedItem] == _groupMenuItem)) {
			[_fullNameTextField setEnabled:NO];
			[_passwordTextField setEnabled:NO];
			[_groupPopUpButton setEnabled:NO];
			[_groupsTokenField setEnabled:NO];
		}

		[_commentTextView setEditable:editable];
		[_selectAllButton setEnabled:YES];
	}
	else if([_accounts count] == 0) {
		[_typePopUpButton setEnabled:NO];
		[_nameTextField setEnabled:NO];
		[_fullNameTextField setEnabled:NO];
		[_passwordTextField setEnabled:NO];
		[_groupPopUpButton setEnabled:NO];
		[_groupsTokenField setEnabled:NO];
		[_commentTextView setEditable:NO];
		[_selectAllButton setEnabled:NO];
	}
	else {
		[_typePopUpButton setEnabled:NO];
		[_nameTextField setEnabled:NO];
		[_fullNameTextField setEnabled:NO];
		[_passwordTextField setEnabled:NO];
		[_groupPopUpButton setEnabled:NO];
		[_groupsTokenField setEnabled:NO];
		[_commentTextView setEditable:NO];
		[_selectAllButton setEnabled:YES];
	}
	
	[_settingsOutlineView setNeedsDisplay:YES];
}



- (void)_writeToAccount:(WCAccount *)account {
	NSString		*password, *group;
	NSArray			*groups;
	
	if(_editing)
		[account setNewName:[_nameTextField stringValue]];
	else
		[account setName:[_nameTextField stringValue]];
	
	[account setComment:[_commentTextView string]];
	
	if([account isKindOfClass:[WCUserAccount class]]) {
		[(WCUserAccount *) account setFullName:[_fullNameTextField stringValue]];

		if([[_passwordTextField stringValue] isEqualToString:@""])
			password = [@"" SHA1];
		else if(![[(WCUserAccount *) account password] isEqualToString:[_passwordTextField stringValue]])
			password = [[_passwordTextField stringValue] SHA1];
		else
			password = [(WCUserAccount *) account password];
		
		[(WCUserAccount *) account setPassword:password];
		
		if([_groupPopUpButton selectedItem] != _noneMenuItem)
			group = [_groupPopUpButton titleOfSelectedItem];
		else
			group = @"";
		
		[(WCUserAccount *) account setGroup:group];

		groups = [[_groupsTokenField stringValue] componentsSeparatedByCharactersFromSet:[_groupsTokenField tokenizingCharacterSet]];
		
		if(!groups)
			groups = [NSArray array];

		[(WCUserAccount *) account setGroups:groups];
	}
}



#pragma mark -

- (WCAccount *)_accountAtIndex:(NSUInteger)index {
	NSUInteger		i;
	
	i = ([_accountsTableView sortOrder] == WISortDescending)
		? [_shownAccounts count] - index - 1
		: index;
	
	return [_shownAccounts objectAtIndex:i];
}



- (NSArray *)_selectedAccounts {
	NSMutableArray		*array;
	NSIndexSet			*indexes;
	NSUInteger			index;
	
	array = [NSMutableArray array];
	indexes = [_accountsTableView selectedRowIndexes];
	index = [indexes firstIndex];
	
	while(index != NSNotFound) {
		[array addObject:[self _accountAtIndex:index]];
		
		index = [indexes indexGreaterThanIndex:index];
	}
	
	return array;
}



- (void)_reloadGroups {
	NSEnumerator		*enumerator;
	NSMutableArray		*groupAccounts;
	WCAccount			*account;
	
	while([_groupPopUpButton numberOfItems] > 1)
		[_groupPopUpButton removeItemAtIndex:1];
	
	while([_groupFilterPopUpButton numberOfItems] > 2)
		[_groupFilterPopUpButton removeItemAtIndex:2];

	groupAccounts	= [NSMutableArray array];
	enumerator		= [_allAccounts objectEnumerator];
	
	while((account = [enumerator nextObject])) {
		if([account isKindOfClass:[WCGroupAccount class]])
			[groupAccounts addObject:account];
	}
	
	if([groupAccounts count] > 0) {
		[[_groupFilterPopUpButton menu] addItem:[NSMenuItem separatorItem]];
		[[_groupPopUpButton menu] addItem:[NSMenuItem separatorItem]];
		
		enumerator = [groupAccounts objectEnumerator];
	
		while((account = [enumerator nextObject])) {
			if([account isKindOfClass:[WCGroupAccount class]]) {
				[_groupFilterPopUpButton addItemWithTitle:[account name]];
				[_groupPopUpButton addItemWithTitle:[account name]];
			}
		}
	}
}



- (void)_reloadSettings {
	NSEnumerator			*enumerator, *settingsEnumerator, *accountsEnumerator;
	NSMutableDictionary		*newSection;
	NSMutableArray			*settings;
	NSDictionary			*section, *setting;
	WCAccount				*account;
	
	if([_showPopUpButton selectedItem] == _allSettingsMenuItem) {
		[_shownSettings setArray:_allSettings];
	} else {
		[_shownSettings removeAllObjects];
	
		enumerator = [_allSettings objectEnumerator];
		
		while((section = [enumerator nextObject])) {
			settings			= [NSMutableArray array];
			settingsEnumerator	= [[section objectForKey:WCAccountsFieldSettings] objectEnumerator];
			
			while((setting = [settingsEnumerator nextObject])) {
				accountsEnumerator = [_accounts objectEnumerator];
				
				while((account = [accountsEnumerator nextObject])) {
					if([account valueForKey:[setting objectForKey:WCAccountFieldName]]) {
						[settings addObject:setting];
						
						break;
					}
				}
			}
			
			if([settings count] > 0) {
				newSection = [[section mutableCopy] autorelease];
				[newSection setObject:settings forKey:WCAccountsFieldSettings];
				[_shownSettings addObject:newSection];
			}
		}
	}
	
	[_settingsOutlineView reloadData];
	
	enumerator = [_shownSettings objectEnumerator];
	
	while((section = [enumerator nextObject]))
		[_settingsOutlineView expandItem:section];
}



- (BOOL)_filterIncludesAccount:(WCAccount *)account {
	NSMenuItem		*item;
	BOOL			passed;
	
	if([_allFilterButton state] != NSOnState) {
		passed = NO;
		
		if([_usersFilterButton state] == NSOnState && [account isKindOfClass:[WCUserAccount class]])
			passed = YES;
		else if([_groupsFilterButton state] == NSOnState && [account isKindOfClass:[WCGroupAccount class]])
			passed = YES;
	
		if(!passed)
			return NO;
	}
	
	item = [_groupFilterPopUpButton selectedItem];
	
	if(item != _anyGroupMenuItem) {
		passed = NO;
		
		if([account isKindOfClass:[WCUserAccount class]]) {
			if(item == _noGroupMenuItem)
				passed = [[(WCUserAccount *) account group] isEqualToString:@""];
			else
				passed = [[(WCUserAccount *)account group] isEqualToString:[item title]];
		}
		
		if(!passed)
			return NO;
	}
	
	if(_accountFilter) {
		passed = NO;
		
		if([[account name] containsSubstring:_accountFilter])
			passed = YES;
		
		if([account isKindOfClass:[WCUserAccount class]]) {
			if([[(WCUserAccount *) account fullName] containsSubstring:_accountFilter])
				passed = YES;
		}

		if(!passed)
			return NO;
	}
	
	return YES;
}



- (void)_reloadFilter {
	NSEnumerator	*enumerator;
	WCAccount		*account;
	
	[_shownAccounts removeAllObjects];
	
	enumerator = [_allAccounts objectEnumerator];
	
	while((account = [enumerator nextObject])) {
		if([self _filterIncludesAccount:account])
			[_shownAccounts addObject:account];
	}
}

@end



@implementation WCAccountsController

- (id)init {
	NSEnumerator			*enumerator;
	NSMutableDictionary		*setting;
	NSDictionary			*field;
	NSMutableArray			*basicsSettings, *filesSettings, *boardsSettings, *trackerSettings, *usersSettings, *accountsSettings, *administrationSettings, *limitsSettings;
	NSButtonCell			*buttonCell;
	NSTextFieldCell			*textFieldCell;
	
	self = [super init];
	
	_allAccounts			= [[NSMutableArray alloc] init];
	_shownAccounts			= [[NSMutableArray alloc] init];
	_userImage				= [[NSImage imageNamed:@"User"] retain];
	_groupImage				= [[NSImage imageNamed:@"Group"] retain];
	_accounts				= [[NSMutableArray alloc] init];
	_selectAccounts			= [[NSMutableArray alloc] init];
	_deletedAccounts		= [[NSMutableDictionary alloc] init];

	basicsSettings			= [NSMutableArray array];
	filesSettings			= [NSMutableArray array];
	boardsSettings			= [NSMutableArray array];
	trackerSettings			= [NSMutableArray array];
	usersSettings			= [NSMutableArray array];
	accountsSettings		= [NSMutableArray array];
	administrationSettings	= [NSMutableArray array];
	limitsSettings			= [NSMutableArray array];
	enumerator				= [[WCAccount fields] objectEnumerator];
	
	while((field = [enumerator nextObject])) {
		setting = [[field mutableCopy] autorelease];
		
		switch([[setting objectForKey:WCAccountFieldType] intValue]) {
			case WCAccountFieldBoolean:
				buttonCell = [[NSButtonCell alloc] initTextCell:@""];
				[buttonCell setButtonType:NSSwitchButton];
				[buttonCell setControlSize:NSSmallControlSize];
				[buttonCell setAllowsMixedState:YES];
				[setting setObject:buttonCell forKey:WCAccountsFieldCell];
				[buttonCell release];
				break;

			case WCAccountFieldNumber:
			case WCAccountFieldString:
				textFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
				[textFieldCell setControlSize:NSSmallControlSize];
				[textFieldCell setEditable:YES];
				[textFieldCell setSelectable:YES];
				[textFieldCell setFont:[NSFont smallSystemFont]];
				[setting setObject:textFieldCell forKey:WCAccountsFieldCell];
				[textFieldCell release];
				break;
		}
		
		switch([[setting objectForKey:WCAccountFieldSection] intValue]) {
			case WCAccountFieldBasics:
				[basicsSettings addObject:setting];
				break;

			case WCAccountFieldFiles:
				[filesSettings addObject:setting];
				break;

			case WCAccountFieldBoards:
				[boardsSettings addObject:setting];
				break;

			case WCAccountFieldTracker:
				[trackerSettings addObject:setting];
				break;

			case WCAccountFieldUsers:
				[usersSettings addObject:setting];
				break;

			case WCAccountFieldAccounts:
				[accountsSettings addObject:setting];
				break;

			case WCAccountFieldAdministration:
				[administrationSettings addObject:setting];
				break;

			case WCAccountFieldLimits:
				[limitsSettings addObject:setting];
				break;
		}
	}
	
	_allSettings = [[NSArray alloc] initWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Basics", @"Account section"),			WCAccountFieldLocalizedName,
			basicsSettings,									WCAccountsFieldSettings,
			NULL],	
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Files", @"Account section"),				WCAccountFieldLocalizedName,
			filesSettings,									WCAccountsFieldSettings,
			NULL],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Boards", @"Account section"),			WCAccountFieldLocalizedName,
			boardsSettings,									WCAccountsFieldSettings,
			NULL],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Tracker", @"Account section"),			WCAccountFieldLocalizedName,
			trackerSettings,								WCAccountsFieldSettings,
			NULL],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Users", @"Account section"),				WCAccountFieldLocalizedName,
			usersSettings,									WCAccountsFieldSettings,
			NULL],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Accounts", @"Account section"),			WCAccountFieldLocalizedName,
			accountsSettings,								WCAccountsFieldSettings,
			NULL],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Administration", @"Account section"),	WCAccountFieldLocalizedName,
			administrationSettings,							WCAccountsFieldSettings,
			NULL],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLS(@"Limits", @"Account section"),			WCAccountFieldLocalizedName,
			limitsSettings,									WCAccountsFieldSettings,
			NULL],
		NULL];
	
	_shownSettings = [_allSettings mutableCopy];

	return self;
}



- (void)dealloc {
	[_allSettings release];
	[_shownSettings release];
	
	[_userImage release];
	[_groupImage release];

	[_allAccounts release];
	[_shownAccounts release];
	
	[_accounts release];
	[_selectAccounts release];
	
	[_dateFormatter release];
	[_accountFilter release];
	
	[_deletedAccounts release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[[_administration connection] addObserver:self
									 selector:@selector(wiredAccountAccountsChanged:)
								  messageName:@"wired.account.accounts_changed"];
	
	[_accountsTableView setTarget:self];
	[_accountsTableView setDeleteAction:@selector(delete:)];
	
	[_settingsOutlineView setTarget:self];
	[_settingsOutlineView setDeleteAction:@selector(clearSetting:)];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _validateForAccounts];
	[self _readFromAccounts];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	[_allAccounts removeAllObjects];
	[_shownAccounts removeAllObjects];
	
	[_accountsTableView reloadData];
	
	_requested = NO;

	[self _validate];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _requestAccounts];
	[self _validate];
	[self _validateForAccounts];
}



- (void)wiredAccountAccountsChanged:(WIP7Message *)message {
	[self _reloadAccounts];
}



- (void)wiredAccountListAccountsReply:(WIP7Message *)message {
	NSEnumerator		*enumerator;
	NSMutableIndexSet	*indexes;
	WCAccount			*account;
	NSUInteger			index;
	
	if([[message name] isEqualToString:@"wired.account.user_list"]) {
		[_allAccounts addObject:[WCUserAccount accountWithMessage:message]];
	}
	else if([[message name] isEqualToString:@"wired.account.user_list.done"]) {
	}
	else if([[message name] isEqualToString:@"wired.account.group_list"]) {
		[_allAccounts addObject:[WCGroupAccount accountWithMessage:message]];
	}
	else if([[message name] isEqualToString:@"wired.account.group_list.done"]) {
		[_progressIndicator stopAnimation:self];
		[_allAccounts sortUsingSelector:@selector(compareName:)];
		[self _reloadFilter];
		[self _reloadGroups];
		[_accountsTableView reloadData];
		
		indexes		= [NSMutableIndexSet indexSet];
		enumerator	= [_selectAccounts objectEnumerator];
		
		while((account = [enumerator nextObject])) {
			index = [_shownAccounts indexOfObject:account];
			
			if(index != NSNotFound)
				[indexes addIndex:index];
		}
		
		[_accountsTableView selectRowIndexes:indexes byExtendingSelection:NO];
		[_selectAccounts removeAllObjects];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
	}
}



- (void)wiredAccountSubscribeAccountsReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.okay"]) {
		[[_administration connection] removeObserver:self message:message];
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
		
		[[_administration connection] removeObserver:self message:message];
	}
}



- (void)wiredAccountReadAccountReply:(WIP7Message *)message {
	WCUserAccount	*userAccount;
	WCAccount		*account;
	
	if([[message name] isEqualToString:@"wired.account.user"] || [[message name] isEqualToString:@"wired.account.group"]) {
		if([[message name] isEqualToString:@"wired.account.user"])
			account = [WCUserAccount accountWithMessage:message];
		else
			account = [WCGroupAccount accountWithMessage:message];
		
		if(_requestedAccounts <= 1 && [_accounts count] == 1) {
			userAccount = [_accounts lastObject];
			
			if([userAccount isKindOfClass:[WCUserAccount class]] && [account isKindOfClass:[WCGroupAccount class]] &&
			   [[userAccount group] isEqualToString:[account name]]) {
				[userAccount setGroupAccount:(WCGroupAccount *) account];
			}
			
			[_progressIndicator stopAnimation:self];
			
			[self _validateForAccounts];
			[self _readFromAccounts];
		} else {
			[_accounts addObject:account];
			
			if([_accounts count] == _requestedAccounts) {
				if([_accounts count] == 1) {
					if([account isKindOfClass:[WCUserAccount class]] && [[(WCUserAccount *) account group] length] > 0)
						[self _readAccount:[WCGroupAccount accountWithName:[(WCUserAccount *) account group]]]; 
				}
				
				[_progressIndicator stopAnimation:self];
			
				_editing = YES;

				[self _validateForAccounts];
				[self _readFromAccounts];
			}
		}
		
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[_administration showError:[WCError errorWithWiredMessage:message]];
	}
}



- (void)wiredAccountChangeAccountReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_administration showError:[WCError errorWithWiredMessage:message]];
}



- (void)wiredAccountDeleteAccountReply:(WIP7Message *)message {
	NSEnumerator	*enumerator;
	NSArray			*accounts;
	NSAlert			*alert;
	NSNumber		*key;
	NSString		*title, *description;
	WCError			*error;
	NSUInteger		lastTransaction;
	WIP7UInt32		transaction;
	
	if([[message name] isEqualToString:@"wired.okay"] || [[message name] isEqualToString:@"wired.error"]) {
		if([[message name] isEqualToString:@"wired.error"])
			error = [WCError errorWithWiredMessage:message];
		else
			error = NULL;
		
		if([message getUInt32:&transaction forName:@"wired.transaction"]) {
			if([[message name] isEqualToString:@"wired.okay"] || [error code] != WCWiredProtocolAccountInUse)
				[_deletedAccounts removeObjectForKey:[NSNumber numberWithUnsignedInteger:transaction]];
			
			lastTransaction		= 0;
			enumerator			= [_deletedAccounts keyEnumerator];
			
			while((key = [enumerator nextObject])) {
				if([key unsignedIntegerValue] > lastTransaction)
					lastTransaction = [key unsignedIntegerValue];
			}
			
			if(lastTransaction > 0 && lastTransaction <= transaction) {
				accounts = [_deletedAccounts allValues];
				
				if([accounts count] == 1) {
					title = [NSSWF:
						NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete account dialog title (filename)"),
						[[accounts objectAtIndex:0] name]];
					description = NSLS(@"The account is currently used by a logged in user. Deleting it will disconnect the affected user. This cannot be undone.",
									   @"Delete and disconnect account dialog description");
				} else {
					title = [NSSWF:
						NSLS(@"Are you sure you want to delete %lu items?", @"Delete and disconnect account dialog title (count)"),
						[accounts count]];
					description = NSLS(@"The accounts are currently used by logged in users. Deleting them will disconnect the affected users. This cannot be undone.",
									   @"Delete and disconnect account dialog description");
				}
				
				alert = [[NSAlert alloc] init];
				[alert setMessageText:title];
				[alert setInformativeText:description];
				[alert addButtonWithTitle:NSLS(@"Delete & Disconnect", @"Delete and disconnect account dialog button title")];
				[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete and disconnect account dialog button title")];
				[alert beginSheetModalForWindow:[_administration window]
								  modalDelegate:self
								 didEndSelector:@selector(deleteAndDisconnectSheetDidEnd:returnCode:contextInfo:)
									contextInfo:NULL];
				[alert release];
			}
		}
		
		if(error && [error code] != WCWiredProtocolAccountInUse)
			[_administration showError:error];

		[[_administration connection] removeObserver:self message:message];
	}
}



- (void)wiredAccountChangePasswordReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"])
		[_administration showError:[WCError errorWithWiredMessage:message]];
}



- (void)textDidChange:(NSNotification *)notification {
	[self touch:self];
}



- (void)controlTextDidChange:(NSNotification *)notification {
	[self touch:self];
}



- (NSArray *)tokenField:(NSTokenField *)tokenField completionsForSubstring:(NSString *)substring indexOfToken:(NSInteger)tokenIndex indexOfSelectedItem:(NSInteger *)selectedIndex {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	WCAccount			*account;
	
	array = [NSMutableArray array];
	enumerator = [_allAccounts objectEnumerator];
	
	while((account = [enumerator nextObject])) {
		if([account isKindOfClass:[WCGroupAccount class]] && [[account name] hasPrefix:substring])
			[array addObject:[account name]];
	}
	
	return array;
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	
	selector = [item action];
	
	if(selector == @selector(newDocument:))
		return [self _validateAddAccount];
	else if(selector == @selector(deleteDocument:))
		return [self _validateDeleteAccount];
	
	return YES;
}



#pragma mark -

- (BOOL)controllerWindowShouldClose {
	return [self _verifyUnsavedAndSelectRow:-2];
}



- (void)controllerDidSelect {
	[[_administration window] makeFirstResponder:_accountsTableView];
}



- (BOOL)controllerShouldUnselect {
	return [self _verifyUnsavedAndSelectRow:-1];
}



#pragma mark -

- (NSSize)minimumWindowSize {
	return NSMakeSize(678.0, 571.0);
}



#pragma mark -

- (NSString *)newDocumentMenuItemTitle {
	return NSLS(@"New Account\u2026", @"New menu item");
}



- (NSString *)deleteDocumentMenuItemTitle {
	NSArray			*accounts;
	
	accounts = [self _selectedAccounts];
	
	switch([accounts count]) {
		case 0:
			return NSLS(@"Delete Account\u2026", @"Delete menu item");
			break;
		
		case 1:
			return [NSSWF:NSLS(@"Delete \u201c%@\u201d\u2026", @"Delete menu item (account)"), [[accounts objectAtIndex:0] name]];
			break;
		
		default:
			return [NSSWF:NSLS(@"Delete %u Items\u2026", @"Delete menu item (count)"), [accounts count]];
			break;
	}
}



#pragma mark -

- (NSArray *)accounts {
	return _shownAccounts;
}



- (NSArray *)users {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCAccount		*account;

	array = [NSMutableArray array];
	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account isKindOfClass:[WCUserAccount class]])
			[array addObject:account];
	}

	return array;
}



- (NSArray *)userNames {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCAccount		*account;

	array = [NSMutableArray array];
	enumerator = [[self users] objectEnumerator];

	while((account = [enumerator nextObject]))
		[array addObject:[account name]];
	
	[array sortUsingSelector:@selector(caseInsensitiveCompare:)];

	return array;
}



- (NSArray *)groups {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCAccount		*account;

	array = [NSMutableArray array];
	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account isKindOfClass:[WCGroupAccount class]])
			[array addObject:account];
	}

	return array;
}



- (NSArray *)groupNames {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCAccount		*account;

	array = [NSMutableArray array];
	enumerator = [[self groups] objectEnumerator];

	while((account = [enumerator nextObject]))
		[array addObject:[account name]];
	
	[array sortUsingSelector:@selector(caseInsensitiveCompare:)];

	return array;
}



- (WCAccount *)userWithName:(NSString *)name {
	NSEnumerator	*enumerator;
	WCAccount		*account;

	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account isKindOfClass:[WCUserAccount class]] && [[account name] isEqualToString:name])
			return account;
	}

	return NULL;
}



- (WCAccount *)groupWithName:(NSString *)name {
	NSEnumerator	*enumerator;
	WCAccount		*account;

	enumerator = [[self accounts] objectEnumerator];

	while((account = [enumerator nextObject])) {
		if([account isKindOfClass:[WCGroupAccount class]] && [[account name] isEqualToString:name])
			return account;
	}

	return NULL;
}



- (void)editUserAccountWithName:(NSString *)name {
	WCAccount	*account;
	NSInteger	i, count;
	
	count = [_shownAccounts count];
	
	for(i = 0; i < count; i++) {
		account = [_shownAccounts objectAtIndex:i];
		
		if([account isKindOfClass:[WCUserAccount class]] && [[account name]isEqualToString:name]) {
			[_accountsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
			
			break;
		}
	}
	
	[_administration selectController:self];
	[_administration showWindow:self];
}



#pragma mark -

- (IBAction)newDocument:(id)sender {
	[self addAccount:sender];
}



- (IBAction)deleteDocument:(id)sender {
	[self deleteAccount:sender];
}



- (IBAction)touch:(id)sender {
	_touched = YES;

	[[_administration window] setDocumentEdited:YES];
	
	[self _validate];
}



- (IBAction)addAccount:(id)sender {
	WCUserAccount		*account;
	
	if(![self _validateAddAccount])
		return;
	
	[_accounts removeAllObjects];

	[self _readFromAccounts];

	account = [[[WCUserAccount alloc] init] autorelease];
	[account setName:NSLS(@"Untitled", @"Account name")];
	[_accounts addObject:account];

	_creating	= YES;
	_editing	= NO;
	_touched	= YES;
	
	[_accountsTabView selectTabViewItemAtIndex:0];
	
	if([[[_administration connection] account] accountCreateUsers])
		[_typePopUpButton selectItem:_userMenuItem];
	else
		[_typePopUpButton selectItem:_groupMenuItem];
	
	[_nameTextField setStringValue:[account name]];
	
	[self _validate];
	[self _validateForAccounts];
	[self _readFromAccounts];
	
	[[_administration window] setDocumentEdited:YES];
	
	[[_administration window] makeFirstResponder:_nameTextField];
	[_nameTextField selectText:self];
}



- (IBAction)deleteAccount:(id)sender {
	NSAlert			*alert;
	NSArray			*accounts;
	NSString		*title;
	
	if(![self _validateDeleteAccount])
		return;

	accounts = [self _selectedAccounts];

	if([accounts count] == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete account dialog title (filename)"),
			[[accounts objectAtIndex:0] name]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu items?", @"Delete account dialog title (count)"),
			[accounts count]];
	}

	alert = [[NSAlert alloc] init];
	[alert setMessageText:title];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete account dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete account dialog button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete account dialog button title")];
	[alert beginSheetModalForWindow:[_administration window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteSheetDidEnd:returnCode:contextInfo:)
						contextInfo:NULL];
	[alert release];
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	WIP7Message		*message;
	WCAccount		*account;
	NSUInteger		transaction;

	if(returnCode == NSAlertFirstButtonReturn) {
		enumerator = [[self _selectedAccounts] objectEnumerator];

		while((account = [enumerator nextObject])) {
			if([account isKindOfClass:[WCUserAccount class]]) {
				message = [WIP7Message messageWithName:@"wired.account.delete_user" spec:WCP7Spec];
				[message setBool:NO forName:@"wired.account.disconnect_users"];
			} else {
				message = [WIP7Message messageWithName:@"wired.account.delete_group" spec:WCP7Spec];
			}
			
			[message setString:[account name] forName:@"wired.account.name"];
			
			transaction = [[_administration connection] sendMessage:message
													   fromObserver:self
														   selector:@selector(wiredAccountDeleteAccountReply:)];
			
			[_deletedAccounts setObject:account forKey:[NSNumber numberWithUnsignedInteger:transaction]];
		}
	}
}



- (void)deleteAndDisconnectSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	WIP7Message		*message;
	WCAccount		*account;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		enumerator = [_deletedAccounts objectEnumerator];

		while((account = [enumerator nextObject])) {
			if([account isKindOfClass:[WCUserAccount class]]) {
				message = [WIP7Message messageWithName:@"wired.account.delete_user" spec:WCP7Spec];
				[message setBool:YES forName:@"wired.account.disconnect_users"];
			} else {
				message = [WIP7Message messageWithName:@"wired.account.delete_group" spec:WCP7Spec];
			}
			
			[message setString:[account name] forName:@"wired.account.name"];
			
			[[_administration connection] sendMessage:message
										 fromObserver:self
											 selector:@selector(wiredAccountDeleteAccountReply:)];
		}
	}
	
	[_deletedAccounts removeAllObjects];
}



- (IBAction)all:(id)sender {
	[_usersFilterButton setState:NSOffState];
	[_groupsFilterButton setState:NSOffState];
	
	[self _reloadFilter];

	[_accountsTableView reloadData];
	[_accountsTableView deselectAll:self];
}



- (IBAction)users:(id)sender {
	[_allFilterButton setState:NSOffState];
	[_groupsFilterButton setState:NSOffState];
	
	[self _reloadFilter];
	
	[_accountsTableView reloadData];
	[_accountsTableView deselectAll:self];
}



- (IBAction)groups:(id)sender {
	[_usersFilterButton setState:NSOffState];
	[_allFilterButton setState:NSOffState];

	[self _reloadFilter];
	
	[_accountsTableView reloadData];
	[_accountsTableView deselectAll:self];
}



- (IBAction)groupFilter:(id)sender {
	[self _reloadFilter];
	
	[_accountsTableView reloadData];
}



- (IBAction)search:(id)sender {
	[_accountFilter release];
	
	if([[_filterSearchField stringValue] length] > 0)
		_accountFilter = [[_filterSearchField stringValue] retain];
	else
		_accountFilter = NULL;
	
	[self _reloadFilter];
	
	[_accountsTableView reloadData];
}



- (IBAction)type:(id)sender {
	WCUserAccount		*userAccount;
	
	if(_creating) {
		if([_typePopUpButton selectedItem] == _groupMenuItem) {
			[_groupPopUpButton selectItemAtIndex:0];
		
			userAccount = [_accounts lastObject];
			
			[userAccount setGroup:@""];
			[userAccount setGroupAccount:NULL];
		}
	}
	
	[self _validateForAccounts];
}



- (IBAction)group:(id)sender {
	WCUserAccount		*account;
	
	if([_typePopUpButton selectedItem] == _userMenuItem) {
		account = [_accounts lastObject];
		
		if([_groupPopUpButton selectedItem] != _noneMenuItem) {
			[account setGroup:[_groupPopUpButton titleOfSelectedItem]];
			
			[self _readAccount:[WCGroupAccount accountWithName:[account group]]];
		} else {
			[account setGroup:@""];
			[account setGroupAccount:NULL];
			
			[_settingsOutlineView reloadData];
		}

		[self touch:self];
	} else {
		[_groupPopUpButton selectItemAtIndex:0];
	}
}



- (IBAction)show:(id)sender {
	[self _reloadSettings];
}



- (IBAction)selectAll:(id)sender {
	NSEnumerator		*enumerator, *settingsEnumerator, *accountsEnumerator;
	NSDictionary		*section, *setting;
	WCAccount			*account;
	
	enumerator = [_shownSettings objectEnumerator];
	
	while((section = [enumerator nextObject])) {
		settingsEnumerator = [[section objectForKey:WCAccountsFieldSettings] objectEnumerator];
		
		while((setting = [settingsEnumerator nextObject])) {
			if([[setting objectForKey:WCAccountFieldType] integerValue] == WCAccountFieldBoolean) {
				accountsEnumerator = [_accounts objectEnumerator];
				
				while((account = [accountsEnumerator nextObject]))
					[account setValue:[NSNumber numberWithBool:YES] forKey:[setting objectForKey:WCAccountFieldName]];
			}
		}
	}
	
	[_settingsOutlineView reloadData];
	
	[self touch:self];
}



- (IBAction)clearSetting:(id)sender {
	NSEnumerator		*enumerator;
	NSDictionary		*setting;
	NSString			*name;
	NSIndexSet			*indexes;
	WCAccount			*account;
	NSUInteger			index;
	BOOL				changed = NO;
	
	indexes		= [_settingsOutlineView selectedRowIndexes];
	index		= [indexes firstIndex];
	
	while(index != NSNotFound) {
		setting		= [_settingsOutlineView itemAtRow:index];
		name		= [setting objectForKey:WCAccountFieldName];
		
		if(name) {
			enumerator = [_accounts objectEnumerator];
			
			while((account = [enumerator nextObject]))
				[account setValue:NULL forKey:name];
			
			changed = YES;
		}
		
		index = [indexes indexGreaterThanIndex:index];
	}
	
	if(changed) {
		[self touch:self];
		
		if([_showPopUpButton selectedItem] == _settingsDefinedAtThisLevelMenuItem)
			[self _reloadSettings];
	
		[_settingsOutlineView reloadData];
	}
}



- (IBAction)save:(id)sender {
	[[_administration window] makeFirstResponder:_accountsTableView];
	
	[self _save];
}



- (void)saveSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber	*number = contextInfo;
	NSInteger	row = [number integerValue];

	if(row != -2 || returnCode != NSAlertSecondButtonReturn) {
		if(returnCode == NSAlertFirstButtonReturn) {
			[self _save];
		} else {
			[_accounts removeAllObjects];
			
			_creating = _editing = NO;
		}

		_touched = NO;

		[[_administration window] setDocumentEdited:NO];

		if(row >= 0) {
			[_accountsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		} else {
			[self _validateForAccounts];
			[self _readFromAccounts];
			
			if(row == -2) {
				[_accountsTableView deselectAll:self];

				[_administration close];
			}
		}

		[self _validate];
	}
	
	[number release];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownAccounts count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCAccount		*account;

	account = [self _accountAtIndex:row];

	return [account name];
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if([[self _accountAtIndex:row] isKindOfClass:[WCUserAccount class]])
		[cell setImage:_userImage];
	else
		[cell setImage:_groupImage];
}


- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self _accountAtIndex:row] name];
}



- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
	if(row != [_accountsTableView selectedRow])
		return [self _verifyUnsavedAndSelectRow:row];
	
	return YES;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	if([self _verifyUnsavedAndSelectRow:-1]) {
		if([[[_administration connection] account] accountReadAccounts]) {
			if([_accountsTableView numberOfSelectedRows] > 0) {
				[self _readAccounts:[self _selectedAccounts]];
			} else {
				[_accounts removeAllObjects];
				
				_editing = _creating = NO;

				[self _validateForAccounts];
				[self _readFromAccounts];
			}
		}
		
		[self _validate];
	}
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if([_accounts count] == 0)
		return 0;
	
	if(!item)
		return [_shownSettings count];
	
	return [[item objectForKey:WCAccountsFieldSettings] count];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(!item)
		return [_shownSettings objectAtIndex:index];
	
	return [[item objectForKey:WCAccountsFieldSettings] objectAtIndex:index];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSEnumerator		*enumerator;
	NSMutableSet		*values;
	NSString			*name;
	WCAccount			*account;
	id					value;
	NSInteger			type;
	
	if(tableColumn == _settingTableColumn) {
		return [item objectForKey:WCAccountFieldLocalizedName];
	}
	else if(tableColumn == _valueTableColumn) {
		type = [[item objectForKey:WCAccountFieldType] integerValue];
		name = [item objectForKey:WCAccountFieldName];
		
		if(!name)
			return NULL;
		
		if([_accounts count] == 1) {
			account		= [_accounts lastObject];
			value		= [account valueForKey:name];
			
			if(!value && [account isKindOfClass:[WCUserAccount class]])
				value = [[(WCUserAccount *) account groupAccount] valueForKey:name];
		} else {
			values		= [NSMutableSet set];
			enumerator	= [_accounts objectEnumerator];
			
			while((account = [enumerator nextObject])) {
				value = [account valueForKey:name];
				
				if(value)
					[values addObject:value];
				else
					[values addObject:[NSNull null]];
			}
			
			if([values count] == 1) {
				value = [values anyObject];
				
				if([value isKindOfClass:[NSNull class]])
					value = @"";
			}
			else if([values count] == 0) {
				value = NULL;
			}
			else {
				if(type == WCAccountFieldBoolean)
					value = [NSNumber numberWithInteger:NSMixedState];
				else
					value = NSLS(@"<Multiple values>", @"Account field value");
			}
		}

		if([name isEqualToString:@"wired.account.transfer.download_speed_limit"] ||
		   [name isEqualToString:@"wired.account.transfer.upload_speed_limit"]) {
			if([value isKindOfClass:[NSNumber class]])
				value = [NSNumber numberWithInteger:[value doubleValue] / 1024.0];
		}
		
		if(type == WCAccountFieldNumber && [value isKindOfClass:[NSNumber class]] && [value integerValue] == 0)
			value = NULL;

		return value;
	}

	return NULL;
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _valueTableColumn)
		return ([item objectForKey:WCAccountFieldName] != NULL);

	return NO;
}



- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSEnumerator	*enumerator;
	NSString		*name;
	WCAccount		*account;
	NSInteger		type;
	id				value;
	
	type	= [[item objectForKey:WCAccountFieldType] integerValue];
	name	= [item objectForKey:WCAccountFieldName];
	value	= object;
	
	if(type == WCAccountFieldNumber) {
		if([object isKindOfClass:[NSString class]] && [object length] == 0)
			return;
		
		value = [NSNumber numberWithInteger:[value integerValue]];
	}
	else if(type == WCAccountFieldBoolean) {
		value = [NSNumber numberWithBool:([value integerValue] == -1) ? YES : [value boolValue]];
	}

	if([name isEqualToString:@"wired.account.transfer.download_speed_limit"] ||
	   [name isEqualToString:@"wired.account.transfer.upload_speed_limit"])
		value = [NSNumber numberWithInteger:[value integerValue] * 1024.0];

	enumerator = [_accounts objectEnumerator];
	
	while((account = [enumerator nextObject]))
		[account setValue:value forKey:name];
	
	[self touch:self];
	
	[_settingsOutlineView setNeedsDisplay:YES];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	NSEnumerator	*enumerator;
	NSString		*name;
	WCAccount		*account;
	BOOL			set = NO;
	
	name		= [item objectForKey:WCAccountFieldName];
	enumerator	= [_accounts objectEnumerator];
	
	while((account = [enumerator nextObject])) {
		if([account valueForKey:name]) {
			set = YES;
			
			break;
		}
	}
	
	if(set)
		[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
	else
		[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
	
	if([cell respondsToSelector:@selector(setTextColor:)]) {
		if([[cell objectValue] isEqual:NSLS(@"<Multiple values>", @"Account field value")])
			[cell setTextColor:[NSColor grayColor]];
		else
			[cell setTextColor:[NSColor blackColor]];
	}
	
	if(tableColumn == _valueTableColumn)
		[cell setEnabled:[self _canEditAccounts]];
}



- (NSString *)outlineView:(NSOutlineView *)outlineView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation {
	return [item objectForKey:WCAccountFieldToolTip];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return ([[item objectForKey:WCAccountsFieldSettings] count] > 0);
}

@end



@implementation WCAccountsTableColumn

- (id)dataCellForRow:(NSInteger)row {
	id		cell;
	
	cell = [[(NSOutlineView *) [self tableView] itemAtRow:row] objectForKey:WCAccountsFieldCell];
	
	if(cell)
		return cell;
	
	return [super dataCellForRow:row];
}

@end
