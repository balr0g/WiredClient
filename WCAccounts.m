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

- (void)_readAccount:(WCAccount *)account;
- (void)_validateAccount:(WCAccount *)account;
- (void)_readFromAccount:(WCAccount *)account;
- (void)_writeToAccount:(WCAccount *)account;

- (WCAccount *)_accountAtIndex:(NSUInteger)index;
- (WCAccount *)_selectedAccount;
- (NSArray *)_selectedAccounts;
- (void)_sortAccounts;
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
	NSNumber				*section;
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
		
		section = [setting objectForKey:WCAccountFieldSection];
		
		if(section) {
			switch([section intValue]) {
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
	NSEnumerator	*enumerator;
	NSControl		*control;
	
	[_typePopUpButton setEnabled:_creatingAccount];
	[_nameTextField setEnabled:_creatingAccount];
	
	if(account) {
		enumerator = [_controls objectEnumerator];
		
		while((control = [enumerator nextObject]))
			[control setEnabled:YES];
		
		[_nameTextField setEnabled:NO];

		if([account isKindOfClass:[WCUserAccount class]]) {
			[_fullNameTextField setEnabled:YES];
			[_passwordTextField setEnabled:YES];
			[_groupPopUpButton setEnabled:YES];
			[_groupsTokenField setEnabled:YES];
		} else {
			[_fullNameTextField setEnabled:NO];
			[_passwordTextField setEnabled:NO];
			[_groupPopUpButton setEnabled:NO];
			[_groupsTokenField setEnabled:NO];
		}
	} else {
		enumerator = [_controls objectEnumerator];
		
		while((control = [enumerator nextObject]))
			[control setEnabled:_creatingAccount];
	}
}



- (void)_readFromAccount:(WCAccount *)account {
	NSEnumerator	*enumerator;
	NSControl		*control;
	
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
	
			if([[(WCUserAccount *) account loginDate] isAtBeginningOfAnyEpoch])
				[_loginTimeTextField setStringValue:@""];
			else
				[_loginTimeTextField setStringValue:[_dateFormatter stringFromDate:[(WCUserAccount *) account loginDate]]];
		} else {
			[_typePopUpButton selectItem:_groupMenuItem];
			[_fullNameTextField setStringValue:@""];
			[_passwordTextField setStringValue:@""];
			[_groupPopUpButton selectItem:_noneMenuItem];
			[_loginTimeTextField setStringValue:@""];
		}
			
		[_nameTextField setStringValue:[account name]];

		if([[account creationDate] isAtBeginningOfAnyEpoch])
			[_creationTimeTextField setStringValue:@""];
		else
			[_creationTimeTextField setStringValue:[_dateFormatter stringFromDate:[account creationDate]]];

		if([[account modificationDate] isAtBeginningOfAnyEpoch])
			[_modificationTimeTextField setStringValue:@""];
		else
			[_modificationTimeTextField setStringValue:[_dateFormatter stringFromDate:[account modificationDate]]];

		[_editedByTextField setStringValue:[(WCUserAccount *) account editedBy]];
		
	} else {
		enumerator = [_controls objectEnumerator];
		
		while((control = [enumerator nextObject])) {
			if([control isKindOfClass:[NSButton class]])
				[(NSButton *) control setState:NSOffState];
			else
				[control setStringValue:@""];
		}
		
		[_typePopUpButton selectItem:_userMenuItem];
		[_groupPopUpButton selectItem:_noneMenuItem];
		
		if(_creatingAccount) {
			[_nameTextField setStringValue:NSLS(@"Untitled", @"Account name")];
			
/*			[_userGetInfoButton setState:NSOnState];
			[_chatCreateChatsButton setState:NSOnState];
			[_messageSendMessagesButton setState:NSOnState];
			[_boardReadBoardsButton setState:NSOnState];
			[_boardAddThreadsButton setState:NSOnState];
			[_boardAddPostsButton setState:NSOnState];
			[_boardEditOwnPostsButton setState:NSOnState];
			[_fileListFilesButton setState:NSOnState];
			[_fileGetInfoButton setState:NSOnState];
			[_transferDownloadFilesButton setState:NSOnState];
			[_transferUploadFilesButton setState:NSOnState];
			[_transferUploadDirectoriesButton setState:NSOnState];
			[_trackerListServersButton setState:NSOnState];*/
		}
	}
	
	[_settingsOutlineView reloadData];
}



- (void)_writeToAccount:(WCAccount *)account {
	NSString		*password, *group;
	NSArray			*groups;
	
	[account setValue:[_nameTextField stringValue] forKey:@"name"];
	
	if([account isKindOfClass:[WCUserAccount class]]) {
		[account setValue:[_fullNameTextField stringValue] forKey:@"fullName"];

		if([[_passwordTextField stringValue] isEqualToString:@""])
			password = @"";
		else if(![[(WCUserAccount *) account password] isEqualToString:[_passwordTextField stringValue]])
			password = [[_passwordTextField stringValue] SHA1];
		else
			password = [(WCUserAccount *) account password];
		
		[account setValue:password forKey:@"password"];
		
		if([_groupPopUpButton selectedItem] != _noneMenuItem)
			group = [_groupPopUpButton titleOfSelectedItem];
		else
			group = @"";
		
		[account setValue:group forKey:@"group"];

		groups = [[_groupsTokenField stringValue] componentsSeparatedByCharactersFromSet:
				  [_groupsTokenField tokenizingCharacterSet]];
		
		if(!groups)
			groups = [NSArray array];

		[account setValue:groups forKey:@"groups"];
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



- (void)_sortAccounts {
	NSTableColumn   *tableColumn;

	tableColumn = [_accountsTableView highlightedTableColumn];
	
	if(tableColumn == _nameTableColumn)
		[_shownAccounts sortUsingSelector:@selector(compareName:)];
	else if(tableColumn == _typeTableColumn)
		[_shownAccounts sortUsingSelector:@selector(compareType:)];
}



- (void)_reloadAccounts {
	WIP7Message		*message;
	
	[_progressIndicator startAnimation:self];

	[_allAccounts removeAllObjects];
	[_shownAccounts removeAllObjects];

	_users = _groups = 0;
	[_accountsTableView reloadData];

	message = [WIP7Message messageWithName:@"wired.account.list_users" spec:WCP7Spec];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];

	message = [WIP7Message messageWithName:@"wired.account.list_groups" spec:WCP7Spec];
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountListAccountsReply:)];
}



- (void)_reloadGroups {
	NSEnumerator	*enumerator;
	WCAccount		*account;
	
	while([_groupPopUpButton numberOfItems] > 1)
		[_groupPopUpButton removeItemAtIndex:1];
	
	if(_groups > 0) {
		[[_groupPopUpButton menu] addItem:[NSMenuItem separatorItem]];
		
		enumerator = [_allAccounts objectEnumerator];
		
		while((account = [enumerator nextObject])) {
			if([account isKindOfClass:[WCGroupAccount class]])
				[_groupPopUpButton addItemWithTitle:[account name]];
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
				if([_account valueForKey:[setting objectForKey:WCAccountFieldKey]])
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

@end


@implementation WCAccounts

+ (id)accountsWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initAccountsWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_allSettings release];
	[_shownSettings release];
	
	[_controls release];
	
	[_userImage release];
	[_groupImage release];

	[_allAccounts release];
	[_shownAccounts release];
	
	[_account release];
	[_underlyingAccount release];
	
	[_dateFormatter release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator		*enumerator;
	NSToolbar			*toolbar;
	NSControl			*control;
	NSDictionary		*section;

	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Accounts"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];

	[self setShouldCascadeWindows:YES];
	[self setWindowFrameAutosaveName:@"Accounts"];

	[_accountsTableView setPropertiesFromDictionary:
		[[WCSettings objectForKey:WCWindowProperties] objectForKey:@"WCAccountsTableView"]];

	[_accountsTableView setDoubleAction:@selector(edit:)];
	[_accountsTableView setDeleteAction:@selector(delete:)];
	[_accountsTableView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[[self window] makeFirstResponder:_accountsTableView];
	
	[_settingsOutlineView setDeleteAction:@selector(clearSetting:)];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	_controls = [[NSMutableArray alloc] initWithObjects:
		_nameTextField,
		_fullNameTextField,
		_creationTimeTextField,
		_modificationTimeTextField,
		_loginTimeTextField,
		_editedByTextField,
		_passwordTextField,
		_groupPopUpButton,
		_groupsTokenField,
		NULL];
	
	enumerator = [_controls objectEnumerator];
	
	while((control = [enumerator nextObject])) {
		if([control isKindOfClass:[NSButton class]] && ![control target]) {
			[control setTarget:self];
			[control setAction:@selector(touch:)];
		}
	}
	
	enumerator = [_shownSettings objectEnumerator];
	
	while((section = [enumerator nextObject]))
		[_settingsOutlineView expandItem:section];

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
	
	_users = _groups = 0;
	_received = NO;
	
	[super linkConnectionLoggedIn:notification];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	if(!_received) {
		if([[[self connection] account] accountListAccounts])
			[self _reloadAccounts];

		_received = YES;
	}
	
	[super serverConnectionPrivilegesDidChange:notification];
}



- (void)wiredAccountListAccountsReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.account.user_list"]) {
		[_allAccounts addObject:[WCUserAccount accountWithMessage:message]];
		
		_users++;
	}
	else if([[message name] isEqualToString:@"wired.account.user_list.done"]) {
	}
	else if([[message name] isEqualToString:@"wired.account.group_list"]) {
		[_allAccounts addObject:[WCGroupAccount accountWithMessage:message]];
		
		_groups++;
	}
	else if([[message name] isEqualToString:@"wired.account.group_list.done"]) {
		[_shownAccounts setArray:_allAccounts];
		
		[_progressIndicator stopAnimation:self];
		[self _sortAccounts];
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
			_underlyingAccount = [account retain];
	
			[_settingsOutlineView reloadData];
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
		if((_creatingAccount && [account accountCreateAccounts]) ||
		   (_editingAccount && [account accountEditAccounts]))
			save = YES;
	}

	[_saveButton setEnabled:save];
	
	[[[self window] toolbar] validateVisibleItems];

	[super validate];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCAccount	*account;
	SEL			selector;
	BOOL		connected;

	selector	= [item action];
	account		= [[self connection] account];
	connected	= [[self connection] isConnected];
	
	if(selector == @selector(add:))
		return ([account accountCreateAccounts] && connected);
	else if(selector == @selector(delete:))
		return ([_accountsTableView selectedRow] >= 0 && [account accountDeleteAccounts] && connected);
	else if(selector == @selector(reload:))
		return ([account accountListAccounts] && connected);
	else if(selector == @selector(changePassword:))
		return ([account accountChangePassword] && connected);
	
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
	_creatingAccount = YES;
	_accountTouched = YES;
	
	[_accountsTabView selectTabViewItemAtIndex:0];
	
	[self _validateAccount:NULL];
	[self _readFromAccount:NULL];
	
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
	[_changePasswordTextField setStringValue:@""];
	
	[NSApp beginSheet:_changePasswordPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(changePasswordSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)changePasswordSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*password;
	WIP7Message		*message;

	[_changePasswordPanel close];

	if(returnCode == NSAlertDefaultReturn) {
		if([[_changePasswordTextField stringValue] length] > 0)
			password = [[_changePasswordTextField stringValue] SHA1];
		else
			password = @"";
		
		message = [WIP7Message messageWithName:@"wired.account.change_password" spec:WCP7Spec];
		[message setString:password forName:@"wired.account.password"];
		[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountChangePasswordReply:)];
	}
}



- (IBAction)group:(id)sender {
	if(_account) {
		if([_groupPopUpButton selectedItem] != _noneMenuItem)
			[_account setValue:[_groupPopUpButton titleOfSelectedItem] forKey:@"group"];
		
		[self _validateAccount:_account];
	}
	
	[self touch:self];
}



- (IBAction)show:(id)sender {
	[self _reloadSettings];
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
				if([_account valueForKey:[setting objectForKey:WCAccountFieldKey]])
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



- (IBAction)clearSetting:(id)sender {
	NSDictionary	*setting;
	NSString		*key;
	NSIndexSet		*indexes;
	NSUInteger		index;
	BOOL			changed = NO;
	
	indexes		= [_settingsOutlineView selectedRowIndexes];
	index		= [indexes firstIndex];
	
	while(index != NSNotFound) {
		setting		= [_settingsOutlineView itemAtRow:index];
		key			= [setting objectForKey:WCAccountFieldKey];
		
		if(key) {
			[_account setValue:NULL forKey:key];
			
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

	if(tableColumn == _nameTableColumn) {
		return [account name];
	}
	else if(tableColumn == _typeTableColumn) {
		if([account isKindOfClass:[WCUserAccount class]])
			return NSLS(@"User", @"Account type");
		else
			return NSLS(@"Group", @"Account type");
	}

	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if(tableColumn == _nameTableColumn) {
		if([[self _accountAtIndex:row] isKindOfClass:[WCUserAccount class]])
			[cell setImage:_userImage];
		else
			[cell setImage:_groupImage];
	}
	
	[cell setBackgroundColor:[NSColor yellowColor]];
}


- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self _accountAtIndex:row] name];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_accountsTableView setHighlightedTableColumn:tableColumn];
	[self _sortAccounts];
	[_accountsTableView reloadData];
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
				[self _validateAccount:NULL];
				[self _readFromAccount:NULL];
				
				[_account release];
				_account = NULL;
				[_underlyingAccount release];
				_underlyingAccount = NULL;
				_editingAccount = NO;
			}
		}
		
		[self validate];
	}
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
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
		value = [_account valueForKey:[item objectForKey:WCAccountFieldKey]];
		
		if(!value)
			value = [_underlyingAccount valueForKey:[item objectForKey:WCAccountFieldKey]];
		
		if([[item objectForKey:WCAccountFieldType] intValue] == WCAccountFieldNumber && [value integerValue] == 0)
			return NULL;
		
		if([[item objectForKey:WCAccountFieldKey] isEqualToString:@"transferDownloadSpeedLimit"] ||
		   [[item objectForKey:WCAccountFieldKey] isEqualToString:@"transferUploadSpeedLimit"])
			value = [NSNumber numberWithInteger:[value doubleValue] / 1024.0];
		
		return value;
	}

	return NULL;
}



- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	id			value;
	
	value = object;
	
	if([[item objectForKey:WCAccountFieldType] intValue] == WCAccountFieldNumber)
		value = [NSNumber numberWithInteger:[object integerValue]];
	
	if([[item objectForKey:WCAccountFieldKey] isEqualToString:@"transferDownloadSpeedLimit"] ||
	   [[item objectForKey:WCAccountFieldKey] isEqualToString:@"transferUploadSpeedLimit"])
		value = [NSNumber numberWithInteger:[value integerValue] * 1024.0];

	[_account setValue:value forKey:[item objectForKey:WCAccountFieldKey]];
	
	[self touch:self];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _settingTableColumn) {
		if([_account valueForKey:[item objectForKey:WCAccountFieldKey]])
			[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
		else
			[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
	}
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
