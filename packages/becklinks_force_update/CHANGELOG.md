## 0.1.1 (2026-10-23)

- A runnable example, a description and topics that name force update, and links to the other Beck Links packages.
- Declares Android and iOS as the supported platforms. Other platforms are only told "ok", so pub.dev should not list them (or flag the web build as not WASM compatible because of `package_info_plus`).
- The constructors of `UpdateCache` and `MemoryUpdateCache` are documented. No behaviour change.

## 0.1.0

- First release: asks Beck Links for the minimum and latest app version and shows a required or optional update; works on its own.
