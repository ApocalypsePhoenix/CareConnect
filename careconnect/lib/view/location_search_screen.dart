import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ADDED for Recent & Saved Data

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

  // Real Data Lists for Recent & Saved
  List<Map<String, dynamic>> _recentLocations = [];
  List<Map<String, dynamic>> _savedLocations = [];

  bool get _isDropoff => 
      widget.title.toLowerCase().contains('destination') || 
      widget.title.toLowerCase().contains('drop-off') ||
      widget.title.toLowerCase().contains('destinasi') ||
      widget.title.toLowerCase().contains('hantar');

  final Color themePrimary = const Color(0xFF6B3F69);
  final Color themeLight = const Color(0xFFDDC3C3);

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  // Load Saved and Recent data from device storage
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final recentStr = prefs.getString('recent_locations');
    final savedStr = prefs.getString('saved_locations');
    
    if (mounted) {
      setState(() {
        if (recentStr != null) {
          _recentLocations = List<Map<String, dynamic>>.from(jsonDecode(recentStr));
        }
        if (savedStr != null) {
          _savedLocations = List<Map<String, dynamic>>.from(jsonDecode(savedStr));
        }
      });
    }
  }

  // Save changes back to device storage
  Future<void> _saveLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_locations', jsonEncode(_recentLocations));
    await prefs.setString('saved_locations', jsonEncode(_savedLocations));
  }

  // Add to recent and navigate back
  void _selectLocationAndPop(String address, double lat, double lng) {
    final locData = {'address': address, 'lat': lat, 'lng': lng};
    
    // Remove if exists so it moves to the top of the list
    _recentLocations.removeWhere((loc) => loc['address'] == address);
    _recentLocations.insert(0, locData);
    
    // Limit recent history to 10 items
    if (_recentLocations.length > 10) _recentLocations.removeLast();
    
    _saveLocalData();
    Navigator.pop(context, locData);
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty || query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    // Limit=5 ensures accurate 5 results for areas like "Changlun"
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

  Future<void> _useCurrentLocation(AppLocalizations l10n) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.detectingGps), duration: const Duration(seconds: 2)),
    );

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception(l10n.gpsDisabled);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception(l10n.permissionsDenied);
      }

      // Upgraded Accuracy to Best For Navigation
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Highly accurate location formatting for Current Location
        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
        if (place.postalCode != null && place.postalCode!.isNotEmpty) addressParts.add(place.postalCode!);
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);

        String formattedAddress = addressParts.join(', ');

        if (mounted) {
          _selectLocationAndPop(formattedAddress, position.latitude, position.longitude);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTyping = _searchController.text.isNotEmpty;
    final l10n = AppLocalizations.of(context)!; 

    return DefaultTabController(
      length: 2, // Removed Suggested Tab
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 10, 20, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
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
                  ],
                ),
              ),

              Expanded(
                child: isTyping 
                  ? _buildLiveSearchResults() 
                  : Column(
                      children: [
                        TabBar(
                          labelColor: themePrimary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: themePrimary,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                          tabs: [
                            Tab(child: FittedBox(child: Text(l10n.recentTab))),
                            Tab(child: FittedBox(child: Text(l10n.savedTab))),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildRecentTab(l10n),
                              _buildSavedTab(l10n),
                            ],
                          ),
                        ),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.only(top: 10),
      children: [
        _buildGrabListTile(
          icon: Icons.my_location,
          iconColor: Colors.blue,
          title: l10n.currentLocation,
          subtitle: l10n.autoDetectGps,
          showOptions: false,
          onTap: () => _useCurrentLocation(l10n),
        ),
        const Divider(height: 1),
        if (_recentLocations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text('No recent locations found.', style: TextStyle(color: Colors.grey))),
          )
        else
          ..._recentLocations.map((loc) {
            final parts = loc['address'].toString().split(', ');
            final mainText = parts.first;
            final subText = parts.length > 1 ? parts.sublist(1).join(', ') : '';

            return Column(
              children: [
                _buildGrabListTile(
                  icon: Icons.access_time_filled,
                  iconColor: Colors.grey.shade600,
                  title: mainText,
                  subtitle: subText,
                  showOptions: true,
                  locationData: loc,
                  onTap: () => _selectLocationAndPop(
                  loc['address'].toString(), 
                  double.parse(loc['lat'].toString()), 
                   double.parse(loc['lng'].toString())
),
                ),
                const Divider(height: 1),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildSavedTab(AppLocalizations l10n) {
    if (_savedLocations.isEmpty) {
      return const Center(child: Text('No saved locations yet.', style: TextStyle(color: Colors.grey)));
    }

    return ListView(
      padding: const EdgeInsets.only(top: 10),
      children: _savedLocations.map((loc) {
        final parts = loc['address'].toString().split(', ');
        final mainText = parts.first;
        final subText = parts.length > 1 ? parts.sublist(1).join(', ') : '';

        return Column(
          children: [
            _buildGrabListTile(
              icon: Icons.favorite,
              iconColor: Colors.red,
              title: mainText,
              subtitle: subText,
              showOptions: true,
              locationData: loc,
              onTap: () => _selectLocationAndPop(
                loc['address'].toString(),
                double.parse(loc['lat'].toString()),
                double.parse(loc['lng'].toString()),
                ),
            ),
            const Divider(height: 1),
          ],
        );
      }).toList(),
    );
  }

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

        final locData = {
          'address': displayName,
          'lat': double.parse(result['lat']),
          'lng': double.parse(result['lon']),
        };

        return _buildGrabListTile(
          icon: Icons.location_on,
          iconColor: Colors.grey.shade600,
          title: mainText,
          subtitle: subText,
          showOptions: true,
          locationData: locData,
          onTap: () => _selectLocationAndPop(
          displayName, 
          double.parse(locData['lat'].toString()), 
          double.parse(locData['lng'].toString())
          ),
        );
      },
    );
  }

  Widget _buildGrabListTile({
    required IconData icon, 
    required Color iconColor, 
    required String title, 
    required String subtitle, 
    required VoidCallback onTap,
    required bool showOptions,
    Map<String, dynamic>? locationData,
  }) {
    bool isSaved = locationData != null && _savedLocations.any((loc) => loc['address'] == locationData['address']);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      
      // Functional 3-Dots Menu to Save/Unsave Locations
      trailing: showOptions && locationData != null
          ? PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isSaved ? Colors.red : Colors.grey),
              onSelected: (value) {
                setState(() {
                  if (value == 'toggle_save') {
                    if (isSaved) {
                      _savedLocations.removeWhere((loc) => loc['address'] == locationData['address']);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from Saved'), duration: Duration(seconds: 1)));
                    } else {
                      _savedLocations.insert(0, locationData);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Saved'), duration: Duration(seconds: 1)));
                    }
                    _saveLocalData();
                  }
                });
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'toggle_save',
                  child: Text(isSaved ? 'Remove from Saved' : 'Save Location'),
                ),
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}