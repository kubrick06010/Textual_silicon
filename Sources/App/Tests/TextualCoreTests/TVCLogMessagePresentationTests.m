@import XCTest;

#include "BuildConfig.h"

#import "TPCPreferencesLocal.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCLogControllerPrivate.h"
#import "TVCLogLine.h"

@interface TVCLogMessagePresentationTests : XCTestCase
@property (nonatomic, strong, nullable) id originalStoredPresentationStyle;
@property (nonatomic, assign) BOOL hadStoredPresentationStyle;
@end

@implementation TVCLogMessagePresentationTests

- (void)setUp
{
	[super setUp];

	NSDictionary<NSString *, id> *persistentDomain =
	[RZUserDefaults() persistentDomainForName:TXBundleBuildGroupContainerIdentifier];

	self.originalStoredPresentationStyle = persistentDomain[TPCPreferencesMessagePresentationStyleDefaultsKey];
	self.hadStoredPresentationStyle = (self.originalStoredPresentationStyle != nil);

	[RZUserDefaults() removeObjectForKey:TPCPreferencesMessagePresentationStyleDefaultsKey];
}

- (void)tearDown
{
	if (self.hadStoredPresentationStyle) {
		[RZUserDefaults() setObject:self.originalStoredPresentationStyle
						 forKey:TPCPreferencesMessagePresentationStyleDefaultsKey];
	} else {
		[RZUserDefaults() removeObjectForKey:TPCPreferencesMessagePresentationStyleDefaultsKey];
	}

	[super tearDown];
}

- (TVCLogLineMutable *)lineWithNickname:(nullable NSString *)nickname
								 type:(TVCLogLineType)lineType
						   memberType:(TVCLogLineMemberType)memberType
							  timestamp:(NSTimeInterval)timestamp
{
	TVCLogLineMutable *line = [TVCLogLineMutable new];

	line.nickname = nickname;
	line.lineType = lineType;
	line.memberType = memberType;
	line.receivedAt = [NSDate dateWithTimeIntervalSince1970:timestamp];

	return line;
}

- (TVCLogLineMutable *)messageFromNickname:(nullable NSString *)nickname
									  type:(TVCLogLineType)lineType
							 timestamp:(NSTimeInterval)timestamp
{
	return [self lineWithNickname:nickname
						 type:lineType
					memberType:TVCLogLineMemberTypeNormal
					 timestamp:timestamp];
}

- (void)testClassicPresentationStylePersists
{
	[TPCPreferences setMessagePresentationStyle:TVCLogMessagePresentationStyleClassicIRC];

	XCTAssertEqual([TPCPreferences messagePresentationStyle], TVCLogMessagePresentationStyleClassicIRC);
	XCTAssertEqual([RZUserDefaults() unsignedIntegerForKey:TPCPreferencesMessagePresentationStyleDefaultsKey],
				 TVCLogMessagePresentationStyleClassicIRC);
}

- (void)testChatPresentationStylePersists
{
	[TPCPreferences setMessagePresentationStyle:TVCLogMessagePresentationStyleChat];

	XCTAssertEqual([TPCPreferences messagePresentationStyle], TVCLogMessagePresentationStyleChat);
	XCTAssertEqual([RZUserDefaults() unsignedIntegerForKey:TPCPreferencesMessagePresentationStyleDefaultsKey],
				 TVCLogMessagePresentationStyleChat);
}

- (void)testInvalidPresentationStyleIsNormalizedToClassicWhenStored
{
	[TPCPreferences setMessagePresentationStyle:(TVCLogMessagePresentationStyle)NSUIntegerMax];

	XCTAssertEqual([TPCPreferences messagePresentationStyle], TVCLogMessagePresentationStyleClassicIRC);
	XCTAssertEqual([RZUserDefaults() unsignedIntegerForKey:TPCPreferencesMessagePresentationStyleDefaultsKey],
				 TVCLogMessagePresentationStyleClassicIRC);
}

- (void)testInvalidPersistedPresentationStyleReadsAsClassic
{
	[RZUserDefaults() setUnsignedInteger:42 forKey:TPCPreferencesMessagePresentationStyleDefaultsKey];

	XCTAssertEqual([TPCPreferences messagePresentationStyle], TVCLogMessagePresentationStyleClassicIRC);
}

- (void)testPrivateMessagesFromSameSenderGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	XCTAssertTrue(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testActionsFromSameSenderGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypeAction timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypeAction timestamp:1001.0];

	XCTAssertTrue(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testNoHighlightVariantsGroupWithinTheirMessageFamily
{
	TVCLogLine *privateMessage = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *privateMessageNoHighlight = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessageNoHighlight timestamp:1001.0];
	TVCLogLine *action = [self messageFromNickname:@"alice" type:TVCLogLineTypeAction timestamp:1000.0];
	TVCLogLine *actionNoHighlight = [self messageFromNickname:@"alice" type:TVCLogLineTypeActionNoHighlight timestamp:1001.0];

	XCTAssertTrue(TVCLogLineShouldGroupWithPreviousLine(privateMessageNoHighlight, privateMessage, NO, NO));
	XCTAssertTrue(TVCLogLineShouldGroupWithPreviousLine(actionNoHighlight, action, NO, NO));
}

- (void)testDifferentSendersDoNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"bob" type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testMissingSenderDoesNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:nil type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:nil type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testDifferentMemberTypesDoNotGroup
{
	TVCLogLine *previousLine = [self lineWithNickname:@"alice"
									 type:TVCLogLineTypePrivateMessage
							   memberType:TVCLogLineMemberTypeNormal
								  timestamp:1000.0];
	TVCLogLine *currentLine = [self lineWithNickname:@"alice"
								  type:TVCLogLineTypePrivateMessage
							 memberType:TVCLogLineMemberTypeLocalUser
								timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testMessagesAtFiveMinuteBoundaryGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1300.0];

	XCTAssertTrue(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testMessagesBeyondFiveMinuteBoundaryDoNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1300.001];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testMessagesWithReverseTimestampsDoNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1001.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testHighlightedMessageDoesNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, YES, NO));
}

- (void)testFirstMessageOfDayDoesNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLineMutable *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	currentLine.isFirstForDay = YES;

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testFirstMessageOfSessionDoesNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, YES));
}

- (void)testEventBetweenMessagesBreaksGrouping
{
	TVCLogLine *eventLine = [self messageFromNickname:@"alice" type:TVCLogLineTypeJoin timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, eventLine, NO, NO));
}

- (void)testDifferentMessageFamiliesDoNotGroup
{
	TVCLogLine *previousLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1000.0];
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypeAction timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, previousLine, NO, NO));
}

- (void)testMissingPreviousLineDoesNotGroup
{
	TVCLogLine *currentLine = [self messageFromNickname:@"alice" type:TVCLogLineTypePrivateMessage timestamp:1001.0];

	XCTAssertFalse(TVCLogLineShouldGroupWithPreviousLine(currentLine, nil, NO, NO));
}

@end
