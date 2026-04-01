import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationSearchScreen extends StatefulWidget {
  final String title;

  const LocationSearchScreen({super.key, required this.title});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  // Grab-Style Live Address Search API (OpenStreetMap Nominatim)
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    // Free Geocoding API (Restricted to Malaysia for better local results)
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&countrycodes=my');
    
    try {
      final response = await http.get(url, headers: {'User-Agent': 'CareConnectApp/1.0'});
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  // Auto-Detect GPS (Grab's "Use Current Location")
  Future<void> _useCurrentLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Detecting your GPS location...'), duration: Duration(seconds: 2)),
    );

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS is disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permissions denied.');
      }

      // 1. Get Coordinates
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // 2. Convert Coordinates to Address (Reverse Geocoding)
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String formattedAddress = '${place.street}, ${place.locality}, ${place.administrativeArea}';
        if (formattedAddress.startsWith(', ')) formattedAddress = formattedAddress.substring(2);

        // 3. Return the Address AND the Coordinates back to the Booking Screen!
        if (mounted) {
          Navigator.pop(context, {
            'address': formattedAddress,
            'lat': position.latitude,
            'lng': position.longitude,
          });
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.title, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 1. Search Bar Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0, 3))],
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _searchPlaces,
              decoration: InputDecoration(
                hintText: 'Search location or building...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B3F69)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),

          // 2. Search Results OR Default Options
          Expanded(
            child: _searchResults.isEmpty && _searchController.text.isEmpty
                ? _buildDefaultOptions() // Show Current Location, Map, Home when not searching
                : _buildSearchResults(), // Show Live Geocoding Results when typing
          ),
        ],
      ),
    );
  }

  // The Grab-style default options before you start typing
  Widget _buildDefaultOptions() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // OPTION A: Auto Detect Location
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFDDC3C3).withOpacity(0.3), shape: BoxShape.circle),
            child: const Icon(Icons.my_location, color: Color(0xFF6B3F69)),
          ),
          title: const Text('Use Current Location', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Auto-detect using GPS', style: TextStyle(fontSize: 12, color: Colors.grey)),
          onTap: _useCurrentLocation,
        ),
        const Divider(),
        
        // OPTION B: Drop a Pin (Placeholder for Map SDK integration)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.map_outlined, color: Colors.black54),
          ),
          title: const Text('Choose on Map', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Drag a pin to your exact location', style: TextStyle(fontSize: 12, color: Colors.grey)),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Map Interface will be connected here!')));
          },
        ),
        const Divider(),

        // OPTION C: Saved Places
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('Saved Places', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.home_outlined, color: Colors.black54),
          title: const Text('Home'),
          onTap: () {
            // Simulated Geocoding for "Home"
            Navigator.pop(context, {
              'address': '10, Lorong 2, Bandar Tasek Mutiara',
              'lat': 5.2796,
              'lng': 100.4908,
            });
          },
        ),
      ],
    );
  }

  // The Live Results from typing
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6B3F69)));
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final displayName = result['display_name'].toString();
        
        // Split the long address for cleaner Grab-style UI (Main Title + Subtitle)
        final parts = displayName.split(', ');
        final mainText = parts.first;
        final subText = parts.length > 1 ? parts.sublist(1).join(', ') : '';

        return ListTile(
          leading: const Icon(Icons.location_on, color: Color(0xFF6B3F69)),
          title: Text(mainText, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          onTap: () {
            // When user clicks a search result, pass the Address AND Coordinates back!
            Navigator.pop(context, {
              'address': displayName,
              'lat': double.parse(result['lat']),
              'lng': double.parse(result['lon']),
            });
          },
        );
      },
    );
  }
}