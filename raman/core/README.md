# Raman VPN core build

Raman VPN uses its own build of [hiddify-core](https://github.com/hiddify/hiddify-core)
(GNU GPL v3 with the Hiddify additional terms, see `LICENSE.md` of this repository and of
hiddify-core) instead of the released `hiddify-lib-android.tar.gz`, so that Shield can pass its own
Psiphon settings.

- `build-core.sh` clones hiddify-core at the tag of `dependencies.properties` (`core.version`),
  applies `raman/core-patches/<dir>/*.patch` and builds `hiddify-core.aar` with gomobile
  (arm, arm64, x86_64). The workflow `.github/workflows/raman-android.yml` (job `core`) runs it and
  the app build uses the result.
- `raman/core-patches/hiddify-sing-box/0001-psiphon-merge-parameters.patch` (changes to
  hiddify-sing-box, the sing-box fork inside hiddify-core):
  - new Psiphon outbound fields `protocol_mode` (`auto` / `direct` / `cdn` / `conduit`),
    `beast_mode`, `inproxy_compartment_id`, `unsafe_traffic_alerts` and `parameters` (any
    psiphon-tunnel-core config field);
  - they are **merged on top of** the resolved Psiphon config (with `"config": "hiddify"`, the one
    embedded at build time) instead of replacing it; the config's encrypted `AdditionalParameters`
    are opened first so the outbound's settings win;
  - Psiphon `ServerAlert` notices are logged as `psiphon server alert: reason=… subject=…`.
- With `INPROXY=true` (default) the core is built with psiphon-tunnel-core's tag
  `PSIPHON_ENABLE_INPROXY` and Psiphon's forks of pion dtls/ice/webrtc (from the same
  tunnel-core commit), which in-proxy (Conduit) needs.
- The built-in Psiphon config: by default the encrypted config and its key are taken unchanged
  from the official hiddify-core release of the same version (`extract_embedded.py`), so
  `"config": "hiddify"` behaves as in the official core. Repository secrets `HIDDIFY_SECRET_KEY`
  and `PSIPHON_CONFIG` replace it with a config of your own.

Field mapping (psiphon-tunnel-core config fields):

| outbound field | tunnel-core |
|---|---|
| `protocol_mode: direct` | `LimitTunnelProtocols` = SSH, OSSH, TLS-OSSH, UNFRONTED-MEEK-*, QUIC-OSSH, SHADOWSOCKS-OSSH, FRONTED-MEEK-*; `DisableTactics` |
| `protocol_mode: cdn` | `LimitTunnelProtocols` = FRONTED-MEEK-OSSH, FRONTED-MEEK-HTTP-OSSH, FRONTED-MEEK-QUIC-OSSH; `DisableTactics` |
| `protocol_mode: conduit` | `LimitTunnelProtocols` = INPROXY-WEBRTC-* (tactics stay on: they carry the broker specs) |
| `inproxy_compartment_id` (conduit only) | `InproxyClientPersonalCompartmentID` |
| `beast_mode` | `ConnectionWorkerPoolSize` 30, `EstablishTunnelServerAffinityGracePeriodMilliseconds` 0, `StaggerConnectionWorkersMilliseconds` 0 |
| `unsafe_traffic_alerts` | `ClientFeatures` ["unsafe-traffic-alerts"], `EmitServerAlerts` |
| `parameters` | any field, applied last |
