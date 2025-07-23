// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_visibility_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$videoVisibilityStreamHash() =>
    r'4a8546c63546facfd77fe7b1dc002c6e68ad3c73';

/// Stream provider for visibility changes
///
/// Copied from [videoVisibilityStream].
@ProviderFor(videoVisibilityStream)
final videoVisibilityStreamProvider =
    AutoDisposeStreamProvider<VideoVisibilityInfo>.internal(
  videoVisibilityStream,
  name: r'videoVisibilityStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoVisibilityStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VideoVisibilityStreamRef
    = AutoDisposeStreamProviderRef<VideoVisibilityInfo>;
String _$playableVideosHash() => r'6cd99ce0ebb9c228fb47988345384ea94c0090ef';

/// Convenience providers
///
/// Copied from [playableVideos].
@ProviderFor(playableVideos)
final playableVideosProvider = AutoDisposeProvider<Set<String>>.internal(
  playableVideos,
  name: r'playableVideosProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$playableVideosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlayableVideosRef = AutoDisposeProviderRef<Set<String>>;
String _$isVideoPlayableHash() => r'cdf433b39de30f002f4c9fed43eb947a5849f9ba';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [isVideoPlayable].
@ProviderFor(isVideoPlayable)
const isVideoPlayableProvider = IsVideoPlayableFamily();

/// See also [isVideoPlayable].
class IsVideoPlayableFamily extends Family<bool> {
  /// See also [isVideoPlayable].
  const IsVideoPlayableFamily();

  /// See also [isVideoPlayable].
  IsVideoPlayableProvider call(
    String videoId,
  ) {
    return IsVideoPlayableProvider(
      videoId,
    );
  }

  @override
  IsVideoPlayableProvider getProviderOverride(
    covariant IsVideoPlayableProvider provider,
  ) {
    return call(
      provider.videoId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'isVideoPlayableProvider';
}

/// See also [isVideoPlayable].
class IsVideoPlayableProvider extends AutoDisposeProvider<bool> {
  /// See also [isVideoPlayable].
  IsVideoPlayableProvider(
    String videoId,
  ) : this._internal(
          (ref) => isVideoPlayable(
            ref as IsVideoPlayableRef,
            videoId,
          ),
          from: isVideoPlayableProvider,
          name: r'isVideoPlayableProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$isVideoPlayableHash,
          dependencies: IsVideoPlayableFamily._dependencies,
          allTransitiveDependencies:
              IsVideoPlayableFamily._allTransitiveDependencies,
          videoId: videoId,
        );

  IsVideoPlayableProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.videoId,
  }) : super.internal();

  final String videoId;

  @override
  Override overrideWith(
    bool Function(IsVideoPlayableRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IsVideoPlayableProvider._internal(
        (ref) => create(ref as IsVideoPlayableRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        videoId: videoId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<bool> createElement() {
    return _IsVideoPlayableProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IsVideoPlayableProvider && other.videoId == videoId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, videoId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IsVideoPlayableRef on AutoDisposeProviderRef<bool> {
  /// The parameter `videoId` of this provider.
  String get videoId;
}

class _IsVideoPlayableProviderElement extends AutoDisposeProviderElement<bool>
    with IsVideoPlayableRef {
  _IsVideoPlayableProviderElement(super.provider);

  @override
  String get videoId => (origin as IsVideoPlayableProvider).videoId;
}

String _$isAutoPlayEnabledHash() => r'e5e148350672ecc9c2d4377c7d5abe7ae47c1d67';

/// See also [isAutoPlayEnabled].
@ProviderFor(isAutoPlayEnabled)
final isAutoPlayEnabledProvider = AutoDisposeProvider<bool>.internal(
  isAutoPlayEnabled,
  name: r'isAutoPlayEnabledProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isAutoPlayEnabledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsAutoPlayEnabledRef = AutoDisposeProviderRef<bool>;
String _$activelyPlayingVideoHash() =>
    r'a1830f0523906ae50deddea90a4dd875c57f0d5a';

/// See also [activelyPlayingVideo].
@ProviderFor(activelyPlayingVideo)
final activelyPlayingVideoProvider = AutoDisposeProvider<String?>.internal(
  activelyPlayingVideo,
  name: r'activelyPlayingVideoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activelyPlayingVideoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActivelyPlayingVideoRef = AutoDisposeProviderRef<String?>;
String _$videoVisibilityNotifierHash() =>
    r'badd06927ff5f34ba47213dc8394eb7aa0fb608f';

/// Main video visibility provider
///
/// Copied from [VideoVisibilityNotifier].
@ProviderFor(VideoVisibilityNotifier)
final videoVisibilityNotifierProvider = AutoDisposeNotifierProvider<
    VideoVisibilityNotifier, VideoVisibilityState>.internal(
  VideoVisibilityNotifier.new,
  name: r'videoVisibilityNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$videoVisibilityNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VideoVisibilityNotifier = AutoDisposeNotifier<VideoVisibilityState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
