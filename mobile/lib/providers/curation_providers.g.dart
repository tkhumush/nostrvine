// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'curation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$analyticsApiServiceHash() =>
    r'bffbe1efb4b6d2a6172d4397e70d82b0312410e7';

/// Provider for analytics API service
///
/// Copied from [analyticsApiService].
@ProviderFor(analyticsApiService)
final analyticsApiServiceProvider =
    AutoDisposeProvider<AnalyticsApiService>.internal(
  analyticsApiService,
  name: r'analyticsApiServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$analyticsApiServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AnalyticsApiServiceRef = AutoDisposeProviderRef<AnalyticsApiService>;
String _$curationLoadingHash() => r'e1a04d9f8d90870d340665613c0938b356085039';

/// Provider to check if curation is loading
///
/// Copied from [curationLoading].
@ProviderFor(curationLoading)
final curationLoadingProvider = AutoDisposeProvider<bool>.internal(
  curationLoading,
  name: r'curationLoadingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$curationLoadingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurationLoadingRef = AutoDisposeProviderRef<bool>;
String _$editorsPicksHash() => r'47f6f4c73a8e2f6f8aafa718986c063feb530d08';

/// Provider to get editor's picks
///
/// Copied from [editorsPicks].
@ProviderFor(editorsPicks)
final editorsPicksProvider = AutoDisposeProvider<List<VideoEvent>>.internal(
  editorsPicks,
  name: r'editorsPicksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$editorsPicksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EditorsPicksRef = AutoDisposeProviderRef<List<VideoEvent>>;
String _$curationHash() => r'cc52c49a2b2eaab0bb1e846b8d850bc97632d8e7';

/// Main curation provider that manages curated content sets
///
/// Copied from [Curation].
@ProviderFor(Curation)
final curationProvider =
    AutoDisposeNotifierProvider<Curation, CurationState>.internal(
  Curation.new,
  name: r'curationProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$curationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Curation = AutoDisposeNotifier<CurationState>;
String _$analyticsTrendingHash() => r'33fdef5b2b5d2132b37636190d051e8420aefed1';

/// Provider for analytics-based trending videos
///
/// Copied from [AnalyticsTrending].
@ProviderFor(AnalyticsTrending)
final analyticsTrendingProvider =
    AutoDisposeNotifierProvider<AnalyticsTrending, List<VideoEvent>>.internal(
  AnalyticsTrending.new,
  name: r'analyticsTrendingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$analyticsTrendingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AnalyticsTrending = AutoDisposeNotifier<List<VideoEvent>>;
String _$analyticsPopularHash() => r'ced5475cd590efb845077badd27bb7b01a602ac3';

/// Provider for analytics-based popular videos
///
/// Copied from [AnalyticsPopular].
@ProviderFor(AnalyticsPopular)
final analyticsPopularProvider =
    AutoDisposeNotifierProvider<AnalyticsPopular, List<VideoEvent>>.internal(
  AnalyticsPopular.new,
  name: r'analyticsPopularProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$analyticsPopularHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AnalyticsPopular = AutoDisposeNotifier<List<VideoEvent>>;
String _$trendingHashtagsHash() => r'6798c272e87bb8733a4f1729132ba7e5a54c656a';

/// Provider for trending hashtags
///
/// Copied from [TrendingHashtags].
@ProviderFor(TrendingHashtags)
final trendingHashtagsProvider = AutoDisposeAsyncNotifierProvider<
    TrendingHashtags, List<TrendingHashtag>>.internal(
  TrendingHashtags.new,
  name: r'trendingHashtagsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$trendingHashtagsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TrendingHashtags = AutoDisposeAsyncNotifier<List<TrendingHashtag>>;
String _$topCreatorsHash() => r'5e191a9d9edb8c77a2c36ccc5046e801c64e56e8';

/// Provider for top creators
///
/// Copied from [TopCreators].
@ProviderFor(TopCreators)
final topCreatorsProvider =
    AutoDisposeAsyncNotifierProvider<TopCreators, List<TopCreator>>.internal(
  TopCreators.new,
  name: r'topCreatorsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$topCreatorsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TopCreators = AutoDisposeAsyncNotifier<List<TopCreator>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
