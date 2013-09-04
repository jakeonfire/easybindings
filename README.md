easybindings
=======

Category over `NSObject` that adds one-way data-binding via KVO

Requirements
========

Cocoa Touch project

Features
========

- Bind the property of one object to the key-value observable property of another, optionally with an NSValueTransformer, so that the bound property automatically reflects changes to the observed property. Unlike bind:toObject:withKeyPath:options: in Cocoa's NSKeyValueBindingCreation protocol:
  - it works with Cocoa Touch
  - the binding is one-way (only the binding object gets updates)

Usage
=====

Property Binding:
---------------------
Called from the object whose property should be updated. The bound key path is updated immediately when this method is called, as well as whenever the value of the observed key path changes. If the same observer.keypath is bound twice, the first binding is unbound automatically.
```objc
[observer bind:@"boundKeyPath" toObject:observable withKeyPath:@"observedKeyPath"];
```
It optionally takes an NSValueTransformer which transforms the value before it is set on the observer.
```objc
[observer bind:@"boundKeyPath" toObject:observable withKeyPath:@"observedKeyPath" valueTransformer:customNSValueTransformer];
```
Bindings can be removed with unbind. The bindings must be unbound if either end of the binding goes out of scope, as they utilize KVO under the hood.
```objc
[observer unbind:@"boundKeyPath"];
```
To retrieve the description for a binding or check if a binding exists:
```objc
[observer infoForBinding:@"boundKeyPath"];
```
