@import XCTest;

#import "IRCNicknameCaseMapping.h"
#import "IRCClient.h"
#import "IRCISupportInfoPrivate.h"

@interface IRCISupportInfoClientStub : NSObject
@property (nonatomic, assign) ClientIRCv3SupportedCapability capabilities;
@end

@implementation IRCISupportInfoClientStub

- (void)enableCapability:(ClientIRCv3SupportedCapability)capability
{
	self.capabilities |= capability;
}

@end

@interface IRCNicknameCaseMappingTests : XCTestCase
@end

@implementation IRCNicknameCaseMappingTests

- (void)testParsesKnownISupportValuesCaseInsensitively
{
	IRCNicknameCaseMapping mapping;

	XCTAssertTrue(IRCNicknameCaseMappingParse(@"RFC1459", &mapping));
	XCTAssertEqual(mapping, IRCNicknameCaseMappingRFC1459);
	XCTAssertTrue(IRCNicknameCaseMappingParse(@"strict-rfc1459", &mapping));
	XCTAssertEqual(mapping, IRCNicknameCaseMappingStrictRFC1459);
	XCTAssertTrue(IRCNicknameCaseMappingParse(@"ASCII", &mapping));
	XCTAssertEqual(mapping, IRCNicknameCaseMappingASCII);
	XCTAssertFalse(IRCNicknameCaseMappingParse(@"unicode", &mapping));
}

- (void)testASCIIMappingOnlyFoldsLatinUppercase
{
	XCTAssertEqualObjects(IRCNicknameCasefold(@"Nick[\\]^Ä", IRCNicknameCaseMappingASCII), @"nick[\\]^Ä");
}

- (void)testStrictRFC1459AddsBracketAndBackslashEquivalences
{
	XCTAssertEqualObjects(IRCNicknameCasefold(@"Nick[\\]^", IRCNicknameCaseMappingStrictRFC1459), @"nick{|}^");
	XCTAssertEqualObjects(
		IRCNicknameCasefold(@"Nick[\\]", IRCNicknameCaseMappingStrictRFC1459),
		IRCNicknameCasefold(@"NICK{|}", IRCNicknameCaseMappingStrictRFC1459));
}

- (void)testRFC1459AlsoTreatsCaretAndTildeAsEquivalent
{
	XCTAssertEqualObjects(
		IRCNicknameCasefold(@"Nick^", IRCNicknameCaseMappingRFC1459),
		IRCNicknameCasefold(@"NICK~", IRCNicknameCaseMappingRFC1459));
}

- (void)testCasefoldIsIdempotentAndDoesNotNormalizeUnicode
{
	NSString *folded = IRCNicknameCasefold(@"NICK[Éé", IRCNicknameCaseMappingRFC1459);

	XCTAssertEqualObjects(folded, @"nick{Éé");
	XCTAssertEqualObjects(IRCNicknameCasefold(folded, IRCNicknameCaseMappingRFC1459), folded);
	XCTAssertNotEqualObjects(
		IRCNicknameCasefold(@"É", IRCNicknameCaseMappingRFC1459),
		IRCNicknameCasefold(@"é", IRCNicknameCaseMappingRFC1459));
}

- (void)testISupportDefaultsToRFC1459AndAcceptsNegotiatedMapping
{
	NSObject *clientPlaceholder = [NSObject new];
	IRCISupportInfo *supportInfo = [[IRCISupportInfo alloc] initWithClient:(IRCClient *)clientPlaceholder];

	XCTAssertEqual(supportInfo.nicknameCaseMapping, IRCNicknameCaseMappingRFC1459);

	[supportInfo processConfigurationData:@"CASEMAPPING=ascii"];
	XCTAssertEqual(supportInfo.nicknameCaseMapping, IRCNicknameCaseMappingASCII);

	[supportInfo processConfigurationData:@"CASEMAPPING=strict-rfc1459"];
	XCTAssertEqual(supportInfo.nicknameCaseMapping, IRCNicknameCaseMappingStrictRFC1459);
}

- (void)testUnknownISupportValueKeepsCurrentMappingAndRemovalRestoresDefault
{
	NSObject *clientPlaceholder = [NSObject new];
	IRCISupportInfo *supportInfo = [[IRCISupportInfo alloc] initWithClient:(IRCClient *)clientPlaceholder];

	[supportInfo processConfigurationData:@"CASEMAPPING=ascii"];
	[supportInfo processConfigurationData:@"CASEMAPPING=unknown"];
	XCTAssertEqual(supportInfo.nicknameCaseMapping, IRCNicknameCaseMappingASCII);

	[supportInfo processConfigurationData:@"-CASEMAPPING"];
	XCTAssertEqual(supportInfo.nicknameCaseMapping, IRCNicknameCaseMappingRFC1459);
}

- (void)testResetDoesNotCarryMappingAcrossConnections
{
	NSObject *clientPlaceholder = [NSObject new];
	IRCISupportInfo *supportInfo = [[IRCISupportInfo alloc] initWithClient:(IRCClient *)clientPlaceholder];

	[supportInfo processConfigurationData:@"CASEMAPPING=ascii"];
	[supportInfo reset];

	XCTAssertEqual(supportInfo.nicknameCaseMapping, IRCNicknameCaseMappingRFC1459);
}

- (void)testMONITORLimitIsNegotiatedAndResetWithConnectionState
{
	IRCISupportInfoClientStub *clientStub = [IRCISupportInfoClientStub new];
	IRCISupportInfo *supportInfo = [[IRCISupportInfo alloc] initWithClient:(IRCClient *)clientStub];

	[supportInfo processConfigurationData:@"MONITOR=25"];

	XCTAssertEqual(supportInfo.maximumMonitorTargets, 25U);
	XCTAssertTrue((clientStub.capabilities & ClientIRCv3SupportedCapabilityMonitorCommand) != 0);

	[supportInfo reset];

	XCTAssertEqual(supportInfo.maximumMonitorTargets, 0U);
}

@end
