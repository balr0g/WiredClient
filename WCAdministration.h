/* $Id$ */

/*
 *  Copyright (c) 2008 Axel Andersson
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

#import "WCConnectionController.h"

@class WCMonitorController, WCLogController, WCSettingsController, WCBanlistController, WCErrorQueue;

@interface WCAdministration : WCConnectionController {
	IBOutlet NSView						*_monitorView;
	IBOutlet NSView						*_logView;
	IBOutlet NSView						*_settingsView;
	IBOutlet NSView						*_banlistView;
	
	IBOutlet WCMonitorController		*_monitorController;
	IBOutlet WCLogController			*_logController;
	IBOutlet WCSettingsController		*_settingsController;
	IBOutlet WCBanlistController		*_banlistController;
	
	WCErrorQueue						*_errorQueue;
	
	NSMutableArray						*_identifiers;
	NSMutableDictionary					*_views;
	
	NSView								*_shownView;
	id									_shownController;
}

+ (id)administrationWithConnection:(WCServerConnection *)connection;

- (id)selectedController;

- (void)showError:(WCError *)error;

@end


@interface WCAdministrationController : WIObject {
	IBOutlet WCAdministration			*_administration;
}

- (void)windowDidLoad;
- (void)linkConnectionLoggedIn:(NSNotification *)notification;
- (void)linkConnectionDidClose:(NSNotification *)notification;
- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification;

- (void)controllerWindowDidBecomeKey;
- (void)controllerWindowWillClose;
- (void)controllerDidSelect;
- (void)controllerDidUnselect;

- (void)setAdministration:(WCAdministration *)administration;

@end
