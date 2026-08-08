@import XCTest;

#import "IRCIsonResultApplicator.h"

@interface IRCIsonResultApplicatorTests : XCTestCase
@end


@implementation IRCIsonResultApplicatorTests

- (IRCIsonRoundResult *)resultForRequestedNicknames:(NSArray<NSString *> *)requestedNicknames
							 onlineNicknames:(NSArray<NSString *> *)onlineNicknames
									 initial:(BOOL)initial
								 caseMapping:(IRCNicknameCaseMapping)caseMapping
{
	IRCIsonRoundCoordinator *coordinator = [IRCIsonRoundCoordinator new];
	IRCIsonBatchEncodingPolicy policy = IRCIsonBatchEncodingPolicyMake(NSUTF8StringEncoding, NSISOLatin1StringEncoding);
	NSError *error = nil;
	IRCIsonRoundTransition *start = [coordinator enqueueNicknames:requestedNicknames
														 kind:IRCIsonRequestKindAutomaticTracking
													  context:nil
													  initial:initial
												 encodingPolicy:policy
													caseMapping:caseMapping
											maximumBodyBytes:510
													   error:&error];

	XCTAssertNotNil(start);
	XCTAssertNil(error);

	IRCIsonRound *round = start.roundToStart;
	XCTAssertNotNil(round);

	IRCIsonRoundTransition *completion = [coordinator recordReplyNicknames:onlineNicknames
															 roundIdentifier:round.identifier
																  generation:round.generation];

	XCTAssertTrue(completion.consumedReply);
	XCTAssertNotNil(completion.completedResult);

	return completion.completedResult;
}

- (IRCIsonTrackedUserSnapshot *)user:(NSString *)nickname online:(BOOL)online
{
	return [[IRCIsonTrackedUserSnapshot alloc] initWithNickname:nickname online:online];
}

- (IRCIsonQuerySnapshot *)query:(NSString *)nickname identifier:(NSString *)identifier active:(BOOL)active
{
	return [[IRCIsonQuerySnapshot alloc] initWithIdentifier:identifier nickname:nickname active:active];
}

- (IRCIsonApplicationPlan *)planForRequestedNicknames:(NSArray<NSString *> *)requestedNicknames
							  onlineNicknames:(NSArray<NSString *> *)onlineNicknames
									  initial:(BOOL)initial
								 caseMapping:(IRCNicknameCaseMapping)caseMapping
								 trackedUsers:(NSArray<IRCIsonTrackedUserSnapshot *> *)trackedUsers
										queries:(NSArray<IRCIsonQuerySnapshot *> *)queries
{
	IRCIsonRoundResult *result = [self resultForRequestedNicknames:requestedNicknames
													 onlineNicknames:onlineNicknames
															  initial:initial
														 caseMapping:caseMapping];
	IRCIsonApplicationContext *context = [[IRCIsonApplicationContext alloc] initWithTrackedUsers:trackedUsers
																						 queries:queries];

	return IRCIsonApplicationPlanForResult(result, context);
}

- (void)testInitialRoundMarksNewlyOnlineUserAvailable
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice"]
											 onlineNicknames:@[@"ALICE"]
													 initial:YES
												caseMapping:IRCNicknameCaseMappingRFC1459
											 trackedUsers:@[[self user:@"Alice" online:NO]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 1U);
	XCTAssertEqualObjects(plan.trackedUserChanges.firstObject.nickname, @"Alice");
	XCTAssertEqual(plan.trackedUserChanges.firstObject.kind, IRCIsonTrackedUserChangeKindAvailable);
}

- (void)testInitialRoundDoesNotSignOffPreviouslyOnlineUser
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice"]
											 onlineNicknames:@[]
													 initial:YES
												caseMapping:IRCNicknameCaseMappingRFC1459
											 trackedUsers:@[[self user:@"Alice" online:YES]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 0U);
}

- (void)testLaterRoundProducesSignedOnAndSignedOffChanges
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice", @"Bob"]
											 onlineNicknames:@[@"alice"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingRFC1459
											 trackedUsers:@[[self user:@"Alice" online:NO], [self user:@"Bob" online:YES]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 2U);
	XCTAssertEqualObjects(plan.trackedUserChanges[0].nickname, @"Alice");
	XCTAssertEqual(plan.trackedUserChanges[0].kind, IRCIsonTrackedUserChangeKindSignedOn);
	XCTAssertEqualObjects(plan.trackedUserChanges[1].nickname, @"Bob");
	XCTAssertEqual(plan.trackedUserChanges[1].kind, IRCIsonTrackedUserChangeKindSignedOff);
}

- (void)testUnchangedTrackedUsersDoNotProduceRedundantChanges
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice", @"Bob"]
											 onlineNicknames:@[@"Alice"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingASCII
											 trackedUsers:@[[self user:@"Alice" online:YES], [self user:@"Bob" online:NO]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 0U);
}

- (void)testOnlyRequestedTrackedUsersAreEvaluated
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice"]
											 onlineNicknames:@[]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingASCII
											 trackedUsers:@[[self user:@"Alice" online:YES], [self user:@"Bob" online:YES]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 1U);
	XCTAssertEqualObjects(plan.trackedUserChanges.firstObject.nickname, @"Alice");
}

- (void)testQueriesActivateDeactivateAndPreserveIdentifiers
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice", @"Bob"]
											 onlineNicknames:@[@"ALICE"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingRFC1459
											 trackedUsers:@[]
													 queries:@[[self query:@"Alice" identifier:@"query-a" active:NO],
															  [self query:@"Bob" identifier:@"query-b" active:YES]]];

	XCTAssertEqual(plan.queryChanges.count, 2U);
	XCTAssertEqualObjects(plan.queryChanges[0].identifier, @"query-a");
	XCTAssertEqualObjects(plan.queryChanges[0].nickname, @"Alice");
	XCTAssertTrue(plan.queryChanges[0].shouldBeActive);
	XCTAssertEqualObjects(plan.queryChanges[1].identifier, @"query-b");
	XCTAssertFalse(plan.queryChanges[1].shouldBeActive);
}

- (void)testUnchangedAndUnrequestedQueriesDoNotProduceChanges
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice", @"Bob"]
											 onlineNicknames:@[@"Alice"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingASCII
											 trackedUsers:@[]
													 queries:@[[self query:@"Alice" identifier:@"active" active:YES],
															  [self query:@"Bob" identifier:@"inactive" active:NO],
															  [self query:@"Carol" identifier:@"outside-scope" active:YES]]];

	XCTAssertEqual(plan.queryChanges.count, 0U);
}

- (void)testRFC1459MatchesBracketBackslashAndCaretEquivalents
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"[Nick]", @"Path\\", @"Caret^"]
											 onlineNicknames:@[@"{nICK}", @"path|", @"caret~"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingRFC1459
											 trackedUsers:@[[self user:@"[Nick]" online:NO],
																   [self user:@"Path\\" online:NO],
																   [self user:@"Caret^" online:NO]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 3U);
	for (IRCIsonTrackedUserChange *change in plan.trackedUserChanges) {
		XCTAssertEqual(change.kind, IRCIsonTrackedUserChangeKindSignedOn);
	}
}

- (void)testStrictRFC1459DoesNotEquateCaretAndTilde
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Caret^"]
											 onlineNicknames:@[@"caret~"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingStrictRFC1459
											 trackedUsers:@[[self user:@"Caret^" online:YES]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 1U);
	XCTAssertEqual(plan.trackedUserChanges.firstObject.kind, IRCIsonTrackedUserChangeKindSignedOff);
}

- (void)testASCIICaseMappingDoesNotEquateBrackets
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"[Nick]"]
											 onlineNicknames:@[@"{nick}"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingASCII
											 trackedUsers:@[[self user:@"[Nick]" online:YES]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 1U);
	XCTAssertEqual(plan.trackedUserChanges.firstObject.kind, IRCIsonTrackedUserChangeKindSignedOff);
}

- (void)testCaseMappingDoesNotPerformUnicodeCaseFolding
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"É"]
											 onlineNicknames:@[@"é"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingRFC1459
											 trackedUsers:@[[self user:@"É" online:YES]]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 1U);
	XCTAssertEqual(plan.trackedUserChanges.firstObject.kind, IRCIsonTrackedUserChangeKindSignedOff);
}

- (void)testContextAndResultDeeplySnapshotMutableInputs
{
	NSMutableString *requestedNickname = [NSMutableString stringWithString:@"Alice"];
	NSMutableString *trackedNickname = [NSMutableString stringWithString:@"Alice"];
	NSMutableString *queryNickname = [NSMutableString stringWithString:@"Alice"];
	NSMutableString *queryIdentifier = [NSMutableString stringWithString:@"query-a"];
	NSMutableArray<NSString *> *requested = [NSMutableArray arrayWithObject:requestedNickname];
	NSMutableArray<IRCIsonTrackedUserSnapshot *> *users = [NSMutableArray arrayWithObject:[self user:trackedNickname online:NO]];
	NSMutableArray<IRCIsonQuerySnapshot *> *queries = [NSMutableArray arrayWithObject:[self query:queryNickname identifier:queryIdentifier active:NO]];
	IRCIsonRoundResult *result = [self resultForRequestedNicknames:requested
													 onlineNicknames:@[@"Alice"]
															  initial:NO
														 caseMapping:IRCNicknameCaseMappingRFC1459];
	IRCIsonApplicationContext *context = [[IRCIsonApplicationContext alloc] initWithTrackedUsers:users queries:queries];

	[requestedNickname setString:@"MutatedRequest"];
	[trackedNickname setString:@"MutatedUser"];
	[queryNickname setString:@"MutatedQuery"];
	[queryIdentifier setString:@"mutated-id"];
	[requested removeAllObjects];
	[users removeAllObjects];
	[queries removeAllObjects];

	IRCIsonApplicationPlan *plan = IRCIsonApplicationPlanForResult(result, context);

	XCTAssertEqualObjects(result.round.requestedNicknames, (@[@"Alice"]));
	XCTAssertEqual(plan.trackedUserChanges.count, 1U);
	XCTAssertEqualObjects(plan.trackedUserChanges.firstObject.nickname, @"Alice");
	XCTAssertEqual(plan.queryChanges.count, 1U);
	XCTAssertEqualObjects(plan.queryChanges.firstObject.identifier, @"query-a");
}

- (void)testEmptyContextProducesEmptyPlan
{
	IRCIsonApplicationPlan *plan = [self planForRequestedNicknames:@[@"Alice"]
											 onlineNicknames:@[@"Alice"]
													 initial:NO
												caseMapping:IRCNicknameCaseMappingASCII
											 trackedUsers:@[]
													 queries:@[]];

	XCTAssertEqual(plan.trackedUserChanges.count, 0U);
	XCTAssertEqual(plan.queryChanges.count, 0U);
}

@end
