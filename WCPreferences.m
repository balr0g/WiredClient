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
#import "WCKeychain.h"
#import "WCPreferences.h"

#define WCThemePboardType									@"WCThemePboardType"
#define WCBookmarkPboardType								@"WCBookmarkPboardType"
#define WCHighlightPboardType								@"WCHighlightPboardType"
#define WCIgnorePboardType									@"WCIgnorePboardType"
#define WCTrackerBookmarkPboardType							@"WCTrackerBookmarkPboardType"


NSString * const WCPreferencesDidChangeNotification			= @"WCPreferencesDidChangeNotification";
NSString * const WCThemeDidChangeNotification				= @"WCThemeDidChangeNotification";
NSString * const WCSelectedThemeDidChangeNotification		= @"WCSelectedThemeDidChangeNotification";
NSString * const WCBookmarksDidChangeNotification			= @"WCBookmarksDidChangeNotification";
NSString * const WCBookmarkDidChangeNotification			= @"WCBookmarkDidChangeNotification";
NSString * const WCIgnoresDidChangeNotification				= @"WCIgnoresDidChangeNotification";
NSString * const WCTrackerBookmarksDidChangeNotification	= @"WCTrackerBookmarksDidChangeNotification";
NSString * const WCTrackerBookmarkDidChangeNotification		= @"WCTrackerBookmarkDidChangeNotification";
NSString * const WCNickDidChangeNotification				= @"WCNickDidChangeNotification";
NSString * const WCStatusDidChangeNotification				= @"WCStatusDidChangeNotification";
NSString * const WCIconDidChangeNotification				= @"WCIconDidChangeNotification";


@interface WCPreferences(Private)

- (void)_validate;

- (void)_bookmarkDidChange:(NSDictionary *)bookmark;

- (void)_reloadThemes;
- (void)_reloadTheme;
- (NSImage *)_imageForTheme:(NSDictionary *)theme size:(NSSize)size;
- (void)_reloadBookmark;
- (void)_reloadEvents;
- (void)_reloadEvent;
- (void)_updateEventControls;
- (void)_reloadDownloadFolder;
- (void)_reloadTrackerBookmark;

- (NSArray *)_themeNames;
- (void)_changeSelectedThemeToTheme:(NSDictionary *)theme;

- (void)_savePasswordForBookmark:(NSArray *)arguments;
- (void)_savePasswordForTrackerBookmark:(NSArray *)arguments;

@end


@implementation WCPreferences(Private)

- (void)_validate {
	NSDictionary		*theme;
	NSInteger			row;
	
	row = [_themesTableView selectedRow];
	
	if(row < 0) {
		[_deleteThemeButton setEnabled:NO];
	} else {
		theme = [[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row];
		
		[_deleteThemeButton setEnabled:![theme objectForKey:WCThemesBuiltinName]];
	}
	
	[_deleteBookmarkButton setEnabled:([_bookmarksTableView selectedRow] >= 0)];
	[_deleteHighlightButton setEnabled:([_highlightsTableView selectedRow] >= 0)];
	[_deleteIgnoreButton setEnabled:([_ignoresTableView selectedRow] >= 0)];
	[_deleteTrackerBookmarkButton setEnabled:([_trackerBookmarksTableView selectedRow] >= 0)];
}



#pragma mark -

- (void)_bookmarkDidChange:(NSDictionary *)bookmark {
	[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarkDidChangeNotification object:bookmark];
	[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
}



#pragma mark -

- (void)_reloadThemes {
	NSEnumerator	*enumerator;
	NSDictionary	*theme;
	NSMenuItem		*item;
	NSInteger		index;
	
	while((index = [_bookmarksThemePopUpButton indexOfItemWithTag:0]) != -1)
		[_bookmarksThemePopUpButton removeItemAtIndex:index];
	
	enumerator = [[[WCSettings settings] objectForKey:WCThemes] objectEnumerator];
	
	while((theme = [enumerator nextObject])) {
		item = [NSMenuItem itemWithTitle:[theme objectForKey:WCThemesName]];
		[item setRepresentedObject:[theme objectForKey:WCThemesIdentifier]];
		[item setImage:[self _imageForTheme:theme size:NSMakeSize(16.0, 12.0)]];
		
		[[_bookmarksThemePopUpButton menu] addItem:item];
	}
}



- (void)_reloadTheme {
	NSDictionary	*theme;
	NSInteger		row;
	
	row = [_themesTableView selectedRow];
	
	if(row >= 0 && (NSUInteger) row < [[[WCSettings settings] objectForKey:WCThemes] count]) {
		theme = [[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row];
		
		[_themesChatFontTextField setStringValue:[WIFontFromString([theme objectForKey:WCThemesChatFont]) displayNameWithSize]];
		[_themesChatTextColorWell setColor:WIColorFromString([theme objectForKey:WCThemesChatTextColor])];
		[_themesChatBackgroundColorWell setColor:WIColorFromString([theme objectForKey:WCThemesChatBackgroundColor])];
		[_themesChatEventsColorWell setColor:WIColorFromString([theme objectForKey:WCThemesChatEventsColor])];
		[_themesChatTimestampEveryLineColorWell setColor:WIColorFromString([theme objectForKey:WCThemesChatTimestampEveryLineColor])];
		[_themesChatURLsColorWell setColor:WIColorFromString([theme objectForKey:WCThemesChatURLsColor])];

		[_themesMessagesFontTextField setStringValue:[WIFontFromString([theme objectForKey:WCThemesMessagesFont]) displayNameWithSize]];
		[_themesMessagesTextColorWell setColor:WIColorFromString([theme objectForKey:WCThemesMessagesTextColor])];
		[_themesMessagesBackgroundColorWell setColor:WIColorFromString([theme objectForKey:WCThemesMessagesBackgroundColor])];

		[_themesBoardsFontTextField setStringValue:[WIFontFromString([theme objectForKey:WCThemesBoardsFont]) displayNameWithSize]];
		[_themesBoardsTextColorWell setColor:WIColorFromString([theme objectForKey:WCThemesBoardsTextColor])];
		[_themesBoardsBackgroundColorWell setColor:WIColorFromString([theme objectForKey:WCThemesBoardsBackgroundColor])];

		[_themesShowSmileysButton setState:[theme boolForKey:WCThemesShowSmileys]];

		[_themesChatTimestampEveryLineButton setState:[theme boolForKey:WCThemesChatTimestampEveryLine]];
		
		[_themesUserListIconSizeMatrix selectCellWithTag:[theme integerForKey:WCThemesUserListIconSize]];
		[_themesUserListAlternateRowsButton setState:[theme boolForKey:WCThemesUserListAlternateRows]];
		
		[_themesFileListIconSizeMatrix selectCellWithTag:[theme integerForKey:WCThemesFileListIconSize]];
		[_themesFileListAlternateRowsButton setState:[theme boolForKey:WCThemesFileListAlternateRows]];
		
		[_themesTransferListShowProgressBarButton setState:[theme boolForKey:WCThemesTransferListShowProgressBar]];
		[_themesTransferListAlternateRowsButton setState:[theme boolForKey:WCThemesTransferListAlternateRows]];
		
		[_themesTrackerListAlternateRowsButton setState:[theme boolForKey:WCThemesTrackerListAlternateRows]];
		
		[_themesMonitorIconSizeMatrix selectCellWithTag:[theme integerForKey:WCThemesMonitorIconSize]];
		[_themesMonitorAlternateRowsButton setState:[theme boolForKey:WCThemesMonitorAlternateRows]];
	}
}



- (NSImage *)_imageForTheme:(NSDictionary *)theme size:(NSSize)size {
	NSMutableDictionary		*attributes;
	NSBezierPath			*path;
	NSImage					*image;
	NSSize					largeSize;
	
	largeSize	= NSMakeSize(64.0, 48.0);
	image		= [[NSImage alloc] initWithSize:largeSize];
	
	[image lockFocus];
	
	path = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1.0, 1.0, largeSize.width - 2.0, largeSize.height - 2.0) cornerRadius:4.0];
	
	[WIColorFromString([theme objectForKey:WCThemesChatBackgroundColor]) set];
	[path fill];

	[[NSColor lightGrayColor] set];
	[path setLineWidth:2.0];
	[path stroke];
	
	attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSFont fontWithName:[WIFontFromString([theme objectForKey:WCThemesChatFont]) fontName] size:12.0],
			NSFontAttributeName,
		WIColorFromString([theme objectForKey:WCThemesChatTextColor]),
			NSForegroundColorAttributeName,
		NULL];

	[@"hello," drawAtPoint:NSMakePoint(8.0, largeSize.height - 19.0) withAttributes:attributes];
	[@"world!" drawAtPoint:NSMakePoint(8.0, largeSize.height - 31.0) withAttributes:attributes];
	
	[attributes setObject:WIColorFromString([theme objectForKey:WCThemesChatEventsColor]) forKey:NSForegroundColorAttributeName];
	
	[@"<< ! >>" drawAtPoint:NSMakePoint(8.0, largeSize.height - 43.0) withAttributes:attributes];

	[image unlockFocus];
	
	[image setScalesWhenResized:YES];
	[image setSize:size];
	
	return [image autorelease];
}



- (void)_reloadBookmark {
	NSDictionary	*bookmark;
	NSString		*theme;
	NSInteger		index, row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row >= 0 && (NSUInteger) row < [[[WCSettings settings] objectForKey:WCBookmarks] count]) {
		bookmark = [[[WCSettings settings] objectForKey:WCBookmarks] objectAtIndex:row];
		
		[_bookmarksAddressTextField setEnabled:YES];
		[_bookmarksLoginTextField setEnabled:YES];
		[_bookmarksPasswordTextField setEnabled:YES];
		[_bookmarksAutoConnectButton setEnabled:YES];
		[_bookmarksAutoReconnectButton setEnabled:YES];
		[_bookmarksNickTextField setEnabled:YES];
		[_bookmarksStatusTextField setEnabled:YES];

		[_bookmarksAddressTextField setStringValue:[bookmark objectForKey:WCBookmarksAddress]];
		[_bookmarksLoginTextField setStringValue:[bookmark objectForKey:WCBookmarksLogin]];
		
		[_bookmarksPassword release];
		_bookmarksPassword = [[[WCKeychain keychain] passwordForBookmark:bookmark] copy];

		if([[bookmark objectForKey:WCBookmarksAddress] length] > 0 && [_bookmarksPassword length] > 0)
			[_bookmarksPasswordTextField setStringValue:_bookmarksPassword];
		else
			[_bookmarksPasswordTextField setStringValue:@""];
		
		theme = [bookmark objectForKey:WCBookmarksTheme];
		
		if(theme && (index = [_bookmarksThemePopUpButton indexOfItemWithRepresentedObject:theme]) != -1)
			[_bookmarksThemePopUpButton selectItemAtIndex:index];
		else
			[_bookmarksThemePopUpButton selectItemAtIndex:0];
		
		[_bookmarksAutoConnectButton setState:[bookmark boolForKey:WCBookmarksAutoConnect]];
		[_bookmarksAutoReconnectButton setState:[bookmark boolForKey:WCBookmarksAutoReconnect]];
		[_bookmarksNickTextField setStringValue:[bookmark objectForKey:WCBookmarksNick]];
		[_bookmarksStatusTextField setStringValue:[bookmark objectForKey:WCBookmarksStatus]];
	} else {
		[_bookmarksAddressTextField setEnabled:NO];
		[_bookmarksLoginTextField setEnabled:NO];
		[_bookmarksPasswordTextField setEnabled:NO];
		[_bookmarksAutoConnectButton setEnabled:NO];
		[_bookmarksAutoReconnectButton setEnabled:NO];
		[_bookmarksNickTextField setEnabled:NO];
		[_bookmarksStatusTextField setEnabled:NO];

		[_bookmarksAddressTextField setStringValue:@""];
		[_bookmarksLoginTextField setStringValue:@""];
		[_bookmarksPasswordTextField setStringValue:@""];
		[_bookmarksAutoConnectButton setState:NSOffState];
		[_bookmarksAutoReconnectButton setState:NSOffState];
		[_bookmarksNickTextField setStringValue:@""];
		[_bookmarksStatusTextField setStringValue:@""];
	}
}



- (void)_reloadEvents {
	NSDictionary			*events;
	NSArray					*orderedEvents;
	NSEnumerator			*enumerator;
	NSDictionary			*event;
	NSString				*path;
	NSMenuItem				*item;
	NSNumber				*eventTag;
	
	[_eventsSoundsPopUpButton removeAllItems];

	enumerator = [[[NSFileManager defaultManager] libraryResourcesForTypes:[NSSound soundUnfilteredFileTypes] inDirectory:@"Sounds"] 
		objectEnumerator];

	while((path = [enumerator nextObject]))
		[_eventsSoundsPopUpButton addItemWithTitle:[[path lastPathComponent] stringByDeletingPathExtension]];

	[_eventsEventPopUpButton removeAllItems];
	
	events = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Server Connected", @"Event"),
			[NSNumber numberWithInt:WCEventsServerConnected],
		NSLS(@"Server Disconnected", @"Event"),
			[NSNumber numberWithInt:WCEventsServerDisconnected],
		NSLS(@"Error", @"Event"),
			[NSNumber numberWithInt:WCEventsError],
		NSLS(@"User Joined", @"Event"),
			[NSNumber numberWithInt:WCEventsUserJoined],
		NSLS(@"User Changed Nick", @"Event"),
			[NSNumber numberWithInt:WCEventsUserChangedNick],
		NSLS(@"User Changed Status", @"Event"),
			[NSNumber numberWithInt:WCEventsUserChangedStatus],
		NSLS(@"User Left", @"Event"),
			[NSNumber numberWithInt:WCEventsUserLeft],
		NSLS(@"Chat Received", @"Event"),
			[NSNumber numberWithInt:WCEventsChatReceived],
		NSLS(@"Highlighted Chat Received", @"Event"),
			[NSNumber numberWithInt:WCEventsHighlightedChatReceived],
		NSLS(@"Private Chat Invitation Received", @"Event"),
			[NSNumber numberWithInt:WCEventsChatInvitationReceived],
		NSLS(@"Message Received", @"Event"),
			[NSNumber numberWithInt:WCEventsMessageReceived],
		NSLS(@"Broadcast Received", @"Event"),
			[NSNumber numberWithInt:WCEventsBroadcastReceived],
		NSLS(@"Board Post Added", @"Event"),
			[NSNumber numberWithInt:WCEventsBoardPostReceived],
		NSLS(@"Transfer Started", @"Event"),
			[NSNumber numberWithInt:WCEventsTransferStarted],
		NSLS(@"Transfer Finished", @"Event"),
			[NSNumber numberWithInt:WCEventsTransferFinished],
		NULL];
	
	orderedEvents = [NSArray arrayWithObjects:
		[NSNumber numberWithInt:WCEventsServerConnected],
		[NSNumber numberWithInt:WCEventsServerDisconnected],
		[NSNumber numberWithInt:WCEventsError],
		[NSNumber numberWithInt:0],
		[NSNumber numberWithInt:WCEventsUserJoined],
		[NSNumber numberWithInt:WCEventsUserChangedNick],
		[NSNumber numberWithInt:WCEventsUserChangedStatus],
		[NSNumber numberWithInt:WCEventsUserLeft],
		[NSNumber numberWithInt:WCEventsChatReceived],
		[NSNumber numberWithInt:WCEventsHighlightedChatReceived],
		[NSNumber numberWithInt:WCEventsChatInvitationReceived],
		[NSNumber numberWithInt:WCEventsMessageReceived],
		[NSNumber numberWithInt:WCEventsBroadcastReceived],
		[NSNumber numberWithInt:WCEventsBoardPostReceived],
		[NSNumber numberWithInt:0],
		[NSNumber numberWithInt:WCEventsTransferStarted],
		[NSNumber numberWithInt:WCEventsTransferFinished],
		NULL];
	
	enumerator = [orderedEvents objectEnumerator];
	
	while((eventTag = [enumerator nextObject])) {
		if([eventTag intValue] > 0) {
			event = [[WCSettings settings] eventWithTag:[eventTag intValue]];

			item = [NSMenuItem itemWithTitle:[events objectForKey:eventTag]];
			[item setTag:[eventTag intValue]];

			if([event boolForKey:WCEventsPlaySound]  || [event boolForKey:WCEventsBounceInDock] ||
			   [event boolForKey:WCEventsPostInChat] || [event boolForKey:WCEventsShowDialog])
				[item setImage:[NSImage imageNamed:@"EventOn"]];
			else
				[item setImage:[NSImage imageNamed:@"EventOff"]];
			
			[[_eventsEventPopUpButton menu] addItem:item];
		} else {
			[[_eventsEventPopUpButton menu] addItem:[NSMenuItem separatorItem]];
		}
	}
}



- (void)_reloadEvent {
	NSDictionary	*event;
	NSString		*sound;
	NSInteger		tag;
	
	tag		= [_eventsEventPopUpButton tagOfSelectedItem];
	event	= [[WCSettings settings] eventWithTag:tag];
	
	[_eventsPlaySoundButton setState:[event boolForKey:WCEventsPlaySound]];
	
	sound = [event objectForKey:WCEventsSound];
	
	if(sound && [_eventsSoundsPopUpButton indexOfItemWithTitle:sound] != -1)
		[_eventsSoundsPopUpButton selectItemWithTitle:sound];
	else if ([_eventsSoundsPopUpButton numberOfItems] > 0)
		[_eventsSoundsPopUpButton selectItemAtIndex:0];

	[_eventsBounceInDockButton setState:[event boolForKey:WCEventsBounceInDock]];
	[_eventsPostInChatButton setState:[event boolForKey:WCEventsPostInChat]];
	[_eventsShowDialogButton setState:[event boolForKey:WCEventsShowDialog]];
	
	if(tag == WCEventsUserJoined || tag == WCEventsUserChangedNick ||
	   tag == WCEventsUserLeft || tag == WCEventsUserChangedStatus)
		[_eventsPostInChatButton setEnabled:YES];
	else
		[_eventsPostInChatButton setEnabled:NO];

	if(tag == WCEventsMessageReceived || tag == WCEventsBroadcastReceived)
		[_eventsShowDialogButton setEnabled:YES];
	else
		[_eventsShowDialogButton setEnabled:NO];

	[self _updateEventControls];
}



- (void)_updateEventControls {
	if([_eventsPlaySoundButton state] == NSOnState || [_eventsBounceInDockButton state] == NSOnState ||
	   [_eventsPostInChatButton state] == NSOnState || [_eventsShowDialogButton state] == NSOnState)
		[[_eventsEventPopUpButton selectedItem] setImage:[NSImage imageNamed:@"EventOn"]];
	else
		[[_eventsEventPopUpButton selectedItem] setImage:[NSImage imageNamed:@"EventOff"]];
	
	[_eventsSoundsPopUpButton setEnabled:[_eventsPlaySoundButton state]];
}



- (void)_reloadDownloadFolder {
	NSString		*downloadFolder;
	NSImage			*icon;
	
	downloadFolder = [[[WCSettings settings] objectForKey:WCDownloadFolder] stringByStandardizingPath];
	
	[_filesDownloadFolderMenuItem setTitle:[[NSFileManager defaultManager] displayNameAtPath:downloadFolder]];
	
	icon = [[NSWorkspace sharedWorkspace] iconForFile:downloadFolder];
	[icon setSize:NSMakeSize(16.0, 16.0)];
	
	[_filesDownloadFolderMenuItem setImage:icon];
}



- (void)_reloadTrackerBookmark {
	NSDictionary	*bookmark;
	NSInteger		row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row >= 0 && (NSUInteger) row < [[[WCSettings settings] objectForKey:WCTrackerBookmarks] count]) {
		bookmark = [[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectAtIndex:row];
		
		[_trackerBookmarksAddressTextField setEnabled:YES];
		[_trackerBookmarksLoginTextField setEnabled:YES];
		[_trackerBookmarksPasswordTextField setEnabled:YES];

		[_trackerBookmarksAddressTextField setStringValue:[bookmark objectForKey:WCTrackerBookmarksAddress]];
		[_trackerBookmarksLoginTextField setStringValue:[bookmark objectForKey:WCTrackerBookmarksLogin]];
		
		[_trackerBookmarksPassword release];
		_trackerBookmarksPassword = [[[WCKeychain keychain] passwordForTrackerBookmark:bookmark] copy];

		if([[bookmark objectForKey:WCTrackerBookmarksAddress] length] > 0 && [_trackerBookmarksPassword length] > 0)
			[_trackerBookmarksPasswordTextField setStringValue:_trackerBookmarksPassword];
		else
			[_trackerBookmarksPasswordTextField setStringValue:@""];
	} else {
		[_trackerBookmarksAddressTextField setEnabled:NO];
		[_trackerBookmarksLoginTextField setEnabled:NO];
		[_trackerBookmarksPasswordTextField setEnabled:NO];

		[_trackerBookmarksAddressTextField setStringValue:@""];
		[_trackerBookmarksLoginTextField setStringValue:@""];
		[_trackerBookmarksPasswordTextField setStringValue:@""];
	}
}



#pragma mark -

- (NSArray *)_themeNames {
	NSEnumerator		*enumerator;
	NSDictionary		*theme;
	NSMutableArray		*array;
	
	array			= [NSMutableArray array];
	enumerator		= [[[WCSettings settings] objectForKey:WCThemes] objectEnumerator];
	
	while((theme = [enumerator nextObject]))
		[array addObject:[theme objectForKey:WCThemesName]];
	
	return array;
}



- (void)_changeSelectedThemeToTheme:(NSDictionary *)theme {
	NSAlert		*alert;
	
	if([theme objectForKey:WCThemesBuiltinName]) {
		alert = [[NSAlert alloc] init];
		[alert setMessageText:[NSSWF:
			NSLS(@"You cannot edit the built-in theme \u201c%@\u201d", @"Duplicate builtin theme dialog title (theme)"),
			[theme objectForKey:WCThemesName]]];
		[alert setInformativeText:NSLS(@"Make a copy of it to edit it.", @"Duplicate builtin theme dialog description")];
		[alert addButtonWithTitle:NSLS(@"Duplicate", @"Duplicate builtin theme dialog button title")];
		[alert addButtonWithTitle:NSLS(@"Cancel", @"Duplicate builtin theme button title")];
		[alert beginSheetModalForWindow:[self window]
						  modalDelegate:self
						 didEndSelector:@selector(_changeBuiltinThemePanelDidEnd:returnCode:contextInfo:)
							contextInfo:[theme retain]];
		[alert release];
	} else {
		[[WCSettings settings] replaceObjectAtIndex:[_themesTableView selectedRow] withObject:theme inArrayForKey:WCThemes];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCThemeDidChangeNotification object:theme];

		[self _reloadTheme];
		[self _reloadThemes];
	}
}



- (void)_changeBuiltinThemePanelDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSMutableDictionary		*newTheme;
	NSDictionary			*theme = contextInfo;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		newTheme = [[theme mutableCopy] autorelease];
		[newTheme setObject:[WCApplicationController copiedNameForName:[theme objectForKey:WCThemesName] existingNames:[self _themeNames]]
					 forKey:WCThemesName];
		[newTheme setObject:[NSString UUIDString] forKey:WCThemesIdentifier];
		[newTheme removeObjectForKey:WCThemesBuiltinName];
		
		[[WCSettings settings] addObject:newTheme toArrayForKey:WCThemes];
		
		[_themesTableView reloadData];
		[_themesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCThemes] count] - 1]
					  byExtendingSelection:NO];
	}
	
	[theme release];
}



#pragma mark -

- (void)_savePasswordForBookmark:(NSArray *)arguments {
	NSDictionary		*oldBookmark = [arguments objectAtIndex:0];
	NSDictionary		*bookmark = [arguments objectAtIndex:1];
	NSString			*password = [arguments objectAtIndex:2];

	if(![oldBookmark isEqual:bookmark])
		[[WCKeychain keychain] deletePasswordForBookmark:oldBookmark];
	
	if([_bookmarksPassword length] > 0)
		[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
	else
		[[WCKeychain keychain] deletePasswordForBookmark:bookmark];
}



- (void)_savePasswordForTrackerBookmark:(NSArray *)arguments {
	NSDictionary		*oldBookmark = [arguments objectAtIndex:0];
	NSDictionary		*bookmark = [arguments objectAtIndex:1];
	NSString			*password = [arguments objectAtIndex:2];
	
	if(![oldBookmark isEqual:bookmark])
		[[WCKeychain keychain] deletePasswordForTrackerBookmark:oldBookmark];
	
	if([password length] > 0)
		[[WCKeychain keychain] setPassword:password forTrackerBookmark:bookmark];
	else
		[[WCKeychain keychain] deletePasswordForTrackerBookmark:bookmark];
}

@end


@implementation WCPreferences

+ (WCPreferences *)preferences {
	static id	sharedPreferences;

	if(!sharedPreferences)
		sharedPreferences = [[self alloc] init];

	return sharedPreferences;
}



- (id)init {
	self = [super initWithWindowNibName:@"Preferences"];
	
	[self window];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(themeDidChange:)
			   name:WCThemeDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bookmarksDidChange:)
			   name:WCBookmarksDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(ignoresDidChange:)
			   name:WCIgnoresDidChangeNotification];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(trackerBookmarksDidChange:)
			   name:WCTrackerBookmarksDidChangeNotification];

	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[self addPreferenceView:_generalView
					   name:NSLS(@"General", @"General preferences")
					  image:[NSImage imageNamed:@"General"]];
	
	[self addPreferenceView:_themesView
					   name:NSLS(@"Themes", @"Themes preferences")
					  image:[NSImage imageNamed:@"Themes"]];

	[self addPreferenceView:_bookmarksView
					   name:NSLS(@"Bookmarks", @"Bookmarks preferences")
					  image:[NSImage imageNamed:@"Bookmarks"]];
	
	[self addPreferenceView:_chatView
					   name:NSLS(@"Chat", @"Chat preferences")
					  image:[NSImage imageNamed:@"Chat"]];
	
	[self addPreferenceView:_eventsView
					   name:NSLS(@"Events", @"Events preferences")
					  image:[NSImage imageNamed:@"Events"]];
	
	[self addPreferenceView:_filesView
					   name:NSLS(@"Files", @"Files preferences")
					  image:[NSImage imageNamed:@"Folder"]];
	
	[self addPreferenceView:_trackersView
					   name:NSLS(@"Trackers", @"Trackers preferences")
					  image:[NSImage imageNamed:@"Trackers"]];
	
	[_iconImageView setMaxImageSize:NSMakeSize(32.0, 32.0)];
	[_iconImageView setDefaultImage:[NSImage imageNamed:@"DefaultIcon"]];

	[[_themesNameTableColumn dataCell] setHorizontalTextOffset:2.0];
	[[_themesNameTableColumn dataCell] setVerticalTextOffset:10.0];
	[[_themesNameTableColumn dataCell] setTextHeight:14.0];
	
	[_chatTabView selectFirstTabViewItem:self];
	
	[_highlightsTableView setTarget:self];
	[_highlightsTableView setDoubleAction:@selector(changeHighlightColor:)];
	
	[_themesTableView registerForDraggedTypes:[NSArray arrayWithObject:WCThemePboardType]];
	[_bookmarksTableView registerForDraggedTypes:[NSArray arrayWithObject:WCBookmarkPboardType]];
	[_highlightsTableView registerForDraggedTypes:[NSArray arrayWithObject:WCIgnorePboardType]];
	[_ignoresTableView registerForDraggedTypes:[NSArray arrayWithObject:WCIgnorePboardType]];
	[_trackerBookmarksTableView registerForDraggedTypes:[NSArray arrayWithObject:WCTrackerBookmarkPboardType]];
	
	[self _reloadThemes];
	[self _reloadTheme];
	[self _reloadBookmark];
	[self _reloadEvents];
	[self _reloadEvent];
	[self _reloadDownloadFolder];
	[self _reloadTrackerBookmark];
	
	[_nickTextField setStringValue:[[WCSettings settings] objectForKey:WCNick]];
	[_statusTextField setStringValue:[[WCSettings settings] objectForKey:WCStatus]];
	[_iconImageView setImage:[NSImage imageWithData:
		[NSData dataWithBase64EncodedString:[[WCSettings settings] objectForKey:WCIcon]]]];
	
	[_checkForUpdateButton setState:[[WCSettings settings] boolForKey:WCCheckForUpdate]];
	[_showConnectAtStartupButton setState:[[WCSettings settings] boolForKey:WCShowConnectAtStartup]];
	[_showServersAtStartupButton setState:[[WCSettings settings] boolForKey:WCShowServersAtStartup]];
	[_confirmDisconnectButton setState:[[WCSettings settings] boolForKey:WCConfirmDisconnect]];
	[_autoReconnectButton setState:[[WCSettings settings] boolForKey:WCAutoReconnect]];

	[_bookmarksNickTextField setPlaceholderString:[_nickTextField stringValue]];
	[_bookmarksStatusTextField setPlaceholderString:[_statusTextField stringValue]];
	
	[_chatHistoryScrollbackButton setState:[[WCSettings settings] boolForKey:WCChatHistoryScrollback]];
	[_chatHistoryScrollbackModifierPopUpButton selectItemWithTag:[[WCSettings settings] integerForKey:WCChatHistoryScrollbackModifier]];
	[_chatTabCompleteNicksButton setState:[[WCSettings settings] boolForKey:WCChatTabCompleteNicks]];
	[_chatTabCompleteNicksTextField setStringValue:[[WCSettings settings] objectForKey:WCChatTabCompleteNicksString]];
	[_chatTimestampChatButton setState:[[WCSettings settings] boolForKey:WCChatTimestampChat]];
	[_chatTimestampChatIntervalTextField setStringValue:[NSSWF:@"%.0f", [[WCSettings settings] doubleForKey:WCChatTimestampChatInterval] / 60.0]];

	[_eventsVolumeSlider setFloatValue:[[WCSettings settings] floatForKey:WCEventsVolume]];

	[_filesOpenFoldersInNewWindowsButton setState:[[WCSettings settings] boolForKey:WCOpenFoldersInNewWindows]];
	[_filesQueueTransfersButton setState:[[WCSettings settings] boolForKey:WCQueueTransfers]];
	[_filesCheckForResourceForksButton setState:[[WCSettings settings] boolForKey:WCCheckForResourceForks]];
	[_filesRemoveTransfersButton setState:[[WCSettings settings] boolForKey:WCRemoveTransfers]];

	[self _validate];
	
	[super windowDidLoad];
}



- (void)themeDidChange:(NSNotification *)notification {
	NSDictionary	*theme;
	
	theme = [notification object];
	
	if([[theme objectForKey:WCThemesIdentifier] isEqualToString:[[WCSettings settings] objectForKey:WCTheme]])
		[[NSNotificationCenter defaultCenter] postNotificationName:WCSelectedThemeDidChangeNotification object:theme];
	
	[_themesTableView setNeedsDisplay:YES];
}



- (void)bookmarksDidChange:(NSNotification *)notification {
	[_bookmarksTableView reloadData];
}



- (void)ignoresDidChange:(NSNotification *)notification {
	[_ignoresTableView reloadData];
}



- (void)trackerBookmarksDidChange:(NSNotification *)notification {
	[_trackerBookmarksTableView reloadData];
}



- (void)controlTextDidChange:(NSNotification *)notification {
	id			object;
	
	object = [notification object];

	if(object == _nickTextField) {
		[_bookmarksNickTextField setPlaceholderString:[_nickTextField stringValue]];
	}
	else if(object == _statusTextField) {
		[_bookmarksStatusTextField setPlaceholderString:[_statusTextField stringValue]];
	}
	else if(object == _bookmarksLoginTextField || object == _bookmarksPasswordTextField ||
			object == _bookmarksNickTextField || object == _bookmarksStatusTextField) {
		[self changeBookmark:object];
	}
	else if(object == _trackerBookmarksAddressTextField || object == _trackerBookmarksLoginTextField ||
			object == _trackerBookmarksPasswordTextField) {
		[self changeTrackerBookmark:object];
	}
}



#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)item {
	SEL		selector;
	
	selector = [item action];
	
	if(selector == @selector(duplicateBookmark:))
		return ([_bookmarksTableView selectedRow] >= 0);
	else if(selector == @selector(exportBookmarks:) || selector == @selector(importBookmarks:))
		return ([[[WCSettings settings] objectForKey:WCBookmarks] count] > 0);
	else if(selector == @selector(duplicateTrackerBookmark:))
		return ([_trackerBookmarksTableView selectedRow] >= 0);
	else if(selector == @selector(exportTrackerBookmarks:) || selector == @selector(importTrackerBookmarks:))
		return ([[[WCSettings settings] objectForKey:WCTrackerBookmarks] count] > 0);
	
	return YES;
}



#pragma mark -

- (BOOL)importThemeFromFile:(NSString *)path {
	NSMutableDictionary		*theme;
	
	[self showWindow:self];
	[self selectPreferenceView:_themesView];
	
	theme = [NSMutableDictionary dictionaryWithContentsOfFile:path];
	
	if(!theme || ![theme objectForKey:WCThemesName])
		return NO;
	
	[theme setObject:[NSString UUIDString] forKey:WCThemesIdentifier];
	
	[[WCSettings settings] addObject:theme toArrayForKey:WCThemes];
	
	[_themesTableView reloadData];
	[_themesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCThemes] count] - 1]
				  byExtendingSelection:NO];
	
	return YES;
}



- (BOOL)importBookmarksFromFile:(NSString *)path {
	NSEnumerator			*enumerator;
	NSArray					*array;
	NSMutableDictionary		*bookmark;
	NSDictionary			*dictionary;
	NSString				*password;
	NSUInteger				firstIndex;
	
	[self showWindow:self];
	[self selectPreferenceView:_bookmarksView];
	
	array = [NSArray arrayWithContentsOfFile:path];
	
	if(!array || [array count] == 0)
		return NO;
	
	firstIndex = NSNotFound;
	enumerator = [array objectEnumerator];
	
	while((dictionary = [enumerator nextObject])) {
		bookmark = [[dictionary mutableCopy] autorelease];
		
		if(![bookmark objectForKey:WCBookmarksName])
			continue;
		
		[bookmark setObject:[NSString UUIDString] forKey:WCBookmarksIdentifier];
		
		password = [bookmark objectForKey:WCBookmarksPassword];
		
		if(password) {
			[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
			
			[bookmark removeObjectForKey:WCBookmarksPassword];
		}
		
		[[WCSettings settings] addObject:bookmark toArrayForKey:WCBookmarks];
		
		if(firstIndex == NSNotFound)
			firstIndex = [[[WCSettings settings] objectForKey:WCBookmarks] count] - 1;
	}
	
	[_bookmarksTableView reloadData];
	[_bookmarksTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:firstIndex] byExtendingSelection:NO];
	
	return YES;
}



- (BOOL)importTrackerBookmarksFromFile:(NSString *)path {
	NSEnumerator			*enumerator;
	NSArray					*array;
	NSMutableDictionary		*bookmark;
	NSDictionary			*dictionary;
	NSString				*password;
	NSUInteger				firstIndex;
	
	[self showWindow:self];
	[self selectPreferenceView:_trackersView];

	array = [NSArray arrayWithContentsOfFile:path];

	if(!array || [array count] == 0)
		return NO;

	firstIndex = NSNotFound;
	enumerator = [array objectEnumerator];

	while((dictionary = [enumerator nextObject])) {
		bookmark = [[dictionary mutableCopy] autorelease];
		
		if(![bookmark objectForKey:WCTrackerBookmarksName])
			continue;
		
		[bookmark setObject:[NSString UUIDString] forKey:WCTrackerBookmarksIdentifier];
		
		password = [bookmark objectForKey:WCTrackerBookmarksPassword];
		
		if(password) {
			[[WCKeychain keychain] setPassword:password forTrackerBookmark:bookmark];
			
			[bookmark removeObjectForKey:WCTrackerBookmarksPassword];
		}
		
		[[WCSettings settings] addObject:bookmark toArrayForKey:WCTrackerBookmarks];
		
		if(firstIndex == NSNotFound)
			firstIndex = [[[WCSettings settings] objectForKey:WCBookmarks] count] - 1;
	}

	[_trackerBookmarksTableView reloadData];
	
	return YES;
}



#pragma mark -

- (IBAction)changePreferences:(id)sender {
	NSImage		*image;
	NSString	*string;
	
	if(![[_nickTextField stringValue] isEqualToString:[[WCSettings settings] objectForKey:WCNick]]) {
		[[WCSettings settings] setObject:[_nickTextField stringValue] forKey:WCNick];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCNickDidChangeNotification];
	}
	
	if(![[_statusTextField stringValue] isEqualToString:[[WCSettings settings] objectForKey:WCStatus]]) {
		[[WCSettings settings] setObject:[_statusTextField stringValue] forKey:WCStatus];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCStatusDidChangeNotification];
	}
	
	image = [_iconImageView image];
	
	if(image) {
		string = [[[NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]] representationUsingType:NSPNGFileType properties:NULL]
			base64EncodedString];
		
		if(!string)
			string = @"";
	} else {
		string	= @"";
	}

	if(![string isEqualToString:[[WCSettings settings] objectForKey:WCIcon]]) {
		[[WCSettings settings] setObject:string forKey:WCIcon];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCIconDidChangeNotification];
	}

	[[WCSettings settings] setBool:[_checkForUpdateButton state] forKey:WCCheckForUpdate];
	[[WCSettings settings] setBool:[_showConnectAtStartupButton state] forKey:WCShowConnectAtStartup];
	[[WCSettings settings] setBool:[_showServersAtStartupButton state] forKey:WCShowServersAtStartup];
	[[WCSettings settings] setBool:[_confirmDisconnectButton state] forKey:WCConfirmDisconnect];
	[[WCSettings settings] setBool:[_autoReconnectButton state] forKey:WCAutoReconnect];

	[[WCSettings settings] setBool:[_chatHistoryScrollbackButton state] forKey:WCChatHistoryScrollback];
	[[WCSettings settings] setInt:[_chatHistoryScrollbackModifierPopUpButton tagOfSelectedItem] forKey:WCChatHistoryScrollbackModifier];
	[[WCSettings settings] setBool:[_chatTabCompleteNicksButton state] forKey:WCChatTabCompleteNicks];
	[[WCSettings settings] setObject:[_chatTabCompleteNicksTextField stringValue] forKey:WCChatTabCompleteNicksString];
	[[WCSettings settings] setBool:[_chatTimestampChatButton state] forKey:WCChatTimestampChat];
	[[WCSettings settings] setInt:[_chatTimestampChatIntervalTextField intValue] * 60 forKey:WCChatTimestampChatInterval];

	[[WCSettings settings] setBool:[_filesOpenFoldersInNewWindowsButton state] forKey:WCOpenFoldersInNewWindows];
	[[WCSettings settings] setBool:[_filesQueueTransfersButton state] forKey:WCQueueTransfers];
	[[WCSettings settings] setBool:[_filesCheckForResourceForksButton state] forKey:WCCheckForResourceForks];
	[[WCSettings settings] setBool:[_filesRemoveTransfersButton state] forKey:WCRemoveTransfers];

	[[WCSettings settings] setFloat:[_eventsVolumeSlider floatValue] forKey:WCEventsVolume];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChangeNotification];
}



#pragma mark -

- (IBAction)addTheme:(id)sender {
	NSDictionary		*theme;
	
	theme = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled theme"),							WCThemesName,
		[NSString UUIDString],											WCThemesIdentifier,
		WIStringFromFont([NSFont userFixedPitchFontOfSize:9.0]),		WCThemesChatFont,
		WIStringFromColor([NSColor blackColor]),						WCThemesChatTextColor,
		WIStringFromColor([NSColor whiteColor]),						WCThemesChatBackgroundColor,
		WIStringFromColor([NSColor redColor]),							WCThemesChatEventsColor,
		WIStringFromColor([NSColor redColor]),							WCThemesChatTimestampEveryLineColor,
		WIStringFromColor([NSColor blueColor]),							WCThemesChatURLsColor,
		WIStringFromFont([NSFont userFixedPitchFontOfSize:9.0]),		WCThemesMessagesFont,
		WIStringFromColor([NSColor blackColor]),						WCThemesMessagesTextColor,
		WIStringFromColor([NSColor whiteColor]),						WCThemesMessagesBackgroundColor,
		WIStringFromFont([NSFont fontWithName:@"Helvetica" size:13.0]),	WCThemesBoardsFont,
		WIStringFromColor([NSColor blackColor]),						WCThemesBoardsTextColor,
		WIStringFromColor([NSColor whiteColor]),						WCThemesBoardsBackgroundColor,
		[NSNumber numberWithBool:NO],									WCThemesShowSmileys,
		[NSNumber numberWithBool:NO],									WCThemesChatTimestampEveryLine,
		[NSNumber numberWithInteger:WCThemesUserListIconSizeLarge],		WCThemesUserListIconSize,
		[NSNumber numberWithBool:NO],									WCThemesUserListAlternateRows,
		[NSNumber numberWithBool:NO],									WCThemesFileListAlternateRows,
		[NSNumber numberWithBool:YES],									WCThemesTransferListShowProgressBar,
		[NSNumber numberWithBool:NO],									WCThemesTransferListAlternateRows,
		[NSNumber numberWithBool:NO],									WCThemesTrackerListAlternateRows,
		[NSNumber numberWithInteger:WCThemesMonitorIconSizeLarge],		WCThemesMonitorIconSize,
		[NSNumber numberWithBool:NO],									WCThemesMonitorAlternateRows,
		NULL];

	[[WCSettings settings] addObject:theme toArrayForKey:WCThemes];

	[_themesTableView reloadData];
	[_themesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCThemes] count] - 1]
				  byExtendingSelection:NO];
	
	[self _reloadThemes];
}



- (IBAction)deleteTheme:(id)sender {
	NSAlert			*alert;
	NSString		*name;
	NSInteger		row;
	
	row = [_themesTableView selectedRow];
	
	if(row < 0)
		return;
	
	name = [[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row] objectForKey:WCThemesName];
	
	alert = [[NSAlert alloc] init];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete theme dialog title (theme)"), name]];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete theme dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete theme dialog button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete theme button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteThemeSheetDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSNumber alloc] initWithInteger:row]];
	[alert release];
}



- (void)deleteThemeSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber		*row = contextInfo;
	NSString		*identifier;

	if(returnCode == NSAlertFirstButtonReturn) {
		identifier = [[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:[row unsignedIntegerValue]]
			objectForKey:WCThemesIdentifier];
		
		if([[[WCSettings settings] objectForKey:WCTheme] isEqualToString:identifier]) {
			identifier = [[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:0] objectForKey:WCThemesIdentifier];
			
			[[WCSettings settings] setObject:identifier forKey:WCTheme];
		}
		
		[[WCSettings settings] removeObjectAtIndex:[row unsignedIntegerValue] fromArrayForKey:WCThemes];

		[_themesTableView reloadData];
		
		[self _reloadTheme];
	}
	
	[row release];
}



- (IBAction)duplicateTheme:(id)sender {
	NSMutableDictionary		*theme;
	NSInteger				row;
	
	row = [_themesTableView selectedRow];
	
	if(row < 0)
		return;
	
	theme = [[[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row] mutableCopy] autorelease];
	
	[theme setObject:[NSString UUIDString] forKey:WCThemesIdentifier];
	[theme removeObjectForKey:WCThemesBuiltinName];
	[theme setObject:[WCApplicationController copiedNameForName:[theme objectForKey:WCThemesName] existingNames:[self _themeNames]]
			  forKey:WCThemesName];
	
	[[WCSettings settings] addObject:theme toArrayForKey:WCThemes];
	
	[_themesTableView reloadData];
	[_themesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCThemes] count] - 1]
				  byExtendingSelection:NO];
}



- (IBAction)exportTheme:(id)sender {
	NSSavePanel				*savePanel;
	NSMutableDictionary		*theme;
	NSInteger				row;
	
	row = [_themesTableView selectedRow];
	
	if(row < 0)
		return;
	
	theme = [[[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row] mutableCopy] autorelease];
	[theme removeObjectForKey:WCThemesIdentifier];
	[theme removeObjectForKey:WCThemesBuiltinName];

	savePanel = [NSSavePanel savePanel];
	[savePanel setRequiredFileType:@"WiredTheme"];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel beginSheetForDirectory:NULL
								 file:[[theme objectForKey:WCThemesName] stringByAppendingPathExtension:@"WiredTheme"]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(exportThemePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:[theme retain]];
}



- (void)exportThemePanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSDictionary		*theme = contextInfo;
	
	if(returnCode == NSOKButton)
		[theme writeToFile:[savePanel filename] atomically:YES];
	
	[theme release];
}



- (IBAction)importTheme:(id)sender {
	NSOpenPanel			*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:[NSArray arrayWithObject:@"WiredTheme"]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(importThemePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)importThemePanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton)
		[self importThemeFromFile:[openPanel filename]];
}



- (IBAction)selectTheme:(id)sender {
	NSDictionary		*theme;
	NSInteger			row;
	
	row = [_themesTableView selectedRow];
	
	if(row < 0)
		return;
	
	theme = [[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row];
	
	[[WCSettings settings] setObject:[theme objectForKey:WCThemesIdentifier] forKey:WCTheme];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:WCThemeDidChangeNotification object:theme];

	[_themesTableView setNeedsDisplay:YES];
}



- (IBAction)changeTheme:(id)sender {
	NSMutableDictionary		*theme;
	NSDictionary			*oldTheme;
	NSInteger				row;
	
	row = [_themesTableView selectedRow];
	
	if(row < 0)
		return;

	oldTheme		= [[[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row] retain] autorelease];
	theme			= [[oldTheme mutableCopy] autorelease];
	
	[theme setObject:WIStringFromColor([_themesChatTextColorWell color]) forKey:WCThemesChatTextColor];
	[theme setObject:WIStringFromColor([_themesChatBackgroundColorWell color]) forKey:WCThemesChatBackgroundColor];
	[theme setObject:WIStringFromColor([_themesChatEventsColorWell color]) forKey:WCThemesChatEventsColor];
	[theme setObject:WIStringFromColor([_themesChatTimestampEveryLineColorWell color]) forKey:WCThemesChatTimestampEveryLineColor];
	[theme setObject:WIStringFromColor([_themesChatURLsColorWell color]) forKey:WCThemesChatURLsColor];
	
	[theme setObject:WIStringFromColor([_themesMessagesTextColorWell color]) forKey:WCThemesMessagesTextColor];
	[theme setObject:WIStringFromColor([_themesMessagesBackgroundColorWell color]) forKey:WCThemesMessagesBackgroundColor];
	[theme setObject:WIStringFromColor([_themesBoardsTextColorWell color]) forKey:WCThemesBoardsTextColor];
	[theme setObject:WIStringFromColor([_themesBoardsBackgroundColorWell color]) forKey:WCThemesBoardsBackgroundColor];
	
	[theme setBool:[_themesShowSmileysButton state] forKey:WCThemesShowSmileys];
	
	[theme setBool:[_themesChatTimestampEveryLineButton state] forKey:WCThemesChatTimestampEveryLine];
	
	[theme setInteger:[_themesUserListIconSizeMatrix selectedTag] forKey:WCThemesUserListIconSize];
	[theme setBool:[_themesUserListAlternateRowsButton state] forKey:WCThemesUserListAlternateRows];
	
	[theme setInteger:[_themesFileListIconSizeMatrix selectedTag] forKey:WCThemesFileListIconSize];
	[theme setBool:[_themesFileListAlternateRowsButton state] forKey:WCThemesFileListAlternateRows];
	
	[theme setBool:[_themesTransferListShowProgressBarButton state] forKey:WCThemesTransferListShowProgressBar];
	[theme setBool:[_themesTransferListAlternateRowsButton state] forKey:WCThemesTransferListAlternateRows];
	
	[theme setBool:[_themesTrackerListAlternateRowsButton state] forKey:WCThemesTrackerListAlternateRows];

	[theme setInteger:[_themesMonitorIconSizeMatrix selectedTag] forKey:WCThemesMonitorIconSize];
	[theme setBool:[_themesMonitorAlternateRowsButton state] forKey:WCThemesMonitorAlternateRows];
	
	if(![oldTheme isEqualToDictionary:theme])
		[self _changeSelectedThemeToTheme:theme];
}



- (IBAction)changeThemeFont:(id)sender {
	NSDictionary		*theme;
	NSFontManager		*fontManager;
	
	theme			= [[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:[_themesTableView selectedRow]];
	fontManager		= [NSFontManager sharedFontManager];
	
	if(sender == _themesChatFontButton) {
		[fontManager setSelectedFont:WIFontFromString([theme objectForKey:WCThemesChatFont]) isMultiple:NO];
		[fontManager setAction:@selector(setChatFont:)];
	}
	else if(sender == _themesMessagesFontButton) {
		[fontManager setSelectedFont:WIFontFromString([theme objectForKey:WCThemesMessagesFont]) isMultiple:NO];
		[fontManager setAction:@selector(setMessagesFont:)];
	}
	else if(sender == _themesBoardsFontButton) {
		[fontManager setSelectedFont:WIFontFromString([theme objectForKey:WCThemesBoardsFont]) isMultiple:NO];
		[fontManager setAction:@selector(setBoardsFont:)];
	}
	
	[fontManager orderFrontFontPanel:self];
}



- (void)setChatFont:(id)sender {
	NSMutableDictionary		*theme;
	NSFont					*font, *newFont;
	
	theme		= [[[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:[_themesTableView selectedRow]] mutableCopy] autorelease];
	font		= WIFontFromString([theme objectForKey:WCThemesChatFont]);
	newFont		= [sender convertFont:font];
	
	[theme setObject:WIStringFromFont(newFont) forKey:WCThemesChatFont];
	
	[self _changeSelectedThemeToTheme:theme];
}



- (void)setMessagesFont:(id)sender {
	NSMutableDictionary		*theme;
	NSFont					*font, *newFont;
	
	theme		= [[[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:[_themesTableView selectedRow]] mutableCopy] autorelease];
	font		= WIFontFromString([theme objectForKey:WCThemesMessagesFont]);
	newFont		= [sender convertFont:font];
	
	[theme setObject:WIStringFromFont(newFont) forKey:WCThemesMessagesFont];
	
	[self _changeSelectedThemeToTheme:theme];
}



- (void)setBoardsFont:(id)sender {
	NSMutableDictionary		*theme;
	NSFont					*font, *newFont;
	
	theme		= [[[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:[_themesTableView selectedRow]] mutableCopy] autorelease];
	font		= WIFontFromString([theme objectForKey:WCThemesBoardsFont]);
	newFont		= [sender convertFont:font];
	
	[theme setObject:WIStringFromFont(newFont) forKey:WCThemesBoardsFont];
	
	[self _changeSelectedThemeToTheme:theme];
}



#pragma mark -

- (IBAction)addBookmark:(id)sender {
	NSDictionary	*bookmark;
	
	bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled bookmark"),	WCBookmarksName,
		@"",										WCBookmarksAddress,
		@"",										WCBookmarksLogin,
		[NSString UUIDString],						WCBookmarksIdentifier,
		[NSNumber numberWithBool:NO],				WCBookmarksAutoConnect,
		[NSNumber numberWithBool:NO],				WCBookmarksAutoReconnect,
		@"",										WCBookmarksNick,
		@"",										WCBookmarksStatus,
		NULL];
	
	[[WCSettings settings] addObject:bookmark toArrayForKey:WCBookmarks];

	[_bookmarksTableView reloadData];
	[_bookmarksTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCBookmarks] count] - 1]
					 byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
}



- (IBAction)deleteBookmark:(id)sender {
	NSAlert			*alert;
	NSString		*name;
	NSInteger		row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	name = [[[[WCSettings settings] objectForKey:WCBookmarks] objectAtIndex:row] objectForKey:WCBookmarksName];
	
	alert = [[NSAlert alloc] init];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete bookmark dialog title (bookmark)"), name]];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete bookmark dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete bookmark dialog button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete bookmark button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteBookmarkSheetDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSNumber alloc] initWithInteger:row]];
	[alert release];
}



- (void)deleteBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber	*row = contextInfo;

	if(returnCode == NSAlertFirstButtonReturn) {
		[[WCKeychain keychain] deletePasswordForBookmark:[[[WCSettings settings] objectForKey:WCBookmarks] objectAtIndex:[row integerValue]]];
		
		[[WCSettings settings] removeObjectAtIndex:[row integerValue] fromArrayForKey:WCBookmarks];

		[_bookmarksTableView reloadData];
		
		[self _reloadBookmark];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
	}
	
	[row release];
}



- (IBAction)duplicateBookmark:(id)sender {
	NSMutableDictionary		*bookmark;
	NSString				*password;
	NSInteger				row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	bookmark = [[[[[WCSettings settings] objectForKey:WCBookmarks] objectAtIndex:row] mutableCopy] autorelease];
	password = [[WCKeychain keychain] passwordForBookmark:bookmark];
	
	[bookmark setObject:[NSString UUIDString] forKey:WCBookmarksIdentifier];
	
	[[WCKeychain keychain] setPassword:password forBookmark:bookmark];
	
	[[WCSettings settings] addObject:bookmark toArrayForKey:WCBookmarks];

	[_bookmarksTableView reloadData];
	[_bookmarksTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCBookmarks] count] - 1]
					 byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
}



- (IBAction)exportBookmarks:(id)sender {
	NSSavePanel				*savePanel;
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setRequiredFileType:@"WiredBookmarks"];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setAccessoryView:_bookmarksExportView];
	[savePanel beginSheetForDirectory:NULL
								 file:[NSLS(@"Bookmarks", @"Default export bookmarks name")
										stringByAppendingPathExtension:@"WiredBookmarks"]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(exportBookmarksPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)exportBookmarksPanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator			*enumerator;
	NSMutableArray			*bookmarks;
	NSMutableDictionary		*bookmark;
	NSDictionary			*dictionary;
	NSString				*password;
	
	if(returnCode == NSOKButton) {
		bookmarks	= [NSMutableArray array];
		enumerator	= [[[WCSettings settings] objectForKey:WCBookmarks] objectEnumerator];
		
		while((dictionary = [enumerator nextObject])) {
			bookmark = [[dictionary mutableCopy] autorelease];
			password = [[WCKeychain keychain] passwordForBookmark:bookmark];
			
			if(password)
				[bookmark setObject:password forKey:WCBookmarksPassword];
			
			[bookmark removeObjectForKey:WCBookmarksIdentifier];
			
			[bookmarks addObject:bookmark];
		}
		
		[bookmarks writeToURL:[savePanel URL] atomically:YES];
	}
}



- (IBAction)importBookmarks:(id)sender {
	NSOpenPanel			*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:[NSArray arrayWithObject:@"WiredBookmarks"]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(importBookmarksPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)importBookmarksPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton)
		[self importBookmarksFromFile:[openPanel filename]];
}



- (IBAction)changeBookmark:(id)sender {
	NSMutableDictionary		*bookmark;
	NSDictionary			*oldBookmark;
	NSString				*password;
	NSInteger				row;
	
	row = [_bookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	oldBookmark		= [[[[[WCSettings settings] objectForKey:WCBookmarks] objectAtIndex:row] retain] autorelease];
	bookmark		= [[oldBookmark mutableCopy] autorelease];
	password		= [_bookmarksPasswordTextField stringValue];

	[bookmark setObject:[_bookmarksAddressTextField stringValue] forKey:WCBookmarksAddress];
	[bookmark setObject:[_bookmarksLoginTextField stringValue] forKey:WCBookmarksLogin];
	
	if([_bookmarksThemePopUpButton representedObjectOfSelectedItem])
		[bookmark setObject:[_bookmarksThemePopUpButton representedObjectOfSelectedItem] forKey:WCBookmarksTheme];
	else
		[bookmark removeObjectForKey:WCBookmarksTheme];
	
	[bookmark setBool:[_bookmarksAutoConnectButton state] forKey:WCBookmarksAutoConnect];
	[bookmark setBool:[_bookmarksAutoReconnectButton state] forKey:WCBookmarksAutoReconnect];
	[bookmark setObject:[_bookmarksNickTextField stringValue] forKey:WCBookmarksNick];
	[bookmark setObject:[_bookmarksStatusTextField stringValue] forKey:WCBookmarksStatus];
	
	if(!_bookmarksPassword || ![_bookmarksPassword isEqualToString:password] ||
	   ![[oldBookmark objectForKey:WCBookmarksAddress] isEqualToString:[bookmark objectForKey:WCBookmarksAddress]]) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		[self performSelector:@selector(_savePasswordForBookmark:)
				   withObject:[NSArray arrayWithObjects:oldBookmark, bookmark, password, NULL]
				   afterDelay:1.0];

		[_bookmarksPassword release];
		_bookmarksPassword = [password copy];
	}
	
	if(![oldBookmark isEqualToDictionary:bookmark]) {
		[[WCSettings settings] replaceObjectAtIndex:row withObject:bookmark inArrayForKey:WCBookmarks];
		
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_bookmarkDidChange:) object:oldBookmark];
		[self performSelector:@selector(_bookmarkDidChange:) withObject:bookmark afterDelay:1.0];
	}
}



#pragma mark -

- (IBAction)addHighlight:(id)sender {
	NSDictionary	*highlight;
	NSColor			*color;
	NSInteger		row;
	
	row = [[[WCSettings settings] objectForKey:WCHighlights] count] - 1;
	
	if(row >= 0)
		color = WIColorFromString([[[[WCSettings settings] objectForKey:WCHighlights] objectAtIndex:row] objectForKey:WCHighlightsColor]);
	else
		color = [NSColor yellowColor];
	
	highlight = [NSDictionary dictionaryWithObjectsAndKeys:
		@"",						WCHighlightsPattern,
		WIStringFromColor(color),	WCHighlightsColor,
		NULL];
	
	[[WCSettings settings] addObject:highlight toArrayForKey:WCHighlights];

	row = [[[WCSettings settings] objectForKey:WCHighlights] count] - 1;
	
	[_highlightsTableView reloadData];
	[_highlightsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[_highlightsTableView editColumn:0 row:row withEvent:NULL select:YES];
}



- (IBAction)deleteHighlight:(id)sender {
	NSAlert		*alert;
	NSInteger	row;
	
	row = [_highlightsTableView selectedRow];

	if(row < 0)
		return;

	alert = [[NSAlert alloc] init];
	[alert setMessageText:NSLS(@"Are you sure you want to delete the selected highlight?", @"Delete highlight dialog title (bookmark)")];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete highlight dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete highlight dialog button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete highlight button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteHighlightSheetDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSNumber alloc] initWithInteger:row]];
	[alert release];
}



- (void)deleteHighlightSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber	*row = contextInfo;

	if(returnCode == NSAlertFirstButtonReturn) {
		[[WCSettings settings] removeObjectAtIndex:[row integerValue] fromArrayForKey:WCHighlights];
		
		[_highlightsTableView reloadData];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChangeNotification];
	}
	
	[row release];
}



- (void)changeHighlightColor:(id)sender {
	NSColorPanel	*colorPanel;
	NSDictionary	*highlight;
	NSInteger		row;
	
	row = [_highlightsTableView selectedRow];
	
	if(row < 0)
		return;
	
	highlight = [[[WCSettings settings] objectForKey:WCHighlights] objectAtIndex:row];
	
	colorPanel = [NSColorPanel sharedColorPanel];
	[colorPanel setTarget:self];
	[colorPanel setAction:@selector(setHighlightColor:)];
	[colorPanel setColor:WIColorFromString([highlight objectForKey:WCHighlightsColor])];
	[colorPanel makeKeyAndOrderFront:self];
}



- (void)setHighlightColor:(id)sender {
	NSMutableDictionary		*highlight;
	NSInteger				row;
	
	if(_highlightsTableView == [[self window] firstResponder]) {
		row = [_highlightsTableView selectedRow];
		
		if(row < 0)
			return;
		
		highlight = [[[[[WCSettings settings] objectForKey:WCHighlights] objectAtIndex:row] mutableCopy] autorelease];
		[highlight setObject:WIStringFromColor([sender color]) forKey:WCHighlightsColor];

		[[WCSettings settings] replaceObjectAtIndex:row withObject:highlight inArrayForKey:WCHighlights];
		
		[_highlightsTableView reloadData];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChangeNotification];
	}
}



#pragma mark -

- (IBAction)addIgnore:(id)sender {
	NSDictionary	*ignore;
	NSInteger		row;
	
	ignore = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled ignore"),		WCIgnoresNick,
		NULL];
	
	[[WCSettings settings] addObject:ignore toArrayForKey:WCIgnores];
	
	row = [[[WCSettings settings] objectForKey:WCIgnores] count] - 1;

	[_ignoresTableView reloadData];
	[_ignoresTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[_ignoresTableView editColumn:0 row:row withEvent:NULL select:YES];
}



- (IBAction)deleteIgnore:(id)sender {
	NSAlert		*alert;
	NSInteger	row;

	row = [_ignoresTableView selectedRow];
		
	if(row < 0)
		return;

	alert = [[NSAlert alloc] init];
	[alert setMessageText:NSLS(@"Are you sure you want to delete the selected ignore?", @"Delete ignore dialog title (bookmark)")];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete ignore dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete ignore dialog button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete ignore button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteIgnoreSheetDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSNumber alloc] initWithInteger:row]];
	[alert release];
}



- (void)deleteIgnoreSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber	*row = contextInfo;
	
	if(returnCode == NSAlertFirstButtonReturn) {
		[[WCSettings settings] removeObjectAtIndex:[row integerValue] fromArrayForKey:WCIgnores];
		
		[_ignoresTableView reloadData];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChangeNotification];
	}
	
	[row release];
}



#pragma mark -

- (IBAction)selectEvent:(id)sender {
	[self _reloadEvent];
}



- (IBAction)changeEvent:(id)sender {
	NSMutableArray			*events;
	NSMutableDictionary		*event;
	NSUInteger				i, count;
	NSInteger				tag;
	
	events	= [[[[WCSettings settings] objectForKey:WCEvents] mutableCopy] autorelease];
	tag		= [_eventsEventPopUpButton tagOfSelectedItem];
	count	= [events count];
	
	for(i = 0; i < count; i++) {
		if([[events objectAtIndex:i] integerForKey:WCEventsEvent] == tag) {
			event = [[[events objectAtIndex:i] mutableCopy] autorelease];

			[event setBool:[_eventsPlaySoundButton state] forKey:WCEventsPlaySound];
			[event setObject:[_eventsSoundsPopUpButton titleOfSelectedItem] forKey:WCEventsSound];
			[event setBool:[_eventsBounceInDockButton state] forKey:WCEventsBounceInDock];
			[event setBool:[_eventsPostInChatButton state] forKey:WCEventsPostInChat];
			[event setBool:[_eventsShowDialogButton state] forKey:WCEventsShowDialog];
			
			[events replaceObjectAtIndex:i withObject:event];
			
			break;
		}
	}
	
	[[WCSettings settings] setObject:events forKey:WCEvents];
	
	[self _updateEventControls];
	
	if(sender == _eventsSoundsPopUpButton || (sender == _eventsPlaySoundButton && [sender state] == NSOnState))
		[NSSound playSoundNamed:[_eventsSoundsPopUpButton titleOfSelectedItem]];
}



#pragma mark -

- (IBAction)otherDownloadFolder:(id)sender {
	NSOpenPanel		*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:NO];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanCreateDirectories:YES];
	[openPanel setTitle:NSLS(@"Select Download Folder", @"Select download folder dialog title")];
	[openPanel setPrompt:NSLS(@"Select", @"Select download folder dialog button title")];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(downloadFolderPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)downloadFolderPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton) {
		[[WCSettings settings] setObject:[openPanel filename] forKey:WCDownloadFolder];
		
		[self _reloadDownloadFolder];
	}
	
	[_filesDownloadFolderPopUpButton selectItem:_filesDownloadFolderMenuItem];
}



#pragma mark -

- (IBAction)addTrackerBookmark:(id)sender {
	NSDictionary	*bookmark;
	
	bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
		NSLS(@"Untitled", @"Untitled tracker bookmark"),	WCTrackerBookmarksName,
		@"",												WCTrackerBookmarksAddress,
		@"",												WCTrackerBookmarksLogin,
		[NSString UUIDString],								WCTrackerBookmarksIdentifier,
		NULL];

	[[WCSettings settings] addObject:bookmark toArrayForKey:WCTrackerBookmarks];
	
	[_trackerBookmarksTableView reloadData];
	[_trackerBookmarksTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCTrackerBookmarks] count] - 1]
							byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChangeNotification];
}



#pragma mark -

- (IBAction)deleteTrackerBookmark:(id)sender {
	NSAlert		*alert;
	NSString	*name;
	NSInteger	row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	name = [[[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectAtIndex:row] objectForKey:WCTrackerBookmarksName];
	
	alert = [[NSAlert alloc] init];
	[alert setMessageText:[NSSWF:NSLS(@"Are you sure you want to delete \u201c%@\u201d?", @"Delete tracker bookmark dialog title (bookmark)"), name]];
	[alert setInformativeText:NSLS(@"This cannot be undone.", @"Delete tracker bookmark dialog description")];
	[alert addButtonWithTitle:NSLS(@"Delete", @"Delete tracker bookmark dialog button title")];
	[alert addButtonWithTitle:NSLS(@"Cancel", @"Delete tracker bookmark button title")];
	[alert beginSheetModalForWindow:[self window]
					  modalDelegate:self
					 didEndSelector:@selector(deleteTrackerBookmarkSheetDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSNumber alloc] initWithInteger:row]];
	[alert release];
}



- (void)deleteTrackerBookmarkSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSNumber	*row = contextInfo;

	if(returnCode == NSAlertFirstButtonReturn) {
		[[WCSettings settings] removeObjectAtIndex:[row integerValue] fromArrayForKey:WCTrackerBookmarks];
		
		[_trackerBookmarksTableView reloadData];
		
		[self _reloadTrackerBookmark];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChangeNotification];
	}
	
	[row release];
}



- (IBAction)duplicateTrackerBookmark:(id)sender {
	NSMutableDictionary		*bookmark;
	NSString				*password;
	NSInteger				row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	bookmark = [[[[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectAtIndex:row] mutableCopy] autorelease];
	password = [[WCKeychain keychain] passwordForTrackerBookmark:bookmark];
	
	[bookmark setObject:[NSString UUIDString] forKey:WCTrackerBookmarksIdentifier];
	
	[[WCKeychain keychain] setPassword:password forTrackerBookmark:bookmark];
	
	[[WCSettings settings] addObject:bookmark toArrayForKey:WCTrackerBookmarks];

	[_trackerBookmarksTableView reloadData];
	[_trackerBookmarksTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[[[WCSettings settings] objectForKey:WCTrackerBookmarks] count] - 1]
							byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChangeNotification];
}



- (IBAction)exportTrackerBookmarks:(id)sender {
	NSSavePanel				*savePanel;
	
	savePanel = [NSSavePanel savePanel];
	[savePanel setRequiredFileType:@"WiredTrackerBookmarks"];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setAccessoryView:_bookmarksExportView];
	[savePanel beginSheetForDirectory:NULL
								 file:[NSLS(@"Bookmarks", @"Default export bookmarks name")
										stringByAppendingPathExtension:@"WiredTrackerBookmarks"]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(exportTrackerBookmarksPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)exportTrackerBookmarksPanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator			*enumerator;
	NSMutableArray			*bookmarks;
	NSMutableDictionary		*bookmark;
	NSDictionary			*dictionary;
	NSString				*password;
	
	if(returnCode == NSOKButton) {
		bookmarks	= [NSMutableArray array];
		enumerator	= [[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectEnumerator];
		
		while((dictionary = [enumerator nextObject])) {
			bookmark = [[dictionary mutableCopy] autorelease];
			password = [[WCKeychain keychain] passwordForTrackerBookmark:bookmark];
			
			if(password)
				[bookmark setObject:password forKey:WCTrackerBookmarksPassword];
			
			[bookmark removeObjectForKey:WCTrackerBookmarksIdentifier];
			
			[bookmarks addObject:bookmark];
		}
		
		[bookmarks writeToURL:[savePanel URL] atomically:YES];
	}
}



- (IBAction)importTrackerBookmarks:(id)sender {
	NSOpenPanel			*openPanel;
	
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel beginSheetForDirectory:NULL
								 file:NULL
								types:[NSArray arrayWithObject:@"WiredTrackerBookmarks"]
					   modalForWindow:[self window]
						modalDelegate:self
					   didEndSelector:@selector(importTrackerBookmarksPanelDidEnd:returnCode:contextInfo:)
						  contextInfo:NULL];
}



- (void)importTrackerBookmarksPanelDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	if(returnCode == NSOKButton)
		[self importTrackerBookmarksFromFile:[openPanel filename]];
}



- (IBAction)changeTrackerBookmark:(id)sender {
	NSMutableDictionary		*bookmark;
	NSDictionary			*oldBookmark;
	NSString				*password;
	NSInteger				row;
	
	row = [_trackerBookmarksTableView selectedRow];
	
	if(row < 0)
		return;
	
	oldBookmark		= [[[[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectAtIndex:row] retain] autorelease];
	bookmark		= [[oldBookmark mutableCopy] autorelease];
	password		= [_trackerBookmarksPasswordTextField stringValue];
	
	[bookmark setObject:[_trackerBookmarksAddressTextField stringValue] forKey:WCTrackerBookmarksAddress];
	[bookmark setObject:[_trackerBookmarksLoginTextField stringValue] forKey:WCTrackerBookmarksLogin];
	
	if(!_trackerBookmarksPassword || ![_trackerBookmarksPassword isEqualToString:password] ||
	   ![[oldBookmark objectForKey:WCTrackerBookmarksAddress] isEqualToString:[bookmark objectForKey:WCTrackerBookmarksAddress]]) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self];
		[self performSelector:@selector(_savePasswordForTrackerBookmark:)
				   withObject:[NSArray arrayWithObjects:oldBookmark, bookmark, password, NULL]
				   afterDelay:1.0];

		[_trackerBookmarksPassword release];
		_trackerBookmarksPassword = [password copy];
	}

	if(![oldBookmark isEqualToDictionary:bookmark]) {
		[[WCSettings settings] replaceObjectAtIndex:row withObject:bookmark inArrayForKey:WCTrackerBookmarks];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarkDidChangeNotification object:bookmark];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChangeNotification];
	}
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	if(tableView == _themesTableView)
		return [[[WCSettings settings] objectForKey:WCThemes] count];
	else if(tableView == _bookmarksTableView)
		return [[[WCSettings settings] objectForKey:WCBookmarks] count];
	else if(tableView == _highlightsTableView)
		return [[[WCSettings settings] objectForKey:WCHighlights] count];
	else if(tableView == _ignoresTableView)
		return [[[WCSettings settings] objectForKey:WCIgnores] count];
	else if(tableView == _trackerBookmarksTableView)
		return [[[WCSettings settings] objectForKey:WCTrackerBookmarks] count];

	return 0;
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
	NSDictionary	*dictionary;
		
	if(tableView == _themesTableView) {
		dictionary = [[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row];
		
		if(column == _themesNameTableColumn)
			return [dictionary objectForKey:WCThemesName];
	}
	else if(tableView == _bookmarksTableView) {
		dictionary = [[[WCSettings settings] objectForKey:WCBookmarks] objectAtIndex:row];
		
		if(column == _bookmarksNameTableColumn)
			return [dictionary objectForKey:WCBookmarksName];
	}
	else if(tableView == _highlightsTableView) {
		dictionary = [[[WCSettings settings] objectForKey:WCHighlights] objectAtIndex:row];
		
		if(column == _highlightsPatternTableColumn)
			return [dictionary objectForKey:WCHighlightsPattern];
		else if(column == _highlightsColorTableColumn)
			return WIColorFromString([dictionary objectForKey:WCHighlightsColor]);
	}
	else if(tableView == _ignoresTableView) {
		dictionary = [[[WCSettings settings] objectForKey:WCIgnores] objectAtIndex:row];
		
		if(column == _ignoresNickTableColumn)
			return [dictionary objectForKey:WCIgnoresNick];
	}
	else if(tableView == _trackerBookmarksTableView) {
		dictionary = [[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectAtIndex:row];
		
		if(column == _trackerBookmarksNameTableColumn)
			return [dictionary objectForKey:WCTrackerBookmarksName];
	}

	return NULL;
}



- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSDictionary		*dictionary;
	
	if(tableView == _themesTableView) {
		dictionary = [[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row];
		
		return ([dictionary objectForKey:WCThemesBuiltinName] == NULL);
	}
	
	return YES;
}



- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSMutableDictionary		*dictionary;
	
	if(tableView == _themesTableView) {
		dictionary = [[[[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row] mutableCopy] autorelease];
		
		if(tableColumn == _themesNameTableColumn)
			[dictionary setObject:object forKey:WCThemesName];
		
		[[WCSettings settings] replaceObjectAtIndex:row withObject:dictionary inArrayForKey:WCThemes];
		
		[self _reloadThemes];
	}
	else if(tableView == _bookmarksTableView) {
		dictionary = [[[[[WCSettings settings] objectForKey:WCBookmarks] objectAtIndex:row] mutableCopy] autorelease];
		
		if(tableColumn == _bookmarksNameTableColumn)
			[dictionary setObject:object forKey:WCBookmarksName];
		
		[[WCSettings settings] replaceObjectAtIndex:row withObject:dictionary inArrayForKey:WCBookmarks];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarkDidChangeNotification object:dictionary];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];
	}
	if(tableView == _highlightsTableView) {
		dictionary = [[[[[WCSettings settings] objectForKey:WCHighlights] objectAtIndex:row] mutableCopy] autorelease];
		
		if(tableColumn == _highlightsPatternTableColumn)
			[dictionary setObject:object forKey:WCHighlightsPattern];
		
		[[WCSettings settings] replaceObjectAtIndex:row withObject:dictionary inArrayForKey:WCHighlights];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChangeNotification];
	}
	else if(tableView == _ignoresTableView) {
		dictionary = [[[[[WCSettings settings] objectForKey:WCIgnores] objectAtIndex:row] mutableCopy] autorelease];
		
		if(tableColumn == _ignoresNickTableColumn)
			[dictionary setObject:object forKey:WCIgnoresNick];
	
		[[WCSettings settings] replaceObjectAtIndex:row withObject:dictionary inArrayForKey:WCIgnores];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCPreferencesDidChangeNotification];
	}
	else if(tableView == _trackerBookmarksTableView) {
		dictionary = [[[[[WCSettings settings] objectForKey:WCTrackerBookmarks] objectAtIndex:row] mutableCopy] autorelease];
		
		if(tableColumn == _trackerBookmarksNameTableColumn)
			[dictionary setObject:object forKey:WCTrackerBookmarksName];
		
		[[WCSettings settings] replaceObjectAtIndex:row withObject:dictionary inArrayForKey:WCTrackerBookmarks];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarkDidChangeNotification object:dictionary];
		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChangeNotification];
	}
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSDictionary		*theme;
	
	if(tableView == _themesTableView) {
		theme = [[[WCSettings settings] objectForKey:WCThemes] objectAtIndex:row];
		
		if([[theme objectForKey:WCThemesIdentifier] isEqualToString:[[WCSettings settings] objectForKey:WCTheme]])
			[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
		else
			[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
		
		[cell setImage:[self _imageForTheme:theme size:NSMakeSize(32.0, 24.0)]];
	}
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	NSTableView		*tableView;
	
	tableView = [notification object];
	
	if(tableView == _themesTableView)
		[self _reloadTheme];
	else if(tableView == _bookmarksTableView)
		[self _reloadBookmark];
	else if(tableView == _trackerBookmarksTableView)
		[self _reloadTrackerBookmark];

	[self _validate];
}



- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)indexes toPasteboard:(NSPasteboard *)pasteboard {
	NSUInteger		index;
	
	index = [indexes firstIndex];
	
	if(tableView == _themesTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCThemePboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%ld", index] forType:WCThemePboardType];
		
		return YES;
	}
	else if(tableView == _bookmarksTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCBookmarkPboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%ld", index] forType:WCBookmarkPboardType];
		
		return YES;
	}
	else if(tableView == _highlightsTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCHighlightPboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%ld", index] forType:WCHighlightPboardType];
		
		return YES;
	}
	else if(tableView == _ignoresTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCIgnorePboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%ld", index] forType:WCIgnorePboardType];
		
		return YES;
	}
	else if(tableView == _trackerBookmarksTableView) {
		[pasteboard declareTypes:[NSArray arrayWithObject:WCTrackerBookmarkPboardType] owner:NULL];
		[pasteboard setString:[NSSWF:@"%ld", index] forType:WCTrackerBookmarkPboardType];
		
		return YES;
	}

	return NO;
}



- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	if(operation != NSTableViewDropAbove)
		return NSDragOperationNone;

	return NSDragOperationGeneric;
}



- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
	NSMutableArray		*array;
	NSPasteboard		*pasteboard;
	NSArray				*types;
	NSUInteger			index;
	
	pasteboard = [info draggingPasteboard];
	types = [pasteboard types];
	
	if([types containsObject:WCThemePboardType]) {
		array = [[[[WCSettings settings] objectForKey:WCThemes] mutableCopy] autorelease];
		index = [array moveObjectAtIndex:[[pasteboard stringForType:WCThemePboardType] integerValue] toIndex:row];

		[[WCSettings settings] setObject:array forKey:WCThemes];
		
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		
		[self _reloadThemes];

		return YES;
	}
	if([types containsObject:WCBookmarkPboardType]) {
		array = [[[[WCSettings settings] objectForKey:WCBookmarks] mutableCopy] autorelease];
		index = [array moveObjectAtIndex:[[pasteboard stringForType:WCBookmarkPboardType] integerValue] toIndex:row];

		[[WCSettings settings] setObject:array forKey:WCBookmarks];
		
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCBookmarksDidChangeNotification];

		return YES;
	}
	else if([types containsObject:WCHighlightPboardType]) {
		array = [[[[WCSettings settings] objectForKey:WCHighlights] mutableCopy] autorelease];
		[array moveObjectAtIndex:[[pasteboard stringForType:WCHighlightPboardType] integerValue] toIndex:row];

		[[WCSettings settings] setObject:array forKey:WCHighlights];
		
		return YES;
	}
	else if([types containsObject:WCIgnorePboardType]) {
		array = [[[[WCSettings settings] objectForKey:WCIgnores] mutableCopy] autorelease];
		[array moveObjectAtIndex:[[pasteboard stringForType:WCIgnorePboardType] integerValue] toIndex:row];

		[[WCSettings settings] setObject:array forKey:WCIgnores];
		
		return YES;
	}
	else if([types containsObject:WCTrackerBookmarkPboardType]) {
		array = [[[[WCSettings settings] objectForKey:WCTrackerBookmarks] mutableCopy] autorelease];
		index = [array moveObjectAtIndex:[[pasteboard stringForType:WCTrackerBookmarkPboardType] integerValue] toIndex:row];

		[[WCSettings settings] setObject:array forKey:WCTrackerBookmarks];

		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];

		[[NSNotificationCenter defaultCenter] postNotificationName:WCTrackerBookmarksDidChangeNotification];

		return YES;
	}
	
	return NO;
}

@end
