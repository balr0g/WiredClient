/* $Id$ */

/*
 *  Copyright (c) 2005-2007 Axel Andersson
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

#import "WCLinkConnection.h"

#define WCServerConnectionWillReconnect					@"WCServerConnectionWillReconnect"

#define WCServerConnectionShouldHide					@"WCServerConnectionShouldHide"
#define WCServerConnectionShouldUnhide					@"WCServerConnectionShouldUnhide"
#define WCServerConnectionTriggeredEvent				@"WCServerConnectionTriggeredEvent"

#define WCServerConnectionShouldLoadWindowTemplate		@"WCServerConnectionShouldLoadWindowTemplate"
#define WCServerConnectionShouldSaveWindowTemplate		@"WCServerConnectionShouldSaveWindowTemplate"
#define WCServerConnectionThemeDidChangeNotification	@"WCServerConnectionThemeDidChangeNotification"

#define WCServerConnectionServerInfoDidChange			@"WCServerConnectionServerInfoDidChange"
#define WCServerConnectionPrivilegesDidChange			@"WCServerConnectionPrivilegesDidChange"

#define WCServerConnectionReceivedServerInfo			@"WCServerConnectionReceivedServerInfo"
#define WCServerConnectionReceivedPing					@"WCServerConnectionReceivedPing"
#define WCServerConnectionReceivedBanner				@"WCServerConnectionReceivedBanner"

#define WCServerConnectionEventConnectionKey			@"WCServerConnectionEventConnectionKey"
#define WCServerConnectionEventInfo1Key					@"WCServerConnectionEventInfo1Key"
#define WCServerConnectionEventInfo2Key					@"WCServerConnectionEventInfo2Key"


@class WCServer, WCCache, WCAccount;
@class WCLink, WCNotificationCenter;
@class WCAccounts, WCAdministration, WCPublicChat, WCConsole, WCNews, WCBoard, WCServerInfo;

@interface WCServerConnection : WCLinkConnection {
	NSDictionary										*_theme;
	
	NSUInteger											_userID;
	
	WCServer											*_server;
	WCCache												*_cache;
	
	WCAccounts											*_accounts;
	WCAdministration									*_administration;
	WCPublicChat										*_chat;
	WCConsole											*_console;
	WCNews												*_news;
	WCBoard												*_board;
	WCServerInfo										*_serverInfo;
	
	BOOL												_manuallyReconnecting;
	BOOL												_shouldAutoReconnect;
	BOOL												_autoReconnecting;
	BOOL												_hidden;
}

- (void)reconnect;
- (void)hide;
- (void)unhide;

- (void)triggerEvent:(int)event;
- (void)triggerEvent:(int)event info1:(id)info1;
- (void)triggerEvent:(int)event info1:(id)info1 info2:(id)info2;

- (void)setTheme:(NSDictionary *)theme;
- (NSDictionary *)theme;

- (BOOL)isReconnecting;
- (BOOL)isManuallyReconnecting;
- (BOOL)isAutoReconnecting;
- (BOOL)isHidden;
- (NSUInteger)userID;
- (NSString *)name;
- (WCAccount *)account;
- (WCServer *)server;
- (WCCache *)cache;

- (WCAccounts *)accounts;
- (WCAdministration *)administration;
- (WCPublicChat *)chat;
- (WCConsole *)console;
- (WCNews *)news;
- (WCBoard *)board;
- (WCServerInfo *)serverInfo;

@end
