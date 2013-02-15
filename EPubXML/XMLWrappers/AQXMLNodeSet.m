//
//  AQXMLNodeSet.m
//  EPubXML
//
//  Created by Jim Dovey on 2012-09-18.
//  Copyright (c) 2012 Kobo Inc. All rights reserved.
//

#import "AQXMLNodeSet.h"
#import "AQXMLUtilities.h"
#import "AQXML_Private.h"
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

@implementation AQXMLNodeSet
{
    xmlNodeSetPtr   _nodeSet;
}

+ (AQXMLNodeSet *) nodeSetWithXMLNodeSet: (xmlNodeSetPtr) nodeSet
{
    return ( [[self alloc] initWithXMLNodeSet: nodeSet] );
}

+ (AQXMLNodeSet *) nodeSet
{
    return ( [[self alloc] init] );
}

+ (AQXMLNodeSet *) nodeSetWithNode: (AQXMLNode *) node
{
    return ( [[self alloc] initWithNode: node] );
}

+ (void) addChildNodesOfElement: (AQXMLElement *) element toSet: (AQXMLNodeSet *) nodeSet
{
    [element enumerateChildrenUsingBlock: ^(AQXMLNode *child, NSUInteger idx, BOOL *stop) {
        [nodeSet addUniqueNode: child];
        if ( [child isKindOfClass: [AQXMLElement class]] )
            [self addChildNodesOfElement: (AQXMLElement *)child toSet: nodeSet];
    }];
}

+ (AQXMLNodeSet *) nodeSetWithTreeAtElement: (AQXMLElement *) element
{
    AQXMLNodeSet * set = [self nodeSetWithNode: element];
    [self addChildNodesOfElement: element toSet: set];
    return ( set );
}

- (id) init
{
    return ( [self initWithNode: nil] );
}

- (id) initWithXMLNodeSet: (xmlNodeSetPtr) nodeSet
{
    NSParameterAssert(nodeSet != NULL);
    self = [self initWithNode: nil];
    if ( self == nil )
        return ( nil );
    
    // a nodeSet is usually the child of an xmlXPathObjectPtr, which will free
    // the set when it's released. For that reason, *copy* the node set
    _nodeSet = xmlXPathNodeSetCreate(NULL);
    _nodeSet = xmlXPathNodeSetMerge(_nodeSet, nodeSet);
    
    return ( self );
}

- (id) initWithNode: (AQXMLNode *) node
{
    self = [super init];
    if ( self == nil )
        return ( nil );
    
    _nodeSet = xmlXPathNodeSetCreate(node.xmlObj);
    
    return ( self );
}

- (void) dealloc
{
    xmlXPathFreeNodeSet(_nodeSet);
    _nodeSet = NULL;
}

- (id) copyWithZone: (NSZone *) zone
{
    AQXMLNodeSet * result = [AQXMLNodeSet new];
    [result unionSet: self];
    return ( result );
}

- (NSUInteger) count
{
    return ( _nodeSet->nodeNr );
}

- (NSArray *) nodes
{
    NSMutableArray * nodes = [NSMutableArray new];
    for ( int i = 0; i < _nodeSet->nodeNr; i++ )
    {
        [nodes addObject: (__bridge AQXMLNode *)_nodeSet->nodeTab[i]->_private];
    }
    return ( nodes );
}

- (AQXMLNode *) nodeAtIndex: (NSUInteger) idx
{
    if ( idx >= _nodeSet->nodeNr )
        [NSException raise: NSRangeException format: @"AQXMLNodeSet: Index %lu beyond bounds (0 .. %d)", idx, _nodeSet->nodeNr];
    
    return ( (__bridge AQXMLNode *)_nodeSet->nodeTab[idx]->_private );
}

- (AQXMLNode *) objectAtIndexedSubscript: (NSUInteger) idx
{
    if ( idx >= _nodeSet->nodeNr )
        [NSException raise: NSRangeException format: @"AQXMLNodeSet: Index %lu beyond bounds (0 .. %d)", idx, _nodeSet->nodeNr];
    
    return ( (__bridge AQXMLNode *)_nodeSet->nodeTab[idx]->_private );
}

- (BOOL) boolValue
{
    return ( xmlXPathCastNodeSetToBoolean(_nodeSet) != 0 );
}

- (NSNumber *) numberValue
{
    return ( @(xmlXPathCastNodeSetToNumber(_nodeSet)) );
}

- (NSString *) stringValue
{
    return ( [NSString stringWithXMLString: xmlXPathCastNodeSetToString(_nodeSet)] );
}

- (void) expandSubtree
{
    AQXMLNodeSet * initialSet = [self copy];
    [initialSet enumerateNodesUsingBlock: ^(AQXMLNode *node, BOOL *stop) {
        if ( node.type == AQXMLNodeTypeElement )
            [AQXMLNodeSet addChildNodesOfElement: (AQXMLElement *)node toSet: self];
    }];
}

- (void) sort
{
    xmlXPathNodeSetSort(_nodeSet);
}

- (AQXMLNodeSet *) sortedNodeSet
{
    AQXMLNodeSet * result = [self copy];
    [result sort];
    return ( result );
}

- (void) addNode: (AQXMLNode *) node
{
    xmlXPathNodeSetAdd(_nodeSet, node.xmlObj);
    AQXMLNamespace * ns = node.ns;
    if ( ns != nil )
        xmlXPathNodeSetAddNs(_nodeSet, node.xmlObj, ns.xmlObj);
}

- (void) removeNode: (AQXMLNode *) node
{
    xmlXPathNodeSetDel(_nodeSet, node.xmlObj);
}

- (BOOL) containsNode: (AQXMLNode *) node
{
    return ( xmlXPathNodeSetContains(_nodeSet, node.xmlObj) == 1 );
}

- (void) addUniqueNode: (AQXMLNode *) node
{
    xmlXPathNodeSetAddUnique(_nodeSet, node.xmlObj);
    AQXMLNamespace * ns = node.ns;
    if ( ns != nil )
        xmlXPathNodeSetAddNs(_nodeSet, node.xmlObj, ns.xmlObj);
}

- (void) unionSet: (AQXMLNodeSet *) set
{
    _nodeSet = xmlXPathNodeSetMerge(_nodeSet, set->_nodeSet);
}

- (void) intersectSet: (AQXMLNodeSet *) set
{
    [self enumerateNodesUsingBlock: ^(AQXMLNode *node, BOOL *stop) {
        if ( [set containsNode: node] == NO )
            [self removeNode: node];
    }];
}

- (void) subtractSet: (AQXMLNodeSet *) set
{
    [self enumerateNodesUsingBlock: ^(AQXMLNode *node, BOOL *stop) {
        if ( [set containsNode: node] )
            [self removeNode: node];
    }];
}

#if NS_BLOCKS_AVAILABLE
- (void) enumerateNodesUsingBlock: (void (^)(AQXMLNode * node, BOOL *stop)) block
{
    if ( block == nil )
        return;
    for ( int i = 0; i < _nodeSet->nodeNr; i++ )
    {
        BOOL stop = NO;
        AQXMLNode * node = (__bridge AQXMLNode *)_nodeSet->nodeTab[i]->_private;
        if ( node != nil )
            block(node, &stop);
        if ( stop )
            break;
    }
}
#endif

- (void) ensureAncestorsOfNode: (AQXMLNode *) node existsInDocument: (AQXMLDocument *) document
{
    
}

@end