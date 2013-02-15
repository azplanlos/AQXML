//
//  C14NTransforms.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-20.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "C14NTransforms.h"
#import "AQXMLDocument.h"
#import "AQXMLElement.h"
#import "AQXMLNodeSet.h"
#import "AQXMLAttribute.h"

@implementation C14NTransform

- (AQXMLCanonicalizationMethod) method
{
    return ( AQXMLCanonicalizationMethod_1_0 );
}

- (id) main
{
    id obj = self.input;
    if ( [obj isKindOfClass: [NSData class]] )
    {
        obj = [AQXMLDocument documentWithXMLData: obj error: NULL];
    }
    
    NSData * output = nil;
    if ( [obj isKindOfClass: [AQXMLDocument class]] )
    {
        output = [obj canonicalizedDataUsingMethod: self.method usedEncoding: NULL];
    }
    else if ( [obj isKindOfClass: [AQXMLElement class]] )
    {
        output = [[obj document] canonicalizedDataForElement: obj usingMethod: self.method usedEncoding: NULL];
    }
    else if ( [obj isKindOfClass: [AQXMLNodeSet class]] && [obj count] != 0 )
    {
        AQXMLNodeSet * nodeSet = obj;
        output = [AQXMLCanonicalizer canonicalizeDocument: nodeSet[0].document usingMethod: self.method visibilityFilter: ^BOOL(AQXMLNode *node) {
            return ( [nodeSet containsNode: node] );
        }];
    }
    
    return ( output );
}

@end

@implementation C14N_CLASS(10)
- (AQXMLCanonicalizationMethod) method { return ( AQXMLCanonicalizationMethod_1_0 ); }
@end

@implementation C14N_CLASS(11)
- (AQXMLCanonicalizationMethod) method { return ( AQXMLCanonicalizationMethod_1_1 ); }
@end

@implementation C14N_CLASS(10Exclusive)
- (AQXMLCanonicalizationMethod) method { return ( AQXMLCanonicalizationMethod_exclusive_1_0 ); }
@end

@implementation C14N_CLASS(10WithComments)
- (AQXMLCanonicalizationMethod) method { return ( AQXMLCanonicalizationMethod_1_0|AQXMLCanonicalizationMethod_with_comments ); }
@end

@implementation C14N_CLASS(11WithComments)
- (AQXMLCanonicalizationMethod) method { return ( AQXMLCanonicalizationMethod_1_1|AQXMLCanonicalizationMethod_with_comments ); }
@end

@implementation C14N_CLASS(10ExclusiveWithComments)
- (AQXMLCanonicalizationMethod) method { return ( AQXMLCanonicalizationMethod_exclusive_1_0|AQXMLCanonicalizationMethod_with_comments ); }
@end

@implementation C14N20Transform

- (id) main
{
    if ( self.methodElement == nil )
        return ( nil );
    
    AQXMLCanonicalizer * canon = nil;
    
    id obj = self.input;
    if ( [obj isKindOfClass: [NSData class]] )
    {
        canon = [[AQXMLCanonicalizer alloc] initWithData: obj];
    }
    else if ( [obj isKindOfClass: [AQXMLDocument class]] )
    {
        canon = [[AQXMLCanonicalizer alloc] initWithDocument: obj];
    }
    else if ( [obj isKindOfClass: [AQXMLElement class]] )
    {
        canon = [[AQXMLCanonicalizer alloc] initWithDocument: [obj document]];
        AQXMLNodeSet * nodeSet = [AQXMLNodeSet nodeSetWithTreeAtElement: obj];
        canon.isNodeVisible = ^(AQXMLNode * node) {
            return ( [nodeSet containsNode: node] );
        };
    }
    else if ( [obj isKindOfClass: [AQXMLNodeSet class]] && [obj count] != 0 )
    {
        AQXMLNodeSet * nodeSet = obj;
        canon = [[AQXMLCanonicalizer alloc] initWithDocument: nodeSet[0].document];
        canon.isNodeVisible = ^(AQXMLNode * node) {
            return ( [nodeSet containsNode: node] );
        };
    }
    
    if ( canon == nil )
        return ( nil );
    
    // parse the options
    canon.preserveComments = [self.methodElement firstChildNamed: @"c14n2:IgnoreComments"].firstChild.boolValue;
    canon.preserveWhitespace = ![self.methodElement firstChildNamed: @"c14n2:TrimTextNodes"].firstChild.boolValue;
    canon.rewritePrefixes = [[self.methodElement firstChildNamed: @"c14n2:PrefixRewrite"].firstChild.stringValue isEqualToString: @"sequential"];
    
    AQXMLElement * qNames = [self.methodElement firstChildNamed: @"c14n2:QNameAware"];
    for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:QualifiedAttr"] )
    {
        AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
        AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
        if ( nameAttr == nil || nsAttr == nil )
            continue;
        
        [canon addQNameAwareAttribute: nameAttr.value namespaceURI: nsAttr.value];
    }
    
    for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:Element"] )
    {
        AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
        AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
        if ( nameAttr == nil || nsAttr == nil )
            continue;
        
        [canon addQNameAwareElement: nameAttr.value namespaceURI: nsAttr.value];
    }
    
    for ( AQXMLElement * element in [qNames childrenNamed: @"c14n2:XPathElement"] )
    {
        AQXMLAttribute * nameAttr = [element attributeNamed: @"Name"];
        AQXMLAttribute * nsAttr = [element attributeNamed: @"NS"];
        if ( nameAttr == nil || nsAttr == nil )
            continue;
        
        [canon addQNameAwareXPathElement: nameAttr.value namespaceURI: nsAttr.value];
    }
    
    // run it
    NSOutputStream * stream = [NSOutputStream outputStreamToMemory];
    if ( [canon canonicalizeToStream: stream error: NULL] == NO )
        return ( nil );
    
    return ( [stream propertyForKey: NSStreamDataWrittenToMemoryStreamKey] );
}

@end