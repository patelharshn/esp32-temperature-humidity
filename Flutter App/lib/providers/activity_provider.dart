import 'package:flutter/material.dart';
import '../core/network/api_exceptions.dart';
import '../models/door_event.dart';
import '../repositories/rfid_repository.dart';

class ActivityProvider extends ChangeNotifier {
  final RfidRepository _rfidRepository;

  List<DoorEvent> _allEvents = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filter & Search states
  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all', 'rfid_access', 'password_attempt', 'admin'
  String _resultFilter = 'all'; // 'all', 'granted', 'denied'
  bool _sortNewestFirst = true;

  ActivityProvider(this._rfidRepository) {
    _allEvents = _rfidRepository.getCachedEvents();
  }

  List<DoorEvent> get allEvents => _allEvents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;
  String get resultFilter => _resultFilter;
  bool get sortNewestFirst => _sortNewestFirst;

  /// Returns filtered and sorted events
  List<DoorEvent> get filteredEvents {
    var list = List<DoorEvent>.from(_allEvents);

    // 1. Search Query Filter (UID or Type)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((e) {
        return e.uid.toLowerCase().contains(q) ||
            e.type.toLowerCase().contains(q) ||
            e.displayTitle.toLowerCase().contains(q);
      }).toList();
    }

    // 2. Type Filter
    if (_typeFilter != 'all') {
      if (_typeFilter == 'admin') {
        list = list.where((e) => e.isAdminEvent).toList();
      } else {
        list = list.where((e) => e.type == _typeFilter).toList();
      }
    }

    // 3. Result Filter
    if (_resultFilter == 'granted') {
      list = list.where((e) => e.isAccessGranted).toList();
    } else if (_resultFilter == 'denied') {
      list = list.where((e) => e.isDenied).toList();
    }

    // 4. Sorting
    list.sort((a, b) {
      if (_sortNewestFirst) {
        return b.id.compareTo(a.id);
      } else {
        return a.id.compareTo(b.id);
      }
    });

    return list;
  }

  /// Specific getter for Administrative Events (Section 7)
  List<DoorEvent> get adminEvents {
    final list = _allEvents.where((e) => e.isAdminEvent).toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  Future<void> loadEvents() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final events = await _rfidRepository.getEvents();
      _allEvents = events;
      _errorMessage = null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      // Preserve cached events even on error
      _allEvents = _rfidRepository.getCachedEvents();
    } catch (e) {
      _errorMessage = 'Failed to load events from ESP32.';
      _allEvents = _rfidRepository.getCachedEvents();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTypeFilter(String type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setResultFilter(String result) {
    _resultFilter = result;
    notifyListeners();
  }

  void toggleSortOrder() {
    _sortNewestFirst = !_sortNewestFirst;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _typeFilter = 'all';
    _resultFilter = 'all';
    _sortNewestFirst = true;
    notifyListeners();
  }
}
