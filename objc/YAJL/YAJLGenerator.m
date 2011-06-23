// YAJL YAJLGenerator.m
//
// Copyright © 2010, 2011, Roy Ratcliffe, Pioneering Software, United Kingdom
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND, EITHER
// EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "YAJLGenerator.h"
#import "YAJLErrorDomain.h"

#import "yajl_gen.h"

@implementation YAJLGenerator

- (id)init
{
	if ((self = [super init]))
	{
		gen = yajl_gen_alloc(NULL);
	}
	return self;
}

- (void)dealloc
{
	yajl_gen_free(gen);
	free(indentCString);
	[super dealloc];
}

//------------------------------------------------------------------------------
#pragma mark                                                               flags
//------------------------------------------------------------------------------

- (NSString *)indentString
{
	return [NSString stringWithUTF8String:indentCString];
}

- (void)setIndentString:(NSString *)string
{
	free(indentCString);
	indentCString = strdup([string UTF8String]);
	yajl_gen_config(gen, yajl_gen_indent_string, indentCString);
}

- (BOOL)beautify
{
	return (yajl_gen_get_flags(gen) & yajl_gen_beautify) != 0;
}

- (void)setBeautify:(BOOL)flag
{
	yajl_gen_config(gen, yajl_gen_beautify, flag);
}

- (BOOL)validateUTF8
{
	return (yajl_gen_get_flags(gen) & yajl_gen_validate_utf8) != 0;
}

- (void)setValidateUTF8:(BOOL)flag
{
	yajl_gen_config(gen, yajl_gen_validate_utf8, flag);
}

- (BOOL)escapeSolidus
{
	return (yajl_gen_get_flags(gen) & yajl_gen_escape_solidus) != 0;
}

- (void)setEscapeSolidus:(BOOL)flag
{
	// Strangely, the following runs but has no effect. At version 2.0.3, the
	// yajl_gen_config API accepts the escape-solidus request but does
	// nothing. See the implementation of YAJL's yajl_gen_config in yajl_gen.c
	// source.
	yajl_gen_config(gen, yajl_gen_escape_solidus, flag);
}

//------------------------------------------------------------------------------
#pragma mark                                                          generators
//------------------------------------------------------------------------------

/*!
 * Handles YAJL status; answers with YES or NO, and generates an error if
 * NO. All the generator methods answer YES on success, NO on failure. If they
 * fail and you supply a pointer to an NSError pointer equal to nil, the
 * generator methods create a new error. The error code equals the generator
 * status, a non-zero value.
 */
static BOOL YAJLGenerateError(yajl_gen_status status, NSError **outError)
{
	BOOL yes = status == yajl_gen_status_ok;
	if (!yes && outError && *outError == nil)
	{
		*outError = [NSError errorWithDomain:YAJLErrorDomain code:status userInfo:nil];
	}
	return yes;
}

- (BOOL)generateInteger:(long long)number error:(NSError **)outError
{
	return YAJLGenerateError(yajl_gen_integer(gen, number), outError);
}

- (BOOL)generateDouble:(double)number error:(NSError **)outError
{
	return YAJLGenerateError(yajl_gen_double(gen, number), outError);
}

- (BOOL)generateString:(NSString *)string error:(NSError **)outError
{
	const char *UTF8String = [string UTF8String];
	return YAJLGenerateError(yajl_gen_string(gen, (const unsigned char *)UTF8String, strlen(UTF8String)), outError);
}

- (BOOL)generateNullWithError:(NSError **)outError
{
	return YAJLGenerateError(yajl_gen_null(gen), outError);
}

- (BOOL)generateBool:(BOOL)yesOrNo error:(NSError **)outError
{
	return YAJLGenerateError(yajl_gen_bool(gen, yesOrNo), outError);
}

- (BOOL)generateMap:(NSDictionary *)dictionary error:(NSError **)outError
{
	BOOL yes = YAJLGenerateError(yajl_gen_map_open(gen), outError);
	if (yes)
	{
		for (id key in dictionary)
		{
			yes = [self generateObject:key error:outError];
			if (!yes) return yes;
			
			yes = [self generateObject:[dictionary objectForKey:key] error:outError];
			if (!yes) return yes;
		}
		yes = YAJLGenerateError(yajl_gen_map_close(gen), outError);
	}
	return yes;
}

- (BOOL)generateArray:(NSArray *)array error:(NSError **)outError
{
	BOOL yes = YAJLGenerateError(yajl_gen_array_open(gen), outError);
	if (yes)
	{
		for (id element in array)
		{
			yes = [self generateObject:element error:outError];
			if (!yes) return yes;
		}
		yes = YAJLGenerateError(yajl_gen_array_close(gen), outError);
	}
	return yes;
}

- (BOOL)generateObject:(id)object error:(NSError **)outError
{
	BOOL yes;
	if (object == nil || [object isKindOfClass:[NSNull class]])
	{
		yes = [self generateNullWithError:outError];
	}
	else if ([object isKindOfClass:[NSNumber class]])
	{
		const char *objCType = [object objCType];
		// Fold all the integer formats available for NSNumber to a long-long
		// integer, a signed integer or to be more specific a signed
		// long-long. Long-long is the basic type accepted by the underlying
		// implementation. Unsigned values greater than LLONG_MAX (see limits.h)
		// become type cast to the equivalent signed value.
		static const char *integerEncodings[] =
		{
			// signed
			@encode(char),
			@encode(short),
			@encode(int),
			@encode(long),
			@encode(long long),
			// unsigned
			@encode(unsigned char),
			@encode(unsigned short),
			@encode(unsigned int),
			@encode(unsigned long),
			@encode(unsigned long long),
		};
#define DIMOF(array) (sizeof(array)/sizeof((array)[0]))
		NSUInteger i;
		for (i = 0; i < DIMOF(integerEncodings) && strcmp(objCType, integerEncodings[i]); i++);
		if (i < DIMOF(integerEncodings))
		{
			yes = [self generateInteger:[object longLongValue] error:outError];
		}
		else if (strcmp(objCType, @encode(double)) == 0 || strcmp(objCType, @encode(float)) == 0)
		{
			yes = [self generateDouble:[object doubleValue] error:outError];
		}
		else if (strcmp(objCType, @encode(BOOL)) == 0)
		{
			yes = [self generateBool:[object boolValue] error:outError];
		}
	}
	else if ([object isKindOfClass:[NSString class]])
	{
		yes = [self generateString:object error:outError];
	}
	else if ([object isKindOfClass:[NSDictionary class]])
	{
		yes = [self generateMap:object error:outError];
	}
	else if ([object isKindOfClass:[NSArray class]])
	{
		yes = [self generateArray:object error:outError];
	}
	else
	{
		yes = NO;
	}
	return yes;
}

//------------------------------------------------------------------------------
#pragma mark                                                              buffer
//------------------------------------------------------------------------------

- (NSData *)bufferWithError:(NSError **)outError
{
	NSData *data;
	const unsigned char *buf;
	size_t len;
	if (YAJLGenerateError(yajl_gen_get_buf(gen, &buf, &len), outError))
	{
		data = [NSData dataWithBytes:buf length:len];
	}
	else
	{
		data = nil;
	}
	return data;
}

- (NSString *)stringWithError:(NSError **)outError
{
	NSString *string;
	NSData *data = [self bufferWithError:outError];
	if (data)
	{
		string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	}
	else
	{
		string = nil;
	}
	return string;
}

@end
