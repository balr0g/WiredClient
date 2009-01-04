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

#import "WCAccount.h"
#import "WCNews.h"
#import "WCNewsPost.h"
#import "WCPreferences.h"
#import "WCServerConnection.h"

@interface WCNews(Private)

- (id)_initNewsWithConnection:(WCServerConnection *)connection;

- (void)_update;
- (void)_reloadNews;
- (void)_readAllPosts;

- (NSAttributedString *)_attributedStringForPost:(WCNewsPost *)post;
- (NSAttributedString *)_attributedStringForPosts;

@end


@implementation WCNews(Private)

- (id)_initNewsWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"News"
								   name:NSLS(@"News", @"News window title")
							 connection:connection
							  singleton:YES];
	
	_posts = [[NSMutableArray alloc] init]; 
	_newsFilter = [[WITextFilter alloc] initWithSelectors:@selector(filterURLs:), @selector(filterWiredSmilies:), 0];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		   selector:@selector(preferencesDidChange:)
			   name:WCPreferencesDidChangeNotification];
	
	[[self connection] addObserver:self selector:@selector(wiredNewsPost:) messageName:@"wired.news.post"];
	
	[self window];
	
	return self;
}



#pragma mark -

- (void)_update {
/*	[_newsTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsBackgroundColor]]];
	[_newsTextView setNeedsDisplay:YES];
	
	[_newsTextView setLinkTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
										  [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCChatURLsColor]],
										  NSForegroundColorAttributeName,
										  [NSNumber numberWithInt:NSSingleUnderlineStyle],
										  NSUnderlineStyleAttributeName,
										  NULL]];
	
	[_postTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsFont]]];
	[_postTextView setTextColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTextColor]]];
	[_postTextView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsBackgroundColor]]];
	[_postTextView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTextColor]]];
	[_postTextView setNeedsDisplay:YES];*/
}



- (void)_reloadNews {
	WIP7Message		*message;
	
	if([[[self connection] account] newsReadNews]) {
		[_posts removeAllObjects];
		[_newsTextView setString:@""];
		[_newsTextView setNeedsDisplay:YES];
		
		message = [WIP7Message messageWithName:@"wired.news.get_news" spec:WCP7Spec];
		[[self connection] sendMessage:message fromObserver:self selector:@selector(wiredNewsGetNewsReply:)];
	}
}



- (void)_readAllPosts {
	while(_unread > 0) {
		_unread--;
		
		[[self connection] postNotificationName:WCNewsDidReadPostNotification object:[self connection]];
	}
}



#pragma mark -

- (NSAttributedString *)_attributedStringForPost:(WCNewsPost *)post {
	NSMutableAttributedString	*attributedString;
	NSAttributedString			*header, *entry;
	NSDictionary				*attributes;
	NSString					*string;
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
//				  [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTitlesFont]],
//				  NSFontAttributeName,
//				  [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTitlesColor]],
//				  NSForegroundColorAttributeName,
				  NULL];
	string = [NSSWF:NSLS(@"From %@ (%@):\n", @"News header (nick, time)"),
			  [post userNick],
			  [_dateFormatter stringFromDate:[post date]]];
	header = [NSAttributedString attributedStringWithString:string attributes:attributes];
	
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
//				  [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsFont]],
//				  NSFontAttributeName,
//				  [NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsTextColor]],
//				  NSForegroundColorAttributeName,
				  NULL];
	entry = [NSAttributedString attributedStringWithString:[post message] attributes:attributes];
	
	attributedString = [NSMutableAttributedString attributedString];
	[attributedString appendAttributedString:header];
	[attributedString appendAttributedString:entry];
	
	return [attributedString attributedStringByApplyingFilter:_newsFilter];
}



- (NSAttributedString *)_attributedStringForPosts {
	NSMutableAttributedString	*attributedString;
	NSUInteger					i, count;
	
	attributedString = [NSMutableAttributedString attributedString];
	count = [_posts count];
	
	for(i = 0; i < count; i++) {
		[attributedString appendAttributedString:[self _attributedStringForPost:[_posts objectAtIndex:i]]];
		
		if(i != count - 1)
			[[attributedString mutableString] appendString:@"\n\n"];
	}
	
	return attributedString;
}

@end


@implementation WCNews

+ (id)newsWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initNewsWithConnection:connection] autorelease];
}



- (void)dealloc {
	[_posts release];
	[_newsFilter release];
	[_dateFormatter release];
	
	[super dealloc];
}



#pragma mark -

- (void)windowDidLoad {
	NSToolbar		*toolbar;
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"News"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[[self window] setToolbar:toolbar];
	[toolbar release];
	
	[_newsTextView setEditable:NO];
	[_newsTextView setUsesFindPanel:YES];
	
	_dateFormatter = [[WIDateFormatter alloc] init];
	[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	[_dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[_dateFormatter setNaturalLanguageStyle:WIDateFormatterCapitalizedNaturalLanguageStyle];
	
	[self _update];
	
	[super windowDidLoad];
}



- (void)windowDidBecomeKey:(NSNotification *)notification {
	[self _readAllPosts];
}



- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar {
	if([identifier isEqualToString:@"Post"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Post", @"Post news toolbar item")
												content:[NSImage imageNamed:@"PostNews"]
												 target:self
												 action:@selector(postNews:)];
	}
	else if([identifier isEqualToString:@"Reload"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Reload", @"Reload news toolbar item")
												content:[NSImage imageNamed:@"ReloadNews"]
												 target:self
												 action:@selector(reloadNews:)];
	}
	else if([identifier isEqualToString:@"Clear"]) {
		return [NSToolbarItem toolbarItemWithIdentifier:identifier
												   name:NSLS(@"Clear", @"Clear news toolbar item")
												content:[NSImage imageNamed:@"ClearNews"]
												 target:self
												 action:@selector(clearNews:)];
	}
	
	return NULL;
}



- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
			@"Post",
			@"Reload",
			NSToolbarFlexibleSpaceItemIdentifier,
			@"Clear",
			NULL];
}



- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	return [NSArray arrayWithObjects:
			@"Post",
			@"Reload",
			@"Clear",
			NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			NULL];
}



- (void)linkConnectionDidTerminate:(NSNotification *)notification {
	[self _readAllPosts];
	
	[super linkConnectionDidTerminate:notification];
}



- (void)serverConnectionPrivilegesDidChange:(NSNotification *)notification {
	if(!_receivedNews)
		[self _reloadNews];
	
	[super serverConnectionPrivilegesDidChange:notification];
}



- (void)serverConnectionWillReconnect:(NSNotification *)notification {
	[self _readAllPosts];
}



- (void)serverConnectionShouldHide:(NSNotification *)notification {
	NSWindow	*sheet;
	
	sheet = [[self window] attachedSheet];
	
	if(sheet == _postPanel)
		_hiddenNews = [[_postTextView string] copy];
	
	[super serverConnectionShouldHide:notification];
}



- (void)serverConnectionShouldUnhide:(NSNotification *)notification {
	[super serverConnectionShouldUnhide:notification];
	
	if(_hiddenNews) {
		[self showPost:_hiddenNews];
		
		[_hiddenNews release];
		_hiddenNews = NULL;
	}
}



- (void)wiredNewsGetNewsReply:(WIP7Message *)message {
	WCNewsPost		*post;
	
	if([[message name] isEqualToString:@"wired.news.list"]) {
		post = [WCNewsPost newsPostWithMessage:message];
		
		if(post)
			[_posts addObject:post];
	}
	else if([[message name] isEqualToString:@"wired.news.list.done"]) {
		[[_newsTextView textStorage] setAttributedString:[self _attributedStringForPosts]];
		
		_receivedNews = YES;
	}
}



- (void)wiredNewsPost:(WIP7Message *)message {
	NSAttributedString		*string;
	WCNewsPost				*post;
	
	post = [WCNewsPost newsPostWithMessage:message];
	
	if(!post)
		return;
	
	if([_posts count] == 0)
		[_posts addObject:post];
	else
		[_posts insertObject:post atIndex:0];
	
	string = [self _attributedStringForPost:post];
	
	if([_posts count] > 0)
		[[[_newsTextView textStorage] mutableString] insertString:@"\n\n" atIndex:0];
	
	[[_newsTextView textStorage] insertAttributedString:string atIndex:0];
	
	if(![[self window] isVisible]) {
		_unread++;
		
		[[self connection] postNotificationName:WCNewsDidAddPostNotification object:[self connection]];
	}
	
	[[self connection] triggerEvent:WCEventsNewsPosted info1:[post userNick] info2:[post message]];
}



- (void)preferencesDidChange:(NSNotification *)notification {
	[self _update];
}



- (BOOL)textView:(NSTextView *)sender doCommandBySelector:(SEL)selector {
	BOOL		value = NO;
	
	if(selector == @selector(insertNewline:)) {
		if([[[NSApp currentEvent] characters] characterAtIndex:0] == NSEnterCharacter) {
			[self submitSheet:_postTextView];
			
			value = YES;
		}
	}
	
	return value;
}



#pragma mark -

- (void)validate {
	[[[self window] toolbar] validateVisibleItems];
	
	[super validate];
}



- (BOOL)validateToolbarItem:(NSToolbarItem *)item {
	WCAccount	*account;
	SEL			selector;
	BOOL		connected;
	
	selector	= [item action];
	account		= [[self connection] account];
	connected	= [[self connection] isConnected];
	
	if(selector == @selector(reloadNews:))
		return ([account newsReadNews] && connected);
	else if(selector == @selector(postNews:))
		return ([account newsPostNews] && connected);
	else if(selector == @selector(clearNews:))
		return ([account newsClearNews] && connected);
	
	return YES;
}



#pragma mark -

- (void)showPost:(NSString *)post {
	[self showWindow:self];
	
	[_postTextView setString:post];
	
	[NSApp beginSheet:_postPanel
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(postSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:NULL];
}



- (NSUInteger)numberOfUnreadPosts {
	return _unread;
}



#pragma mark -

- (IBAction)postNews:(id)sender {
	[self showPost:@""];
}



- (void)postSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.news.post_news" spec:WCP7Spec];
		[message setString:[_postTextView string] forName:@"wired.news.post"];
		[[self connection] sendMessage:message];
	}
	
	[_postPanel close];
	[_postTextView setString:@""];
//	[_postTextView setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCNewsFont]]];
}



- (IBAction)clearNews:(id)sender {
	NSBeginAlertSheet(NSLS(@"Are you sure you want to clear the news?", @"Clear news dialog title"),
					  NSLS(@"Clear", @"Clear news button title"),
					  NSLS(@"Cancel", @"Clear news button title"),
					  NULL,
					  [self window],
					  self,
					  @selector(clearSheetDidEnd:returnCode:contextInfo:),
					  NULL,
					  NULL,
					  NSLS(@"This cannot be undone.", @"Clear news dialog description"));
}



- (void)clearSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
	WIP7Message		*message;
	
	if(returnCode == NSAlertDefaultReturn) {
		message = [WIP7Message messageWithName:@"wired.news.clear_news" spec:WCP7Spec];
		[[self connection] sendMessage:message];
		
		[self _reloadNews];
	}
}



- (IBAction)reloadNews:(id)sender {
	[self _reloadNews];
}

@end
