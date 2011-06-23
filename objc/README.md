Yet Another JSON Library, Objective-C Wrappers
==============================================

Lloyd Hilaiel has written a small, fast, portable JSON parser and generator in C. This sub-project adds very thin wrappers over the top using Objective-C, ideal for use on Apple platforms, iOS and OS X.

There are some key design goals for these wrappers:

1. Do not polute global namespace unnecessarily.

	The Objective-C wrappers _entirely_ wrap the C-language implementation. Objective-C clients never need to include the C headers. They never directly interface or even __see__ the C implementation, including the headers.

2. Stick to one-to-one mappings between classes and methods.

	The C library encapsulates classes. Not language-level classes because the C language does not support the concept of classes. But that does not mean that you cannot implement object-oriented decomposition using C. You can. And Lloyd does a good job of this.

	The wrappers do not attempt to add a different level of abstraction. Hence Lloyd's C APIs present a parser abstraction; therefore the Objective-C wrappers present a `YAJLParser` class. Lloyd provides a generator abstraction; you have `YAJLGenerator`!

Small Changes to YAJL 2 Sources
-------------------------------

The wrappers require two small but important changes to Lloyd's work: The addition of two new APIs for accessing the parser and generator flags without breaking encapsulation.

API function `yajl_get_flags` gives access to a YAJL parser's flags without needing access to the underlying opaque handle type.

Similarly, for the generator, a new API function `yajl_gen_get_flags` answers a given generator's flags. Hence the wrappers can provide Objective-C property interfaces to the parser and generator options.

You could call these changes _improvements_. Perhaps Lloyd will one-day incorporate them within the standard C API for YAJL.

Merging Objective-C Wrappers With C Project
-------------------------------------------

The Objective-C components overlay the main "yajl" project as follows.

- `yajl/` (the project root)
	- `objc/` (Objective-C wrappers)
		- `YAJL/` (sources)
			- `YAJL.h`, framework's monolithic header
			- `YAJLParser.h` and `m`, YAJL parser wrapper
			- `YAJLGenerator.h` and `m`, YAJL generator wrapper
			- `YAJLErrorDomain.h` and `m`, YAJL error domain constant
		- `cocoa-touch-static-library/`
			- `YAJL.xcodeproj`, an Xcode project containing a Cocoa Touch static-library target for iOS platforms
		- `cocoa-framework/`
			- `YAJL.xcodeproj`, an Xcode project containing a Cocoa framework target for OS X platforms

Versioning
----------

The Cocoa Touch static library and Cocoa framework for YAJL both use Apple-generic versioning, which uses a double and an array of `char` to mark the version. This is incompatible with `yajl_version` which returns an `int` representing the version major, minor and micro sub-version numbers in multiples of 100; e.g. 10203 would represent version 1.2.3.

Currently, the Objective-C sub-project takes a simple approach: remove the `yajl_version` API!

