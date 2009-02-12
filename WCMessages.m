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

@interface WCMessages(Private)

- (void)_validate;
- (void)_themeDidChange;

- (void)_showDialogForMessage:(WCMessage *)message;
- (NSString *)_stringForMessageString:(NSString *)string;

- (WCConversation *)_selectedConversation;
- (void)_readMessages;
- (void)_saveMessages;
- (void)_removeAllMessages;

- (void)_reselectConversation:(WCConversation *)conversation message:(WCMessage *)message;

- (void)_reloadConversation;
- (NSString *)_HTMLStringForMessage:(WCMessage *)message;
- (NSString *)_HTMLStringForStatus:(NSString *)status;

@end


@implementation WCMessages(Private)

- (void)_validate {
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_themeDidChange {
	NSDictionary		*theme;
	
	theme = [WCSettings themeWithIdentifier:[WCSettings objectForKey:WCTheme]];
	
	[_messageColor release];
	_messageColor = [WIColorFromString([theme objectForKey:WCThemesMessagesTextColor]) retain];
	
	[_messageFont release];
	_messageFont = [WIFontFromString([theme objectForKey:WCThemesMessagesFont]) retain];
	
/*	[_messageTextView setFont:_messageFont];
	[_messageTextView setTextColor:_messageColor];
	[_messageTextView setBackgroundColor:WIColorFromString([theme objectForKey:WCThemesMessagesBackgroundColor])];

	[_messageTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		WIColorFromString([theme objectForKey:WCThemesURLsColor]),
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];*/
	
/*	[_replyTextView setFont:_messageFont];
	[_replyTextView setTextColor:_messageColor];
	[_replyTextView setInsertionPointColor:_messageColor];
	[_replyTextView setBackgroundColor:WIColorFromString([theme objectForKey:WCThemesMessagesBackgroundColor])];*/

	[_broadcastTextView setFont:_messageFont];
	[_broadcastTextView setTextColor:_messageColor];
	[_broadcastTextView setInsertionPointColor:_messageColor];
	[_broadcastTextView setBackgroundColor:WIColorFromString([theme objectForKey:WCThemesMessagesBackgroundColor])];
	
/*	if([theme boolForKey:WCThemesShowSmileys] != _showSmileys) {
		_showSmileys = !_showSmileys;
		
		if(_showSmileys) {
			[WCChatController applySmileyAttributesToAttributedString:[_messageTextView textStorage]];
		} else {
			[[_messageTextView textStorage] replaceAttachmentsWithStrings];
			
			[self _applyMessageAttributesToAttributedString:[_messageTextView textStorage]];
		}
	}*/
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



#pragma mark -

- (WCConversation *)_selectedConversation {
	return _selectedConversation;
}



- (void)_saveMessages {
	[WCSettings setObject:[NSKeyedArchiver archivedDataWithRootObject:[_messageConversations conversations]]
				   forKey:WCMessageConversations];
	
	[WCSettings setObject:[NSKeyedArchiver archivedDataWithRootObject:[_broadcastConversations conversations]]
				   forKey:WCBroadcastConversations];
}



- (void)_readMessages {
	NSArray			*messages;
	WCMessage		*message;
	NSUInteger		i, count;
	BOOL			changedUnread = NO;
	
	messages = [_conversations unreadMessages];
	count = [messages count];
	
	for(i = 0; i < count; i++) {
		message = [messages objectAtIndex:i];
		
		if([message isUnread]) {
			[message setUnread:NO];
			
			changedUnread = YES;
		}
	}

	if(changedUnread) {
		[[NSNotificationCenter defaultCenter] postNotificationName:WCMessagesDidChangeUnreadCountNotification];

		[_conversationsOutlineView setNeedsDisplay:YES];
	}
}



- (void)_removeAllMessages {
	NSEnumerator	*enumerator;
	WCConversation	*conversation;
	
	enumerator = [[_conversations conversations] objectEnumerator];
	
	while((conversation = [enumerator nextObject]))
		[conversation removeAllConversations];
}



#pragma mark -

- (void)_reselectConversation:(WCConversation *)conversation message:(WCMessage *)message {
//	NSUInteger		i, index;
	NSInteger		row;
	
	row = [_conversationsOutlineView rowForItem:conversation];
	
	if(row >= 0)
		[_conversationsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

/*	row = [[[self _selectedConversation] messages] indexOfObject:message];
	
	if(row >= 0) {
		index = row;
		i = ([_messagesTableView sortOrder] == WISortDescending)
			? [[self _selectedConversation] numberOfMessages] - index - 1
			: index;
		
		[_messagesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
	}*/
}



#pragma mark -

- (void)_reloadConversation {
	NSEnumerator		*enumerator;
	NSMutableString		*html;
	NSCalendar			*calendar;
	NSDateComponents	*components;
	WCConversation		*conversation;
	WCMessage			*message;
	NSInteger			day;
	BOOL				changedUnread = NO;
	
	conversation = [self _selectedConversation];
	
	html = [NSMutableString stringWithString:_headerTemplate];
	
//	[html replaceOccurrencesOfString:@"<? fontname ?>" withString:[_threadFont fontName]];
//	[html replaceOccurrencesOfString:@"<? fontsize ?>" withString:[NSSWF:@"%.0fpx", [_threadFont pointSize]]];
//	[html replaceOccurrencesOfString:@"<? textcolor ?>" withString:[NSSWF:@"#%.6x", [_threadColor HTMLValue]]];
//	[html replaceOccurrencesOfString:@"<? backgroundcolor ?>" withString:[NSSWF:@"#%.6x", [_backgroundColor HTMLValue]]];

	if(conversation) {
		calendar	= [NSCalendar currentCalendar];
		day			= -1;
		enumerator	= [[conversation messages] objectEnumerator];
		
		while((message = [enumerator nextObject])) {
			components = [calendar components:NSDayCalendarUnit fromDate:[message date]];
			
			if([components day] != day) {
				[html appendString:[self _HTMLStringForStatus:[_messageStatusDateFormatter stringFromDate:[message date]]]];
				
				day = [components day];
			}
			
			[html appendString:[self _HTMLStringForMessage:message]];
			
			if([message isUnread]) {
				[message setUnread:NO];
				
				changedUnread = YES;
			}
		}
		
/*		if([thread isUnread]) {
			[thread setUnread:NO];
			
			changedUnread = YES;
		}*/
	}
	
	[html appendString:_footerTemplate];
	
	[[_messageWebView mainFrame] loadHTMLString:html baseURL:[NSURL fileURLWithPath:[[self bundle] resourcePath]]];
	
/*	if(changedUnread) {
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBoardsDidChangeUnreadCountNotification];
			
		[WCSettings setObject:[_readPosts allObjects] forKey:WCReadBoardPosts];
		
		[_boardsOutlineView setNeedsDisplay:YES];
		[_threadsTableView setNeedsDisplay:YES];
	}*/
}



- (NSString *)_HTMLStringForMessage:(WCMessage *)message {
	NSEnumerator		*enumerator;
	NSDictionary		*theme;
	NSMutableString		*string, *text;
	NSString			*smiley, *path, *icon;
	WCAccount			*account;
	
	theme		= [[message connection] theme];
	account		= [[message connection] account];
	text		= [[[message message] mutableCopy] autorelease];
	
	[text replaceOccurrencesOfString:@"&" withString:@"&#38;"];
	[text replaceOccurrencesOfString:@"<" withString:@"&#60;"];
	[text replaceOccurrencesOfString:@">" withString:@"&#62;"];
	[text replaceOccurrencesOfString:@"\"" withString:@"&#34;"];
	[text replaceOccurrencesOfString:@"\'" withString:@"&#39;"];
	[text replaceOccurrencesOfString:@"\n" withString:@"<br />"];

	[text replaceOccurrencesOfRegex:[WCChatController URLRegex] withString:@"<a href=\"$1\">$1</a>" options:RKLCaseless];
	[text replaceOccurrencesOfRegex:[WCChatController mailtoURLRegex] withString:@"<a href:\"mailto:$1\">$1</a>" options:RKLCaseless];
	
	if([theme boolForKey:WCThemesShowSmileys]) {
		enumerator = [[[WCApplicationController sharedController] allSmileys] objectEnumerator];
		
		while((smiley = [enumerator nextObject])) {
			path = [[WCApplicationController sharedController] pathForSmiley:smiley];
			
			[text replaceOccurrencesOfString:smiley withString:[NSSWF:@"<img src=\"%@\" alt=\"%@\" />", path, smiley]];
		}
	}

	string = [[_messageTemplate mutableCopy] autorelease];

	[string replaceOccurrencesOfString:@"<? nick ?>" withString:[message nick]];
	[string replaceOccurrencesOfString:@"<? time ?>" withString:[_messageTimeDateFormatter stringFromDate:[message date]]];
	[string replaceOccurrencesOfString:@"<? body ?>" withString:text];
	
	icon = [[[[message user] icon] TIFFRepresentation] base64EncodedString];
	
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
		   selector:@selector(chatUserAppeared:)
			   name:WCChatUserAppearedNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatUserDisappeared:)
			   name:WCChatUserDisappearedNotification];
	
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
	NSToolbar	*toolbar;
	NSData		*data;
	NSArray		*array;
	
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

	[[_conversationTableColumn dataCell] setVerticalTextOffset:3.0];
	[[_unreadTableColumn dataCell] setImageAlignment:NSImageAlignRight];
	
	_conversations			= [[WCConversation rootConversation] retain];
	_messageConversations	= [[WCMessageConversation rootConversation] retain];
	_broadcastConversations	= [[WCBroadcastConversation rootConversation] retain];
	
	data = [WCSettings objectForKey:WCMessageConversations];
	
	if(data) {
		array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		
		[_messageConversations addConversations:array];
	}
	
	data = [WCSettings objectForKey:WCBroadcastConversations];
	
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
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"Reply"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reply", @"Reply message toolbar item")
												content:[NSImage imageNamed:@"ReplyMessage"]
												 target:self
												 action:@selector(reply:)];
	}
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
		@"Reply",
		@"RevealInUserList",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Clear",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Reply",
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
}



- (void)chatUserAppeared:(NSNotification *)notification {
	WCUser		*user;
	
	user = [notification object];
	
	[_conversations revalidateForConnection:[user connection] user:user];
}



- (void)chatUserDisappeared:(NSNotification *)notification {
	WCUser		*user;
	
	user = [notification object];
	
	[_conversations invalidateForConnection:[user connection] user:user];
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
	
//	selectedMessage = [self _selectedMessage];
	selectedConversation = [self _selectedConversation];

	message = [WCPrivateMessage messageWithMessage:[p7Message stringForName:@"wired.message.message"]
											  user:user
										connection:connection];

	[conversation addMessage:message];
	[message setConversation:conversation];

	[self _saveMessages];
	
	[_conversationsOutlineView reloadData];
//	[_messagesTableView reloadData];
	
	[self _reselectConversation:selectedConversation message:NULL];

	if([[WCSettings eventWithTag:WCEventsMessageReceived] boolForKey:WCEventsShowDialog])
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

//	selectedMessage = [self _selectedMessage];
	selectedConversation = [self _selectedConversation];

	message = [WCBroadcastMessage broadcastWithMessage:[p7Message stringForName:@"wired.message.broadcast"]
												  user:user
											connection:connection];
	
	[conversation addMessage:message];
	[message setConversation:conversation];

	[self _saveMessages];

	[_conversationsOutlineView reloadData];
//	[_messagesTableView reloadData];
	
	[self _reselectConversation:selectedConversation message:NULL];

	if([[WCSettings eventWithTag:WCEventsBroadcastReceived] boolForKey:WCEventsShowDialog])
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
	BOOL		value = NO;

	if(textView == _broadcastTextView) {
		if(selector == @selector(insertNewline:)) {
			if([[NSApp currentEvent] character] == NSEnterCharacter) {
				[self submitSheet:textView];

				value = YES;
			}
		}
	}
	else if(textView == _messageTextView2) {
		NSLog(@"hai");
	}

	return value;
}



- (void)webView:(WebView *)webView didFinishLoadForFrame:(WebFrame *)frame {
	NSRect		rect;
	
	rect = [[[[[_messageWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y = rect.size.height;
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
	
	if(selector == @selector(reply:))
		return NO;
	else if(selector == @selector(revealInUserList:))
		return ([[[[self _selectedConversation] messages] lastObject] user] != NULL);
	else if(selector == @selector(clearMessages:))
		return ([_messageConversations numberOfConversations] > 0 || [_broadcastConversations numberOfConversations] > 0);
	
	return YES;
}



#pragma mark -

- (void)showNextUnreadConversation {
//	WCConversation	*conversation;
	NSRect			rect;
	
	rect = [[[[[_messageWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y += 0.9 * rect.size.height;
	
	if([[[[_messageWebView mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return;

/*	WCMessage		*message;
	NSRect			rect;
	
	rect = [[_messageTextView enclosingScrollView] documentVisibleRect];
	rect.origin.y += 0.9 * rect.size.height;
	
	if([_messageTextView scrollRectToVisible:rect])
		return;
		
	message = [_conversations nextUnreadMessageStartingAtConversation:[self _selectedConversation]
															  message:[self _selectedMessage]
												   forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(!message)
		message = [_conversations nextUnreadMessageStartingAtConversation:NULL message:NULL forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(message) {
		[[self window] makeFirstResponder:_messagesTableView];
		
		[self _selectMessage:message];
	}*/
}



- (void)showPreviousUnreadConversation {
//	WCConversation	*conversation;
	NSRect			rect;
	
	rect = [[[[[_messageWebView mainFrame] frameView] documentView] enclosingScrollView] documentVisibleRect];
	rect.origin.y -= 0.9 * rect.size.height;
	
	if([[[[_messageWebView mainFrame] frameView] documentView] scrollRectToVisible:rect])
		return;
	
/*	WCMessage		*message;
	NSRect			rect;
	
	rect = [[_messageTextView enclosingScrollView] documentVisibleRect];
	
	rect.origin.y -= 0.9 * rect.size.height;
	
	if([_messageTextView scrollRectToVisible:rect])
		return;
	
	message = [_conversations previousUnreadMessageStartingAtConversation:[self _selectedConversation]
																  message:[self _selectedMessage]
													   forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(!message)
		message = [_conversations previousUnreadMessageStartingAtConversation:NULL message:NULL forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(message) {
		[[self window] makeFirstResponder:_messagesTableView];
	
		[self _selectMessage:message];
	}*/
}



- (void)showPrivateMessageToUser:(WCUser *)user {
	[self showPrivateMessageToUser:user message:@""];
}



- (void)showPrivateMessageToUser:(WCUser *)user message:(NSString *)message {
/*	[_userTextField setStringValue:[user nick]];
	[_replyTextView setString:message];
	
	[self showWindow:self];
	
	[NSApp beginSheet:_replyPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(replySheetDidEnd:returnCode:contextInfo:)
		  contextInfo:user];*/
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



- (IBAction)reply:(id)sender {
/*	WCMessage   *message;
	WCError		*error;
	
	message = [self _selectedMessage];
	
	if(!message)
		return;
	
	if(![[message connection] isConnected]) {
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientNotConnected argument:[message connectionName]]; 
		[[message connection] triggerEvent:WCEventsError info1:error]; 
		[[error alert] beginSheetModalForWindow:[self window]]; 
	} else {
		if([message user]) {
			[self showPrivateMessageToUser:[message user]];
		} else { 
			error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientClientNotFound]; 
			[[message connection] triggerEvent:WCEventsError info1:error]; 
			[[error alert] beginSheetModalForWindow:[self window]]; 
		}
	}*/
}



/*- (void)replySheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*p7Message;
	WCUser			*user = contextInfo;
	WCMessage		*message, *selectedMessage;
	WCConversation  *conversation, *selectedConversation;
	
	if(returnCode == NSAlertDefaultReturn) {
		conversation = [_messageConversations conversationForUser:user connection:[user connection]];
		
		if(!conversation) {
			conversation = [WCMessageConversation conversationWithUser:user connection:[user connection]];
			[_messageConversations addConversation:conversation];
		}
		
		selectedMessage = [self _selectedMessage];
		selectedConversation = [self _selectedConversation];

		message = [WCPrivateMessage messageToUser:user
										  message:[[[_replyTextView string] copy] autorelease]
									   connection:[user connection]];

		[conversation addMessage:message];
		[message setConversation:conversation];
		
		[self _saveMessages];

		p7Message = [WIP7Message messageWithName:@"wired.message.send_message" spec:WCP7Spec];
		[p7Message setUInt32:[[message user] userID] forName:@"wired.user.id"];
		[p7Message setString:[self _stringForMessageString:[message message]] forName:@"wired.message.message"];
		[[message connection] sendMessage:p7Message];

		[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesSent];
		
		[_conversationsOutlineView reloadData];
		[_messagesTableView reloadData];
		
		[self _reselectConversation:selectedConversation message:selectedMessage];
	}
	
	[_replyPanel close];
	[_replyTextView setString:@""];
}*/



- (IBAction)revealInUserList:(id)sender {
	WCUser				*user;
	WCError				*error;
	WCConversation		*conversation;
	
	conversation = [self _selectedConversation];
	
	if(!conversation)
		return;
	
	user = [(WCMessage *) [[conversation messages] lastObject] user];
	
	if(user) {
		[[WCPublicChat publicChat] selectChatController:[[conversation connection] chatController]];
		[[[conversation connection] chatController] selectUser:user];
		[[WCPublicChat publicChat] showWindow:self];
	} else { 
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientClientNotFound]; 
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
	if(returnCode == NSAlertFirstButtonReturn) {
		[self _readMessages];
		[self _removeAllMessages];
		
		[_conversationsOutlineView reloadData];
		
		[self _validate];
	}
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
	if(tableColumn == _conversationTableColumn) {
		return [item name];
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
			[cell setImage:_conversationIcon];
		else
			[cell setImage:NULL];
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
}

@end
