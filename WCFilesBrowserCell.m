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

#import "WCFilesBrowserCell.h"
#import "WCSettings.h"

@implementation WCFilesBrowserCell

- (id)init {
	self = [super init];
	
//	[self setFont:[NSUnarchiver unarchiveObjectWithData:[WCSettings objectForKey:WCFilesFont]]];
	
	return self;
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	WCFilesBrowserCell		*cell;

	cell			= [super copyWithZone:zone];
	cell->_icon		= [_icon retain];
	
	return cell;
}



#pragma mark -

- (void)setIcon:(NSImage *)icon {
	[icon retain];
	[_icon release];
	
	_icon = icon;
}



- (NSImage *)icon {
	return _icon;
}



#pragma mark -

- (NSSize)cellSizeForBounds:(NSRect)bounds {
	NSSize		size;
	
	size = [super cellSizeForBounds:bounds];
	size.height += 2.0;
	
	return size;
}


- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)controlView {    
	NSRect			imageFrame, textFrame, highlightRect;
	NSSize			imageSize;
	
	imageSize = [[self icon] size];
	
	NSDivideRect(frame, &imageFrame, &textFrame, imageSize.width + 6.0, NSMinXEdge);

	imageFrame.origin.x += 4.0;
	imageFrame.size = imageSize;
	
	if([controlView isFlipped])
		imageFrame.origin.y += ceil((textFrame.size.height + imageFrame.size.height) / 2.0);
	else
		imageFrame.origin.y += ceil((textFrame.size.height - imageFrame.size.height) / 2.0);
	
	if([self isHighlighted]) {
		highlightRect = NSMakeRect(frame.origin.x, frame.origin.y, frame.size.width - textFrame.size.width, frame.size.height);

		[[self highlightColorInView:controlView] set];
		NSRectFill(highlightRect);
	}
	
	[[self icon] compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver fraction:1.0];
	
	[super drawInteriorWithFrame:textFrame inView:controlView];
}

@end
