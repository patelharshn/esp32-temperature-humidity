import '../models/door_event.dart';
import '../models/rfid_card.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class RfidRepository {
  final ApiService _apiService;
  final StorageService _storageService;

  RfidRepository(this._apiService, this._storageService);

  /// Fetches registered cards from ESP32 and enriches with user-saved labels
  Future<List<RfidCard>> getRegisteredCards() async {
    final rawUids = await _apiService.getRfidCards();
    final labels = _storageService.getCardLabels();

    return rawUids.map((uid) {
      final cleanUid = uid.trim().toUpperCase();
      return RfidCard(
        uid: cleanUid,
        label: labels[cleanUid],
      );
    }).toList();
  }

  /// Sets or updates friendly nickname for a card UID
  Future<void> setCardLabel(String uid, String label) async {
    await _storageService.setCardLabel(uid, label);
  }

  /// Fetches recent events from ESP32 and merges with local persistent cache
  Future<List<DoorEvent>> getEvents() async {
    final liveEvents = await _apiService.getEvents();
    if (liveEvents.isNotEmpty) {
      await _storageService.mergeCachedEvents(liveEvents);
    }
    return _storageService.getCachedEvents();
  }

  /// Returns cached events even when offline
  List<DoorEvent> getCachedEvents() {
    return _storageService.getCachedEvents();
  }

  /// Starts RFID card registration on ESP32
  Future<Map<String, dynamic>> startRegistration() async {
    return await _apiService.startRfidRegistration();
  }

  /// Cancels RFID card registration on ESP32
  Future<void> cancelRegistration() async {
    await _apiService.cancelRfidRegistration();
  }

  /// Removes an RFID card UID from ESP32
  Future<void> removeCard(String uid) async {
    await _apiService.removeRfidCard(uid);
    // Optionally clean up label
    await _storageService.setCardLabel(uid, '');
  }
}
