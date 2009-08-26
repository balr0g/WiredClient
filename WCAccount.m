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
#import "WCServerConnection.h"

NSString * const WCAccountFieldName					= @"WCAccountFieldName";
NSString * const WCAccountFieldLocalizedName		= @"WCAccountFieldLocalizedName";
NSString * const WCAccountFieldType					= @"WCAccountFieldType";
NSString * const WCAccountFieldSection				= @"WCAccountFieldSection";
NSString * const WCAccountFieldReadOnly				= @"WCAccountFieldReadOnly";
NSString * const WCAccountFieldToolTip				= @"WCAccountFieldToolTip";


@interface WCAccount(Private)

- (id)_initWithMessage:(WIP7Message *)message;

- (void)_writeToMessage:(WIP7Message *)message;

@end


@implementation WCAccount(Private)

- (id)_initWithMessage:(WIP7Message *)message {
	NSEnumerator	*enumerator;
	NSDictionary	*field;
	NSString		*name;
	id				value;
	
	self = [self init];
	
	enumerator = [[[self class] fields] objectEnumerator];
	
	while((field = [enumerator nextObject])) {
		name	= [field objectForKey:WCAccountFieldName];
		value	= NULL;
		
		switch([[field objectForKey:WCAccountFieldType] intValue]) {
			case WCAccountFieldString:
				value = [message stringForName:name];
				break;
			
			case WCAccountFieldDate:
				value = [message dateForName:name];
				break;

			case WCAccountFieldNumber:
			case WCAccountFieldBoolean:
				value = [message numberForName:name];
				break;

			case WCAccountFieldList:
				value = [message listForName:name];
				break;
		}
		
		if(value)
			[_values setObject:value forKey:name];
	}

	return self;
}



#pragma mark -

- (void)_writeToMessage:(WIP7Message *)message {
	NSEnumerator	*enumerator;
	NSDictionary	*field;
	NSString		*name;
	id				value;
	
	enumerator = [[[self class] fields] objectEnumerator];
	
	while((field = [enumerator nextObject])) {
		if(![[field objectForKey:WCAccountFieldReadOnly] boolValue]) {
			name	= [field objectForKey:WCAccountFieldName];
			value	= [self valueForKey:name];
			
			if(value) {
				switch([[field objectForKey:WCAccountFieldType] intValue]) {
					case WCAccountFieldString:
						[message setString:value forName:name];
						break;
					
					case WCAccountFieldDate:
						[message setDate:value forName:name];
						break;

					case WCAccountFieldNumber:
					case WCAccountFieldBoolean:
						[message setNumber:value forName:name];
						break;

					case WCAccountFieldList:
						[message setList:value forName:name];
						break;
				}
			}
		}
	}
}

@end


@implementation WCAccount

#define WCAccountFieldDictionary(section, name, localizedname, type, readonly, tooltip)		\
	[NSDictionary dictionaryWithObjectsAndKeys:												\
		[NSNumber numberWithInteger:(section)],		WCAccountFieldSection,					\
		(name),										WCAccountFieldName,						\
		(localizedname),							WCAccountFieldLocalizedName,			\
		[NSNumber numberWithInteger:(type)],		WCAccountFieldType,						\
		[NSNumber numberWithBool:(readonly)],		WCAccountFieldReadOnly,					\
		(tooltip),									WCAccountFieldToolTip,					\
		NULL]

#define WCAccountFieldBooleanDictionary(section, name, localizedname, tooltip)				\
	WCAccountFieldDictionary((section), (name), (localizedname), WCAccountFieldBoolean, NO, (tooltip))

#define WCAccountFieldNumberDictionary(section, name, localizedname, tooltip)				\
	WCAccountFieldDictionary((section), (name), (localizedname), WCAccountFieldNumber, NO, (tooltip))

+ (NSArray *)fields {
	static NSArray		*fields;
	
	if(fields)
		return fields;
	
	fields = [[NSArray alloc] initWithObjects:
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.name", @"", WCAccountFieldString, NO, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.new_name", @"", WCAccountFieldString, NO, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.full_name", @"", WCAccountFieldString, NO, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.creation_time", @"", WCAccountFieldDate, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.modification_time", @"", WCAccountFieldDate, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.login_time", @"", WCAccountFieldDate, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.edited_by", @"", WCAccountFieldString, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.downloads", @"", WCAccountFieldNumber, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.download_transferred", @"", WCAccountFieldNumber, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.uploads", @"", WCAccountFieldNumber, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.upload_transferred", @"", WCAccountFieldNumber, YES, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.group", @"", WCAccountFieldString, NO, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.groups", @"", WCAccountFieldList, NO, @""),
		WCAccountFieldDictionary(WCAccountFieldNone,
			@"wired.account.password", @"", WCAccountFieldString, NO, @""),
		
		WCAccountFieldBooleanDictionary(WCAccountFieldBasics,
			@"wired.account.user.cannot_set_nick", NSLS(@"Cannot Set Nick", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBasics,
			@"wired.account.user.get_info", NSLS(@"Get User Info", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBasics,
			@"wired.account.chat.set_topic", NSLS(@"Set Chat Topic", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBasics,
			@"wired.account.chat.create_chats", NSLS(@"Create Chats", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBasics,
			@"wired.account.message.send_messages", NSLS(@"Send Messages", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBasics,
			@"wired.account.message.broadcast", NSLS(@"Broadcast Messages", @"Account field name"),
			@"TBD"),

		WCAccountFieldDictionary(WCAccountFieldFiles,
			@"wired.account.files", NSLS(@"Files Folder", @"Account field name"), WCAccountFieldString, NO, 
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.list_files", NSLS(@"List Files", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.search_files", NSLS(@"Search Files", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.get_info", NSLS(@"Get File Info", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.create_directories", NSLS(@"Create Folders", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.create_links", NSLS(@"Create Links", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.move_files", NSLS(@"Move Files", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.rename_files", NSLS(@"Rename Files", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.set_type", NSLS(@"Set Folder Type", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.set_comment", NSLS(@"Set Comments", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.set_permissions", NSLS(@"Set Permissions", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.set_executable", NSLS(@"Set Executable", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.set_label", NSLS(@"Set Label", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.delete_files", NSLS(@"Delete Files", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.file.access_all_dropboxes", NSLS(@"Access All Drop Boxes", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.transfer.download_files", NSLS(@"Download Files", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.transfer.upload_files", NSLS(@"Upload Files", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.transfer.upload_directories", NSLS(@"Upload Folders", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldFiles,
			@"wired.account.transfer.upload_anywhere", NSLS(@"Upload Anywhere", @"Account field name"),
			@"TBD"),

		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.read_boards", NSLS(@"Read Boards", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.add_boards", NSLS(@"Add Boards", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.move_boards", NSLS(@"Move Boards", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.rename_boards", NSLS(@"Rename Boards", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.delete_boards", NSLS(@"Delete Boards", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.set_permissions", NSLS(@"Set Board Permissions", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.add_threads", NSLS(@"Add Threads", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.move_threads", NSLS(@"Move Threads", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.delete_threads", NSLS(@"Delete Threads", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.add_posts", NSLS(@"Add Posts", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.edit_own_posts", NSLS(@"Edit Own Posts", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.edit_all_posts", NSLS(@"Edit All Posts", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.delete_own_posts", NSLS(@"Delete Own Posts", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldBoards,
			@"wired.account.board.delete_all_posts", NSLS(@"Delete All Posts", @"Account field name"),
			@"TBD"),
			  
		WCAccountFieldBooleanDictionary(WCAccountFieldTracker,
			@"wired.account.tracker.list_servers", NSLS(@"List Servers", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldTracker,
			@"wired.account.tracker.register_servers", NSLS(@"Register Servers", @"Account field name"),
			@"TBD"),

		WCAccountFieldBooleanDictionary(WCAccountFieldUsers,
			@"wired.account.chat.kick_users", NSLS(@"Kick Users", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldUsers,
			@"wired.account.user.disconnect_users", NSLS(@"Disconnect Users", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldUsers,
			@"wired.account.user.ban_users", NSLS(@"Ban Users", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldUsers,
			@"wired.account.user.cannot_be_disconnected", NSLS(@"Cannot Be Disconnected", @"Account field name"),
			@"TBD"),

		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.change_password", NSLS(@"Change Password", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.list_accounts", NSLS(@"List Accounts", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.read_accounts", NSLS(@"Read Accounts", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.create_users", NSLS(@"Create Users", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.edit_users", NSLS(@"Edit Users", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.delete_users", NSLS(@"Delete Users", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.create_groups", NSLS(@"Create Groups", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.edit_groups", NSLS(@"Edit Groups", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.delete_groups", NSLS(@"Delete Groups", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAccounts,
			@"wired.account.account.raise_account_privileges", NSLS(@"Raise Privileges", @"Account field name"),
			@"TBD"),
		
		WCAccountFieldBooleanDictionary(WCAccountFieldAdministration,
			@"wired.account.user.get_users", NSLS(@"Monitor Users", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAdministration,
			@"wired.account.log.view_log", NSLS(@"View Log", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAdministration,
			@"wired.account.settings.get_settings", NSLS(@"Read Settings", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAdministration,
			@"wired.account.settings.set_settings", NSLS(@"Edit Settings", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAdministration,
			@"wired.account.banlist.get_bans", NSLS(@"Read Banlist", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAdministration,
			@"wired.account.banlist.add_bans", NSLS(@"Add Bans", @"Account field name"),
			@"TBD"),
		WCAccountFieldBooleanDictionary(WCAccountFieldAdministration,
			@"wired.account.banlist.delete_bans", NSLS(@"Delete Bans", @"Account field name"),
			@"TBD"),

		WCAccountFieldNumberDictionary(WCAccountFieldLimits,
			@"wired.account.file.recursive_list_depth_limit", NSLS(@"Download Folder Depth", @"Account field name"),
			@"TBD"),
		WCAccountFieldNumberDictionary(WCAccountFieldLimits,
			@"wired.account.transfer.download_limit", NSLS(@"Concurrent Downloads", @"Account field name"),
			@"TBD"),
		WCAccountFieldNumberDictionary(WCAccountFieldLimits,
			@"wired.account.transfer.upload_limit", NSLS(@"Concurrent Uploads", @"Account field name"),
			@"TBD"),
		WCAccountFieldNumberDictionary(WCAccountFieldLimits,
			@"wired.account.transfer.download_speed_limit", NSLS(@"Download Speed (KB/s)", @"Account field name"),
			@"TBD"),
		WCAccountFieldNumberDictionary(WCAccountFieldLimits,
			@"wired.account.transfer.upload_speed_limit", NSLS(@"Upload Speed (KB/s)", @"Account field name"),
			@"TBD"),
		NULL];
	
	return fields;
}



#pragma mark -

+ (id)account {
	return [[[self alloc] init] autorelease];
}



+ (id)accountWithName:(NSString *)name {
	WCAccount		*account;
	
	account = [[self alloc] init];
	
	[account setValue:name forKey:@"wired.account.name"];
	
	return [account autorelease];
}



+ (id)accountWithMessage:(WIP7Message *)message {
	return [[[self alloc] _initWithMessage:message] autorelease];
}



- (id)init {
	self = [super init];
	
	_values = [[NSMutableDictionary alloc] init];
	
	return self;
}



- (void)dealloc {
	[_values release];
	
	[super dealloc];
}



#pragma mark -

- (NSUInteger)hash {
	return [[self newName] hash] + [[self name] hash];
}



- (BOOL)isEqual:(id)object {
	if(![object isKindOfClass:[self class]])
		return NO;
	
	if([[self name] isEqualToString:[object newName]])
		return YES;
	
	return [[self name] isEqualToString:[object name]];
}



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
	[self setValue:name forKey:@"wired.account.name"];
}



- (NSString *)name {
	return [self valueForKey:@"wired.account.name"];
}



- (void)setNewName:(NSString *)newName {
	[self setValue:newName forKey:@"wired.account.new_name"];
}



- (NSString *)newName {
	return [self valueForKey:@"wired.account.new_name"];
}



- (NSDate *)modificationDate {
	return [self valueForKey:@"wired.account.modification_time"];
}



- (NSDate *)creationDate {
	return [self valueForKey:@"wired.account.creation_time"];
}



- (NSString *)editedBy {
	return [self valueForKey:@"wired.account.edited_by"];
}



- (NSString *)files {
	return [self valueForKey:@"wired.account.files"];
}



- (BOOL)userCannotSetNick {
	return [[self valueForKey:@"wired.account.user.cannot_set_nick"] boolValue];
}



- (BOOL)userGetInfo {
	return [[self valueForKey:@"wired.account.user.get_info"] boolValue];
}



- (BOOL)userKickUsers {
	return [[self valueForKey:@"wired.account.user.kick_users"] boolValue];
}



- (BOOL)userBanUsers {
	return [[self valueForKey:@"wired.account.user.ban_users"] boolValue];
}



- (BOOL)userCannotBeDisconnected {
	return [[self valueForKey:@"wired.account.user.cannot_be_disconnected"] boolValue];
}



- (BOOL)userGetUsers {
	return [[self valueForKey:@"wired.account.user.get_users"] boolValue];
}



- (BOOL)chatSetTopic {
	return [[self valueForKey:@"wired.account.chat.set_topic"] boolValue];
}



- (BOOL)chatCreateChats {
	return [[self valueForKey:@"wired.account.chat.create_chats"] boolValue];
}



- (BOOL)messageSendMessages {
	return [[self valueForKey:@"wired.account.message.send_messages"] boolValue];
}



- (BOOL)messageBroadcast {
	return [[self valueForKey:@"wired.account.message.broadcast"] boolValue];
}



- (BOOL)boardReadBoards {
	return [[self valueForKey:@"wired.account.board.read_boards"] boolValue];
}



- (BOOL)boardAddBoards {
	return [[self valueForKey:@"wired.account.board.add_boards"] boolValue];
}



- (BOOL)boardMoveBoards {
	return [[self valueForKey:@"wired.account.board.move_boards"] boolValue];
}



- (BOOL)boardRenameBoards {
	return [[self valueForKey:@"wired.account.board.rename_boards"] boolValue];
}



- (BOOL)boardDeleteBoards {
	return [[self valueForKey:@"wired.account.board.delete_boards"] boolValue];
}



- (BOOL)boardSetPermissions {
	return [[self valueForKey:@"wired.account.board.set_permissions"] boolValue];
}



- (BOOL)boardAddThreads {
	return [[self valueForKey:@"wired.account.board.add_threads"] boolValue];
}



- (BOOL)boardMoveThreads {
	return [[self valueForKey:@"wired.account.board.move_threads"] boolValue];
}



- (BOOL)boardDeleteThreads {
	return [[self valueForKey:@"wired.account.board.delete_threads"] boolValue];
}



- (BOOL)boardAddPosts {
	return [[self valueForKey:@"wired.account.board.add_posts"] boolValue];
}



- (BOOL)boardEditOwnPosts {
	return [[self valueForKey:@"wired.account.board.edit_own_posts"] boolValue];
}



- (BOOL)boardEditAllPosts {
	return [[self valueForKey:@"wired.account.board.edit_all_posts"] boolValue];
}



- (BOOL)boardDeleteOwnPosts {
	return [[self valueForKey:@"wired.account.board.delete_own_posts"] boolValue];
}



- (BOOL)boardDeleteAllPosts {
	return [[self valueForKey:@"wired.account.board.delete_all_posts"] boolValue];
}



- (BOOL)fileListFiles {
	return [[self valueForKey:@"wired.account.file.list_files"] boolValue];
}



- (BOOL)fileGetInfo {
	return [[self valueForKey:@"wired.account.file.get_info"] boolValue];
}



- (BOOL)fileCreateDirectories {
	return [[self valueForKey:@"wired.account.file.create_directories"] boolValue];
}



- (BOOL)fileCreateLinks {
	return [[self valueForKey:@"wired.account.file.create_links"] boolValue];
}



- (BOOL)fileMoveFiles {
	return [[self valueForKey:@"wired.account.file.move_files"] boolValue];
}



- (BOOL)fileRenameFiles {
	return [[self valueForKey:@"wired.account.file.rename_files"] boolValue];
}



- (BOOL)fileSetType {
	return [[self valueForKey:@"wired.account.file.set_type"] boolValue];
}



- (BOOL)fileSetComment {
	return [[self valueForKey:@"wired.account.file.set_comment"] boolValue];
}



- (BOOL)fileSetPermissions {
	return [[self valueForKey:@"wired.account.file.set_permissions"] boolValue];
}



- (BOOL)fileSetExecutable {
	return [[self valueForKey:@"wired.account.file.set_executable"] boolValue];
}



- (BOOL)fileSetLabel {
	return [[self valueForKey:@"wired.account.file.set_label"] boolValue];
}



- (BOOL)fileDeleteFiles {
	return [[self valueForKey:@"wired.account.file.delete_files"] boolValue];
}



- (BOOL)fileAccessAllDropboxes {
	return [[self valueForKey:@"wired.account.file.access_all_dropboxes"] boolValue];
}



- (NSUInteger)fileRecursiveListDepthLimit {
	return [[self valueForKey:@"wired.account.file.recursive_list_depth_limit"] unsignedIntegerValue];
}



- (BOOL)transferDownloadFiles {
	return [[self valueForKey:@"wired.account.transfer.download_files"] boolValue];
}



- (BOOL)transferUploadFiles {
	return [[self valueForKey:@"wired.account.transfer.upload_files"] boolValue];
}



- (BOOL)transferUploadDirectories {
	return [[self valueForKey:@"wired.account.transfer.upload_directories"] boolValue];
}



- (BOOL)transferUploadAnywhere {
	return [[self valueForKey:@"wired.account.transfer.upload_anywhere"] boolValue];
}



- (NSUInteger)transferDownloadLimit {
	return [[self valueForKey:@"wired.account.transfer.download_limit"] unsignedIntegerValue];
}



- (NSUInteger)transferUploadLimit {
	return [[self valueForKey:@"wired.account.transfer.upload_limit"] unsignedIntegerValue];
}



- (NSUInteger)transferDownloadSpeedLimit {
	return [[self valueForKey:@"wired.account.transfer.download_speed_limit"] unsignedIntegerValue];
}



- (NSUInteger)transferUploadSpeedLimit {
	return [[self valueForKey:@"wired.account.transfer.upload_speed_limit"] unsignedIntegerValue];
}



- (BOOL)accountChangePassword {
	return [[self valueForKey:@"wired.account.account.change_password"] boolValue];
}



- (BOOL)accountListAccounts {
	return [[self valueForKey:@"wired.account.account.list_accounts"] boolValue];
}



- (BOOL)accountReadAccounts {
	return [[self valueForKey:@"wired.account.account.read_accounts"] boolValue];
}



- (BOOL)accountCreateUsers {
	return [[self valueForKey:@"wired.account.account.create_users"] boolValue];
}



- (BOOL)accountEditUsers {
	return [[self valueForKey:@"wired.account.account.edit_users"] boolValue];
}



- (BOOL)accountDeleteUsers {
	return [[self valueForKey:@"wired.account.account.delete_users"] boolValue];
}



- (BOOL)accountCreateGroups {
	return [[self valueForKey:@"wired.account.account.create_groups"] boolValue];
}



- (BOOL)accountEditGroups {
	return [[self valueForKey:@"wired.account.account.edit_groups"] boolValue];
}



- (BOOL)accountDeleteGroups {
	return [[self valueForKey:@"wired.account.account.delete_groups"] boolValue];
}



- (BOOL)accountRaiseAccountPrivileges {
	return [[self valueForKey:@"wired.account.account.raise_account_privileges"] boolValue];
}



- (BOOL)logViewLog {
	return [[self valueForKey:@"wired.account.log.view_log"] boolValue];
}



- (BOOL)settingsGetSettings {
	return [[self valueForKey:@"wired.account.settings.get_settings"] boolValue];
}



- (BOOL)settingsSetSettings {
	return [[self valueForKey:@"wired.account.settings.set_settings"] boolValue];
}



- (BOOL)banlistGetBans {
	return [[self valueForKey:@"wired.account.banlist.get_bans"] boolValue];
}



- (BOOL)banlistAddBans {
	return [[self valueForKey:@"wired.account.banlist.add_bans"] boolValue];
}



- (BOOL)banlistDeleteBans {
	return [[self valueForKey:@"wired.account.banlist.delete_bans"] boolValue];
}



- (BOOL)trackerListServers {
	return [[self valueForKey:@"wired.account.tracker.list_servers"] boolValue];
}



- (BOOL)trackerRegisterServers {
	return [[self valueForKey:@"wired.account.tracker.register_servers"] boolValue];
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



- (void)setValues:(NSDictionary *)values {
	[_values release];
	_values = [values mutableCopy];
}



- (NSDictionary *)values {
	return _values;
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

- (void)dealloc {
	[_groupAccount release];
	
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

- (void)setGroupAccount:(WCGroupAccount *)account {
	[account retain];
	[_groupAccount release];
	
	_groupAccount = account;
}



- (WCGroupAccount *)groupAccount {
	return _groupAccount;
}



#pragma mark -

- (NSDate *)loginDate {
	return [self valueForKey:@"wired.account.login_time"];
}



- (NSUInteger)downloads {
	return [[self valueForKey:@"wired.account.downloads"] unsignedIntegerValue];
}



- (WIFileOffset)downloadTransferred {
	return [[self valueForKey:@"wired.account.download_transferred"] unsignedLongLongValue];
}



- (NSUInteger)uploads {
	return [[self valueForKey:@"wired.account.uploads"] unsignedIntegerValue];
}



- (WIFileOffset)uploadTransferred {
	return [[self valueForKey:@"wired.account.upload_transferred"] unsignedLongLongValue];
}



- (void)setFullName:(NSString *)fullName {
	[self setValue:fullName forKey:@"wired.account.full_name"];
}



- (NSString *)fullName {
	return [self valueForKey:@"wired.account.full_name"];
}



- (void)setGroup:(NSString *)group {
	[self setValue:group forKey:@"wired.account.group"];
}



- (NSString *)group {
	return [self valueForKey:@"wired.account.group"];
}



- (void)setGroups:(NSArray *)groups {
	[self setValue:groups forKey:@"wired.account.groups"];
}



- (NSArray *)groups {
	return [self valueForKey:@"wired.account.groups"];
}



- (void)setPassword:(NSString *)password {
	[self setValue:password forKey:@"wired.account.password"];
}



- (NSString *)password {
	return [self valueForKey:@"wired.account.password"];
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
