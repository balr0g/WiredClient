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
#import "WCAccounts.h" 
#import "WCApplicationController.h" 
#import "WCChat.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCStats.h"
#import "WCTopic.h"
#import "WCUser.h"
#import "WCUserCell.h"
#import "WCUserInfo.h"

#define WCPublicChatID					1

#define WCLastChatFormat				@"WCLastChatFormat"
#define WCLastChatEncoding				@"WCLastChatEncoding"

#define WCChatPrepend					13
#define WCChatLimit						4096


enum _WCChatFormat {
	WCChatPlainText,
	WCChatRTF,
	WCChatRTFD,
};
typedef enum _WCChatFormat				WCChatFormat;


@interface WCChat(Private)

- (void)_update;
- (void)_updateSaveChatForPanel:(NSSavePanel *)savePanel;

- (void)_setTopic:(WCTopic *)topic;
- (void)_updateTopic;

- (void)_printString:(NSString *)message;
- (void)_printTimestamp;
- (void)_printTopic;
- (void)_printUserJoin:(WCUser *)user;
- (void)_printUserLeave:(WCUser *)user;
- (void)_printUserChange:(WCUser *)user nick:(NSString *)nick;
- (void)_printUserChange:(WCUser *)user status:(NSString *)status;
- (void)_printUserKick:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message;
- (void)_printUserBan:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message;
- (void)_printChat:(NSString *)chat by:(WCUser *)user;
- (void)_printActionChat:(NSString *)chat by:(WCUser *)user;

- (NSArray *)_commands;
- (BOOL)_runCommand:(NSString *)command;

- (NSString *)_stringByCompletingString:(NSString *)string;
- (NSString *)_stringByDecomposingAttributedString:(NSAttributedString *)attributedString;

- (BOOL)_isHighlightedChat:(NSString *)chat;

@end


@implementation WCChat(Private)

- (void)_update {
/*	NSFont		*font;
	NSColor		*color;
	
	return;
	
	font = [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatFont]];

	if(![[_chatOutputTextView font] isEqualTo:font]) {
		[_chatOutputTextView setFont:font];
		[_chatInputTextView setFont:font];
		[_setTopicTextView setFont:font];
	}
	
	color = [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatBackgroundColor]];

	if(![[_chatOutputTextView backgroundColor] isEqualTo:color]) {
		[_chatOutputTextView setBackgroundColor:color];
		[_chatInputTextView setBackgroundColor:color];
		[_setTopicTextView setBackgroundColor:color];
	}

	color = [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatTextColor]];

	if(![[_chatOutputTextView textColor] isEqualTo:color]) {
		[_chatOutputTextView setTextColor:color];
		[_chatInputTextView setTextColor:color];
		[_chatInputTextView setInsertionPointColor:color];
		[_setTopicTextView setTextColor:color];
		[_setTopicTextView setInsertionPointColor:color];

		[_chatOutputTextView setString:[_chatOutputTextView string] withFilter:_chatFilter];
	}
	
	[_chatOutputTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatURLsColor]],
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];

	[_userListTableView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatUserListFont]]];
	[_userListTableView setUsesAlternatingRowBackgroundColors:[WCSettings boolForKey:WCChatUserListAlternateRows]];
	
	switch([WCSettings intForKey:WCChatUserListIconSize]) {
		case WCChatUserListIconSizeLarge:
			[_userListTableView setRowHeight:35.0];
			
			[[_nickTableColumn dataCell] setControlSize:NSRegularControlSize];
			break;

		case WCChatUserListIconSizeSmall:
			[_userListTableView setRowHeight:17.0];

			[[_nickTableColumn dataCell] setControlSize:NSSmallControlSize];
			break;
	}
	
	[_chatOutputTextView setNeedsDisplay:YES];
	[_chatInputTextView setNeedsDisplay:YES];
	[_setTopicTextView setNeedsDisplay:YES];
	[_userListTableView setNeedsDisplay:YES];*/
}



- (void)_updateSaveChatForPanel:(NSSavePanel *)savePanel {
	WCChatFormat		format;
	
	format = [_saveChatFileFormatPopUpButton tagOfSelectedItem];
	
	switch(format) {
		case WCChatPlainText:
			[savePanel setRequiredFileType:@"txt"];
			break;
			
		case WCChatRTF:
			[savePanel setRequiredFileType:@"rtf"];
			break;

		case WCChatRTFD:
			[savePanel setRequiredFileType:@"rtfd"];
			break;
	}

	[_saveChatPlainTextEncodingPopUpButton setEnabled:(format == WCChatPlainText)];
}



#pragma mark -

- (void)_setTopic:(WCTopic *)topic {
	[topic retain];
	[_topic release];
	
	_topic = topic;
	
	[self _updateTopic];
}



- (void)_updateTopic {
	NSMutableAttributedString	*string;
	
	if([[_topic topic] length] > 0) {
		string = [NSMutableAttributedString attributedStringWithString:[_topic topic]];
		
		[_topicTextField setToolTip:[_topic topic]];
		[_topicTextField setAttributedStringValue:[string attributedStringByApplyingFilter:_topicFilter]];
		[_topicNickTextField setStringValue:[NSSWF:
			NSLS(@"%@ %C %@", @"Chat topic set by (nick, time)"),
			[_topic nick],
			0x2014,
			[_topicDateFormatter stringFromDate:[_topic date]]]];
	} else {
		[_topicTextField setToolTip:NULL];
		[_topicTextField setStringValue:@""];
		[_topicNickTextField setStringValue:@""];
	}
}



#pragma mark -

- (void)_printString:(NSString *)string {
	float		position;
	
	position = [[_chatOutputScrollView verticalScroller] floatValue];
	
	if([[_chatOutputTextView textStorage] length] > 0)
		[[[_chatOutputTextView textStorage] mutableString] appendString:@"\n"];
	
	[_chatOutputTextView appendString:string withFilter:_chatFilter];
	
	if(position == 1.0)
		[_chatOutputTextView performSelectorOnce:@selector(scrollToBottom) withObject:NULL afterDelay:0.05];
}



- (void)_printTimestamp {
	NSDate			*date;
	NSTimeInterval	interval;
	
	if(!_timestamp)
		_timestamp = [[NSDate date] retain];
	
	interval = [[WCSettings objectForKey:WCChatTimestampChatInterval] doubleValue];
	date = [NSDate dateWithTimeIntervalSinceNow:-interval];
	
	if([date compare:_timestamp] == NSOrderedDescending) {
		[self printEvent:[_timestampDateFormatter stringFromDate:[NSDate date]]];
		
		[_timestamp release];
		_timestamp = [[NSDate date] retain];
	}
}



- (void)_printTopic {
	[self printEvent:[NSSWF:
		NSLS(@"%@ changed topic to %@", @"Topic changed (nick, topic)"),
		[_topic nick], [_topic topic]]];
}



- (void)_printUserJoin:(WCUser *)user {
	[self printEvent:[NSSWF:
		NSLS(@"%@ has joined", @"Client has joined message (nick)"),
		[user nick]]];
}



- (void)_printUserLeave:(WCUser *)user {
	[self printEvent:[NSSWF:
		NSLS(@"%@ has left", @"Client has left message (nick)"),
		[user nick]]];
}



- (void)_printUserChange:(WCUser *)user nick:(NSString *)nick {
	[self printEvent:[NSSWF:
		NSLS(@"%@ is now known as %@", @"Client rename message (oldnick, newnick)"),
		[user nick],
		nick]];
}



- (void)_printUserChange:(WCUser *)user status:(NSString *)status {
	[self printEvent:[NSSWF:
		NSLS(@"%@ changed status to %@", @"Client status changed message (nick, status)"),
		[user nick],
		status]];
}



- (void)_printUserKick:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message {
	if([message length] > 0) {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was kicked by %@ (%@)", @"Client kicked message (victim, killer, message)"),
			[victim nick],
			[killer nick],
			message]];
	} else {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was kicked by %@", @"Client kicked message (victim, killer)"),
			[victim nick],
			[killer nick]]];
	}
}



- (void)_printUserBan:(WCUser *)victim by:(WCUser *)killer message:(NSString *)message {
	if([message length] > 0) {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was banned by %@ (%@)", @"Client banned message (victim, killer, message)"),
			[victim nick],
			[killer nick],
			message]];
	} else {
		[self printEvent:[NSSWF:
			NSLS(@"%@ was banned by %@", @"Client banned message (victim, killer)"),
			[victim nick],
			[killer nick]]];
	}
}



- (void)_printChat:(NSString *)chat by:(WCUser *)user {
	NSString	*output, *nick;
	NSInteger	offset, length;
	
	offset = [WCSettings boolForKey:WCChatTimestampEveryLine] ? WCChatPrepend - 4 : WCChatPrepend;
	nick = [user nick];
	length = offset - [nick length];

	if(length < 0)
		nick = [nick substringToIndex:offset];
	
	output = [NSSWF:NSLS(@"%@: %@", @"Chat message, Wired style (nick, message)"),
		nick, chat];
	
	if(length > 0)
		output = [NSSWF:@"%*s%@", length, " ", output];
	
	if([WCSettings boolForKey:WCChatTimestampEveryLine])
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];

	[self _printString:output];
}



- (void)_printActionChat:(NSString *)chat by:(WCUser *)user {
	NSString	*output;

	output = [NSSWF:NSLS(@" *** %@ %@", @"Action chat message, Wired style (nick, message)"),
		[user nick], chat];

	if([WCSettings boolForKey:WCChatTimestampEveryLine])
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];
	
	[self _printString:output];
}



#pragma mark -

- (NSArray *)_commands {
	return [NSArray arrayWithObjects:
		@"/me",
		@"/exec",
		@"/nick",
		@"/status",
		@"/stats",
		@"/clear",
		@"/topic",
		@"/broadcast",
		@"/ping",
		NULL];
}



- (BOOL)_runCommand:(NSString *)string {
	NSString		*command, *argument;
	WIP7Message		*message;
	NSRange			range;
	NSUInteger		transaction;
	
	range = [string rangeOfString:@" "];
	
	if(range.location == NSNotFound) {
		command = string;
		argument = @"";
	} else {
		command = [string substringToIndex:range.location];
		argument = [string substringFromIndex:range.location + 1];
	}
	
	if([command isEqualToString:@"/me"] && [argument length] > 0) {
		if([argument length] > WCChatLimit)
			argument = [argument substringToIndex:WCChatLimit];
		
		message = [WIP7Message messageWithName:@"wired.chat.send_me" spec:WCP7Spec];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:argument forName:@"wired.chat.me"];
		[[self connection] sendMessage:message];
		
		[[WCStats stats] addUnsignedLongLong:[argument length] forKey:WCStatsChat];
		
		return YES;
	}
	else if([command isEqualToString:@"/exec"] && [argument length] > 0) {
		NSString			*output;
		
		output = [[self class] outputForShellCommand:argument];
		
		if(output && [output length] > 0) {
			if([output length] > WCChatLimit)
				output = [output substringToIndex:WCChatLimit];
			
			message = [WIP7Message messageWithName:@"wired.chat.send_say" spec:WCP7Spec];
			[message setUInt32:[self chatID] forName:@"wired.chat.id"];
			[message setString:output forName:@"wired.chat.say"];
			[[self connection] sendMessage:message];
		}
		
		return YES;
	}
	else if(([command isEqualToString:@"/nick"] ||
			 [command isEqualToString:@"/n"]) && [argument length] > 0) {
		message = [WIP7Message messageWithName:@"wired.user.set_nick" spec:WCP7Spec];
		[message setString:argument forName:@"wired.user.nick"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/status"] || [command isEqualToString:@"/s"]){
		message = [WIP7Message messageWithName:@"wired.user.set_status" spec:WCP7Spec];
		[message setString:argument forName:@"wired.user.status"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/stats"]) {
		[self stats:self];
		
		return YES;
	}
	else if([command isEqualToString:@"/clear"]) {
		[[[_chatOutputTextView textStorage] mutableString] setString:@""];
		
		return YES;
	}
	else if([command isEqualToString:@"/topic"]) {
		message = [WIP7Message messageWithName:@"wired.chat.set_topic" spec:WCP7Spec];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:argument forName:@"wired.chat.topic.topic"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/broadcast"] && [argument length] > 0) {
		message = [WIP7Message messageWithName:@"wired.message.send_broadcast" spec:WCP7Spec];
		[message setString:argument forName:@"wired.message.broadcast"];
		[[self connection] sendMessage:message];
		
		return YES;
	}
	else if([command isEqualToString:@"/ping"]) {
		message = [WIP7Message messageWithName:@"wired.send_ping" spec:WCP7Spec];
		transaction = [[self connection] sendMessage:message fromObserver:self selector:@selector(wiredSendPingReply:)];

		[_pings setObject:[NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]]
				   forKey:[NSNumber numberWithUnsignedInt:transaction]];
		
		return YES;
	}

	return NO;
}



#pragma mark -

- (NSString *)_stringByCompletingString:(NSString *)string {
	NSEnumerator	*enumerator, *setEnumerator;
	NSArray			*nicks, *commands, *set, *matchingSet = NULL;
	NSString		*match, *prefix = NULL;
	NSUInteger		matches = 0;
	
	nicks = [self nicks];
	commands = [self _commands];
	enumerator = [[NSArray arrayWithObjects:nicks, commands, NULL] objectEnumerator];
	
	while((set = [enumerator nextObject])) {
		setEnumerator = [set objectEnumerator];
		
		while((match = [setEnumerator nextObject])) {
			if([match rangeOfString:string options:NSCaseInsensitiveSearch].location == 0) {
				if(matches == 0) {
					prefix = match;
					matches = 1;
				} else {
					prefix = [prefix commonPrefixWithString:match options:NSCaseInsensitiveSearch];
				
					if([prefix length] < [match length])
						matches++;
				}
				
				matchingSet = set;
			}
		}
	}
	
	if(matches > 1)
		return prefix;

	if(matches == 1) {
		if(matchingSet == nicks) {
			return [prefix stringByAppendingString:
				[WCSettings objectForKey:WCChatTabCompleteNicksString]];
		}
		else if(matchingSet == commands) {
			return [prefix stringByAppendingString:@" "];
		}
	}
	
	return string;
}



- (NSString *)_stringByDecomposingAttributedString:(NSAttributedString *)attributedString {
	if(![attributedString containsAttachments])
		return [attributedString string];
	
	return [[attributedString attributedStringByReplacingAttachmentsWithStrings] string];
}



#pragma mark -

- (BOOL)_isHighlightedChat:(NSString *)chat {
	NSEnumerator		*enumerator;
	NSDictionary		*highlight;
	
	enumerator = [[WCSettings objectForKey:WCHighlights] objectEnumerator];
	
	while((highlight = [enumerator nextObject])) {
		if([chat rangeOfString:[highlight objectForKey:WCHighlightsPattern] options:NSCaseInsensitiveSearch].location != NSNotFound)
			return YES;
	}
	
	return NO;
}

@end


@implementation WCChat

+ (NSString *)outputForShellCommand:(NSString *)command {
	NSTask				*task;
	NSPipe				*pipe;
	NSFileHandle		*fileHandle;
	NSDictionary		*environment;
	NSData				*data;
	double				timeout = 5.0;
	
	pipe = [NSPipe pipe];
	fileHandle = [pipe fileHandleForReading];
	
	environment	= [NSDictionary dictionaryWithObject:@"/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"
											  forKey:@"PATH"];
	
	task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", command, NULL]];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
	[task setEnvironment:environment];
	[task launch];
	
	while([task isRunning]) {
		usleep(100000);
		timeout -= 0.1;
		
		if(timeout <= 0.0) {
			[task terminate];
			
			break;
		}
	}
	
	data = [fileHandle readDataToEndOfFile];
	
	return [NSString stringWithData:data encoding:NSUTF8StringEncoding];
}



#pragma mark -

+ (id)allocWithZone:(NSZone *)zone {
	if([self isEqual:[WCChat class]]) {
		NSLog(@"*** -[%@ allocWithZone:]: attempt to instantiate abstract class", self);

		return NULL;
	}

	return [super allocWithZone:zone];
}



- (id)initChatWithConnection:(WCServerConnection *)connection windowNibName:(NSString *)windowNibName name:(NSString *)name singleton:(BOOL)singleton {
	self = [super initWithWindowNibName:windowNibName name:name connection:connection singleton:singleton];

	_commandHistory = [[NSMutableArray alloc] init];
	_users			= [[NSMutableDictionary alloc] init];
	_allUsers		= [[NSMutableArray alloc] init];
	_shownUsers		= [[NSMutableArray alloc] init];
	_pings			= [[NSMutableDictionary alloc] init];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(dateDidChange:)
			   name:WCDateDidChangeNotification];

	[[self connection] addObserver:self
						  selector:@selector(chatUsersDidChange:)
							  name:WCChatUsersDidChangeNotification];

	[[self connection] addObserver:self selector:@selector(wiredChatUserJoin:) messageName:@"wired.chat.user_join"];
	[[self connection] addObserver:self selector:@selector(wiredChatUserLeave:) messageName:@"wired.chat.user_leave"];
	[[self connection] addObserver:self selector:@selector(wiredChatTopic:) messageName:@"wired.chat.topic"];
	[[self connection] addObserver:self selector:@selector(wiredChatSayOrMe:) messageName:@"wired.chat.say"];
	[[self connection] addObserver:self selector:@selector(wiredChatSayOrMe:) messageName:@"wired.chat.me"];
	[[self connection] addObserver:self selector:@selector(wiredChatUserKick:) messageName:@"wired.chat.user_kick"];
	[[self connection] addObserver:self selector:@selector(wiredUserStatus:) messageName:@"wired.user.status"];
	[[self connection] addObserver:self selector:@selector(wiredUserIcon:) messageName:@"wired.user.icon"];
	[[self connection] addObserver:self selector:@selector(wiredUserUserBan:) messageName:@"wired.user.user_ban"];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_saveChatView release];
	
	[_users release];
	[_allUsers release];
	[_shownUsers release];

	[_commandHistory release];

	[_chatFilter release];
	[_topicFilter release];
	[_timestamp release];
	[_topic release];
	
	[_timestampDateFormatter release];
	[_timestampEveryLineDateFormatter release];
	[_topicDateFormatter release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[_chatOutputTextView setEditable:NO];
	[_chatOutputTextView setUsesFindPanel:YES];
	[_userListTableView setDoubleAction:@selector(sendPrivateMessage:)];

	_chatFilter = [[WITextFilter alloc] initWithSelectors:@selector(filterWiredChat:), @selector(filterURLs:), @selector(filterWiredSmilies:), 0];
	_topicFilter = [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmallSmilies:), 0];

	_timestampDateFormatter = [[WIDateFormatter alloc] init];
	[_timestampDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_timestampDateFormatter setDateStyle:NSDateFormatterShortStyle];
	
	_timestampEveryLineDateFormatter = [[WIDateFormatter alloc] init];
	[_timestampEveryLineDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	_topicDateFormatter = [[WIDateFormatter alloc] init];
	[_topicDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_topicDateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_topicDateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _update];
	
	[super windowDidLoad];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_userListTableView setDataSource:NULL];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[super windowTemplateShouldLoad:windowTemplate];

	[_userListSplitView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCChatUserListSplitView"]];
	[_chatSplitView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCChatSplitView"]];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[_userListSplitView propertiesDictionary] forKey:@"WCChatUserListSplitView"];
	[windowTemplate setObject:[_chatSplitView propertiesDictionary] forKey:@"WCChatSplitView"];
	
	[super windowTemplateShouldSave:windowTemplate];
}



- (void)themeDidChange:(NSDictionary *)theme {
	NSFont		*font;
	NSColor		*color;
	
	font = WIFontFromString([theme objectForKey:WCThemesChatFont]);

	if(![[_chatOutputTextView font] isEqualTo:font]) {
		[_chatOutputTextView setFont:font];
		[_chatInputTextView setFont:font];
		[_setTopicTextView setFont:font];
	}
	
	color = WIColorFromString([theme objectForKey:WCThemesChatBackgroundColor]);

	if(![[_chatOutputTextView backgroundColor] isEqualTo:color]) {
		[_chatOutputTextView setBackgroundColor:color];
		[_chatInputTextView setBackgroundColor:color];
		[_setTopicTextView setBackgroundColor:color];
	}

	color = WIColorFromString([theme objectForKey:WCThemesChatTextColor]);

	if(![[_chatOutputTextView textColor] isEqualTo:color]) {
		[_chatOutputTextView setTextColor:color];
		[_chatInputTextView setTextColor:color];
		[_chatInputTextView setInsertionPointColor:color];
		[_setTopicTextView setTextColor:color];
		[_setTopicTextView setInsertionPointColor:color];

		[_chatOutputTextView setString:[_chatOutputTextView string] withFilter:_chatFilter];
	}
	
	[_chatOutputTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		WIColorFromString([theme objectForKey:WCThemesChatURLsColor]),
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];

//	[_userListTableView setFont: [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatUserListFont]]];
	[_userListTableView setUsesAlternatingRowBackgroundColors:[[theme objectForKey:WCThemesUserListAlternateRows] boolValue]];
	
	switch([[theme objectForKey:WCThemesUserListIconSize] integerValue]) {
		case WCThemesUserListIconSizeLarge:
			[_userListTableView setRowHeight:35.0];
			
			[[_nickTableColumn dataCell] setControlSize:NSRegularControlSize];
			break;

		case WCThemesUserListIconSizeSmall:
			[_userListTableView setRowHeight:17.0];

			[[_nickTableColumn dataCell] setControlSize:NSSmallControlSize];
			break;
	}
	
	[_chatOutputTextView setNeedsDisplay:YES];
	[_chatInputTextView setNeedsDisplay:YES];
	[_setTopicTextView setNeedsDisplay:YES];
	[_userListTableView setNeedsDisplay:YES];
}



- (void)serverConnectionThemeDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	if([[self connection] isReconnecting])
		[self _setTopic:NULL];
	
	[super serverConnectionServerInfoDidChange:notification];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	[_users removeAllObjects];
	[_shownUsers removeAllObjects];
	[_userListTableView reloadData];

	[super linkConnectionLoggedIn:notification];
}



- (void)wiredSendPingReply:(WIP7Message *)message {
	NSNumber			*number;
	NSTimeInterval		interval;
	NSUInteger			transaction;
	
	[message getUInt32:&transaction forName:@"wired.transaction"];

	number = [_pings objectForKey:[NSNumber numberWithUnsignedInt:transaction]];
	
	if(number) {
		interval = [NSDate timeIntervalSinceReferenceDate] - [number doubleValue];

		[self printEvent:[NSSWF:
			NSLS(@"Received ping reply after %.2fms", @"Ping received message (interval)"),
			interval * 1000.0]];
		
		[_pings removeObjectForKey:number];
	}
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)dateDidChange:(NSNotification *)notification {
	[self _updateTopic];
}



- (void)chatUsersDidChange:(NSNotification *)notification {
	[_userListTableView reloadData];
}



- (void)wiredChatJoinChatReply:(WIP7Message *)message {
	WCUser			*user;
	WCTopic			*topic;
	NSUInteger		i, count;
	
	if([[message name] isEqualToString:@"wired.chat.user_list"]) {
		user = [WCUser userWithMessage:message connection:[self connection]];

		[_allUsers addObject:user];
		[_users setObject:user forKey:[NSNumber numberWithUnsignedInt:[user userID]]];
	}
	else if([[message name] isEqualToString:@"wired.chat.user_list.done"]) {
		[_shownUsers addObjectsFromArray:_allUsers];
		[_allUsers removeAllObjects];
		
		count = [_shownUsers count];
		
		for(i = 0; i < count; i++)
			[[self connection] postNotificationName:WCChatUserAppearedNotification object:[_shownUsers objectAtIndex:i]];

		_receivedUserList = YES;
		
		[[self connection] postNotificationName:WCChatUsersDidChangeNotification object:[self connection]];
	}
	else if([[message name] isEqualToString:@"wired.chat.topic"]) {
		topic = [WCTopic topicWithMessage:message];
		
		[self _setTopic:topic];
	}
}



- (void)wiredChatUserJoin:(WIP7Message *)message {
	WCUser			*user;
	WIP7UInt32		cid;
	
	if(!_receivedUserList)
		return;

	[message getUInt32:&cid forName:@"wired.chat.id"];

	if(cid != [self chatID])
		return;

	user = [WCUser userWithMessage:message connection:[self connection]];
	
	[_shownUsers addObject:user];
	[_users setObject:user forKey:[NSNumber numberWithUnsignedInt:[user userID]]];

	if([[WCSettings eventWithTag:WCEventsUserJoined] boolForKey:WCEventsPostInChat])
		[self _printUserJoin:user];
	
	[[self connection] postNotificationName:WCChatUserAppearedNotification object:user];
	[[self connection] postNotificationName:WCChatUsersDidChangeNotification object:[self connection]];

	[[self connection] triggerEvent:WCEventsUserJoined info1:user];
}



- (void)wiredChatUserLeave:(WIP7Message *)message {
	WCUser			*user;
	WIP7UInt32		cid, uid;

	[message getUInt32:&cid forName:@"wired.chat.id"];

	if(cid != WCPublicChatID && cid != [self chatID])
		return;

	[message getUInt32:&uid forName:@"wired.user.id"];

	user = [self userWithUserID:uid];
	
	if(!user)
		return;

	if([[WCSettings eventWithTag:WCEventsUserLeft] boolForKey:WCEventsPostInChat])
		[self _printUserLeave:user];

	[[self connection] triggerEvent:WCEventsUserLeft info1:user];
	[[self connection] postNotificationName:WCChatUserDisappearedNotification object:user];

	[_shownUsers removeObject:user];
	[_users removeObjectForKey:[NSNumber numberWithUnsignedInt:[user userID]]];
	
	[[self connection] postNotificationName:WCChatUsersDidChangeNotification object:[self connection]];
}



- (void)wiredChatTopic:(WIP7Message *)message {
	WCTopic		*topic;
	
	topic = [WCTopic topicWithMessage:message];
	
	if([topic chatID] != [self chatID])
		return;
	
	[self _setTopic:topic];
	
	if([[_topic topic] length] > 0)
		[self _printTopic];
}



- (void)wiredChatSayOrMe:(WIP7Message *)message {
	NSString		*name, *chat;
	WCUser			*user;
	WIP7UInt32		cid, uid;

	[message getUInt32:&cid forName:@"wired.chat.id"];
	[message getUInt32:&uid forName:@"wired.user.id"];

	if(cid != [self chatID])
		return;

	user = [self userWithUserID:uid];

	if(!user || [user isIgnored])
		return;

	if([WCSettings boolForKey:WCChatTimestampChat])
		[self _printTimestamp];

	name = [message name];
	chat = [message stringForName:name];
	
	if([name isEqualToString:@"wired.chat.say"])
		[self _printChat:chat by:user];
	else
		[self _printActionChat:chat by:user];
	
	if([self _isHighlightedChat:chat])
		[[self connection] triggerEvent:WCEventsHighlightedChatReceived info1:user info2:chat];
	else
		[[self connection] triggerEvent:WCEventsChatReceived info1:user info2:chat];
}



- (void)wiredChatUserKick:(WIP7Message *)message {
	NSString		*disconnectMessage;
	WIP7UInt32		killerUserID, victimUserID;
	WCUser			*killer, *victim;
	WIP7UInt32		cid;
	
	if(![message getUInt32:&cid forName:@"wired.chat.id"])
		cid = WCPublicChatID;
	
	if(cid != WCPublicChatID && cid != [self chatID])
		return;
	
	[message getUInt32:&killerUserID forName:@"wired.user.id"];
	[message getUInt32:&victimUserID forName:@"wired.user.disconnected_id"];

	killer = [self userWithUserID:killerUserID];
	victim = [self userWithUserID:victimUserID];

	if(!killer || !victim)
		return;

	disconnectMessage = [message stringForName:@"wired.user.disconnect_message"];
	
	[self _printUserKick:victim by:killer message:disconnectMessage];
	
	if(cid == WCPublicChatID && [victim userID] == [[self connection] userID])
		[[self connection] postNotificationName:WCChatSelfWasKickedNotification object:[self connection]];

	[[self connection] postNotificationName:WCChatUserDisappearedNotification object:victim];

	[_shownUsers removeObject:victim];
	[_users removeObjectForKey:[NSNumber numberWithInt:victimUserID]];
	
	[[self connection] postNotificationName:WCChatUsersDidChangeNotification object:[self connection]];
}



- (void)wiredUserStatus:(WIP7Message *)message {
	NSString		*nick, *status;
	WCUser			*user;
	WIP7UInt32		uid;
	WIP7Bool		idle, admin;

	[message getUInt32:&uid forName:@"wired.user.id"];

	user = [self userWithUserID:uid];

	if(!user)
		return;

	[message getBool:&idle forName:@"wired.user.idle"];
	[message getBool:&admin forName:@"wired.user.admin"];
	nick = [message stringForName:@"wired.user.nick"];
	status = [message stringForName:@"wired.user.status"];

	if(![nick isEqualToString:[user nick]]) {
		if([[WCSettings eventWithTag:WCEventsUserChangedNick] boolForKey:WCEventsPostInChat])
			[self _printUserChange:user nick:nick];

		[[self connection] triggerEvent:WCEventsUserChangedNick info1:user info2:nick];
	}

	if(![status isEqualToString:[user status]]) {
		if([[WCSettings eventWithTag:WCEventsUserChangedStatus] boolForKey:WCEventsPostInChat])
			[self _printUserChange:user status:status];
		
		[[self connection] triggerEvent:WCEventsUserChangedStatus info1:user info2:status];
	}
	
	[user setNick:nick];
	[user setStatus:status];
	[user setIdle:idle];
	[user setAdmin:admin];

	[_userListTableView setNeedsDisplay:YES];
}



- (void)wiredUserIcon:(WIP7Message *)message {
	NSImage			*image;
	WCUser			*user;
	WIP7UInt32		uid;

	[message getUInt32:&uid forName:@"wired.user.id"];

	user = [self userWithUserID:uid];

	if(!user)
		return;

	image = [[NSImage alloc] initWithData:[message dataForName:@"wired.user.icon"]];
	[user setIcon:image];
	[image release];

	[_userListTableView setNeedsDisplay:YES];
}



- (void)wiredUserUserBan:(WIP7Message *)message {
	NSString		*disconnectMessage;
	WIP7UInt32		killerUserID, victimUserID;
	WCUser			*killer, *victim;
	
	[message getUInt32:&killerUserID forName:@"wired.user.id"];
	[message getUInt32:&victimUserID forName:@"wired.user.disconnected_id"];

	killer = [self userWithUserID:killerUserID];
	victim = [self userWithUserID:victimUserID];

	if(!killer || !victim)
		return;

	disconnectMessage = [message stringForName:@"wired.user.disconnect_message"];
	
	[self _printUserBan:victim by:killer message:disconnectMessage];
	
	if([victim userID] == [[self connection] userID])
		[[self connection] postNotificationName:WCChatSelfWasBannedNotification object:[self connection]];

	[[self connection] postNotificationName:WCChatUserDisappearedNotification object:victim];

	[_shownUsers removeObject:victim];
	[_users removeObjectForKey:[NSNumber numberWithInt:victimUserID]];
	
	[[self connection] postNotificationName:WCChatUsersDidChangeNotification object:[self connection]];
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	if(splitView == _userListSplitView)
		return proposedMin + 50.0;
	else if(splitView == _chatSplitView)
		return proposedMin + 15.0;

	return proposedMin;
}



- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
	if(splitView == _userListSplitView) {
		NSSize		size, rightSize, leftSize;

		size = [_userListSplitView frame].size;
		rightSize = [_userListView frame].size;
		rightSize.height = size.height;
		leftSize.height = size.height;
		leftSize.width = size.width - [_userListSplitView dividerThickness] - rightSize.width;

		[_chatView setFrameSize:leftSize];
		[_userListView setFrameSize:rightSize];
	}
	else if(splitView == _chatSplitView) {
		NSSize		size, bottomSize, topSize;

		size = [_chatSplitView frame].size;
		bottomSize = [_chatInputScrollView frame].size;
		bottomSize.width = size.width;
		topSize.width = size.width;
		topSize.height = size.height - [_chatSplitView dividerThickness] - bottomSize.height;

		[_chatOutputScrollView setFrameSize:topSize];
		[_chatInputScrollView setFrameSize:bottomSize];
	}

	[splitView adjustSubviews];
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return YES;
}



- (BOOL)topicTextView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	if(selector == @selector(insertNewline:)) {
		if([[NSApp currentEvent] character] == NSEnterCharacter) {
			[self submitSheet:textView];
			
			return YES;
		}
	}
	
	return NO;
}



- (BOOL)chatTextView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	WIP7Message		*message;
	NSInteger		historyModifier;
	BOOL			commandKey, optionKey, controlKey, historyScrollback;

	commandKey	= [[NSApp currentEvent] commandKeyModifier];
	optionKey	= [[NSApp currentEvent] alternateKeyModifier];
	controlKey	= [[NSApp currentEvent] controlKeyModifier];

	historyScrollback = [WCSettings boolForKey:WCChatHistoryScrollback];
	historyModifier = [WCSettings integerForKey:WCChatHistoryScrollbackModifier];
	
	// --- user pressed the return/enter key
	if(selector == @selector(insertNewline:) ||
	   selector == @selector(insertNewlineIgnoringFieldEditor:)) {
		NSString		*string;
		NSUInteger		length;

		string = [self _stringByDecomposingAttributedString:[_chatInputTextView textStorage]];
		length = [string length];
		
		if(length == 0)
			return YES;

		if(length > WCChatLimit)
			string = [string substringToIndex:WCChatLimit];
		
		[_commandHistory addObject:[[string copy] autorelease]];
		_currentCommand = [_commandHistory count];
		
		if(![string hasPrefix:@"/"] || ![self _runCommand:string]) {
			if(selector == @selector(insertNewlineIgnoringFieldEditor:) ||
			   (selector == @selector(insertNewline:) && optionKey)) {
				message = [WIP7Message messageWithName:@"wired.chat.send_me" spec:WCP7Spec];
				[message setString:string forName:@"wired.chat.me"];
			} else {
				message = [WIP7Message messageWithName:@"wired.chat.send_say" spec:WCP7Spec];
				[message setString:string forName:@"wired.chat.say"];
			}
			
			[message setUInt32:[self chatID] forName:@"wired.chat.id"];
			[[self connection] sendMessage:message];

			[[WCStats stats] addUnsignedLongLong:[string UTF8StringLength] forKey:WCStatsChat];
		}

		[_chatInputTextView setString:@""];

		return YES;
	}
	// --- user pressed tab key
	else if(selector == @selector(insertTab:)) {
		if([WCSettings boolForKey:WCChatTabCompleteNicks]) {
			[_chatInputTextView setString:[self _stringByCompletingString:[_chatInputTextView string]]];
			
			return YES;
		}
	}
	// --- user pressed the escape key
	else if(selector == @selector(cancelOperation:)) {
		[_chatInputTextView setString:@""];

		return YES;
	}
	// --- user pressed configured history up key
	else if(historyScrollback &&
			((selector == @selector(moveUp:) &&
			  historyModifier == WCChatHistoryScrollbackModifierNone) ||
			 (selector == @selector(moveToBeginningOfDocument:) &&
			  historyModifier == WCChatHistoryScrollbackModifierCommand &&
			  commandKey) ||
			 (selector == @selector(moveToBeginningOfParagraph:) &&
			  historyModifier == WCChatHistoryScrollbackModifierOption &&
			  optionKey) ||
			 (selector == @selector(scrollPageUp:) &&
			  historyModifier == WCChatHistoryScrollbackModifierControl &&
			  controlKey))) {
		if(_currentCommand > 0) {
			if(_currentCommand == [_commandHistory count]) {
				[_currentString release];

				_currentString = [[_chatInputTextView string] copy];
			}

			[_chatInputTextView setString:[_commandHistory objectAtIndex:--_currentCommand]];

			return YES;
		}
	}
	// --- user pressed the arrow down key
	else if(historyScrollback &&
			((selector == @selector(moveDown:) &&
			  historyModifier == WCChatHistoryScrollbackModifierNone) ||
			 (selector == @selector(moveToEndOfDocument:) &&
			  historyModifier == WCChatHistoryScrollbackModifierCommand &&
			  commandKey) ||
			 (selector == @selector(moveToEndOfParagraph:) &&
			  historyModifier == WCChatHistoryScrollbackModifierOption &&
			  optionKey) ||
			 (selector == @selector(scrollPageDown:) &&
			  historyModifier == WCChatHistoryScrollbackModifierControl &&
			  controlKey))) {
		if(_currentCommand + 1 < [_commandHistory count]) {
			[_chatInputTextView setString:[_commandHistory objectAtIndex:++_currentCommand]];

			return YES;
		}
		else if(_currentCommand + 1 == [_commandHistory count]) {
			_currentCommand++;
			[_chatInputTextView setString:_currentString];
			[_currentString release];
			_currentString = NULL;

			return YES;
		}
	}
	// --- user pressed cmd/ctrl arrow up/down or page up/down
	else if(selector == @selector(moveToBeginningOfDocument:) ||
			selector == @selector(moveToEndOfDocument:) ||
			selector == @selector(scrollToBeginningOfDocument:) ||
			selector == @selector(scrollToEndOfDocument:) ||
			selector == @selector(scrollPageUp:) ||
			selector == @selector(scrollPageDown:)) {
		[_chatOutputTextView performSelector:selector withObject:self];
		
		return YES;
	}
	
	return NO;
}



- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	BOOL	value = NO;

	if(textView == _setTopicTextView) {
		value = [self topicTextView:textView doCommandBySelector:selector];
		
		[_setTopicTextView setFont:WIFontFromString([[[self connection] theme] objectForKey:WCThemesChatFont])];
	}
	else if(textView == _chatInputTextView) {
		value = [self chatTextView:textView doCommandBySelector:selector];
		
		[_chatInputTextView setFont:WIFontFromString([[[self connection] theme] objectForKey:WCThemesChatFont])];
	}
	
	return value;
}



#pragma mark -

- (void)validate {
	BOOL	connected;
	
	connected = [[self connection] isConnected];
	
	if([_userListTableView selectedRow] < 0) {
		[_infoButton setEnabled:NO];
		[_privateMessageButton setEnabled:NO];
		[_kickButton setEnabled:NO];
	} else {
		[_infoButton setEnabled:([[[self connection] account] userGetInfo] && connected)];
		[_privateMessageButton setEnabled:connected];
		[_kickButton setEnabled:(([self chatID] != WCPublicChatID) || ([[[self connection] account] userKickUsers] && connected))];
	}
}



- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	BOOL	connected;
	
	selector = [item action];
	connected = [[self connection] isConnected];
	
	if(selector == @selector(sendPrivateMessage:))
		return connected;
	else if(selector == @selector(getInfo:))
		return ([[[self connection] account] userGetInfo] && connected);
	else if(selector == @selector(kick:))
		return (([self chatID] != WCPublicChatID) || ([[[self connection] account] userKickUsers] && connected));
	else if(selector == @selector(editAccount:))
		return ([[[self connection] account] accountEditAccounts] && connected);
	else if(selector == @selector(ignore:) || selector == @selector(unignore:)) {
		if([[self selectedUser] isIgnored]) {
			[item setTitle:NSLS(@"Unignore", "User list menu title")];
			[item setAction:@selector(unignore:)];
		} else {
			[item setTitle:NSLS(@"Ignore", "User list menu title")];
			[item setAction:@selector(ignore:)];
		}
	}
	
	return [super validateMenuItem:item];
}



#pragma mark -

- (WCUser *)selectedUser {
	NSInteger		row;

	row = [_userListTableView selectedRow];

	if(row < 0)
		return NULL;

	return [_shownUsers objectAtIndex:row];
}



- (NSArray *)selectedUsers {
	return [NSArray arrayWithObject:[self selectedUser]];
}



- (NSArray *)users {
	return _shownUsers;
}



- (NSArray *)nicks {
	NSEnumerator	*enumerator;
	NSMutableArray	*nicks;
	WCUser			*user;
	
	nicks = [NSMutableArray array];
	enumerator = [_shownUsers objectEnumerator];
	
	while((user = [enumerator nextObject]))
		[nicks addObject:[user nick]];
	
	return nicks;
}



- (WCUser *)userAtIndex:(NSUInteger)index {
	return [_shownUsers objectAtIndex:index];
}



- (WCUser *)userWithUserID:(NSUInteger)uid {
	return [_users objectForKey:[NSNumber numberWithInt:uid]];
}



- (void)selectUser:(WCUser *)user {
	NSUInteger	index;
	
	index = [_shownUsers indexOfObject:user];
	
	if(index != NSNotFound) {
		[_userListTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[[self window] makeFirstResponder:_userListTableView];
	}
}



- (NSUInteger)chatID {
	return WCPublicChatID;
}



- (NSTextView *)insertionTextView {
	return _chatInputTextView;
}



#pragma mark -

- (void)printEvent:(NSString *)message {
	NSString	*output;

	output = [NSSWF:NSLS(@"<<< %@ >>>", @"Chat event (message)"), message];

	if([WCSettings boolForKey:WCChatTimestampEveryLine])
		output = [NSSWF:@"%@ %@", [_timestampEveryLineDateFormatter stringFromDate:[NSDate date]], output];

	[self _printString:output];
}



#pragma mark -

- (IBAction)stats:(id)sender {
	WIP7Message		*message;

	message = [WIP7Message messageWithName:@"wired.chat.send_say" spec:WCP7Spec];
	[message setUInt32:[self chatID] forName:@"wired.chat.id"];
	[message setString:[[WCStats stats] stringValue] forName:@"wired.chat.say"];
	[[self connection] sendMessage:message];
}



- (IBAction)saveChat:(id)sender {
	const NSStringEncoding	*encodings;
	NSSavePanel				*savePanel;
	NSAttributedString		*attributedString;
	NSString				*name, *path, *string;
	WCChatFormat			format;
	NSStringEncoding		encoding;
	NSUInteger				i = 0;
	 
	format		= [WCSettings intForKey:WCLastChatFormat];
	encoding	= [WCSettings intForKey:WCLastChatEncoding];
	
	if(encoding == 0)
		encoding = NSUTF8StringEncoding;
	
	if(!_saveChatView) {
		[NSBundle loadNibNamed:@"SaveChat" owner:self];
		
		[_saveChatFileFormatPopUpButton removeAllItems];
		[_saveChatFileFormatPopUpButton addItem:
			[NSMenuItem itemWithTitle:NSLS(@"Plain Text", @"Save chat format") tag:WCChatPlainText]];
		
		[_saveChatPlainTextEncodingPopUpButton removeAllItems];

		encodings = [NSString availableStringEncodings];
		
		while(encodings[i]) {
			if(encodings[i] <= NSMacOSRomanStringEncoding) {
				[_saveChatPlainTextEncodingPopUpButton addItem:
					[NSMenuItem itemWithTitle:[NSString localizedNameOfStringEncoding:encodings[i]] tag:encodings[i]]];
			}
			
			i++;
		}
	}
	
	if([_saveChatFileFormatPopUpButton numberOfItems] > 1)
		[_saveChatFileFormatPopUpButton removeItemAtIndex:1];
	
	if([[_chatOutputTextView textStorage] containsAttachments]) {
		[_saveChatFileFormatPopUpButton addItem:
			[NSMenuItem itemWithTitle:NSLS(@"Rich Text With Graphics Format (RTFD)", @"Save chat format") tag:WCChatRTFD]];
		
		if(format == WCChatRTF)
			format = WCChatRTFD;
	} else {
		[_saveChatFileFormatPopUpButton addItem:
			[NSMenuItem itemWithTitle:NSLS(@"Rich Text Format (RTF)", @"Save chat format") tag:WCChatRTF]];
		
		if(format == WCChatRTFD)
			format = WCChatRTF;
	}
	
	[_saveChatFileFormatPopUpButton selectItemWithTag:format];
	[_saveChatPlainTextEncodingPopUpButton selectItemWithTag:encoding];
	
	if([self chatID] == WCPublicChatID) {
		name = [NSSWF:NSLS(@"%@ Public Chat", "Save chat file name (server)"),
			[[self connection] name]];
	} else {
		name = [NSSWF:NSLS(@"%@ Private Chat", "Save chat file name (server)"),
			[[self connection] name]];
	}
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setAccessoryView:_saveChatView];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setTitle:NSLS(@"Save Chat", @"Save chat save panel title")];
	
	[self _updateSaveChatForPanel:savePanel];

	if([savePanel runModalForDirectory:[WCSettings objectForKey:WCDownloadFolder] file:name] == NSFileHandlingPanelOKButton) {
		path		= [savePanel filename];
		format		= [_saveChatFileFormatPopUpButton tagOfSelectedItem];
		encoding	= [_saveChatPlainTextEncodingPopUpButton tagOfSelectedItem];
		
		switch(format) {
			case WCChatPlainText:
				string = [_chatOutputTextView string];
				
				[[string dataUsingEncoding:encoding]
					writeToFile:path atomically:YES];
				break;
			
			case WCChatRTF:
				attributedString = [_chatOutputTextView textStorage];
				
				[[attributedString RTFFromRange:NSMakeRange(0, [attributedString length]) documentAttributes:NULL]
					writeToFile:path atomically:YES];
				break;
			
			case WCChatRTFD:
				attributedString = [_chatOutputTextView textStorage];
				
				[[attributedString RTFDFileWrapperFromRange:NSMakeRange(0, [attributedString length]) documentAttributes:NULL]
					writeToFile:path atomically:YES updateFilenames:YES];
				break;
		}
	}
	
	[WCSettings setInt:[_saveChatFileFormatPopUpButton tagOfSelectedItem] forKey:WCLastChatFormat];
	[WCSettings setInt:[_saveChatPlainTextEncodingPopUpButton tagOfSelectedItem] forKey:WCLastChatEncoding];
}



- (IBAction)setTopic:(id)sender {
	[_setTopicTextView setString:[_topicTextField stringValue]];
	[_setTopicTextView setSelectedRange:NSMakeRange(0, [[_setTopicTextView string] length])];
	
	[NSApp beginSheet:_setTopicPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(topicSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)topicSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.chat.set_topic" spec:WCP7Spec];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:[_setTopicTextView string] forName:@"wired.chat.topic.topic"];
		[[self connection] sendMessage:message];
	}

	[_setTopicPanel close];
	[_setTopicTextView setString:@""];
}



- (IBAction)sendPrivateMessage:(id)sender {
	if(![_privateMessageButton isEnabled])
		return;
	
	[[WCMessages messages] showPrivateMessageToUser:[self selectedUser]];
}



- (IBAction)getInfo:(id)sender {
	[WCUserInfo userInfoWithConnection:[self connection] user:[self selectedUser]];
}



- (IBAction)kick:(id)sender {
	[NSApp beginSheet:_kickMessagePanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(kickSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:[[self selectedUser] retain]];
}



- (void)kickSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	WCUser			*user = contextInfo;

	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.chat.kick_user" spec:WCP7Spec];
		[message setUInt32:[user userID] forName:@"wired.user.id"];
		[message setUInt32:[self chatID] forName:@"wired.chat.id"];
		[message setString:[_kickMessageTextField stringValue] forName:@"wired.user.disconnect_message"];
		[[self connection] sendMessage:message];
	}

	[user release];

	[_kickMessagePanel close];
	[_kickMessageTextField setStringValue:@""];
}



- (IBAction)editAccount:(id)sender {
	WCUser			*user;

	user = [self selectedUser];

	[[[self connection] accounts] editUserAccountWithName:[user login]];
}



- (IBAction)ignore:(id)sender {
	NSDictionary	*ignore;
	WCUser			*user;

	user = [self selectedUser];

	if([user isIgnored])
		return;

	ignore = [NSDictionary dictionaryWithObjectsAndKeys:
				[user nick],	WCIgnoresNick,
				[user login],	WCIgnoresLogin,
				NULL];
	
	[WCSettings addObject:ignore toArrayForKey:WCIgnores];

	[_userListTableView setNeedsDisplay:YES];
}



- (IBAction)unignore:(id)sender {
	NSDictionary		*ignore;
	NSEnumerator		*enumerator;
	WCUser				*user;
	BOOL				nick, login;
	NSUInteger			i;

	user = [self selectedUser];

	if(![user isIgnored])
		return;

	while([user isIgnored]) {
		enumerator = [[WCSettings objectForKey:WCIgnores] objectEnumerator];
		i = 0;

		while((ignore = [enumerator nextObject])) {
			nick = login = NO;

			if([[ignore objectForKey:WCIgnoresNick] isEqualToString:[user nick]] ||
				[[ignore objectForKey:WCIgnoresNick] isEqualToString:@""])
				nick = YES;

			if([[ignore objectForKey:WCIgnoresLogin] isEqualToString:[user login]] ||
				[[ignore objectForKey:WCIgnoresLogin] isEqualToString:@""])
				login = YES;

			if(nick && login)
				[WCSettings removeObjectAtIndex:i fromArrayForKey:WCIgnores];
			
			i++;
		}
	}

	[_userListTableView setNeedsDisplay:YES];
}



#pragma mark -

- (IBAction)fileFormat:(id)sender {
	[self _updateSaveChatForPanel:(NSSavePanel *) [sender window]];
}



#pragma mark -

- (void)insertSmiley:(id)sender {
	NSFileWrapper		*wrapper;
	NSTextAttachment	*attachment;
	NSAttributedString	*attributedString;
	
	wrapper				= [[NSFileWrapper alloc] initWithPath:[sender representedObject]];
	attachment			= [[WITextAttachment alloc] initWithFileWrapper:wrapper string:[sender toolTip]];
	attributedString	= [NSAttributedString attributedStringWithAttachment:attachment];
	
	[_chatInputTextView insertText:attributedString];
	
	[attachment release];
	[wrapper release];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownUsers count];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self validate];
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	WCUser		*user;

	if(column == _nickTableColumn) {
		user = [self userAtIndex:row];

		[cell setTextColor:[user color]];
		[cell setIgnored:[user isIgnored]];
	}
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	WCUser		*user;

	user = [self userAtIndex:row];
	
	if(column == _iconTableColumn)
		return [user iconWithIdleTint:YES];
	else if(column == _nickTableColumn) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[user nick],		WCUserCellNickKey,
			[user status],		WCUserCellStatusKey,
			NULL];
	}

	return NULL;
}



- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
	return [[self userAtIndex:row] nick];
}



- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {
	NSMutableString		*toolTip;
	WCUser				*user;
	NSTimeInterval		interval;

	user = [self userAtIndex:row];
	toolTip = [[user nick] mutableCopy];
	
	if([[user status] length] > 0)
		[toolTip appendFormat:@"\n%@", [user status]];
	
	interval = [[NSDate date] timeIntervalSinceDate:[user idleDate]];
	[toolTip appendFormat:@"\n"];
	[toolTip appendFormat:NSLS(@"Idle %@", @"Chat tooltip (idle time)"),
		[NSString humanReadableStringForTimeInterval:interval]];
	
	return toolTip;
}



- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
	WCUser		*user;
	NSInteger	row;

	row = [[items objectAtIndex:0] integerValue];
	user = [self userAtIndex:row];

	[pasteboard declareTypes:[NSArray arrayWithObjects:WCUserPboardType, NSStringPboardType, NULL]
				owner:NULL];
	[pasteboard setString:[NSSWF:@"%u", [user userID]] forType:WCUserPboardType];
	[pasteboard setString:[user nick] forType:NSStringPboardType];

	return YES;
}



- (void)tableViewShouldCopyInfo:(NSTableView *)tableView {
	NSPasteboard	*pasteboard;
	WCUser			*user;

	user = [self selectedUser];

	pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, NULL] owner:NULL];
	[pasteboard setString:[user nick] forType:NSStringPboardType];
}

@end
