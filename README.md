# triplebuffer-odin

Triple buffer implementation in [Odin](https://odin-lang.org/).

## About

Triple buffering is a technique for safely sharing data between a single producer and a single consumer, and is a specific case of [multiple buffering](https://en.wikipedia.org/wiki/Multiple_buffering).

It is ideal for situations where the producer and consumer need to run at different rates but still in a time-sensitive fashion  (i.e. "real time"), and where the consumer does not care about receiving every single version of data that the producer produces - it only wants whatever the latest is.

Double buffering is also a common technique but it relies on synchronising the producer/consumer in some way, for example the producer waits until the consumer has read the latest data, so could get blocked.

### Use cases

- Graphics rendering (fast producer) vs monitor refresh (slow consumer)
- Fast audio thread (e.g. filling a buffer with audio input from a soundcard at 100Hz+) vs GUI thread (visualising the latest buffer or an transformed version of it, such as a spectogram, every 60Hz)
- Dealing with sensor data where the consumption rate might differ from the incoming rate, such as accelerometer data.

## Running the tests

1. Install/build the Odin compiler. See the Odin [Getting Started](https://odin-lang.org/docs/install/) guide for more info.
2. Run `make` to build the test runner in `out/testrunner` or `make test` to build and run. N.B. if you don't have Make on your system, you can just run the commands defined in the Makefile directly.

## How to use in your project

Copy `triplebuffer.odin`, or the contents of it, into your project. Do what you want with it!

See the multithreaded test in `tests/test_triplebuffer.odin` for example usage.

## Further reading

[Triple Buffering as a Concurrency Mechanism (II)](https://remis-thoughts.blogspot.com/2012/01/triple-buffering-as-concurrency_30.html) - Remi's Thoughts

