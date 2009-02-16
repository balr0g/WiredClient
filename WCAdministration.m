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

#define WIAdministrationView			@"WIAdministrationView"
#define WIAdministrationName			@"WIAdministrationName"
#define WIAdministrationImage			@"WIAdministrationImage"
#define WIAdministrationController		@"WIAdministrationController"


@interface WCAdministration(Private)

- (id)_initAdministrationWithConnection:(WCServerConnection *)connection;

- (void)_addAdministrationView:(NSView *)view name:(NSString *)name image:(NSImage *)image controller:(id)controller;
- (void)_selectAdministrationViewWithIdentifier:(NSString *)identifier animate:(BOOL)animate;

@end



@implementation WCAdministration(Private)

- (id)_initAdministrationWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Administration"
								   name:NSLS(@"Administration", @"Administration window title")
							 connection:connection
							  singleton:YES];
	
	_identifiers	= [[NSMutableArray alloc] init];
	_views			= [[NSMutableDictionary alloc] init];

	[self window];
	
	return self;
}



#pragma mark -

- (void)_addAdministrationView:(NSView *)view name:(NSString *)name image:(NSImage *)image controller:(id)controller {
	NSMutableDictionary			*dictionary;
	NSString					*identifier;
	
	[view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable | NSViewMaxXMargin | NSViewMaxYMargin];
	
	dictionary = [NSMutableDictionary dictionary];
	[dictionary setObject:view forKey:WIAdministrationView];
	[dictionary setObject:name forKey:WIAdministrationName];
	[dictionary setObject:image forKey:WIAdministrationImage];
	[dictionary setObject:controller forKey:WIAdministrationController];
	
	identifier = [NSString UUIDString];
	
	[_identifiers addObject:identifier];
	[_views setObject:dictionary forKey:identifier];
}



- (void)_selectAdministrationViewWithIdentifier:(NSString *)identifier animate:(BOOL)animate {
	NSViewAnimation		*animation;
	NSDictionary		*dictionary;
	NSArray				*animations;
	NSView				*view;
	id					controller;
	NSRect				frame;
	
	dictionary	= [_views objectForKey:identifier];
	view		= [dictionary objectForKey:WIAdministrationView];
	controller	= [dictionary objectForKey:WIAdministrationController];
	
	if(view != _shownView) {
		[_shownController controllerDidUnselect];
		[_shownView removeFromSuperview];
		
		[view setHidden:YES];
		
		frame = [[self window] frame];
		frame.size = [[self window] frameRectForContentRect:[view frame]].size;
		frame.origin.y -= frame.size.height - [[self window] frame].size.height;
		[[self window] setFrame:frame display:YES animate:animate];
		
		[[[self window] contentView] addSubview:view];
		
		if(animate) {
			animations = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
				view,
					NSViewAnimationTargetKey,
				NSViewAnimationFadeInEffect,
					NSViewAnimationEffectKey,
				NULL]];

			animation = [[NSViewAnimation alloc] initWithViewAnimations:animations];
			[animation setAnimationBlockingMode:NSAnimationNonblocking];
			[animation setDuration:0.25];
			[animation startAnimation];
			[animation release];
		} else {
			[view setHidden:NO];
		}

		[[self window] setTitle:[dictionary objectForKey:WIAdministrationName]];
		
		[[[self window] toolbar] setSelectedItemIdentifier:identifier];

		_shownView = view;
		_shownController = controller;

		[controller controllerDidSelect];
	}
}

@end



@implementation WCAdministration

+ (id)administrationWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initAdministrationWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_monitorController setAdministration:NULL];
	[_logController setAdministration:NULL];
	[_settingsController setAdministration:NULL];
	[_banlistController setAdministration:NULL];
	
	[_identifiers release];
	[_views release];

	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSWindow	*window;
	NSToolbar		*toolbar;
	
	[self _addAdministrationView:_monitorView
							name:NSLS(@"Monitor", @"Monitor toolbar item")
						   image:[NSImage imageNamed:@"Monitor"]
					  controller:_monitorController];
	
	[self _addAdministrationView:_logView
							name:NSLS(@"Log", @"Log toolbar item")
						   image:[NSImage imageNamed:@"Log"]
					  controller:_logController];
	
	[self _addAdministrationView:_settingsView
							name:NSLS(@"Settings", @"Settings toolbar item")
						   image:[NSImage imageNamed:@"Settings"]
					  controller:_settingsController];
	
	[self _addAdministrationView:_banlistView
							name:NSLS(@"Banlist", @"Banlist toolbar item")
						   image:[NSImage imageNamed:@"Banlist"]
					  controller:_banlistController];
	
	window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 100.0, 100.0)
										 styleMask:NSTitledWindowMask |
												   NSClosableWindowMask |
												   NSMiniaturizableWindowMask |
												   NSResizableWindowMask
										   backing:NSBackingStoreBuffered
											 defer:YES];
	[window setShowsToolbarButton:NO];
	[window setDelegate:self];
	[self setWindow:window];
	[window release];

	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Administration"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[[self window] center];
	
	[self setShouldCascadeWindows:NO];
	[self setWindowFrameAutosaveName:@"Administration"];

	[_monitorController windowDidLoad];
	[_logController windowDidLoad];
	[_settingsController windowDidLoad];
	[_banlistController windowDidLoad];
	
	[self _selectAdministrationViewWithIdentifier:[_identifiers objectAtIndex:0] animate:NO];

	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	[_shownController controllerWindowDidBecomeKey];
}



- (void)windowWillClose:(NSNotification *)notification {
	[_shownController controllerWindowWillClose];
}



- (NSSize)windowWillResize:(NSWindow *)window toSize:(NSSize)proposedFrameSize {
	if(_shownController == _settingsController)
		return [window frame].size;
	
	return proposedFrameSize;
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	NSDictionary		*dictionary;
	
	dictionary = [_views objectForKey:identifier];
	
	return [NSToolbarItem toolbarItemWithIdentifier:identifier
											   name:[dictionary objectForKey:WIAdministrationName]
											content:[dictionary objectForKey:WIAdministrationImage]
											 target:self
											 action:@selector(toolbarItem:)];
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return _identifiers;
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarDefaultItemIdentifiers:toolbar];
}



- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarDefaultItemIdentifiers:toolbar];
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
	return _shownController;
}



#pragma mark -

- (void)toolbarItem:(id)sender {
	[self _selectAdministrationViewWithIdentifier:[sender itemIdentifier] animate:YES];
}



- (IBAction)submitSheet:(id)sender {
	[_shownController submitSheet:sender];
}

@end



@implementation WCAdministrationController

- (void)windowDidLoad {
}



- (void)linkConnectionLoggedIn:(NSNotification *)notification {
}



- (void)linkConnectionDidClose:(NSNotification *)notification {
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

- (void)setAdministration:(WCAdministration *)administration {
	_administration = administration;
}

@end
