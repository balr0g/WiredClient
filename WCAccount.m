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

#import "WCAccount.h"
#import "WCServerConnection.h"

@interface WCAccount(Private)

- (id)_initWithMessage:(WIP7Message *)message;

- (void)_writeToMessage:(WIP7Message *)message;

@end


@implementation WCAccount(Private)

- (id)_initWithMessage:(WIP7Message *)message {
	self = [super init];

	_name				= [[message stringForName:@"wired.account.name"] retain];
	_creationDate		= [[message dateForName:@"wired.account.creation_time"] retain];
	_modificationDate	= [[message dateForName:@"wired.account.modification_time"] retain];
	_editedBy			= [[message stringForName:@"wired.account.edited_by"] retain];
	_files				= [[message stringForName:@"wired.account.files"] retain];

	[message getBool:&_userCannotSetNick forName:@"wired.account.user.cannot_set_nick"];
	[message getBool:&_userGetInfo forName:@"wired.account.user.get_info"];
	[message getBool:&_userKickUsers forName:@"wired.account.user.kick_users"];
	[message getBool:&_userBanUsers forName:@"wired.account.user.ban_users"];
	[message getBool:&_userCannotBeDisconnected forName:@"wired.account.user.cannot_be_disconnected"];
	[message getBool:&_userGetUsers forName:@"wired.account.user.get_users"];
	[message getBool:&_chatSetTopic forName:@"wired.account.chat.set_topic"];
	[message getBool:&_chatCreateChats forName:@"wired.account.chat.create_chats"];
	[message getBool:&_messageSendMessages forName:@"wired.account.message.send_messages"];
	[message getBool:&_messageBroadcast forName:@"wired.account.message.broadcast"];
	[message getBool:&_newsReadNews forName:@"wired.account.news.read_news"];
	[message getBool:&_newsPostNews forName:@"wired.account.news.post_news"];
	[message getBool:&_newsClearNews forName:@"wired.account.news.clear_news"];
	[message getBool:&_fileListFiles forName:@"wired.account.file.list_files"];
	[message getBool:&_fileGetInfo forName:@"wired.account.file.get_info"];
	[message getBool:&_fileCreateDirectories forName:@"wired.account.file.create_directories"];
	[message getBool:&_fileCreateLinks forName:@"wired.account.file.create_links"];
	[message getBool:&_fileMoveFiles forName:@"wired.account.file.move_files"];
	[message getBool:&_fileRenameFiles forName:@"wired.account.file.rename_files"];
	[message getBool:&_fileSetType forName:@"wired.account.file.set_type"];
	[message getBool:&_fileSetComment forName:@"wired.account.file.set_comment"];
	[message getBool:&_fileSetPermissions forName:@"wired.account.file.set_permissions"];
	[message getBool:&_fileSetExecutable forName:@"wired.account.file.set_executable"];
	[message getBool:&_fileDeleteFiles forName:@"wired.account.file.delete_files"];
	[message getBool:&_fileAccessAllDropboxes forName:@"wired.account.file.access_all_dropboxes"];
	[message getUInt32:&_fileRecursiveListDepthLimit forName:@"wired.account.file.recursive_list_depth_limit"];
	[message getBool:&_transferDownloadFiles forName:@"wired.account.transfer.download_files"];
	[message getBool:&_transferUploadFiles forName:@"wired.account.transfer.upload_files"];
	[message getBool:&_transferUploadDirectories forName:@"wired.account.transfer.upload_directories"];
	[message getBool:&_transferUploadAnywhere forName:@"wired.account.transfer.upload_anywhere"];
	[message getUInt32:&_transferDownloadLimit forName:@"wired.account.transfer.download_limit"];
	[message getUInt32:&_transferUploadLimit forName:@"wired.account.transfer.upload_limit"];
	[message getUInt32:&_transferDownloadSpeedLimit forName:@"wired.account.transfer.download_speed_limit"];
	[message getUInt32:&_transferUploadSpeedLimit forName:@"wired.account.transfer.upload_speed_limit"];
	[message getBool:&_accountChangePassword forName:@"wired.account.account.change_password"];
	[message getBool:&_accountListAccounts forName:@"wired.account.account.list_accounts"];
	[message getBool:&_accountReadAccounts forName:@"wired.account.account.read_accounts"];
	[message getBool:&_accountCreateAccounts forName:@"wired.account.account.create_accounts"];
	[message getBool:&_accountEditAccounts forName:@"wired.account.account.edit_accounts"];
	[message getBool:&_accountDeleteAccounts forName:@"wired.account.account.delete_accounts"];
	[message getBool:&_accountRaiseAccountPrivileges forName:@"wired.account.account.raise_account_privileges"];
	[message getBool:&_logViewLog forName:@"wired.account.log.view_log"];
	[message getBool:&_settingsGetSettings forName:@"wired.account.settings.get_settings"];
	[message getBool:&_settingsSetSettings forName:@"wired.account.settings.set_settings"];
	[message getBool:&_trackerListServers forName:@"wired.account.tracker.list_servers"];
	[message getBool:&_trackerRegisterServers forName:@"wired.account.tracker.register_servers"];

	return self;
}



#pragma mark -

- (void)_writeToMessage:(WIP7Message *)message {
	[message setString:_name forName:@"wired.account.name"];
	[message setString:_files forName:@"wired.account.files"];
	[message setBool:_userCannotSetNick forName:@"wired.account.user.cannot_set_nick"];
	[message setBool:_userGetInfo forName:@"wired.account.user.get_info"];
	[message setBool:_userKickUsers forName:@"wired.account.user.kick_users"];
	[message setBool:_userBanUsers forName:@"wired.account.user.ban_users"];
	[message setBool:_userCannotBeDisconnected forName:@"wired.account.user.cannot_be_disconnected"];
	[message setBool:_userGetUsers forName:@"wired.account.user.get_users"];
	[message setBool:_chatSetTopic forName:@"wired.account.chat.set_topic"];
	[message setBool:_chatCreateChats forName:@"wired.account.chat.create_chats"];
	[message setBool:_messageSendMessages forName:@"wired.account.message.send_messages"];
	[message setBool:_messageBroadcast forName:@"wired.account.message.broadcast"];
	[message setBool:_newsReadNews forName:@"wired.account.news.read_news"];
	[message setBool:_newsPostNews forName:@"wired.account.news.post_news"];
	[message setBool:_newsClearNews forName:@"wired.account.news.clear_news"];
	[message setBool:_fileListFiles forName:@"wired.account.file.list_files"];
	[message setBool:_fileGetInfo forName:@"wired.account.file.get_info"];
	[message setBool:_fileCreateDirectories forName:@"wired.account.file.create_directories"];
	[message setBool:_fileCreateLinks forName:@"wired.account.file.create_links"];
	[message setBool:_fileMoveFiles forName:@"wired.account.file.move_files"];
	[message setBool:_fileRenameFiles forName:@"wired.account.file.rename_files"];
	[message setBool:_fileSetType forName:@"wired.account.file.set_type"];
	[message setBool:_fileSetComment forName:@"wired.account.file.set_comment"];
	[message setBool:_fileSetPermissions forName:@"wired.account.file.set_permissions"];
	[message setBool:_fileSetExecutable forName:@"wired.account.file.set_executable"];
	[message setBool:_fileDeleteFiles forName:@"wired.account.file.delete_files"];
	[message setBool:_fileAccessAllDropboxes forName:@"wired.account.file.access_all_dropboxes"];
	[message setUInt32:_fileRecursiveListDepthLimit forName:@"wired.account.file.recursive_list_depth_limit"];
	[message setBool:_transferDownloadFiles forName:@"wired.account.transfer.download_files"];
	[message setBool:_transferUploadFiles forName:@"wired.account.transfer.upload_files"];
	[message setBool:_transferUploadDirectories forName:@"wired.account.transfer.upload_directories"];
	[message setBool:_transferUploadAnywhere forName:@"wired.account.transfer.upload_anywhere"];
	[message setUInt32:_transferDownloadLimit forName:@"wired.account.transfer.download_limit"];
	[message setUInt32:_transferUploadLimit forName:@"wired.account.transfer.upload_limit"];
	[message setUInt32:_transferDownloadSpeedLimit forName:@"wired.account.transfer.download_speed_limit"];
	[message setUInt32:_transferUploadSpeedLimit forName:@"wired.account.transfer.upload_speed_limit"];
	[message setBool:_accountChangePassword forName:@"wired.account.account.change_password"];
	[message setBool:_accountListAccounts forName:@"wired.account.account.list_accounts"];
	[message setBool:_accountReadAccounts forName:@"wired.account.account.read_accounts"];
	[message setBool:_accountCreateAccounts forName:@"wired.account.account.create_accounts"];
	[message setBool:_accountEditAccounts forName:@"wired.account.account.edit_accounts"];
	[message setBool:_accountDeleteAccounts forName:@"wired.account.account.delete_accounts"];
	[message setBool:_accountRaiseAccountPrivileges forName:@"wired.account.account.raise_account_privileges"];
	[message setBool:_logViewLog forName:@"wired.account.log.view_log"];
	[message setBool:_settingsGetSettings forName:@"wired.account.settings.get_settings"];
	[message setBool:_settingsSetSettings forName:@"wired.account.settings.set_settings"];
	[message setBool:_trackerListServers forName:@"wired.account.tracker.list_servers"];
	[message setBool:_trackerRegisterServers forName:@"wired.account.tracker.register_servers"];
}

@end


@implementation WCAccount

+ (id)account {
	return [[[self alloc] init] autorelease];
}



+ (id)accountWithMessage:(WIP7Message *)message {
	return [[[self alloc] _initWithMessage:message] autorelease];
}



- (void)dealloc {
	[_name release];
	[_creationDate release];
	[_modificationDate release];
	[_editedBy release];
	[_files release];

	[super dealloc];
}



#pragma mark -

- (NSString *)description {
	return [NSSWF:@"<%@ %p>{name = %@}",
		[self className],
		self,
		[self name]];
}



#pragma mark -

- (WIP7Message *)createAccountMessage {
	[self doesNotRecognizeSelector:_cmd];

	return NULL;
}



- (WIP7Message *)editAccountMessage {
	[self doesNotRecognizeSelector:_cmd];
	
	return NULL;
}



#pragma mark -

- (void)setName:(NSString *)name {
	[name retain];
	[_name release];
	
	_name = name;
}



- (NSString *)name {
	return _name;
}



- (NSDate *)modificationDate {
	return _modificationDate;
}



- (NSDate *)creationDate {
	return _creationDate;
}



- (NSString *)editedBy {
	return _editedBy;
}



- (void)setFiles:(NSString *)files {
	[files retain];
	[_files release];
	
	_files = files;
}



- (NSString *)files {
	return _files;
}



- (void)setUserCannotSetNick:(BOOL)value {
	_userCannotSetNick = value;
}



- (BOOL)userCannotSetNick {
	return _userCannotSetNick;
}



- (void)setUserGetInfo:(BOOL)value {
	_userGetInfo = value;
}



- (BOOL)userGetInfo {
	return _userGetInfo;
}



- (void)setUserKickUsers:(BOOL)value {
	_userKickUsers = value;
}



- (BOOL)userKickUsers {
	return _userKickUsers;
}



- (void)setUserBanUsers:(BOOL)value {
	_userBanUsers = value;
}



- (BOOL)userBanUsers {
	return _userBanUsers;
}



- (void)setUserCannotBeDisconnected:(BOOL)value {
	_userCannotBeDisconnected = value;
}



- (BOOL)userCannotBeDisconnected {
	return _userCannotBeDisconnected;
}



- (void)setUserGetUsers:(BOOL)value {
	_userGetUsers = value;
}



- (BOOL)userGetUsers {
	return _userGetUsers;
}



- (void)setChatSetTopic:(BOOL)value {
	_chatSetTopic = value;
}



- (BOOL)chatSetTopic {
	return _chatSetTopic;
}



- (void)setChatCreateChats:(BOOL)value {
	_chatCreateChats = value;
}



- (BOOL)chatCreateChats {
	return _chatCreateChats;
}



- (void)setMessageSendMessages:(BOOL)value {
	_messageSendMessages = value;
}



- (BOOL)messageSendMessages {
	return _messageSendMessages;
}



- (void)setMessageBroadcast:(BOOL)value {
	_messageBroadcast = value;
}



- (BOOL)messageBroadcast {
	return _messageBroadcast;
}



- (void)setNewsReadNews:(BOOL)value {
	_newsReadNews = value;
}



- (BOOL)newsReadNews {
	return _newsReadNews;
}



- (void)setNewsPostNews:(BOOL)value {
	_newsPostNews = value;
}



- (BOOL)newsPostNews {
	return _newsPostNews;
}



- (void)setNewsClearNews:(BOOL)value {
	_newsClearNews = value;
}



- (BOOL)newsClearNews {
	return _newsClearNews;
}



- (void)setFileListFiles:(BOOL)value {
	_fileListFiles = value;
}



- (BOOL)fileListFiles {
	return _fileListFiles;
}



- (void)setFileGetInfo:(BOOL)value {
	_fileGetInfo = value;
}



- (BOOL)fileGetInfo {
	return _fileGetInfo;
}



- (void)setFileCreateDirectories:(BOOL)value {
	_fileCreateDirectories = value;
}



- (BOOL)fileCreateDirectories {
	return _fileCreateDirectories;
}



- (void)setFileCreateLinks:(BOOL)value {
	_fileCreateLinks = value;
}



- (BOOL)fileCreateLinks {
	return _fileCreateLinks;
}



- (void)setFileMoveFiles:(BOOL)value {
	_fileMoveFiles = value;
}



- (BOOL)fileMoveFiles {
	return _fileMoveFiles;
}



- (void)setFileRenameFiles:(BOOL)value {
	_fileRenameFiles = value;
}



- (BOOL)fileRenameFiles {
	return _fileRenameFiles;
}



- (void)setFileSetType:(BOOL)value {
	_fileSetType = value;
}



- (BOOL)fileSetType {
	return _fileSetType;
}



- (void)setFileSetComment:(BOOL)value {
	_fileSetComment = value;
}



- (BOOL)fileSetComment {
	return _fileSetComment;
}



- (void)setFileSetPermissions:(BOOL)value {
	_fileSetPermissions = value;
}



- (BOOL)fileSetPermissions {
	return _fileSetPermissions;
}



- (void)setFileSetExecutable:(BOOL)value {
	_fileSetExecutable = value;
}



- (BOOL)fileSetExecutable {
	return _fileSetExecutable;
}



- (void)setFileDeleteFiles:(BOOL)value {
	_fileDeleteFiles = value;
}



- (BOOL)fileDeleteFiles {
	return _fileDeleteFiles;
}



- (void)setFileAccessAllDropboxes:(BOOL)value {
	_fileAccessAllDropboxes = value;
}



- (BOOL)fileAccessAllDropboxes {
	return _fileAccessAllDropboxes;
}



- (void)setFileRecursiveListDepthLimit:(NSUInteger)value {
	_fileRecursiveListDepthLimit = value;
}



- (NSUInteger)fileRecursiveListDepthLimit {
	return _fileRecursiveListDepthLimit;
}



- (void)setTransferDownloadFiles:(BOOL)value {
	_transferDownloadFiles = value;
}



- (BOOL)transferDownloadFiles {
	return _transferDownloadFiles;
}



- (void)setTransferUploadFiles:(BOOL)value {
	_transferUploadFiles = value;
}



- (BOOL)transferUploadFiles {
	return _transferUploadFiles;
}



- (void)setTransferUploadDirectories:(BOOL)value {
	_transferUploadDirectories = value;
}



- (BOOL)transferUploadDirectories {
	return _transferUploadDirectories;
}



- (void)setTransferUploadAnywhere:(BOOL)value {
	_transferUploadAnywhere = value;
}



- (BOOL)transferUploadAnywhere {
	return _transferUploadAnywhere;
}



- (void)setTransferDownloadLimit:(NSUInteger)value {
	_transferDownloadLimit = value;
}



- (NSUInteger)transferDownloadLimit {
	return _transferDownloadLimit;
}



- (void)setTransferUploadLimit:(NSUInteger)value {
	_transferUploadLimit = value;
}



- (NSUInteger)transferUploadLimit {
	return _transferUploadLimit;
}



- (void)setTransferDownloadSpeedLimit:(NSUInteger)value {
	_transferDownloadSpeedLimit = value;
}



- (NSUInteger)transferDownloadSpeedLimit {
	return _transferDownloadSpeedLimit;
}



- (void)setTransferUploadSpeedLimit:(NSUInteger)value {
	_transferUploadSpeedLimit = value;
}



- (NSUInteger)transferUploadSpeedLimit {
	return _transferUploadSpeedLimit;
}



- (void)setAccountChangePassword:(BOOL)value {
	_accountChangePassword = value;
}



- (BOOL)accountChangePassword {
	return _accountChangePassword;
}



- (void)setAccountListAccounts:(BOOL)value {
	_accountListAccounts = value;
}



- (BOOL)accountListAccounts {
	return _accountListAccounts;
}



- (void)setAccountReadAccounts:(BOOL)value {
	_accountReadAccounts = value;
}



- (BOOL)accountReadAccounts {
	return _accountReadAccounts;
}



- (void)setAccountCreateAccounts:(BOOL)value {
	_accountCreateAccounts = value;
}



- (BOOL)accountCreateAccounts {
	return _accountCreateAccounts;
}



- (void)setAccountEditAccounts:(BOOL)value {
	_accountEditAccounts = value;
}



- (BOOL)accountEditAccounts {
	return _accountEditAccounts;
}



- (void)setAccountDeleteAccounts:(BOOL)value {
	_accountDeleteAccounts = value;
}



- (BOOL)accountDeleteAccounts {
	return _accountDeleteAccounts;
}



- (void)setAccountRaiseAccountPrivileges:(BOOL)value {
	_accountRaiseAccountPrivileges = value;
}



- (BOOL)accountRaiseAccountPrivileges {
	return _accountRaiseAccountPrivileges;
}



- (void)setLogViewLog:(BOOL)value {
	_logViewLog = value;
}



- (BOOL)logViewLog {
	return _logViewLog;
}



- (void)setSettingsGetSettings:(BOOL)value {
	_settingsGetSettings = value;
}



- (BOOL)settingsGetSettings {
	return _settingsGetSettings;
}



- (void)setSettingsSetSettings:(BOOL)value {
	_settingsSetSettings = value;
}



- (BOOL)settingsSetSettings {
	return _settingsSetSettings;
}



- (void)setTrackerListServers:(BOOL)value {
	_trackerListServers = value;
}



- (BOOL)trackerListServers {
	return _trackerListServers;
}



- (void)setTrackerRegisterServers:(BOOL)value {
	_trackerRegisterServers = value;
}



- (BOOL)trackerRegisterServers {
	return _trackerRegisterServers;
}



#pragma mark -

- (NSComparisonResult)compareName:(WCAccount *)account {
	return [[self name] compare:[account name] options:NSCaseInsensitiveSearch];
}



- (NSComparisonResult)compareType:(WCAccount *)account {
	if([self isKindOfClass:[WCUserAccount class]] && [account isKindOfClass:[WCGroupAccount class]])
		return NSOrderedAscending;
	else if([self isKindOfClass:[WCGroupAccount class]] && [account isKindOfClass:[WCUserAccount class]])
		return NSOrderedDescending;

	return [self compareName:account];
}

@end



@implementation WCUserAccount(Private)

- (id)_initWithMessage:(WIP7Message *)message {
	self = [super _initWithMessage:message];
	
	_loginDate	= [[message dateForName:@"wired.account.login_time"] retain];
	_fullName	= [[message stringForName:@"wired.account.full_name"] retain];
	_group		= [[message stringForName:@"wired.account.group"] retain];
	_groups		= [[message listForName:@"wired.account.groups"] retain];
	_password	= [[message stringForName:@"wired.account.password"] retain];
	
	return self;
}



#pragma mark -

- (void)_writeToMessage:(WIP7Message *)message {
	[message setString:_fullName forName:@"wired.account.full_name"];
	[message setString:_group forName:@"wired.account.group"];
	[message setList:_groups forName:@"wired.account.groups"];
	[message setString:_password forName:@"wired.account.password"];
	
	[super _writeToMessage:message];
}

@end


@implementation WCUserAccount

- (void)dealloc {
	[_loginDate release];
	[_fullName release];
	[_group release];
	[_groups release];
	[_password release];
	
	[super dealloc];
}



#pragma mark -

- (WIP7Message *)createAccountMessage {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.account.create_user" spec:WCP7Spec];

	[self _writeToMessage:message];
	
	return message;
}



- (WIP7Message *)editAccountMessage {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.account.edit_user" spec:WCP7Spec];

	[self _writeToMessage:message];
	
	return message;
}



#pragma mark -

- (NSDate *)loginDate {
	return _loginDate;
}



- (void)setFullName:(NSString *)fullName {
	[fullName retain];
	[_fullName release];
	
	_fullName = fullName;
}



- (NSString *)fullName {
	return _fullName;
}



- (void)setGroup:(NSString *)group {
	[group retain];
	[_group release];
	
	_group = group;
}



- (NSString *)group {
	return _group;
}



- (void)setGroups:(NSArray *)groups {
	[groups retain];
	[_groups release];
	
	_groups = groups;
}



- (NSArray *)groups {
	return _groups;
}



- (void)setPassword:(NSString *)password {
	[password retain];
	[_password release];
	
	_password = password;
}



- (NSString *)password {
	return _password;
}

@end



@implementation WCGroupAccount

- (WIP7Message *)createAccountMessage {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.account.create_group" spec:WCP7Spec];

	[self _writeToMessage:message];
	
	return message;
}



- (WIP7Message *)editAccountMessage {
	WIP7Message		*message;
	
	message = [WIP7Message messageWithName:@"wired.account.edit_group" spec:WCP7Spec];

	[self _writeToMessage:message];
	
	return message;
}

@end
