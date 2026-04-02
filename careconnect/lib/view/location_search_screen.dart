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

  // Determine if this is a Dropoff to show the Red Pin instead of Blue Dot
  bool get _isDropoff => widget.title.toLowerCase().contains('destination') || widget.title.toLowerCase().contains('drop-off');

  // Theme Colors replacing Grab Green
  final Color themePrimary = const Color(0xFF6B3F69);
  final Color themeLight = const Color(0xFFDDC3C3);

  // Grab-Style Live Address Search API (OpenStreetMap Nominatim)
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

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

  // Auto-Detect GPS
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

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String formattedAddress = '${place.street}, ${place.locality}, ${place.administrativeArea}';
        if (formattedAddress.startsWith(', ')) formattedAddress = formattedAddress.substring(2);

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
    bool isTyping = _searchController.text.isNotEmpty;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 1. GRAB STYLE HEADER & SEARCH BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 10, 20, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // Location Indicator (Blue Dot or Red Pin)
                    Container(
                      margin: const EdgeInsets.only(right: 15),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _isDropoff ? Colors.red : Colors.blue,
                        shape: _isDropoff ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius: _isDropoff ? BorderRadius.circular(2) : null,
                      ),
                    ),
                    // Search Field
                    Expanded(
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isTyping ? themePrimary : Colors.grey.shade300, width: 1.5),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: _searchPlaces,
                          decoration: InputDecoration(
                            hintText: widget.title,
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                            suffixIcon: isTyping
                                ? IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (!isTyping) ...[
                      const SizedBox(width: 15),
                      const Icon(Icons.add_circle_outline, color: Colors.black),
                    ]
                  ],
                ),
              ),

              // 2. TABS OR LIVE SEARCH RESULTS
              Expanded(
                child: isTyping 
                  ? _buildLiveSearchResults() 
                  : Column(
                      children: [
                        // Grab Style Tabs
                        TabBar(
                          labelColor: themePrimary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: themePrimary,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                          tabs: const [
                            Tab(text: 'Recent'),
                            Tab(text: 'Suggested'),
                            Tab(text: 'Saved'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildRecentTab(),
                              const Center(child: Text('No suggestions yet', style: TextStyle(color: Colors.grey))),
                              _buildSavedTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
              ),
            ],
          ),
        ),
        
        // 3. GRAB STYLE FLOATING "CHOOSE ON MAP" BUTTON
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: isTyping ? null : FloatingActionButton.extended(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Map Interface opening...')));
          },
          backgroundColor: themeLight.withOpacity(0.5),
          elevation: 0,
          label: Text('Choose on Map', style: TextStyle(color: themePrimary, fontWeight: FontWeight.bold)),
          icon: Icon(Icons.map_outlined, color: themePrimary),
        ),
      ),
    );
  }

  // --- TAB CONTENTS ---

  Widget _buildRecentTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 80), // bottom padding for floating button
      children: [
        _buildGrabListTile(
          icon: Icons.my_location,
          iconColor: Colors.blue,
          title: 'Current Location',
          subtitle: 'Auto-detect using GPS',
          onTap: _useCurrentLocation,
        ),
        const Divider(height: 1),
        _buildGrabListTile(
          icon: Icons.access_time_filled,
          iconColor: themePrimary,
          title: 'UUM - Dewan Penginapan Pelajar TM',
          subtitle: '3.23km • Persiaran Perdana, Universiti Utara Malaysia...',
          onTap: () => _mockSelectLocation('UUM - Dewan Penginapan Pelajar TM', 6.4603, 100.5010),
        ),
      ],
    );
  }

  Widget _buildSavedTab() {
    return ListView(
      padding: const EdgeInsets.only(top: 10),
      children: [
        _buildGrabListTile(
          icon: Icons.favorite,
          iconColor: Colors.red,
          title: 'Home',
          subtitle: '10, Lorong 2, Bandar Tasek Mutiara',
          onTap: () => _mockSelectLocation('10, Lorong 2, Bandar Tasek Mutiara', 5.2796, 100.4908),
        ),
        const Divider(height: 1),
        _buildGrabListTile(
          icon: Icons.favorite,
          iconColor: Colors.red,
          title: 'Bukit Immigration',
          subtitle: '12.56km • Bukit Kayu Hitam Customs & Immigration...',
          onTap: () => _mockSelectLocation('Bukit Kayu Hitam Customs & Immigration', 6.5204, 100.4190),
        ),
      ],
    );
  }

  // Live Results from OpenStreetMap
  Widget _buildLiveSearchResults() {
    if (_isSearching) return Center(child: CircularProgressIndicator(color: themePrimary));

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final displayName = result['display_name'].toString();
        
        final parts = displayName.split(', ');
        final mainText = parts.first;
        final subText = parts.length > 1 ? parts.sublist(1).join(', ') : '';

        return _buildGrabListTile(
          icon: Icons.location_on,
          iconColor: Colors.grey.shade600,
          title: mainText,
          subtitle: subText,
          onTap: () {
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

  // Reusable Grab-Style List Tile
  Widget _buildGrabListTile({required IconData icon, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.more_vert, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _mockSelectLocation(String address, double lat, double lng) {
    Navigator.pop(context, {
      'address': address,
      'lat': lat,
      'lng': lng,
    });
  }
}