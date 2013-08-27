
//
//  NSObject+__EASY_KVO__.h
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


typedef void(^KVOCallback)(NSString *keyPath, __unsafe_unretained NSObject *object, NSDictionary *change, void* context);
typedef void(^OBserverCallback)(__unsafe_unretained id oberservee);

//------------------------------------------------------------------------------------------------------------------------------------------

@interface KVOContext : NSObject

typedef enum {
    KVOContextCallbackTypeNone, 
    KVOContextCallbackTypeKVO,
    KVOContextCallbackTypeObserver
} KVOContextCallbackType;

@property (nonatomic, assign, readonly)NSObject *observee;
@property (nonatomic, assign, readonly)NSObject *observer;
@property (nonatomic, strong, readonly)NSString *keyPath;
@property (nonatomic, assign, readonly)void *context;
@property (nonatomic, copy, readonly)id callback;
@property (nonatomic, assign, readonly)KVOContextCallbackType callbackType;

@end


//------------------------------------------------------------------------------------------------------------------------------------------

@interface KVOProxy : NSObject

@property (nonatomic, strong, readonly)NSArray *contexts;

@end


//------------------------------------------------------------------------------------------------------------------------------------------

@interface NSObject (__EASY_KVO__)

@property (nonatomic, strong, readonly)KVOProxy *kvoProxy;

/*
 Use these methods if you want to write the handling of a KVO notification 'in-place' thru a callback,
 as opposed to inside -observeValueForKeyPath:ofObject:change:context:
*/

//  This callback is equivalent in signature to -observeValueForKeyPath:ofObject:change:context:
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context KVOCallback:(KVOCallback)callback;

//  This callback only provides access to the observee (the sender of the KVO notification whose keyPath changed)
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context observerCallback:(OBserverCallback)callback;

//  Shorter version of the above with defaults: options:0 context:nil
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath observerCallback:(OBserverCallback)callback;

@end
