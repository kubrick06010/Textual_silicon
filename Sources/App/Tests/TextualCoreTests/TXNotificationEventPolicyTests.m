@import XCTest;

#import "TXNotificationEventPolicy.h"

@interface TXNotificationEventPolicyTests : XCTestCase
@end

@implementation TXNotificationEventPolicyTests

- (void)testSelfAuthoredTextDoesNotNotify
{
	TXNotificationEventPolicyInput input = {
		.terminating = NO,
		.textEvent = YES,
		.authoredBySelf = YES,
	};

	XCTAssertEqual(TXNotificationEventPolicyEvaluate(input), TXNotificationEventPolicyResultDrop);
}

- (void)testOutputRuleSuppressesNotification
{
	TXNotificationEventPolicyInput input = {
		.outputRuleMatched = YES,
	};

	XCTAssertEqual(TXNotificationEventPolicyEvaluate(input), TXNotificationEventPolicyResultDrop);
}

- (void)testIgnoredHighlightIsHandledWithoutExternalNotification
{
	TXNotificationEventPolicyInput input = {
		.hasTarget = YES,
		.highlightEvent = YES,
		.highlightsIgnored = YES,
		.pushNotificationsEnabled = YES,
	};

	XCTAssertEqual(TXNotificationEventPolicyEvaluate(input), TXNotificationEventPolicyResultHandled);
}

- (void)testDisabledChannelNotificationsAreHandledWithoutExternalNotification
{
	TXNotificationEventPolicyInput input = {
		.hasTarget = YES,
		.highlightEvent = NO,
		.pushNotificationsEnabled = NO,
	};

	XCTAssertEqual(TXNotificationEventPolicyEvaluate(input), TXNotificationEventPolicyResultHandled);
}

- (void)testOrdinaryEventContinuesThroughNotificationPipeline
{
	TXNotificationEventPolicyInput input = {
		.textEvent = YES,
		.authoredBySelf = NO,
		.pushNotificationsEnabled = YES,
	};

	XCTAssertEqual(TXNotificationEventPolicyEvaluate(input), TXNotificationEventPolicyResultContinue);
}

@end
