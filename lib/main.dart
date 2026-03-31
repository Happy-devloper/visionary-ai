import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

late String apiKey;

class AppSettings {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.dark,
  );
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  static void setThemeMode(ThemeMode mode) => themeMode.value = mode;
  static void setLocale(Locale newLocale) => locale.value = newLocale;
}

class AppLocalizations {
  static const _translations = {
    'en': {
      'appTitle': 'Visionary AI',
      'settingsTitle': 'Settings',
      'themeTitle': 'Theme',
      'languageTitle': 'Language',
      'helpSupport': 'Help & Support',
      'aboutApp': 'About App',
      'gallery': 'GALLERY',
      'generate': 'GENERATE',
      'settings': 'SETTINGS',
      'createAnything': 'Create anything you imagine',
      'transformText': 'Transform simple text into breathtaking masterpieces',
    },
    'es': {
      'appTitle': 'Visión AI',
      'settingsTitle': 'Configuración',
      'themeTitle': 'Tema',
      'languageTitle': 'Idioma',
      'helpSupport': 'Ayuda y soporte',
      'aboutApp': 'Acerca de la app',
      'gallery': 'GALERÍA',
      'generate': 'GENERAR',
      'settings': 'AJUSTES',
      'createAnything': 'Crea cualquier cosa que imagines',
      'transformText': 'Convierte texto simple en obras impresionantes',
    },
  };

  static String t(String key) {
    final locale = AppSettings.locale.value.languageCode;
    return _translations[locale]?[key] ?? _translations['en']![key] ?? key;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  apiKey = dotenv.env['API_KEY']!;
  await Firebase.initializeApp();
  runApp(const MyApp());
}

// ---------------- APP ----------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: AppSettings.locale,
          builder: (context, locale, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                colorSchemeSeed: const Color(0xFF256AF4),
                scaffoldBackgroundColor: const Color(0xFFF3F4F6),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                colorSchemeSeed: const Color(0xFF256AF4),
                scaffoldBackgroundColor: const Color(0xFF101622),
              ),
              locale: locale,
              supportedLocales: const [Locale('en'), Locale('es')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const HomePage(),
            );
          },
        );
      },
    );
  }
}

// ---------------- MODEL ----------------
class AiImage {
  final String? id;
  final String imageUrl;
  final String prompt;

  AiImage({this.id, required this.imageUrl, required this.prompt});

  factory AiImage.fromMap(Map<dynamic, dynamic> map) {
    return AiImage(
      id: map['id'],
      imageUrl: map['imageUrl'],
      prompt: map['prompt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'imageUrl': imageUrl, 'prompt': prompt};
  }
}

// ---------------- HOME ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  List<AiImage> _allImages = [];
  final List<AiImage> _displayedImages = [];
  final DatabaseReference _ref = FirebaseDatabase.instance.ref('images');
  static const int _itemsPerPage = 12; // 10-15 items
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMoreItems = false;

  // Rate limiting for gallery loads
  DateTime? _lastLoadTime;
  static const int _loadCooldownSeconds = 1;

  @override
  void initState() {
    super.initState();
    _loadAllImages();
  }

  Future<void> _loadAllImages() async {
    final event = await _ref.once();
    if (event.snapshot.value != null) {
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      _allImages = data.values
          .map((e) => AiImage.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    }
    _hasMoreItems = _allImages.length > _itemsPerPage;
    _loadMoreImages();
  }

  void _loadMoreImages() {
    if (_isLoading) return;

    // Rate limit gallery loads
    if (_lastLoadTime != null) {
      final difference = DateTime.now().difference(_lastLoadTime!).inSeconds;
      if (difference < _loadCooldownSeconds) {
        return; // Silently ignore rapid load requests
      }
    }
    _lastLoadTime = DateTime.now();

    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      final startIndex = _currentPage * _itemsPerPage;
      final endIndex = (startIndex + _itemsPerPage).clamp(0, _allImages.length);

      if (startIndex < _allImages.length) {
        _displayedImages.addAll(_allImages.sublist(startIndex, endIndex));
        _currentPage++;
        _hasMoreItems = endIndex < _allImages.length;
      }

      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101622),
        appBar: AppBar(
          backgroundColor: const Color(0xFF101622),
          elevation: 0,
          title: Text(
            AppLocalizations.t('appTitle'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: _currentIndex == 0
            ? GalleryPage(
                images: _displayedImages,
                hasMoreItems: _hasMoreItems,
                isLoading: _isLoading,
                onLoadMore: _loadMoreImages,
                onNavigateToGenerate: () => setState(() => _currentIndex = 1),
              )
            : _currentIndex == 1
            ? const GeneratePage()
            : const SettingsPage(),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF101622),
          selectedItemColor: const Color(0xFF256AF4),
          unselectedItemColor: Colors.white70,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.grid_view),
              label: AppLocalizations.t('gallery'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.add_circle_outline),
              label: AppLocalizations.t('generate'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              label: AppLocalizations.t('settings'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- GALLERY ----------------
class GalleryPage extends StatefulWidget {
  final List<AiImage> images;
  final bool hasMoreItems;
  final bool isLoading;
  final VoidCallback onLoadMore;
  final VoidCallback onNavigateToGenerate;

  const GalleryPage({
    super.key,
    required this.images,
    required this.hasMoreItems,
    required this.isLoading,
    required this.onLoadMore,
    required this.onNavigateToGenerate,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late ScrollController _scrollController;
  static const double _scrollThreshold = 200.0;
  static const int _searchMaxLength = 200;

  // Rate limiting for downloads
  DateTime? _lastDownloadTime;
  static const int _downloadCooldownSeconds = 2;

  Future<String?> _downloadImage(String imageUrl) async {
    // Rate limit downloads
    if (_lastDownloadTime != null) {
      final difference = DateTime.now()
          .difference(_lastDownloadTime!)
          .inSeconds;
      if (difference < _downloadCooldownSeconds) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please wait ${_downloadCooldownSeconds - difference}s before downloading another image',
            ),
          ),
        );
        return null;
      }
    }
    _lastDownloadTime = DateTime.now();

    try {
      Uint8List bytes;
      if (imageUrl.startsWith('data:')) {
        final base64String = imageUrl.split(',')[1];
        bytes = base64Decode(base64String);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        bytes = response.bodyBytes;
      }
      final result = await ImageGallerySaverPlus.saveImage(bytes);
      if (result['isSuccess']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
        return result['filePath'];
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save image')));
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to download image')));
      return null;
    }
  }

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_searchQuery.trim().isNotEmpty) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (!widget.isLoading &&
        widget.hasMoreItems &&
        (maxScroll - currentScroll) <= _scrollThreshold) {
      widget.onLoadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101622),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search your creations...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0A0E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                onChanged: (v) {
                  if (v.length <= _searchMaxLength) {
                    setState(() => _searchQuery = v.trim());
                  }
                },
              ),
            ),
          ),

          // Hero Section
          if (widget.images.isNotEmpty && _searchQuery.trim().isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () {
                    // Navigate using bottom navigation (keeps tabs state)
                    widget.onNavigateToGenerate();
                  },
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: NetworkImage(widget.images.first.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create anything you imagine',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Transform simple text into breathtaking masterpieces',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Trend Styles Section
          if (_searchQuery.trim().isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trend Styles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF256AF4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_searchQuery.trim().isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _trendStyleItem('Cyberpunk'),
                    _trendStyleItem('Anime'),
                    _trendStyleItem('Oil Paint'),
                    _trendStyleItem('3D Render'),
                    _trendStyleItem('Abstract'),
                  ],
                ),
              ),
            ),

          // Featured Templates Section
          if (_searchQuery.trim().isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Featured Templates',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Icon(
                      Icons.filter_list,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),

          // Gallery Grid
          if (widget.images.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No images yet.\nGenerate your first AI image!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == _getFilteredImages().length &&
                        widget.hasMoreItems &&
                        widget.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (index >= _getFilteredImages().length) {
                      return const SizedBox.shrink();
                    }

                    final img = _getFilteredImages()[index];
                    return GalleryDiscoveryCard(
                      aiImage: img,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailPage(aiImage: img),
                          ),
                        );
                      },
                    );
                  },
                  childCount:
                      _getFilteredImages().length +
                      (widget.isLoading && widget.hasMoreItems ? 1 : 0),
                ),
              ),
            ),

          // Bottom spacing
          SliverToBoxAdapter(child: const SizedBox(height: 20)),
        ],
      ),
    );
  }

  List<AiImage> _getFilteredImages() {
    if (_searchQuery.trim().isEmpty) {
      return widget.images;
    }
    return widget.images
        .where(
          (img) =>
              img.prompt.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Widget _trendStyleItem(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF0A0E1E),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                title.split(' ')[0][0],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF256AF4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- GENERATE ----------------
class GeneratePage extends StatefulWidget {
  const GeneratePage({super.key});

  @override
  State<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends State<GeneratePage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  bool _hasNSFWContent = false;

  String? _generatedImageUrl;
  static const String _model = 'flux';

  // Input validation
  static const int _promptMinLength = 3;
  static const int _promptMaxLength = 500;

  String _selectedAspectRatio = '1:1';
  String _selectedStyle = 'Cyberpunk';

  // Rate limiting
  static const int _generationCooldownSeconds = 10; // 10 seconds cooldown
  DateTime? _lastGenerationTime;

  // NSFW content filter
  final List<String> _nsfwKeywords = [
    // Sexual content
    'nude', 'naked', 'porn', 'sex', 'xxx', 'adult', 'explicit',
    'nsfw', 'mature', 'erotic', 'sexually', 'inappropriate',
    'breast', 'penis', 'vagina', 'intimate', 'strip', 'topless',
    'sexy', 'horny', 'hot girl', 'bikini babe', 'lingerie', 'underwear',
    'nudes', 'cum', 'xxx content', 'adult content', 'sexual', 'rape',
    'incest', 'pedophilia', 'minor', 'child abuse', 'violence', 'gore',
    'bloody', 'dead body', 'mutilation', 'torture',
    // Additional sexual terms
    'fuck', 'fucking', 'dick', 'cock', 'pussy', 'ass', 'shit', 'bitch',
    'whore', 'slut', 'dildo', 'vibrator', 'orgasm', 'ejaculate', 'blowjob',
    'handjob', 'anal', 'butt plug', 'masturbate', 'masturbation', 'semen',
    'sperm', 'spermatid', 'fart', 'piss', 'pissing', 'wet panties',
    'creampie', 'gangbang', 'threesome', 'foursome', 'orgy', 'sex toy',
    'sex doll', 'prostitute', 'escort', 'brothel', 'pimp', 'cuckold',
    'cheating', 'affair', 'seduction', 'seductive', 'flirting', 'horny girl',
    'sexy woman', 'sexy girl', 'hot woman', 'hot teen', 'teen sex',
    'young girl', 'school girl', 'student sex', 'teacher sex',
    'lesbian', 'gay', 'transgender', 'transsexual', 'transexual',
    'buttocks', 'butt', 'booty', 'tits', 'nipple', 'cleavage',
    'clitoris', 'labia', 'prostate', 'testicles', 'scrotum',
    'fetish', 'bondage', 'bdsm', 'whip', 'spanking', 'dominance',
    'submission', 'submissive', 'safe word', 'role play', 'cosplay sex',
    'sex scene', 'nude scene', 'sex app', 'porn app', 'adult site',
    'webcam sex', 'cam girl', 'cam boy', 'stripper', 'pole dance',
    'lap dance', 'exotic dancer', 'nude modeling', 'nude photos',
    'intimate photos', 'private photos', 'spicy photos',
    // Violence and gore
    'kill', 'killing', 'murder', 'murderer', 'death', 'dead',
    'blood', 'bloodshed', 'wound', 'wounded', 'injury', 'injure',
    'stab', 'stabbing', 'shoot', 'shooting', 'gun', 'rifle',
    'pistol', 'shotgun', 'missile', 'bomb', 'explosive',
    'explosion', 'blast', 'dismember', 'dismemberment', 'decapitate',
    'decapitation', 'behead', 'eviscerate', 'disembowel', 'burn',
    'burning', 'charred', 'scalp', 'scalping', 'flay', 'flaying',
    'strip skin', 'skinned alive', 'crucifixion', 'crucify',
    'execution', 'executed', 'executed', 'guillotine', 'hanging',
    'hanged', 'lynching', 'mobbing', 'assault', 'battery',
    'domestic violence', 'abuse', 'abused', 'abuser', 'hit',
    'punch', 'kick', 'slap', 'strangle', 'choke', 'suffocate',
    'drown', 'poison', 'poison', 'toxic gas', 'radiation',
    'nuclear', 'accident', 'crash', 'collision', 'accident scene',
    'injury scene', 'emergency room', 'operating room complex surgery',
    // Drug references
    'drug', 'drugs', 'cocaine', 'heroin', 'meth', 'methamphetamine',
    'marijuana', 'weed', 'pot', 'cannabis', 'acid', 'lsd',
    'mdma', 'ecstasy', 'molly', 'pills', 'pills', 'adderall',
    'xanax', 'valium', 'opioid', 'fentanyl', 'morphine',
    'opium', 'crack', 'crystal meth', 'pcp', 'angel dust',
    'ghb', 'rohypnol', 'date rape drug', 'roofies', 'spiked drink',
    'intoxicated', 'drunk', 'high', 'stoned', 'tripping', 'overdose',
    'od', 'addiction', 'addict', 'dealer', 'pusher', 'cartel',
    'trafficking', 'trafficker', 'bootlegger', 'alcohol', 'liquor',
    'whiskey', 'vodka', 'beer', 'wine', 'drugs', 'dope',
    // Hate speech and discrimination
    'nigger', 'nigga', 'faggot', 'fag', 'dyke', 'retard',
    'retarded', 'idiot', 'imbecile', 'moron', 'stupid fuck',
    'jew', 'jewish', 'arab', 'muslim', 'islam', 'christian',
    'racist', 'racism', 'sexist', 'sexism', 'homophobic',
    'homophobia', 'transphobic', 'transphobia', 'ableist',
    'ableism', 'xenophobic', 'xenophobia', 'swastika', 'nazi',
    'hitler', 'holocaust', 'genocide', 'ethnic cleansing',
    'apartheid', 'slavery', 'slave', 'master', 'plantation',
    'colonization', 'colonialism', 'imperialism', 'occupation',
    'oppression', 'oppressed', 'discrimination', 'discriminate',
    // Child safety
    'child', 'children', 'kid', 'kids', 'teen', 'teenager',
    'underage', 'minor', 'youth', 'young', 'juvenile', 'baby',
    'toddler', 'infant', 'newborn', 'child abuse', 'child porn',
    'child sexual abuse', 'child exploitation', 'grooming',
    'molesting', 'molestation', 'pedophile', 'pedophilia',
    'pedo', 'loli', 'lolita', 'shota', 'elementary school',
    'middle school', 'high school', 'school uniform', 'schoolgirl',
    'schoolboy', 'student', 'pupil', 'innocent', 'virginity',
    'virginity loss', 'defloration', 'first time', 'inexperienced',
    // Other explicit content
    'snuff', 'snuff film', 'bestiality', 'zoophilia', 'animal abuse',
    'animal cruelty', 'animal sex', 'dog sex', 'cat sex', 'horse sex',
    'necrophilia', 'corpse', 'dead body sex', 'scat', 'poop',
    'feces', 'vomit', 'bodily fluids', 'urine', 'menstruation',
    'period', 'miscarriage', 'abortion', 'fetus', 'embryo',
    'self harm', 'self injury', 'suicide', 'suicidal', 'cutting',
    'depression', 'mental illness', 'psychiatric', 'madness',
    'deformity', 'deformed', 'disability', 'disabled', 'handicapped',
    'crippled', 'blind', 'deaf', 'mute', 'dumb', 'deaf and dumb',
    'humiliation', 'humiliate', 'shame', 'ashamed', 'degradation',
    'degrade', 'dehumanization', 'dehumanize',
  ];

  bool _containsNSFWContent(String text) {
    final lowerText = text.toLowerCase();
    return _nsfwKeywords.any((keyword) => lowerText.contains(keyword));
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  bool _canGenerate() {
    if (_lastGenerationTime == null) return true;
    final now = DateTime.now();
    final difference = now.difference(_lastGenerationTime!).inSeconds;
    return difference >= _generationCooldownSeconds;
  }

  String? _validatePrompt(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a prompt';
    }
    if (trimmed.length < _promptMinLength) {
      return 'Prompt must be at least $_promptMinLength characters';
    }
    if (trimmed.length > _promptMaxLength) {
      return 'Prompt must not exceed $_promptMaxLength characters';
    }
    return null;
  }

  void _startCooldown() {
    _lastGenerationTime = DateTime.now();
  }

  void _onTextChanged() {
    final hasNSFW = _containsNSFWContent(_controller.text);
    if (hasNSFW != _hasNSFWContent) {
      setState(() {
        _hasNSFWContent = hasNSFW;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  // final List<String> aspectRatios = ['1:1', '16:9', '9:16', '4:3', '3:4'];
  final List<String> aspectRatios = ['16:9', '9:16'];
  final List<String> styles = [
    'Cyberpunk',
    'Hyperrealistic',
    'Oil Painting',
    'Cartoon',
    'Anime',
    '3D Render',
    'Photography',
    'Watercolor',
    'Minimalist',
    'Abstract',
  ];

  Future<String?> _downloadImage(String imageUrl) async {
    try {
      Uint8List bytes;
      if (imageUrl.startsWith('data:')) {
        final base64String = imageUrl.split(',')[1];
        bytes = base64Decode(base64String);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        bytes = response.bodyBytes;
      }
      final result = await ImageGallerySaverPlus.saveImage(bytes);
      if (result['isSuccess']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
        return result['filePath'];
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save image')));
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to download image')));
      return null;
    }
  }

  Future<void> _shareImage(String imageUrl, String prompt) async {
    try {
      Uint8List bytes;
      if (imageUrl.startsWith('data:')) {
        final base64String = imageUrl.split(',')[1];
        bytes = base64Decode(base64String);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        bytes = response.bodyBytes;
      }
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: prompt);
      file.delete();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to share image')));
    }
  }

  void _generateImage() {
    final validationError = _validatePrompt(_controller.text);
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    if (!_canGenerate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        // SnackBar(content: Text('Please wait $_remainingCooldown seconds before generating another image')),
        SnackBar(content: Text('Generating another image')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _generatedImageUrl = null;
    });

    final encodedPrompt = Uri.encodeComponent(_controller.text.trim());
    final imageUrl =
        'https://gen.pollinations.ai/image/$encodedPrompt?model=$_model&key=$apiKey';

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _generatedImageUrl = imageUrl;
          _loading = false;
        });
        _startCooldown();
      }
    });
  }

  // Return prompt with NSFW keywords removed/replaced
  String _sanitizedPrompt() {
    var text = _controller.text.trim();
    if (text.isEmpty) return '';
    var lower = text.toLowerCase();
    for (final kw in _nsfwKeywords) {
      if (lower.contains(kw)) {
        // replace occurrences case-insensitively
        text = text.replaceAll(RegExp(kw, caseSensitive: false), '[removed]');
      }
    }
    return text;
  }

  // Return list of excluded (matched) keywords found in prompt
  List<String> _excludedKeywordsInPrompt() {
    final text = _controller.text.toLowerCase();
    final found = <String>[];
    for (final kw in _nsfwKeywords) {
      if (text.contains(kw)) {
        found.add(kw);
      }
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PROMPT INPUT
            Card(
              elevation: 4,
              color: _hasNSFWContent ? Colors.red.withOpacity(0.1) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _hasNSFWContent ? Colors.red : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      maxLines: 3,
                      maxLength: _promptMaxLength,
                      decoration: InputDecoration(
                        hintText: 'Describe the image you want to generate...',
                        border: InputBorder.none,
                        errorText: _hasNSFWContent
                            ? 'Contains explicit content'
                            : _validatePrompt(_controller.text),
                        counterText:
                            '${_controller.text.length}/$_promptMaxLength',
                        counterStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_controller.text.length < _promptMinLength &&
                        _controller.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'At least $_promptMinLength characters required',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : (_canGenerate() ? _generateImage : null),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  disabledBackgroundColor: const Color(0xFF5A2FA0),
                ),
                child: const Text(
                  '✨ Generate Image',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ASPECT RATIO SECTION
            const Text(
              'Aspect Ratio',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: aspectRatios.map((ratio) {
                  final isSelected = _selectedAspectRatio == ratio;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(ratio),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedAspectRatio = ratio);
                      },
                      backgroundColor: const Color(0xFF1E1E1E),
                      selectedColor: const Color(0xFF7C3AED),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // GENERATION STYLE SECTION
            const Text(
              'Generation Style',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: styles.map((style) {
                final isSelected = _selectedStyle == style;
                return FilterChip(
                  label: Text(style),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedStyle = style);
                  },
                  backgroundColor: const Color(0xFF1E1E1E),
                  selectedColor: const Color(0xFF7C3AED),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            if (_generatedImageUrl != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share),

                            onPressed: () => _shareImage(
                              _generatedImageUrl!,
                              _controller.text.trim(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () =>
                                _downloadImage(_generatedImageUrl!),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: _generatedImageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Final prompt / excluded keywords / style / aspect ratio
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prompt: ${_sanitizedPrompt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Excluded: ${_excludedKeywordsInPrompt().isEmpty ? 'None' : _excludedKeywordsInPrompt().join(', ')}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Style: $_selectedStyle • Aspect: $_selectedAspectRatio',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- DETAIL ----------------
class DetailPage extends StatelessWidget {
  final AiImage aiImage;

  const DetailPage({super.key, required this.aiImage});

  // Rate limiting for downloads
  static final DateTime _lastDownloadTime = DateTime(2000);
  static const int _downloadCooldownSeconds = 2;

  Future<String?> _downloadImage(BuildContext context, String imageUrl) async {
    // Rate limit check
    final now = DateTime.now();
    final difference = now.difference(_lastDownloadTime).inSeconds;
    if (difference < _downloadCooldownSeconds &&
        _lastDownloadTime.year > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait ${_downloadCooldownSeconds - difference}s before downloading',
          ),
        ),
      );
      return null;
    }

    try {
      Uint8List bytes;
      if (imageUrl.startsWith('data:')) {
        final base64String = imageUrl.split(',')[1];
        bytes = base64Decode(base64String);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        bytes = response.bodyBytes;
      }
      final result = await ImageGallerySaverPlus.saveImage(bytes);
      if (result['isSuccess']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
        return result['filePath'];
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save image')));
        return null;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to download image')));
      return null;
    }
  }

  Future<void> _shareImage(
    BuildContext context,
    String imageUrl,
    String prompt,
  ) async {
    try {
      Uint8List bytes;
      if (imageUrl.startsWith('data:')) {
        final base64String = imageUrl.split(',')[1];
        bytes = base64Decode(base64String);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        bytes = response.bodyBytes;
      }
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: prompt);
      file.delete();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to share image')));
    }
  }

  void _copyPrompt(BuildContext context, String prompt) async {
    await Clipboard.setData(ClipboardData(text: prompt));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Prompt copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Prompt Details", style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () =>
                _shareImage(context, aiImage.imageUrl, aiImage.prompt),
          ),
        ],
      ),
      body: Column(
        children: [
          // IMAGE
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: aiImage.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          ),

          // PROMPT BOX
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "PROMPT TEXT",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Updated today",
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    aiImage.prompt,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // COPY BUTTON
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _copyPrompt(context, aiImage.prompt),
                icon: const Icon(Icons.copy),
                label: const Text(
                  "Copy Prompt",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- TAB CHIP ----------------
class TabChip extends StatelessWidget {
  final String title;
  final bool isSelected;

  const TabChip({super.key, required this.title, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor: isSelected ? Colors.white : const Color(0xFF1E1E1E),
        label: Text(
          title,
          style: TextStyle(color: isSelected ? Colors.black : Colors.white),
        ),
      ),
    );
  }
}

// ---------------- GALLERY DISCOVERY CARD ----------------
class GalleryDiscoveryCard extends StatelessWidget {
  final AiImage aiImage;
  final VoidCallback onTap;

  const GalleryDiscoveryCard({
    super.key,
    required this.aiImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promptWords = aiImage.prompt.split(' ');
    final shortTitle = promptWords.length > 3
        ? '${promptWords.take(3).join(' ')}...'
        : aiImage.prompt;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: aiImage.imageUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: aiImage.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
}

// ---------------- SETTINGS PAGE ----------------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101622),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Settings Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF256AF4).withOpacity(0.8),
                    const Color(0xFF256AF4).withOpacity(0.6),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.t('settingsTitle'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customize your experience',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // Settings Menu Items
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // _settingsMenuItem(
                  //   icon: Icons.palette_outlined,
                  //   title: AppLocalizations.t('themeTitle'),
                  //   subtitle: 'Dark / Light / System',
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (_) => const ThemeSettingsPage(),
                  //       ),
                  //     );
                  //   },
                  // ),
                  _settingsMenuItem(
                    icon: Icons.language_outlined,
                    title: AppLocalizations.t('languageTitle'),
                    subtitle: 'English / Español',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LanguageSettingsPage(),
                        ),
                      );
                    },
                  ),
                  _settingsMenuItem(
                    icon: Icons.help_outline,
                    title: AppLocalizations.t('helpSupport'),
                    subtitle: 'Send us an email',
                    onTap: () async {
                      final email = Uri(
                        scheme: 'mailto',
                        path: 'hello@gmail.com',
                        queryParameters: {
                          'subject': 'Luma AI Support',
                          'body': 'Hi team,\n\nI need help with...\n',
                        },
                      );
                      if (await canLaunchUrl(email)) {
                        await launchUrl(email);
                      }
                    },
                  ),
                  _settingsMenuItem(
                    icon: Icons.info_outline,
                    title: AppLocalizations.t('aboutApp'),
                    subtitle: 'Version, terms',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AppInfoPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.red : Colors.white70),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDestructive ? Colors.red : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white30),
          ],
        ),
      ),
    );
  }
}

// ---------------- THEME SETTINGS PAGE ----------------
class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101622),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Theme'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.themeMode,
          builder: (context, themeMode, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select an app theme.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                RadioListTile<ThemeMode>(
                  title: const Text('System'),
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) AppSettings.setThemeMode(val);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) AppSettings.setThemeMode(val);
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) AppSettings.setThemeMode(val);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------- LANGUAGE SETTINGS PAGE ----------------
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101622),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Language'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<Locale>(
          valueListenable: AppSettings.locale,
          builder: (context, locale, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select your preferred language.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                RadioListTile<Locale>(
                  title: const Text('English'),
                  value: const Locale('en'),
                  groupValue: locale,
                  onChanged: (val) {
                    if (val != null) AppSettings.setLocale(val);
                  },
                ),
                RadioListTile<Locale>(
                  title: const Text('Español'),
                  value: const Locale('es'),
                  groupValue: locale,
                  onChanged: (val) {
                    if (val != null) AppSettings.setLocale(val);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------- APP INFO PAGE ----------------
class AppInfoPage extends StatelessWidget {
  const AppInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "App Information",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // APP HEADER
            Center(
              child: Column(
                children: [
                  Image.asset('assets/icons/logo.png', width: 200, height: 200),
                  // const Icon(
                  //   Icons.auto_awesome,
                  //   size: 64,
                  //   color: Color(0xFF7C3AED),
                  // ),
                  const SizedBox(height: 12),
                  const Text(
                    'Luma AI',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ABOUT APP SECTION
            const Text(
              'About App',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Luma AI is a cutting-edge application that uses advanced AI models to create stunning images from text descriptions. Simply describe what you want to see, and let our AI bring your imagination to life.\n\n'
                  'Features:\n'
                  '• Generate images using Flux AI model\n'
                  '• Multiple aspect ratios and styles\n'
                  '• Save images to your gallery\n'
                  '• Share images with friends\n'
                  '• View and manage your image collection',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ABOUT US SECTION
            const Text(
              'About Us',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'We are a team of passionate developers dedicated to bringing AI technology to everyone. Our mission is to make powerful AI tools accessible, easy-to-use, and enjoyable for creators worldwide.\n\n'
                  'We believe in the power of artificial intelligence to inspire creativity and transform ideas into reality. Our commitment is to continuously improve and innovate to provide you with the best AI image generation experience.\n\n'
                  'Thank you for using Luma AI!',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // TERMS OF SERVICE SECTION
            const Text(
              'Terms of Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '1. Acceptable Use\n'
                  'You agree not to use this application for generating inappropriate, offensive, or illegal content. Any NSFW content is strictly prohibited.\n\n'
                  '2. Content Ownership\n'
                  'You retain ownership of images you generate. However, by using this service, you grant us permission to use generated images for improving our AI models.\n\n'
                  '3. Disclaimer\n'
                  'This application is provided "as is" without warranties. We are not responsible for any issues or damages arising from the use of this application.\n\n'
                  '4. API Usage\n'
                  'This application uses third-party APIs. Usage is subject to their terms and conditions.\n\n'
                  '5. Privacy\n'
                  'Your privacy is important to us. We do not store your prompts or personal information on our servers.\n\n'
                  '6. Changes to Terms\n'
                  'We reserve the right to modify these terms at any time. Continued use of the application constitutes acceptance of updated terms.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // FOOTER
            Center(
              child: Text(
                '© 2026 Luma AI. All rights reserved.',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
