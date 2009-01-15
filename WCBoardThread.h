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

@class WCBoardPost;

@interface WCBoardThread : WCServerConnectionObject {
	NSString					*_threadID;
	NSMutableArray				*_posts;
}

+ (id)threadWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection;
- (id)initWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection;

- (NSString *)threadID;

- (NSUInteger)numberOfPosts;
- (NSArray *)posts;
- (WCBoardPost *)postAtIndex:(NSUInteger)index;
- (WCBoardPost *)postWithID:(NSString *)postID;
- (void)addPost:(WCBoardPost *)post;
- (void)removePost:(WCBoardPost *)post;
- (void)removeAllPosts;

- (NSComparisonResult)compareSubject:(id)object;
- (NSComparisonResult)compareNick:(id)object;
- (NSComparisonResult)compareDate:(id)object;

@end
