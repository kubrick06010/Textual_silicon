#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const IRCIsonBatcherErrorDomain;

typedef NS_ERROR_ENUM(IRCIsonBatcherErrorDomain, IRCIsonBatcherError) {
	IRCIsonBatcherErrorInvalidNickname = 1,
	IRCIsonBatcherErrorUnencodableNickname,
	IRCIsonBatcherErrorNicknameExceedsByteLimit,
};

typedef NS_ENUM(NSUInteger, IRCIsonBatchEncodingSelection) {
	IRCIsonBatchEncodingSelectionPrimary,
	IRCIsonBatchEncodingSelectionFallback,
};

typedef struct {
	NSStringEncoding primaryEncoding;
	NSStringEncoding fallbackEncoding;
} IRCIsonBatchEncodingPolicy;

NS_INLINE IRCIsonBatchEncodingPolicy IRCIsonBatchEncodingPolicyMake(NSStringEncoding primaryEncoding, NSStringEncoding fallbackEncoding)
{
	return (IRCIsonBatchEncodingPolicy){primaryEncoding, fallbackEncoding};
}

@interface IRCIsonBatch : NSObject
@property (readonly, copy) NSArray<NSString *> *nicknames;
@property (readonly, copy) NSString *commandBody;
@property (readonly, copy) NSData *encodedBody;
@property (readonly) IRCIsonBatchEncodingSelection encodingSelection;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/**
 * Builds ISON batches whose encoded command bodies fit maximumBodyBytes.
 * Primary encoding is preferred whenever it can represent the complete body;
 * fallback is used only when primary cannot. CRLF is excluded from the limit.
 */
FOUNDATION_EXPORT NSArray<IRCIsonBatch *> * _Nullable IRCIsonBatchesForNicknames(
	NSArray<NSString *> *nicknames,
	IRCIsonBatchEncodingPolicy encodingPolicy,
	NSUInteger maximumBodyBytes,
	NSError **error);

NS_ASSUME_NONNULL_END
