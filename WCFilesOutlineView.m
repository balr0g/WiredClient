/* $Id$ */

/*
 *  Copyright (c) 2006-2007 Daniel Ericsson, Axel Andersson
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

#import "WCFilesOutlineView.h"

static void _WCFilesOutlineViewShader(void *, const CGFloat *, CGFloat *);

static void _WCFilesOutlineViewShader(void *info, const CGFloat *in, CGFloat *out) {
	CGFloat		*colors;
	
	colors = info;
	
	out[0] = colors[0] + (in[0] * (colors[4] - colors[0]));
	out[1] = colors[1] + (in[0] * (colors[5] - colors[1]));
	out[2] = colors[2] + (in[0] * (colors[6] - colors[2]));
    out[3] = colors[3] + (in[0] * (colors[7] - colors[3]));
}



@interface WCFilesOutlineView(Private)

- (void)_drawRowBackgroundGradientWithStartingColor:(NSColor *)startingColor endingColor:(NSColor *)endingColor inRect:(NSRect)rect;

@end


@implementation WCFilesOutlineView(Private)

- (void)_drawRowBackgroundGradientWithStartingColor:(NSColor *)startingColor endingColor:(NSColor *)endingColor inRect:(NSRect)rect {
	static const CGFloat		domain[] = { 0.0, 2.0 };
	static const CGFloat		range[] = { 0.0, 2.0, 0.0, 2.0, 0.0, 2.0, 0.0, 2.0, 0.0, 2.0 };
	NSColor						*deviceStartingColor, *deviceEndingColor;
	CGContextRef				context;
	CGFunctionRef				function;
	CGColorSpaceRef				colorSpace;
	CGShadingRef				shading;
	struct CGFunctionCallbacks	callbacks;
	CGFloat						colors[8], radius;
	
	deviceStartingColor		= [startingColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	deviceEndingColor		= [endingColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	
	colors[0]				= [deviceStartingColor redComponent];
	colors[1]				= [deviceStartingColor greenComponent];
	colors[2]				= [deviceStartingColor blueComponent];
	colors[3]				= [deviceStartingColor alphaComponent];
	
	colors[4]				= [deviceEndingColor redComponent];
	colors[5]				= [deviceEndingColor greenComponent];
	colors[6]				= [deviceEndingColor blueComponent];
	colors[7]				= [deviceEndingColor alphaComponent];
	
	callbacks.version		= 0;
	callbacks.evaluate		= _WCFilesOutlineViewShader;
	callbacks.releaseInfo	= NULL;
	
	function = CGFunctionCreate(colors, 1, domain, 4, range, &callbacks);
	colorSpace = CGColorSpaceCreateDeviceRGB();
	
	radius		= rect.size.height / 2.0;
	context		= [[NSGraphicsContext currentContext] graphicsPort];
	shading		= CGShadingCreateAxial(colorSpace,
									   CGPointMake(0.0, rect.origin.y),
									   CGPointMake(0.0, rect.origin.y + rect.size.height),
									   function,
									   false,
									   false);
	
	CGContextSaveGState(context);
	
	CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + radius);
	CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y + rect.size.height - radius);
	CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + rect.size.height - radius, radius, M_PI / 4.0, M_PI / 2.0, 1.0);
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width - radius, rect.origin.y + rect.size.height);
	CGContextAddArc(context, rect.origin.x + rect.size.width - radius, rect.origin.y + rect.size.height - radius, radius, M_PI / 2.0, 0.0, 1.0);
	CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + radius);
	CGContextAddArc(context, rect.origin.x + rect.size.width - radius, rect.origin.y + radius, radius, 0.0, -M_PI / 2.0, 1.0);
	CGContextAddLineToPoint(context, rect.origin.x + radius, rect.origin.y);
	CGContextAddArc(context, rect.origin.x + radius, rect.origin.y + radius, radius, -M_PI / 2.0, M_PI, 1.0);
	CGContextClip(context);
	
	CGContextDrawShading(context, shading);
	
	CGContextRestoreGState(context);
	
	CGShadingRelease(shading);
	CGColorSpaceRelease(colorSpace);
	CGFunctionRelease(function);
}

@end



@implementation WCFilesOutlineView

- (void)drawRow:(NSInteger)row clipRect:(NSRect)clipRect {
	NSColor			*color;
	NSRect			rowRect;
	id				item;
	
	item	= [self itemAtRow:row];
	color	= [[self delegate] outlineView:self backgroundColorForItem:item];

	if(color) {
		rowRect = [self rectOfRow:row];
		
		rowRect.origin.x += 2.0;
		rowRect.size.width -= 4.0;

		if([[self selectedRowIndexes] containsIndex:row])
			rowRect.size.width = 18.0;
			
		rowRect.size.height -= 1.0;

		[self _drawRowBackgroundGradientWithStartingColor:[color blendedColorWithFraction:0.6 ofColor:[NSColor whiteColor]]
											  endingColor:[color blendedColorWithFraction:0.2 ofColor:[NSColor whiteColor]]
												   inRect:rowRect];
	}
	
	[super drawRow:row clipRect:clipRect];
}

@end
