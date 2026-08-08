@import XCTest;

#import "IRCMessage.h"
#import "IRCPrefix.h"

@interface IRCMessageTests : XCTestCase
@end

@implementation IRCMessageTests

- (void)testParsesUserPrefixCommandAndTrailingParameter
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":nick!user@example.com PRIVMSG #textual :hello world"];

	XCTAssertNotNil(message);
	XCTAssertEqualObjects(message.command, @"PRIVMSG");
	XCTAssertEqual(message.commandNumeric, 0U);
	XCTAssertEqualObjects(message.senderNickname, @"nick");
	XCTAssertEqualObjects(message.senderUsername, @"user");
	XCTAssertEqualObjects(message.senderAddress, @"example.com");
	XCTAssertEqualObjects(message.params, (@[@"#textual", @"hello world"]));
	XCTAssertEqualObjects(message.sequence, @"hello world");
}

- (void)testNormalizesTextCommandToUppercase
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":irc.example.net notice nick :maintenance"];

	XCTAssertEqualObjects(message.command, @"NOTICE");
	XCTAssertTrue(message.senderIsServer);
	XCTAssertEqualObjects(message.senderNickname, @"irc.example.net");
}

- (void)testParsesNumericCommand
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":irc.example.net 001 nick :Welcome"];

	XCTAssertEqualObjects(message.command, @"001");
	XCTAssertEqual(message.commandNumeric, 1U);
	XCTAssertEqualObjects([message paramAt:0], @"nick");
	XCTAssertEqualObjects([message paramAt:1], @"Welcome");
}

- (void)testParsesAndUnescapesIRCv3MessageTags
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@"@example=value\\swith\\sspaces;flag :server.example NOTICE * :hello"];

	XCTAssertEqualObjects(message.messageTags[@"example"], @"value with spaces");
	XCTAssertNotNil(message.messageTags[@"flag"]);
}

- (void)testSequenceFromIndexJoinsRemainingParameters
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":server.example COMMAND one two :three four"];

	XCTAssertEqualObjects([message sequence:0], @"one two three four");
	XCTAssertEqualObjects([message sequence:2], @"three four");
	XCTAssertEqualObjects([message sequence:99], @"");
}

- (void)testOutOfBoundsParameterReturnsEmptyString
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":server.example PING token"];

	XCTAssertEqualObjects([message paramAt:99], @"");
}

- (void)testRejectsMissingCommand
{
	XCTAssertNil([[IRCMessage alloc] initWithLine:@":server.example"]);
	XCTAssertNil([[IRCMessage alloc] initWithLine:@"@tag=value :server.example"]);
}

- (void)testPreservesEmptyTrailingParameter
{
	IRCMessage *message = [[IRCMessage alloc] initWithLine:@":server.example PING :"];

	XCTAssertEqual(message.paramsCount, 1U);
	XCTAssertEqualObjects([message paramAt:0], @"");
}

@end
