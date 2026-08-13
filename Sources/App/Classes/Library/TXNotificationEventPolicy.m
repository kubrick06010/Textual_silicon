#import "../Headers/TXNotificationEventPolicy.h"

TXNotificationEventPolicyResult TXNotificationEventPolicyEvaluate(TXNotificationEventPolicyInput input)
{
	if (input.terminating) {
		return TXNotificationEventPolicyResultDrop;
	}

	if (input.textEvent && input.authoredBySelf) {
		return TXNotificationEventPolicyResultDrop;
	}

	if (input.outputRuleMatched) {
		return TXNotificationEventPolicyResultDrop;
	}

	if (input.hasTarget) {
		if (input.highlightEvent && input.highlightsIgnored) {
			return TXNotificationEventPolicyResultHandled;
		}

		if (input.highlightEvent == NO && input.pushNotificationsEnabled == NO) {
			return TXNotificationEventPolicyResultHandled;
		}
	}

	return TXNotificationEventPolicyResultContinue;
}
