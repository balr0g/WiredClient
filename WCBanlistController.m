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

#import "WCAccount.h"
#import "WCAdministration.h"
#import "WCBan.h"
#import "WCBanlistController.h"
#import "WCServerConnection.h"

@interface WCBanlistController(Private)

- (void)_validate;

- (void)_getBans;

- (WCBan *)_banAtIndex:(NSUInteger)index;
- (WCBan *)_selectedBan;
- (NSArray *)_selectedBans;
- (void)_sortBans;

@end


@implementation WCBanlistController(Private)

- (void)_validate {
	WCAccount		*account;
	BOOL			connected;

	account		= [[_administration connection] account];
	connected	= [[_administration connection] isConnected];

	[_addButton setEnabled:(connected && [account banlistAddBans])];
	[_deleteButton setEnabled:(connected && [account banlistDeleteBans] && ([_banlistTableView selectedRow] >= 0))];
}



#pragma mark -

- (void)_getBans {
	WIP7Message		*message;
	
	[_bans removeAllObjects];

	if([[_administration connection] isConnected] && [[[_administration connection] account] banlistGetBans]) {
		message = [WIP7Message messageWithName:@"wired.banlist.get_bans" spec:WCP7Spec];
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredBanlistGetBansReply:)];
		
		[_progressIndicator startAnimation:self];
	}
}



#pragma mark -

- (WCBan *)_banAtIndex:(NSUInteger)index {
	NSUInteger		i;
	
	i = ([_banlistTableView sortOrder] == WISortDescending)
		? [_shownBans count] - index - 1
		: index;
	
	return [_shownBans objectAtIndex:i];
}



- (WCBan *)_selectedBan {
	NSInteger		row;
	
	row = [_banlistTableView selectedRow];
	
	if(row < 0)
		return NULL;
	
	return [self _banAtIndex:row];
}



- (NSArray *)_selectedBans {
	NSEnumerator		*enumerator;
	NSMutableArray		*array;
	NSNumber			*row;
	
	array = [NSMutableArray array];
	enumerator = [_banlistTableView selectedRowEnumerator];
	
	while((row = [enumerator nextObject]))
		[array addObject:[self _banAtIndex:[row unsignedIntValue]]];
	
	return array;
}



- (void)_sortBans {
	NSTableColumn   *tableColumn;

	tableColumn = [_banlistTableView highlightedTableColumn];
	
	if(tableColumn == _ipTableColumn)
		[_shownBans sortUsingSelector:@selector(compareIP:)];
	else if(tableColumn == _expiresTableColumn)
		[_shownBans sortUsingSelector:@selector(compareExpirationDate:)];
}

@end



@implementation WCBanlistController

- (id)init {
	self = [super init];

	_bans		= [[NSMutableArray alloc] init];
	_shownBans	= [[NSMutableArray alloc] init];

	return self;
}



- (void)dealloc {
	[_bans release];
	[_shownBans release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	[_banlistTableView setDeleteAction:@selector(deleteBan:)];
	[_banlistTableView setDefaultHighlightedTableColumnIdentifier:@"IP"];

	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _validate];
}



- (void)windowTemplateShouldLoad:(NSMutableDictionary *)windowTemplate {
	[_banlistTableView setPropertiesFromDictionary:[windowTemplate objectForKey:@"WCBanlistTableView"]];
	
	[super windowTemplateShouldLoad:windowTemplate];
}



- (void)windowTemplateShouldSave:(NSMutableDictionary *)windowTemplate {
	[windowTemplate setObject:[_banlistTableView propertiesDictionary] forKey:@"WCBanlistTableView"];
	
	[super windowTemplateShouldSave:windowTemplate];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	[self _getBans];
	[self _validate];
}



- (void)wiredBanlistGetBansReply:(WIP7Message *)message {
	if([[message name] isEqualToString:@"wired.banlist.ban_list"]) {
		[_bans addObject:[WCBan banWithMessage:message connection:[_administration connection]]];
	}
	else if([[message name] isEqualToString:@"wired.banlist.ban_list.done"]) {
		[_shownBans setArray:_bans];
		[_bans removeAllObjects];
		
		[self _sortBans];

		[_banlistTableView reloadData];

		[_progressIndicator stopAnimation:self];
	}
}



- (void)wiredBanlistDeleteBanReply:(WIP7Message *)message {
	NSLog(@"wiredBanlistDeleteBanReply = %@", message);
}



- (void)wiredBanlistAddBanReply:(WIP7Message *)message {
	NSLog(@"wiredBanlistAddBanReply = %@", message);
}



#pragma mark -

- (void)controllerWindowDidBecomeKey {
	[self _getBans];
}



- (void)controllerDidSelect {
	[self _getBans];
}



#pragma mark -

- (IBAction)submitSheet:(id)sender {
	BOOL	valid = YES;
	
	if([sender window] == _addBanPanel)
		valid = ([[_addBanTextField stringValue] length] > 0);
	
	if(valid)
		[super submitSheet:sender];
}



#pragma mark -

- (IBAction)addBan:(id)sender {
	[NSApp beginSheet:_addBanPanel
	   modalForWindow:[_administration window]
		modalDelegate:self
	   didEndSelector:@selector(addSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (void)addSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.banlist.add_ban" spec:WCP7Spec];
		[message setString:[_addBanTextField stringValue] forName:@"wired.banlist.ip"];
		
		if([_addBanPopUpButton tagOfSelectedItem] > 0) {
			[message setDate:[NSDate dateWithTimeIntervalSinceNow:[_addBanPopUpButton tagOfSelectedItem]]
					 forName:@"wired.banlist.expiration_date"];
		}
		
		[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredBanlistAddBanReply:)];
	}
	
	[_addBanPanel close];
	[_addBanTextField setStringValue:@""];
}



- (IBAction)deleteBan:(id)sender {
	NSString	*title;

	if([_banlistTableView numberOfSelectedRows] == 1) {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete \"%@\"?", @"Delete ban dialog title (IP)"),
			[[self _selectedBan] IP]];
	} else {
		title = [NSSWF:
			NSLS(@"Are you sure you want to delete %lu items?", @"Delete ban dialog title (count)"),
			[_banlistTableView numberOfSelectedRows]];
	}

	NSBeginAlertSheet(title,
					  NSLS(@"Delete", @"Delete ban dialog button title"),
					  NSLS(@"Cancel", @"Delete ban dialog button title"),
					  NULL,
					  [_administration window],
					  self,
					  @selector(deleteSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Delete ban dialog description"));
}



- (void)deleteSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	NSEnumerator	*enumerator;
	WIP7Message		*message;
	WCBan			*ban;
	
	if(returnCode == NSAlertDefaultReturn) {
		enumerator = [[self _selectedBans] objectEnumerator];
		
		while((ban = [enumerator nextObject])) {
			message = [WIP7Message messageWithName:@"wired.banlist.delete_ban" spec:WCP7Spec];
			[message setString:[ban IP] forName:@"wired.banlist.ip"];
			
			if([ban expirationDate])
				[message setDate:[ban expirationDate] forName:@"wired.banlist.expiration_date"];
			
			[[_administration connection] sendMessage:message fromObserver:self selector:@selector(wiredBanlistDeleteBanReply:)];
		}
		
		[self _getBans];
	}
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [_shownBans count];
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	WCBan		*ban;
	
	ban = [self _banAtIndex:row];
	
	if(tableColumn == _ipTableColumn)
		return [ban IP];
	else if(tableColumn == _expiresTableColumn)
		return [ban expirationDate] ? [_dateFormatter stringFromDate:[ban expirationDate]] : NSLS(@"Never", @"Banlist expiration");
	
	return NULL;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self _validate];
}



- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
	[_banlistTableView setHighlightedTableColumn:tableColumn];
	[self _sortBans];
	[_banlistTableView reloadData];
}

@end
