import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_exceptions.dart';
import '../models/door_event.dart';
import '../models/rfid_card.dart';
import '../repositories/device_repository.dart';
import '../repositories/rfid_repository.dart';

enum RfidRegistrationStep {
  idle,
  initiating,
  waitingForTap,
  cardDetected,
  success,
  alreadyRegistered,
  timeout,
  error,
}

class RfidProvider extends ChangeNotifier {
  final RfidRepository _rfidRepository;
  final DeviceRepository _deviceRepository;

  List<RfidCard> _cards = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Card Registration State
  RfidRegistrationStep _registrationStep = RfidRegistrationStep.idle;
  String? _registrationError;
  String? _newlyRegisteredUid;
  Timer? _pollingTimer;
  int _pollCount = 0;
  static const int _maxPollCycles = 60; // 60 * 1 sec = 60 seconds timeout

  RfidProvider(this._rfidRepository, this._deviceRepository);

  List<RfidCard> get cards => _cards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RfidRegistrationStep get registrationStep => _registrationStep;
  String? get registrationError => _registrationError;
  String? get newlyRegisteredUid => _newlyRegisteredUid;

  /// Loads all registered RFID cards from ESP32
  Future<void> loadCards() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final list = await _rfidRepository.getRegisteredCards();
      _cards = list;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Failed to load registered cards from ESP32.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets or updates a friendly nickname for an RFID card
  Future<void> updateCardLabel(String uid, String label) async {
    await _rfidRepository.setCardLabel(uid, label);
    final index = _cards.indexWhere((c) => c.uid.toUpperCase() == uid.toUpperCase());
    if (index >= 0) {
      _cards[index] = _cards[index].copyWith(label: label.trim().isEmpty ? null : label.trim());
      notifyListeners();
    }
  }

  /// Initiates the multi-step card registration workflow
  Future<void> startRegistration() async {
    _registrationStep = RfidRegistrationStep.initiating;
    _registrationError = null;
    _newlyRegisteredUid = null;
    _pollCount = 0;
    notifyListeners();

    try {
      // Step 2: Send POST /api/rfid/register
      await _rfidRepository.startRegistration();

      // Step 3 & 4: Set state to waiting for card tap
      _registrationStep = RfidRegistrationStep.waitingForTap;
      notifyListeners();

      // Step 5: Poll the API for newly registered card and event
      _startPollingForCard();
    } on ApiException catch (e) {
      // If ESP32 was busy or lingering, reset state and retry once cleanly
      try {
        await _rfidRepository.cancelRegistration();
        await Future.delayed(const Duration(milliseconds: 350));
        await _rfidRepository.startRegistration();

        _registrationStep = RfidRegistrationStep.waitingForTap;
        notifyListeners();
        _startPollingForCard();
        return;
      } catch (_) {}

      _registrationStep = RfidRegistrationStep.error;
      _registrationError = e.message;
      notifyListeners();
    } catch (e) {
      _registrationStep = RfidRegistrationStep.error;
      _registrationError = 'Could not start RFID registration mode on ESP32.';
      notifyListeners();
    }
  }

  void _startPollingForCard() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      _pollCount++;

      if (_pollCount > _maxPollCycles) {
        cancelRegistration(isTimeout: true);
        return;
      }

      try {
        // Poll status to see if registration_waiting transitioned
        final status = await _deviceRepository.getStatus();
        final latestCards = await _rfidRepository.getRegisteredCards();

        // 1. Check if there is a newly added card not in previous list
        final previousUids = _cards.map((c) => c.uid).toSet();
        final newCard = latestCards.firstWhere(
          (c) => !previousUids.contains(c.uid),
          orElse: () => RfidCard(uid: ''),
        );

        if (newCard.uid.isNotEmpty) {
          // Success detected!
          _newlyRegisteredUid = newCard.uid;
          _cards = latestCards;
          _registrationStep = RfidRegistrationStep.success;
          _pollingTimer?.cancel();
          notifyListeners();
          return;
        }

        // 2. Check if a duplicate / already registered event was logged
        final events = await _rfidRepository.getEvents();
        if (events.isNotEmpty) {
          final regEvent = events.firstWhere(
            (e) => e.type == 'rfid_card_registered',
            orElse: () => DoorEvent(
              id: 0,
              type: '',
              uid: '',
              result: '',
              uptimeMs: 0,
              timestamp: 0,
              timestampSource: '',
            ),
          );

          if (regEvent.type == 'rfid_card_registered' &&
              regEvent.result.toLowerCase() == 'already_registered') {
            _newlyRegisteredUid = regEvent.uid;
            _cards = latestCards;
            _registrationStep = RfidRegistrationStep.alreadyRegistered;
            _pollingTimer?.cancel();
            notifyListeners();
            return;
          }
        }

        // 3. Fallback: If ESP32 finished/left registration mode without adding a new card,
        // it means the scanned card was already registered or scan cancelled
        if (!status.registrationWaiting && _pollCount >= 2) {
          _cards = latestCards;
          _registrationStep = RfidRegistrationStep.alreadyRegistered;
          _pollingTimer?.cancel();
          notifyListeners();
          return;
        }
      } catch (_) {
        // Continue polling until timeout
      }
    });
  }

  void cancelRegistration({bool isTimeout = false}) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _rfidRepository.cancelRegistration().catchError((_) {});
    if (isTimeout) {
      _registrationStep = RfidRegistrationStep.timeout;
      _registrationError = 'Registration timed out. No RFID card was scanned within 60 seconds.';
    } else {
      _registrationStep = RfidRegistrationStep.idle;
      _registrationError = null;
    }
    notifyListeners();
  }

  void resetRegistration() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _rfidRepository.cancelRegistration().catchError((_) {});
    _registrationStep = RfidRegistrationStep.idle;
    _registrationError = null;
    _newlyRegisteredUid = null;
    notifyListeners();
  }

  /// Removes a card UID from ESP32
  Future<bool> removeCard(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _rfidRepository.removeCard(uid);
      _cards.removeWhere((c) => c.uid.toUpperCase() == uid.toUpperCase());
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to remove RFID card.';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
