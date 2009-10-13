/* $Id$ */

/*
 *  Copyright (c) 2008-2009 Axel Andersson
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

@class WCBoard, WCBoardThreadFilter, WCBoardPost;

@interface WCBoardThread : WCServerConnectionObject {
	NSString							*_threadID;
	NSMutableArray						*_posts;
	BOOL								_unread;
	WCBoard								*_board;
	NSButton							*_goToLatestPostButton;
}

+ (WCBoardThread *)threadWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection;
- (id)initWithPost:(WCBoardPost *)post connection:(WCServerConnection *)connection;

- (NSString *)threadID;
- (void)setUnread:(BOOL)unread;
- (BOOL)isUnread;
- (void)setBoard:(WCBoard *)board;
- (WCBoard *)board;

- (NSButton *)goToLatestPostButton;

- (NSUInteger)numberOfPosts;
- (NSUInteger)numberOfUnreadPosts;
- (NSArray *)posts;
- (WCBoardPost *)postAtIndex:(NSUInteger)index;
- (WCBoardPost *)postWithID:(NSString *)postID;
- (WCBoardPost *)firstPost;
- (WCBoardPost *)lastPost;
- (BOOL)hasPostMatchingFilter:(WCBoardThreadFilter *)filter;
- (void)addPost:(WCBoardPost *)post;
- (void)removePost:(WCBoardPost *)post;
- (void)removeAllPosts;

- (NSComparisonResult)compareUnread:(id)object;
- (NSComparisonResult)compareSubject:(id)object;
- (NSComparisonResult)compareNick:(id)object;
- (NSComparisonResult)compareNumberOfPosts:(id)object;
- (NSComparisonResult)compareDate:(id)object;
- (NSComparisonResult)compareLastPostDate:(id)object;

@end


@interface WCBoardThreadFilter : WIObject {
	NSString							*_name;
	NSString							*_board;
	NSString							*_text;
	NSString							*_subject;
	NSString							*_nick;
	BOOL								_unread;
}

+ (id)filter;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (void)setBoard:(NSString *)board;
- (NSString *)board;
- (void)setText:(NSString *)text;
- (NSString *)text;
- (void)setSubject:(NSString *)subject;
- (NSString *)subject;
- (void)setNick:(NSString *)nick;
- (NSString *)nick;
- (void)setUnread:(BOOL)unread;
- (BOOL)unread;

@end
