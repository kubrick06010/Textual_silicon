#import "IRCMonitorReply.h"

#import "IRCMessage.h"
#import "IRCNumerics.h"

@interface IRCMonitorReply ()
@property (readwrite) BOOL online;
@property (readwrite, copy) NSArray<NSString *> *targets;

- (instancetype)initWithOnline:(BOOL)online targets:(NSArray<NSString *> *)targets;
@end

@implementation IRCMonitorReply

- (instancetype)initWithOnline:(BOOL)online targets:(NSArray<NSString *> *)targets
{
	if ((self = [super init])) {
		_online = online;
		_targets = [targets copy];
	}

	return self;
}

+ (nullable instancetype)replyWithMessage:(IRCMessage *)message
{
	NSParameterAssert(message != nil);

	BOOL online = NO;

	if (message.commandNumeric == RPL_MONONLINE) {
		online = YES;
	} else if (message.commandNumeric != RPL_MONOFFLINE) {
		return nil;
	}

	if (message.paramsCount < 2) {
		return nil;
	}

	NSString *targetList = [message paramAt:1];
	NSMutableArray<NSString *> *targets = [NSMutableArray array];

	for (NSString *target in [targetList componentsSeparatedByString:@","]) {
		if (target.length > 0) {
			[targets addObject:target];
		}
	}

	return [[self alloc] initWithOnline:online targets:targets];
}

@end
