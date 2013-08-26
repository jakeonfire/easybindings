easybindings
=======

Category over `NSObject` that adds one-way data-binding via KVO; built on top of easyKVO, which "provides automatic removal of KVO observers and broadcasters when objects go out of scope as well as KVO-triggered callbacks for observers." https://github.com/saldavonschwartz/easyKVO

Features
========

- Bind the property of one object to the key-value observable property of another, optionally with an NSValueTransformer, so that the bound property automatically reflects changes to the observed property. Unlike bind:toObject:withKeyPath:options: in Cocoa's NSKeyValueBindingCreation protocol:
  - it automatically unbinds when either observer or observable goes out of scope (thanks to easyKVO)
  - it works with Cocoa Touch
  - the binding is one-way (only the binding object gets updates)

Installation
============

easykVO is included as a submodule. Make sure to update it via: git submodule update
or if you add easybindings as a submodule to your own project and want to update easyKVO as well: git submodule update --init --recursive

Usage
=====

Property Binding:
---------------------
Called from the object whose property should be updated. The bound key path is updated immediately when this method is called, as well as whenever the value of the observed key path changes.
```objc
[observer bind:@"boundKeyPath" toObject:observable withKeyPath:@"observedKeyPath"];
```
It optionally takes an NSValueTransformer which transforms the value before it is set on the observer.
```objc
[observer bind:@"boundKeyPath" toObject:observable withKeyPath:@"observedKeyPath" valueTransformer:customNSValueTransformer];
```
Bindings can be removed with unbind. This will still remove bindings created with the NSKeyValueBindingCreation protocol in Cocoa as well.
```objc
[observer unbind:@"boundKeyPath"];
```
