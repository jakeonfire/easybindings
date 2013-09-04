//
//  NSObject+__easybindings.m
//  easybindings-test
//
//  Created by Grockit on 8/23/13.
//  Copyright (c) 2013 Learnist. All rights reserved.
//

#import "NSObject+__easybindings.h"

@interface BindingInfo : NSObject
@property(nonatomic, weak) id observer;
@property(nonatomic, strong) NSString *binding;
@property(nonatomic, strong) NSValueTransformer *transformer;
@property(nonatomic, strong) NSMutableDictionary *bindingHelpers;
@property(nonatomic, weak) id observable;
@property(nonatomic, strong) NSString *keyPath;
@end

@implementation BindingInfo

static NSMutableDictionary *allBindingInfos;

+ (void)load
{
    allBindingInfos = [NSMutableDictionary dictionary];
}

+ (BindingInfo *)createBindingInfoForBinding:(NSString *)binding on:(NSObject *)boundObject
{
    NSMutableDictionary *objectBindingInfos = allBindingInfos[@(boundObject.hash)];
    if (!objectBindingInfos) {
        objectBindingInfos = [NSMutableDictionary dictionary];
        allBindingInfos[@(boundObject.hash)] = objectBindingInfos;
    }
    BindingInfo *bindingInfo = objectBindingInfos[binding];
    if (bindingInfo) {
        [boundObject unbind:binding];
    }
    bindingInfo = [[BindingInfo alloc] init];
    bindingInfo.binding = binding;
    bindingInfo.observer = boundObject;
    bindingInfo.bindingHelpers = objectBindingInfos;
    objectBindingInfos[binding] = bindingInfo;
    return bindingInfo;
}

+ (BindingInfo *)bindingInfoForBinding:(NSString *)binding on:(NSObject *)boundObject
{
    NSMutableDictionary *objectBindingInfos = allBindingInfos[@(boundObject.hash)];
    return [objectBindingInfos valueForKey:binding];
}

+ (void)removeBindingInfo:(BindingInfo *)bindingInfo on:(NSObject *)boundObject
{
    NSMutableDictionary *objectBindingInfos = allBindingInfos[@(boundObject.hash)];
    [objectBindingInfos removeObjectForKey:bindingInfo.binding];
    if (!objectBindingInfos.count) {
        [allBindingInfos removeObjectForKey:@(boundObject.hash)];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id newValue = change[NSKeyValueChangeNewKey];
    if (_transformer) {
        newValue = [_transformer transformedValue:newValue];
    }
    [self.observer setValue:newValue forKeyPath:self.binding];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<easybinding %p: <%@ %p>.%@ bound to <%@ %p>.%@>", self, [self.observer class], self.observer, self.binding, [self.observable class], self.observable, self.keyPath];
}

@end

@implementation NSObject (__easybindings)

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath
{
    [self bind:binding toObject:observable withKeyPath:keyPath valueTransformer:nil];
}

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath valueTransformer:(NSValueTransformer *)transformer
{
    BindingInfo *bindingInfo = [BindingInfo createBindingInfoForBinding:binding on:self];
    bindingInfo.observable = observable;
    bindingInfo.keyPath = keyPath;
    bindingInfo.transformer = transformer;
    [observable addObserver:bindingInfo forKeyPath:keyPath options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) context:(void *)binding.hash];
}

- (NSString *)infoForBinding:(NSString *)binding
{
    return [[BindingInfo bindingInfoForBinding:binding on:self] description];
}

- (void)unbind:(NSString *)binding
{
    BindingInfo *bindingInfo = [BindingInfo bindingInfoForBinding:binding on:self];
    if (!bindingInfo) {
        NSLog(@"[easybindings] unbind not possible: cannot determine the original binding info for %@.%@", self, binding);
        return;
    }
    [BindingInfo removeBindingInfo:bindingInfo on:self];
    [bindingInfo.observable removeObserver:bindingInfo forKeyPath:bindingInfo.keyPath context:(void *)binding.hash];
}

@end
