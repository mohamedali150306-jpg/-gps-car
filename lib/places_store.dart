import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved place: a name the user types and the GPS point the car drives to.
class Place {
  final String name;
  final double lat;
  final double lon;
  const Place(this.name, this.lat, this.lon);

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon};

  static Place? fromJson(dynamic j) {
    if (j is! Map) return null;
    final n = j['name'];
    final la = j['lat'];
    final lo = j['lon'];
    if (n is! String || la is! num || lo is! num) return null;
    return Place(n, la.toDouble(), lo.toDouble());
  }
}

/// Saved places, kept on the phone (survives closing the app).
class PlacesStore extends ChangeNotifier {
  static const _key = 'saved_places_v1';
  final List<Place> places = [];

  Future<void> load() async {
    try {
      final sp  = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      places.clear();
      if (raw != null) {
        for (final j in jsonDecode(raw) as List) {
          final p = Place.fromJson(j);
          if (p != null) places.add(p);
        }
      }
    } catch (_) {
      places.clear();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(places.map((p) => p.toJson()).toList()));
  }

  /// Adds a place, or replaces the one with the same name (case-insensitive).
  Future<void> add(Place p) async {
    places.removeWhere((x) => x.name.toLowerCase() == p.name.toLowerCase());
    places.add(p);
    places.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    await _save();
  }

  Future<void> remove(String name) async {
    places.removeWhere((x) => x.name.toLowerCase() == name.toLowerCase());
    notifyListeners();
    await _save();
  }

  /// Finds a place from what the user typed: exact name first, then a name
  /// that starts with the text (only if that is unambiguous).
  Place? find(String typed) {
    final t = typed.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final p in places) {
      if (p.name.toLowerCase() == t) return p;
    }
    final starts = places.where((p) => p.name.toLowerCase().startsWith(t)).toList();
    return starts.length == 1 ? starts.first : null;
  }
}
