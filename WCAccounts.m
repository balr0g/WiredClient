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

@interface WCAccounts(Private)

- (id)_initAccountsWithConnection:(WCServerConnection *)connection;

- (void)_update;
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

@end


@implementation WCAccounts(Private)

- (id)_initAccountsWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Accounts"
								   name:NSLS(@"Accounts", @"Accounts window title")
							 connection:connection
							  singleton:YES];

	_allAccounts	= [[NSMutableArray alloc] init];
	_shownAccounts	= [[NSMutableArray alloc] init];
	_userImage		= [[NSImage imageNamed:@"User"] retain];
	_groupImage		= [[NSImage imageNamed:@"Group"] retain];

	[self window];

	return self;
}



#pragma mark -

- (void)_update {
}



- (BOOL)_verifyUnsavedAndSelectRow:(NSInteger)row {
	NSAlert		*alert;
	NSString	*name;
	
	if(_accountTouched) {
		name = [_nameTextField stringValue];
		
		if([name length] > 0) {
			alert = [NSAlert alertWithMessageText:[NSSWF:NSLS(@"Save changes to the \"%@\" account?", @"Save account dialog title (name)"), name]
									defaultButton:NSLS(@"Save", @"Save account dialog button")
								  alternateButton:NSLS(@"Don't Save", @"Save account dialog button")
									  otherButton:NSLS(@"Cancel", @"Save account dialog button")
						informativeTextWithFormat:NSLS(@"If you don't save the changes, they will be lost.", @"Save account dialog description")];
			
			[alert beginSheetModalForWindow:[self window]
							  modalDelegate:self
							 didEndSelector:@selector(saveSheetDidEnd:returnCode:contextInfo:)
								contextInfo:[[NSNumber alloc] initWithInteger:row]];
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
		[self _writeToAccount:_editedAccount];

		message = [_editedAccount editAccountMessage];
	} else {
		if([_typePopUpButton selectedItem] == _userMenuItem)
			account = [WCUserAccount account];
		else
			account = [WCGroupAccount account];

		[self _writeToAccount:account];
		
		message = [account createAccountMessage];
	}
	
	[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredAccountChangeAccountReply:)];
	
	if(clear && _editingAccount) {
		[_editedAccount release];
		_editedAccount = NULL;
		_editingAccount = NO;
	}
	
	if(_creatingAccount) {
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
		enumerator = [_allControls objectEnumerator];
		
		while((control = [enumerator nextObject]))
			[control setEnabled:YES];
		
		[_nameTextField setEnabled:NO];

		if([account isKindOfClass:[WCUserAccount class]]) {
			if([[(WCUserAccount *) account group] length] > 0) {
				enumerator = [_groupControls objectEnumerator];
				
				while((control = [enumerator nextObject]))
					[control setEnabled:NO];
			}
		} else {
			[_fullNameTextField setEnabled:NO];
			[_passwordTextField setEnabled:NO];
			[_groupPopUpButton setEnabled:NO];
			[_groupsTokenField setEnabled:NO];
		}
	} else {
		enumerator = [_allControls objectEnumerator];
		
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
		[_filesTextField setStringValue:[account files]];

		if([[account creationDate] isAtBeginningOfAnyEpoch])
			[_creationTimeTextField setStringValue:@""];
		else
			[_creationTimeTextField setStringValue:[_dateFormatter stringFromDate:[account creationDate]]];

		if([[account modificationDate] isAtBeginningOfAnyEpoch])
			[_modificationTimeTextField setStringValue:@""];
		else
			[_modificationTimeTextField setStringValue:[_dateFormatter stringFromDate:[account modificationDate]]];

		[_editedByTextField setStringValue:[(WCUserAccount *) account editedBy]];
		
		[_userCannotSetNickButton setState:[account userCannotSetNick]];
		[_userGetInfoButton setState:[account userGetInfo]];
		[_userKickUsersButton setState:[account userKickUsers]];
		[_userBanUsersButton setState:[account userBanUsers]];
		[_userCannotBeDisconnectedButton setState:[account userCannotBeDisconnected]];
		[_userGetUsersButton setState:[account userGetUsers]];
		[_chatSetTopicButton setState:[account chatSetTopic]];
		[_chatCreateChatsButton setState:[account chatCreateChats]];
		[_messageSendMessagesButton setState:[account messageSendMessages]];
		[_messageBroadcastButton setState:[account messageBroadcast]];
		[_newsReadNewsButton setState:[account newsReadNews]];
		[_newsPostNewsButton setState:[account newsPostNews]];
		[_newsClearNewsButton setState:[account newsClearNews]];
		[_fileListFilesButton setState:[account fileListFiles]];
		[_fileGetInfoButton setState:[account fileGetInfo]];
		[_fileCreateDirectoriesButton setState:[account fileCreateDirectories]];
		[_fileCreateLinksButton setState:[account fileCreateLinks]];
		[_fileMoveFilesButton setState:[account fileMoveFiles]];
		[_fileRenameFilesButton setState:[account fileRenameFiles]];
		[_fileSetTypeButton setState:[account fileSetType]];
		[_fileSetCommentButton setState:[account fileSetComment]];
		[_fileSetPermissionsButton setState:[account fileSetPermissions]];
		[_fileDeleteFilesButton setState:[account fileDeleteFiles]];
		[_fileAccessAllDropboxesButton setState:[account fileAccessAllDropboxes]];

		if([account fileRecursiveListDepthLimit] > 0)
			[_fileRecursiveListDepthLimitTextField setIntValue:[account fileRecursiveListDepthLimit]];
		else
			[_fileRecursiveListDepthLimitTextField setStringValue:@""];
		
		[_transferDownloadFilesButton setState:[account transferDownloadFiles]];
		[_transferUploadFilesButton setState:[account transferUploadFiles]];
		[_transferUploadDirectoriesButton setState:[account transferUploadDirectories]];
		[_transferUploadAnywhereButton setState:[account transferUploadAnywhere]];
		
		if([account transferDownloadLimit] > 0)
			[_transferDownloadLimitTextField setIntValue:[account transferDownloadLimit]];
		else
			[_transferDownloadLimitTextField setStringValue:@""];
		
		if([account transferUploadLimit] > 0)
			[_transferUploadLimitTextField setIntValue:[account transferUploadLimit]];
		else
			[_transferUploadLimitTextField setStringValue:@""];

		if([account transferDownloadSpeedLimit] > 0)
			[_transferDownloadSpeedLimitTextField setIntValue:(double) [account transferDownloadSpeedLimit] / 1024.0];
		else
			[_transferDownloadSpeedLimitTextField setStringValue:@""];
		
		if([account transferUploadSpeedLimit] > 0)
			[_transferUploadSpeedLimitTextField setIntValue:(double) [account transferUploadSpeedLimit] / 1024.0];
		else
			[_transferUploadSpeedLimitTextField setStringValue:@""];

		[_accountChangePasswordButton setState:[account accountChangePassword]];
		[_accountListAccountsButton setState:[account accountListAccounts]];
		[_accountReadAccountsButton setState:[account accountReadAccounts]];
		[_accountCreateAccountsButton setState:[account accountCreateAccounts]];
		[_accountEditAccountsButton setState:[account accountEditAccounts]];
		[_accountDeleteAccountsButton setState:[account accountDeleteAccounts]];
		[_accountRaiseAccountPrivilegesButton setState:[account accountRaiseAccountPrivileges]];
		[_logViewLogButton setState:[account logViewLog]];
		[_settingsGetSettingsButton setState:[account settingsGetSettings]];
		[_settingsSetSettingsButton setState:[account settingsSetSettings]];
		[_banlistGetBansButton setState:[account banlistGetBans]];
		[_banlistAddBansButton setState:[account banlistAddBans]];
		[_banlistDeleteBansButton setState:[account banlistDeleteBans]];
		[_trackerListServersButton setState:[account trackerListServers]];
		[_trackerRegisterServersButton setState:[account trackerRegisterServers]];
	} else {
		enumerator = [_allControls objectEnumerator];
		
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
			
			[_userGetInfoButton setState:NSOnState];
			[_chatCreateChatsButton setState:NSOnState];
			[_messageSendMessagesButton setState:NSOnState];
			[_newsReadNewsButton setState:NSOnState];
			[_newsPostNewsButton setState:NSOnState];
			[_fileListFilesButton setState:NSOnState];
			[_fileGetInfoButton setState:NSOnState];
			[_transferDownloadFilesButton setState:NSOnState];
			[_transferUploadFilesButton setState:NSOnState];
			[_transferUploadDirectoriesButton setState:NSOnState];
			[_trackerListServersButton setState:NSOnState];
		}
	}
}



- (void)_writeToAccount:(WCAccount *)account {
	NSString		*password, *group;
	
	[account setName:[_nameTextField stringValue]];
	
	if([account isKindOfClass:[WCUserAccount class]]) {
		[(WCUserAccount *) account setFullName:[_fullNameTextField stringValue]];

		if([[_passwordTextField stringValue] isEqualToString:@""])
			password = @"";
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
		[(WCUserAccount *) account setGroups:[[_groupsTokenField stringValue] componentsSeparatedByCharactersFromSet:
			[_groupsTokenField tokenizingCharacterSet]]];
	}
	
	[account setFiles:[_filesTextField stringValue]];
	[account setUserCannotSetNick:[_userCannotSetNickButton state]];
	[account setUserGetInfo:[_userGetInfoButton state]];
	[account setUserKickUsers:[_userKickUsersButton state]];
	[account setUserBanUsers:[_userBanUsersButton state]];
	[account setUserCannotBeDisconnected:[_userCannotBeDisconnectedButton state]];
	[account setUserGetUsers:[_userGetUsersButton state]];
	[account setChatSetTopic:[_chatSetTopicButton state]];
	[account setChatCreateChats:[_chatCreateChatsButton state]];
	[account setMessageSendMessages:[_messageSendMessagesButton state]];
	[account setMessageBroadcast:[_messageBroadcastButton state]];
	[account setNewsReadNews:[_newsReadNewsButton state]];
	[account setNewsPostNews:[_newsPostNewsButton state]];
	[account setNewsClearNews:[_newsClearNewsButton state]];
	[account setFileListFiles:[_fileListFilesButton state]];
	[account setFileGetInfo:[_fileGetInfoButton state]];
	[account setFileCreateDirectories:[_fileCreateDirectoriesButton state]];
	[account setFileCreateLinks:[_fileCreateLinksButton state]];
	[account setFileMoveFiles:[_fileMoveFilesButton state]];
	[account setFileRenameFiles:[_fileRenameFilesButton state]];
	[account setFileSetType:[_fileSetTypeButton state]];
	[account setFileSetComment:[_fileSetCommentButton state]];
	[account setFileSetPermissions:[_fileSetPermissionsButton state]];
	[account setFileDeleteFiles:[_fileDeleteFilesButton state]];
	[account setFileAccessAllDropboxes:[_fileAccessAllDropboxesButton state]];
	[account setFileRecursiveListDepthLimit:[_fileRecursiveListDepthLimitTextField intValue]];
	[account setTransferDownloadFiles:[_transferDownloadFilesButton state]];
	[account setTransferUploadFiles:[_transferUploadFilesButton state]];
	[account setTransferUploadDirectories:[_transferUploadDirectoriesButton state]];
	[account setTransferUploadAnywhere:[_transferUploadAnywhereButton state]];
	[account setTransferDownloadLimit:[_transferDownloadLimitTextField intValue]];
	[account setTransferUploadLimit:[_transferUploadLimitTextField intValue]];
	[account setTransferDownloadSpeedLimit:[_transferDownloadSpeedLimitTextField intValue] * 1024.0];
	[account setTransferUploadSpeedLimit:[_transferUploadSpeedLimitTextField intValue] * 1024.0];
	[account setAccountChangePassword:[_accountChangePasswordButton state]];
	[account setAccountListAccounts:[_accountListAccountsButton state]];
	[account setAccountReadAccounts:[_accountReadAccountsButton state]];
	[account setAccountCreateAccounts:[_accountCreateAccountsButton state]];
	[account setAccountEditAccounts:[_accountEditAccountsButton state]];
	[account setAccountDeleteAccounts:[_accountDeleteAccountsButton state]];
	[account setAccountRaiseAccountPrivileges:[_accountRaiseAccountPrivilegesButton state]];
	[account setLogViewLog:[_logViewLogButton state]];
	[account setSettingsGetSettings:[_settingsGetSettingsButton state]];
	[account setSettingsSetSettings:[_settingsSetSettingsButton state]];
	[account setBanlistGetBans:[_banlistGetBansButton state]];
	[account setBanlistAddBans:[_banlistAddBansButton state]];
	[account setBanlistDeleteBans:[_banlistDeleteBansButton state]];
	[account setTrackerListServers:[_trackerListServersButton state]];
	[account setTrackerRegisterServers:[_trackerRegisterServersButton state]];
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
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	NSNumber			*row;

	array = [NSMutableArray array];
	enumerator = [_accountsTableView selectedRowEnumerator];

	while((row = [enumerator nextObject]))
		[array addObject:[self _accountAtIndex:[row unsignedIntValue]]];

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

@end


@implementation WCAccounts

+ (id)accountsWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initAccountsWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_groupControls release];
	[_allControls release];
	
	[_userImage release];
	[_groupImage release];

	[_allAccounts release];
	[_shownAccounts release];
	
	[_dateFormatter release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSEnumerator	*enumerator;
	NSToolbar		*toolbar;
	NSControl		*control;

	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Accounts"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];

	[_accountsTableView setDoubleAction:@selector(edit:)];
	[_accountsTableView setDeleteAction:@selector(delete:)];
	[_accountsTableView setDefaultHighlightedTableColumnIdentifier:@"Name"];
	[[self window] makeFirstResponder:_accountsTableView];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	_groupControls = [[NSArray alloc] initWithObjects:
		_selectAllBasicPrivilegesButton,
		_selectAllFilesPrivilegesButton,
		_selectAllTrackerPrivilegesButton,
		_selectAllAccountsPrivilegesButton,
		_selectAllAdministrationPrivilegesButton,
		_filesTextField,
		_userCannotSetNickButton,
		_userGetInfoButton,
		_userKickUsersButton,
		_userBanUsersButton,
		_userCannotBeDisconnectedButton,
		_userGetUsersButton,
		_chatSetTopicButton,
		_chatCreateChatsButton,
		_messageSendMessagesButton,
		_messageBroadcastButton,
		_newsReadNewsButton,
		_newsPostNewsButton,
		_newsClearNewsButton,
		_fileListFilesButton,
		_fileGetInfoButton,
		_fileCreateDirectoriesButton,
		_fileCreateLinksButton,
		_fileMoveFilesButton,
		_fileRenameFilesButton,
		_fileSetTypeButton,
		_fileSetCommentButton,
		_fileSetPermissionsButton,
		_fileDeleteFilesButton,
		_fileAccessAllDropboxesButton,
		_fileRecursiveListDepthLimitTextField,
		_transferDownloadFilesButton,
		_transferUploadFilesButton,
		_transferUploadDirectoriesButton,
		_transferUploadAnywhereButton,
		_transferDownloadLimitTextField,
		_transferUploadLimitTextField,
		_transferDownloadSpeedLimitTextField,
		_transferUploadSpeedLimitTextField,
		_accountChangePasswordButton,
		_accountListAccountsButton,
		_accountReadAccountsButton,
		_accountCreateAccountsButton,
		_accountEditAccountsButton,
		_accountDeleteAccountsButton,
		_accountRaiseAccountPrivilegesButton,
		_logViewLogButton,
		_settingsGetSettingsButton,
		_settingsSetSettingsButton,
		_banlistGetBansButton,
		_banlistAddBansButton,
		_banlistDeleteBansButton,
		_trackerListServersButton,
		_trackerRegisterServersButton,
		NULL];

	_allControls = [[NSMutableArray alloc] initWithObjects:
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
	[_allControls addObjectsFromArray:_groupControls];
	
	enumerator = [_allControls objectEnumerator];
	
	while((control = [enumerator nextObject])) {
		if([control isKindOfClass:[NSButton class]] && ![control target]) {
			[control setTarget:self];
			[control setAction:@selector(touch:)];
		}
	}

	[self _update];
	[self _validateAccount:NULL];
	[self _readFromAccount:NULL];
	
	[super windowDidLoad];
}



- (BOOL)windowShouldClose:(NSWindow *)window {
	return [self _verifyUnsavedAndSelectRow:-2];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[_accountsTableView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCAccountsTableView"]];
	
	[super windowTemplateShouldLoad:windowTemplate];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[_accountsTableView propertiesDictionary] forKey:@"WCAccountsTableView"];
	
	[super windowTemplateShouldSave:windowTemplate];
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



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
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

	if(account) {
		if([[account name] isEqualToString:[[self _selectedAccount] name]]) {
			[self _validateAccount:account];
			[self _readFromAccount:account];
			
			_editedAccount = [account retain];
			_editingAccount = YES;
			
			[self validate];
		}
	}

	[_progressIndicator stopAnimation:self];
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
			[_accountsTableView selectRow:i byExtendingSelection:NO];
			
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
	[_editedAccount release];
	_editedAccount = NULL;
	_editingAccount = NO;
	
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
	NSString	*title;
	NSUInteger	count;

	if(![[self connection] isConnected])
		return;

	count = [[self _selectedAccounts] count];

	if(count == 0)
		return;

	if(count == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \"%@\"?", @"Delete account dialog title (filename)"),
			[[self _selectedAccount] name]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu items?", @"Delete account dialog title (count)"),
			count];
	}

	NSBeginAlertSheet(title,
					  NSLS(@"Delete", @"Delete account dialog button title"),
					  NSLS(@"Cancel", @"Delete account dialog button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete account dialog description"));
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	WIP7Message		*message;
	WCAccount		*account;

	if(returnCode == NSAlertDefaultReturn) {
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
	NSString		*group;
	
	if(_editedAccount) {
		if([_groupPopUpButton selectedItem] != _noneMenuItem)
			group = [_groupPopUpButton titleOfSelectedItem];
		else
			group = @"";

		[(WCUserAccount *) _editedAccount setGroup:group];
		
		[self _validateAccount:_editedAccount];
	}
	
	[self touch:self];
}



- (IBAction)save:(id)sender {
	[self _saveAndClear:NO];
}



- (void)saveSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber	*number = contextInfo;
	NSInteger	row = [number integerValue];

	if(row != -2 || returnCode != NSAlertOtherReturn) {
		if(returnCode == NSAlertDefaultReturn) {
			[self _saveAndClear:YES];
		} else {
			[_editedAccount release];
			_editedAccount = NULL;
			_creatingAccount = NO;
		}

		_accountTouched = NO;

		[[self window] setDocumentEdited:NO];

		if(row >= 0) {
			[_accountsTableView selectRow:row byExtendingSelection:NO];
		} else {
			[self _validateAccount:NULL];
			[self _readFromAccount:NULL];

			if(row == -2)
				[self close];
		}

		[self validate];
	}
	
	[number release];
}



- (IBAction)selectAllBasicPrivileges:(id)sender {
	[_userCannotSetNickButton setState:NSOnState];
	[_userGetInfoButton setState:NSOnState];
	[_userKickUsersButton setState:NSOnState];
	[_userBanUsersButton setState:NSOnState];
	[_userCannotBeDisconnectedButton setState:NSOnState];
	[_chatSetTopicButton setState:NSOnState];
	[_chatCreateChatsButton setState:NSOnState];
	[_messageSendMessagesButton setState:NSOnState];
	[_messageBroadcastButton setState:NSOnState];
	[_newsReadNewsButton setState:NSOnState];
	[_newsPostNewsButton setState:NSOnState];
	[_newsClearNewsButton setState:NSOnState];
	
	[self touch:self];
}



- (IBAction)selectAllFilesPrivileges:(id)sender {
	[_fileListFilesButton setState:NSOnState];
	[_fileGetInfoButton setState:NSOnState];
	[_fileCreateDirectoriesButton setState:NSOnState];
	[_fileCreateLinksButton setState:NSOnState];
	[_fileMoveFilesButton setState:NSOnState];
	[_fileRenameFilesButton setState:NSOnState];
	[_fileSetTypeButton setState:NSOnState];
	[_fileSetCommentButton setState:NSOnState];
	[_fileSetPermissionsButton setState:NSOnState];
	[_fileDeleteFilesButton setState:NSOnState];
	[_fileAccessAllDropboxesButton setState:NSOnState];
	[_transferDownloadFilesButton setState:NSOnState];
	[_transferUploadFilesButton setState:NSOnState];
	[_transferUploadDirectoriesButton setState:NSOnState];
	[_transferUploadAnywhereButton setState:NSOnState];
	
	[self touch:self];
}



- (IBAction)selectAllTrackerPrivileges:(id)sender {
	[_trackerListServersButton setState:NSOnState];
	[_trackerRegisterServersButton setState:NSOnState];
	
	[self touch:self];
}



- (IBAction)selectAllAccountsPrivileges:(id)sender {
	[_accountChangePasswordButton setState:NSOnState];
	[_accountListAccountsButton setState:NSOnState];
	[_accountReadAccountsButton setState:NSOnState];
	[_accountCreateAccountsButton setState:NSOnState];
	[_accountEditAccountsButton setState:NSOnState];
	[_accountDeleteAccountsButton setState:NSOnState];
	[_accountRaiseAccountPrivilegesButton setState:NSOnState];
	
	[self touch:self];
}



- (IBAction)selectAllAdministrationPrivileges:(id)sender {
	[_userGetUsersButton setState:NSOnState];
	[_logViewLogButton setState:NSOnState];
	[_settingsGetSettingsButton setState:NSOnState];
	[_settingsSetSettingsButton setState:NSOnState];
	[_banlistGetBansButton setState:NSOnState];
	[_banlistAddBansButton setState:NSOnState];
	[_banlistDeleteBansButton setState:NSOnState];
	
	[self touch:self];
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
	WCAccount	*account;

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
				
				[_editedAccount release];
				_editedAccount = NULL;
				_editingAccount = NO;
			}
		}
		
		[self validate];
	}
}

@end
