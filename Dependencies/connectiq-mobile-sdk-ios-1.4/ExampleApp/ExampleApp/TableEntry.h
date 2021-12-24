//
//  TableEntry.h
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TableEntry : NSObject

@property (nonatomic, strong) NSString *label;
@property (nonatomic, strong) id message;

+ (instancetype)entryWithLabel:(NSString *)label message:(id)message;

@end
