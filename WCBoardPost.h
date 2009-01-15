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

#import "WCServerConnectionObject.h"

@interface WCBoardPost : WCServerConnectionObject {
	NSString					*_board;
	NSString					*_thread;
	NSString					*_post;
	NSDate						*_postDate;
	NSDate						*_editDate;
	NSString					*_nick;
	NSString					*_login;
	NSString					*_subject;
	NSString					*_text;
}

+ (id)postWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection;
- (id)initWithMessage:(WIP7Message *)message connection:(WCServerConnection *)connection;

- (NSString *)board;
- (NSString *)threadID;
- (NSString *)postID;
- (NSDate *)postDate;
- (NSDate *)editDate;
- (NSString *)nick;
- (NSString *)login;
- (NSString *)subject;
- (NSString *)text;

- (NSComparisonResult)comparePostDate:(id)object;

@end
