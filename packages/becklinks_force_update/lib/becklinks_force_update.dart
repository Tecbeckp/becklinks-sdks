/// Force update for Flutter apps: ask Beck Links whether the running version is too old, offer or
/// require an update, and send people to the store.
///
/// Create one [BeckLinksForceUpdate] with the publishable key of your project and call `check()`,
/// or put a [ForceUpdateGate] above your app to get the screens too. It works on its own: no other
/// Beck Links package is needed.
library;

export 'package:becklinks_core/becklinks_core.dart'
    show BeckLinksErrorCode, BeckLinksException, LogLevel;

export 'src/force_update.dart' show BeckLinksForceUpdate;
export 'src/force_update_gate.dart' show ForceUpdateGate, ForceUpdateTexts;
export 'src/update_cache.dart'
    show MemoryUpdateCache, SharedPreferencesUpdateCache, UpdateCache;
export 'src/update_check_result.dart' show UpdateCheckResult, UpdateStatus;
