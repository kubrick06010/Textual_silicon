#import "IRCNicknameCaseMapping.h"

BOOL IRCNicknameCaseMappingParse(NSString *value, IRCNicknameCaseMapping *caseMapping)
{
	NSCParameterAssert(value != nil);

	IRCNicknameCaseMapping parsedMapping;
	NSString *normalizedValue = value.lowercaseString;

	if ([normalizedValue isEqualToString:@"rfc1459"]) {
		parsedMapping = IRCNicknameCaseMappingRFC1459;
	} else if ([normalizedValue isEqualToString:@"strict-rfc1459"]) {
		parsedMapping = IRCNicknameCaseMappingStrictRFC1459;
	} else if ([normalizedValue isEqualToString:@"ascii"]) {
		parsedMapping = IRCNicknameCaseMappingASCII;
	} else {
		return NO;
	}

	if (caseMapping) {
		*caseMapping = parsedMapping;
	}

	return YES;
}

NSString *IRCNicknameCasefold(NSString *nickname, IRCNicknameCaseMapping caseMapping)
{
	NSCParameterAssert(nickname != nil);

	NSMutableString *foldedNickname = [NSMutableString stringWithCapacity:nickname.length];

	for (NSUInteger index = 0; index < nickname.length; index++) {
		unichar character = [nickname characterAtIndex:index];

		if (character >= 'A' && character <= 'Z') {
			character += ('a' - 'A');
		} else if (caseMapping != IRCNicknameCaseMappingASCII) {
			switch (character) {
				case '[':
					character = '{';
					break;
				case ']':
					character = '}';
					break;
				case '\\':
					character = '|';
					break;
				case '^':
					if (caseMapping == IRCNicknameCaseMappingRFC1459) {
						character = '~';
					}
					break;
			}
		}

		[foldedNickname appendFormat:@"%C", character];
	}

	return [foldedNickname copy];
}
