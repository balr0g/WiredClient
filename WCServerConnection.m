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

#import "NSAlert-WCAdditions.h"
#import "WCAccount.h"
#import "WCAccounts.h"
#import "WCAdministration.h"
#import "WCApplicationController.h"
#import "WCBoards.h"
#import "WCCache.h"
#import "WCConsole.h"
#import "WCDock.h"
#import "WCLink.h"
#import "WCMessages.h"
#import "WCNews.h"
#import "WCNotificationCenter.h"
#import "WCPreferences.h"
#import "WCPublicChat.h"
#import "WCSearch.h"
#import "WCServer.h"
#import "WCServerConnection.h"
#import "WCServerInfo.h"
#import "WCTransfers.h"

@implementation WCServerConnection

- (id)init {
	self = [super init];
	
	_server = [[WCServer alloc] init];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(nickDidChange:)
			   name:WCNickDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(statusDidChange:)
			   name:WCStatusDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(iconDidChange:)
			   name:WCIconDidChange];

	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(bookmarksDidChange:)
			   name:WCBookmarksDidChange];

	[self addObserver:self
			 selector:@selector(serverConnectionShouldHide:)
				 name:WCServerConnectionShouldHide];

	[self addObserver:self
			 selector:@selector(serverConnectionShouldUnhide:)
				 name:WCServerConnectionShouldUnhide];

	[self addObserver:self
			 selector:@selector(chatSelfWasKicked:)
				 name:WCChatSelfWasKicked];

	[self addObserver:self
			 selector:@selector(chatSelfWasKicked:)
				 name:WCChatSelfWasBanned];

	[self addObserver:self selector:@selector(wiredAccountPrivileges:) messageName:@"wired.account.privileges"];
	
	[self retain];
	
	return self;
}



- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self removeObserver:self];
	
	[_server release];
	[_cache release];
	
	[_notificationCenter release];
	[_linkNotificationCenter release];

	[_console release];
	[_accounts release];
	[_news release];
	[_board release];
	[_serverInfo release];
	[_chat release];
	
	[super dealloc];
}



#pragma mark -

- (void)nickDidChange:(NSNotification *)notification {
	[self sendMessage:[self setNickMessage]];
}



- (void)statusDidChange:(NSNotification *)notification {
	[self sendMessage:[self setStatusMessage]];
}



- (void)iconDidChange:(NSNotification *)notification {
	[self sendMessage:[self setIconMessage]];
}



- (void)bookmarksDidChange:(NSNotification *)notification {
	NSDictionary	*bookmark;
	
	bookmark = [notification userInfo];
	
	if([[bookmark objectForKey:WCBookmarksIdentifier] isEqualToString:[[self bookmark] objectForKey:WCBookmarksIdentifier]]) {
		[self sendMessage:[self setNickMessage]];
		[self sendMessage:[self setStatusMessage]];
	}
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoReconnect) object:NULL];
	
	[super linkConnectionDidTerminate:notification];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	NSTimeInterval		time;
	
	[super linkConnectionDidClose:notification];
	
	[self triggerEvent:WCEventsServerDisconnected];

	if(_shouldAutoReconnect && ([WCSettings boolForKey:WCAutoReconnect])) {
		time = (100.0 + (random() % 200)) / 10.0;

		[[self chat] printEvent:[NSSWF:NSLS(@"Reconnecting to %@ in %.1f seconds...", @"Auto-reconnecting chat message"),
			[self name], time]];

		[self performSelector:@selector(autoReconnect) afterDelay:time];
	}
}



- (void)wiredSendPing:(WIP7Message *)message {
	[self replyMessage:[WIP7Message messageWithName:@"wired.ping" spec:WCP7Spec] toMessage:message];
}



- (void)wiredServerInfo:(WIP7Message *)message {
	[super wiredServerInfo:message];

	[_server setWithMessage:message];
	
	if([self isReconnecting]) {
		[[self chat] printEvent:[NSSWF:NSLS(@"Reconnected to %@", @"Reconnected chat message"),
			[self name]]];
	}

	[self postNotificationName:WCServerConnectionServerInfoDidChange object:self];
}



- (void)wiredLoginReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.login"]) {
		[message getUInt32:&_userID forName:@"wired.user.id"];

		_manuallyReconnecting	= NO;
		_autoReconnecting		= NO;
		_shouldAutoReconnect	= YES;
		
		[self triggerEvent:WCEventsServerConnected];
	}
	else if([[message name] isEqualToString:@"wired.account.privileges"]) {
		[_server setAccount:[WCUserAccount accountWithMessage:message]];

		[self postNotificationName:WCServerConnectionPrivilegesDidChange object:self];
	}
	
	[super wiredLoginReply:message];
}



- (void)wiredAccountPrivileges:(WIP7Message *)message {
	[_server setAccount:[WCUserAccount accountWithMessage:message]];

	[self postNotificationName:WCServerConnectionPrivilegesDidChange object:self];
}



- (void)serverConnectionShouldHide:(NSNotification *)notification {
	_hidden = YES;
}



- (void)serverConnectionShouldUnhide:(NSNotification *)notification {
	_hidden = NO;
}



- (void)chatSelfWasKicked:(NSNotification *)notification {
	_shouldAutoReconnect = NO;
}



#pragma mark -

- (void)connect {
	if(!_cache) {
		_cache			= [[WCCache alloc] initWithCapacity:100];

#if defined(DEBUG) || defined(TEST)
		_console		= [[WCConsole consoleWithConnection:self] retain];
#endif
		
		_accounts		= [[WCAccounts accountsWithConnection:self] retain];
		_administration	= [[WCAdministration administrationWithConnection:self] retain];
		_news			= [[WCNews newsWithConnection:self] retain];
		_serverInfo		= [[WCServerInfo serverInfoWithConnection:self] retain];

		_chat			= [[WCPublicChat publicChatWithConnection:self] retain];
	}
	
	[super connect];
}



- (void)reconnect {
	if(![self isConnected] && !_manuallyReconnecting) {
		_autoReconnecting		= NO;
		_manuallyReconnecting	= YES;
		_shouldAutoReconnect	= YES;
		
		[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(autoReconnect) object:NULL];
		
		[[self chat] printEvent:[NSSWF:NSLS(@"Reconnecting to %@...", @"Reconnecting chat message"),
			[self name]]];
		
		[self postNotificationName:WCServerConnectionWillReconnect object:self];

		[self connect];
	}
}



- (void)autoReconnect {
	if(![self isConnected] && !_autoReconnecting) {
		_autoReconnecting		= YES;
		_manuallyReconnecting	= NO;
		
		[self postNotificationName:WCServerConnectionWillReconnect object:self];

		[self connect];
	}
}



- (void)hide {
	[self postNotificationName:WCServerConnectionShouldHide object:self];
}



- (void)unhide {
	[self postNotificationName:WCServerConnectionShouldUnhide object:self];
}



#pragma mark -

- (void)triggerEvent:(int)tag {
	[self triggerEvent:tag info1:NULL info2:NULL];
}



- (void)triggerEvent:(int)tag info1:(id)info1 {
	[self triggerEvent:tag info1:info1 info2:NULL];
}



- (void)triggerEvent:(int)tag info1:(id)info1 info2:(id)info2 {
	NSMutableDictionary	*userInfo;
	NSDictionary		*event;
	
	event = [WCSettings eventForTag:tag];
	userInfo = [NSMutableDictionary dictionaryWithObject:self forKey:WCServerConnectionEventConnectionKey];
	
	if(info1)
		[userInfo setObject:info1 forKey:WCServerConnectionEventInfo1Key];
	
	if(info2)
		[userInfo setObject:info2 forKey:WCServerConnectionEventInfo2Key];
	
	[self postNotificationName:WCServerConnectionTriggeredEvent object:event userInfo:userInfo];
}



#pragma mark -

- (BOOL)isDisconnecting {
	return _disconnecting;
}



- (BOOL)isReconnecting {
	return (_manuallyReconnecting || _autoReconnecting);
}



- (BOOL)isManuallyReconnecting {
	return _manuallyReconnecting;
}



- (BOOL)isAutoReconnecting {
	return _autoReconnecting;
}



- (BOOL)isHidden {
	return _hidden;
}



- (NSUInteger)userID {
	return _userID;
}



- (NSString *)name {
	return [_server name];
}



- (WCAccount *)account {
	return [_server account];
}



- (WCServer *)server {
	return _server;
}



- (WCCache *)cache {
	return _cache;
}



#pragma mark -

- (WCAccounts *)accounts {
	return _accounts;
}



- (WCAdministration *)administration {
	return _administration;
}



- (WCPublicChat *)chat {
	return _chat;
}



- (WCConsole *)console {
	return _console;
}



- (WCNews *)news {
	return _news;
}



- (WCBoard *)board {
	return _board;
}



- (WCServerInfo *)serverInfo {
	return _serverInfo;
}

@end
