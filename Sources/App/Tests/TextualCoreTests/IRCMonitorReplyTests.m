@import XCTest;

#import "IRCMessage.h"
#import "IRCMonitorReply.h"

@interface IRCMonitorReplyTests : XCTestCase
@end

@implementation IRCMonitorReplyTests

- (void)testParsesOnlineReplyWithOptionalHostmasks
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":irc.example 730 * :alice!user@example.com,bob"];
	IRCMonitorReply *reply = [IRCMonitorReply replyWithMessage:message];

	XCTAssertNotNil(reply);
	XCTAssertTrue(reply.online);
	XCTAssertEqualObjects(reply.targets, (@[@"alice!user@example.com", @"bob"]));
}

- (void)testParsesOfflineReplyAndDropsEmptyTargets
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":irc.example 731 me :alice,,"];
	IRCMonitorReply *reply = [IRCMonitorReply replyWithMessage:message];

	XCTAssertNotNil(reply);
	XCTAssertFalse(reply.online);
	XCTAssertEqualObjects(reply.targets, (@[@"alice"]));
}

- (void)testEmptyTrailingReplyIsAValidEmptyResult
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":irc.example 731 me :"];
	IRCMonitorReply *reply = [IRCMonitorReply replyWithMessage:message];

	XCTAssertNotNil(reply);
	XCTAssertEqualObjects(reply.targets, @[]);
}

- (void)testRejectsOtherNumericsAndMalformedReplies
{
	XCTAssertNil([IRCMonitorReply replyWithMessage:[[IRCMessage alloc] initWithLine:@":irc.example 303 me :alice"]]);
	XCTAssertNil([IRCMonitorReply replyWithMessage:[[IRCMessage alloc] initWithLine:@":irc.example 730 me"]]);
}

@end
