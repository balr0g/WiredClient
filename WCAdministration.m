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

#import "WCAdministration.h"
#import "WCServerConnection.h"

@interface WCAdministration(Private)

- (id)_initAdministrationWithConnection:(WCServerConnection *)connection;

@end



@implementation WCAdministration(Private)

- (id)_initAdministrationWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Administration"
								   name:NSLS(@"Administration", @"Administration window title")
							 connection:connection
							  singleton:YES];
	
	[self window];
	
	return self;
}

@end



@implementation WCAdministration

+ (id)administrationWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initAdministrationWithConnection:connection] autorelease];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Administration"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];

	[self monitor:self];
	
	[[[self window] toolbar] setSelectedItemIdentifier:@"Monitor"];

	[_monitorController windowDidLoad];
	[_logController windowDidLoad];
	[_settingsController windowDidLoad];
	[_banlistController windowDidLoad];
	
	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	[_selectedController controllerWindowDidBecomeKey];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_selectedController controllerWindowWillClose];
}



/*- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[super windowTemplateShouldLoad:windowTemplate];

	[_monitorController windowTemplateShouldLoad:windowTemplate];
	[_logController windowTemplateShouldLoad:windowTemplate];
	[_settingsController windowTemplateShouldLoad:windowTemplate];
	[_banlistController windowTemplateShouldLoad:windowTemplate];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[_monitorController windowTemplateShouldSave:windowTemplate];
	[_logController windowTemplateShouldSave:windowTemplate];
	[_settingsController windowTemplateShouldSave:windowTemplate];
	[_banlistController windowTemplateShouldSave:windowTemplate];

	[super windowTemplateShouldSave:windowTemplate];
}*/



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"Monitor"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Monitor", @"Monitor toolbar item")
												content:[NSImage imageNamed:@"Monitor"]
												 target:self
												 action:@selector(monitor:)];
	}
	else if([identifier isEqualToString:@"Log"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Log", @"Log toolbar item")
												content:[NSImage imageNamed:@"Log"]
												 target:self
												 action:@selector(log:)];
	}
	else if([identifier isEqualToString:@"Settings"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Settings", @"Settings toolbar item")
												content:[NSImage imageNamed:@"Settings"]
												 target:self
												 action:@selector(settings:)];
	}
	else if([identifier isEqualToString:@"Banlist"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Banlist", @"Banlist toolbar item")
												content:[NSImage imageNamed:@"Banlist"]
												 target:self
												 action:@selector(banlist:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Monitor",
		@"Log",
		@"Settings",
		@"Banlist",
		NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Monitor",
		@"Log",
		@"Settings",
		@"Banlist",
		NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NULL];
}



- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
		@"Monitor",
		@"Log",
		@"Settings",
		@"Banlist",
		NULL];
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
	[_monitorController linkConnectionLoggedIn:notification];
	[_logController linkConnectionLoggedIn:notification];
	[_settingsController linkConnectionLoggedIn:notification];
	[_banlistController linkConnectionLoggedIn:notification];
	
	[super linkConnectionLoggedIn:notification];
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
	[_monitorController linkConnectionDidClose:notification];
	[_logController linkConnectionDidClose:notification];
	[_settingsController linkConnectionDidClose:notification];
	[_banlistController linkConnectionDidClose:notification];
	
	[super linkConnectionDidClose:notification];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	[_monitorController linkConnectionDidTerminate:notification];
	[_logController linkConnectionDidTerminate:notification];
	[_settingsController linkConnectionDidTerminate:notification];
	[_banlistController linkConnectionDidTerminate:notification];
	
	[super linkConnectionDidTerminate:notification];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[_monitorController serverConnectionPrivilegesDidChange:notification];
	[_logController serverConnectionPrivilegesDidChange:notification];
	[_settingsController serverConnectionPrivilegesDidChange:notification];
	[_banlistController serverConnectionPrivilegesDidChange:notification];
	
	[super serverConnectionPrivilegesDidChange:notification];
}



#pragma mark -

- (void)validate {
	[[[self window] toolbar] validateVisibleItems];

	[super validate];
}



#pragma mark -

- (id)selectedController {
	return _selectedController;
}



#pragma mark -

- (IBAction)monitor:(id)sender {
	if(_selectedController != _monitorController) {
		[_administrationTabView selectTabViewItem:_monitorTabViewItem];
		
		[_selectedController controllerDidUnselect];
		_selectedController = _monitorController;
		[_selectedController controllerDidSelect];
	}
}



- (IBAction)log:(id)sender {
	if(_selectedController != _logController) {
		[_administrationTabView selectTabViewItem:_logTabViewItem];
		
		[_selectedController controllerDidUnselect];
		_selectedController = _logController;
		[_selectedController controllerDidSelect];
	}
}



- (IBAction)settings:(id)sender {
	if(_selectedController != _settingsController) {
		[_administrationTabView selectTabViewItem:_settingsTabViewItem];
		
		[_selectedController controllerDidUnselect];
		_selectedController = _settingsController;
		[_selectedController controllerDidSelect];
	}
}



- (IBAction)banlist:(id)sender {
	if(_selectedController != _banlistController) {
		[_administrationTabView selectTabViewItem:_banlistTabViewItem];
		
		[_selectedController controllerDidUnselect];
		_selectedController = _banlistController;
		[_selectedController controllerDidSelect];
	}
}



- (IBAction)submitSheet:(id)sender {
	[_selectedController submitSheet:sender];
}

@end



@implementation WCAdministrationController

- (void)windowDidLoad {
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
}



#pragma mark -

- (void)controllerWindowDidBecomeKey {
}



- (void)controllerWindowWillClose {
}



- (void)controllerDidSelect {
}



- (void)controllerDidUnselect {
}



#pragma mark -

- (IBAction)submitSheet:(id)sender {
	[NSApp endSheet:[sender window] returnCode:NSOKButton];
}

@end
