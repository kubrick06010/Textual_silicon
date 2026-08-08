#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const IRCMonitorBatcherErrorDomain;

typedef NS_ERROR_ENUM(IRCMonitorBatcherErrorDomain, IRCMonitorBatcherError) {
	IRCMonitorBatcherErrorInvalidNickname = 1,
	IRCMonitorBatcherErrorUnencodableNickname,
	IRCMonitorBatcherErrorNicknameExceedsByteLimit,
};

typedef NS_ENUM(NSUInteger, IRCMonitorBatchEncodingSelection) {
	IRCMonitorBatchEncodingSelectionPrimary,
	IRCMonitorBatchEncodingSelectionFallback,
};

typedef struct {
	NSStringEncoding primaryEncoding;
	NSStringEncoding fallbackEncoding;
} IRCMonitorBatchEncodingPolicy;

NS_INLINE IRCMonitorBatchEncodingPolicy IRCMonitorBatchEncodingPolicyMake(NSStringEncoding primaryEncoding, NSStringEncoding fallbackEncoding)
{
	return (IRCMonitorBatchEncodingPolicy){primaryEncoding, fallbackEncoding};
}

@interface IRCMonitorBatch : NSObject
@property (readonly, copy) NSArray<NSString *> *nicknames;
@property (readonly, copy) NSString *commandBody;
@property (readonly, copy) NSData *encodedBody;
@property (readonly) IRCMonitorBatchEncodingSelection encodingSelection;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/**
 * Builds MONITOR batches whose encoded command bodies fit maximumBodyBytes.
 * CRLF is excluded from the byte limit.
 */
FOUNDATION_EXPORT NSArray<IRCMonitorBatch *> * _Nullable IRCMonitorBatchesForNicknames(
	NSArray<NSString *> *nicknames,
	BOOL adding,
	IRCMonitorBatchEncodingPolicy encodingPolicy,
	NSUInteger maximumBodyBytes,
	NSError **error);

NS_ASSUME_NONNULL_END
