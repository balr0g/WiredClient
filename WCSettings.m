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

#import "WCKeychain.h"
#import "WCPreferences.h"

#define _WCAutoHideOnSwitch						@"WCAutoHideOnSwitch"
#define _WCPreventMultipleConnections			@"WCPreventMultipleConnections"

#define _WCChatTextColor						@"WCChatTextColor"
#define _WCChatBackgroundColor					@"WCChatBackgroundColor"
#define _WCChatEventsColor						@"WCChatEventsColor"
#define _WCChatURLsColor						@"WCChatURLsColor"
#define _WCChatFont								@"WCChatFont"
#define _WCChatUserListAlternateRows			@"WCChatUserListAlternateRows"
#define _WCChatUserListIconSize					@"WCChatUserListIconSize"
#define _WCChatUserListIconSizeLarge				1
#define _WCChatUserListIconSizeSmall				0

#define _WCTimestampEveryLineColor				@"WCTimestampEveryLineColor"

#define _WCMessagesTextColor					@"WCMessagesTextColor"
#define _WCMessagesBackgroundColor				@"WCMessagesBackgroundColor"
#define _WCMessagesFont							@"WCMessagesFont"
#define _WCMessagesListAlternateRows			@"WCMessagesListAlternateRows"

#define _WCNewsTextColor						@"WCNewsTextColor"
#define _WCNewsBackgroundColor					@"WCNewsBackgroundColor"
#define _WCNewsFont								@"WCNewsFont"

#define _WCFilesAlternateRows					@"WCFilesAlternateRows"

#define _WCTransfersShowProgressBar				@"WCTransfersShowProgressBar"
#define _WCTransfersAlternateRows				@"WCTransfersAlternateRows"

#define _WCTrackersAlternateRows				@"WCTrackersAlternateRows"

#define _WCBookmarksPassword						@"Password"


@interface WCSettings(Private)

+ (void)_upgrade;

@end


@implementation WCSettings(Private)

+ (void)_upgrade {
	NSEnumerator			*enumerator;
	NSDictionary			*defaultTheme;
	NSMutableDictionary		*theme;
	NSArray					*bookmarks;
	NSMutableArray			*newBookmarks;
	NSDictionary			*bookmark;
	NSMutableDictionary		*newBookmark;
	NSString				*password;
	
	/* Convert font/color settings */
	defaultTheme = [[[self defaults] objectForKey:WCThemes] objectAtIndex:0];
	
	if([[self objectForKey:WCThemes] isEqualToArray:[NSArray arrayWithObject:defaultTheme]]) {
		theme = [[defaultTheme mutableCopy] autorelease];
			
		if([self objectForKey:_WCChatTextColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatTextColor]])
					  forKey:WCThemesChatTextColor];
		}
		
		if([self objectForKey:_WCChatBackgroundColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatBackgroundColor]])
					  forKey:WCThemesChatBackgroundColor];
		}

		if([self objectForKey:_WCChatEventsColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatEventsColor]])
					  forKey:WCThemesChatEventsColor];
		}

		if([self objectForKey:_WCChatURLsColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatURLsColor]])
					  forKey:WCThemesChatURLsColor];
		}

		if([self objectForKey:_WCChatFont]) {
			[theme setObject:WIStringFromFont([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCChatFont]])
					  forKey:WCThemesChatFont];
		}

		if([self objectForKey:_WCMessagesTextColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCMessagesTextColor]])
					  forKey:WCThemesMessagesTextColor];
		}
		
		if([self objectForKey:_WCMessagesBackgroundColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCMessagesBackgroundColor]])
					  forKey:WCThemesMessagesBackgroundColor];
		}
		
		if([self objectForKey:_WCMessagesFont]) {
			[theme setObject:WIStringFromFont([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCMessagesFont]])
					  forKey:WCThemesMessagesFont];
		}
		
		if([self objectForKey:_WCMessagesListAlternateRows]) {
			[theme setObject:[self objectForKey:_WCMessagesListAlternateRows]
					  forKey:WCThemesMessageListAlternateRows];
		}
		
		if([self objectForKey:_WCNewsTextColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCNewsTextColor]])
					  forKey:WCThemesNewsTextColor];
		}
		
		if([self objectForKey:_WCNewsBackgroundColor]) {
			[theme setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCNewsBackgroundColor]])
					  forKey:WCThemesNewsBackgroundColor];
		}
		
		if([self objectForKey:_WCNewsFont]) {
			[theme setObject:WIStringFromFont([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCNewsFont]])
					  forKey:WCThemesNewsFont];
		}
		
		if([self objectForKey:_WCFilesAlternateRows]) {
			[theme setObject:[self objectForKey:_WCFilesAlternateRows]
					  forKey:WCThemesFileListAlternateRows];
		}

		if([self objectForKey:_WCTransfersShowProgressBar]) {
			[theme setObject:[self objectForKey:_WCTransfersShowProgressBar]
					  forKey:WCThemesTransferListShowProgressBar];
		}

		if([self objectForKey:_WCTransfersAlternateRows]) {
			[theme setObject:[self objectForKey:_WCTransfersAlternateRows]
					  forKey:WCThemesTransferListAlternateRows];
		}

		if([self objectForKey:_WCTrackersAlternateRows]) {
			[theme setObject:[self objectForKey:_WCTrackersAlternateRows]
					  forKey:WCThemesTrackerListAlternateRows];
		}

		if(![theme isEqualToDictionary:defaultTheme]) {
			[theme setObject:@"Wired Client 1.x" forKey:WCThemesName];
			[theme setObject:[NSString UUIDString] forKey:WCThemesIdentifier];
			
			[self addObject:theme toArrayForKey:WCThemes];
		}

/*		[self removeObjectForKey:_WCChatTextColor];
		[self removeObjectForKey:_WCChatBackgroundColor];
		[self removeObjectForKey:_WCChatEventsColor];
		[self removeObjectForKey:_WCChatURLsColor];
		[self removeObjectForKey:_WCChatFont];
		[self removeObjectForKey:_WCMessagesTextColor];
		[self removeObjectForKey:_WCMessagesBackgroundColor];
		[self removeObjectForKey:_WCMessagesFont];
		[self removeObjectForKey:_WCMessagesListAlternateRows];
		[self removeObjectForKey:_WCNewsTextColor];
		[self removeObjectForKey:_WCNewsBackgroundColor];
		[self removeObjectForKey:_WCNewsFont];
		[self removeObjectForKey:_WCFilesAlternateRows];
		[self removeObjectForKey:_WCTransfersShowProgressBar];
		[self removeObjectForKey:_WCTransfersAlternateRows];
		[self removeObjectForKey:_WCTrackersAlternateRows];*/
	}
	
	if([self objectForKey:_WCTimestampEveryLineColor]) {
		[self setObject:WIStringFromColor([NSUnarchiver unarchiveObjectWithData:[self objectForKey:_WCTimestampEveryLineColor]])
				 forKey:WCChatTimestampEveryLineColor];
		
		[self removeObjectForKey:_WCTimestampEveryLineColor];
	}
	
	if(![self themeWithIdentifier:[self objectForKey:WCTheme]])
		[self setObject:[[[self objectForKey:WCThemes] objectAtIndex:0] objectForKey:WCThemesIdentifier] forKey:WCTheme];
	
	/* Convert bookmarks */
	bookmarks		= [self objectForKey:WCBookmarks];
	newBookmarks	= [NSMutableArray array];
	enumerator		= [bookmarks objectEnumerator];
	
	while((bookmark = [enumerator nextObject])) {
		newBookmark = [[bookmark mutableCopy] autorelease];
		
		if(![newBookmark objectForKey:WCBookmarksIdentifier])
			[newBookmark setObject:[NSString UUIDString] forKey:WCBookmarksIdentifier];

		if(![newBookmark objectForKey:WCBookmarksNick])
			[newBookmark setObject:@"" forKey:WCBookmarksNick];

		if(![newBookmark objectForKey:WCBookmarksStatus])
			[newBookmark setObject:@"" forKey:WCBookmarksStatus];
		
		password = [newBookmark objectForKey:_WCBookmarksPassword];

		if(password) {
			if([password length] > 0)
				[[WCKeychain keychain] setPassword:password forBookmark:newBookmark];
			
			[newBookmark removeObjectForKey:_WCBookmarksPassword];
		}
	
		[newBookmarks addObject:newBookmark];
	}
	
	[self setObject:newBookmarks forKey:WCBookmarks];

	/* Convert tracker bookmarks */
	bookmarks		= [self objectForKey:WCTrackerBookmarks];
	newBookmarks	= [NSMutableArray array];
	enumerator		= [bookmarks objectEnumerator];
	
	while((bookmark = [enumerator nextObject])) {
		newBookmark = [[bookmark mutableCopy] autorelease];
		
		if(![newBookmark objectForKey:WCTrackerBookmarksIdentifier])
			[newBookmark setObject:[NSString UUIDString] forKey:WCTrackerBookmarksIdentifier];

		if(![newBookmark objectForKey:WCTrackerBookmarksLogin])
			[newBookmark setObject:@"" forKey:WCTrackerBookmarksLogin];
		
		[newBookmarks addObject:newBookmark];
	}
	
	[self setObject:newBookmarks forKey:WCTrackerBookmarks];
}

@end


@implementation WCSettings

+ (void)loadWithIdentifier:(NSString *)identifier {
#ifndef RELEASE
	NSUserDefaults	*defaults;
	NSDictionary	*persistentDomain;
	
	defaults = [NSUserDefaults standardUserDefaults];
	persistentDomain = [defaults persistentDomainForName:@"com.zanka.WiredClientDebug"];
		
	if(!persistentDomain) {
		persistentDomain = [defaults persistentDomainForName:@"com.zanka.WiredClient"];
		
		if(persistentDomain)
			[defaults setPersistentDomain:persistentDomain forName:@"com.zanka.WiredClientDebug"];
	}
	
	[defaults synchronize];
#endif
	
	[super loadWithIdentifier:identifier];
	
	[self _upgrade];
}


	
+ (NSDictionary *)defaults {
	static NSString		*themesIdentifier;
	
	if(!themesIdentifier)
		themesIdentifier = [[NSString UUIDString] retain];

	return [NSDictionary dictionaryWithObjectsAndKeys:
		// --- general
		NSUserName(),
			WCNick,
		@"",
			WCStatus,
		@"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABGdBTUEAANkE3LLa"
		@"AgAAB7NJREFUeJztl31sVfUZxz/nnvO7p/f2hbb0Ddvby6XtpaVWECmgIorLNLyU"
		@"LAhbxpoyNmYVcZlBpEt0FDUxrrBlGTh1E0hGQQeJCx3BGUp1KC8iL7YFKRNKedEu"
		@"fS+9vb333HOe/YEQCkznZuI/fpNfcv74Pc/n+/yeJ3ly4Ft9w9L+l5hNmzaVHT16"
		@"9LbW0615Do7m9/nPFRUXfbxgwYK6zMzMga/dJUBdXd09k+6YtNvAEANDFEpu9h0s"
		@"CB5++eWXf/C1gZubm91Tp0596wrITDTFe6spSd/xSvLsBBkxJ15SZiVK4lSveP2e"
		@"q2YCgUBTS0tL9pfl/8IWHDx4sHja3dOaJSboiTpqikbSHYlkjskkJSmVeD0Bzdaw"
		@"JEp3rIuu9k76TvUT3h8lctxCEN6se3N6WVnZ3hMnTow6fvz4OE3TtNLS0sN+v7/n"
		@"Cw0cO3YsUDqp9AwxUEGDhDlu8sYGyfX4cYlONBbBiTnYtoPjOGiahuWK0k0PHZFP"
		@"6XvnEoM7o8QsGyPOsNLS0lQgEKCjo4OTJ08yY8aM7Q0NDQv+owG3221LVFxmiSJ5"
		@"QTy3+0opH1/BhFG386dDr7L/9D7C4TCWY2E7Fg4ODoJuGOhuF6HEPi41heh/ZQjH"
		@"ckjNTKW4uJj6+nrOnj1LMBiksrKyWr8ZfNGiRb9pPNJ4l8pUjFjoIT+9kMK0Ip68"
		@"/ylGJozEnzCabcdf51997YSsfnpCHQzaA9guG8uJEnUi6DEDvUAQU4g2x+gP9dPa"
		@"2kpTUxOVlZV0d3ezY8eOVNfNDGyp3fKEhkbcVIPU1HQM26A71E1nZycArT2nGZIh"
		@"+sOdhKJ9TBg7hexsP4PhPqKuMJYWIaKFcXrAW6bj9qmruR+a9xAA6enpOI6jjOvh"
		@"K1euXLH2xbW4R7tJmOwh2ZVCV7iT3lgvy/c8gT85wIcXD/BZzzk0Bf9YdpiSnNsA"
		@"eOzvj7D1g9cwTS+ia2iGhksH43sW/B4efeRRFv5oIQAbNmygqKjoyA0z4PP5TrWf"
		@"by+InxNH+oMpxA3GMxgdIOIM4TJc6MogFLlEpGuQO++8l13f3z0sPuulREQsdMON"
		@"ZoDlGoIYVIQeZ80v1gKwbNky1q9fT1tbW+oNL9B+vr3ApVyYt+tIBAbsfqJaBMdl"
		@"Yzk2segQTtRB88Ds/LIb2ufyCDYOomxsLFxxsOauVym/5ccAVD1Vxfr161m1atXj"
		@"fr+/Z5iBkpKSvR83fYye7kJPBysSJaZbOEYMASzCEBHyS8bxxv1vEhg5Zhj85+8v"
		@"xVZRNBNELHKzCthb+iFxHg8A5eXl1NbWsmLFiqdWr169DuCqgUAgcLK3p3csgBgC"
		@"HsG2ozjiYOsWsaiFSnbz7NRf8/CtSwGI9IWZtv1OIvYQ0ViYTuczDB9oJizN/yXP"
		@"5K8GoIcuJj09kTO156ioqFhbU1NTc4VrACxZsuSF06dPjx0KD3H+wnkUOijBcceI"
		@"OmGwIFhYwv4HD8PnA72/5QCzt9yD0w9aPLgSQeVpqBRFXdH7TEifAEDj+WM88MFk"
		@"hgYEgLy8vDPXvppx8eJFb2FhYdXOnTuZPn06AOGBCAmWAyZkpeVSc+vvmJk3+3LE"
		@"EMyvn8vud3ahZ2iYRYADrhHwUMFi1gVfuZr8Z4cW8dfDW3EXasQVKgbRcLlcMqxv"
		@"M2fO/PO8efOkt7dXgKunrOFBebdrj1yrqv3LJfVFQ1JWGZK5XcnWs5ulsf8jef5C"
		@"tZwZ+OTqvTfObpHs7YmSvlFJ1ltK8iVeRlZdXlQ7duy4d5iBjIyMtrlz54qIyMED"
		@"B6X+rXq5XtWHnpGslxIl9XlDMjYrGfW2kl0df7vh3vmus3L33omSvklJVp2SnH0e"
		@"8R3zSIF4JfG+ODFQw6sHWL58+UqllPT29g5Ldq7tgix+r1wy/uiWkWuUZGxVkl3v"
		@"lZxDbslpdouEh8O3XdgqGZuVZP5FyS3vuiX3ozjJbYyT0Rc9EujwiokpEydMbLjB"
		@"AMC4ceP2ATJ+/HiZXDpZRpgjBJCUakOydirJafBK7hGv+I97xX/KI74WU15t/8Mw"
		@"A/cdmCKj3lbiOxonuSc8kttsSs4HpuSLR0YsvFz9tm3bHrierQN0dHS8Vltbe0gp"
		@"dTIYDO7s7u92t7e3B4wBk9Qa9flYAG5BU4AuNHy6i+6eECmXkln6z5/yUWgfxi0a"
		@"mgKxBAmDKgLnM43uJUJaRuq5jZs2Pn69gZuu49bW1uRgINgDkPycIvlpjWirAzZg"
		@"gKaB1W0TOyNIBDQFRo6GnqQhFkgY9FHgHq1zsdAm2uLw+vat350/f/7u61k33YaB"
		@"QKD32ReerQTof8am51cOKqChxQsScnBCDi5dw8hyYWSAkeFC0zScfnBCgnsiqNE6"
		@"n95hY7U4/OThxS/cDP6lqqqqelKhRKEkabZH/Kc8khfziL/NlJz9bsl+15TsBrdk"
		@"N7jFd8wtgb7LPR+13SNmkikKJRXlFb/9yuBrVVtbO+uKCRMlSXNNydxgiv8Tj4wZ"
		@"jJPAJVPGDHjEd8gjac+Z4h17GaxQUl1d/dj/Bb9WixcvrrmS+MvOnFlzNrW1taX8"
		@"N3m/8o/JunXrfrhn9577G5saJ3V2dPps21Zp6WnniscVH5k2fdp7U6ZM2ThjxozY"
		@"Vy/xW31D+jfvNtPdS+ASBQAAAABJRU5ErkJggg==",
			WCIcon,
		
		[NSNumber numberWithBool:NO],
			WCShowConnectAtStartup,
		[NSNumber numberWithBool:YES],
			WCShowServersAtStartup,
		
		[NSNumber numberWithBool:YES],
			WCConfirmDisconnect,
		[NSNumber numberWithBool:NO],
			WCAutoReconnect,
		
		[NSNumber numberWithBool:YES],
			WCCheckForUpdate,
			
		// --- themes
		themesIdentifier,
			WCTheme,
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				NSLS(@"Basic", @"Theme"),										WCThemesName,
				themesIdentifier,												WCThemesIdentifier,
				WIStringFromFont([NSFont userFixedPitchFontOfSize:9.0]),		WCThemesChatFont,
				WIStringFromColor([NSColor blackColor]),						WCThemesChatTextColor,
				WIStringFromColor([NSColor whiteColor]),						WCThemesChatBackgroundColor,
				WIStringFromColor([NSColor blueColor]),							WCThemesChatURLsColor,
				WIStringFromColor([NSColor redColor]),							WCThemesChatEventsColor,
				WIStringFromFont([NSFont userFixedPitchFontOfSize:9.0]),		WCThemesMessagesFont,
				WIStringFromColor([NSColor blackColor]),						WCThemesMessagesTextColor,
				WIStringFromColor([NSColor whiteColor]),						WCThemesMessagesBackgroundColor,
				WIStringFromFont([NSFont fontWithName:@"Helvetica" size:12.0]),	WCThemesNewsFont,
				WIStringFromColor([NSColor blackColor]),						WCThemesNewsTextColor,
				WIStringFromColor([NSColor whiteColor]),						WCThemesNewsBackgroundColor,
				[NSNumber numberWithInteger:WCThemesUserListIconSizeLarge],		WCThemesUserListIconSize,
				[NSNumber numberWithBool:NO],									WCThemesUserListAlternateRows,
				[NSNumber numberWithBool:NO],									WCThemesMessageListAlternateRows,
				[NSNumber numberWithBool:NO],									WCThemesFileListAlternateRows,
				[NSNumber numberWithBool:YES],									WCThemesTransferListShowProgressBar,
				[NSNumber numberWithBool:NO],									WCThemesTransferListAlternateRows,
				[NSNumber numberWithBool:NO],									WCThemesTrackerListAlternateRows,
				NULL],
			NULL],
			WCThemes,

		// --- bookmarks
		[NSArray array],
			WCBookmarks,
		
		// --- chat/settings
		[NSNumber numberWithBool:NO],
			WCChatHistoryScrollback,
		[NSNumber numberWithInt:WCChatHistoryScrollbackModifierNone],
			WCChatHistoryScrollbackModifier,
		[NSNumber numberWithBool:YES],
			WCChatTabCompleteNicks,
		@": ",
			WCChatTabCompleteNicksString,
		[NSNumber numberWithBool:NO],
			WCChatTimestampChat,
		[NSNumber numberWithInt:300],
			WCChatTimestampChatInterval,
		[NSNumber numberWithBool:NO],
			WCChatTimestampEveryLine,
		WIStringFromColor([NSColor redColor]),
			WCChatTimestampEveryLineColor,
		[NSNumber numberWithBool:NO],
			WCChatShowSmileys,

		// --- chat/highlights
		[NSArray array],
			WCHighlights,

		// --- chat/ignores
		[NSArray array],
			WCIgnores,

		// --- events
		[NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsServerConnected],			WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsServerDisconnected],		WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsError],						WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsUserJoined],				WCEventsEvent,
				[NSNumber numberWithBool:YES],								WCEventsPostInChat,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsUserChangedNick],			WCEventsEvent,
				[NSNumber numberWithBool:YES],								WCEventsPostInChat,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsUserLeft],					WCEventsEvent,
				[NSNumber numberWithBool:YES],								WCEventsPostInChat,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsChatReceived],				WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsMessageReceived],			WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsNewsPosted],				WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsBroadcastReceived],			WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsTransferStarted],			WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsTransferFinished],			WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsUserChangedStatus],			WCEventsEvent,
				[NSNumber numberWithBool:NO],								WCEventsPostInChat,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsHighlightedChatReceived],	WCEventsEvent,
				NULL],
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:WCEventsChatInvitationReceived],	WCEventsEvent,
				NULL],
			NULL],
			WCEvents,
		[NSNumber numberWithFloat:1.0],
			WCEventsVolume,

		// --- files
		[@"~/Downloads" stringByExpandingTildeInPath],
			WCDownloadFolder,
		[NSNumber numberWithBool:NO],
			WCOpenFoldersInNewWindows,
		[NSNumber numberWithBool:YES],
			WCQueueTransfers,
		[NSNumber numberWithBool:YES],
			WCEncryptTransfers,
		[NSNumber numberWithBool:YES],
			WCCheckForResourceForks,
		[NSNumber numberWithBool:NO],
			WCRemoveTransfers,
		[NSNumber numberWithInt:WCFilesStyleList],
			WCFilesStyle,
		
		// --- trackers
		[NSArray arrayWithObject:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Zanka Tracker",				WCTrackerBookmarksName,
				@"wired.zankasoftware.com",		WCTrackerBookmarksAddress,
				@"",							WCTrackerBookmarksLogin,
				[NSString UUIDString],			WCTrackerBookmarksIdentifier,
				NULL]],
			WCTrackerBookmarks,
		
		// --- window templates
		[NSDictionary dictionary],
			WCWindowTemplates,
		
		// -- SSL
		@"ALL:!LOW:!EXP:!MD5",
			WCSSLControlCiphers,
		@"NULL:ALL:!LOW:!EXP:!MD5",
			WCSSLNullControlCiphers,
		@"RC4:ALL:!LOW:!EXP:!MD5",
			WCSSLTransferCiphers,
		@"NULL:RC4:ALL:!LOW:!EXP:!MD5",
			WCSSLNullTransferCiphers,
		
		// --- debug
		[NSNumber numberWithBool:NO],
			WCDebug,
		
		NULL];
}



#pragma mark -

+ (NSDictionary *)themeWithIdentifier:(NSString *)identifier {
	NSEnumerator	*enumerator;
	NSDictionary	*theme;
	
	enumerator = [[self objectForKey:WCThemes] objectEnumerator];
	
	while((theme = [enumerator nextObject])) {
		if([[theme objectForKey:WCThemesIdentifier] isEqualToString:identifier])
			return theme;
	}
	
	return NULL;
}



#pragma mark -

+ (NSDictionary *)eventWithTag:(NSUInteger)tag {
	NSEnumerator	*enumerator;
	NSDictionary	*event;
	
	enumerator = [[self objectForKey:WCEvents] objectEnumerator];
	
	while((event = [enumerator nextObject])) {
		if([event unsignedIntegerForKey:WCEventsEvent] == tag)
			return event;
	}
	
	return NULL;
}



#pragma mark -

+ (NSDictionary *)windowTemplateForKey:(NSString *)key {
	return [[self objectForKey:WCWindowTemplates] objectForKey:key];
}



+ (void)setWindowTemplate:(NSDictionary *)windowTemplate forKey:(NSString *)key {
	NSMutableDictionary		*windowTemplates;
	
	windowTemplates = [[self objectForKey:WCWindowTemplates] mutableCopy];
	[windowTemplates setObject:windowTemplate forKey:key];
	[self setObject:windowTemplates forKey:WCWindowTemplates];
	[windowTemplates release];
}

@end
