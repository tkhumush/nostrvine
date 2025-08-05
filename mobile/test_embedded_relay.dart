#!/usr/bin/env dart
// ABOUTME: Direct test script to debug embedded relay subscription forwarding
// ABOUTME: Tests whether the embedded relay properly forwards REQ messages to external relays

import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart' as embedded;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('\n=== EMBEDDED RELAY DIRECT TEST ===\n');
  
  // Initialize embedded relay
  print('1. Initializing embedded relay...');
  final embeddedRelay = embedded.EmbeddedNostrRelay();
  await embeddedRelay.initialize(
    enableGarbageCollection: true,
  );
  print('   ✅ Embedded relay initialized');
  
  // Add external relay
  print('\n2. Adding external relay...');
  const relayUrl = 'wss://relay3.openvine.co';
  await embeddedRelay.addExternalRelay(relayUrl);
  print('   ✅ Added relay: $relayUrl');
  
  // Check connection status
  print('\n3. Checking connection status...');
  final connectedRelays = embeddedRelay.connectedRelays;
  print('   Connected relays: $connectedRelays');
  
  if (!connectedRelays.contains(relayUrl)) {
    print('   ⚠️ WARNING: Not connected to $relayUrl yet');
    print('   Waiting 2 seconds for connection...');
    await Future.delayed(Duration(seconds: 2));
    final connectedRelaysAfter = embeddedRelay.connectedRelays;
    print('   Connected relays after wait: $connectedRelaysAfter');
  }
  
  // Test 1: Query with NO author filter (should work)
  print('\n4. Testing query with NO author filter...');
  final openFilter = embedded.Filter(
    kinds: [32222], // Video events
    limit: 5,
  );
  
  final openEvents = await embeddedRelay.queryEvents([openFilter]);
  print('   Received ${openEvents.length} events with open filter');
  
  if (openEvents.isNotEmpty) {
    print('   ✅ Open filter works - relay is responding');
    print('   First event author: ${openEvents.first.pubkey.substring(0, 8)}...');
  } else {
    print('   ❌ No events received with open filter');
  }
  
  // Test 2: Query with specific author filter
  print('\n5. Testing query with specific author filter...');
  
  // Use authors we know have videos from the logs
  final knownAuthors = [
    '377d059b8e4154c95e45c951b5b2b1b15d6f11c17e59e6a7b1c70ba7f3f7e079', // ＊emi＊
    '46322367c46f0fd68e587c8b3f0a967bb3e0c97a6b96c48ae40be08a78c73b64', // 일곱숨결7ᴴᴱᴬᴿᵀ
  ];
  
  final authorFilter = embedded.Filter(
    kinds: [32222],
    authors: knownAuthors,
    limit: 10,
  );
  
  final authorEvents = await embeddedRelay.queryEvents([authorFilter]);
  print('   Received ${authorEvents.length} events with author filter');
  
  if (authorEvents.isNotEmpty) {
    print('   ✅ Author filter works');
    for (var i = 0; i < authorEvents.length && i < 3; i++) {
      print('   Event $i: author=${authorEvents[i].pubkey.substring(0, 8)}...');
    }
  } else {
    print('   ❌ No events received with author filter');
  }
  
  // Test 3: Create a subscription and see if it gets events
  print('\n6. Testing subscription (REQ message)...');
  
  final subscriptionId = 'test_sub_${DateTime.now().millisecondsSinceEpoch}';
  var receivedCount = 0;
  final completer = Completer<void>();
  
  print('   Creating subscription with ID: $subscriptionId');
  
  final subscription = embeddedRelay.subscribe(
    subscriptionId: subscriptionId,
    filters: [
      embedded.Filter(
        kinds: [32222],
        limit: 5,
      )
    ],
    onEvent: (event) {
      receivedCount++;
      print('   📨 Received event ${receivedCount}: kind=${event.kind}, author=${event.pubkey.substring(0, 8)}...');
      if (receivedCount >= 3 && !completer.isCompleted) {
        completer.complete();
      }
    },
    onError: (error) {
      print('   ❌ Subscription error: $error');
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    },
  );
  
  // Wait for events with timeout
  try {
    await completer.future.timeout(Duration(seconds: 5));
    print('   ✅ Subscription received $receivedCount events');
  } catch (e) {
    if (e is TimeoutException) {
      print('   ⏱️ Timeout after 5 seconds - received $receivedCount events');
    } else {
      print('   ❌ Error: $e');
    }
  }
  
  subscription.close();
  
  // Test 4: Test with the actual followed users
  print('\n7. Testing with actual followed users from home feed...');
  
  final followedUsers = [
    '2646f4c01362b3b48d4b4e31d9c96a4eabe06c4eb97fe1a482ef651f1bf023b7',
    '2d85b149e9eb1b56720b7123e303ead76e4d7cc3aa24073c5b909ae89aaabe38',
    '1f90a3fdecb318d01a150e0e6980de03359659895e94669ba2a0c889d531d879',
    '4a88417a9502445bbdae41c2e7fc9289dd1e8c5cbcc8e6c2a2e2f5f38b5ac5f4',
    'f3c4705c2539f244b35df1f8e5c76c5e1dee0f68f07eee7bc959177f604b16bd',
    'e47336b1b91a97dd2c88e4c2f6d9d396837c96577f3e69f84b5fc088f06faaef',
    'cb1e36bb7f690c92b8aac951c7fd1c5ad90e8c45e037c8c37a951e39cfbcb9a7',
    '4f62e079b8e44cffe1173ea87e90e604c8c92e5e93e7c616e3e9fff10f98e23a',
    '032a9cf96e1965f3f96a13bb6e8f4c6b5a1c7e17c973d6e3bc674cc91bbf4f69',
  ];
  
  final followedFilter = embedded.Filter(
    kinds: [32222],
    authors: followedUsers,
    limit: 50,
  );
  
  print('   Querying for videos from ${followedUsers.length} followed users...');
  final followedEvents = await embeddedRelay.queryEvents([followedFilter]);
  print('   Received ${followedEvents.length} events from followed users');
  
  if (followedEvents.isEmpty) {
    print('   ❌ No videos found from followed users');
    print('   This confirms the issue - these users should have videos!');
  } else {
    print('   ✅ Found videos from followed users');
    // Group by author
    final eventsByAuthor = <String, int>{};
    for (final event in followedEvents) {
      eventsByAuthor[event.pubkey] = (eventsByAuthor[event.pubkey] ?? 0) + 1;
    }
    print('   Videos per author:');
    eventsByAuthor.forEach((pubkey, count) {
      print('     ${pubkey.substring(0, 8)}...: $count videos');
    });
  }
  
  // Clean up
  print('\n8. Shutting down...');
  await embeddedRelay.shutdown();
  print('   ✅ Embedded relay shut down');
  
  print('\n=== TEST COMPLETE ===\n');
  
  // Summary
  print('SUMMARY:');
  print('- Open query (no filter): ${openEvents.length} events');
  print('- Known authors query: ${authorEvents.length} events');
  print('- Subscription received: $receivedCount events');
  print('- Followed users query: ${followedEvents.length} events');
  
  if (followedEvents.isEmpty && openEvents.isNotEmpty) {
    print('\n❌ PROBLEM CONFIRMED: Embedded relay works but fails with specific author filters!');
    print('This suggests the issue is either:');
    print('1. The followed users have no videos on the relay');
    print('2. There\'s a bug in author filtering in the embedded relay');
    print('3. The relay is not properly querying external relays with author filters');
  }
  
  exit(0);
}