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

#import "WCAboutWindow.h"
#import "WCApplicationController.h"
#import "WCBoards.h"
#import "WCChat.h"
#import "WCConnect.h"
#import "WCConsole.h"
#import "WCKeychain.h"
#import "WCMessage.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCPreferences.h"
#import "WCSearch.h"
#import "WCServerConnection.h"
#import "WCServers.h"
#import "WCStats.h"
#import "WCTransfers.h"
#import "WCUser.h"

#define WCGrowlServerConnected			@"Connected to server"
#define WCGrowlServerDisconnected		@"Disconnected from server"
#define WCGrowlError					@"Error"
#define WCGrowlUserJoined				@"User joined"
#define WCGrowlUserChangedNick			@"User changed nick"
#define WCGrowlUserChangedStatus		@"User changed status"
#define WCGrowlUserJoined				@"User joined"
#define WCGrowlUserLeft					@"User left"
#define WCGrowlChatReceived				@"Chat received"
#define WCGrowlHighlightedChatReceived	@"Highlighted chat received"
#define WCGrowlChatInvitationReceived	@"Private chat invitation received"
#define WCGrowlMessageReceived			@"Message received"
#define WCGrowlNewsPosted				@"News posted"
#define WCGrowlBroadcastReceived		@"Broadcast received"
#define WCGrowlTransferStarted			@"Transfer started"
#define WCGrowlTransferFinished			@"Transfer finished"


static NSInteger _WCCompareSmileyLength(id, id, void *);

static NSInteger _WCCompareSmileyLength(id object1, id object2, void *context) {
	NSUInteger	length1 = [(NSString *) object1 length];
	NSUInteger	length2 = [(NSString *) object2 length];
	
	if(length1 > length2)
		return -1;
	else if(length1 < length2)
		return 1;
	
	return 0;
}


@interface WCApplicationController(Private)

- (void)_loadSmileys;

- (void)_update;
- (void)_updateApplicationIcon;
- (void)_updateBookmarksMenu;

- (void)_connectWithBookmark:(NSDictionary *)bookmark;
- (BOOL)_openConnectionWithURL:(WIURL *)url;

@end


@implementation WCApplicationController(Private)

- (void)_loadSmileys {
	NSBundle			*bundle;
	NSMenuItem			*item;
	NSMutableArray		*array;
	NSDictionary		*dictionary, *list, *map, *names;
	NSEnumerator		*enumerator;
	NSString			*path, *file, *name, *smiley, *title;
	
	bundle			= [self bundle];
	path			= [bundle pathForResource:@"Smileys" ofType:@"plist"];
	dictionary		= [NSDictionary dictionaryWithContentsOfFile:path];
	list			= [dictionary objectForKey:@"List"];
	map				= [dictionary objectForKey:@"Map"];
	enumerator		= [map keyEnumerator];
	_smileys		= [[NSMutableDictionary alloc] initWithCapacity:[map count]];

	while((smiley = [enumerator nextObject])) {
		file = [map objectForKey:smiley];
		path = [bundle pathForResource:file ofType:NULL];
		
		if(path)
			[_smileys setObject:path forKey:[smiley lowercaseString]];
		else
			NSLog(@"*** -[%@ %@]: could not find image \u201c%@\u201d", [self class], NSStringFromSelector(_cmd), file);
	}
	
	array = [NSMutableArray arrayWithObjects:
		@"Smile.tiff",
		@"Wink.tiff",
		@"Frown.tiff",
		@"Slant.tiff",
		@"Gasp.tiff",
		@"Laugh.tiff",
		@"Kiss.tiff",
		@"Yuck.tiff",
		@"Embarrassed.tiff",
		@"Footinmouth.tiff",
		@"Cool.tiff",
		@"Angry.tiff",
		@"Innocent.tiff",
		@"Cry.tiff",
		@"Sealed.tiff",
		@"Moneymouth.tiff",
		NULL];
	
	names = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Smile", @"Smiley"),					@"Smile.tiff",
		NSLS(@"Wink", @"Smiley"),					@"Wink.tiff",
		NSLS(@"Frown", @"Smiley"),					@"Frown.tiff",
		NSLS(@"Undecided", @"Smiley"),				@"Slant.tiff",
		NSLS(@"Gasp", @"Smiley"),					@"Gasp.tiff",
		NSLS(@"Laugh", @"Smiley"),					@"Laugh.tiff",
		NSLS(@"Kiss", @"Smiley"),					@"Kiss.tiff",
		NSLS(@"Sticking out tongue", @"Smiley"),	@"Yuck.tiff",
		NSLS(@"Embarrassed", @"Smiley"),			@"Embarrassed.tiff",
		NSLS(@"Foot in mouth", @"Smiley"),			@"Footinmouth.tiff",
		NSLS(@"Cool", @"Smiley"),					@"Cool.tiff",
		NSLS(@"Angry", @"Smiley"),					@"Angry.tiff",
		NSLS(@"Innocent", @"Smiley"),				@"Innocent.tiff",
		NSLS(@"Cry", @"Smiley"),					@"Cry.tiff",
		NSLS(@"Lips are sealed", @"Smiley"),		@"Sealed.tiff",
		NSLS(@"Money-mouth", @"Smiley"),			@"Moneymouth.tiff",
		NULL];

	[array addObjectsFromArray:[[[[NSSet setWithArray:[list allKeys]] setByMinusingSet:[NSSet setWithArray:array]] allObjects] sortedArrayUsingSelector:@selector(compare:)]];
	
	enumerator = [array objectEnumerator];
	
	while((name = [enumerator nextObject])) {
		smiley	= [list objectForKey:name];
		path	= [_smileys objectForKey:[smiley lowercaseString]];
		title	= [names objectForKey:name];
		
		if(!title)
			title = [name stringByDeletingPathExtension];
		
		item = [NSMenuItem itemWithTitle:title];
		[item setRepresentedObject:path];
		[item setImage:[[[NSImage alloc] initWithContentsOfFile:path] autorelease]];
		[item setAction:@selector(insertSmiley:)];
		[item setToolTip:smiley];
		[_insertSmileyMenu addItem:item];
	}
	
	_sortedSmileys = [[[_smileys allKeys] sortedArrayUsingFunction:_WCCompareSmileyLength context:NULL] retain];
}



#pragma mark -

- (void)_update {
	if([WCSettings boolForKey:WCConfirmDisconnect]) {
		[_disconnectMenuItem setTitle:[NSSWF:
			@"%@%C", NSLS(@"Disconnect", @"Disconnect menu item"), 0x2026]];
	} else {
		[_disconnectMenuItem setTitle:NSLS(@"Disconnect", @"Disconnect menu item")];
	}
	
	[_updater setAutomaticallyChecksForUpdates:[WCSettings boolForKey:WCCheckForUpdate]];
}



- (void)_updateApplicationIcon {
	[NSApp setApplicationIconImage:
		[[NSImage imageNamed:@"NSApplicationIcon"] badgedImageWithInt:_unread]];
}



- (void)_updateBookmarksMenu {
	NSEnumerator	*enumerator;
	NSArray			*bookmarks;
	NSDictionary	*bookmark;
	NSMenuItem		*item;
	NSUInteger		i = 1;

	while((item = (NSMenuItem *) [_bookmarksMenu itemWithTag:0]))
		[_bookmarksMenu removeItem:item];

	bookmarks = [WCSettings objectForKey:WCBookmarks];

	if([bookmarks count] > 0)
		[_bookmarksMenu addItem:[NSMenuItem separatorItem]];

	enumerator = [bookmarks objectEnumerator];

	while((bookmark = [enumerator nextObject])) {
		item = [NSMenuItem itemWithTitle:[bookmark objectForKey:WCBookmarksName] action:@selector(bookmark:)];
		[item setRepresentedObject:bookmark];
		
		if(i <= 10) {
			[item setKeyEquivalent:[NSSWF:@"%u", (i == 10) ? 0 : i]];
			[item setKeyEquivalentModifierMask:NSCommandKeyMask];
		}
		else if(i <= 20) {
			[item setKeyEquivalent:[NSSWF:@"%u", (i == 20) ? 0 : i - 10]];
			[item setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask];
		}
		else if(i <= 30) {
			[item setKeyEquivalent:[NSSWF:@"%u", (i == 30) ? 0 : i - 20]];
			[item setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];
		}

		[_bookmarksMenu addItem:item];

		i++;
	}
}



#pragma mark -

- (void)_connectWithBookmark:(NSDictionary *)bookmark {
	NSString			*address, *login, *password;
	WCConnect			*connect;
	WIURL				*url;

	address		= [bookmark objectForKey:WCBookmarksAddress];
	login		= [bookmark objectForKey:WCBookmarksLogin];
	password	= [[WCKeychain keychain] passwordForBookmark:bookmark];

	url = [WIURL URLWithString:address scheme:@"wired"];
	[url setUser:login];
	[url setPassword:password ? password : @""];
	
	if(![self _openConnectionWithURL:url]) {
		connect = [WCConnect connectWithURL:url bookmark:bookmark];
		[connect showWindow:self];
		[connect connect:self];
	}
}



- (BOOL)_openConnectionWithURL:(WIURL *)url {
	NSEnumerator            *enumerator;
	WCServerConnection      *connection;
	
	enumerator = [_connections objectEnumerator];
	
	while((connection = [enumerator nextObject])) {
		if([url isEqual:[connection URL]]) {
			[[connection chat] showWindow:self];

			if(![connection isConnected])
				[connection reconnect];
			
			return YES;
		}
	}
	
	return NO;
}

@end


@implementation WCApplicationController

static WCApplicationController		*sharedController;


+ (WCApplicationController *)sharedController {
	return sharedController;
}



- (id)init {
	NSTimer		*timer;
	NSDate		*date;

	sharedController = self = [super init];
	
#ifndef RELEASE
	[[WIExceptionHandler sharedExceptionHandler] enable];
#endif
	
	_connections = [[NSMutableArray alloc] init];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bookmarksDidChange:)
			   name:WCBookmarksDidChangeNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionDidTerminate:)
			   name:WCLinkConnectionDidTerminateNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(linkConnectionLoggedIn:)
			   name:WCLinkConnectionLoggedInNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		  selector:@selector(messagesDidAddMessage:)
			   name:WCMessagesDidAddMessageNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(messagesDidReadMessage:)
			   name:WCMessagesDidReadMessageNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(newsDidAddPost:)
			   name:WCNewsDidAddPostNotification];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(newsDidReadPost:)
			   name:WCNewsDidReadPostNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(serverConnectionTriggeredEvent:)
			   name:WCServerConnectionTriggeredEventNotification];
	
	[[NSAppleEventManager sharedAppleEventManager]
		setEventHandler:self
		andSelector:@selector(handleAppleEvent:withReplyEvent:)
		forEventClass:kInternetEventClass
		andEventID:kAEGetURL];

	[[NSFileManager defaultManager]
		createDirectoryAtPath:[WCApplicationSupportPath stringByStandardizingPath]
		attributes:NULL];
	
	date = [[NSDate dateAtStartOfCurrentDay] dateByAddingDays:1];
	timer = [[NSTimer alloc] initWithFireDate:date
									 interval:86400.0
									   target:self
									 selector:@selector(dailyTimer:)
									 userInfo:NULL
									  repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
	[timer release];
	
	signal(SIGPIPE, SIG_IGN);

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[_clientVersion release];
	[_smileys release];
	[_sortedSmileys release];

	[super dealloc];
}



#pragma mark -

- (void)awakeFromNib {
	NSEnumerator		*enumerator;
	NSDictionary		*bookmark;
	WIError				*error;
	
#ifdef RELEASE
	if(![WCSettings boolForKey:WCDebug])
		[[NSApp mainMenu] removeItemAtIndex:[[NSApp mainMenu] indexOfItemWithSubmenu:_debugMenu]];
#endif
	
	[WIDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
	[NSNumberFormatter setDefaultFormatterBehavior:NSNumberFormatterBehavior10_4];
	
	[GrowlApplicationBridge setGrowlDelegate:self];
		
	[_updater setDelegate:self];

#ifdef RELEASE
	[_updater setFeedURL:[NSURL URLWithString:@"http://www.zankasoftware.com/sparkle/wiredclient.xml"]];
#else
	[_updater setFeedURL:[NSURL URLWithString:@"http://www.zankasoftware.com/sparkle/wiredclient-nightly.xml"]];
#endif
	
	WCP7Spec = [[WIP7Spec alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"wired" ofType:@"xml"]
								   originator:WIP7Client
										error:&error];
	
	if(!WCP7Spec) {
		[[error alert] runModal];
		
		[NSApp terminate:self];
	}

	[WCStats stats];
	[WCTransfers transfers];
	[WCMessages messages];
	[WCBoards boards];
	[WCSearch search];
	
	[_deleteMenuItem setKeyEquivalent:[NSSWF:@"%C", NSBackspaceCharacter]];
	[_deleteMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	
	[self _update];
	[self _updateBookmarksMenu];

	if([WCSettings boolForKey:WCShowServersAtStartup])
		[[WCServers servers] showWindow:self];

	if([WCSettings boolForKey:WCShowConnectAtStartup])
		[[WCConnect connect] showWindow:self];
	
	if((GetCurrentKeyModifiers() & optionKey) == 0) {
		enumerator = [[WCSettings objectForKey:WCBookmarks] objectEnumerator];

		while((bookmark = [enumerator nextObject])) {
			if([[bookmark objectForKey:WCBookmarksAutoConnect] boolValue])
				[self _connectWithBookmark:bookmark];
		}
	}
}



#pragma mark -

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)application {
	NSEnumerator		*enumerator;
	WCServerConnection	*connection;
	NSUInteger			count;
	
	enumerator = [_connections objectEnumerator];
	count = 0;
	
	while((connection = [enumerator nextObject])) {
		if([connection isConnected])
			count++;
	}
	
	if([WCSettings boolForKey:WCConfirmDisconnect] && count > 0)
		return [(WIApplication *) NSApp runTerminationDelayPanelWithTimeInterval:30.0];

	return NSTerminateNow;
}



- (void)applicationWillTerminate:(NSNotification *)notification {
	_unread = 0;

	[self _updateApplicationIcon];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (void)bookmarksDidChange:(NSNotification *)notification {
	[self _updateBookmarksMenu];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	WCServerConnection	*connection;

	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;

	[_connections removeObject:connection];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	WCServerConnection	*connection;
	
	connection = [notification object];
	
	if(![connection isKindOfClass:[WCServerConnection class]])
		return;

	[_connections addObject:connection];
}



- (void)messagesDidAddMessage:(NSNotification *)notification {
	if(![[notification object] isRead]) {
		_unread++;
		
		[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
	}
}



- (void)messagesDidReadMessage:(NSNotification *)notification {
	_unread--;
	
	[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
}



- (void)newsDidAddPost:(NSNotification *)notification {
	_unread++;
	
	[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
}



- (void)newsDidReadPost:(NSNotification *)notification {
	_unread--;
	
	[self performSelector:@selector(_updateApplicationIcon) withObject:NULL afterDelay:0.0];
}



- (void)serverConnectionTriggeredEvent:(NSNotification *)notification {
	NSDictionary		*event;
	NSString			*sound;
	NSNumber			*clickContext;
	WCServerConnection	*connection;
	id					info1, info2;
	
	event = [notification object];
	connection = [[notification userInfo] objectForKey:WCServerConnectionEventConnectionKey];
	info1 = [[notification userInfo] objectForKey:WCServerConnectionEventInfo1Key];
	info2 = [[notification userInfo] objectForKey:WCServerConnectionEventInfo2Key];
	
	if([event boolForKey:WCEventsPlaySound]) {
		sound = [event objectForKey:WCEventsSound];
		
		if(sound)
			[NSSound playSoundNamed:sound];
	}
	
	if([event boolForKey:WCEventsBounceInDock])
		[NSApp requestUserAttention:NSInformationalRequest];
	
	clickContext = [NSNumber numberWithUnsignedInteger:[_connections indexOfObject:connection]];
	
	switch([event intForKey:WCEventsEvent]) {
		case WCEventsServerConnected:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Connected", @"Growl event connected title")
										description:[NSSWF:NSLS(@"Connected to %@", @"Growl event connected description (server)"),
											[connection name]]
								   notificationName:WCGrowlServerConnected
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:NULL];
			break;

		case WCEventsServerDisconnected:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Disconnected", @"Growl event disconnected title")
										description:[NSSWF:NSLS(@"Disconnected from %@", @"Growl event disconnected description (server)"),
											[connection name]]
								   notificationName:WCGrowlServerDisconnected
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsError:
			[GrowlApplicationBridge notifyWithTitle:[info1 localizedDescription]
										description:[info1 localizedFailureReason]
								   notificationName:WCGrowlError
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserJoined:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User joined", @"Growl event user joined title")
										description:[info1 nick]
								   notificationName:WCGrowlUserJoined
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserChangedNick:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User changed nick", @"Growl event user changed nick title")
										description:[NSSWF:NSLS(@"%@ is now known as %@", @"Growl event user changed nick description (oldnick, newnick)"),
											[info1 nick], info2]
								   notificationName:WCGrowlUserChangedNick
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserChangedStatus:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User changed status", @"Growl event user changed status title")
										description:[NSSWF:NSLS(@"%@ changed status to %@", @"Growl event user changed status description (nick, status)"),
											[info1 nick], info2]
								   notificationName:WCGrowlUserChangedStatus
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsUserLeft:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"User left", @"Growl event user left title")
										description:[info1 nick]
								   notificationName:WCGrowlUserLeft
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsChatReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Chat received", @"Growl event chat received title")
										description:[NSSWF:@"%@: %@", [info1 nick], info2]
								   notificationName:WCGrowlChatReceived
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsHighlightedChatReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Chat received", @"Growl event chat received title")
										description:[NSSWF:@"%@: %@", [info1 nick], info2]
								   notificationName:WCGrowlHighlightedChatReceived
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsChatInvitationReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Private chat invitation received", @"Growl event private chat invitation received title")
										description:[info1 nick]
								   notificationName:WCGrowlChatInvitationReceived
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
			
		case WCEventsMessageReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Message received", @"Growl event message received title")
										description:[NSSWF:@"%@: %@", [info1 nick], [info1 message]]
								   notificationName:WCGrowlMessageReceived
										   iconData:[[(WCUser *) [info1 user] icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsNewsPosted:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"News posted", @"Growl event news posted title")
										description:[NSSWF:@"%@: %@", info1, info2]
								   notificationName:WCGrowlNewsPosted
										   iconData:NULL
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsBroadcastReceived:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Broadcast received", @"Growl event broadcast received title")
										description:[NSSWF:@"%@: %@", [info1 nick], [info1 message]]
								   notificationName:WCGrowlBroadcastReceived
										   iconData:[[(WCUser *) [info1 user] icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsTransferStarted:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Transfer started", @"Growl event transfer started title")
										description:[info1 name]
								   notificationName:WCGrowlTransferStarted
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
		
		case WCEventsTransferFinished:
			[GrowlApplicationBridge notifyWithTitle:NSLS(@"Transfer finished", @"Growl event transfer started title")
										description:[info1 name]
								   notificationName:WCGrowlTransferFinished
										   iconData:[[info1 icon] TIFFRepresentation]
										   priority:0.0
										   isSticky:NO
									   clickContext:clickContext];
			break;
	}
}



#pragma mark -

- (NSDictionary *)registrationDictionaryForGrowl {
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:
			WCGrowlServerConnected,
			WCGrowlServerDisconnected,
			WCGrowlError,
			WCGrowlUserJoined,
			WCGrowlUserChangedNick,
			WCGrowlUserChangedStatus,
			WCGrowlUserLeft,
			WCGrowlChatReceived,
			WCGrowlHighlightedChatReceived,
			WCGrowlChatInvitationReceived,
			WCGrowlMessageReceived,
			WCGrowlNewsPosted,
			WCGrowlBroadcastReceived,
			WCGrowlTransferStarted,
			WCGrowlTransferFinished,
			NULL],
			GROWL_NOTIFICATIONS_ALL,
		[NSArray arrayWithObjects:
			WCGrowlServerDisconnected,
			WCGrowlHighlightedChatReceived,
			WCGrowlMessageReceived,
			WCGrowlNewsPosted,
			WCGrowlBroadcastReceived,
			WCGrowlTransferFinished,
			NULL],
			GROWL_NOTIFICATIONS_DEFAULT,
		NULL];
}



- (void)growlNotificationWasClicked:(id)clickContext {
	WCServerConnection	*connection;
	
	[NSApp activateIgnoringOtherApps:YES];
	
	connection = [_connections objectAtIndex:[clickContext unsignedIntegerValue]];

	[[connection chat] showWindow:self];
}



#pragma mark -

- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)updater {
	return NO;
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;

	selector = [item action];
	
	if(selector == @selector(nextConnection:) ||
			selector == @selector(previousConnection:))
		return ([_connections count] > 0);
	else if(selector == @selector(makeLayoutDefault:))
		return [[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]];
	else if(selector == @selector(restoreLayoutToDefault:))
		return ([[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]] &&
				[WCSettings windowTemplateForKey:WCWindowTemplatesDefault] != NULL);
	else if(selector == @selector(restoreAllLayoutsToDefault:))
		return ([_connections count] > 0 && [WCSettings windowTemplateForKey:WCWindowTemplatesDefault] != NULL);

	return YES;
}



- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
	NSDictionary	*bookmark;
	NSString		*string;
	WIURL			*url;
	WCConnect		*connect;

	string = [[event descriptorForKeyword:keyDirectObject] stringValue];
	url = [WIURL URLWithString:string];

	if([[url scheme] isEqualToString:@"wired"]) {
		if(![self _openConnectionWithURL:url]) {
			connect = [WCConnect connectWithURL:url bookmark:NULL];
			[connect showWindow:self];
			[connect connect:self];
		}
	}
	else if([[url scheme] isEqualToString:@"wiredtracker"]) {
		bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
			[url host],					WCTrackerBookmarksName,
			[url hostpair],				WCTrackerBookmarksAddress,
			@"",						WCTrackerBookmarksLogin,
			[NSString UUIDString],		WCTrackerBookmarksIdentifier,
			NULL];
		
		[WCSettings addObject:bookmark toArrayForKey:WCTrackerBookmarks];

		[[WCServers servers] showWindow:self];
	}
}



- (void)dailyTimer:(NSTimer *)timer {
	[[NSNotificationCenter defaultCenter] postNotificationName:WCDateDidChangeNotification];
}



#pragma mark -

- (NSArray *)allSmileys {
	if(!_sortedSmileys)
		[self _loadSmileys];
	
	return _sortedSmileys;
}



- (NSString *)pathForSmiley:(NSString *)smiley {
	if(!_smileys)
		[self _loadSmileys];
	
	return [_smileys objectForKey:[smiley lowercaseString]];
}



#pragma mark -

- (IBAction)about:(id)sender {
	NSMutableParagraphStyle		*style;
	NSMutableAttributedString	*credits;
	NSDictionary				*attributes;
	NSAttributedString			*header, *stats;
	NSData						*rtf;
	NSString					*string;
	
	if([[NSApp currentEvent] alternateKeyModifier]) {
		[[WCAboutWindow aboutWindow] makeKeyAndOrderFront:self];
	} else {
		rtf = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"]];
		credits = [[[NSMutableAttributedString alloc] initWithRTF:rtf documentAttributes:NULL] autorelease];

		style = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[style setAlignment:NSCenterTextAlignment];
		attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont boldSystemFontOfSize:11.0],	NSFontAttributeName,
			[NSColor grayColor],					NSForegroundColorAttributeName,
			style,									NSParagraphStyleAttributeName,
			NULL];
		string = [NSSWF:@"%@\n", NSLS(@"Stats", @"About box title")];
		header = [NSAttributedString attributedStringWithString:string attributes:attributes];

		attributes = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont systemFontOfSize:11.0],			NSFontAttributeName,
			style,									NSParagraphStyleAttributeName,
			NULL];
		string = [NSSWF:@"%@\n\n", [[WCStats stats] stringValue]];
		stats = [NSAttributedString attributedStringWithString:string attributes:attributes];

		[credits insertAttributedString:stats atIndex:0];
		[credits insertAttributedString:header atIndex:0];

		[NSApp orderFrontStandardAboutPanelWithOptions:
			[NSDictionary dictionaryWithObject:credits forKey:@"Credits"]];
	}
}



- (IBAction)preferences:(id)sender {
	[[WCPreferences preferences] showWindow:self];
}



#pragma mark -

- (IBAction)connect:(id)sender {
	[[WCConnect connect] showWindow:self];
}



#pragma mark -

- (IBAction)search:(id)sender {
	[[WCSearch search] showWindow:self];
}



#pragma mark -

- (IBAction)bookmark:(id)sender {
	[self _connectWithBookmark:[sender representedObject]];
}



#pragma mark -

- (IBAction)servers:(id)sender {
	[[WCServers servers] showWindow:self];
}



- (IBAction)boards:(id)sender {
	[[WCBoards boards] showWindow:self];
}



- (IBAction)messages:(id)sender {
	[[WCMessages messages] showWindow:self];
}



- (IBAction)transfers:(id)sender {
	[[WCTransfers transfers] showWindow:self];
}



- (IBAction)nextConnection:(id)sender {
/*	WCServerConnection	*connection, *nextConnection;
	NSUInteger			i;
	
	if([[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]]) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];

		i = [_shownConnections indexOfObject:connection] + 1;
		
		if(i >= [_shownConnections count])
			i = 0;
			
		nextConnection = [self _connectionAtIndex:i];
	} else {
		connection = NULL;

		nextConnection = [self _connectionAtIndex:0];
	}
	
	if(nextConnection && connection != nextConnection)
		[self _openConnection:nextConnection];*/
}



- (IBAction)previousConnection:(id)sender {
/*	WCServerConnection	*connection, *previousConnection;
	NSInteger			i;
	
	if([[[NSApp keyWindow] windowController] isKindOfClass:[WCConnectionController class]]) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];

		i = [_shownConnections indexOfObject:connection] - 1;
		
		if(i < 0)
			i = [_shownConnections count] - 1;

		previousConnection = [self _connectionAtIndex:i];
	} else {
		connection = NULL;

		previousConnection = [_shownConnections lastObject];
	}

	if(previousConnection && connection != previousConnection)
		[self _openConnection:previousConnection];*/
}



- (IBAction)makeLayoutDefault:(id)sender {
	NSAlert				*alert;
	WCServerConnection	*connection;
	
	alert = [NSAlert alertWithMessageText:NSLS(@"Make Current Layout Default?", @"Make layout default dialog title")
							defaultButton:NSLS(@"OK", @"Make layout default dialog button title")
						  alternateButton:NULL
							  otherButton:NSLS(@"Cancel", @"Make layout default dialog button title")
				informativeTextWithFormat:NSLS(@"This will set the windows for the currently shown connection as the default layout.", @"Make layout default dialog button description")];
	
	if([alert runModal] == NSAlertDefaultReturn) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];
		
		[connection postNotificationName:WCServerConnectionShouldSaveWindowTemplateNotification];
		
		[WCSettings setWindowTemplate:[WCSettings windowTemplateForKey:[connection identifier]]
							   forKey:WCWindowTemplatesDefault];
	}
}



- (IBAction)restoreLayoutToDefault:(id)sender {
	NSAlert				*alert;
	WCServerConnection	*connection;
	
	alert = [NSAlert alertWithMessageText:NSLS(@"Restore Layout To Default?", @"Restore layout to default dialog title")
							defaultButton:NSLS(@"OK", @"Restore layout to default dialog button title")
						  alternateButton:NULL
							  otherButton:NSLS(@"Cancel", @"Restore layout to default dialog button title")
				informativeTextWithFormat:NSLS(@"This will restore all windows for the currently shown connection to the previously saved default layout.", @"Restore layout to default dialog button description")];

	if([alert runModal] == NSAlertDefaultReturn) {
		connection = [(WCConnectionController *) [[NSApp keyWindow] windowController] connection];
		
		[WCSettings setWindowTemplate:[WCSettings windowTemplateForKey:WCWindowTemplatesDefault]
							   forKey:[connection identifier]];
		
		[connection postNotificationName:WCServerConnectionShouldLoadWindowTemplateNotification];
	}
}



- (IBAction)restoreAllLayoutsToDefault:(id)sender {
	NSEnumerator		*enumerator;
	NSAlert				*alert;
	WCServerConnection	*connection;
	
	alert = [NSAlert alertWithMessageText:NSLS(@"Restore All Layouts To Default?", @"Restore all layouts to default dialog title")
							defaultButton:NSLS(@"OK", @"Restore all layouts to default dialog button title")
						  alternateButton:NULL
							  otherButton:NSLS(@"Cancel", @"Restore all layouts to default dialog button title")
				informativeTextWithFormat:NSLS(@"This will restore all windows for all connections to the previously saved default layout.", @"Restore all layouts to default dialog button description")];

	if([alert runModal] == NSAlertDefaultReturn) {
		enumerator = [_connections objectEnumerator];
		
		while((connection = [enumerator nextObject])) {
			[WCSettings setWindowTemplate:[WCSettings windowTemplateForKey:WCWindowTemplatesDefault]
								   forKey:[connection identifier]];
			
			[connection postNotificationName:WCServerConnectionShouldLoadWindowTemplateNotification];
		}
	}
}



#pragma mark -

- (IBAction)manual:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.zankasoftware.com/wired/manual/#2"]];
}

@end
