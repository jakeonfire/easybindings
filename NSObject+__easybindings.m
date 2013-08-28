//
//  NSObject+__easybindings.m
//  easybindings-test
//
//  Created by Grockit on 8/23/13.
//  Copyright (c) 2013 Learnist. All rights reserved.
//

#import <objc/runtime.h>
#import "NSObject+__easybindings.h"
#import "NSObject+__EASY_KVO__.h"

@implementation NSObject (__easybindings)

#if !TARGET_OS_IPHONE
static IMP _originalUnbind;

+ (void)load
{
    const char *methodTypeEncoding = method_getTypeEncoding(class_getInstanceMethod(self, @selector(unbind:)));
    IMP poppedIMP = class_getMethodImplementation(self, @selector(unbind:));
    class_replaceMethod(self, @selector(unbind:), class_getMethodImplementation(self, @selector(__EASY_KVO__unbind:)), methodTypeEncoding);
    _originalUnbind = poppedIMP;
}
#endif

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath
{
    [self bind:binding toObject:observable withKeyPath:keyPath valueTransformer:nil];
}

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath valueTransformer:(NSValueTransformer *)transformer
{
    __unsafe_unretained NSObject *_observer = self;
    void (^callback)(__unsafe_unretained id) = ^(__unsafe_unretained id _observable) {
        id newValue = [_observable valueForKeyPath:keyPath];
        if (transformer) {
            newValue = [transformer transformedValue:newValue];
        }
        [_observer setValue:newValue forKey:binding];
    };
    callback(observable);
    [observable addObserver:self forKeyPath:keyPath options:0 context:(void *)binding.hash observerCallback:callback];
}

#if !TARGET_OS_IPHONE
- (void)__easybindings__unbind:(NSString *)binding
{
    if ([self infoForBinding:binding]) {
        _originalUnbind(self, @selector(unbind:), binding);
        return;
    }
#else
- (void)unbind:(NSString *)binding
{
#endif
    KVOProxy *kvoProxy = self.kvoProxy;
    if (kvoProxy) {
        NSSet *allContexts = [NSSet setWithArray:kvoProxy.contexts];
        for (KVOContext *aContext in allContexts) {
            if (aContext.observer == self && aContext.context == (void *)binding.hash) {
                [aContext.observee removeObserver:self forKeyPath:aContext.keyPath context:aContext.context];
                break;
            }
        }
    }
}

@end
