import 'package:flutter/foundation.dart';

const revenueCatAppleApiKey = 'appl_bjXUADQLZnVvXNZNmcjxNxSDmeH';
const revenueCatGoogleApiKey = 'goog_BYuGTnkRIPEDaDKQUKihOECjDKK';
const revenueCatEntitlementId = 'premium';

/// Android builds sell through Google Play; everything else through the App Store.
bool get isPlayStore => defaultTargetPlatform == TargetPlatform.android;

String get revenueCatApiKey =>
    isPlayStore ? revenueCatGoogleApiKey : revenueCatAppleApiKey;

/// Where a member cancels, as it reads in the paywall's renewal terms.
String get storeCancelTerms => isPlayStore
    ? 'Cancel anytime in Google Play before renewal.'
    : 'Cancel anytime in Settings at least 24 hours before renewal.';

String get storeTermsUrl => isPlayStore
    ? 'https://play.google.com/about/play-terms/'
    : 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
