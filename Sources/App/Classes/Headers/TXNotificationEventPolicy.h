#import "TLONotificationController.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct {
	BOOL terminating;
	BOOL textEvent;
	BOOL authoredBySelf;
	BOOL outputRuleMatched;
	BOOL hasTarget;
	BOOL highlightEvent;
	BOOL highlightsIgnored;
	BOOL pushNotificationsEnabled;
} TXNotificationEventPolicyInput;

typedef NS_ENUM(NSUInteger, TXNotificationEventPolicyResult) {
	/* The event must not update notification or unread state. */
	TXNotificationEventPolicyResultDrop = 0,
	/* The event was handled by a local rule; preserve the caller's event state. */
	TXNotificationEventPolicyResultHandled,
	/* Continue through sound, speech, Dock and UserNotifications policy. */
	TXNotificationEventPolicyResultContinue,
};

FOUNDATION_EXPORT TXNotificationEventPolicyResult TXNotificationEventPolicyEvaluate(TXNotificationEventPolicyInput input);

NS_ASSUME_NONNULL_END
