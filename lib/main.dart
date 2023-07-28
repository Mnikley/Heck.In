import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'colors.dart';
import 'firebase_options.dart';
import 'form.dart';
import 'snackbar.dart';
import 'utils_geo.dart' as geo;

void main() => runApp(const HedgeProfilerApp());

class HedgeProfilerApp extends StatefulWidget {
  const HedgeProfilerApp({super.key});

  @override
  HedgeProfilerAppState createState() => HedgeProfilerAppState();

  static HedgeProfilerAppState of(BuildContext context) =>
      context.findAncestorStateOfType<HedgeProfilerAppState>()!;
}

class HedgeProfilerAppState extends State<HedgeProfilerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hedge Profiler',
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: const WebViewPage(),
    );
  }

  /// 3) Call this to change theme from any context using "of" accessor
  /// e.g.:
  /// HedgeProfilerApp.of(context).changeTheme(ThemeMode.dark);
  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => WebViewPageState();
}

/// main page, instantiates WebView controller and NameForm (displayed as overlay)
class WebViewPageState extends State<WebViewPage> {
  final ValueNotifier<double> _loadingPercentage = ValueNotifier<double>(0.0);
  late final WebViewController _controller;

  bool _showNameForm = true;
  GlobalKey<NameFormState> _nameFormKey = GlobalKey<NameFormState>();

  String _currentUrlSynonym = '';
  String _geoLastChange = 'never updated';
  String _geoLastKnown = 'no location available';
  String systemLocale = Platform.localeName.startsWith("de") ? "DE" : "EN";
  String currentLocale = "EN";
  bool _darkMode = true;
  bool _isLoading = true;

  /// initializes the firebase app
  _initDatabase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      showSnackbar(context, e.toString());
    }
  }

  @override
  void initState() {
    super.initState();

    _updateLocationAndLocales();
    _initDatabase();

    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _loadingPercentage.value = 0;
            // debugPrint('Page started loading: $url');
          },
          onProgress: (int progress) {
            _loadingPercentage.value = progress.toDouble();
            // debugPrint('WebView is loading (progress: $progress%)');
          },
          onPageFinished: (String url) {
            _loadingPercentage.value = 100;
            // debugPrint('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            _loadingPercentage.value = 0;
            showSnackbar(context, error.description.toString());
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    _controller = controller;
  }

  /// refreshes geo coordinates and updates variables for menu accordingly
  _updateLocationAndLocales() async {
    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // initially set locale
    if (!prefs.containsKey("locale")) {
      prefs.setString("locale", systemLocale);
    }

    // load last stored locale
    currentLocale = prefs.getString("locale")!;

    // set to last known pos
    await geo.getLastKnownLocation();
    setState(() {
      _geoLastChange =
          prefs.getString("geo_last_change")?.split(".")[0] ?? 'n/a';
      String lat = prefs.getString("geo_latitude") ?? "n/a";
      String lon = prefs.getString("geo_longitude") ?? "n/a";
      _geoLastKnown = "lat: $lat\nlon: $lon";
    });

    // wait for refresh of coords
    try {
      // wait for refresh of coords with a timeout of 5 seconds
      await geo.updateLocation().timeout(const Duration(seconds: 5),
          onTimeout: () {
        setState(() {
          _isLoading = false;
        });
        showSnackbar(
            context,
            currentLocale == "EN"
                ? "Updating geo information timed out after 5 seconds"
                : "Geo koordinaten konnten nach 5 Sekunden nicht aktualisiert werden");
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        showSnackbar(context, "Error when upding geo information: $e");
      });
    }

    setState(() {
      _geoLastChange =
          prefs.getString("geo_last_change")?.split(".")[0] ?? 'n/a';
      String lat = prefs.getString("geo_latitude") ?? "n/a";
      String lon = prefs.getString("geo_longitude") ?? "n/a";
      _geoLastKnown = "lat: $lat\nlon: $lon";
      _isLoading = false;
    });
  }

  /// scaffold of app with menu drawer and WebViewWidget as body
  /// NameForm is stacked on top and controlled with _showNameForm
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: MyColors.topBarColor,
          title: Text(
              currentLocale == "EN" ? "Hedge Profiler" : "Hecken Profiler"),
        ),
        drawer: Drawer(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: const BoxDecoration(
                        color: MyColors.blue,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            currentLocale == "EN"
                                ? "Hedge Profiler"
                                : "Hecken Profiler",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildGeoStatusText(),
                        ],
                      ),
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.eco_rounded, color: MyColors.green),
                      title: Text(currentLocale == "EN"
                          ? "Rate Hedge"
                          : "Hecke Bewerten"),
                      onTap: () {
                        setState(() {
                          _showNameForm = true;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.coral),
                      title: Text(currentLocale == "EN"
                          ? "View Arcanum Map"
                          : "Arcanum Karte Öffnen"),
                      onTap: () {
                        loadMapArcanum();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.teal),
                      title: Text(currentLocale == "EN"
                          ? "View Bodenkarte"
                          : "Bodenkarte Öffnen"),
                      onTap: () {
                        loadMapBodenkarte();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.teal),
                      title: Text(currentLocale == "EN"
                          ? "View Bodenkarte (fieldcapacity)"
                          : "Bodenkarte (Feldkapazität) Öffnen"),
                      onTap: () {
                        loadMapBodenkarteNutzbareFeldkapazitaet();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.teal),
                      title: Text(currentLocale == "EN"
                          ? "View Bodenkarte (humus)"
                          : "Bodenkarte (Humus) Öffnen"),
                      onTap: () {
                        loadMapBodenkarteHumusBilanz();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.teal),
                      title: Text(currentLocale == "EN"
                          ? "View Geonode Map"
                          : "Geonode Karte Öffnen"),
                      onTap: () {
                        loadMapGeonodeLebensraumverletzung();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.teal),
                      title: Text(currentLocale == "EN"
                          ? "View Ecosystem Map"
                          : "Ecosystem Karte Öffnen"),
                      onTap: () {
                        loadMapEcosystemAccounts();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.teal),
                      title: Text(currentLocale == "EN"
                          ? "View NOE Atlas"
                          : "NOE Atlas Öffnen"),
                      onTap: () {
                        loadMapNoeNaturschutz();
                      },
                    ),
                    ListTile(
                      leading:
                          const Icon(Icons.map_outlined, color: MyColors.teal),
                      title: Text(currentLocale == "EN"
                          ? "View EEA Map"
                          : "EEA Karte Öffnen"),
                      onTap: () {
                        loadMapEEAEuropa();
                      },
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLanguageToggleButton(),
                        _buildGeoRefreshButton(),
                        _buildDarkmodeToggleButton(),
                      ]),
                  const SizedBox(height: 30),
                  Image.asset(
                    'data/lsw_logo.png',
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 30)
                ],
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(
              controller: _controller,
            ),
            ValueListenableBuilder<double>(
              valueListenable: _loadingPercentage,
              builder: (context, value, child) {
                return value < 100
                    ? LinearProgressIndicator(
                        value: value / 100.0,
                      )
                    : const SizedBox.shrink();
              },
            ),
            if (_showNameForm)
              Positioned.fill(
                child: Container(
                  color: MyColors.black.withOpacity(0.5),
                  child: Center(
                    child:
                        NameForm(formKey: _nameFormKey, webViewPageState: this),
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  void loadMapArcanum() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var latitude = prefs.getString("geo_latitude");
    var longitude = prefs.getString("geo_longitude");
    String stem = "https://maps.arcanum.com/en/map";
    String map = "europe-19century-secondsurvey";
    loadPageWrapper(
        "$stem/$map/?lon=$longitude&lat=$latitude&zoom=15",
        "arcanum");
  }

  void loadMapBodenkarte() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var latitude = prefs.getString("geo_latitude");
    var longitude = prefs.getString("geo_longitude");
    loadPageWrapper(
        "https://bodenkarte.at/#/center/$longitude,$latitude/zoom/15",
        "bodenkarte");
  }

  void loadMapBodenkarteNutzbareFeldkapazitaet() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var latitude = prefs.getString("geo_latitude");
    var longitude = prefs.getString("geo_longitude");
    loadPageWrapper(
        "https://bodenkarte.at/#/d/baw/l/nf,false,60,kb/center/$longitude,$latitude/zoom/15",
        "bodenkarteNutzbareFeldkapazitaet");
  }

  void loadMapBodenkarteHumusBilanz() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var latitude = prefs.getString("geo_latitude");
    var longitude = prefs.getString("geo_longitude");
    loadPageWrapper(
        "https://bodenkarte.at/#/d/bfa/l/hb,false,60,kb/center/$longitude,$latitude/zoom/15",
        "bodenkarteHumusBilanz");
  }

  void loadMapGeonodeLebensraumverletzung() {
    loadPageWrapper(
        "https://geonode.lebensraumvernetzung.at/maps/63/view#/",
        "geonode");
  }

  void loadMapEcosystemAccounts() {
    loadPageWrapper(
        "https://ecosystem-accounts.jrc.ec.europa.eu/map",
        "ecosystem");
  }

  void loadMapGeoland() {
    loadPageWrapper(
        "https://www.geoland.at/webgisviewer/geoland/map/Geoland_Viewer/Geoland",
        "geoland");
  }

  void loadMapNoeNaturschutz() {
    loadPageWrapper(
        "https://atlas.noe.gv.at/atlas/portal/noe-atlas/map/Naturraum/Naturschutz",
        "noe");
  }

  void loadMapEEAEuropa() {
    loadPageWrapper(
        "https://www.eea.europa.eu/data-and-maps/explore-interactive-maps/european-protected-areas-1",
        "eea");
  }

  void loadPageWrapper(String pageURL, String pageSynonym) async {
    if (mounted) {
      setState(() {
        _showNameForm = false;
      });
    }
    if (_currentUrlSynonym != pageSynonym) {
      setState(() {
        _currentUrlSynonym = pageSynonym;
      });
      // loadPage(context, pageURL);
      _controller.loadRequest(Uri.parse(pageURL));
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _toggleLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getString("locale") == "EN") {
      prefs.setString("locale", "DE");
      currentLocale = "DE";
    } else {
      prefs.setString("locale", "EN");
      currentLocale = "EN";
    }
    // Rebuild main form
    setState(() {});

    // // re-initialize form (delayed)
    // Future.delayed(Duration.zero, () {
    //   _nameFormKey.currentState?.initState();
    // });

    // reset form key
    _nameFormKey = GlobalKey<NameFormState>();
  }

  Widget _buildLanguageToggleButton() {
    return ElevatedButton(
      onPressed: _toggleLanguage,
      child: Column(children: [
        const Icon(
          Icons.translate,
        ),
        currentLocale == "EN" ? const Text("Deutsch") : const Text("English"),
      ]),
    );
  }

  Widget _buildDarkmodeToggleButton() {
    String light = currentLocale == "EN" ? "Light" : "Hell";
    String dark = currentLocale == "EN" ? "Dark" : "Dunkel";

    return ElevatedButton(
      child: Column(
        children: [
          _darkMode
              ? const Icon(Icons.light_mode, color: MyColors.yellow)
              : const Icon(
                  Icons.dark_mode,
                  color: MyColors.black,
                ),
          _darkMode ? Text(light) : Text(dark),
        ],
      ),
      onPressed: () {
        setState(() {
          _darkMode = !_darkMode;
          if (_darkMode) {
            HedgeProfilerApp.of(context).changeTheme(ThemeMode.dark);
          } else {
            HedgeProfilerApp.of(context).changeTheme(ThemeMode.light);
          }
        });
      },
    );
  }

  Widget _buildGeoRefreshButton() {
    return ElevatedButton(
        onPressed: _updateLocationAndLocales,
        child: Column(children: [
          const Icon(Icons.my_location_sharp, color: MyColors.coral),
          currentLocale == "EN"
              ? const Text("Location")
              : const Text("Standort")
        ]));
  }

  Widget _buildGeoStatusText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              currentLocale == "EN"
                  ? "Location updated: "
                  : "Standort aktualisiert: ",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              _geoLastChange,
              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Text(
            _geoLastKnown,
            style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}

class ConfirmationDialog extends StatelessWidget {
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ConfirmationDialog({
    Key? key,
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Action'),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
