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

#import "WCConsole.h"
#import "WCServerConnection.h"

@interface WCConsole(Private)

- (id)_initConsoleWithConnection:(WCServerConnection *)connection;

- (void)_log:(NSString *)string color:(NSColor *)color;

@end


@implementation WCConsole(Private)

- (id)_initConsoleWithConnection:(WCServerConnection *)connection {
	self = [super initWithWindowNibName:@"Console"
								   name:NSLS(@"Console", @"Console window title")
							 connection:connection
							  singleton:YES];
	
	[[self connection] addObserver:self
						  selector:@selector(linkConnectionReceivedMessage:)
							  name:WCLinkConnectionReceivedMessage];
	
	[[self connection] addObserver:self
						  selector:@selector(linkConnectionReceivedErrorMessage:)
							  name:WCLinkConnectionReceivedErrorMessage];
	
	[[self connection] addObserver:self
						  selector:@selector(linkConnectionReceivedInvalidMessage:)
							  name:WCLinkConnectionReceivedInvalidMessage];
	
	[[self connection] addObserver:self
						  selector:@selector(linkConnectionSentMessage:)
							  name:WCLinkConnectionSentMessage];
	
	[self window];
	
	return self;
}



#pragma mark -

- (void)_log:(NSString *)string color:(NSColor *)color {
	static NSFont		*font;
	NSDictionary		*attributes;
	NSAttributedString	*attributedString;
	CGFloat				position;

	if(!font)
		font = [[NSFont fontWithName:@"Monaco" size:9.0] retain];

	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		color,		NSForegroundColorAttributeName,
		font,		NSFontAttributeName,
		NULL];
	attributedString = [NSAttributedString attributedStringWithString:string attributes:attributes];

	position = [[_consoleScrollView verticalScroller] floatValue];
	
	if([[_consoleTextView textStorage] length] > 0)
		[[[_consoleTextView textStorage] mutableString] appendString:@"\n"];
	
	[[_consoleTextView textStorage] appendAttributedString:attributedString];
	
	if(position == 1.0)
		[_consoleTextView performSelectorOnce:@selector(scrollToBottom) withObject:NULL afterDelay:0.05];
}

@end


@implementation WCConsole

+ (id)consoleWithConnection:(WCServerConnection *)connection {
	return [[[self alloc] _initConsoleWithConnection:connection] autorelease];
}



#pragma mark -

- (void)linkConnectionReceivedMessage:(NSNotification *)notification {
	[self _log:[[notification object] description] color:[NSColor blueColor]];
}



- (void)linkConnectionReceivedErrorMessage:(NSNotification *)notification {
	[self _log:[[notification object] description] color:[NSColor redColor]];
}



- (void)linkConnectionReceivedInvalidMessage:(NSNotification *)notification {
	[self _log:[[notification object] description] color:[NSColor redColor]];
	[self _log:[[[notification userInfo] objectForKey:@"WCError"] localizedDescription] color:[NSColor redColor]];
}



- (void)linkConnectionSentMessage:(NSNotification *)notification {
	[self _log:[[notification object] description] color:[NSColor blackColor]];
}

@end
