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
#import "WCAccount.h"
#import "WCApplicationController.h"
#import "WCBoards.h"
#import "WCFile.h"
#import "WCFiles.h"
#import "WCKeychain.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCPrivateChat.h"
#import "WCPublicChat.h"
#import "WCPublicChatController.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCServerInfo.h"
#import "WCUser.h"

@interface WCPublicChat(Private)

- (void)_updateToolbarForConnection:(WCServerConnection *)connection;

- (BOOL)_beginConfirmDisconnectSheetModalForWindow:(NSWindow *)window connection:(WCServerConnection *)connection modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo;

- (void)_closeSelectedTabViewItem;

@end


@implementation WCPublicChat(Private)

- (void)_updateToolbarForConnection:(WCServerConnection *)connection {
	NSToolbarItem		*item;
	NSImage				*image;
	NSSize				size;
	
	item = [[[self window] toolbar] itemWithIdentifier:@"Banner"];
	
	if(connection) {
		[item setLabel:[connection name]];
		[item setPaletteLabel:[connection name]];
		[item setToolTip:[connection name]];
	} else {
		[item setLabel:NSLS(@"Banner", @"Banner toolbar item")];
		[item setPaletteLabel:NSLS(@"Banner", @"Banner toolbar item")];
		[item setToolTip:NSLS(@"Banner", @"Banner toolbar item")];
	}
	
	image = [[connection server] banner];
	
	if(image) {
		[(NSButton *) [item view] setImage:image];
		
		size = [image size];
		
		if(size.width <= 200.0 && size.height <= 32.0) {
			[item setMinSize:size];
			[item setMaxSize:size];
		} else {
			[item setMinSize:NSMakeSize(32.0 * (size.width / size.height), 32.0)];
			[item setMaxSize:NSMakeSize(32.0 * (size.width / size.height), 32.0)];
		}
	} else {
		[(NSButton *) [item view] setImage:[NSImage imageNamed:@"Banner"]];
		
		size = NSMakeSize(32.0, 32.0);
		
		[item setMinSize:size];
		[item setMaxSize:size];
	}

	item = [[[self window] toolbar] itemWithIdentifier:@"Messages"];
	
	[item setImage:[[NSImage imageNamed:@"Messages"] badgedImageWithInt:[[WCMessages messages] numberOfUnreadMessages]]];

	item = [[[self window] toolbar] itemWithIdentifier:@"Boards"];
	
	[item setImage:[[NSImage imageNamed:@"Boards"] badgedImageWithInt:[[WCBoards boards] numberOfUnreadThreads]]];
}



#pragma mark -

- (BOOL)_beginConfirmDisconnectSheetModalForWindow:(NSWindow *)window connection:(WCServerConnection *)connection modalDelegate:(id)delegate didEndSelector:(SEL)selector contextInfo:(void *)contextInfo {
	NSAlert		*alert;
	
	if([WCSettings boolForKey:WCConfirmDisconnect] && [connection isConnected]) {
		alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLS(@"Are you sure you want to disconnect?", @"Disconnect dialog title")];
		[alert setInformativeText:NSLS(@"Disconnecting will close any ongoing file transfers.", @"Disconnect dialog description")];
		[alert addButtonWithTitle:NSLS(@"Disconnect", @"Disconnect dialog button")];
		[alert addButtonWithTitle:NSLS(@"Cancel", @"Disconnect dialog button title")];
		[alert beginSheetModalForWindow:window
						  modalDelegate:delegate
						 didEndSelector:selector
							contextInfo:contextInfo];
		[alert release];
		
		return NO;
	}
	
	return YES;
}



#pragma mark -

- (void)_closeSelectedTabViewItem {
	NSTabViewItem			*tabViewItem;
	NSString				*identifier;
	WCPublicChatController	*chatController;
	
	tabViewItem			= [_chatTabView selectedTabViewItem];
	identifier			= [tabViewItem identifier];
	chatController		= [_chatControllers objectForKey:identifier];
	
	[chatController saveWindowProperties];
	
	[[chatController connection] terminate];
	
	[_chatControllers removeObjectForKey:identifier];
	
	[_chatTabView removeTabViewItem:tabViewItem];
	
	if([_chatControllers count] == 0) {
		[self _updateToolbarForConnection:NULL];
		
		[_noConnectionTextField setHidden:NO];
	}
}

@end



@implementation WCPublicChat

+ (id)publicChat {
	static WCPublicChat			*publicChat;
	
	if(!publicChat)
		publicChat = [[self alloc] init];
	
	return publicChat;
}



- (id)init {
	self = [super initWithWindowNibName:@"PublicChatWindow"];
	
	_chatControllers = [[NSMutableDictionary alloc] init];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverConnectionServerInfoDidChange:)
			   name:WCServerConnectionServerInfoDidChangeNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatRegularChatDidAppear:)
			   name:WCChatRegularChatDidAppearNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatHighlightedChatDidAppear:)
			   name:WCChatHighlightedChatDidAppearNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(chatEventDidAppear:)
			   name:WCChatEventDidAppearNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(boardsDidChangeUnreadCount:)
			   name:WCBoardsDidChangeUnreadCountNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(messagesDidChangeUnreadCount:)
			   name:WCMessagesDidChangeUnreadCountNotification];
	
	[self window];
	
	return self;
}



- (void)dealloc {
	[_tabBarControl release];
	
	[_chatControllers release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar			*toolbar;
	NSRect				frame;
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"PublicChat"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setShowsBaselineSeparator:NO];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"PublicChat"];

	frame				= [[[self window] contentView] frame];
	frame.origin.y		= frame.size.height - 23.0;
	frame.size.height	= 23.0;
	
	_tabBarControl = [[PSMTabBarControl alloc] initWithFrame:frame];
	[_tabBarControl setTabView:_chatTabView];
	[_tabBarControl setStyleNamed:@"Wired"];
	[_tabBarControl setDelegate:self];
	[_tabBarControl setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin]; 
	[_tabBarControl setCanCloseOnlyTab:YES];
	[[[self window] contentView] addSubview:_tabBarControl];
	[_chatTabView setDelegate:_tabBarControl];
	
	[self _updateToolbarForConnection:NULL];

	[super windowDidLoad];
}




- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	NSButton		*button;
	
	if([identifier isEqualToString:@"Banner"]) {
		button = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 32.0, 32.0)] autorelease];
		[button setBordered:NO];
		[button setImage:[NSImage imageNamed:@"Banner"]];
		
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Banner", @"Banner toolbar item")
												content:button
												 target:self
												 action:@selector(serverInfo:)];
	}
	else if([identifier isEqualToString:@"News"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"News", @"News toolbar item")
												content:[NSImage imageNamed:@"News"]
												 target:self
												 action:@selector(news:)];
	}
	else if([identifier isEqualToString:@"Boards"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Boards", @"Boards toolbar item")
												content:[NSImage imageNamed:@"Boards"]
												 target:[WCApplicationController sharedController]
												 action:@selector(boards:)];
	}
	else if([identifier isEqualToString:@"Messages"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Messages", @"Messages toolbar item")
												content:[NSImage imageNamed:@"Messages"]
												 target:[WCApplicationController sharedController]
												 action:@selector(messages:)];
	}
	else if([identifier isEqualToString:@"Files"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Files", @"Files toolbar item")
												content:[NSImage imageNamed:@"Folder"]
												 target:self
												 action:@selector(files:)];
	}
	else if([identifier isEqualToString:@"Search"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Search", @"Search toolbar item")
												content:[NSImage imageNamed:@"Search"]
												 target:[WCApplicationController sharedController]
												 action:@selector(search:)];
	}
	else if([identifier isEqualToString:@"Transfers"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Transfers", @"Transfers toolbar item")
												content:[NSImage imageNamed:@"Transfers"]
												 target:[WCApplicationController sharedController]
												 action:@selector(transfers:)];
	}
	else if([identifier isEqualToString:@"Accounts"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Accounts", @"Accounts toolbar item")
												content:[NSImage imageNamed:@"Accounts"]
												 target:self
												 action:@selector(accounts:)];
	}
	else if([identifier isEqualToString:@"Administration"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Administration", @"Administration toolbar item")
												content:[NSImage imageNamed:@"Settings"]
												 target:self
												 action:@selector(administration:)];
	}
	else if([identifier isEqualToString:@"Console"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Console", @"Console toolbar item")
												content:[NSImage imageNamed:@"Console"]
												 target:self
												 action:@selector(console:)];
	}
	else if([identifier isEqualToString:@"Reconnect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reconnect", @"Disconnect toolbar item")
												content:[NSImage imageNamed:@"Reconnect"]
												 target:self
												 action:@selector(reconnect:)];
	}
	else if([identifier isEqualToString:@"Disconnect"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Disconnect", @"Disconnect toolbar item")
												content:[NSImage imageNamed:@"Disconnect"]
												 target:self
												 action:@selector(disconnect:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Banner",
		NSToolbarSpaceItemIdentifier,
		@"News",
		@"Boards",
		@"Messages",
		@"Files",
		@"Search",
		@"Transfers",
		@"Accounts",
		@"Administration",
		NSToolbarFlexibleSpaceItemIdentifier,
		@"Reconnect",
		@"Disconnect",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Banner",
		@"News",
		@"Boards",
		@"Messages",
		@"Files",
		@"Search",
		@"Transfers",
		@"Accounts",
		@"Administration",
#ifndef WCConfigurationRelease
		@"Console",
#endif
		@"Reconnect",
		@"Disconnect",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (void)serverConnectionServerInfoDidChange:(NSNotification *)notification {
	WCServerConnection		*connection;
	
	connection = [notification object];

	[[_chatTabView tabViewItemWithIdentifier:[connection identifier]] setLabel:[connection name]];
	
	[self _updateToolbarForConnection:connection];
}



- (void)chatRegularChatDidAppear:(NSNotification *)notification {
	NSTabViewItem			*tabViewItem;
	NSColor					*color;
	WCServerConnection		*connection;
	
	connection		= [notification object];
	tabViewItem		= [_chatTabView tabViewItemWithIdentifier:[connection identifier]];
	
	if(tabViewItem != [_chatTabView selectedTabViewItem]) {
		color = [WIColorFromString([[connection theme] objectForKey:WCThemesChatTextColor]) colorWithAlphaComponent:0.5];

		[_tabBarControl setIcon:[[NSImage imageNamed:@"GrayDrop"] tintedImageWithColor:color] forTabViewItem:tabViewItem];
	}
}



- (void)chatHighlightedChatDidAppear:(NSNotification *)notification {
	NSTabViewItem			*tabViewItem;
	NSColor					*color;
	WCServerConnection		*connection;
	
	connection		= [notification object];
	tabViewItem		= [_chatTabView tabViewItemWithIdentifier:[connection identifier]];
	
	if(tabViewItem != [_chatTabView selectedTabViewItem]) {
		color = [[[notification userInfo] objectForKey:WCChatHighlightColorKey] colorWithAlphaComponent:0.5];

		[_tabBarControl setIcon:[[NSImage imageNamed:@"GrayDrop"] tintedImageWithColor:color] forTabViewItem:tabViewItem];
	}
}



- (void)chatEventDidAppear:(NSNotification *)notification {
	NSTabViewItem			*tabViewItem;
	NSColor					*color;
	WCServerConnection		*connection;
	
	connection		= [notification object];
	tabViewItem		= [_chatTabView tabViewItemWithIdentifier:[connection identifier]];
	
	if(tabViewItem != [_chatTabView selectedTabViewItem]) {
		color = [WIColorFromString([[connection theme] objectForKey:WCThemesChatEventsColor]) colorWithAlphaComponent:0.5];

		[_tabBarControl setIcon:[[NSImage imageNamed:@"GrayDrop"] tintedImageWithColor:color] forTabViewItem:tabViewItem];
	}
}



- (void)boardsDidChangeUnreadCount:(NSNotification *)notification {
	[self _updateToolbarForConnection:[[self selectedChatController] connection]];
}



- (void)messagesDidChangeUnreadCount:(NSNotification *)notification {
	[self _updateToolbarForConnection:[[self selectedChatController] connection]];
}



- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	WCPublicChatController		*chatController;
	
	chatController = [_chatControllers objectForKey:[tabViewItem identifier]];
	
	[self _updateToolbarForConnection:[chatController connection]];

	[_tabBarControl setIcon:NULL forTabViewItem:tabViewItem];
}



- (BOOL)tabView:(NSTabView *)tabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem {
	WCPublicChatController		*chatController;
	
	chatController = [_chatControllers objectForKey:[tabViewItem identifier]];
	
	return [self _beginConfirmDisconnectSheetModalForWindow:[self window]
												 connection:[chatController connection]
											  modalDelegate:self
											 didEndSelector:@selector(closeTabSheetDidEnd:returnCode:contextInfo:)
												contextInfo:NULL];
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	WCPublicChatController	*chatController;
	WCServerConnection		*connection;
	SEL						selector;
	
	chatController	= [self selectedChatController];
	connection		= [[self selectedChatController] connection];
	selector		= [item action];
	
	if(selector == @selector(disconnect:))
		return ([connection isConnected] && ![connection isDisconnecting]);
	else if(selector == @selector(reconnect:))
		return (connection != NULL && ![connection isConnected] && ![connection isManuallyReconnecting]);
	else if(selector == @selector(files:) || selector == @selector(broadcast:))
		return [connection isConnected];
	else if(selector == @selector(serverInfo:) || selector == @selector(news:) ||
			selector == @selector(accounts:) || selector == @selector(administration:) ||
			selector == @selector(console:))
		return (connection != NULL);
	else if(selector == @selector(nextConnection:) || selector == @selector(previousConnection:))
		return ([_chatControllers count] > 1);
	
	return [chatController validateMenuItem:item];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCPublicChatController	*chatController;
	WCServerConnection		*connection;
	SEL						selector;
	
	chatController	= [self selectedChatController];
	connection		= [[self selectedChatController] connection];
	selector		= [item action];
	
	if(selector == @selector(disconnect:))
		return (connection != NULL && [connection isConnected] && ![connection isDisconnecting]);
	else if(selector == @selector(reconnect:))
		return (connection != NULL && ![connection isConnected] && ![connection isManuallyReconnecting]);
	else if(selector == @selector(files:))
		return (connection != NULL && [connection isConnected]);
	else if(selector == @selector(serverInfo:) || selector == @selector(news:) ||
			selector == @selector(accounts:) || selector == @selector(administration:) ||
			selector == @selector(console:))
		return (connection != NULL);
	
	return YES;
}



#pragma mark -

- (IBAction)disconnect:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];

	if([self _beginConfirmDisconnectSheetModalForWindow:[self window]
											 connection:connection
										  modalDelegate:self
										 didEndSelector:@selector(disconnectSheetDidEnd:returnCode:contextInfo:)
											contextInfo:[connection retain]]) {
		[connection disconnect];
	}
}



- (void)disconnectSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	WCServerConnection		*connection = contextInfo;
	
	if(returnCode == NSAlertFirstButtonReturn)
		[connection disconnect];
	
	[connection release];
}



- (IBAction)reconnect:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[connection reconnect];
}



- (IBAction)serverInfo:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection serverInfo] showWindow:self];
}



- (IBAction)news:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection news] showWindow:self];
}



- (IBAction)files:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[WCFiles filesWithConnection:connection path:[WCFile fileWithRootDirectoryForConnection:connection]];
}



- (IBAction)accounts:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection accounts] showWindow:self];
}



- (IBAction)administration:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection administration] showWindow:self];
}



- (IBAction)getInfo:(id)sender {
	[[self selectedChatController] getInfo:sender];
}



- (IBAction)saveChat:(id)sender {
	[[self selectedChatController] saveChat:sender];
}



- (IBAction)setTopic:(id)sender {
	[[self selectedChatController] setTopic:sender];
}



- (IBAction)broadcast:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[WCMessages messages] showBroadcastForConnection:connection];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary		*bookmark;
	NSString			*login, *password;
	WIURL				*url;
	WCServerConnection	*connection;
	
	connection	= [[self selectedChatController] connection];
	url			= [connection URL];
	
	if(url) {
		login		= [url user] ? [url user] : @"";
		password	= [url password] ? [url password] : @"";
		bookmark	= [NSDictionary dictionaryWithObjectsAndKeys:
		   [connection name],			WCBookmarksName,
		   [url hostpair],				WCBookmarksAddress,
		   login,						WCBookmarksLogin,
		   @"",							WCBookmarksNick,
		   @"",							WCBookmarksStatus,
		   [NSString UUIDString],		WCBookmarksIdentifier,
		   NULL];
		
		[WCSettings addObject:bookmark toArrayForKey:WCBookmarks];
		
		[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
		
		[connection setBookmark:bookmark];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
	}
}



#pragma mark -

- (IBAction)console:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	[[connection console] showWindow:self];
}



#pragma mark -

- (IBAction)nextConnection:(id)sender {
	NSArray				*items;
	NSUInteger			index, newIndex;
	
	items = [_chatTabView tabViewItems];
	index = [items indexOfObject:[_chatTabView selectedTabViewItem]];
	
	if([items count] > 0) {
		if(index == [items count] - 1)
			newIndex = 0;
		else
			newIndex = index + 1;
		
		[_chatTabView selectTabViewItemAtIndex:newIndex];

		[[self window] makeFirstResponder:[[self selectedChatController] insertionTextView]];
	}
}



- (IBAction)previousConnection:(id)sender {
	NSArray				*items;
	NSUInteger			index, newIndex;
	
	items = [_chatTabView tabViewItems];
	index = [items indexOfObject:[_chatTabView selectedTabViewItem]];
	
	if([items count] > 0) {
		if(index == 0)
			newIndex = [items count] - 1;
		else
			newIndex = index - 1;
		
		[_chatTabView selectTabViewItemAtIndex:newIndex];

		[[self window] makeFirstResponder:[[self selectedChatController] insertionTextView]];
	}
}



- (IBAction)closeTab:(id)sender {
	WCServerConnection		*connection;
	
	connection = [[self selectedChatController] connection];
	
	if([self _beginConfirmDisconnectSheetModalForWindow:[self window]
											 connection:connection
										  modalDelegate:self
										 didEndSelector:@selector(closeTabSheetDidEnd:returnCode:contextInfo:)
											contextInfo:NULL]) {
		[self _closeSelectedTabViewItem];
	}
}



- (void)closeTabSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSAlertFirstButtonReturn)
		[self _closeSelectedTabViewItem];
}



#pragma mark -

- (NSTextView *)insertionTextView {
	return [[self selectedChatController] insertionTextView];
}



#pragma mark -

- (void)addChatController:(WCPublicChatController *)chatController {
	NSTabViewItem		*tabViewItem;
	NSString			*identifier;
	
	identifier = [[chatController connection] identifier];
	
	if([_chatControllers objectForKey:identifier] != NULL)
		return;
	
	[[chatController connection] setIdentifier:identifier];
	
	[_chatControllers setObject:chatController forKey:identifier];
	
	if([_chatControllers count] == 1)
		[_noConnectionTextField setHidden:YES];
	
	tabViewItem = [[[NSTabViewItem alloc] initWithIdentifier:identifier] autorelease];
	[tabViewItem setLabel:[[chatController connection] name]];
	[tabViewItem setView:[chatController view]];
	
	[_chatTabView addTabViewItem:tabViewItem];
	[_chatTabView selectTabViewItem:tabViewItem];
	
	[chatController loadWindowProperties];
}



- (void)selectChatController:(WCPublicChatController *)chatController {
	[_chatTabView selectTabViewItemWithIdentifier:[[chatController connection] identifier]];

	[[self window] makeFirstResponder:[[self selectedChatController] insertionTextView]];
}



- (WCPublicChatController *)selectedChatController {
	NSString			*identifier;
	
	identifier = [[_chatTabView selectedTabViewItem] identifier];
	
	return [_chatControllers objectForKey:identifier];
}



- (NSArray *)chatControllers {
	return [_chatControllers allValues];
}

@end
