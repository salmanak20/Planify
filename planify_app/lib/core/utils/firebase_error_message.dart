import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

const _networkErrorMessage = 'Network Error. Check you internet connection';

String planifyFirebaseErrorMessage(Object error) {
  if (error is TimeoutException) {
    return _networkErrorMessage;
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Firebase rejected this action. Check your sign-in session and Firestore rules.',
      'unavailable' => _networkErrorMessage,
      'unauthenticated' => 'Please sign in again to continue.',
      'not-found' => 'This item was not found in Firebase.',
      'already-exists' => 'This item already exists.',
      'deadline-exceeded' => _networkErrorMessage,
      _ => error.message?.isNotEmpty == true
          ? error.message!
          : 'Firebase could not complete the request.',
    };
  }

  final message = error.toString().toLowerCase();
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('connection') ||
      message.contains('timed out') ||
      message.contains('unavailable')) {
    return _networkErrorMessage;
  }

  return error.toString();
}
