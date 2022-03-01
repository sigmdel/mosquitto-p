# Fork of [mosquitto-p](https://github.com/chainq/mosquitto-p) by chainq

Free Pascal conversions of the libmosquitto header file `mosquitto.h`,
as part of the Eclipse Mosquitto project, and some Pascal examples
and language integration.

This allows using the libmosquitto MQTT client library, part of the
Mosquitto MQTT Broker project from Free Pascal applications.

For the original sources, see:
https://github.com/eclipse/mosquitto

### Source Files

* `mosquitto.pas` - conversion of the C `mosquitto.h` header to Pascal,
                    provides the same API as the C version
* `mqttclass.pas` - Object Pascal wrapper class to ease the integration
                    of libmosquitto into Object Oriented applications
* `test.pas`      - Test code for the Pascal header unit with C-like API
* `testclass.pas` - Test code for the Object Pascal wrapper class

### mqttclass.pas

It is a fully featured Object Pascal class to handle MQTT connections via
libmosquitto. Apart from providing an OOP-style API, it maps the low-level
C types used by libmosquitto itself to higher level Pascal types. For
example, you can pass a `String` instead of a `PChar/char *` everywhere.
Thanks to Free Pascal's native threading features it can be fully
asynchronous and behave equally on all platforms. This feature also works
on Windows, without depending on pthreads on this platform, unlike
libmosquitto itself.

### Changes (2022-03-01 sigmdel)

#### Changes to `mosquitto.pas`
This fork adds dynamic loading of the `mosquitto` library in 
`mosquitto.pas` so that a Free Pascal program will not crash on startup when
the library is not installed. Enable this feature by adding the 
`DYNAMIC_MOSQLIB` define in the project options. Check that the library was 
loaded with the `mosquitto_lib_loaded()` function. That function always 
returns `True` when the library is statically linked and represents the only 
change to the original library when `DYNAMIC_MOSQLIB` is not defined.

There must be an easier way to trap an error when a statically 
linked library is not found or to test for the presence of the library
before it is loaded. Anyone?

#### Changes to `mqttclass.pas`

Added an additional initial test for `mosquitto_lib_loaded` when setting the 
`libinited` boolean in the `mqttclass initialization` procedure. That way the
`mosquitto_lib_init()` function will not be called if the `mosquitto`
library was not found and `mqtt_ini()` will return `false`. The 
`mosquitto_lib_loaded()` function can be used to distinguish between a problem
initializing the mosquitto library or its absence.

Added `UnSubscribe` functions in `TMQTTConnection`. These were suggested
by JacoFourie in issue #5: No Unsubscribe 2020-10-3.

In the spirit of the 2021-11-08 commit by Károly Balogh (chainq), two fields were 
added to the `TMQTTConfig` record:

  1. `client_id` a string.
  2. `retain_session` a boolean.
     
Both fields are passed on to `mosquitto_new` when a mosquitto client instance is
created in the `TMQTTConnection` constructor. Note that it is the logical inverse of 
`retain_session` 
which is passed on as `clean_session`. This is done because when the
`TMQTTConfig`  record is initially cleared, the added field `retain_session` will be
reset to `false` but the `clean_session` was always `true` in the original
version. 

See the [RomanIz](https://github.com/RomanIz/mosquitto-p) fork for a different 
approach.

#### Added test/demo application

The directory `test_multi` contains a Lazarus application which tests most
changes in `mqttclass.pas` and demonstrate how multiple MQTT clients can be
set up in a single application and how they use a common logging facility.

The program makes it easy to see what happens if two clients with the 
same `client_id` are connected to the same MQTT broker. In the test environment
with an older version of the mosquitto broker the second client could be 
connected, but the first client was then disconnected.

### License

The Eclipse Mosquitto project is licensed under the Eclipse Public License 1.0.

The contents of this repository (except for the content of the `test_multi` directory) are covered by the ISC License, see the `LICENSE` file for details.

The contents of the `test_multi` directory are covered by the [BSD Zero Clause License](https://spdx.org/licenses/0BSD.html).
