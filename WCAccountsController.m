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

#import "WCAccount.h"
#import "WCAdministration.h"
#import "WCAccountsController.h"
#import "WCServerConnection.h"

@interface WCAccountsController(Private)

@end


@implementation WCAccountsController(Private)

@end



@implementation WCAccountsController

- (NSArray *)accounts {
	return NULL;
}



- (NSArray *)users {
	return NULL;
}



- (NSArray *)userNames {
	return NULL;
}



- (NSArray *)groups {
	return NULL;
}



- (NSArray *)groupNames {
	return NULL;
}



- (WCAccount *)userWithName:(NSString *)name {
	return NULL;
}



- (WCAccount *)groupWithName:(NSString *)name {
	return NULL;
}



- (void)editUserAccountWithName:(NSString *)name {
}



#pragma mark -

- (IBAction)touch:(id)sender {
}



- (IBAction)add:(id)sender {
}



- (IBAction)delete:(id)sender {
}



- (IBAction)reload:(id)sender {
}



- (IBAction)changePassword:(id)sender {
}



- (IBAction)submitPasswordSheet:(id)sender {
}



- (IBAction)all:(id)sender {
}



- (IBAction)users:(id)sender {
}



- (IBAction)groups:(id)sender {
}



- (IBAction)groupFilter:(id)sender {
}



- (IBAction)search:(id)sender {
}



- (IBAction)type:(id)sender {
}



- (IBAction)group:(id)sender {
}



- (IBAction)show:(id)sender {
}



- (IBAction)clearSetting:(id)sender {
}



- (IBAction)save:(id)sender {
}



#pragma mark -

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
//	return [_shownAccounts count];
	
	return 0;
}



- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
/*	WCAccount		*account;

	account = [self _accountAtIndex:row];

	return [account name];*/
	
	return NULL;
}



- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
/*	if([[self _accountAtIndex:row] isKindOfClass:[WCUserAccount class]])
		[cell setImage:_userImage];
	else
		[cell setImage:_groupImage];*/
}


- (NSString *)tableView:(NSTableView *)tableView stringValueForRow:(NSInteger)row {
/*	return [[self _accountAtIndex:row] name];*/
	
	return NULL;
}



- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
/*	if(row != [_accountsTableView selectedRow])
		return [self _verifyUnsavedAndSelectRow:row];*/
	
	return YES;
}



- (void)tableViewSelectionDidChange:(NSNotification *)notification {
/*	if([self _verifyUnsavedAndSelectRow:-1]) {
		if([[[self connection] account] accountReadAccounts]) {
			if([_accountsTableView numberOfSelectedRows] == 1) {
				[self _readAccount:[self _selectedAccount]];
			} else {
				[_account release];
				_account = NULL;
				[_underlyingAccount release];
				_underlyingAccount = NULL;
				_editingAccount = NO;
				_creatingAccount = NO;

				[self _validateAccount:NULL];
				[self _readFromAccount:NULL];
			}
		}
		
		[self validate];
	}*/
}



#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
/*	if(!_account)
		return 0;
	
	if(!item)
		return [_shownSettings count];
	
	return [[item objectForKey:WCAccountsFieldSettings] count];*/
	
	return 0;
}



- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
/*	if(!item)
		return [_shownSettings objectAtIndex:index];
	
	return [[item objectForKey:WCAccountsFieldSettings] objectAtIndex:index];*/

	return NULL;
}



- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
/*	id			value;
	
	if(tableColumn == _settingTableColumn) {
		return [item objectForKey:WCAccountFieldLocalizedName];
	}
	else if(tableColumn == _valueTableColumn) {
		value = [_account valueForKey:[item objectForKey:WCAccountFieldName]];
		
		if(!value)
			value = [_underlyingAccount valueForKey:[item objectForKey:WCAccountFieldName]];
		
		if([[item objectForKey:WCAccountFieldType] intValue] == WCAccountFieldNumber && [value integerValue] == 0)
			return NULL;
		
		if([[item objectForKey:WCAccountFieldName] isEqualToString:@"wired.account.transfer.download_speed_limit"] ||
		   [[item objectForKey:WCAccountFieldName] isEqualToString:@"wired.account.transfer.upload_speed_limit"])
			value = [NSNumber numberWithInteger:[value doubleValue] / 1024.0];
		
		return value;
	}*/

	return NULL;
}



- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
/*	NSString	*name;
	id			value;
	
	name	= [item objectForKey:WCAccountFieldName];
	value	= object;
	
	if([[item objectForKey:WCAccountFieldType] intValue] == WCAccountFieldNumber)
		value = [NSNumber numberWithInteger:[object integerValue]];
	
	if([name isEqualToString:@"wired.account.transfer.download_speed_limit"] ||
	   [name isEqualToString:@"wired.account.transfer.upload_speed_limit"])
		value = [NSNumber numberWithInteger:[value integerValue] * 1024.0];

	[_account setValue:value forKey:name];
	
	[self touch:self];*/
}



- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
/*	if([_account valueForKey:[item objectForKey:WCAccountFieldName]])
		[cell setFont:[[cell font] fontByAddingTrait:NSBoldFontMask]];
	else
		[cell setFont:[[cell font] fontByAddingTrait:NSUnboldFontMask]];
	
	if(tableColumn == _valueTableColumn)
		[cell setEnabled:[self _isEditableAccount:_account]];*/
}



- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
//	return ([[item objectForKey:WCAccountsFieldSettings] count] > 0);

	return NO;
}

@end



/*@implementation WCAccountsTableColumn

- (id)dataCellForRow:(NSInteger)row {
	id		cell;
	
	cell = [[(NSOutlineView *) [self tableView] itemAtRow:row] objectForKey:WCAccountsFieldCell];
	
	if(cell)
		return cell;
	
	return [super dataCellForRow:row];
}

@end*/
