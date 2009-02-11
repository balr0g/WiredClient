/* $Id$ */

/*
 *  Copyright (c) 2003-2007 Axel Andersson
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

#import "NSAlert-WCAdditions.h"
#import "WCAccount.h"
#import "WCAccounts.h"
#import "WCServerConnection.h"

#define	WCAccountsFieldCell					@"WCAccountsFieldCell"
#define	WCAccountsFieldSettings				@"WCAccountsFieldSettings"

@interface WCAccounts(Private)

- (id)_initAccountsWithConnection:(WCServerConnection *)connection;

- (NSDictionary *)_settingForRow:(NSInteger)row;

- (BOOL)_verifyUnsavedAndSelectRow:(NSInteger)row;
- (void)_saveAndClear:(BOOL)clear;
- (BOOL)_isEditableAccount:(WCAccount *)account;

- (void)_readAccount:(WCAccount *)account;
- (void)_validateAccount:(WCAccount *)account;
- (void)_readFromAccount:(WCAccount *)account;
- (void)_writeToAccount:(WCAccount *)account;

- (WCAccount *)_accountAtIndex:(NSUInteger)index;
- (WCAccount *)_selectedAccount;
- (NSArray *)_selectedAccounts;
- (void)_reloadAccounts;
- (void)_reloadGroups;
- (void)_reloadSettings;

@end


@implementation WCAccounts(Private)

- (id)_initAccountsWithConnection:(WCServerConnection *)connection {
	NSEnumerator			*enumerator;
	NSMutableDictionary		*setting;
	NSDictionary			*field;
	NSMutableArray			*basicsSettings, *filesSettings, *boardsSettings, *trackerSettings, *usersSettings, *accountsSettings, *administrationSettings, *limitsSettings;
	NSButtonCell			*buttonCell;
	NSTextFieldCell			*textFieldCell;
	
	self = [super initWithWindowNibName:@"Accounts"
								   name:NSLS(@"Accounts", @"Accounts window title")
							 connection:connection
							  singleton:YES];
	
	_allAccounts			= [[NSMutableArray alloc] init];
	_shownAccounts			= [[NSMutableArray alloc] init];
	_userImage				= [[NSImage imageNamed:@"User"] retain];
	_groupImage				= [[NSImage imageNamed:@"Group"] retain];

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
	
	[self window];

	return self;
}



#pragma mark -

- (NSDictionary *)_settingForRow:(NSInteger)row {
	return [_shownSettings objectAtIndex:row];
}



#pragma mark -

- (BOOL)_verifyUnsavedAndSelectRow:(NSInteger)row {
	NSAlert		*alert;
	NSString	*name;
	
	if(_accountTouched) {
		name = [_nameTextField stringValue];
		
		if([name length] > 0) {
			alert = [[NSAlert alloc] init];
			[alert setMessageText:[NSSWF:NSLS(@"Save changes to the \u201c%@\u201d account?", @"Save account dialog title (name)"), name]];
			[alert setInformativeText:NSLS(@"If you don't save the changes, they will be lost.", @"Save account dialog description")];
			[alert addButtonWithTitle:NSLS(@"Save", @"Save account dialog button")];
			[alert addButtonWithTitle:NSLS(@"Cancel", @"Save account dialog button")];
			[alert addButtonWithTitle:NSLS(@"Don't Save", @"Save account dialog button")];
			[alert beginSheetModalForWindow:[self window]
							  modalDelegate:self
							 didEndSelector:@selector(saveSheetDidEnd:returnCode:contextInfo:)
								contextInfo:[[NSNumber alloc] initWithInteger:row]];
			[alert release];
		}
		
		return NO;
	}
	
	return YES;
}



- (void)_saveAndClear:(BOOL)clear {
	WIP7Message		*message;
	WCAccount		*account;
	
	if([[_nameTextField stringValue] length] == 0)
		return;
	
	if(_editingAccount) {
		[self _writeToAccount:_account];

		message = [_account editAccountMessage];
	} else {
		if([_typePopUpButton selectedItem] == _userMenuItem)
			account = [WCUserAccount account];
		else
			account = [WCGroupAccount account];
		
		[account setValues:[_account values]];

		[self _writeToAccount:account];
		
		message = [account createAccountMessage];
	}
	
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountChangeAccountReply:)];
	
	if(clear && _editingAccount) {
		[_account release];
		_account = NULL;
		[_underlyingAccount release];
		_underlyingAccount = NULL;
		
		_editingAccount = NO;
	}
	
	if(_creatingAccount) {
		[_account release];
		_account = NULL;
		
		_creatingAccount = NO;

		[self _validateAccount:NULL];
		[self _readFromAccount:NULL];
		[self _reloadAccounts];
	}
	
	[[self window] setDocumentEdited:NO];

	_accountTouched = NO;
	
	[self validate];
}



- (BOOL)_isEditableAccount:(WCAccount *)account {
	BOOL		user, group;
	
	user = group = NO;
	
	if([account isKindOfClass:[WCUserAccount class]] || (_creatingAccount && [_typePopUpButton selectedItem] == _userMenuItem))
		user = YES;
	else if([account isKindOfClass:[WCGroupAccount class]] || (_creatingAccount && [_typePopUpButton selectedItem] == _groupMenuItem))
		group = YES;
	
	if(user)
		return _creatingAccount ? [[[self connection] account] accountCreateUsers] : [[[self connection] account] accountEditUsers];
	else if(group)
		return _creatingAccount ? [[[self connection] account] accountCreateGroups] : [[[self connection] account] accountEditGroups];
	
	return NO;
}



#pragma mark -

- (void)_readAccount:(WCAccount *)account {
	WIP7Message		*message;
	
	if([account isKindOfClass:[WCUserAccount class]])
		message = [WIP7Message messageWithName:@"wired.account.read_user" spec:WCP7Spec];
	else
		message = [WIP7Message messageWithName:@"wired.account.read_group" spec:WCP7Spec];

	[message setString:[account name] forName:@"wired.account.name"];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountReadAccountReply:)];
	
	[_progressIndicator startAnimation:self];
}



- (void)_validateAccount:(WCAccount *)account {
	BOOL		editable;
	
	if(account) {
		editable = [self _isEditableAccount:account];
		
		[_typePopUpButton setEnabled:(_creatingAccount && editable)];
		[_nameTextField setEnabled:(_creatingAccount && editable)];
		
		if([account isKindOfClass:[WCUserAccount class]] || (_creatingAccount && [_typePopUpButton selectedItem] == _userMenuItem)) {
			[_fullNameTextField setEnabled:editable];
			[_passwordTextField setEnabled:editable];
			[_groupPopUpButton setEnabled:editable];
			[_groupsTokenField setEnabled:editable];
		}
		else if([account isKindOfClass:[WCGroupAccount class]] || (_creatingAccount && [_typePopUpButton selectedItem] == _groupMenuItem)) {
			[_fullNameTextField setEnabled:NO];
			[_passwordTextField setEnabled:NO];
			[_groupPopUpButton setEnabled:NO];
			[_groupsTokenField setEnabled:NO];
		}
	} else {
		[_typePopUpButton setEnabled:NO];
		[_nameTextField setEnabled:NO];
		[_fullNameTextField setEnabled:NO];
		[_passwordTextField setEnabled:NO];
		[_groupPopUpButton setEnabled:NO];
		[_groupsTokenField setEnabled:NO];
	}
	
	[_settingsOutlineView setNeedsDisplay:YES];
}



- (void)_readFromAccount:(WCAccount *)account {
	NSEnumerator		*enumerator;
	NSDictionary		*section;
	
	if(account) {
		if([account isKindOfClass:[WCUserAccount class]]) {
			[_typePopUpButton selectItem:_userMenuItem];
			[_fullNameTextField setStringValue:[(WCUserAccount *) account fullName]];
			
			if([[(WCUserAccount *) account password] isEqualToString:[@"" SHA1]])
				[_passwordTextField setStringValue:@""];
			else
				[_passwordTextField setStringValue:[(WCUserAccount *) account password]];
			
			if([[(WCUserAccount *) account group] length] > 0)
				[_groupPopUpButton selectItemWithTitle:[(WCUserAccount *) account group]];
			else
				[_groupPopUpButton selectItem:_noneMenuItem];
			
			[_groupsTokenField setStringValue:[[(WCUserAccount *) account groups] componentsJoinedByString:@","]];
	
			if([(WCUserAccount *) account loginDate] && ![[(WCUserAccount *) account loginDate] isAtBeginningOfAnyEpoch])
				[_loginTimeTextField setStringValue:[_dateFormatter stringFromDate:[(WCUserAccount *) account loginDate]]];
			else
				[_loginTimeTextField setStringValue:@""];
		}
		else if([account isKindOfClass:[WCGroupAccount class]]) {
			[_typePopUpButton selectItem:_groupMenuItem];
			[_fullNameTextField setStringValue:@""];
			[_passwordTextField setStringValue:@""];
			[_groupPopUpButton selectItem:_noneMenuItem];
			[_loginTimeTextField setStringValue:@""];
		}
		
		[_nameTextField setStringValue:[account name]];

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
	} else {
		[_typePopUpButton selectItem:_userMenuItem];
		[_nameTextField setStringValue:@""];
		[_fullNameTextField setStringValue:@""];
		[_passwordTextField setStringValue:@""];
		[_groupPopUpButton selectItem:_noneMenuItem];
		[_groupsTokenField setStringValue:@""];
		[_creationTimeTextField setStringValue:@""];
		[_modificationTimeTextField setStringValue:@""];
		[_loginTimeTextField setStringValue:@""];
		[_editedByTextField setStringValue:@""];
	}
	
	[self _reloadSettings];
	
	[_settingsOutlineView reloadData];

	enumerator = [_shownSettings objectEnumerator];
	
	while((section = [enumerator nextObject]))
		[_settingsOutlineView expandItem:section];
}



- (void)_writeToAccount:(WCAccount *)account {
	NSString		*password, *group;
	NSArray			*groups;
	
	[account setName:[_nameTextField stringValue]];
	
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



- (WCAccount *)_selectedAccount {
	NSInteger		row;

	row = [_accountsTableView selectedRow];

	if(row < 0)
		return NULL;

	return [self _accountAtIndex:row];
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



- (void)_reloadAccounts {
	WIP7Message		*message;
	
	[_progressIndicator startAnimation:self];

	[_allAccounts removeAllObjects];
	[_shownAccounts removeAllObjects];

	[_accountsTableView reloadData];

	message = [WIP7Message messageWithName:@"wired.account.list_users" spec:WCP7Spec];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];

	message = [WIP7Message messageWithName:@"wired.account.list_groups" spec:WCP7Spec];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];
}



- (void)_reloadGroups {
	NSEnumerator		*enumerator;
	NSMutableArray		*groupAccounts;
	WCAccount			*account;
	
	while([_groupPopUpButton numberOfItems] > 1)
		[_groupPopUpButton removeItemAtIndex:1];
	
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
	NSEnumerator			*enumerator, *settingsEnumerator;
	NSMutableDictionary		*newSection;
	NSMutableArray			*settings;
	NSDictionary			*section, *setting;
	
	if([_showPopUpButton selectedItem] == _allSettingsMenuItem) {
		[_shownSettings setArray:_allSettings];
	} else {
		[_shownSettings removeAllObjects];
	
		enumerator = [_allSettings objectEnumerator];
		
		while((section = [enumerator nextObject])) {
			settings			= [NSMutableArray array];
			settingsEnumerator	= [[section objectForKey:WCAccountsFieldSettings] objectEnumerator];
			
			while((setting = [settingsEnumerator nextObject])) {
				if([_account valueForKey:[setting objectForKey:WCAccountFieldName]])
					[settings addObject:setting];
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


@implementation WCAccounts

+ (id)accountsWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initAccountsWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_allSettings release];
	[_shownSettings release];
	
	[_userImage release];
	[_groupImage release];

	[_allAccounts release];
	[_shownAccounts release];
	
	[_account release];
	[_underlyingAccount release];
	
	[_dateFormatter release];
	[_accountFilter release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;

	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Accounts"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];

	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Accounts"];

	[_accountsTableView setPropertiesFromDictionary:
		[[WCSettings objectForKey:WCWindowProperties] objectForKey:@"WCAccountsTableView"]];
	[_accountsTableView setDeleteAction:@selector(delete:)];
	[[self window] makeFirstResponder:_accountsTableView];
	
	[_settingsOutlineView setDeleteAction:@selector(clearSetting:)];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _validateAccount:NULL];
	[self _readFromAccount:NULL];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSWindow *)window {
	[WCSettings setObject:[_accountsTableView propertiesDictionary]
				   forKey:@"WCAccountsTableView"
	   inDictionaryForKey:WCWindowProperties];
}



- (BOOL)windowShouldClose:(NSWindow *)window {
	return [self _verifyUnsavedAndSelectRow:-2];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"New"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"New", @"New account toolbar item")
												content:[NSImage imageNamed:@"NewAccount"]
												 target:self
												 action:@selector(add:)];
	}
	else if([identifier isEqualToString:@"Delete"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Delete", @"Delete account toolbar item")
												content:[NSImage imageNamed:@"DeleteAccount"]
												 target:self
												 action:@selector(delete:)];
	}
	else if([identifier isEqualToString:@"Reload"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reload", @"Reload accounts toolbar item")
												content:[NSImage imageNamed:@"ReloadAccounts"]
												 target:self
												 action:@selector(reload:)];
	}
	else if([identifier isEqualToString:@"ChangePassword"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Change Password", @"Change password toolbar item")
												content:[NSImage imageNamed:@"ChangePassword"]
												 target:self
												 action:@selector(changePassword:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"New",
		@"Delete",
		@"Reload",
		NSToolbarSpaceItemIdentifier,
		@"ChangePassword",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"New",
		@"Delete",
		@"Reload",
		@"ChangePassword",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	[_allAccounts removeAllObjects];
	[_shownAccounts removeAllObjects];
	
	_received = NO;
	
	[super linkConnectionLoggedIn:notification];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	if(!_received) {
		if([[[self connection] account] accountListAccounts])
			[self _reloadAccounts];

		_received = YES;
	}
	
	[self _validateAccount:_account];
	
	[super serverConnectionPrivilegesDidChange:notification];
}



- (void)wiredAccountListAccountsReply:(WIP7Message *)message {
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
	}
	else if([[message name] isEqualToString:@"wired.error"]) {
		[[[WCError errorWithWiredMessage:message] alert] beginSheetModalForWindow:[self window]];
	}
}



- (void)wiredAccountReadAccountReply:(WIP7Message *)message {
	WCAccount		*account = NULL;
	
	if([[message name] isEqualToString:@"wired.account.user"])
		account = [WCUserAccount accountWithMessage:message];
	else if([[message name] isEqualToString:@"wired.account.group"])
		account = [WCGroupAccount accountWithMessage:message];
	else if([[message name] isEqualToString:@"wired.error"])
		[[[WCError errorWithWiredMessage:message] alert] beginSheetModalForWindow:[self window]];

	[_progressIndicator stopAnimation:self];

	if(account) {
		if([[account name] isEqualToString:[[self _selectedAccount] name]]) {
			_account = [account retain];
			_editingAccount = YES;
			
			if([_account isKindOfClass:[WCUserAccount class]] && [[(WCUserAccount *) _account group] length] > 0)
				[self _readAccount:[WCGroupAccount accountWithName:[(WCUserAccount *) _account group]]]; 
			
			[self _validateAccount:_account];
			[self _readFromAccount:_account];
			
			[self validate];
		}
		else if([_account isKindOfClass:[WCUserAccount class]] && [[(WCUserAccount *) _account group] isEqualToString:[account name]]) {
			[_underlyingAccount release];
			_underlyingAccount = [account retain];
			
			[self _validateAccount:_account];
			[self _readFromAccount:_account];
		}
	}
}



- (void)wiredAccountChangeAccountReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"]) {
		[[[WCError errorWithWiredMessage:message] alert] beginSheetModalForWindow:[self window]];
	}
}



- (void)wiredAccountDeleteAccountReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"]) {
		[[[WCError errorWithWiredMessage:message] alert] beginSheetModalForWindow:[self window]];
	}
}



- (void)wiredAccountChangePasswordReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.error"]) {
		[[[WCError errorWithWiredMessage:message] alert] beginSheetModalForWindow:[self window]];
	}
}



#pragma mark -

- (void)validate {
	WCAccount	*account;
	BOOL		save, editing, connected;

	account		= [[self connection] account];
	connected	= [[self connection] isConnected];
	editing		= (_creatingAccount || _editingAccount);
	
	save = NO;
	
	if(_accountTouched && connected) {
		if(_creatingAccount && ([account accountCreateUsers] || [account accountCreateGroups]))
			save = YES;
		else if(_editingAccount && ([account accountEditUsers] || [account accountEditGroups]))
			save = YES;
	}

	[_saveButton setEnabled:save];
	
	[[[self window] toolbar] validateVisibleItems];

	[super validate];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	NSEnumerator	*enumerator;
	NSArray			*accounts;
	WCAccount		*account, *eachAccount;
	SEL				selector;
	BOOL			connected;
	NSUInteger		users, groups;

	selector	= [item action];
	account		= [[self connection] account];
	connected	= [[self connection] isConnected];
	accounts	= [self _selectedAccounts];
	enumerator	= [accounts objectEnumerator];
	users		= 0;
	groups		= 0;
	
	while((eachAccount = [enumerator nextObject])) {
		if([eachAccount isKindOfClass:[WCUserAccount class]])
			users++;
		else if([eachAccount isKindOfClass:[WCGroupAccount class]])
			groups++;
	}
	
	if(selector == @selector(add:)) {
		return (([account accountCreateUsers] || [account accountCreateGroups]) && connected);
	}
	else if(selector == @selector(delete:)) {
		if(users > 0 && [account accountDeleteUsers])
			return NO;

		if(groups > 0 && [account accountDeleteGroups])
			return NO;
		
		return (users + groups > 0 && connected);
	}
	else if(selector == @selector(reload:)) {
		return ([account accountListAccounts] && connected);
	}
	else if(selector == @selector(changePassword:)) {
		return ([account accountChangePassword] && connected);
	}
	
	return YES;
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
	
	[self showWindow:self];
}



#pragma mark -

- (IBAction)touch:(id)sender {
	_accountTouched = YES;

	[[self window] setDocumentEdited:YES];
	
	[self validate];
}



- (IBAction)add:(id)sender {
	[_account release];
	_account = NULL;
	
	[_underlyingAccount release];
	_underlyingAccount = NULL;

	_editingAccount = NO;

	_account = [[WCAccount alloc] init];
	[_account setValue:NSLS(@"Untitled", @"Account name") forKey:@"name"];

	_creatingAccount = YES;
	_accountTouched = YES;
	
	[_accountsTabView selectTabViewItemAtIndex:0];
	
	[self _validateAccount:_account];
	[self _readFromAccount:_account];
	
	[self validate];
	
	[[self window] setDocumentEdited:YES];
	
	[[self window] makeFirstResponder:_nameTextField];
	[_nameTextField selectText:self];
}



- (IBAction)delete:(id)sender {
	NSAlert			*alert;
	NSString		*title;
	NSUInteger		count;

	if(![[self connection] isConnected])
		return;

	count = [[self _selectedAccounts] count];

	if(count == 0)
		return;

	if(count == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete account dialog title (filename)"),
			[[self _selectedAccount] name]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu items?", @"Delete account dialog title (count)"),
			count];
	}

	alert = [[NSAlert alloc] init];
	[alert setMessageText:title];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete account dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete account dialog button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete account dialog button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteSheetDidEnd:returnCode:contextInfo:)
						contextInfo:NULL];
	[alert release];
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	WIP7Message		*message;
	WCAccount		*account;

	if(returnCode == NSAlertFirstButtonReturn) {
		enumerator = [[self _selectedAccounts] objectEnumerator];

		while((account = [enumerator nextObject])) {
			if([account isKindOfClass:[WCUserAccount class]])
				message = [WIP7Message messageWithName:@"wired.account.delete_user" spec:WCP7Spec];
			else
				message = [WIP7Message messageWithName:@"wired.account.delete_group" spec:WCP7Spec];
			
			[message setString:[account name] forName:@"wired.account.name"];
			[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountDeleteAccountReply:)];
		}

		[self _reloadAccounts];
	}
}



- (IBAction)reload:(id)sender {
	[self _reloadAccounts];
}



- (IBAction)changePassword:(id)sender {
	[_newPasswordTextField setStringValue:@""];
	[_verifyPasswordTextField setStringValue:@""];
	[_passwordMismatchTextField setHidden:YES];

	[_changePasswordPanel makeFirstResponder:_newPasswordTextField];

	[NSApp beginSheet:_changePasswordPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(changePasswordSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)changePasswordSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;

	[_changePasswordPanel close];

	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.account.change_password" spec:WCP7Spec];
		[message setString:[[_newPasswordTextField stringValue] SHA1] forName:@"wired.account.password"];
		[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountChangePasswordReply:)];
	}
}



- (IBAction)submitPasswordSheet:(id)sender {
	NSString		*newPassword, *verifyPassword;
	
	newPassword		= [_newPasswordTextField stringValue];
	verifyPassword	= [_verifyPasswordTextField stringValue];
	
	if([newPassword isEqualToString:verifyPassword]) {
		[self submitSheet:sender];
	} else {
		NSBeep();
		
		[_passwordMismatchTextField setHidden:NO];
	}
}



- (IBAction)all:(id)sender {
	[_usersFilterButton setState:NSOffState];
	[_groupsFilterButton setState:NSOffState];
	
	[self _reloadFilter];

	[_accountsTableView reloadData];
}



- (IBAction)users:(id)sender {
	[_allFilterButton setState:NSOffState];
	
	[self _reloadFilter];
	
	[_accountsTableView reloadData];
}



- (IBAction)groups:(id)sender {
	[_allFilterButton setState:NSOffState];

	[self _reloadFilter];
	
	[_accountsTableView reloadData];
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
	[self _validateAccount:_account];
}



- (IBAction)group:(id)sender {
	if([_groupPopUpButton selectedItem] != _noneMenuItem) {
		[self _readAccount:[WCGroupAccount accountWithName:[_groupPopUpButton titleOfSelectedItem]]];
	} else {
		[_underlyingAccount release];
		_underlyingAccount = NULL;
		
		[_settingsOutlineView reloadData];
	}

	[self touch:self];
}



- (IBAction)show:(id)sender {
	[self _reloadSettings];
}



- (IBAction)clearSetting:(id)sender {
	NSDictionary	*setting;
	NSString		*name;
	NSIndexSet		*indexes;
	NSUInteger		index;
	BOOL			changed = NO;
	
	indexes		= [_settingsOutlineView selectedRowIndexes];
	index		= [indexes firstIndex];
	
	while(index != NSNotFound) {
		setting		= [_settingsOutlineView itemAtRow:index];
		name		= [setting objectForKey:WCAccountFieldName];
		
		if(name) {
			[_account setValue:NULL forKey:name];
			
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
	[self _saveAndClear:NO];
}



- (void)saveSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber	*number = contextInfo;
	NSInteger	row = [number integerValue];

	if(row != -2 || returnCode != NSAlertSecondButtonReturn) {
		if(returnCode == NSAlertFirstButtonReturn) {
			[self _saveAndClear:YES];
		} else {
			[_account release];
			_account = NULL;
			[_underlyingAccount release];
			_underlyingAccount = NULL;
			_creatingAccount = NO;
		}

		_accountTouched = NO;

		[[self window] setDocumentEdited:NO];

		if(row >= 0) {
			[_accountsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		} else {
			[self _validateAccount:NULL];
			[self _readFromAccount:NULL];
			
			if(row == -2) {
				[_accountsTableView deselectAll:self];

				[self close];
			}
		}

		[self validate];
	}
	
	[number release];
}



#pragma mark -

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
		if([[[self connection] account] accountReadAccounts]) {
			if([_accountsTableView numberOfSelectedRows] == 1) {
				[self _readAccount:[self _selectedAccount]];
			} else {
				[_account release];
				_account = NULL;
				[_underlyingAccount release];
				_underlyingAccount = NULL;
				_editingAccount = NO;
				_creatingAccount = NO;

				[self _validateAccount:NULL];
				[self _readFromAccount:NULL];
			}
		}
		
		[self validate];
	}
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!_account)
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
	id			value;
	
	if(tableColumn == _settingTableColumn) {
		return [item objectForKey:WCAccountFieldLocalizedName];
	}
	else if(tableColumn == _valueTableColumn) {
		value = [_account valueForKey:[item objectForKey:WCAccountFieldName]];
		
		if(!value)
			value = [_underlyingAccount valueForKey:[item objectForKey:WCAccountFieldName]];
		
		if([[item objectForKey:WCAccountFieldType] intValue] == WCAccountFieldNumber && [value integerValue] == 0)
			return NULL;
		
		if([[item objectForKey:WCAccountFieldName] isEqualToString:@"transferDownloadSpeedLimit"] ||
		   [[item objectForKey:WCAccountFieldName] isEqualToString:@"transferUploadSpeedLimit"])
			value = [NSNumber numberWithInteger:[value doubleValue] / 1024.0];
		
		return value;
	}

	return NULL;
}



- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSString	*name;
	id			value;
	
	name	= [item objectForKey:WCAccountFieldName];
	value	= object;
	
	if([[item objectForKey:WCAccountFieldType] intValue] == WCAccountFieldNumber)
		value = [NSNumber numberWithInteger:[object integerValue]];
	
	if([name isEqualToString:@"transferDownloadSpeedLimit"] ||
	   [name isEqualToString:@"transferUploadSpeedLimit"])
		value = [NSNumber numberWithInteger:[value integerValue] * 1024.0];

	[_account setValue:value forKey:name];
	
	[self touch:self];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if([_account valueForKey:[item objectForKey:WCAccountFieldName]])
		[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
	else
		[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
	
	if(tableColumn == _valueTableColumn)
		[cell setEnabled:[self _isEditableAccount:_account]];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return ([[item objectForKey:WCAccountsFieldSettings] count] > 0);
}

@end



@implementation WCAccountsTableColumn

- (id)dataCellForRow:(NSInteger)row {
	NSDictionary		*setting;
	
	setting = [(NSOutlineView *) [self tableView] itemAtRow:row];
	
	return [setting objectForKey:WCAccountsFieldCell];
}

@end
