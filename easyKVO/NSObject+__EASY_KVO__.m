
//
//  NSObject+__EASY_KVO__.m
//  https://github.com/saldavonschwartz/easyKVO
/*
 Copyright (c) 2013 Federico Saldarini
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */


#import "NSObject+__EASY_KVO__.h"
#import <objc/runtime.h>

#if __has_feature(objc_arc)
#define __BRIDGE_IF_ARC(x) __bridge x
#define __RELEASE_IF_NO_ARC(x)
#define __RETAIN_IF_NO_ARC(x) x
#else
#define __BRIDGE_IF_ARC(x) x
#define __RELEASE_IF_NO_ARC(x) [x release]
#define __RETAIN_IF_NO_ARC(x) [x retain]
#endif


//------------------------------------------------------------------------------------------------------------------------------------------

static const char *KVOProxyKey = "KVOProxyKey";
static const char *RemoveInProgressWithContextKey = "RemoveInProgressWithContextKey";

static IMP _originalAddObserver;
static IMP _originalRemoveObserver;
static IMP _originalRemoveObserverWithContext;
static IMP _originalDealloc;

typedef struct {
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
} BlockDescriptor;

typedef struct {
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    BlockDescriptor *descriptor;
} Block;

NSString *NSStringFromBlockEncoding(id block)
{
    Block *t_block = (__BRIDGE_IF_ARC(void*))block;
    BlockDescriptor *descriptor = t_block->descriptor;
    
    int copyDisposeFlag = 1 << 25;
    int signatureFlag = 1 << 30;
    
    assert(t_block->flags & signatureFlag);
    
    int index = 0;
    if(t_block->flags & copyDisposeFlag)
        index += 2;
    
    return [NSString stringWithUTF8String:descriptor->rest[index]];
}

IMP popAndReplaceImplementation(Class class, SEL original, SEL replacement)
{
    const char *methodTypeEncoding = method_getTypeEncoding(class_getInstanceMethod(class, original));
    IMP poppedIMP = class_getMethodImplementation(class, original);
    class_replaceMethod(class, original, class_getMethodImplementation(class, replacement), methodTypeEncoding);
    return poppedIMP;
}

//------------------------------------------------------------------------------------------------------------------------------------------

@interface KVOContext ()

@property (nonatomic, assign, readwrite)NSObject *observee;
@property (nonatomic, assign, readwrite)NSObject *observer;
@property (nonatomic, strong, readwrite)NSString *keyPath;
@property (nonatomic, assign, readwrite)void *context;
@property (nonatomic, copy, readwrite)id callback;
@property (nonatomic, assign, readwrite)KVOContextCallbackType callbackType;

- (id)initWithObservee:(NSObject*)observee observer:(NSObject*)observer keyPath:(NSString*)keyPath context:(void*)context callback:(id)callback;
- (BOOL)isEqual:(id)object;

@end


@implementation KVOContext

static NSString *CallbackEncodingKVO;
static NSString *CallbackEncodingObserver;

+ (void)initialize
{
    KVOCallback kvoCallback = ^(NSString* keyPath, id object, NSDictionary* change, void* context){};
    OBserverCallback observerCallback = ^(__unsafe_unretained id observee){};
    CallbackEncodingKVO = __RETAIN_IF_NO_ARC(NSStringFromBlockEncoding(kvoCallback));
    CallbackEncodingObserver = __RETAIN_IF_NO_ARC(NSStringFromBlockEncoding(observerCallback));
}

- (id)initWithObservee:(NSObject*)observee observer:(NSObject*)observer keyPath:(NSString*)keyPath context:(void*)context callback:(id)callback
{
    self = [super init];
    if (self) {
        self.observee = observee;
        self.observer = observer;
        self.keyPath = keyPath;
        self.context = context;
        
        if (callback) {
            NSString *callbackEncoding = NSStringFromBlockEncoding(callback);
            if ([callbackEncoding isEqualToString:CallbackEncodingKVO]) {
                self.callbackType = KVOContextCallbackTypeKVO;
            }
            else if ([callbackEncoding isEqualToString:CallbackEncodingObserver]) {
                self.callbackType = KVOContextCallbackTypeObserver;
            }
            else {
                NSAssert(NO, @"invalid callback type. Valid types are KVOContextCallbackTypeKVO or KVOContextCallbackTypeObserver");
            }

            self.callback = callback;
        }
    }
    
    return self;
}

- (BOOL)isEqual:(id)object
{
    BOOL equality = NO;
    if (object && [object isKindOfClass:KVOContext.class]) {
        KVOContext *rho = (KVOContext*)object;
        equality = (self.observee == rho.observee &&
                    self.observer == rho.observer &&
                    self.context == rho.context &&
                    [self.keyPath isEqualToString:rho.keyPath]);
    }
    
    return equality;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@(\n  observee: %@\n  observer: %@\n  keypath: %@\n  context: %@\n  callback: %@ | type = %@\n)",
            [super description],
            self.observee,
            self.observer,
            self.keyPath,
            self.context,
            self.callback,
            self.callbackType == KVOContextCallbackTypeKVO ? @"KVO callback" : self.callbackType == KVOContextCallbackTypeObserver ? @"Observer callback" : @"none"];
}

- (KVOProxy *)kvoProxy
{
    return nil;
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [_keyPath release];
    [_callback release];
    [super dealloc];
}
#endif

@end


//------------------------------------------------------------------------------------------------------------------------------------------

@interface KVOProxy ()
@property (nonatomic, strong)NSMutableArray *_mutableContexts;
@property (nonatomic, strong)NSMutableIndexSet *i;
@property (nonatomic, assign)NSObject *delegate;

- (void)unbindAllContexts;

@end


@implementation KVOProxy

- (id)initWithDelegate:(NSObject*)delegate
{
    self = [super init];
    if (self) {
        __mutableContexts = [[NSMutableArray alloc] init];
        _i = [[NSMutableIndexSet alloc] init];
        self.delegate = delegate;
    }
    
    return self;
}

- (void)unbindAllContexts
{
    NSArray *contextsToUnbind = [NSArray arrayWithArray:self._mutableContexts];
    for (KVOContext *aContext in contextsToUnbind) {
        [aContext.observee removeObserver:aContext.observer forKeyPath:aContext.keyPath context:aContext.context];
    }
}

- (NSArray *)contexts
{
    return [NSArray arrayWithArray:__mutableContexts];
}

- (KVOProxy *)kvoProxy
{
    return nil;
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
    [__mutableContexts release];
    [_i release];
    [super dealloc];
}
#endif

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    KVOContext *aContext = [[KVOContext alloc] initWithObservee:object observer:self.delegate keyPath:keyPath context:context callback:nil];
    NSInteger nextContextIndex = [self.i firstIndex];

    if ((nextContextIndex == NSNotFound) || ![self._mutableContexts[nextContextIndex] isEqual:aContext]) {
        self.i = [self._mutableContexts indexesOfObjectsPassingTest:^BOOL(KVOContext *anotherContext, NSUInteger idx, BOOL *stop) {
            return [aContext isEqual:anotherContext];
        }].mutableCopy;
        __RELEASE_IF_NO_ARC(_i);
    }

    __RELEASE_IF_NO_ARC(aContext);
    
    if (self.i.count) {
        aContext = self._mutableContexts[self.i.firstIndex];
        [self.i removeIndex:self.i.firstIndex];
        
        if (aContext.callback) {
            if (aContext.callbackType == KVOContextCallbackTypeKVO) {
                ((KVOCallback)aContext.callback)(keyPath, object, change, context);
            }
            else {
                ((OBserverCallback)aContext.callback)(object);
            }
            return;
        }
        
        [aContext.observer observeValueForKeyPath:aContext.keyPath ofObject:aContext.observee change:change context:aContext.context];
    }
}

@end


//------------------------------------------------------------------------------------------------------------------------------------------

@interface NSObject (__EASY_KVO__PRIVATE)
@property (nonatomic, assign)BOOL removeWithContextInProgress;
@end

@implementation NSObject (__EASY_KVO__PRIVATE)

- (BOOL)removeWithContextInProgress
{
    return [((NSNumber*)objc_getAssociatedObject(self, RemoveInProgressWithContextKey)) boolValue];
}

- (void)setRemoveWithContextInProgress:(BOOL)removeWithContextInProgress
{
    objc_setAssociatedObject(self, RemoveInProgressWithContextKey, [NSNumber numberWithBool:removeWithContextInProgress], OBJC_ASSOCIATION_RETAIN);
}

@end


@implementation NSObject (__EASY_KVO__)

+ (void)load
{
    _originalAddObserver = popAndReplaceImplementation(self, @selector(addObserver:forKeyPath:options:context:), @selector(__EASY_KVO__addObserver:forKeyPath:options:context:));
    _originalRemoveObserver = popAndReplaceImplementation(self, @selector(removeObserver:forKeyPath:), @selector(__EASY_KVO__removeObserver:forKeyPath:));
    _originalRemoveObserverWithContext = popAndReplaceImplementation(self, @selector(removeObserver:forKeyPath:context:), @selector(__EASY_KVO__removeObserver:forKeyPath:context:));
    _originalDealloc = popAndReplaceImplementation(self, NSSelectorFromString(@"dealloc"), @selector(__EASY_KVO__dealloc));
}

- (KVOProxy *)kvoProxy
{
    KVOProxy *kvoProxy = objc_getAssociatedObject(self, KVOProxyKey);
    if (!kvoProxy) {
        kvoProxy = [[KVOProxy alloc] initWithDelegate:self];
        objc_setAssociatedObject(self, KVOProxyKey, kvoProxy, OBJC_ASSOCIATION_RETAIN);
    }
    
    return kvoProxy;
}

- (void)__EASY_KVO__removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
    if (self.removeWithContextInProgress) {
        observer = ((KVOProxy*)observer).delegate;
    }

    ((void(*)(id, SEL, NSObject *, NSString *))_originalRemoveObserver)(self, @selector(removeObserver:forKeyPath:), observer.kvoProxy, keyPath);
    KVOContext *aContext = [[KVOContext alloc] initWithObservee:self observer:observer keyPath:keyPath context:nil callback:nil];
    NSUInteger observeeContextIndex = [aContext.observee.kvoProxy._mutableContexts indexOfObject:aContext];
    if (observeeContextIndex != NSNotFound) {
        [aContext.observee.kvoProxy._mutableContexts removeObjectAtIndex:observeeContextIndex];
    }
    NSUInteger observerContextIndex = [aContext.observer.kvoProxy._mutableContexts indexOfObject:aContext];
    if (observerContextIndex != NSNotFound) {
        [aContext.observer.kvoProxy._mutableContexts removeObjectAtIndex:observerContextIndex];
    }
    __RELEASE_IF_NO_ARC(aContext);
}

- (void)__EASY_KVO__removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
    if (!context) {
        [self __EASY_KVO__removeObserver:observer forKeyPath:keyPath];
        return;
    }

    self.removeWithContextInProgress = YES;
    ((void(*)(id, SEL, NSObject *, NSString *, void *))_originalRemoveObserverWithContext)(self, @selector(removeObserver:forKeyPath:context:), observer.kvoProxy, keyPath, context);
    KVOContext *aContext = [[KVOContext alloc] initWithObservee:self observer:observer keyPath:keyPath context:context callback:nil];
    NSUInteger observeeContextIndex = [aContext.observee.kvoProxy._mutableContexts indexOfObject:aContext];
    if (observeeContextIndex != NSNotFound) {
        [aContext.observee.kvoProxy._mutableContexts removeObjectAtIndex:observeeContextIndex];
    }
    NSUInteger observerContextIndex = [aContext.observer.kvoProxy._mutableContexts indexOfObject:aContext];
    if (observerContextIndex != NSNotFound) {
        [aContext.observer.kvoProxy._mutableContexts removeObjectAtIndex:observerContextIndex];
    }

    __RELEASE_IF_NO_ARC(aContext);
    self.removeWithContextInProgress = NO;
}

- (void)__EASY_KVO__addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    [self addObserver:observer forKeyPath:keyPath options:options context:context genericCallback:nil];
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context observerCallback:(OBserverCallback)callback
{
    [self addObserver:observer forKeyPath:keyPath options:options context:context genericCallback:callback];
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath observerCallback:(OBserverCallback)callback
{
    [self addObserver:observer forKeyPath:keyPath options:0 context:nil observerCallback:callback];
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context KVOCallback:(KVOCallback)callback
{
    [self addObserver:observer forKeyPath:keyPath options:options context:context genericCallback:callback];
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context genericCallback:(id)genericCallback
{
    ((void(*)(id, SEL, NSObject *, NSString *, NSKeyValueObservingOptions, void *))_originalAddObserver)(self, @selector(addObserver:forKeyPath:options:context:), observer.kvoProxy, keyPath, options, context);
    KVOContext *newContext = [[KVOContext alloc] initWithObservee:self observer:observer keyPath:keyPath context:context callback:genericCallback];
    [newContext.observee.kvoProxy._mutableContexts addObject:newContext];
    [newContext.observer.kvoProxy._mutableContexts addObject:newContext];
    __RELEASE_IF_NO_ARC(newContext);
}

- (void)__EASY_KVO__dealloc
{
    id removeInProgressWithContextProperty = objc_getAssociatedObject(self, RemoveInProgressWithContextKey);
    if (removeInProgressWithContextProperty) {
        objc_setAssociatedObject(self, RemoveInProgressWithContextKey, nil, OBJC_ASSOCIATION_RETAIN);
        __RELEASE_IF_NO_ARC(removeInProgressWithContextProperty);
    }
    
    KVOProxy *kvoProxy = objc_getAssociatedObject(self, KVOProxyKey);
    if (kvoProxy) {
        [kvoProxy unbindAllContexts];
        objc_setAssociatedObject(self, KVOProxyKey, nil, OBJC_ASSOCIATION_RETAIN);
        __RELEASE_IF_NO_ARC(kvoProxy);
    }

    ((void(*)(id, SEL))_originalDealloc)(self, NSSelectorFromString(@"dealloc"));
}


@end
