#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IRCNicknameCaseMapping) {
	IRCNicknameCaseMappingRFC1459,
	IRCNicknameCaseMappingStrictRFC1459,
	IRCNicknameCaseMappingASCII,
};

/** Parses an ISUPPORT CASEMAPPING value. Unknown values return NO. */
FOUNDATION_EXPORT BOOL IRCNicknameCaseMappingParse(
	NSString *value,
	IRCNicknameCaseMapping * _Nullable caseMapping);

/** Returns the canonical identity key defined by the selected IRC casemapping. */
FOUNDATION_EXPORT NSString *IRCNicknameCasefold(
	NSString *nickname,
	IRCNicknameCaseMapping caseMapping);

NS_ASSUME_NONNULL_END
