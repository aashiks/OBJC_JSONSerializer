//
//  KVCBaseObject.m
//  JSONTest
//
//  Created by mahadevan on 09/12/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "KVCBaseObject.h"
#import "JSON.h"

@implementation KVCBaseObject

const char * property_getTypeString( objc_property_t property );

- (id) init {
    if (self = [super init]) {
        
    }
    return self;
}

/*
 * Should be implemented by subclasses using NSArray types.
 */
- (NSString *)getComponentTypeForCollection:(NSString *)propertyName {
    return nil;
}

/*
 * Should be implemented by subclasses that will have a different propertyName for a json key.
 */
- (NSString *) getPropertyNameForJsonKey:(NSString *)jsonKey {
    return nil;
}

+ (id)objectForJSON:(NSString *) inputJSON {
    SBJSON *parser = [[SBJSON alloc] init];
	NSDictionary *jDict = [parser objectWithString:inputJSON error:nil];
    return [self objectForDictionary:jDict];
}


const char * property_getTypeString( objc_property_t property )
{
    const char * attrs = property_getAttributes( property );
    if ( attrs == NULL )
        return ( NULL );
    
    static char buffer[256];
    const char * e = strchr( attrs, ',' );
    if ( e == NULL )
        return ( NULL );
    
    int len = (int)(e - attrs);
    memcpy( buffer, attrs, len );
    buffer[len] = '\0';
    
    return ( buffer );
}

+ (BOOL) hasPropertyNamed: (NSString *) name
{
    return ( class_getProperty(self, [name UTF8String]) != NULL );
}


+ (BOOL) hasPropertyForKVCKey: (NSString *) key
{
    if ( [self hasPropertyNamed: key] )
        return ( YES );
    
    return NO;
}

+ (char *) typeOfPropertyNamed: (const char *) rawPropType
{
    int k = 0;
    char * parsedPropertyType = malloc(sizeof(char *) * 16);
    if (*rawPropType == 'T') {
        rawPropType++;
    } else { 
        rawPropType = NULL;
    }
    
    if (rawPropType == NULL) {
        return NULL;
    }
    if (*rawPropType == '@') {
        rawPropType+=2;
        for (; *rawPropType != '\"';) {
            parsedPropertyType[k++] = *rawPropType;
            rawPropType++;
        }
        parsedPropertyType[k] = '\0';
        return parsedPropertyType;
        
    } else if (*rawPropType == 'i'){
        return "NSInteger";
    } else if (*rawPropType == 'd'){
        return "double";
    } else if (*rawPropType == 'f') {
        return "float";
    } else if (*rawPropType == 'c') {
        return "BOOL";
    }
    return ( NULL );
}




+ (NSMutableDictionary *) getPropertiesAndTypesForClassName:(const char *)className {
    
    NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
    id class = objc_getClass(className);
    
    /*
     * Recursively get properties and types of a class including its parent classes.
     * Stop when NSObject is reached.
     * PS : If you are using models of NSManagedObject, you might want to replace the 
     * below line to 
     * if ([class superclass] != [NSManagedObject class]) {
     * and subclass KVCBaseObject from NSObject to NSManagedObject
     */
    
    if ([class superclass] != [NSObject class]) {
        [dict release];
        dict = [[KVCBaseObject getPropertiesAndTypesForClassName:class_getName([class superclass])] retain];
    }
    unsigned int outCount, i; objc_property_t *properties = class_copyPropertyList(class, &outCount); 
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char * propName = property_getName(property);
        NSString * propertyName = [NSString stringWithCString:propName encoding:NSUTF8StringEncoding];
        const char * rawPropType = property_getTypeString(property);
        const char * objCType = [self typeOfPropertyNamed:rawPropType];
        if (objCType == NULL) {
            NSLog(@"Invalid property type for propertyName %@. Skip ", propertyName);
        } else {
            NSString * propertyType = [NSString stringWithCString:objCType encoding:NSUTF8StringEncoding];
            
            [dict setValue:propertyType forKey:propertyName];
        }
        
    }
    return [dict autorelease];
}

+(BOOL) isPropertyTypeArray:(NSString *)propertyType {
    if ([propertyType isEqualToString:@"NSArray"] ||
        [propertyType isEqualToString:@"NSMutableArray"]) {
        return YES;
    } else {
        return NO;
    }
}

+(BOOL) isPropertyTypeBasic:(NSString *)propertyType {
    if ([propertyType isEqualToString:@"NSString"] ||
        [propertyType isEqualToString:@"NSNumber"] ||
        [propertyType isEqualToString:@"NSInteger"] ||
        [propertyType isEqualToString:@"float"] || 
        [propertyType isEqualToString:@"double"] ||
        [propertyType isEqualToString:@"BOOL"]) {
        
        return YES;
    } else {
        return NO;
    }
}

+(id) objectForPropertyKey:(NSString *)propertyType {
    id kvcObject = [[NSClassFromString(propertyType) alloc] init];
    return kvcObject;
}

+ (NSArray *)arrayForType:(NSString *)componentType withJSONArray:(NSArray *)jArray {
    if ([componentType isEqualToString:@"NSString"] ||
        [componentType isEqualToString:@"NSNumber"]) {
        return [NSArray arrayWithArray:jArray];
    }
    
    /*
     * Now for some good object mapping
     * with classic recursion!
     */
    
    NSMutableArray * resultArray = [[NSMutableArray alloc] init];
    
    for (NSDictionary * item in jArray) {
        Class childClass = NSClassFromString(componentType);
        id kvcChild = [childClass objectForDictionary:item];
        [resultArray addObject:kvcChild];
    }
    
    return [resultArray autorelease];
}

+ (id)objectForDictionary:(NSDictionary *) inputDict {
    
    if ([inputDict isKindOfClass:[NSNull class]]) {
        return nil;
    }

    const char* className = class_getName([self class]);
    NSDictionary * propertyDict = [self getPropertiesAndTypesForClassName:className];
    NSArray * propertyKeys = [propertyDict allKeys];
    
    //Create our object
    id kvcObject = [[NSClassFromString([NSString stringWithCString:className encoding:NSUTF8StringEncoding]) alloc] init];
    
    for (NSString * key in [inputDict allKeys]) {
        id propertyValue = [inputDict objectForKey:key];
        NSLog(@"Current key = %@",key);
        
        if (![propertyKeys containsObject:key]) {
            key = [kvcObject getPropertyNameForJsonKey:key];
        }
        if (key) {
            NSString * propType = [propertyDict objectForKey:key];
            /*
             * Sometimes an invalid property type can be used by the client object.
             * Gracefully ignore it.
             */
            if (propType == nil) {
                continue;
            }
            
            if ([KVCBaseObject isPropertyTypeArray:propType]) {
                
                NSString * componentType = [kvcObject getComponentTypeForCollection:key];
                NSArray  * jArray = (NSArray *)propertyValue;
                // If the object has specified a type, create objects of that type. else 
                // set the array as such.
                if ([componentType length] > 1) {
                    NSArray * componentArray = [KVCBaseObject arrayForType:componentType withJSONArray:jArray];
                    [kvcObject setValue:componentArray forKey:key];
                } else {
                    [kvcObject setValue:jArray forKey:key];
                }
                
            } else if ([KVCBaseObject isPropertyTypeBasic:propType]) {
                
                [kvcObject setValue:propertyValue forKey:key];
                
            } else {
                /*
                 * If the component is not any primitive type or array
                 * create a custom object of it and pass the dictionary to it.
                 */
                Class childClass = NSClassFromString(propType);
                if ([childClass isSubclassOfClass:[KVCBaseObject class]]) {
                    id kvcChild = [childClass objectForDictionary:propertyValue];
                    [kvcObject setValue:kvcChild forKey:key];
                } else {
                    [kvcObject setValue:propertyValue forKey:key];
                }
            }
        }
        
    }
    return [kvcObject autorelease];
}



- (NSDictionary *)objectToDictionary {
    const char* className = class_getName([self class]);
    NSDictionary * propertyDict = [KVCBaseObject getPropertiesAndTypesForClassName:className];
    
    NSMutableDictionary * resultDict = [[NSMutableDictionary alloc] init];
    for (NSString * currentProperty in propertyDict) {
        NSString * propType = [propertyDict objectForKey:currentProperty];
        /*
         * Sometimes an invalid property type can be used by the client object.
         * Gracefully ignore it.
         */
        if (propType == nil) {
            continue;
        }
        
        if ([KVCBaseObject isPropertyTypeArray:propType]) {
            
            NSArray * objArray = [self valueForKey:currentProperty];
            if ([objArray count] > 0) {
                id firstObject = [objArray objectAtIndex:0];
                if ([firstObject isKindOfClass:[NSString class]] ||
                    [firstObject isKindOfClass:[NSNumber class]]) {
                    
                    [resultDict setValue:objArray forKey:currentProperty];
                    
                } else {
                    
                    NSMutableArray * customObjArray = [[NSMutableArray alloc] init];
                    for (id arrayObj in objArray) {
                        if ([arrayObj isKindOfClass:[KVCBaseObject class]]){
                            NSDictionary * childDict = [arrayObj objectToDictionary];
                            [customObjArray addObject:childDict];
                        }
                    }
                    [resultDict setValue:customObjArray forKey:currentProperty];
                    [customObjArray release];
                    
                }
            } else {
                NSArray * emptyArray = [[NSArray alloc] init];
                [resultDict setValue:emptyArray forKey:currentProperty];
                [emptyArray release];
            }
            
            
        } else if ([KVCBaseObject isPropertyTypeBasic:propType]) {
            
            id basicValue = [self valueForKey:currentProperty];
            if (basicValue == nil) {
                basicValue = @"";
            }
            [resultDict setValue:basicValue forKey:currentProperty];
            
        } else {
            
            id kvcChild = [self valueForKey:currentProperty];
            if (kvcChild == nil) {
                kvcChild = [[[KVCBaseObject alloc] init] autorelease];
            }
            if ([kvcChild isKindOfClass:[KVCBaseObject class]]) {
                NSDictionary * childDict = [kvcChild objectToDictionary];
                [resultDict setValue:childDict forKey:currentProperty];
            }
            
        }
        
    }
    return [resultDict autorelease];
}

- (NSString *)objectToJson {
    return [[self objectToDictionary] JSONRepresentation];
}


- (void)dealloc {
    [super dealloc];
}
@end
