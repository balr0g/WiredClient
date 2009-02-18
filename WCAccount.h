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

#define WCAccountFieldName					@"WCAccountFieldName"
#define WCAccountFieldLocalizedName			@"WCAccountFieldLocalizedName"
#define WCAccountFieldType					@"WCAccountFieldType"
#define WCAccountFieldString					0
#define WCAccountFieldDate						1
#define WCAccountFieldNumber					2
#define WCAccountFieldBoolean					3
#define WCAccountFieldList						4
#define WCAccountFieldSection				@"WCAccountFieldSection"
#define WCAccountFieldNone						0
#define WCAccountFieldBasics					1
#define WCAccountFieldFiles						2
#define WCAccountFieldBoards					3
#define WCAccountFieldTracker					4
#define WCAccountFieldUsers						5
#define WCAccountFieldAccounts					6
#define WCAccountFieldAdministration			7
#define WCAccountFieldLimits					8
#define WCAccountFieldReadOnly				@"WCAccountFieldReadOnly"
#define WCAccountFieldToolTip				@"WCAccountFieldToolTip"


@interface WCAccount : WIObject {
	NSMutableDictionary						*_values;
}

+ (NSArray *)fields;

+ (id)account;
+ (id)accountWithName:(NSString *)name;
+ (id)accountWithMessage:(WIP7Message *)message;

- (WIP7Message *)createAccountMessage;
- (WIP7Message *)editAccountMessage;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (NSDate *)creationDate;
- (NSDate *)modificationDate;
- (NSString *)editedBy;
- (NSString *)files;
- (BOOL)userCannotSetNick;
- (BOOL)userGetInfo;
- (BOOL)userKickUsers;
- (BOOL)userBanUsers;
- (BOOL)userCannotBeDisconnected;
- (BOOL)userGetUsers;
- (BOOL)chatSetTopic;
- (BOOL)chatCreateChats;
- (BOOL)messageSendMessages;
- (BOOL)messageBroadcast;
- (BOOL)boardReadBoards;
- (BOOL)boardAddBoards;
- (BOOL)boardMoveBoards;
- (BOOL)boardRenameBoards;
- (BOOL)boardDeleteBoards;
- (BOOL)boardSetPermissions;
- (BOOL)boardAddThreads;
- (BOOL)boardMoveThreads;
- (BOOL)boardDeleteThreads;
- (BOOL)boardAddPosts;
- (BOOL)boardEditOwnPosts;
- (BOOL)boardEditAllPosts;
- (BOOL)boardDeletePosts;
- (BOOL)fileListFiles;
- (BOOL)fileGetInfo;
- (BOOL)fileCreateDirectories;
- (BOOL)fileCreateLinks;
- (BOOL)fileMoveFiles;
- (BOOL)fileRenameFiles;
- (BOOL)fileSetType;
- (BOOL)fileSetComment;
- (BOOL)fileSetPermissions;
- (BOOL)fileSetExecutable;
- (BOOL)fileDeleteFiles;
- (BOOL)fileAccessAllDropboxes;
- (NSUInteger)fileRecursiveListDepthLimit;
- (BOOL)transferDownloadFiles;
- (BOOL)transferUploadFiles;
- (BOOL)transferUploadDirectories;
- (BOOL)transferUploadAnywhere;
- (NSUInteger)transferDownloadLimit;
- (NSUInteger)transferUploadLimit;
- (NSUInteger)transferDownloadSpeedLimit;
- (NSUInteger)transferUploadSpeedLimit;
- (BOOL)accountChangePassword;
- (BOOL)accountListAccounts;
- (BOOL)accountReadAccounts;
- (BOOL)accountCreateUsers;
- (BOOL)accountEditUsers;
- (BOOL)accountDeleteUsers;
- (BOOL)accountCreateGroups;
- (BOOL)accountEditGroups;
- (BOOL)accountDeleteGroups;
- (BOOL)accountRaiseAccountPrivileges;
- (BOOL)logViewLog;
- (BOOL)settingsGetSettings;
- (BOOL)settingsSetSettings;
- (BOOL)banlistGetBans;
- (BOOL)banlistAddBans;
- (BOOL)banlistDeleteBans;
- (BOOL)trackerListServers;
- (BOOL)trackerRegisterServers;

- (void)setValue:(id)value forKey:(NSString *)key;
- (id)valueForKey:(NSString *)key;
- (void)setValues:(NSDictionary *)values;
- (NSDictionary *)values;

- (NSComparisonResult)compareName:(WCAccount *)account;
- (NSComparisonResult)compareType:(WCAccount *)account;

@end


@class WCGroupAccount;

@interface WCUserAccount : WCAccount {
	WCGroupAccount					*_groupAccount;
}

- (void)setGroupAccount:(WCGroupAccount *)account;
- (WCGroupAccount *)groupAccount;

- (NSDate *)loginDate;
- (void)setFullName:(NSString *)fullName;
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
