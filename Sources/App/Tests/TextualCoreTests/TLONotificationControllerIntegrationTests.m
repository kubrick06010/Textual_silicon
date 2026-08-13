@import XCTest;
@import UserNotifications;

#import "TXSharedApplicationPrivate.h"
#import "TLONotificationControllerPrivate.h"

@interface TLONotificationControllerIntegrationTests : XCTestCase
@end

@implementation TLONotificationControllerIntegrationTests

- (void)testMacOSAcceptsNotificationRequestForNotificationCenter
{
	XCTestExpectation *authorizationExpectation = [self expectationWithDescription:@"Read notification authorization status"];
	__block UNAuthorizationStatus authorizationStatus = UNAuthorizationStatusNotDetermined;

	[[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
		authorizationStatus = settings.authorizationStatus;
		[authorizationExpectation fulfill];
	}];

	[self waitForExpectations:@[authorizationExpectation] timeout:5.0];

	if (authorizationStatus == UNAuthorizationStatusNotDetermined) {
		XCTSkip(@"macOS has not decided notification authorization; grant Textual notification permission and rerun this integration test.");
	}

	if (authorizationStatus == UNAuthorizationStatusDenied) {
		XCTSkip(@"macOS denied Textual notification authorization; enable it in System Settings and rerun this integration test.");
	}

	NSString *token = [NSUUID UUID].UUIDString;
	NSString *title = [NSString stringWithFormat:@"Textual notification integration %@", token];
	NSString *message = [NSString stringWithFormat:@"Notification Center request body %@", token];
	NSString *threadIdentifier = [NSString stringWithFormat:@"TextualIntegrationThread-%@", token];

	[sharedNotificationController() scheduleNotificationWithTitle:title
											 message:message
											userInfo:@{@"testToken": token}
										 threadIdentifier:threadIdentifier];

		XCTestExpectation *requestExpectation = [self expectationWithDescription:@"Notification request accepted by macOS"];
		__block NSArray<UNNotificationRequest *> *matchingRequests = nil;

	NSDate *pollStart = [NSDate date];
	__block void (^pollPendingRequests)(void);
	pollPendingRequests = ^{
		[[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
			NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(UNNotificationRequest *request, NSDictionary *bindings) {
				return [request.content.userInfo[@"testToken"] isEqualToString:token];
			}];
			matchingRequests = [requests filteredArrayUsingPredicate:predicate];

			if (matchingRequests.count > 0 || -[pollStart timeIntervalSinceNow] > 5.0) {
				[requestExpectation fulfill];
			} else {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_MSEC * 100)), dispatch_get_main_queue(), pollPendingRequests);
			}
		}];
	};
	pollPendingRequests();

		[self waitForExpectations:@[requestExpectation] timeout:5.0];

		XCTAssertEqual(matchingRequests.count, 1);
		UNNotificationRequest *request = matchingRequests.firstObject;
		XCTAssertEqualObjects(request.content.title, title);
		XCTAssertEqualObjects(request.content.body, message);
		XCTAssertEqualObjects(request.content.threadIdentifier, threadIdentifier);

		[[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[request.identifier]];
}

@end
