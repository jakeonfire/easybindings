//
//  NSObject+__easybindings.h
//  easybindings-test
//
//  Created by Grockit on 8/23/13.
//  Copyright (c) 2013 Learnist. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (__easybindings)

// Similar to -bind:toObject:withKeyPath:options: in Cocoa's NSKeyValueBindingCreaton protocol
- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath;
- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath valueTransformer:(NSValueTransformer *)transformer;
- (void)unbind:(NSString *)binding;
- (NSString *)infoForBinding:(NSString *)binding;

@end
