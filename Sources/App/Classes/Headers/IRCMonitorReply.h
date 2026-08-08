#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class IRCMessage;

@interface IRCMonitorReply : NSObject
@property (readonly) BOOL online;
@property (readonly, copy) NSArray<NSString *> *targets;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (nullable instancetype)replyWithMessage:(IRCMessage *)message;
@end

NS_ASSUME_NONNULL_END
