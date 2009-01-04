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
#import "WCConversation.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCServerConnection.h"
#import "WCStats.h"
#import "WCUser.h"

@interface WCMessages(Private)

- (void)_showDialogForMessage:(WCMessage *)message;
- (NSString *)_stringForMessageString:(NSString *)string;

- (void)_validate;
- (void)_update;

- (id)_messageAtIndex:(NSUInteger)index;
- (id)_selectedConversation;
- (id)_selectedMessage;
- (void)_selectMessage:(id)message;
- (void)_readMessages;
- (void)_saveMessages;
- (void)_removeAllMessages;

- (void)_reselectConversation:(WCConversation *)conversation message:(WCMessage *)message;
- (SEL)_sortSelector;

@end


@implementation WCMessages(Private)

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
	
	alert = [NSAlert alertWithMessageText:title
							defaultButton:nil
						  alternateButton:nil
							  otherButton:nil
				informativeTextWithFormat:@"%@", [message message]];
	
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert runNonModal];
	
	[message setRead:YES];
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
		return [WCChat outputForShellCommand:argument];
	else if([command isEqualToString:@"/stats"])
		return [[WCStats stats] stringValue];
	
	return string;
}



#pragma mark -

- (void)_validate {
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_update {
/*	[_messageTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesFont]]];
	[_messageTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesTextColor]]];
	[_messageTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesBackgroundColor]]];
	[_messageTextView setNeedsDisplay:YES];

	[_messageTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatURLsColor]],
			NSForegroundColorAttributeName,
		[NSNumber numberWithInt:NSSingleUnderlineStyle],
			NSUnderlineStyleAttributeName,
		NULL]];
	
	[_replyTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesFont]]];
	[_replyTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesTextColor]]];
	[_replyTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesBackgroundColor]]];
	[_replyTextView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesTextColor]]];
	[_replyTextView setNeedsDisplay:YES];

	[_broadcastTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesFont]]];
	[_broadcastTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesTextColor]]];
	[_broadcastTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesBackgroundColor]]];
	[_broadcastTextView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesTextColor]]];
	[_broadcastTextView setNeedsDisplay:YES];
	
	[_messageTextView setString:[[_messageTextView textStorage] string] withFilter:_messageFilter];

	[_messagesTableView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesListFont]]];
	[_messagesTableView setUsesAlternatingRowBackgroundColors:[WCSettings boolForKey:WCMessagesListAlternateRows]];
	[_messagesTableView setNeedsDisplay:YES];*/
}



#pragma mark -

- (id)_messageAtIndex:(NSUInteger)index {
	id				conversation;
	NSUInteger		i;
	
	conversation = [self _selectedConversation];
	
	if(!conversation)
		return NULL;
	
	i = ([_messagesTableView sortOrder] == WISortDescending)
		? [conversation numberOfMessages] - index - 1
		: index;
	
	return [conversation messageAtIndex:i];
}



- (id)_selectedConversation {
	NSInteger		row;
	
	row = [_conversationsOutlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_conversationsOutlineView itemAtRow:row];
}



- (id)_selectedMessage {
	id				conversation;
	NSInteger		row;
	
	conversation = [self _selectedConversation];
	
	if(!conversation)
		return NULL;
	
	row = [_messagesTableView selectedRow];
	
	if(row < 0)
		return NULL;

	return [self _messageAtIndex:row];
}



- (void)_selectMessage:(id)message {
	WCConversation		*conversation;
	NSUInteger			i, index;
	NSInteger			row;
	
	conversation = [message conversation];
	row = [_conversationsOutlineView rowForItem:conversation];
	
	if(row < 0)
		return;
	
	[_conversationsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	
	index = [[conversation messages] indexOfObject:message];
	
	if(index == NSNotFound)
		return;
	
	i = ([_messagesTableView sortOrder] == WISortDescending)
		? [conversation numberOfMessages] - index - 1
		: index;
	
	[_messagesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
}



- (void)_saveMessages {
	[WCSettings setObject:[NSKeyedArchiver archivedDataWithRootObject:[_messageConversations conversations]] forKey:WCMessageConversations];
	[WCSettings setObject:[NSKeyedArchiver archivedDataWithRootObject:[_broadcastConversations conversations]] forKey:WCBroadcastConversations];
}



- (void)_readMessages {
	NSArray			*messages;
	WCMessage		*message;
	NSUInteger		i, count;
	
	messages = [_conversations unreadMessages];
	count = [messages count];
	
	for(i = 0; i < count; i++) {
		message = [messages objectAtIndex:i];
		[message setRead:YES];
		[[message connection] postNotificationName:WCMessagesDidReadMessage];
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
	NSUInteger		i, index;
	NSInteger		row;
	
	row = [_conversationsOutlineView rowForItem:conversation];
	
	if(row >= 0)
		[_conversationsOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	row = [[[self _selectedConversation] messages] indexOfObject:message];
	
	if(row >= 0) {
		index = row;
		i = ([_messagesTableView sortOrder] == WISortDescending)
			? [[self _selectedConversation] numberOfMessages] - index - 1
			: index;
		
		[_messagesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
	}
}



- (SEL)_sortSelector {
	NSTableColumn	*tableColumn;
	
	tableColumn = [_messagesTableView highlightedTableColumn];
	
	if(tableColumn == _userTableColumn)
		return @selector(compareUser:);
	else if(tableColumn == _timeTableColumn)
		return @selector(compareDate:);

	return @selector(compareDate:);
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
	
	_messageFilter		= [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmilies:), 0];
	_userFilter			= [[WITextFilter alloc] initWithSelectors:@selector(filterWiredSmallSmilies:), 0];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(applicationWillTerminate:)
			   name:NSApplicationWillTerminateNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionLoggedIn:)
			   name:WCLinkConnectionLoggedIn];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidClose:)
			   name:WCLinkConnectionDidClose];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidTerminate:)
			   name:WCLinkConnectionDidTerminate];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatUserAppeared:)
			   name:WCChatUserAppeared];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatUserDisappeared:)
			   name:WCChatUserDisappeared];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_conversations release];

	[_conversationIcon release];
	
	[_messageFilter release];
	[_userFilter release];
	[_conversationIcon release];
	
	[_tableDateFormatter release];
	[_dialogDateFormatter release];

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

	[_messagesTableView setAutosaveName:@"Messages"];
    [_messagesTableView setAutosaveTableColumns:YES];
	[_messagesTableView setDoubleAction:@selector(reply:)];
	[_messagesTableView setAllowsUserCustomization:YES];
	[_messagesTableView setDefaultHighlightedTableColumnIdentifier:@"Time"];
	[_messagesTableView setDefaultSortOrder:WISortAscending];
	
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
	
	[_messageTextView setEditable:NO];
	[_messageTextView setUsesFindPanel:YES];
	
	_tableDateFormatter = [[WIDateFormatter alloc] init];
	[_tableDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_tableDateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_tableDateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	_dialogDateFormatter = [[WIDateFormatter alloc] init];
	[_dialogDateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	[self _update];
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
	WCMessage				*message, *selectedMessage;
	WCConversation			*conversation, *selectedConversation;
	WIP7UInt32				uid;
	
	[p7Message getUInt32:&uid forName:@"wired.user.id"];
	
	connection = [p7Message contextInfo];
	user = [[connection chat] userWithUserID:uid];
	
	if(!user || [user isIgnored])
		return;
	
	conversation = [_messageConversations conversationForUser:user connection:connection];
	
	if(!conversation) {
		conversation = [WCMessageConversation conversationWithUser:user connection:connection];
		[_messageConversations addConversation:conversation];
	}
	
	selectedMessage = [self _selectedMessage];
	selectedConversation = [self _selectedConversation];

	message = [WCPrivateMessage messageWithMessage:[p7Message stringForName:@"wired.message.message"]
											  user:user
										connection:connection];

	[conversation addMessage:message];
	[message setConversation:conversation];

	[self _saveMessages];
	
	[_conversationsOutlineView reloadData];
	[_messagesTableView reloadData];
	
	[self _reselectConversation:selectedConversation message:selectedMessage];

	if([[WCSettings eventWithTag:WCEventsMessageReceived] boolForKey:WCEventsShowDialog])
		[self _showDialogForMessage:message];

	[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesReceived];

	[connection postNotificationName:WCMessagesDidAddMessage object:message];
	[connection triggerEvent:WCEventsMessageReceived info1:message];
	
	[self _validate];
}



- (void)wiredMessageBroadcast:(WIP7Message *)p7Message {
	WCServerConnection	*connection;
	WCUser				*user;
	WCMessage			*message, *selectedMessage;
	WCConversation		*conversation, *selectedConversation;
	WIP7UInt32			uid;
	
	[p7Message getUInt32:&uid forName:@"wired.user.id"];
	
	connection = [p7Message contextInfo];
	user = [[connection chat] userWithUserID:uid];
	
	if(!user || [user isIgnored])
		return;

	conversation = [_broadcastConversations conversationForUser:user connection:connection];
	
	if(!conversation) {
		conversation = [WCBroadcastConversation conversationWithUser:user connection:connection];
		[_broadcastConversations addConversation:conversation];
	}

	selectedMessage = [self _selectedMessage];
	selectedConversation = [self _selectedConversation];

	message = [WCBroadcastMessage broadcastWithMessage:[p7Message stringForName:@"wired.message.broadcast"]
												  user:user
											connection:connection];
	
	[conversation addMessage:message];
	[message setConversation:conversation];

	[self _saveMessages];

	[_conversationsOutlineView reloadData];
	[_messagesTableView reloadData];
	
	[self _reselectConversation:selectedConversation message:selectedMessage];

	if([[WCSettings eventWithTag:WCEventsBroadcastReceived] boolForKey:WCEventsShowDialog])
		[self _showDialogForMessage:message];

	[connection postNotificationName:WCMessagesDidAddMessage object:message];
	[connection triggerEvent:WCEventsBroadcastReceived info1:message];
	
	[self _validate];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
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
		topSize = [_messageListView frame].size;
		topSize.width = size.width;
		bottomSize.width = size.width;
		bottomSize.height = size.height - [_messagesSplitView dividerThickness] - topSize.height;
		
		[_messageListView setFrameSize:topSize];
		[_messageView setFrameSize:bottomSize];
	}
	
	[splitView adjustSubviews];
}



- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	return YES;
}



- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
	BOOL		value = NO;

	if(selector == @selector(insertNewline:)) {
		if([[NSApp currentEvent] character] == NSEnterCharacter) {
			[self submitSheet:textView];

			value = YES;
		}
	}

	return value;
}



#pragma mark -

- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCMessage		*message;
	SEL				selector;
	
	selector = [item action];
	message = [self _selectedMessage];
	
	if(selector == @selector(reply:))
		return (message != NULL && [message user] && [[message connection] isConnected]);
	else if(selector == @selector(revealInUserList:))
		return ([[[[self _selectedConversation] messages] lastObject] user] != NULL);
	else if(selector == @selector(clearMessages:))
		return ([_messageConversations numberOfConversations] > 0 || [_broadcastConversations numberOfConversations] > 0);
	
	return YES;
}



#pragma mark -

- (void)showNextUnreadMessage {
	WCMessage		*message;
	
	message = [_conversations nextUnreadMessageStartingAtConversation:[self _selectedConversation]
															  message:[self _selectedMessage]
												   forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(!message)
		message = [_conversations nextUnreadMessageStartingAtConversation:NULL message:NULL forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(message)
		[self _selectMessage:message];
}



- (void)showPreviousUnreadMessage {
	WCMessage		*message;
	
	message = [_conversations previousUnreadMessageStartingAtConversation:[self _selectedConversation]
																  message:[self _selectedMessage]
													   forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(!message)
		message = [_conversations previousUnreadMessageStartingAtConversation:NULL message:NULL forwardsInMessages:([_messagesTableView sortOrder] == WISortAscending)];
	
	if(message)
		[self _selectMessage:message];
}



- (void)showPrivateMessageReply {
	[self reply:self];
}



- (void)showPrivateMessageToUser:(WCUser *)user {
	[self showPrivateMessageToUser:user message:@""];
}



- (void)showPrivateMessageToUser:(WCUser *)user message:(NSString *)message {
	[_userTextField setStringValue:[user nick]];
	[_replyTextView setString:message];
	
	[self showWindow:self];
	
	[NSApp beginSheet:_replyPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(replySheetDidEnd:returnCode:contextInfo:)
		  contextInfo:user];
}



- (void)showBroadcastForConnection:(WCServerConnection *)connection {
	[self showWindow:self];

	[NSApp beginSheet:_broadcastPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(broadcastSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:connection];
}



- (NSUInteger)numberOfUnreadMessagesForConnection:(WCServerConnection *)connection {
	return [_conversations numberOfUnreadMessagesForConnection:connection];
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
	WCMessage   *message;
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
	}
}



- (void)replySheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
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
}



- (IBAction)revealInUserList:(id)sender {
	WCUser				*user;
	WCError				*error;
	WCConversation		*conversation;
	
	conversation = [self _selectedConversation];
	
	if(!conversation)
		return;
	
	user = [(WCMessage *) [[conversation messages] lastObject] user];
	
	if(user) {
		[[[conversation connection] chat] selectUser:user];
		[[[conversation connection] chat] showWindow:self];
	} else { 
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientClientNotFound]; 
		[[conversation connection] triggerEvent:WCEventsError info1:error]; 
		[[error alert] beginSheetModalForWindow:[self window]]; 
	} 
}



- (IBAction)clearMessages:(id)sender {
	NSBeginAlertSheet(NSLS(@"Are you sure you want to clear the message history?", @"Clear messages dialog title"),
					  NSLS(@"Clear", @"Clear messages dialog button"),
					  NSLS(@"Cancel", @"Clear messages dialog button"),
					  NULL,
					  [self window],
					  self,
					  @selector(clearSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Clear messages dialog description"));
}



- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertDefaultReturn) {
		[self _readMessages];
		
		[self _removeAllMessages];
		
		[_conversationsOutlineView reloadData];
		[_messagesTableView reloadData];
		
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
	NSString		*name;
	NSUInteger		unread;
	
	name = [item name];
	unread = [item numberOfUnreadMessages];
	
	if(unread > 0)
		name = [name stringByAppendingFormat:@" (%lu)", unread];
	
	return [[NSAttributedString attributedStringWithString:name] attributedStringByApplyingFilter:_userFilter];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if([item numberOfUnreadMessages] > 0)
		[cell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	else
		[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	
	if(item == _messageConversations || item == _broadcastConversations)
		[cell setImage:_conversationIcon];
	else
		[cell setImage:NULL];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return [item isExpandable];
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	[[self _selectedConversation] sortMessagesUsingSelector:[self _sortSelector]];

	[_messagesTableView reloadData];
	[_messagesTableView deselectAll:self];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [[self _selectedConversation] numberOfMessages];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	NSString			*string;
	WCMessage			*message;
	
	message = [self _messageAtIndex:row];
	
	if(column == _userTableColumn) {
		if([message direction] == WCMessageTo)
			string = [NSSWF:NSLS(@"To: %@", @"Message to (nick)"), [message nick]];
		else
			string = [NSSWF:NSLS(@"From: %@", @"Message from (nick)"), [message nick]];

		return [[NSAttributedString attributedStringWithString:string] attributedStringByApplyingFilter:_userFilter];
	}
	else if(column == _timeTableColumn) {
		return [_tableDateFormatter stringFromDate:[message date]];
	}
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	WCMessage		*message;
	
	message = [self _messageAtIndex:row];
	
	if(![message isRead])
		[cell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	else
		[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_messagesTableView setHighlightedTableColumn:tableColumn];
	[[self _selectedConversation] sortMessagesUsingSelector:[self _sortSelector]];
	[_messagesTableView reloadData];
	[[_messagesTableView delegate] tableViewSelectionDidChange:NULL];
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	WCMessage   *message;
	
	message = [self _selectedMessage];
	
	if(!message) {
		[_messageTextView setString:@""];
	} else {
		if(![message isRead]) {
			[message setRead:YES];
			[_conversationsOutlineView setNeedsDisplay:YES];
			[_messagesTableView setNeedsDisplay:YES];
					
			[[message connection] postNotificationName:WCMessagesDidReadMessage];
		}
		
		[_messageTextView setString:[message message] withFilter:_messageFilter];
	}
	
	[self _validate];
}

@end
