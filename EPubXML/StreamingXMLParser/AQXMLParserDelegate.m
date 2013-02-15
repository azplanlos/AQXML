/*
 *  AQXMLParserDelegate.m
 *  AQToolkit
 *
 *  Created by Jim Dovey on 23/01/09.
 *  
 *  Copyright (c) 2009 Jim Dovey.
 *  All rights reserved.
 *  
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  Redistributions of source code must retain the above copyright notice,
 *  this list of conditions and the following disclaimer.
 *  
 *  Redistributions in binary form must reproduce the above copyright
 *  notice, this list of conditions and the following disclaimer in the
 *  documentation and/or other materials provided with the distribution.
 *  
 *  Neither the name of this project's author nor the names of its
 *  contributors may be used to endorse or promote products derived from
 *  this software without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
 *  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
 *  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
 *  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 *  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import "AQXMLParserDelegate.h"
#import "AQXMLParser.h"

#if TARGET_OS_IPHONE
# import <UIKit/UIApplication.h>
#endif

static CFStringRef copySelectorDescription( const void * value )
{
    return ( (CFStringRef) CFBridgingRetain([NSStringFromSelector((SEL)value) copy]) );
}

@interface _AQXMLParserSelectorCache : NSObject
{
    CFMutableDictionaryRef  _startSelectorCache;
    CFMutableDictionaryRef  _endSelectorCache;
}

- (void) emptyCache;

- (SEL) startSelectorForElement: (NSString *) elementName;
- (SEL) endSelectorForElement: (NSString *) elementName;

@end

@implementation _AQXMLParserSelectorCache

- (id) init
{
    self = [super init];
	if ( self == nil )
        return ( nil );
    
    CFDictionaryValueCallBacks cb = { 0, NULL, NULL, copySelectorDescription, NULL };
    _startSelectorCache = CFDictionaryCreateMutable( kCFAllocatorDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &cb );
    _endSelectorCache = CFDictionaryCreateMutable( kCFAllocatorDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &cb );
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(emptyCache)
                                                 name: UIApplicationDidReceiveMemoryWarningNotification
                                               object: nil];
#endif
    
    return ( self );
}

- (void) dealloc
{
    CFRelease( _startSelectorCache );
    CFRelease( _endSelectorCache );
}

- (SEL) startSelectorForElement: (NSString *) element
{
    SEL result = (SEL) CFDictionaryGetValue( _startSelectorCache, (__bridge CFTypeRef)element );
    if ( result != NULL )
        return ( result );
    
    NSString * str = nil;
    NSMutableString * eSel = [NSMutableString stringWithString: [[element substringWithRange: NSMakeRange(0,1)] uppercaseString]];
	
    if ( [element length] > 1 )
	{
        [eSel appendString: [element substringFromIndex: 1]];
		
		NSRange range = [eSel rangeOfString: @"-"];
		for ( ; range.location != NSNotFound; range = [eSel rangeOfString: @"-"] )
		{
			NSString * cap = [[eSel substringWithRange: NSMakeRange(range.location+1, 1)] uppercaseString];
			range.length += 1;
			[eSel replaceCharactersInRange: range withString: cap];
		}
	}
	
	str = [NSString stringWithFormat: @"start%@WithAttributes:", eSel];
    
    result = NSSelectorFromString( str );
    CFDictionaryAddValue( _startSelectorCache, (__bridge CFTypeRef)element, result );
    
    return ( result );
}

- (SEL) endSelectorForElement: (NSString *) element
{
    SEL result = (SEL) CFDictionaryGetValue( _endSelectorCache, (__bridge CFTypeRef)element );
    if ( result != NULL )
        return ( result );
    
    NSString * str = nil;
    NSMutableString * eSel = [NSMutableString stringWithString: [[element substringWithRange: NSMakeRange(0,1)] uppercaseString]];
	
    if ( [element length] > 1 )
	{
        [eSel appendString: [element substringFromIndex: 1]];
		
		NSRange range = [eSel rangeOfString: @"-"];
		for ( ; range.location != NSNotFound; range = [eSel rangeOfString: @"-"] )
		{
			NSString * cap = [[eSel substringWithRange: NSMakeRange(range.location+1, 1)] uppercaseString];
			range.length += 1;
			[eSel replaceCharactersInRange: range withString: cap];
		}
	}
	
	str = [NSString stringWithFormat: @"end%@", eSel];
    
    result = NSSelectorFromString( str );
    CFDictionaryAddValue( _endSelectorCache, (__bridge const void *)(element), result );
    
    return ( result );
}

- (void) emptyCache
{
    CFDictionaryRemoveAllValues( _startSelectorCache );
    CFDictionaryRemoveAllValues( _endSelectorCache );
}

@end

#pragma mark -

static _AQXMLParserSelectorCache * __selectorCache = nil;

@implementation AQXMLParserDelegate

@synthesize xmlParser=_parser;

+ (void) initialize
{
    if ( self == [AQXMLParserDelegate class] )
        __selectorCache = [[_AQXMLParserSelectorCache alloc] init];
}
#if DEBUG_TAGS
- (id) init
{
	self = [super init];
	if ( self == nil )
		return ( nil );
	
	_encounteredStartTags = [NSMutableArray new];
	_encounteredEndTags   = [NSMutableArray new];
	
	return ( self );
}
#endif

- (void) parser: (AQXMLParser *) parser didStartElement: (NSString *) elementName
   namespaceURI: (NSString *) namespaceURI qualifiedName: (NSString *) qName
     attributes: (NSDictionary *) attributeDict
{
	@autoreleasepool
    {
        _parser = parser;
        
#if DEBUG_TAGS
        [_encounteredStartTags addObject: elementName];
#endif
        
        // NSLog( @"Starting element: %@", elementName );
        
        SEL selector = [__selectorCache startSelectorForElement: elementName];
        
        if ( [self respondsToSelector: selector] )
        {
            //NSLog( @"Parser: calling -%@", NSStringFromSelector(selector) );
            [self performSelector: selector withObject: attributeDict];
        }
        
        [_characters setString: @""];
        _parser = nil;
    }
}

- (void) parser: (AQXMLParser *) parser didEndElement: (NSString *) elementName
   namespaceURI: (NSString *) namespaceURI qualifiedName: (NSString *) qName
{
	@autoreleasepool
    {
        _parser = parser;
#if DEBUG_TAGS
        [_encounteredEndTags addObject: elementName];
#endif
        
        SEL selector = [__selectorCache endSelectorForElement: elementName];
        
        if ( [self respondsToSelector: selector] )
        {
            //NSLog( @"Parser: calling -%@", NSStringFromSelector(selector) );
            [self performSelector: selector];
        }
        
        [_characters setString: @""];
        _parser = nil;
    }
}

- (void) parser: (AQXMLParser *) parser foundCDATA: (NSData *) CDATABlock
{
	NSString * chars = [[NSString alloc] initWithData: CDATABlock encoding: NSUTF8StringEncoding];
    [self parser: parser foundCharacters: chars];
}

- (void) parser: (AQXMLParser *) parser foundCharacters: (NSString *) string
{
	if ( string == nil )
        return;
	
	if ( _characters == nil )
		_characters = [[NSMutableString alloc] init];
	
    [_characters appendString: string];
}

- (void) parser: (AQXMLParser *) parser parseErrorOccurred: (NSError *) error
{
	// superclass does nothing
}

- (NSString *) characters
{
	return ( [_characters copy] );
}

@end
