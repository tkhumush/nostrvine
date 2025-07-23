// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_status_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectionStatusStreamHash() =>
    r'21e631f6f2bf465f592a0cf2129689b5174b30a7';

/// Stream provider for connection changes
///
/// Copied from [connectionStatusStream].
@ProviderFor(connectionStatusStream)
final connectionStatusStreamProvider =
    AutoDisposeStreamProvider<ConnectionStatus>.internal(
  connectionStatusStream,
  name: r'connectionStatusStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectionStatusStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectionStatusStreamRef
    = AutoDisposeStreamProviderRef<ConnectionStatus>;
String _$isOnlineHash() => r'e7e781b347b14bc428b98cff887c929c2e060592';

/// Convenience providers
///
/// Copied from [isOnline].
@ProviderFor(isOnline)
final isOnlineProvider = AutoDisposeProvider<bool>.internal(
  isOnline,
  name: r'isOnlineProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isOnlineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsOnlineRef = AutoDisposeProviderRef<bool>;
String _$hasInternetAccessHash() => r'03afa8986ba3f77babc9f9b2353905b56c2b2405';

/// See also [hasInternetAccess].
@ProviderFor(hasInternetAccess)
final hasInternetAccessProvider = AutoDisposeProvider<bool>.internal(
  hasInternetAccess,
  name: r'hasInternetAccessProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hasInternetAccessHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasInternetAccessRef = AutoDisposeProviderRef<bool>;
String _$connectionTypeHash() => r'4f9290f1bea4934fbddebda7d25f807fdb1fb1d6';

/// See also [connectionType].
@ProviderFor(connectionType)
final connectionTypeProvider = AutoDisposeProvider<String>.internal(
  connectionType,
  name: r'connectionTypeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectionTypeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectionTypeRef = AutoDisposeProviderRef<String>;
String _$connectionStatusNotifierHash() =>
    r'3646b959c50d4ebd2724ecb2693e6303bcddb4ac';

/// Main connection status provider
///
/// Copied from [ConnectionStatusNotifier].
@ProviderFor(ConnectionStatusNotifier)
final connectionStatusNotifierProvider = AutoDisposeNotifierProvider<
    ConnectionStatusNotifier, ConnectionStatus>.internal(
  ConnectionStatusNotifier.new,
  name: r'connectionStatusNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectionStatusNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ConnectionStatusNotifier = AutoDisposeNotifier<ConnectionStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
