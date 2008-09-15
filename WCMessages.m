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

static NSInteger _WCMessagesCompareMessages(id, id, void *);


static NSInteger _WCMessagesCompareMessages(id message1, id message2, void *contextInfo) {
	NSComparisonResult	result;
	
	result = [message1 compareClass:message2];
	
	if(result != NSOrderedSame)
		return result;
	
	return (NSComparisonResult) [message1 performSelector:(SEL) contextInfo withObject:message2];
}



@interface WCMessages(Private)

+ (NSString *)_conversationKeyForClass:(Class)class user:(WCUser *)user connection:(WCServerConnection *)connection;

- (void)_showDialogForMessage:(WCMessage *)message;

- (void)_validate;
- (void)_update;

- (NSArray *)_conversationsOfClass:(Class)class;
- (NSArray *)_messagesOfClass:(Class)class;
- (NSArray *)_unreadMessagesOfClass:(Class)class;
- (NSArray *)_messagesForConversation:(WCConversation *)conversation unreadOnly:(BOOL)unreadOnly;
- (NSArray *)_messagesSortedForView;
- (id)_selectedMessageBox;
- (WCConversation *)_selectedConversation;
- (WCMessage *)_selectedMessage;
- (WCMessage *)_selectedMessageForTraversing;
- (WCMessage *)_messageAtIndex:(NSUInteger)index;
- (void)_selectMessage:(WCMessage *)message;
- (SEL)_sortSelector;
- (void)_readMessages;
- (void)_removeAllMessages;
- (void)_removeAllConversations;

@end


@implementation WCMessages(Private)

+ (NSString *)_conversationKeyForClass:(Class)class user:(WCUser *)user connection:(WCServerConnection *)connection {
	return [NSSWF:@"%@_%u_%@", NSStringFromClass(class), [user userID], [connection URL]];
}



#pragma mark -

- (void)_showDialogForMessage:(WCMessage *)message {
	NSAlert		*alert;
	NSString	*title, *nick, *server, *time;
	
	nick	= [message userNick];
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



#pragma mark -

- (void)_validate {
	[[[self window] toolbar] validateVisibleItems];
}



- (void)_update {
	[_messageTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCMessagesFont]]];
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
	[_messagesTableView setNeedsDisplay:YES];
}



#pragma mark -

- (NSArray *)_conversationsOfClass:(Class)class {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCConversation	*conversation;
	
	array = [NSMutableArray array];
	enumerator = [_allConversations objectEnumerator];
	
	while((conversation = [enumerator nextObject])) {
		if([conversation messageClass] == class)
			[array addObject:conversation];
	}
	
	[array reverse];
	
	return array;
}



- (NSArray *)_messagesOfClass:(Class)class {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCMessage		*message;
	
	array = [NSMutableArray array];
	enumerator = [_allMessages objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if([message isKindOfClass:class])
			[array addObject:message];
	}
	
	return array;
}



- (NSArray *)_unreadMessagesOfClass:(Class)class {
	NSEnumerator	*enumerator;
	NSMutableArray	*array;
	WCMessage		*message;
	
	array = [NSMutableArray array];
	enumerator = [[self _messagesOfClass:class] objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if(![message isRead])
			[array addObject:message];
	}
	
	return array;
}



- (NSArray *)_messagesForConversation:(WCConversation *)conversation unreadOnly:(BOOL)unreadOnly {
	NSMutableArray		*messages;
	NSUInteger			i, count;
	
	messages = [[conversation messages] mutableCopy];
	
	if(unreadOnly) {
		count = [messages count];
		
		for(i = 0; i < count; i++) {
			if([[messages objectAtIndex:i] isRead]) {
				[messages removeObjectAtIndex:i];
				
				i--;
				count--;
			}
		}
	}
	
	return [messages autorelease];
}



- (NSArray *)_messagesSortedForView {
	NSMutableArray		*array;
	NSMutableArray		*messages;
	WISortOrder			order;
	
	array = [NSMutableArray array];
	order = [_messagesTableView sortOrder];
	
	messages = [[[self _messagesOfClass:[WCPrivateMessage class]] mutableCopy] autorelease];
	[messages sortUsingFunction:_WCMessagesCompareMessages context:[self _sortSelector]];
	
	if(order == WISortDescending)
		[messages reverse];
	
	[array addObjectsFromArray:messages];
	
	messages = [[[self _messagesOfClass:[WCBroadcastMessage class]] mutableCopy] autorelease];
	[messages sortUsingFunction:_WCMessagesCompareMessages context:[self _sortSelector]];
	
	if(order == WISortDescending)
		[messages reverse];
	
	[array addObjectsFromArray:messages];
	
	return array;
}



- (id)_selectedMessageBox {
	NSInteger		row;
	
	row = [_conversationsOutlineView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [_conversationsOutlineView itemAtRow:row];
}



- (WCConversation *)_selectedConversation {
	id		messageBox;
	
	messageBox = [self _selectedMessageBox];
	
	if([messageBox isKindOfClass:[WCConversation class]])
		return messageBox;
	
	return NULL;
}



- (WCMessage *)_selectedMessage {
	NSInteger		row;
	
	row = [_messagesTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [self _messageAtIndex:row];
}



- (WCMessage *)_selectedMessageForTraversing {
	NSArray				*messages;
	WCConversation		*conversation;
	WCMessage			*message;
	Class				class;
	id					messageBox;
	
	message = [self _selectedMessage];
	
	if(message)
		return message;
	
	class = [WCPrivateMessage class];
	messageBox = [self _selectedMessageBox];
	
	if(messageBox) {
		if([messageBox isKindOfClass:[NSString class]]) {
			if([_titles indexOfObject:messageBox] == 0)
				class = [WCPrivateMessage class];
			else if([_titles indexOfObject:messageBox] == 1)
				class = [WCBroadcastMessage class];
		}
		else if([messageBox isKindOfClass:[WCConversation class]]) {
			conversation = messageBox;
			class = [conversation messageClass];
		}
	}
	
	messages = [self _messagesOfClass:class];
	
	if([messages count] > 0)
		return [messages objectAtIndex:0];
	
	class = (class == [WCPrivateMessage class]) ? [WCBroadcastMessage class] : [WCPrivateMessage class];
	
	messages = [self _messagesOfClass:class];
	
	if([messages count] > 0)
		return [messages objectAtIndex:0];
	
	return NULL;
}



- (WCMessage *)_messageAtIndex:(NSUInteger)index {
	NSUInteger		i;
	
	i = ([_messagesTableView sortOrder] == WISortDescending)
		? [_shownMessages count] - index - 1
		: index;

	return [_shownMessages objectAtIndex:i];
}



- (void)_selectMessage:(WCMessage *)message {
	WCConversation		*conversation;
	NSUInteger			i, index;
	NSInteger			row;
	
	conversation = [message conversation];
	row = [_conversationsOutlineView rowForItem:conversation];
	
	if(row < 0)
		return;
	
	[_conversationsOutlineView selectRow:row byExtendingSelection:NO];
	
	index = [_shownMessages indexOfObject:message];
	
	if(index == NSNotFound)
		return;
	
	i = ([_messagesTableView sortOrder] == WISortDescending)
		? [_shownMessages count] - index - 1
		: index;

	[_messagesTableView selectRow:i byExtendingSelection:NO];
}



- (void)_sortMessages {
	[_shownMessages sortUsingSelector:[self _sortSelector]];
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



- (void)_readMessages {
	NSEnumerator	*enumerator;
	WCMessage		*message;
	
	enumerator = [_allMessages objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if(![message isRead]) {
			[message setRead:YES];
						
			[[message connection] postNotificationName:WCMessagesDidReadMessage];
		}
	}
}



- (void)_removeAllMessages {
	[_allMessages removeAllObjects];
	[_shownMessages removeAllObjects];
	[_conversationsOutlineView reloadData];
	[_messagesTableView reloadData];
}



- (void)_removeAllConversations {
	[_allConversations removeAllObjects];
	[_conversations removeAllObjects];
	[_conversationsOutlineView reloadData];
	[_messagesTableView reloadData];
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

	_titles = [[NSMutableArray alloc] init];
	[_titles addObject:NSLS(@"Conversations", @"Messages item")];
	[_titles addObject:NSLS(@"Broadcasts", @"Messages item")];

	_allConversations	= [[NSMutableArray alloc] init];
	_conversations		= [[NSMutableDictionary alloc] init];
	_allMessages		= [[NSMutableArray alloc] init];
	_shownMessages		= [[NSMutableArray alloc] init];
	_conversationIcon	= [[NSImage imageNamed:@"Conversation"] retain];
	
	_messageFilter	= [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmilies:), 0];
	_userFilter		= [[WITextFilter alloc] initWithSelectors:@selector(filterWiredSmallSmilies:), 0];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChange];

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

	[self window];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_titles release];
	[_allConversations release];
	[_conversations release];
	[_allMessages release];
	[_shownMessages release];
	
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
	[_conversationsOutlineView expandItem:[_titles objectAtIndex:0]];
	[_conversationsOutlineView expandItem:[_titles objectAtIndex:1]];
	
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



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	NSEnumerator			*enumerator;
	WCServerConnection		*connection;
	WCMessage				*message;

	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	connection = [notification object];
	enumerator = [_allMessages objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if([message belongsToConnection:connection])
			[message setConnection:connection];
	}
	
	[connection addObserver:self selector:@selector(wiredMessageMessage:) messageName:@"wired.message.message"];
	[connection addObserver:self selector:@selector(wiredMessageBroadcast:) messageName:@"wired.message.broadcast"];
	
	[self _validate];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	[self _validate];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	NSEnumerator			*enumerator;
	WCServerConnection		*connection;
	WCMessage				*message;
	
	if(![[notification object] isKindOfClass:[WCServerConnection class]])
		return;

	connection = [notification object];
	enumerator = [_allMessages objectEnumerator];

	while((message = [enumerator nextObject])) {
		if([message connection] == connection)
			[message setConnection:NULL];
	}
	
	[self _validate];
}



- (void)wiredMessageMessage:(WIP7Message *)p7Message {
	NSString			*key;
	WCServerConnection	*connection;
	WCUser				*user;
	WCMessage			*message;
	WCConversation		*conversation;
	WIP7UInt32			uid;
	
	[p7Message getUInt32:&uid forName:@"wired.user.id"];
	
	connection = [p7Message contextInfo];
	user = [[connection chat] userWithUserID:uid];
	
	if(!user || [user isIgnored])
		return;
	
	message = [WCPrivateMessage messageWithMessage:[p7Message stringForName:@"wired.message.message"]
											  user:user
										connection:connection];

	key = [[self class] _conversationKeyForClass:[message class] user:user connection:connection];
	conversation = [_conversations objectForKey:key];
	
	if(conversation) {
		[conversation addMessage:message];
	} else {
		conversation = [WCConversation conversationWithMessage:message];
		[_allConversations addObject:conversation];
		[_conversations setObject:conversation forKey:key];
	}
	
	[message setConversation:conversation];

	[_allMessages addObject:message];
	
	[_conversationsOutlineView reloadData];
	[[_conversationsOutlineView delegate] outlineViewSelectionDidChange:NULL];
	
	if([[WCSettings eventForTag:WCEventsMessageReceived] boolForKey:WCEventsShowDialog])
		[self _showDialogForMessage:message];

	[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesReceived];

	[connection postNotificationName:WCMessagesDidAddMessage object:message];
	[connection triggerEvent:WCEventsMessageReceived info1:message];
	
	[self _validate];
}



- (void)wiredMessageBroadcast:(WIP7Message *)p7Message {
	NSString			*key;
	WCServerConnection	*connection;
	WCUser				*user;
	WCMessage			*message;
	WCConversation		*conversation;
	WIP7UInt32			uid;
	
	[p7Message getUInt32:&uid forName:@"wired.user.id"];
	
	connection = [p7Message contextInfo];
	user = [[connection chat] userWithUserID:uid];
	
	if(!user || [user isIgnored])
		return;

	message = [WCBroadcastMessage broadcastWithMessage:[p7Message stringForName:@"wired.message.broadcast"]
												  user:user
											connection:connection];
	
	key = [[self class] _conversationKeyForClass:[message class] user:user connection:connection];
	conversation = [_conversations objectForKey:key];
	
	if(conversation) {
		[conversation addMessage:message];
	} else {
		conversation = [WCConversation conversationWithMessage:message];
		[_allConversations addObject:conversation];
		[_conversations setObject:conversation forKey:key];
	}

	[message setConversation:conversation];

	[_allMessages addObject:message];

	[_conversationsOutlineView reloadData];
	[[_conversationsOutlineView delegate] outlineViewSelectionDidChange:NULL];
	
	if([[WCSettings eventForTag:WCEventsBroadcastReceived] boolForKey:WCEventsShowDialog])
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
		return (message != NULL && [[message connection] isConnected]);
	if(selector == @selector(revealInUserList:))
		return ([self _selectedConversation] != NULL);
	else if(selector == @selector(clearMessages:))
		return ([_allMessages count] > 0);
	
	return YES;
}



#pragma mark -

- (void)showNextUnreadMessage {
	NSArray			*messages;
	WCMessage		*message, *selectedMessage;
	NSUInteger		i, index, count;
	
	message = [self _selectedMessageForTraversing];
	
	if(!message)
		return;
	
	messages = [self _messagesSortedForView];
	selectedMessage = [self _selectedMessage];
	
	if(!selectedMessage || message == selectedMessage) {
		index = [messages indexOfObject:message];
		
		if(index == NSNotFound)
			return;
		
		count = [messages count];
		i = (index < count - 1) ? index + 1 : 0;
		
		do {
			message = [messages objectAtIndex:i];
			
			if(![message isRead])
				break;
			
			message = NULL;
			
			i = (i < count - 1) ? i + 1 : 0;
		} while(i != index);
	}
	
	if(message)
		[self _selectMessage:message];
}



- (void)showPreviousUnreadMessage {
	NSArray			*messages;
	WCMessage		*message, *selectedMessage;
	NSUInteger		i, index, count;
	
	message = [self _selectedMessageForTraversing];
	
	if(!message)
		return;
	
	messages = [self _messagesSortedForView];
	selectedMessage = [self _selectedMessage];

	if(message == [self _selectedMessage]) {
		index = [messages indexOfObject:message];
		
		if(index == NSNotFound)
			return;
		
		count = [messages count];
		i = (index > 0) ? index - 1 : count - 1;
		
		do {
			message = [messages objectAtIndex:i];
			
			if(![message isRead])
				break;
			
			message = NULL;
			
			i = (i > 0) ? i - 1 : count - 1;
		} while(i != index);
	}

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
	NSEnumerator		*enumerator;
	WCMessage			*message;
	NSUInteger			count = 0;
	
	enumerator = [_allMessages objectEnumerator];
	
	while((message = [enumerator nextObject])) {
		if([message connection] == connection && [message isRead])
			count++;
	}
	
	return count;
}



#pragma mark -

- (void)broadcastSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message				*message;
	WCServerConnection		*connection = contextInfo;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.message.send_broadcast" spec:WCP7Spec];
		[message setString:[_broadcastTextView string] forName:@"wired.message.broadcast"];
		[connection sendMessage:message];
	}

	[_broadcastPanel close];
	[_broadcastTextView setString:@""];
}



- (IBAction)reply:(id)sender {
	WCMessage   *message;
	WCUser		*user;
	WCError		*error;
	
	message = [self _selectedMessage];
	
	if(!message)
		return;
	
	user = [[[message connection] chat] userWithUserID:[message userID]];
	
	if(user) {
		[self showPrivateMessageToUser:user];
	} else { 
		error = [WCError errorWithDomain:WCWiredClientErrorDomain code:WCWiredClientClientNotFound]; 
		[[message connection] triggerEvent:WCEventsError info1:error]; 
		[[error alert] beginSheetModalForWindow:[self window]]; 
	} 
}



- (void)replySheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSString		*key;
	WIP7Message		*p7Message;
	WCUser			*user = contextInfo;
	WCMessage		*message;
	WCConversation  *conversation;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WCPrivateMessage messageToUser:user
										  message:[[[_replyTextView string] copy] autorelease]
									   connection:[user connection]];

		key = [[self class] _conversationKeyForClass:[message class] user:user connection:[user connection]];
		conversation = [_conversations objectForKey:key];
		
		if(conversation) {
			[conversation addMessage:message];
		} else {
			conversation = [WCConversation conversationWithMessage:message];
			[_allConversations addObject:conversation];
			[_conversations setObject:conversation forKey:key];
		}
		
		[message setConversation:conversation];

		[_allMessages addObject:message];
		
		p7Message = [WIP7Message messageWithName:@"wired.message.send_message" spec:WCP7Spec];
		[p7Message setUInt32:[message userID] forName:@"wired.user.id"];
		[p7Message setString:[message message] forName:@"wired.message.message"];
		[[message connection] sendMessage:p7Message];

		[[WCStats stats] addUnsignedInt:1 forKey:WCStatsMessagesSent];
		
		[_conversationsOutlineView reloadData];
		[[_conversationsOutlineView delegate] outlineViewSelectionDidChange:NULL];
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

	user = [[[conversation connection] chat] userWithUserID:[conversation userID]];
	
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
		[self _removeAllConversations];
		
		[self _validate];
	}
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(!item)
		return [_titles count];
	
	if([_titles indexOfObject:item] == 0)
		return [[self _conversationsOfClass:[WCPrivateMessage class]] count];
	else if([_titles indexOfObject:item] == 1)
		return [[self _conversationsOfClass:[WCBroadcastMessage class]] count];
	
	return 0;
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
	if(!item)
		return [_titles objectAtIndex:index];
	
	if([_titles indexOfObject:item] == 0)
		return [[self _conversationsOfClass:[WCPrivateMessage class]] objectAtIndex:index];
	else if([_titles indexOfObject:item] == 1)
		return [[self _conversationsOfClass:[WCBroadcastMessage class]] objectAtIndex:index];
	
	return NULL;
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	NSString			*name = NULL;
	WCConversation		*conversation;
	NSUInteger			count = 0;
	
	if([item isKindOfClass:[NSString class]]) {
		name = item;

		if([_titles indexOfObject:item] == 0)
			count = [[self _unreadMessagesOfClass:[WCPrivateMessage class]] count];
		else if([_titles indexOfObject:item] == 1)
			count = [[self _unreadMessagesOfClass:[WCBroadcastMessage class]] count];
	}
	else if([item isKindOfClass:[WCConversation class]]) {
		conversation = item;
		name = [conversation userNick];
		count = [[self _messagesForConversation:conversation unreadOnly:YES] count];
	}
	
	if(count > 0)
		name = [name stringByAppendingFormat:@" (%lu)", count];
	
	return [[NSAttributedString attributedStringWithString:name] attributedStringByApplyingFilter:_userFilter];
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	NSImage			*image = NULL;
	NSUInteger		count = 0;
	
	if([item isKindOfClass:[NSString class]]) {
		image = _conversationIcon;

		if([_titles indexOfObject:item] == 0)
			count = [[self _unreadMessagesOfClass:[WCPrivateMessage class]] count];
		else if([_titles indexOfObject:item] == 1)
			count = [[self _unreadMessagesOfClass:[WCBroadcastMessage class]] count];
	}
	else if([item isKindOfClass:[WCConversation class]]) {
		count = [[self _messagesForConversation:item unreadOnly:YES] count];
		image = NULL;
	}	

	if(count > 0)
		[cell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
	else
		[cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	
	[cell setImage:image];
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	if([_titles containsObject:item])
		return YES;
	
	return NO;
}



- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	NSArray			*messages = NULL;
	id				messageBox;

	messageBox = [self _selectedMessageBox];

	if([messageBox isKindOfClass:[NSString class]]) {
		if([_titles indexOfObject:messageBox] == 0)
			messages = [self _messagesOfClass:[WCPrivateMessage class]];
		else if([_titles indexOfObject:messageBox] == 1)
			messages = [self _messagesOfClass:[WCBroadcastMessage class]];
	}
	else if([messageBox isKindOfClass:[WCConversation class]]) {
		messages = [self _messagesForConversation:messageBox unreadOnly:NO];
	}
	
	[_shownMessages setArray:messages];
	[self _sortMessages];
	
	[_messagesTableView reloadData];
	[_messagesTableView deselectAll:self];
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownMessages count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	NSString			*string;
	WCMessage			*message;
	
	message = [self _messageAtIndex:row];
	
	if(column == _userTableColumn) {
		if([message direction] == WCMessageTo)
			string = [NSSWF:NSLS(@"To: %@", @"Message to (nick)"), [message userNick]];
		else
			string = [NSSWF:NSLS(@"From: %@", @"Message from (nick)"), [message userNick]];

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
	[self _sortMessages];
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
