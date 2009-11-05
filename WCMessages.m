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

#import "WCApplicationController.h"
#import "WCChatController.h"
#import "WCConversation.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCServerConnection.h"
#import "WCSourceSplitView.h"
#import "WCStats.h"
#import "WCUser.h"

NSString * const WCMessagesDidChangeUnreadCountNotification		= @"WCMessagesDidChangeUnreadCountNotification";


@interface WCMessages(Private)

- (void)_validate;
- (void)_themeDidChange;

- (void)_showDialogForMessage:(WCMessage *)message;
- (NSString *)_stringForMessageString:(NSString *)string;
- (void)_sendMessage;

- (WCConversation *)_selectedConversation;
- (void)_saveMessages;

- (void)_selectConversation:(WCConversation *)conversation;

- (void)_reloadConversation;
- (NSString *)_HTMLStringForMessage:(WCMessage *)message icon:(NSString *)icon;
- (NSString *)_HTMLStringForStatus:(NSString *)status;

@end


@implementation WCMessages(Private)

- (void)_validate {
	WCConversation		*conversation;
	WCServerConnection	*connection;
	
	conversation	= [self _selectedConversation];
	connection		= [conversation connection];
	
	[_deleteConversationButton setEnabled:(conversation != NULL)];
	[_messageTextView setEditable:(connection != NULL && [connection isConnected] && [conversation user] != NULL)];
	
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [[WCSettings settings] themeWithIdentifier:[[WCSettings settings] objectForKey:WCTheme]];
	
	[_messageFont release];
	_messageFont = [WIFontFromString([theme objectForKey:WCThemesMessagesFont]) retain];
	
	[_messageColor release];
	_messageColor = [WIColorFromString([theme objectForKey:WCThemesMessagesTextColor]) retain];
	
	[_backgroundColor release];
	_backgroundColor = [WIColorFromString([theme objectForKey:WCThemesMessagesBackgroundColor]) retain];
	
	[_messageTextView setFont:_messageFont];
	[_messageTextView setTextColor:_messageColor];
	[_messageTextView setInsertionPointColor:_messageColor];
	[_messageTextView setBackgroundColor:WIColorFromString([theme objectForKey:WCThemesMessagesBackgroundColor])];
	
	[_broadcastTextView setFont:_messageFont];
	[_broadcastTextView setTextColor:_messageColor];
	[_broadcastTextView setInsertionPointColor:_messageColor];
	[_broadcastTextView setBackgroundColor:_backgroundColor];
	
	[self _reloadConversation];
}



#pragma mark -

- (void)_showDialogForMessage:(WCMessage *)message {
	NSAlert		*alert;
	NSString	*title, *nick, *server, *time;
	
	nick	= [message nick];
	server	= [[message connection] name];
	time	= [_dialogDateFormatter stringFromDate:[message date]];
	
	if([message isKindOfClass:[WCPrivateMessage class]])
		title = [NSSWF:NSLS(@"Private message from %@ on %@ at %@", @"Message dialog title (nick, server, time)"), nick, server, time];
	else
		title = [NSSWF:NSLS(@"Broadcast from %@ on %@ at %@", @"Broadcast dialog title (nick, server, time)"), nick, server, time];
	
	alert = [[NSAlert alloc] init];
	[alert setMessageText:title];
	[alert setInformativeText:[message message]];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert runNonModal];
	[alert release];
	
	[message setUnread:NO];
}



- (NSString *)_stringForMessageString:(NSString *)string {
	NSString	*command, *argument;
	NSRange		range;
	
	range = [string rangeOfString:@" "];
	
	if(range.location == NSNotFound) {
		command = string;
		argument = @"";
	} else {
		command = [string substringToIndex:range.location];
		argument = [string substringFromIndex:range.location + 1];
	}
	
	if([command isEqualToString:@"/exec"] && [argument length] > 0)
		return [WCChatController outputForShellCommand:argument];
	else if([command isEqualToString:@"/stats"])
		return [[WCStats stats] stringValue];
	
	return string;
}



- (void)_sendMessage {
	NSString				*string;
	WIP7Message				*p7Message;
	WCServerConnection		*connection;
	WCConversation			*conversation;
	WCMessage				*message;
	WCUser					*user;

	string			= [WCChatController stringByDecomposingSmileyAttributesInAttributedString:[_messageTextView textStorage]];
	conversation	= [self _selectedConversation];
	connection		= [conversation connection];
	user			= [[connection chatController] userWithUserID:[connection userID]];
	message			= [WCPrivateMessage messageToSomeoneFromUser:user
												   message:string
												connection:connection];
	
	[conversation addMessage:message];
	
	[self _saveMessages];
	
	p7Message = [WIP7Message messageWithName:@"wired.message.send_message" spec:WCP7Spec];
	[p7Message setUInt32:[[conversation user] userID] forName:@"wired.user.id"];
	[p7Message setString:[self _stringForMessageString:[message message]] forName:@"wired.message.message"];
	[[message connection] sendMessage:p7Message];
	
	[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesSent];
	
	[self _reloadConversation];
	
	[_messageTextView setString:@""];
}


#pragma mark -

- (WCConversation *)_selectedConversation {
	return _selectedConversation;
}



- (void)_saveMessages {
	[[WCSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:[_messageConversations conversations]]
							  forKey:WCMessageConversations];
	
	[[WCSettings settings] setObject:[NSKeyedArchiver archivedDataWithRootObject:[_broadcastConversations conversations]]
							  forKey:WCBroadcastConversations];
}



#pragma mark -

- (void)_selectConversation:(WCConversation *)conversation {
	NSInteger		row;
	
	row = [_conversationsOutlineView rowForItem:conversation];
	
	if(row >= 0)
		[_conversationsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}



#pragma mark -

- (void)_reloadConversation {
	NSEnumerator			*enumerator;
	NSMutableString			*html;
	NSMutableDictionary		*icons;
	NSCalendar				*calendar;
	NSDateComponents		*components;
	NSString				*icon;
	WCConversation			*conversation;
	WCMessage				*message;
	NSInteger				day;
	BOOL					changedUnread = NO, isKeyWindow;
	
	conversation = [self _selectedConversation];
	
	html = [NSMutableString stringWithString:_headerTemplate];
	
	[html replaceOccurrencesOfString:@"<? fontname ?>" withString:[_messageFont fontName]];
	[html replaceOccurrencesOfString:@"<? fontsize ?>" withString:[NSSWF:@"%.0fpx", [_messageFont pointSize]]];
	[html replaceOccurrencesOfString:@"<? textcolor ?>" withString:[NSSWF:@"#%.6x", [_messageColor HTMLValue]]];
	[html replaceOccurrencesOfString:@"<? backgroundcolor ?>" withString:[NSSWF:@"#%.6x", [_backgroundColor HTMLValue]]];

	if(conversation && ![conversation isExpandable]) {
		isKeyWindow		= ([NSApp keyWindow] == [self window]);
		calendar		= [NSCalendar currentCalendar];
		day				= -1;
		icons			= [NSMutableDictionary dictionary];
		enumerator		= [[conversation messages] objectEnumerator];
		
		if([conversation numberOfMessages] == 0) {
			[html appendString:[self _HTMLStringForStatus:[_messageStatusDateFormatter stringFromDate:[NSDate date]]]];
		} else {
			while((message = [enumerator nextObject])) {
				components = [calendar components:NSDayCalendarUnit fromDate:[message date]];
				
				if([components day] != day) {
					[html appendString:[self _HTMLStringForStatus:[_messageStatusDateFormatter stringFromDate:[message date]]]];
					
					day = [components day];
				}
				
				icon = [icons objectForKey:[NSNumber numberWithInt:[[message user] userID]]];
				
				if(!icon) {
					icon = [[[[message user] icon] TIFFRepresentation] base64EncodedString];
					
					if(icon)
						[icons setObject:icon forKey:[NSNumber numberWithInt:[[message user] userID]]];
				}
				
				[html appendString:[self _HTMLStringForMessage:message icon:icon]];
				
				if([message isUnread] && isKeyWindow) {
					[message setUnread:NO];
					
					changedUnread = YES;
				}
			}
		}
		
		if([conversation isUnread] && isKeyWindow) {
			[conversation setUnread:NO];
			
			changedUnread = YES;
		}
	}
	
	[html appendString:_footerTemplate];
	
	[[_messageWebView mainFrame] loadHTMLString:html baseURL:[NSURL fileURLWithPath:[[self bundle] resourcePath]]];
	
	if(changedUnread) {
		[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];
		
		[self _saveMessages];
	}
}



- (NSString *)_HTMLStringForMessage:(WCMessage *)message icon:(NSString *)icon {
	NSEnumerator		*enumerator;
	NSDictionary		*theme, *regexs;
	NSMutableString		*string, *text;
	NSString			*smiley, *path, *regex, *substring;
	NSRange				range;
	
	theme		= [message theme];
	text		= [[[message message] mutableCopy] autorelease];
	
	[text replaceOccurrencesOfString:@"&" withString:@"&#38;"];
	[text replaceOccurrencesOfString:@"<" withString:@"&#60;"];
	[text replaceOccurrencesOfString:@">" withString:@"&#62;"];
	[text replaceOccurrencesOfString:@"\"" withString:@"&#34;"];
	[text replaceOccurrencesOfString:@"\'" withString:@"&#39;"];
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:[NSSWF:@"(?:^|\\s)(%@)(?:\\.|,|:|\\?|!)?(?:\\s|$)", [WCChatController URLRegex]]
						   options:RKLCaseless
						   capture:1];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:range];
			
			[text replaceCharactersInRange:range withString:[NSSWF:@"<a href=\"%@\">%@</a>", substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:[NSSWF:@"(?:^|\\s)(%@)(?:\\.|,|:|\\?|!)?(?:\\s|$)", [WCChatController schemelessURLRegex]]
						   options:RKLCaseless
						   capture:1];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:range];
			
			[text replaceCharactersInRange:range withString:[NSSWF:@"<a href=\"http://%@\">%@</a>", substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	/* Do this in a custom loop to avoid corrupted strings when using $1 multiple times */
	do {
		range = [text rangeOfRegex:[NSSWF:@"(?:^|\\s)(%@)(?:\\.|,|:|\\?|!)?(?:\\s|$)", [WCChatController mailtoURLRegex]]
						   options:RKLCaseless
						   capture:1];
		
		if(range.location != NSNotFound) {
			substring = [text substringWithRange:range];
			
			[text replaceCharactersInRange:range withString:[NSSWF:@"<a href=\"mailto:%@\">%@</a>", substring, substring]];
		}
	} while(range.location != NSNotFound);
	
	if([theme boolForKey:WCThemesShowSmileys]) {
		regexs			= [WCChatController smileyRegexs];
		enumerator		= [regexs keyEnumerator];
		
		while((smiley = [enumerator nextObject])) {
			regex		= [regexs objectForKey:smiley];
			path		= [[WCApplicationController sharedController] pathForSmiley:smiley];
		
			[text replaceOccurrencesOfRegex:[NSSWF:@"(^|\\s)%@(\\s|$)", regex]
								 withString:[NSSWF:@"$1<img src=\"%@\" alt=\"%@\" />$2", path, smiley]
									options:RKLCaseless | RKLMultiline];
		}
	}

	[text replaceOccurrencesOfString:@"\n" withString:@"<br />\n"];
	
	string = [[_messageTemplate mutableCopy] autorelease];
	
	if([message direction] == WCMessageTo)
		[string replaceOccurrencesOfString:@"<? direction ?>" withString:@"to"];
	else
		[string replaceOccurrencesOfString:@"<? direction ?>" withString:@"from"];
	
	[string replaceOccurrencesOfString:@"<? nick ?>" withString:[message nick]];
	[string replaceOccurrencesOfString:@"<? time ?>" withString:[_messageTimeDateFormatter stringFromDate:[message date]]];
	[string replaceOccurrencesOfString:@"<? server ?>" withString:[message connectionName]];
	[string replaceOccurrencesOfString:@"<? body ?>" withString:text];
	
	if(icon)
		[string replaceOccurrencesOfString:@"<? icon ?>" withString:[NSSWF:@"data:image/tiff;base64,%@", icon]];
	else
		[string replaceOccurrencesOfString:@"<? icon ?>" withString:@"DefaultIcon.tiff"];
	
	return string;
}



- (NSString *)_HTMLStringForStatus:(NSString *)status {
	NSMutableString		*string;
	
	string = [[_statusTemplate mutableCopy] autorelease];
	
	[string replaceOccurrencesOfString:@"<? status ?>" withString:status];
	
	return string;
}

@end


@implementation WCMessages

+ (id)messages {
	static WCMessages   *sharedMessages;
	
	if(!sharedMessages)
		sharedMessages = [[self alloc] init];
	
	return sharedMessages;
}



#pragma mark -

- (id)init {
	self = [super initWithWindowNibName:@"Messages"];

	_conversationIcon	= [[NSImage imageNamed:@"Conversation"] retain];
	
	_headerTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"MessageHeader" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_footerTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"MessageFooter" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_messageTemplate	= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"Message" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];
	_statusTemplate		= [[NSMutableString alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"MessageStatus" ofType:@"html"]
															  encoding:NSUTF8StringEncoding
																 error:NULL];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(selectedThemeDidChange:)
			   name:WCSelectedThemeDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionLoggedIn:)
			   name:WCLinkConnectionLoggedInNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidClose:)
			   name:WCLinkConnectionDidCloseNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidTerminate:)
			   name:WCLinkConnectionDidTerminateNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatUserNickDidChange:)
			   name:WCChatUserNickDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatUserAppeared:)
			   name:WCChatUserAppearedNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatUserDisappeared:)
			   name:WCChatUserDisappearedNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(messagesDidChangeUnreadCount:)
			   name:WCMessagesDidChangeUnreadCountNotification];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_conversations release];
	[_messageConversations release];
	[_broadcastConversations release];
	
	[_selectedConversation release];

	[_conversationIcon release];
	
	[_messageColor release];
	[_conversationIcon release];
	
	[_dialogDateFormatter release];
	
	[_headerTemplate release];
	[_footerTemplate release];
	[_messageTemplate release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;
	NSData			*data;
	NSArray			*array;
	NSInvocation	*invocation;
	NSUInteger		style;
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Messages"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];

	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Messages"];
	
	[_conversationsSplitView setAutosaveName:@"Conversations"];
	[_messagesSplitView setAutosaveName:@"Messages"];

	if([_conversationsOutlineView respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
		style = 1; // NSTableViewSelectionHighlightStyleSourceList
	
		invocation = [NSInvocation invocationWithTarget:_conversationsOutlineView action:@selector(setSelectionHighlightStyle:)];
		[invocation setArgument:&style atIndex:2];
		[invocation invoke];
	}

	[[_conversationTableColumn dataCell] setVerticalTextOffset:3.0];
	[[_unreadTableColumn dataCell] setImageAlignment:NSImageAlignRight];
	
	[_conversationsOutlineView setTarget:self];
	[_conversationsOutlineView setDeleteAction:@selector(deleteConversation:)];
	
	_conversations			= [[WCConversation rootConversation] retain];
	_messageConversations	= [[WCMessageConversation rootConversation] retain];
	_broadcastConversations	= [[WCBroadcastConversation rootConversation] retain];
	
	data = [[WCSettings settings] objectForKey:WCMessageConversations];
	
	if(data) {
		array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		[_messageConversations addConversations:array];
	}
	
	data = [[WCSettings settings] objectForKey:WCBroadcastConversations];
	
	if(data) {
		array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		[_broadcastConversations addConversations:array];
	}

	[_conversations addConversation:_messageConversations];
	[_conversations addConversation:_broadcastConversations];
	
	[_conversationsOutlineView reloadData];
	[_conversationsOutlineView expandItem:_messageConversations];
	[_conversationsOutlineView expandItem:_broadcastConversations];
	
	_dialogDateFormatter = [[WIDateFormatter alloc] init];
	[_dialogDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	_messageStatusDateFormatter = [[WIDateFormatter alloc] init];
	[_messageStatusDateFormatter setTimeStyle:NSDateFormatterNoStyle];
	[_messageStatusDateFormatter setDateStyle:NSDateFormatterLongStyle];
	
	_messageTimeDateFormatter = [[WIDateFormatter alloc] init];
	[_messageTimeDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	[self _themeDidChange];
	[self _validate];
}



- (void)windowDidBecomeKey:(NSWindow *)window {
	NSEnumerator		*enumerator;
	WCConversation		*conversation;
	WCMessage			*message;
	BOOL				changedUnread = NO;
	
	conversation = [self _selectedConversation];
	
	if(conversation) {
		enumerator = [[conversation messages] objectEnumerator];
		
		while((message = [enumerator nextObject])) {
			if([message isUnread]) {
				[message setUnread:NO];
				
				changedUnread = YES;
			}
		}
		
		if([conversation isUnread]) {
			[conversation setUnread:NO];
			
			changedUnread = YES;
		}
		
		if(changedUnread) {
			[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];
			
			[self _saveMessages];
		}
	}
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"RevealInUserList"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reveal in User List", @"Reveal in user list message toolbar item")
												content:[NSImage imageNamed:@"RevealInUserList"]
												 target:self
												 action:@selector(revealInUserList:)];
	}
	else if([identifier isEqualToString:@"Clear"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Clear", @"Clear messages toolbar item")
												content:[NSImage imageNamed:@"ClearMessages"]
												 target:self
												 action:@selector(clearMessages:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"RevealInUserList",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Clear",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"RevealInUserList",
		@"Clear",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	[self _saveMessages];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	WCServerConnection		*connection;

	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;

	[_conversations revalidateForConnection:connection];
	
	[connection addObserver:self selector:@selector(wiredMessageMessage:) messageName:@"wired.message.message"];
	[connection addObserver:self selector:@selector(wiredMessageBroadcast:) messageName:@"wired.message.broadcast"];
	
	[self _validate];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;

	[_conversations invalidateForConnection:connection];
	
	[connection removeObserver:self];

	[self _validate];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;

	[_conversations invalidateForConnection:connection];
	
	[connection removeObserver:self];
	
	[self _validate];
	[self _reloadConversation];
}



- (void)chatUserAppeared:(NSNotification *)notification {
	WCUser		*user;
	
	user = [notification object];
	
	[_conversations revalidateForUser:user];
	
	if([[self _selectedConversation] user] == user)
		[self _reloadConversation];
	
	[self _validate];
}



- (void)chatUserDisappeared:(NSNotification *)notification {
	WCUser		*user;
	
	user = [notification object];
	
	[_conversations invalidateForUser:user];
	
	if([[self _selectedConversation] user] == user)
		[self _reloadConversation];
	
	[self _validate];
}



- (void)chatUserNickDidChange:(NSNotification *)notification {
	WCUser		*user;
	
	user = [notification object];
	
	if([[self _selectedConversation] user] == user)
		[self _reloadConversation];
	   
	[_conversationsOutlineView reloadData];
	
	[self _validate];
}



- (void)messagesDidChangeUnreadCount:(NSNotification *)notification {
	[_conversationsOutlineView setNeedsDisplay:YES];
}



- (void)wiredMessageMessage:(WIP7Message *)p7Message {
	WCServerConnection		*connection;
	WCUser					*user;
	WCMessage				*message;
	WCConversation			*conversation, *selectedConversation;
	WIP7UInt32				uid;
	
	[p7Message getUInt32:&uid forName:@"wired.user.id"];
	
	connection = [p7Message contextInfo];
	user = [[connection chatController] userWithUserID:uid];
	
	if(!user || [user isIgnored])
		return;
	
	conversation = [_messageConversations conversationForUser:user connection:connection];
	
	if(!conversation) {
		conversation = [WCMessageConversation conversationWithUser:user connection:connection];
		[_messageConversations addConversation:conversation];
	}
	
	selectedConversation = [self _selectedConversation];

	message = [WCPrivateMessage messageFromUser:user
										message:[p7Message stringForName:@"wired.message.message"]
									 connection:connection];
	
	[conversation addMessage:message];

	[self _saveMessages];
	
	[_conversationsOutlineView reloadData];
	
	[self _reloadConversation];
	[self _selectConversation:selectedConversation];

	if([[[WCSettings settings] eventWithTag:WCEventsMessageReceived] boolForKey:WCEventsShowDialog])
		[self _showDialogForMessage:message];

	[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesReceived];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];
	[connection triggerEvent:WCEventsMessageReceived info1:message];
	
	[self _validate];
}



- (void)wiredMessageBroadcast:(WIP7Message *)p7Message {
	WCServerConnection	*connection;
	WCUser				*user;
	WCMessage			*message;
	WCConversation		*conversation, *selectedConversation;
	WIP7UInt32			uid;
	
	[p7Message getUInt32:&uid forName:@"wired.user.id"];
	
	connection = [p7Message contextInfo];
	user = [[connection chatController] userWithUserID:uid];
	
	if(!user || [user isIgnored])
		return;

	conversation = [_broadcastConversations conversationForUser:user connection:connection];
	
	if(!conversation) {
		conversation = [WCBroadcastConversation conversationWithUser:user connection:connection];
		[_broadcastConversations addConversation:conversation];
	}

	selectedConversation = [self _selectedConversation];

	message = [WCBroadcastMessage broadcastFromUser:user
											message:[p7Message stringForName:@"wired.message.broadcast"]
										 connection:connection];
	
	[conversation addMessage:message];

	[self _saveMessages];

	[_conversationsOutlineView reloadData];
	
	[self _reloadConversation];
	[self _selectConversation:selectedConversation];

	if([[[WCSettings settings] eventWithTag:WCEventsBroadcastReceived] boolForKey:WCEventsShowDialog])
		[self _showDialogForMessage:message];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];
	[connection triggerEvent:WCEventsBroadcastReceived info1:message];
	
	[self _validate];
}



- (void)selectedThemeDidChange:(NSNotification *)notification {
	[self _themeDidChange];
}



- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
	if(splitView == _conversationsSplitView) {
		NSSize		size, leftSize, rightSize;
		
		size = [_conversationsSplitView frame].size;
		leftSize = [_conversationsView frame].size;
		leftSize.height = size.height;
		rightSize.height = size.height;
		rightSize.width = size.width - [_conversationsSplitView dividerThickness] - leftSize.width;
		
		[_conversationsView setFrameSize:leftSize];
		[_messagesView setFrameSize:rightSize];
	}
	else if(splitView == _messagesSplitView) {
		NSSize		size, topSize, bottomSize;
		
		size = [_messagesSplitView frame].size;
		bottomSize = [_messageBottomView frame].size;
		bottomSize.width = size.width;
		topSize.width = size.width;
		topSize.height = size.height - [_messagesSplitView dividerThickness] - bottomSize.height;
		
		[_messageTopView setFrameSize:topSize];
		[_messageBottomView setFrameSize:bottomSize];
	}
	
	[splitView adjustSubviews];
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset {
	if(splitView == _conversationsSplitView)
		return proposedMax - 140.0;
	else if(splitView == _messagesSplitView)
		return proposedMax - 40.0;
	
	return proposedMax;
}



- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset {
	if(splitView == _conversationsSplitView)
		return proposedMin + 140.0;
	else if(splitView == _messagesSplitView)
		return proposedMin + 40.0;
	
	return proposedMin;
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return NO;
}



- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	if(textView == _broadcastTextView) {
		if(selector == @selector(insertNewline:)) {
			if([[NSApp currentEvent] character] == NSEnterCharacter) {
				[self submitSheet:textView];

				return YES;
			}
		}
	}
	else if(textView == _messageTextView) {
		if(selector == @selector(insertNewline:)) {
			if([[_messageTextView string] length] > 0)
				[self _sendMessage];
				
			return YES;
		}
		else if(selector == @selector(insertNewlineIgnoringFieldEditor:)) {
			[_messageTextView insertNewline:self];
			
			return YES;
		}
		else if(selector == @selector(moveToBeginningOfDocument:) ||
				selector == @selector(moveToEndOfDocument:) ||
				selector == @selector(scrollToBeginningOfDocument:) ||
				selector == @selector(scrollToEndOfDocument:) ||
				selector == @selector(scrollPageUp:) ||
				selector == @selector(scrollPageDown:)) {
			[_messageWebView performSelector:selector withObject:self];
			
			return YES;
		}
	}

	return NO;
}



- (void)webView:(WebView *)webView didFinishLoadForFrame:(WebFrame *)frame {
	NSRect		rect;
	
	rect = [[[[[_messageWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y = [[[[_messageWebView mainFrame] frameView] documentView] frame].size.height;
	[[[[_messageWebView mainFrame] frameView] documentView] scrollRectToVisible:rect];
}



- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)action request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener {
	if([[action objectForKey:WebActionNavigationTypeKey] unsignedIntegerValue] == WebNavigationTypeOther) {
		[listener use];
	} else {
		[listener ignore];
		
		[[NSWorkspace sharedWorkspace] openURL:[action objectForKey:WebActionOriginalURLKey]];
	}
}



- (NSArray *)webView:(WebView *)webView contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
	return NULL;
}



#pragma mark -

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	SEL		selector;
	
	selector = [item action];
	
	if(selector == @selector(revealInUserList:))
		return ([[self _selectedConversation] user] != NULL);
	else if(selector == @selector(clearMessages:))
		return ([_messageConversations numberOfConversations] > 0 || [_broadcastConversations numberOfConversations] > 0);
	
	return YES;
}



#pragma mark -

- (BOOL)showNextUnreadConversation {
	WCConversation	*conversation;
	NSRect			rect;
	
	if([[self window] firstResponder] == _messageTextView && [_messageTextView isEditable])
		return NO;
	
	rect = [[[[[_messageWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y += 0.9 * rect.size.height;
	
	if([[[[_messageWebView mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return YES;

	conversation = [_conversations nextUnreadConversationStartingAtConversation:[self _selectedConversation]];
	
	if(!conversation)
		conversation = [_conversations nextUnreadConversationStartingAtConversation:NULL];
	
	if(conversation) {
		[self _selectConversation:conversation];
		
		return YES;
	}
	
	return NO;
}



- (BOOL)showPreviousUnreadConversation {
	WCConversation	*conversation;
	NSRect			rect;
	
	if([[self window] firstResponder] == _messageTextView && [_messageTextView isEditable])
		return NO;
	
	rect = [[[[[_messageWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y -= 0.9 * rect.size.height;
	
	if([[[[_messageWebView mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return YES;
	
	conversation = [_conversations previousUnreadConversationStartingAtConversation:[self _selectedConversation]];
	
	if(!conversation)
		conversation = [_conversations previousUnreadConversationStartingAtConversation:NULL];

	if(conversation) {
		[self _selectConversation:conversation];
		
		return YES;
	}
	
	return NO;
}



- (void)showPrivateMessageToUser:(WCUser *)user {
	WCConversation		*conversation;
	WCServerConnection	*connection;
	
	connection		= [user connection];
	conversation	= [_messageConversations conversationForUser:user connection:connection];
	
	if(!conversation) {
		conversation = [WCMessageConversation conversationWithUser:user connection:connection];
		[_messageConversations addConversation:conversation];
		[_conversationsOutlineView reloadData];
	}
	
	[self _selectConversation:conversation];
	
	[self showWindow:self];
	
	[self _validate];
	
	[[self window] makeFirstResponder:_messageTextView];
}



- (void)showBroadcastForConnection:(WCServerConnection *)connection {
	[self showWindow:self];

	[NSApp beginSheet:_broadcastPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(broadcastSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:connection];
}



- (NSUInteger)numberOfUnreadMessages {
	return [_conversations numberOfUnreadMessagesForConnection:NULL includeChildConversations:YES];
}



- (NSUInteger)numberOfUnreadMessagesForConnection:(WCServerConnection *)connection {
	return [_conversations numberOfUnreadMessagesForConnection:connection includeChildConversations:YES];
}



#pragma mark -

- (void)broadcastSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message				*message;
	WCServerConnection		*connection = contextInfo;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.message.send_broadcast" spec:WCP7Spec];
		[message setString:[self _stringForMessageString:[_broadcastTextView string]] forName:@"wired.message.broadcast"];
		[connection sendMessage:message];
	}

	[_broadcastPanel close];
	[_broadcastTextView setString:@""];
}



- (IBAction)revealInUserList:(id)sender {
	WCUser				*user;
	WCError				*error;
	WCConversation		*conversation;
	
	conversation = [self _selectedConversation];
	
	if(!conversation)
		return;
	
	user = [conversation user];
	
	if(user) {
		[[WCPublicChat publicChat] selectChatController:[[conversation connection] chatController]];
		[[[conversation connection] chatController] selectUser:user];
		[[WCPublicChat publicChat] showWindow:self];
	} else { 
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientUserNotFound]; 
		[[conversation connection] triggerEvent:WCEventsError info1:error]; 
		[[error alert] beginSheetModalForWindow:[self window]]; 
	}
}



- (IBAction)clearMessages:(id)sender {
	NSAlert			*alert;
	
	alert = [[NSAlert alloc] init];
	[alert setMessageText:NSLS(@"Are you sure you want to clear the message history?", @"Clear messages dialog title")];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Clear messages dialog description")];
	[alert addButtonWithTitle:NSLS(@"Clear", @"Clear messages dialog button")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Clear messages dialog button")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(clearSheetDidEnd:returnCode:contextInfo:)
						contextInfo:NULL];
	[alert release];
}



- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator		*enumerator;
	WCConversation		*conversation;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		enumerator = [[_conversations conversations] objectEnumerator];
		
		while((conversation = [enumerator nextObject]))
			[conversation removeAllConversations];
		
		[self _saveMessages];
		
		[_conversationsOutlineView reloadData];
		[_conversationsOutlineView deselectAll:self];
		
		[_selectedConversation release];
		_selectedConversation = NULL;
		
		[self _validate];
		[self _reloadConversation];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];
	}
}



- (IBAction)deleteConversation:(id)sender {
	NSAlert				*alert;
	WCConversation		*conversation;
	
	conversation = [self _selectedConversation];
	
	if(!conversation || [conversation isExpandable])
		return;
	
	alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete the conversation with \u201c%@\u201d?", @"Delete conversation dialog title"), [conversation nick]]];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete conversation dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete board button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete board button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteConversationAlertDidEnd:returnCode:contextInfo:)
						contextInfo:[conversation retain]];
}



- (void)deleteConversationAlertDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator		*enumerator;
	WCConversation		*conversation = contextInfo, *eachConversation;
	id					item;
	NSInteger			row;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		enumerator = [[_conversations conversations] objectEnumerator];
		
		while((eachConversation = [enumerator nextObject]))
			[eachConversation removeConversation:conversation];

		[self _saveMessages];

		[_conversationsOutlineView reloadData];
		
		[_selectedConversation release];
		_selectedConversation = NULL;
		
		row = [_conversationsOutlineView selectedRow];
		
		if(row >= 0) {
			item = [_conversationsOutlineView itemAtRow:row];
		
			if(item == _messageConversations || item == _broadcastConversations)
				[_conversationsOutlineView deselectAll:self];
			else
				_selectedConversation = [item retain];
		}

		[self _validate];
		[self _reloadConversation];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];
	}
	
	[conversation release];
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		item = _conversations;
	
	return [item numberOfConversations];
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(!item)
		item = _conversations;
	
	return [item conversationAtIndex:index];
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSDictionary	*attributes;
	NSString		*name;
	
	if(tableColumn == _conversationTableColumn) {
		name = [item name];
		
		if(item == _messageConversations || item == _broadcastConversations) {
			attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSColor colorWithCalibratedRed:96.0 / 255.0 green:110.0 / 255.0 blue:128.0 / 255.0 alpha:1.0],
					NSForegroundColorAttributeName,
				[NSFont boldSystemFontOfSize:11.0],
					NSFontAttributeName,
				NULL];
			
			return [NSAttributedString attributedStringWithString:[name uppercaseString] attributes:attributes];
		}
		
		return name;
	}
	else if(tableColumn == _unreadTableColumn) {
		return [NSImage imageWithPillForCount:[item numberOfUnreadMessagesForConnection:NULL includeChildConversations:NO]
							   inActiveWindow:([NSApp keyWindow] == [self window])
								onSelectedRow:([_conversationsOutlineView rowForItem:item] == [_conversationsOutlineView selectedRow])];
	}
	
	return NULL;
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if(tableColumn == _conversationTableColumn) {
		if([item numberOfUnreadMessagesForConnection:NULL includeChildConversations:NO] > 0)
			[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
		else
			[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
		
		if(item == _messageConversations || item == _broadcastConversations)
			[cell setImage:NULL];
		else
			[cell setImage:_conversationIcon];
	}
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return [item isExpandable];
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	WCConversation	*conversation;
	NSInteger		row;
	
	row = [_conversationsOutlineView selectedRow];
	
	if(row < 0) {
		[_selectedConversation release];
		_selectedConversation = NULL;
	} else {
		conversation = [_conversationsOutlineView itemAtRow:row];

		[conversation retain];
		[_selectedConversation release];
		
		_selectedConversation = conversation;
	}
	
	[self _reloadConversation];
	[self _validate];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
	if(item == _messageConversations || item == _broadcastConversations)
		return NO;
	
	return YES;
}

@end
