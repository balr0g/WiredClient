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

#define WCServerConnectionWillReconnectNotification				@"WCServerConnectionWillReconnectNotification"

#define WCServerConnectionTriggeredEventNotification			@"WCServerConnectionTriggeredEventNotification"

#define WCServerConnectionThemeDidChangeNotification			@"WCServerConnectionThemeDidChangeNotification"

#define WCServerConnectionServerInfoDidChangeNotification		@"WCServerConnectionServerInfoDidChangeNotification"
#define WCServerConnectionPrivilegesDidChangeNotification		@"WCServerConnectionPrivilegesDidChangeNotification"

#define WCServerConnectionReceivedServerInfoNotification		@"WCServerConnectionReceivedServerInfoNotification"
#define WCServerConnectionReceivedPingNotification				@"WCServerConnectionReceivedPingNotification"
#define WCServerConnectionReceivedBannerNotification			@"WCServerConnectionReceivedBannerNotification"

#define WCServerConnectionReceivedLoginErrorNotification		@"WCServerConnectionReceivedLoginErrorNotification"

#define	WCServerConnectionEventConnectionKey					@"WCServerConnectionEventConnectionKey"
#define WCServerConnectionEventInfo1Key							@"WCServerConnectionEventInfo1Key"
#define WCServerConnectionEventInfo2Key							@"WCServerConnectionEventInfo2Key"


@class WCServer, WCCache, WCAccount;
@class WCLink, WCNotificationCenter;
@class WCAccounts, WCAdministration, WCPublicChatController, WCConsole, WCServerInfo;

@interface WCServerConnection : WCLinkConnection {
	NSString													*_identifier;
	NSDictionary												*_theme;
	
	NSUInteger													_userID;
	
	WCServer													*_server;
	WCCache														*_cache;
	
	WCAccounts													*_accounts;
	WCAdministration											*_administration;
	WCPublicChatController										*_chatController;
	WCConsole													*_console;
	WCServerInfo												*_serverInfo;
	
	NSMutableArray												*_connectionControllers;
	
	BOOL														_manuallyReconnecting;
	BOOL														_shouldAutoReconnect;
	BOOL														_autoReconnecting;
	
	BOOL														_hasConnected;
	
	NSUInteger													_autoReconnectAttempts;
}

- (void)reconnect;

- (void)triggerEvent:(int)event;
- (void)triggerEvent:(int)event info1:(id)info1;
- (void)triggerEvent:(int)event info1:(id)info1 info2:(id)info2;

- (void)setIdentifier:(NSString *)identifier;
- (NSString *)identifier;
- (void)setTheme:(NSDictionary *)theme;
- (NSDictionary *)theme;

- (BOOL)isReconnecting;
- (BOOL)isManuallyReconnecting;
- (BOOL)isAutoReconnecting;
- (NSUInteger)userID;
- (NSString *)name;
- (WCAccount *)account;
- (WCServer *)server;
- (WCCache *)cache;

- (WCAccounts *)accounts;
- (WCAdministration *)administration;
- (WCPublicChatController *)chatController;
- (WCConsole *)console;
- (WCServerInfo *)serverInfo;

- (void)addConnectionController:(WCConnectionController *)connectionController;
- (void)removeConnectionController:(WCConnectionController *)connectionController;

@end
