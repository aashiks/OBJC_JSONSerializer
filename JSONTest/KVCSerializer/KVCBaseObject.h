//
//  KVCBaseObject.h
//  JSONTest
//
//  Created by mahadevan on 09/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "objc/runtime.h"

@interface KVCBaseObject : NSObject
{
    
}

- (NSString *) getComponentTypeForCollection:(NSString *)propertyName;
- (NSString *) getPropertyNameForJsonKey:(NSString *)jsonKey;
+ (NSMutableDictionary *) getPropertiesAndTypesForClassName:(const char *)className;

/*
 * Use the below two methods for deserializing to Objects
 */
+ (KVCBaseObject *)objectForJSON:(NSString *) inputJSON;
+ (KVCBaseObject *)objectForDictionary:(NSDictionary *) inputDict;

/*
 * Use the below two methods for serializing To JSON or NSDictionary
 */
- (NSDictionary *)objectToDictionary;
- (NSString *)objectToJson;

@end
