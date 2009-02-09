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
	NSEnumerator	*enumerator;
	NSDictionary	*field;
	id				value;
	
	self = [super init];
	
	_values = [[NSMutableDictionary alloc] init];
	
	enumerator = [[[self class] fields] objectEnumerator];
	
	while((field = [enumerator nextObject])) {
		value = NULL;
		
		switch([[field objectForKey:WCAccountFieldType] intValue]) {
			case WCAccountFieldString:
				value = [message stringForName:[field objectForKey:WCAccountFieldName]];
				break;
			
			case WCAccountFieldDate:
				value = [message dateForName:[field objectForKey:WCAccountFieldName]];
				break;

			case WCAccountFieldNumber:
			case WCAccountFieldBoolean:
				value = [message numberForName:[field objectForKey:WCAccountFieldName]];
				break;

			case WCAccountFieldList:
				value = [message listForName:[field objectForKey:WCAccountFieldName]];
				break;
		}
		
		if(value)
			[_values setObject:value forKey:[field objectForKey:WCAccountFieldKey]];
	}

	return self;
}



#pragma mark -

- (void)_writeToMessage:(WIP7Message *)message {
	NSEnumerator	*enumerator;
	NSDictionary	*field;
	id				value;
	
	enumerator = [[[self class] fields] objectEnumerator];
	
	while((field = [enumerator nextObject])) {
		value = [_values objectForKey:[field objectForKey:WCAccountFieldKey]];
		
		if(value) {
			switch([[field objectForKey:WCAccountFieldType] intValue]) {
				case WCAccountFieldString:
					[message setString:value forName:[field objectForKey:WCAccountFieldName]];
					break;
				
				case WCAccountFieldDate:
					[message setDate:value forName:[field objectForKey:WCAccountFieldName]];
					break;

				case WCAccountFieldNumber:
				case WCAccountFieldBoolean:
					[message setNumber:value forName:[field objectForKey:WCAccountFieldName]];
					break;

				case WCAccountFieldList:
					[message setList:value forName:[field objectForKey:WCAccountFieldName]];
					break;
			}
		}
	}
}

@end


@implementation WCAccount

+ (NSArray *)fields {
	static NSArray		*fields;
	
	if(!fields) {
		fields = [[NSArray alloc] initWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"name",												WCAccountFieldKey,
				@"wired.account.name",									WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldString],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fullName",											WCAccountFieldKey,
				@"wired.account.full_name",								WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldString],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"creationDate",										WCAccountFieldKey,
				@"wired.account.creation_time",							WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldDate],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"modificationDate",									WCAccountFieldKey,
				@"wired.account.modification_time",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldDate],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"loginDate",											WCAccountFieldKey,
				@"wired.account.login_time",							WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldDate],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"editedBy",											WCAccountFieldKey,
				@"wired.account.edited_by",								WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldString],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"group",												WCAccountFieldKey,
				@"wired.account.group",									WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldString],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"groups",												WCAccountFieldKey,
				@"wired.account.groups",								WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldList],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"password",											WCAccountFieldKey,
				@"wired.account.password",								WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldString],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"files",												WCAccountFieldKey,
				@"wired.account.files",									WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldString],			WCAccountFieldType,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"userCannotSetNick",									WCAccountFieldKey,
				NSLS(@"Cannot Set Nick", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.user.cannot_set_nick",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBasics],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"userGetInfo",											WCAccountFieldKey,
				NSLS(@"Get User Info", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.user.get_info",							WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBasics],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"userKickUsers",										WCAccountFieldKey,
				NSLS(@"Kick Users", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.user.kick_users",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldUsers],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"userBanUsers",										WCAccountFieldKey,
				NSLS(@"Ban Users", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.user.ban_users",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldUsers],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"userCannotBeDisconnected",							WCAccountFieldKey,
				NSLS(@"Cannot Be Disconnected", @"Account field name"),	WCAccountFieldLocalizedName,
				@"wired.account.user.cannot_be_disconnected",			WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldUsers],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"userGetUsers",										WCAccountFieldKey,
				NSLS(@"Monitor Users", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.user.get_users",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAdministration],	WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"chatSetTopic",										WCAccountFieldKey,
				NSLS(@"Set Chat Topic", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.chat.set_topic",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBasics],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"chatCreateChats",										WCAccountFieldKey,
				NSLS(@"Create Chats", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.chat.create_chats",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBasics],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"messageSendMessages",									WCAccountFieldKey,
				NSLS(@"Send Messages", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.message.send_messages",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBasics],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"messageBroadcast",									WCAccountFieldKey,
				NSLS(@"Broadcast Messages", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.message.broadcast",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBasics],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardReadBoards",										WCAccountFieldKey,
				NSLS(@"Read Boards", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.read_boards",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardAddBoards",										WCAccountFieldKey,
				NSLS(@"Add Boards", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.board.add_boards",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardMoveBoards",										WCAccountFieldKey,
				NSLS(@"Move Boards", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.move_boards",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardRenameBoards",									WCAccountFieldKey,
				NSLS(@"Rename Boards", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.rename_boards",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardDeleteBoards",									WCAccountFieldKey,
				NSLS(@"Delete Boards", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.delete_boards",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardSetPermissions",									WCAccountFieldKey,
				NSLS(@"Set Board Permissions", @"Account field name"),	WCAccountFieldLocalizedName,
				@"wired.account.board.set_permissions",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardAddThreads",										WCAccountFieldKey,
				NSLS(@"Add Threads", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.add_threads",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardMoveThreads",									WCAccountFieldKey,
				NSLS(@"Move Threads", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.move_threads",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardDeleteThreads",									WCAccountFieldKey,
				NSLS(@"Delete Threads", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.delete_threads",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardAddPosts",										WCAccountFieldKey,
				NSLS(@"Add Posts", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.board.add_posts",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardEditOwnPosts",									WCAccountFieldKey,
				NSLS(@"Edit Own Posts", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.edit_own_posts",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardEditAllPosts",									WCAccountFieldKey,
				NSLS(@"Edit All Posts", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.edit_all_posts",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"boardDeletePosts",									WCAccountFieldKey,
				NSLS(@"Delete Posts", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.board.delete_posts",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldBoards],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileListFiles",										WCAccountFieldKey,
				NSLS(@"List Files", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.file.list_files",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileGetInfo",											WCAccountFieldKey,
				NSLS(@"Get File Info", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.file.get_info",							WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileCreateDirectories",								WCAccountFieldKey,
				NSLS(@"Create Directories", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.file.create_directories",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileCreateLinks",										WCAccountFieldKey,
				NSLS(@"Create Links", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.file.create_links",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileMoveFiles",										WCAccountFieldKey,
				NSLS(@"Move Files", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.file.move_files",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileRenameFiles",										WCAccountFieldKey,
				NSLS(@"Rename Files", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.file.rename_files",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileSetType",											WCAccountFieldKey,
				NSLS(@"Set Folder Type", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.file.set_type",							WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileSetComment",										WCAccountFieldKey,
				NSLS(@"Set Comments", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.file.set_comment",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileSetPermissions",									WCAccountFieldKey,
				NSLS(@"Set Permissions", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.file.set_permissions",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileSetExecutable",									WCAccountFieldKey,
				NSLS(@"Set Executable", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.file.set_executable",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileDeleteFiles",										WCAccountFieldKey,
				NSLS(@"Delete Files", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.file.delete_files",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileAccessAllDropboxes",								WCAccountFieldKey,
				NSLS(@"Access All Drop Boxes", @"Account field name"),	WCAccountFieldLocalizedName,
				@"wired.account.file.access_all_dropboxes",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"fileRecursiveListDepthLimit",							WCAccountFieldKey,
				NSLS(@"Download Folder Depth", @"Account field name"),	WCAccountFieldLocalizedName,
				@"wired.account.file.recursive_list_depth_limit",		WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldNumber],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldLimits],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferDownloadFiles",								WCAccountFieldKey,
				NSLS(@"Download Files", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.transfer.download_files",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferUploadFiles",									WCAccountFieldKey,
				NSLS(@"Upload Files", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.transfer.upload_files",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferUploadDirectories",							WCAccountFieldKey,
				NSLS(@"Upload Folders", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.transfer.upload_directories",			WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferUploadAnywhere",								WCAccountFieldKey,
				NSLS(@"Upload Anywhere", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.transfer.upload_anywhere",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldFiles],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferDownloadLimit",								WCAccountFieldKey,
				NSLS(@"Downloads", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.transfer.download_limit",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldNumber],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldLimits],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferUploadLimit",									WCAccountFieldKey,
				NSLS(@"Uploads", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.transfer.upload_limit",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldNumber],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldLimits],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferDownloadSpeedLimit",							WCAccountFieldKey,
				NSLS(@"Download Speed (KB/s)", @"Account field name"),	WCAccountFieldLocalizedName,
				@"wired.account.transfer.download_speed_limit",			WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldNumber],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldLimits],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"transferUploadSpeedLimit",							WCAccountFieldKey,
				NSLS(@"Upload Speed (KB/s)", @"Account field name"),	WCAccountFieldLocalizedName,
				@"wired.account.transfer.upload_speed_limit",			WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldNumber],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldLimits],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"accountChangePassword",								WCAccountFieldKey,
				NSLS(@"Change Password", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.account.change_password",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAccounts],		WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"accountListAccounts",									WCAccountFieldKey,
				NSLS(@"List Accounts", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.account.list_accounts",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAccounts],		WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"accountReadAccounts",									WCAccountFieldKey,
				NSLS(@"Read Accounts", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.account.read_accounts",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAccounts],		WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"accountCreateAccounts",								WCAccountFieldKey,
				NSLS(@"Create Accounts", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.account.create_accounts",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAccounts],		WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"accountEditAccounts",									WCAccountFieldKey,
				NSLS(@"Edit Accounts", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.account.edit_accounts",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAccounts],		WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"accountDeleteAccounts",								WCAccountFieldKey,
				NSLS(@"Delete Accounts", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.account.delete_accounts",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAccounts],		WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"accountRaiseAccountPrivileges",						WCAccountFieldKey,
				NSLS(@"Raise Privileges", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.account.raise_account_privileges",		WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAccounts],		WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"logViewLog",											WCAccountFieldKey,
				NSLS(@"View Log", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.log.view_log",							WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAdministration],	WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"settingsGetSettings",									WCAccountFieldKey,
				NSLS(@"Read Settings", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.settings.get_settings",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAdministration],	WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"settingsSetSettings",									WCAccountFieldKey,
				NSLS(@"Edit Settings", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.settings.set_settings",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAdministration],	WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"banlistGetBans",										WCAccountFieldKey,
				NSLS(@"Read Banlist", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.banlist.get_bans",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAdministration],	WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"banlistAddBans",										WCAccountFieldKey,
				NSLS(@"Add Bans", @"Account field name"),				WCAccountFieldLocalizedName,
				@"wired.account.banlist.add_bans",						WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAdministration],	WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"banlistDeleteBans",									WCAccountFieldKey,
				NSLS(@"Delete Bans", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.banlist.delete_bans",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldAdministration],	WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"trackerListServers",									WCAccountFieldKey,
				NSLS(@"List Servers", @"Account field name"),			WCAccountFieldLocalizedName,
				@"wired.account.tracker.list_servers",					WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldTracker],			WCAccountFieldSection,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"trackerRegisterServers",								WCAccountFieldKey,
				NSLS(@"Register Servers", @"Account field name"),		WCAccountFieldLocalizedName,
				@"wired.account.tracker.register_servers",				WCAccountFieldName,
				[NSNumber numberWithInt:WCAccountFieldBoolean],			WCAccountFieldType,
				[NSNumber numberWithInt:WCAccountFieldTracker],			WCAccountFieldSection,
				NULL],
			NULL];
	}
	
	return fields;
}



#pragma mark -

+ (id)account {
	return [[[self alloc] init] autorelease];
}



+ (id)accountWithMessage:(WIP7Message *)message {
	return [[[self alloc] _initWithMessage:message] autorelease];
}



- (void)dealloc {
	[_values release];
	
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

- (NSString *)name {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSDate *)modificationDate {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSDate *)creationDate {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSString *)editedBy {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSString *)files {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (BOOL)userCannotSetNick {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)userGetInfo {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)userKickUsers {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)userBanUsers {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)userCannotBeDisconnected {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)userGetUsers {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)chatSetTopic {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)chatCreateChats {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)messageSendMessages {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)messageBroadcast {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardReadBoards {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardAddBoards {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardMoveBoards {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardRenameBoards {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardDeleteBoards {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardSetPermissions {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardAddThreads {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardMoveThreads {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardDeleteThreads {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardAddPosts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardEditOwnPosts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardEditAllPosts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)boardDeletePosts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileListFiles {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileGetInfo {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileCreateDirectories {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileCreateLinks {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileMoveFiles {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileRenameFiles {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileSetType {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileSetComment {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileSetPermissions {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileSetExecutable {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileDeleteFiles {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)fileAccessAllDropboxes {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (NSUInteger)fileRecursiveListDepthLimit {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] unsignedIntegerValue];
}



- (BOOL)transferDownloadFiles {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)transferUploadFiles {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)transferUploadDirectories {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)transferUploadAnywhere {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (NSUInteger)transferDownloadLimit {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] unsignedIntegerValue];
}



- (NSUInteger)transferUploadLimit {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] unsignedIntegerValue];
}



- (NSUInteger)transferDownloadSpeedLimit {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] unsignedIntegerValue];
}



- (NSUInteger)transferUploadSpeedLimit {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] unsignedIntegerValue];
}



- (BOOL)accountChangePassword {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)accountListAccounts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)accountReadAccounts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)accountCreateAccounts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)accountEditAccounts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)accountDeleteAccounts {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)accountRaiseAccountPrivileges {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)logViewLog {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)settingsGetSettings {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)settingsSetSettings {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)trackerListServers {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)banlistGetBans {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)banlistAddBans {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)banlistDeleteBans {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



- (BOOL)trackerRegisterServers {
	return [[_values objectForKey:NSStringFromSelector(_cmd)] boolValue];
}



#pragma mark -

- (void)setValue:(id)value forKey:(NSString *)key {
	if(value)
		[_values setObject:value forKey:key];
	else
		[_values removeObjectForKey:key];
}



- (id)valueForKey:(NSString *)key {
	return [_values objectForKey:key];
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



@implementation WCUserAccount

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
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSString *)fullName {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSString *)group {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSArray *)groups {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
}



- (NSString *)password {
	return [_values objectForKey:NSStringFromSelector(_cmd)];
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
