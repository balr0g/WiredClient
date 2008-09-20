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

@interface WCAccount : WIObject {
	NSString				*_name;
	NSDate					*_creationDate;
	NSDate					*_modificationDate;
	NSString				*_editedBy;
	NSString				*_files;
	WIP7Bool				_userCannotSetNick;
	WIP7Bool				_userGetInfo;
	WIP7Bool				_userKickUsers;
	WIP7Bool				_userBanUsers;
	WIP7Bool				_userCannotBeDisconnected;
	WIP7Bool				_userGetUsers;
	WIP7Bool				_chatSetTopic;
	WIP7Bool				_chatCreateChats;
	WIP7Bool				_messageSendMessages;
	WIP7Bool				_messageBroadcast;
	WIP7Bool				_newsReadNews;
	WIP7Bool				_newsPostNews;
	WIP7Bool				_newsClearNews;
	WIP7Bool				_fileListFiles;
	WIP7Bool				_fileGetInfo;
	WIP7Bool				_fileCreateDirectories;
	WIP7Bool				_fileCreateLinks;
	WIP7Bool				_fileMoveFiles;
	WIP7Bool				_fileRenameFiles;
	WIP7Bool				_fileSetType;
	WIP7Bool				_fileSetComment;
	WIP7Bool				_fileSetPermissions;
	WIP7Bool				_fileSetExecutable;
	WIP7Bool				_fileDeleteFiles;
	WIP7Bool				_fileAccessAllDropboxes;
	WIP7UInt32				_fileRecursiveListDepthLimit;
	WIP7Bool				_transferDownloadFiles;
	WIP7Bool				_transferUploadFiles;
	WIP7Bool				_transferUploadDirectories;
	WIP7Bool				_transferUploadAnywhere;
	WIP7UInt32				_transferDownloadLimit;
	WIP7UInt32				_transferUploadLimit;
	WIP7UInt32				_transferDownloadSpeedLimit;
	WIP7UInt32				_transferUploadSpeedLimit;
	WIP7Bool				_accountChangePassword;
	WIP7Bool				_accountListAccounts;
	WIP7Bool				_accountReadAccounts;
	WIP7Bool				_accountCreateAccounts;
	WIP7Bool				_accountEditAccounts;
	WIP7Bool				_accountDeleteAccounts;
	WIP7Bool				_accountRaiseAccountPrivileges;
	WIP7Bool				_logViewLog;
	WIP7Bool				_settingsGetSettings;
	WIP7Bool				_settingsSetSettings;
	WIP7Bool				_banlistGetBans;
	WIP7Bool				_banlistAddBans;
	WIP7Bool				_banlistDeleteBans;
	WIP7Bool				_trackerListServers;
	WIP7Bool				_trackerRegisterServers;
}

+ (id)account;
+ (id)accountWithMessage:(WIP7Message *)message;

- (WIP7Message *)createAccountMessage;
- (WIP7Message *)editAccountMessage;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (NSDate *)creationDate;
- (NSDate *)modificationDate;
- (NSString *)editedBy;
- (void)setFiles:(NSString *)files;
- (NSString *)files;
- (void)setUserCannotSetNick:(BOOL)value;
- (BOOL)userCannotSetNick;
- (void)setUserGetInfo:(BOOL)value;
- (BOOL)userGetInfo;
- (void)setUserKickUsers:(BOOL)value;
- (BOOL)userKickUsers;
- (void)setUserBanUsers:(BOOL)value;
- (BOOL)userBanUsers;
- (void)setUserCannotBeDisconnected:(BOOL)value;
- (BOOL)userCannotBeDisconnected;
- (void)setUserGetUsers:(BOOL)value;
- (BOOL)userGetUsers;
- (void)setChatSetTopic:(BOOL)value;
- (BOOL)chatSetTopic;
- (void)setChatCreateChats:(BOOL)value;
- (BOOL)chatCreateChats;
- (void)setMessageSendMessages:(BOOL)value;
- (BOOL)messageSendMessages;
- (void)setMessageBroadcast:(BOOL)value;
- (BOOL)messageBroadcast;
- (void)setNewsReadNews:(BOOL)value;
- (BOOL)newsReadNews;
- (void)setNewsPostNews:(BOOL)value;
- (BOOL)newsPostNews;
- (void)setNewsClearNews:(BOOL)value;
- (BOOL)newsClearNews;
- (void)setFileListFiles:(BOOL)value;
- (BOOL)fileListFiles;
- (void)setFileGetInfo:(BOOL)value;
- (BOOL)fileGetInfo;
- (void)setFileCreateDirectories:(BOOL)value;
- (BOOL)fileCreateDirectories;
- (void)setFileCreateLinks:(BOOL)value;
- (BOOL)fileCreateLinks;
- (void)setFileMoveFiles:(BOOL)value;
- (BOOL)fileMoveFiles;
- (void)setFileRenameFiles:(BOOL)value;
- (BOOL)fileRenameFiles;
- (void)setFileSetType:(BOOL)value;
- (BOOL)fileSetType;
- (void)setFileSetComment:(BOOL)value;
- (BOOL)fileSetComment;
- (void)setFileSetPermissions:(BOOL)value;
- (BOOL)fileSetPermissions;
- (void)setFileSetExecutable:(BOOL)value;
- (BOOL)fileSetExecutable;
- (void)setFileDeleteFiles:(BOOL)value;
- (BOOL)fileDeleteFiles;
- (void)setFileAccessAllDropboxes:(BOOL)value;
- (BOOL)fileAccessAllDropboxes;
- (void)setFileRecursiveListDepthLimit:(NSUInteger)value;
- (NSUInteger)fileRecursiveListDepthLimit;
- (void)setTransferDownloadFiles:(BOOL)value;
- (BOOL)transferDownloadFiles;
- (void)setTransferUploadFiles:(BOOL)value;
- (BOOL)transferUploadFiles;
- (void)setTransferUploadDirectories:(BOOL)value;
- (BOOL)transferUploadDirectories;
- (void)setTransferUploadAnywhere:(BOOL)value;
- (BOOL)transferUploadAnywhere;
- (void)setTransferDownloadLimit:(NSUInteger)value;
- (NSUInteger)transferDownloadLimit;
- (void)setTransferUploadLimit:(NSUInteger)value;
- (NSUInteger)transferUploadLimit;
- (void)setTransferDownloadSpeedLimit:(NSUInteger)value;
- (NSUInteger)transferDownloadSpeedLimit;
- (void)setTransferUploadSpeedLimit:(NSUInteger)value;
- (NSUInteger)transferUploadSpeedLimit;
- (void)setAccountChangePassword:(BOOL)value;
- (BOOL)accountChangePassword;
- (void)setAccountListAccounts:(BOOL)value;
- (BOOL)accountListAccounts;
- (void)setAccountReadAccounts:(BOOL)value;
- (BOOL)accountReadAccounts;
- (void)setAccountCreateAccounts:(BOOL)value;
- (BOOL)accountCreateAccounts;
- (void)setAccountEditAccounts:(BOOL)value;
- (BOOL)accountEditAccounts;
- (void)setAccountDeleteAccounts:(BOOL)value;
- (BOOL)accountDeleteAccounts;
- (void)setAccountRaiseAccountPrivileges:(BOOL)value;
- (BOOL)accountRaiseAccountPrivileges;
- (void)setLogViewLog:(BOOL)value;
- (BOOL)logViewLog;
- (void)setSettingsGetSettings:(BOOL)value;
- (BOOL)settingsGetSettings;
- (void)setSettingsSetSettings:(BOOL)value;
- (BOOL)settingsSetSettings;
- (void)setBanlistGetBans:(BOOL)value;
- (BOOL)banlistGetBans;
- (void)setBanlistAddBans:(BOOL)value;
- (BOOL)banlistAddBans;
- (void)setBanlistDeleteBans:(BOOL)value;
- (BOOL)banlistDeleteBans;
- (void)setTrackerListServers:(BOOL)value;
- (BOOL)trackerListServers;
- (void)setTrackerRegisterServers:(BOOL)value;
- (BOOL)trackerRegisterServers;

- (NSComparisonResult)compareName:(WCAccount *)account;
- (NSComparisonResult)compareType:(WCAccount *)account;

@end


@interface WCUserAccount : WCAccount {
	NSDate					*_loginDate;
	NSString				*_fullName;
	NSString				*_group;
	NSArray					*_groups;
	NSString				*_password;
}

- (NSDate *)loginDate;
- (void)setFullName:(NSString *)name;
- (NSString *)fullName;
- (void)setGroup:(NSString *)group;
- (NSString *)group;
- (void)setGroups:(NSArray *)groups;
- (NSArray *)groups;
- (void)setPassword:(NSString *)password;
- (NSString *)password;

@end


@interface WCGroupAccount : WCAccount

@end
