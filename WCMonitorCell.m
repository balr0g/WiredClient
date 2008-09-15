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

#import "WCMonitorCell.h"
#import "WCTransfer.h"

@interface WCMonitorCell(Private)

- (void)_initMonitorCell;

@end


@implementation WCMonitorCell(Private)

- (void)_initMonitorCell {
	NSMutableParagraphStyle		*style;

	_imageCell = [[NSCell alloc] init];

	_statusCell = [[NSCell alloc] init];
	[_statusCell setFont:[NSFont systemFontOfSize:12.0]];

	_transferStatusCell = [[NSCell alloc] init];
	[_transferStatusCell setFont:[NSFont systemFontOfSize:10.0]];
	
	style = [[NSMutableParagraphStyle alloc] init];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];

	_statusAttributes = [[NSMutableDictionary alloc] init];
	[_statusAttributes setObject:[_statusCell font] forKey:NSFontAttributeName];
	[_statusAttributes setObject:style forKey:NSParagraphStyleAttributeName];
	
	_transferStatusAttributes = [[NSMutableDictionary alloc] init];
	[_transferStatusAttributes setObject:[_transferStatusCell font] forKey:NSFontAttributeName];
	[_transferStatusAttributes setObject:style forKey:NSParagraphStyleAttributeName];

	[style release];
}

@end



@implementation WCMonitorCell

- (id)init {
	self = [super init];
	
	[self _initMonitorCell];

	return self;
}



- (id)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	
	[self _initMonitorCell];

	return self;
}



- (void)dealloc {
	[_imageCell release];

	[_statusCell release];
	[_transferStatusCell release];

	[_statusAttributes release];
	[_transferStatusAttributes release];

	[super dealloc];
}



#pragma mark -

- (id)copyWithZone:(NSZone *)zone {
	WCMonitorCell	*cell;
	
	cell = [super copyWithZone:zone];
	cell->_imageCell = [_imageCell retain];

	cell->_statusCell = [_statusCell retain];
	cell->_transferStatusCell = [_transferStatusCell retain];
	
	cell->_statusAttributes = [_statusAttributes retain];
	cell->_transferStatusAttributes = [_transferStatusAttributes retain];
	
	return cell;
}



#pragma mark -

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
	NSProgressIndicator			*progressIndicator;
	NSMutableAttributedString	*string;
	NSImage						*image;
	NSString					*status;
	WCTransfer					*transfer;
	NSRect						imageRect, statusRect, progressRect, transferStatusRect;
	
	transfer	= [(NSDictionary *) [self objectValue] objectForKey:WCMonitorCellTransferKey];
	status		= [(NSDictionary *) [self objectValue] objectForKey:WCMonitorCellStatusKey];

	if(transfer) {
		imageRect			= NSMakeRect(frame.origin.x + 2.0, frame.origin.y + 14.0, frame.size.width, frame.size.height);
		statusRect			= NSMakeRect(frame.origin.x + 14.0, frame.origin.y, frame.size.width - 12.0, 16.0);
		progressRect		= NSMakeRect(frame.origin.x, frame.origin.y + 19.0, frame.size.width - 5.0, 10.0);
		transferStatusRect	= NSMakeRect(frame.origin.x, frame.origin.y + 32.0, frame.size.width, 14.0);

		if([transfer queuePosition] > 0) {
			imageRect.origin.y			+= 6.0;
			statusRect.origin.y			+= 6.0;
			transferStatusRect.origin.y	-= 7.0;
		}

		image = [NSImage imageNamed:[transfer isKindOfClass:[WCDownloadTransfer class]] ? @"Download" : @"Upload"];
		[image compositeToPoint:imageRect.origin operation:NSCompositeSourceOver fraction:1.0];
		
		string = [NSMutableAttributedString attributedStringWithString:[transfer remotePath] attributes:_statusAttributes];
		
		if([self isHighlighted] && [_statusCell highlightColorWithFrame:statusRect inView:view] == [NSColor alternateSelectedControlColor])
			[string addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor]];
		
		[_statusCell setAttributedStringValue:string];
		[_statusCell drawWithFrame:statusRect inView:view];

		if([transfer queuePosition] == 0) {
			progressIndicator = [transfer progressIndicator];
			
			if(progressIndicator) {
				if(![progressIndicator superview])
					[view addSubview:progressIndicator];
				
				[progressIndicator setFrame:progressRect];
			} else {
				if([progressIndicator superview])
					[progressIndicator removeFromSuperview];
			}
		}

		string = [NSMutableAttributedString attributedStringWithString:[transfer status] attributes:_transferStatusAttributes];
		
		if([self isHighlighted] && [_transferStatusCell highlightColorWithFrame:transferStatusRect inView:view] == [NSColor alternateSelectedControlColor])
			[string addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor]];
		
		[_transferStatusCell setAttributedStringValue:string];
		[_transferStatusCell drawWithFrame:transferStatusRect inView:view];
	}
	else if(status) {
		statusRect = NSMakeRect(frame.origin.x, frame.origin.y + 13.0, frame.size.width, 16.0);
		string = [NSMutableAttributedString attributedStringWithString:status attributes:_statusAttributes];
		
		if([self isHighlighted] && [_statusCell highlightColorWithFrame:statusRect inView:view] == [NSColor alternateSelectedControlColor])
			[string addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor]];
		
		[_statusCell setAttributedStringValue:string];
		[_statusCell drawWithFrame:statusRect inView:view];
	}
}

@end
