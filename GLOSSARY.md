# MQTT transport benchmark

Benchmark that compares MQTT over TCP + TLS 1.3 with MQTT over QUIC at scale, using containers. The broker, the client and the workload are the same for both; only the transport changes.

## Language

**Transport**:
The layer carrying MQTT between client and broker. Exactly two are compared: TCP + TLS 1.3, and QUIC.
_Avoid_: Protocol, channel, stack

**Scale**:
The number of concurrent MQTT connections held on the single broker node during a measurement.
_Avoid_: Load, size, number of devices

**Scenario**:
One combination of transport, network profile and scale.
_Avoid_: Case, experiment, configuration

**Run**:
One execution of a scenario: a connection storm followed by 60 s of steady-state publishing, against a freshly started broker.
_Avoid_: Trial, test, iteration

**Publisher**:
One MQTT client connection that publishes to its own topic. Publishers are what Scale counts.
_Avoid_: Device, node, sender

**Subscriber**:
The single MQTT client that receives every publisher message and measures end-to-end latency. It is not counted in Scale and sits on a link with no impairment.
_Avoid_: Consumer, receiver

**Repetition**:
The n-th run of the same scenario. There are 5 per scenario, one per night.
_Avoid_: Replicate, trial

**Network profile**:
A named set of `tc netem` parameters (delay, jitter, loss, rate) describing one direction of a publisher's link, applied at both ends of that link. The rate is per publisher. `lan` is the profile with no impairment.
_Avoid_: Scenario, condition, preset
