// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_videos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Async provider for loading profile videos

@ProviderFor(fetchProfileVideos)
const fetchProfileVideosProvider = FetchProfileVideosFamily._();

/// Async provider for loading profile videos

final class FetchProfileVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          FutureOr<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $FutureProvider<List<VideoEvent>> {
  /// Async provider for loading profile videos
  const FetchProfileVideosProvider._({
    required FetchProfileVideosFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fetchProfileVideosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fetchProfileVideosHash();

  @override
  String toString() {
    return r'fetchProfileVideosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return fetchProfileVideos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FetchProfileVideosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fetchProfileVideosHash() =>
    r'6e79d18a77785f9e1615f0059270df51c405ee2d';

/// Async provider for loading profile videos

final class FetchProfileVideosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VideoEvent>>, String> {
  const FetchProfileVideosFamily._()
    : super(
        retry: null,
        name: r'fetchProfileVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Async provider for loading profile videos

  FetchProfileVideosProvider call(String pubkey) =>
      FetchProfileVideosProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'fetchProfileVideosProvider';
}

/// Notifier for managing profile videos state

@ProviderFor(ProfileVideosNotifier)
const profileVideosProvider = ProfileVideosNotifierProvider._();

/// Notifier for managing profile videos state
final class ProfileVideosNotifierProvider
    extends $NotifierProvider<ProfileVideosNotifier, ProfileVideosState> {
  /// Notifier for managing profile videos state
  const ProfileVideosNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileVideosProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileVideosNotifierHash();

  @$internal
  @override
  ProfileVideosNotifier create() => ProfileVideosNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileVideosState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileVideosState>(value),
    );
  }
}

String _$profileVideosNotifierHash() =>
    r'9b2d8e428b1a69004266bf9a97c799b8a0945b91';

/// Notifier for managing profile videos state

abstract class _$ProfileVideosNotifier extends $Notifier<ProfileVideosState> {
  ProfileVideosState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ProfileVideosState, ProfileVideosState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProfileVideosState, ProfileVideosState>,
              ProfileVideosState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
