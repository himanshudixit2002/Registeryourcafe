/// Mobile / desktop: verification links use the Firebase-hosted handler, not the
/// app URL; nothing to parse here.
Future<bool> consumeEmailActionCodeFromBrowserUrl() async => false;
