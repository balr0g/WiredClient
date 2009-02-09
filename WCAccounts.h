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

#import "WCConnectionController.h"

@interface WCAccounts : WCConnectionController {
	IBOutlet WITableView				*_accountsTableView;
	IBOutlet NSTableColumn				*_nameTableColumn;
	IBOutlet NSTableColumn				*_typeTableColumn;
	
	IBOutlet NSTabView					*_accountsTabView;

	IBOutlet NSButton					*_selectAllBasicPrivilegesButton;
	IBOutlet NSButton					*_selectAllFilesPrivilegesButton;
	IBOutlet NSButton					*_selectAllBoardsPrivilegesButton;
	IBOutlet NSButton					*_selectAllTrackerPrivilegesButton;
	IBOutlet NSButton					*_selectAllUsersPrivilegesButton;
	IBOutlet NSButton					*_selectAllAccountsPrivilegesButton;
	IBOutlet NSButton					*_selectAllAdministrationPrivilegesButton;
	IBOutlet NSProgressIndicator		*_progressIndicator;
	IBOutlet NSButton					*_saveButton;

	IBOutlet NSPopUpButton				*_typePopUpButton;
	IBOutlet NSMenuItem					*_userMenuItem;
	IBOutlet NSMenuItem					*_groupMenuItem;

	IBOutlet NSTextField				*_nameTextField;
	IBOutlet NSTextField				*_fullNameTextField;
	IBOutlet NSTextField				*_creationTimeTextField;
	IBOutlet NSTextField				*_modificationTimeTextField;
	IBOutlet NSTextField				*_loginTimeTextField;
	IBOutlet NSTextField				*_editedByTextField;
	IBOutlet NSSecureTextField			*_passwordTextField;
	IBOutlet NSPopUpButton				*_groupPopUpButton;
	IBOutlet NSMenuItem					*_noneMenuItem;
	IBOutlet NSTokenField				*_groupsTokenField;
	IBOutlet NSTextField				*_filesTextField;
	IBOutlet NSButton					*_userCannotSetNickButton;
	IBOutlet NSButton					*_userGetInfoButton;
	IBOutlet NSButton					*_userKickUsersButton;
	IBOutlet NSButton					*_userBanUsersButton;
	IBOutlet NSButton					*_userCannotBeDisconnectedButton;
	IBOutlet NSButton					*_userGetUsersButton;
	IBOutlet NSButton					*_chatSetTopicButton;
	IBOutlet NSButton					*_chatCreateChatsButton;
	IBOutlet NSButton					*_messageSendMessagesButton;
	IBOutlet NSButton					*_messageBroadcastButton;
	IBOutlet NSButton					*_boardReadBoardsButton;
	IBOutlet NSButton					*_boardAddBoardsButton;
	IBOutlet NSButton					*_boardMoveBoardsButton;
	IBOutlet NSButton					*_boardRenameBoardsButton;
	IBOutlet NSButton					*_boardDeleteBoardsButton;
	IBOutlet NSButton					*_boardSetPermissionsButton;
	IBOutlet NSButton					*_boardAddThreadsButton;
	IBOutlet NSButton					*_boardMoveThreadsButton;
	IBOutlet NSButton					*_boardDeleteThreadsButton;
	IBOutlet NSButton					*_boardAddPostsButton;
	IBOutlet NSButton					*_boardEditOwnPostsButton;
	IBOutlet NSButton					*_boardEditAllPostsButton;
	IBOutlet NSButton					*_boardDeletePostsButton;
	IBOutlet NSButton					*_fileListFilesButton;
	IBOutlet NSButton					*_fileGetInfoButton;
	IBOutlet NSButton					*_fileCreateDirectoriesButton;
	IBOutlet NSButton					*_fileCreateLinksButton;
	IBOutlet NSButton					*_fileMoveFilesButton;
	IBOutlet NSButton					*_fileRenameFilesButton;
	IBOutlet NSButton					*_fileSetTypeButton;
	IBOutlet NSButton					*_fileSetCommentButton;
	IBOutlet NSButton					*_fileSetPermissionsButton;
	IBOutlet NSButton					*_fileDeleteFilesButton;
	IBOutlet NSButton					*_fileAccessAllDropboxesButton;
	IBOutlet NSTextField				*_fileRecursiveListDepthLimitTextField;
	IBOutlet NSButton					*_transferDownloadFilesButton;
	IBOutlet NSButton					*_transferUploadFilesButton;
	IBOutlet NSButton					*_transferUploadDirectoriesButton;
	IBOutlet NSButton					*_transferUploadAnywhereButton;
	IBOutlet NSTextField				*_transferDownloadLimitTextField;
	IBOutlet NSTextField				*_transferUploadLimitTextField;
	IBOutlet NSTextField				*_transferDownloadSpeedLimitTextField;
	IBOutlet NSTextField				*_transferUploadSpeedLimitTextField;
	IBOutlet NSButton					*_accountChangePasswordButton;
	IBOutlet NSButton					*_accountListAccountsButton;
	IBOutlet NSButton					*_accountReadAccountsButton;
	IBOutlet NSButton					*_accountCreateAccountsButton;
	IBOutlet NSButton					*_accountEditAccountsButton;
	IBOutlet NSButton					*_accountDeleteAccountsButton;
	IBOutlet NSButton					*_accountRaiseAccountPrivilegesButton;
	IBOutlet NSButton					*_logViewLogButton;
	IBOutlet NSButton					*_settingsGetSettingsButton;
	IBOutlet NSButton					*_settingsSetSettingsButton;
	IBOutlet NSButton					*_banlistGetBansButton;
	IBOutlet NSButton					*_banlistAddBansButton;
	IBOutlet NSButton					*_banlistDeleteBansButton;
	IBOutlet NSButton					*_trackerListServersButton;
	IBOutlet NSButton					*_trackerRegisterServersButton;
	
	IBOutlet NSPopUpButton				*_showPopUpButton;
	IBOutlet NSMenuItem					*_allSettingsMenuItem;
	IBOutlet NSMenuItem					*_settingsDefinedAtThisLevelMenuItem;
	
	IBOutlet WIOutlineView				*_settingsOutlineView;
	IBOutlet NSTableColumn				*_settingTableColumn;
	IBOutlet NSTableColumn				*_valueTableColumn;
	
	IBOutlet NSPanel					*_changePasswordPanel;
	IBOutlet NSSecureTextField			*_changePasswordTextField;
	
	NSArray								*_allSettings;
	NSMutableArray						*_shownSettings;
	
	NSArray								*_groupControls;
	NSMutableArray						*_allControls;

	NSMutableArray						*_allAccounts, *_shownAccounts;
	NSImage								*_userImage, *_groupImage;
	NSUInteger							_users, _groups;
	
	WCAccount							*_account;
	WCAccount							*_underlyingAccount;
	
	BOOL								_editingAccount;
	BOOL								_creatingAccount;
	BOOL								_accountTouched;

	BOOL								_received;

	WIDateFormatter						*_dateFormatter;
}

+ (id)accountsWithConnection:(WCServerConnection *)connection;

- (NSArray *)accounts;
- (NSArray *)users;
- (NSArray *)userNames;
- (NSArray *)groups;
- (NSArray *)groupNames;
- (WCAccount *)userWithName:(NSString *)name;
- (WCAccount *)groupWithName:(NSString *)name;
- (void)editUserAccountWithName:(NSString *)name;

- (IBAction)touch:(id)sender;
- (IBAction)add:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)reload:(id)sender;
- (IBAction)changePassword:(id)sender;
- (IBAction)group:(id)sender;
- (IBAction)save:(id)sender;
- (IBAction)selectAllBasicPrivileges:(id)sender;
- (IBAction)selectAllFilesPrivileges:(id)sender;
- (IBAction)selectAllBoardsPrivileges:(id)sender;
- (IBAction)selectAllTrackerPrivileges:(id)sender;
- (IBAction)selectAllUsersPrivileges:(id)sender;
- (IBAction)selectAllAccountsPrivileges:(id)sender;
- (IBAction)selectAllAdministrationPrivileges:(id)sender;
- (IBAction)show:(id)sender;
- (IBAction)clearSetting:(id)sender;

@end


@interface WCAccountsTableColumn : NSTableColumn

@end
