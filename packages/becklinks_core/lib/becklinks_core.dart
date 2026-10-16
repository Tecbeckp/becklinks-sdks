/// The shared base of the Beck Links Flutter packages: API key checks, the network client with
/// retries, one exception type and a small logger.
///
/// Apps normally use a feature package (for example `becklinks_force_update`), which depends on
/// this one; it is published separately so those packages can be installed on their own.
library;

export 'src/api_client.dart' show BeckLinksApiClient, productionApiUrl;
export 'src/api_key.dart' show isTestKey, validatePublishableKey;
export 'src/exception.dart' show BeckLinksErrorCode, BeckLinksException;
export 'src/logger.dart' show BeckLinksLogger, LogLevel;
