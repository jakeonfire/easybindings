easyKVO
=======

Category over `NSObject` that provides automatic removal of KVO observers and broadcasters when objects go out of scope
as well as KVO-triggered callbacks for observers.


Features
========

- No need to unregister KVO notifications when either observers or observees (not a real word, I know) go out of scope. Unregistration happens automatically and transparently (though you can still do it explicitly if you need to, on `-dealloc` or elsewhere).
- `NSObjects` have a kvoProxy property of type `KVOProxy`. Querying `kvoProxy.contexts` gives detailed information on KVO properties an object observes and is observed for.
- 3 ways of observing KVO properties: 
  - standard: inside `-observeValueForKeyPath:ofObject:change:context:`.
  - KVO-style callback: by passing in a block whose signature is equivalent to `-observeValueForKeyPath:ofObject:change:context:` on registration. 
  - streamlined callback: by passing in a block whose only parameter is the observee, from which to query the observed property.
- Compatible with manual or automatic reference counting.

Installation
============

Copy the category to your project and either include it in your prefix header for global scope or in whichever file you want.


Usage
=====

Standard Way:
-------------
Register your KVO as usual and handle the observation in the observer's -observeValueForKeyPath:ofObject:change:context:
```objc
[objectA addObserver:objectB forKeyPath:@"someKeyPath" options:<NSKeyValueObservingOptions> context:someContextOrNil];
```

KVO-style Callback:
-------------------
Pass in a callback for handling the observation. The callback's signature is equivalent to that of 
-observeValueForKeyPath:ofObject:change:context:
```objc
[objectA addObserver:objectB forKeyPath:@"someKeyPath" options:<NSKeyValueObservingOptions> context:someContextOrNil KVOCallback:^(NSString *keyPath, NSObject *__unsafe_unretained object, NSDictionary *change, void *context) {
    //  Do something, like NSLog(@"%@", change[NSKeyValueChangeNewKey]);
}];
```

Streamlined Callback:
---------------------
Pass in a callback for handling the observation. The callback's only parameter is the object whose property is being observed:
```objc
[objectA addObserver:objectB forKeyPath:@"someKeyPath" options:<NSKeyValueObservingOptions> context:someContextOrNil observerCallback:^(__unsafe_unretained id oberservee) {
    //  Do something, like NSLog(@"%@", objectA.someKeyPath);
}];
```

Regardless of the way objects are registered, if observers are not removed explictly, removal will happen automatically when either observers or observees go out of scope. 


Each object has a `KVOProxy` property, thru which a collection of `KVOContext` objects (one for each observation registered) can be queried for information about what properties an object is observing or being observed for.
Inspecting an object's `kvoProxy.contexts` property will display output similar to this:
```objc
0 = 0x0a9906e0 <__NSArrayM 0xa9906e0>(
<KVOContext: 0x8e597b0>(
  observee: <ObjectA: 0xa989420>
  observer: <ObjectB: 0xa97bba0>
  keypath: someKeyPath
  context: (null)
  callback: (null) | type = none
),
<KVOContext: 0xa990680>(
  observee: <ObjectA: 0xa989420>
  observer: <ObjectB: 0xa97bba0>
  keypath: someKeyPath
  context: (null)
  callback: <__NSGlobalBlock__: 0x8090> | type = Observer callback
),
<KVOContext: 0xa98ca10>(
  observee: <ObjectA: 0xa989420>
  observer: <ObjectB: 0xa97bba0>
  keypath: someKeyPath
  context: (null)
  callback: <__NSGlobalBlock__: 0x80b8> | type = KVO callback
)
)
```

The above context array is what KVO proxies for both `objectA` and `objectB` would contain after registering `objectB` as an observer of `objectA` in the 3 ways shown before.
Both objects contain the same contexts in their proxies, which implies that the way to tell if an object is an observer or observee for a particular observation context is by comparing it with the appropriate properties of a `KVOContext`.
