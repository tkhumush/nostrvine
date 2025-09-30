# OpenVine Embedded Relay Implementation Plan

## Overview

This plan details the complete replacement of OpenVine's external Nostr relay architecture with the flutter_embedded_nostr_relay package. Given that **OpenVine has no active users**, this is the perfect opportunity for aggressive architectural changes without user disruption.

## Strategic Context

### Why Embedded Relay?
- **Performance**: Sub-10ms query times vs 500-2000ms external relay latency
- **Offline-First**: Full video browsing without internet connection
- **Privacy**: External relays can't track user viewing patterns
- **P2P Capabilities**: Local video sharing via BLE/WiFi Direct with Negentropy sync
- **Reliability**: No dependency on external relay uptime

### CRITICAL IMPLEMENTATION PRINCIPLE
**ALWAYS DELETE CODE WE STOP USING** - Following CLAUDE.md guidelines:
- "Make the SMALLEST reasonable changes" = one clean architecture vs hybrid complexity
- "WORK HARD to reduce code duplication" = eliminate dual relay systems  
- "Don't add features we don't need right now" = no backward compatibility
- **DELETE everything external-relay related - no exceptions**

## Current vs Target Architecture

```
Current Architecture          Target Architecture
===================          ===================

  OpenVine App                   OpenVine App
       |                             |
       v                             v
  NostrService                  NostrService
       |                             |
       v                             v
  WebSocket Client     --->     WebSocket Client
       |                             |
       v                             v
  External Relays              localhost:7447
  (slow, unreliable)                 |
                                     v
                              Embedded Relay
                                     |
                                     v
                                SQLite DB
                                     |
                                     v
                                P2P Sync Layer
                               (BLE + WiFi Direct)
```

## Research Context

### flutter_embedded_nostr_relay Package Capabilities
Based on our research of the package documentation:

- **Cross-Platform**: iOS, Android, macOS, Windows, Linux, Web support
- **WebSocket Server**: Runs on localhost:7447 (mobile/desktop), direct API on Web  
- **SQLite Storage**: Optimized event storage with proper indexing
- **Negentropy P2P Sync**: Bandwidth-efficient set reconciliation protocol
- **Video Optimizations**: Special handling for kind:32222 video events
- **Performance**: <10ms query times, handles 100k+ events efficiently

### OpenVine-Specific Optimizations Available
From `open-vine-optimizations.md`:

- **Metadata-First Loading**: Video metadata loads instantly, actual video files via CDN
- **Social Graph Optimization**: Pre-fetch videos from followed creators
- **Bandwidth-Aware Sync**: Full sync on WiFi, metadata-only on cellular/BLE
- **Intelligent Pre-caching**: Video feed preloading for smooth scrolling
- **Creator-Centric Relay Lists**: Optimize for where video creators actually post
- **Video Event Priorities**: Kind:32222 events get highest priority

### Negentropy Protocol Benefits
From `why-ngentropy.md`:

- **Bandwidth Efficient**: Only exchanges differences, not entire datasets
- **XOR-based Fingerprints**: Perfect for Nostr's immutable event model
- **Resumable Sync**: Handles intermittent BLE/WiFi connections gracefully
- **Logarithmic Scaling**: Efficient even with 100k+ events

## Implementation Plan

### Phase 1: Rapid Demolition (Days 1-2)

#### 1.1 Nuclear Option - Delete External Relay Infrastructure
**CRITICAL: DELETE ALL OF THIS CODE - NO PRESERVATION**

- [ ] **Delete entire WebSocket client for external relays**
  - Remove WebSocket connection pools and managers
  - Delete relay URL configuration systems
  - Remove connection retry/failover logic
- [ ] **Delete NostrService external relay logic**
  - Remove external relay subscription management
  - Delete relay selection and switching code
  - Remove external relay error handling
- [ ] **Clean out relay-related configuration**
  - Delete relay URL settings and preferences
  - Remove relay performance tracking
  - Delete relay metadata and capabilities code
- [ ] **Delete cached event storage systems**
  - Remove old event cache implementations
  - Delete relay-specific event storage
  - Clean up event deduplication across relays

#### 1.2 Add flutter_embedded_nostr_relay Dependency
- [ ] Add `flutter_embedded_nostr_relay: ^0.1.0` to pubspec.yaml
- [ ] Test basic package import and initialization
- [ ] Verify cross-platform compilation (iOS, Android, Web, Desktop)
- [ ] Review any platform-specific setup requirements

#### 1.3 Replace NostrService Core Architecture
- [ ] **Rewrite NostrService as localhost-only WebSocket client**
  - Connect to localhost:7447 embedded relay
  - Remove ALL external relay complexity
  - Keep same public API for VideoEventService compatibility
- [ ] **Initialize embedded relay on app startup**
  - Configure with OpenVine video-optimized settings
  - Set up SQLite database with proper schema
  - Enable P2P sync transports (BLE, WiFi Direct)

### Phase 2: Core Embedded Relay Implementation (Days 3-5)

#### 2.1 Configure OpenVine-Optimized Embedded Relay
```dart
// Implementation based on open-vine-optimizations.md
final config = EmbeddedRelayConfig(
  // Video-optimized event limits
  maxEventsPerKind: {
    32222: 50000,  // Video metadata (primary content)
    0: 10000,      // Creator profiles  
    7: 100000,     // Reactions (small, important for engagement)
    1: 50000,      // Comments
    6: 20000,      // Reposts
    3: 5000,       // Follow lists
  },
  
  // Aggressive caching for video content
  cacheStrategy: CacheStrategy(
    alwaysCacheKinds: [32222, 0], // Videos and profiles
    creatorContentRetention: Duration(days: 90),
    prefetchStrategy: PrefetchStrategy.aggressive,
  ),
  
  // P2P sync optimized for video apps
  syncConfig: SyncConfig(
    defaultSyncWindow: Duration(days: 7),
    favoriteCreatorSyncWindow: Duration(days: 90),
    wifiSyncStrategy: SyncStrategy.full,
    cellularSyncStrategy: SyncStrategy.metadataOnly,
    bluetoothSyncStrategy: SyncStrategy.metadataOnly,
  ),
);
```

#### 2.2 Rewrite VideoEventService Integration
- [ ] **Update VideoEventService to query embedded relay**
  - Replace external relay queries with localhost:7447 connections
  - Implement sub-10ms video feed loading from SQLite
  - Configure video-specific subscription filters
- [ ] **Remove external relay subscription management**
  - Delete subscription pooling across multiple relays
  - Remove relay-specific subscription tracking
  - Simplify to single embedded relay subscriptions

#### 2.3 Update Riverpod Providers for Local-First Operation
- [ ] **Modify homeFeedProvider**
  - Update to query embedded relay for followed creators' videos
  - Implement instant loading from local cache
  - Remove external relay dependency
- [ ] **Update videoEventsProvider** 
  - Configure for local-first discovery feed
  - Enable real-time updates from embedded relay
  - Test provider reactivity with local event streams
- [ ] **Ensure VideoManager integration remains functional**
  - Verify video preloading works with embedded relay
  - Test video controller management with local events
  - Validate memory management with local event storage

#### 2.4 Implement Direct Video Publishing Pipeline
- [ ] **Create embedded relay publishing**
  - Publish video events directly to local embedded relay
  - Configure immediate local availability for user's own content
  - Set up local event validation and storage
- [ ] **Set up external relay broadcasting for discoverability**
  - Publish to strategic external relays for network reach
  - Use creator-centric relay selection from package research
  - Implement video-specific relay prioritization
- [ ] **Remove old publishing infrastructure dependencies**
  - Delete external relay publishing pools
  - Remove relay-specific publishing logic
  - Clean up publishing retry/failover systems

### Phase 3: P2P Features & Optimization (Days 6-8)

#### 3.1 Enable P2P Video Sharing
- [ ] **Configure BLE transport for video metadata sync**
  - Set up Bluetooth permissions for iOS/Android
  - Implement BLE service discovery for nearby OpenVine users
  - Configure Negentropy sync over BLE with 512-byte MTU limits
- [ ] **Set up WiFi Direct for Android**
  - Enable WiFi Direct permissions and discovery
  - Implement TCP Negentropy sync for faster local sharing
  - Test video metadata sharing between Android devices
- [ ] **Test P2P sync scenarios**
  - Watch parties: Multiple users sync latest videos locally
  - Coffee shop discovery: Auto-sync with nearby OpenVine users
  - Offline sharing: Share cached videos when internet unavailable

#### 3.2 Implement Offline-First Video Browsing
- [ ] **Enable full offline video feed browsing**
  - Cache video metadata for offline viewing
  - Implement offline video feed scrolling and navigation
  - Show cached vs live content indicators
- [ ] **Smart preloading based on user patterns**
  - Pre-fetch videos from followed creators
  - Cache creator profiles and engagement data
  - Implement intelligent background sync scheduling
- [ ] **Background sync restoration**
  - Detect when internet connection restored
  - Sync new content in background without UI disruption
  - Update cached content with latest engagement data

#### 3.3 Video-Specific Performance Optimizations
- [ ] **Implement sub-10ms video feed queries**
  - Configure SQLite indexes for video metadata queries
  - Optimize creator-based video lookups
  - Test query performance with large video datasets
- [ ] **Add video engagement preloading**
  - Pre-fetch likes, comments, reposts for visible videos
  - Cache engagement data for smooth scrolling
  - Implement engagement data refresh strategies
- [ ] **Smart refresh for addressable video events**
  - Refresh recent videos (< 1 hour old) every 5 minutes
  - Refresh daily videos every hour
  - Refresh older videos every 24 hours
- [ ] **Memory optimization for large datasets**
  - Implement LRU caching for video metadata
  - Configure automatic cleanup of old cached content
  - Monitor memory usage with performance tracking

### Phase 4: Testing & Launch Preparation (Days 9-10)

#### 4.1 Comprehensive Testing
- [ ] **Performance benchmarking**
  - Test video feed load times: target <100ms vs current 500-2000ms
  - Benchmark query response times: target <10ms for common operations
  - Test memory usage with 10k+ cached video events
- [ ] **P2P functionality validation**
  - Test BLE sync between iOS/Android devices
  - Verify WiFi Direct sync on Android
  - Test Negentropy protocol efficiency with real video metadata
- [ ] **Offline capabilities testing**
  - Test full offline video browsing experience
  - Verify background sync when connection restored
  - Test offline/online content indicators
- [ ] **Feature regression testing**
  - Validate all existing video features work unchanged
  - Test video upload and publishing pipeline
  - Verify Riverpod provider reactivity

#### 4.2 Final Cleanup & Documentation
- [ ] **Delete ALL old external relay code files**
  - Remove WebSocket client files for external relays
  - Delete relay connection management classes
  - Remove relay configuration and settings code
  - Clean up relay-related utility functions
- [ ] **Remove unused dependencies**
  - Clean up pubspec.yaml external relay dependencies
  - Remove WebSocket packages if only used for external relays
  - Update dependency versions for embedded relay
- [ ] **Run mandatory flutter analyze**
  - Fix all analysis issues before completion
  - Ensure code quality meets standards
  - Remove any dead code warnings
- [ ] **Platform build verification**
  - Test builds on iOS, Android, Web, macOS
  - Verify platform-specific permissions work
  - Test embedded relay startup on all platforms

## Critical Success Factors

### 1. Ruthless Code Deletion
**NEVER preserve old external relay code "just in case"**
- Delete external relay WebSocket clients completely
- Remove all relay URL configuration systems  
- Delete connection pooling and failover logic
- Clean up relay-related UI and settings

### 2. Video-Optimized Configuration
Use OpenVine-specific embedded relay settings:
- Prioritize kind:32222 video events
- Aggressive caching for video metadata
- Creator-focused content retention
- Bandwidth-aware P2P sync strategies

### 3. Maintain Provider API Stability
Keep VideoEventService interface unchanged:
- homeFeedProvider continues working seamlessly
- videoEventsProvider maintains same behavior
- VideoManager integration remains functional
- UI components see no breaking changes

### 4. Enable ALL P2P Features Immediately
No gradual P2P rollout - enable everything:
- BLE sync for metadata sharing
- WiFi Direct for Android local sharing
- Negentropy protocol for efficiency
- Automatic peer discovery and sync

### 5. No Backward Compatibility
Clean slate approach with zero legacy support:
- No hybrid external/embedded relay systems
- No migration paths or compatibility layers
- No feature flags or gradual transitions
- Complete architectural replacement

## Expected Outcomes

### Performance Revolution
- **Video feed loading**: <100ms (vs current 500-2000ms)
- **Query response times**: <10ms from local SQLite
- **Memory efficiency**: <50MB for 10k cached events
- **P2P sync speed**: 1000 events in <5 seconds over BLE

### New Capabilities
- **Offline video browsing**: Full feed access without internet
- **P2P video sharing**: Automatic sharing when friends nearby
- **Privacy preservation**: External relays see minimal user data
- **Local-first experience**: Instant responses, always available

### Architecture Benefits
- **Simplified codebase**: Single embedded relay vs complex external management
- **Reduced dependencies**: Fewer external services and failure points
- **Better testing**: Local relay enables comprehensive testing
- **Future flexibility**: Foundation for advanced P2P features

## Risk Mitigation

### Zero User Disruption Risk
- No active users means zero disruption during implementation
- Can break existing functionality without consequences
- Perfect opportunity for aggressive architectural changes
- Extensive testing possible without user impact

### Technical Risk Management
- **Database corruption**: SQLite is battle-tested and reliable
- **Platform compatibility**: flutter_embedded_nostr_relay handles platform differences
- **Performance regression**: Embedded relay designed for <10ms responses
- **P2P sync issues**: Negentropy protocol is proven for efficient sync

### Implementation Risk Management
- **Breaking changes**: No users affected by breaking changes
- **Feature regression**: Comprehensive testing before any user onboarding
- **Code complexity**: Simpler architecture reduces complexity vs hybrid approach
- **Maintenance burden**: Less code to maintain after external relay deletion

## Next Steps

1. **Add flutter_embedded_nostr_relay dependency** to pubspec.yaml
2. **Identify all external relay code** for deletion
3. **Rewrite NostrService** to connect to localhost:7447
4. **Configure embedded relay** with OpenVine video optimizations
5. **Test basic video feed loading** to ensure provider compatibility

This aggressive complete replacement will transform OpenVine into a lightning-fast, offline-capable, P2P-enabled video platform that feels magical to use.