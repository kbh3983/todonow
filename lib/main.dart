import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'camera_page.dart';

void main() {
  runApp(const ChronosApp());
}

class ChronosApp extends StatelessWidget {
  const ChronosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chronos Timestamp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          surface: const Color(0xFF161922),
          primary: const Color(0xFF6366F1),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<TimestampEntry> _entries = [];
  double _uiScale = 0.9; // Default to 0.9 for a smaller, cleaner look
  late ValueNotifier<List<TimestampEntry>> _entriesNotifier;
  final ImagePicker _picker = ImagePicker();

  Map<String, Color> _categoryIndicatorColors = {
    'General': const Color(0xFF6366F1),
  };

  List<String> get _categories => _categoryIndicatorColors.keys.toList();

  Color _getCategoryColor(String category) {
    return _categoryIndicatorColors[category] ?? const Color(0xFF64748B);
  }

  @override
  void initState() {
    super.initState();
    _entriesNotifier = ValueNotifier<List<TimestampEntry>>([]);
    _loadCategories().then((_) => _loadEntries());
    _loadUiScale();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? catsJson = prefs.getString('chronos_categories');
    if (catsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(catsJson);
      setState(() {
        _categoryIndicatorColors = decoded.map(
          (key, value) => MapEntry(key, Color(value as int)),
        );
      });
    } else {
      setState(() {
        _categoryIndicatorColors = {
          'General': const Color(0xFF6366F1),
        };
      });
    }
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, int> encoded = _categoryIndicatorColors.map(
      (key, value) => MapEntry(key, value.value),
    );
    await prefs.setString('chronos_categories', jsonEncode(encoded));
  }

  void _addCategory(String name, Color color) {
    setState(() {
      _categoryIndicatorColors[name] = color;
    });
    _saveCategories();
  }

  void _deleteCategory(String category) {
    if (category == 'General') return;
    setState(() {
      _categoryIndicatorColors.remove(category);
      _entries.removeWhere((e) => e.category == category);
      _entriesNotifier.value = List.from(_entries);
    });
    _saveCategories();
    _saveEntries();
  }

  Future<void> _loadUiScale() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uiScale = prefs.getDouble('ui_scale') ?? 0.9;
    });
  }

  Future<void> _saveUiScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ui_scale', scale);
    setState(() {
      _uiScale = scale;
    });
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161922),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.display_settings_rounded, size: 20, color: Color(0xFF6366F1)),
                      const SizedBox(width: 12),
                      Text(
                        'DISPLAY SETTINGS',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adjust the overall scale of fonts and widgets.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildScaleOption(context, 'Tiny', 0.8),
                      _buildScaleOption(context, 'Compact', 0.9),
                      _buildScaleOption(context, 'Standard', 1.0),
                      _buildScaleOption(context, 'Large', 1.1),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScaleOption(BuildContext context, String label, double scale) {
    bool isSelected = (_uiScale - scale).abs() < 0.01;
    return GestureDetector(
      onTap: () {
        _saveUiScale(scale);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF232832),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
              ),
            ),
            child: Text(
              '${(scale * 100).toInt()}%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _entriesNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? entriesJson = prefs.getString('chronos_entries');
    if (entriesJson != null) {
      final List<dynamic> decoded = jsonDecode(entriesJson);
      setState(() {
        _entries = decoded
            .map((item) => TimestampEntry.fromJson(item))
            .toList();
        _entriesNotifier.value = _entries;
      });
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('chronos_entries', encoded);
  }

  void _onEntriesChanged(List<TimestampEntry> newEntries) {
    setState(() {
      _entries = newEntries;
      _entriesNotifier.value = _entries;
    });
    _saveEntries();
  }

  Future<String?> _saveImage(File? image) async {
    if (image == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    final fileName = path.basename(image.path);
    final savedImage = await image.copy('${directory.path}/$fileName');
    return savedImage.path;
  }

  void _deleteEntry(String id) {
    final updatedEntries = List<TimestampEntry>.from(_entries);
    updatedEntries.removeWhere((e) => e.id == id);
    _onEntriesChanged(updatedEntries);
  }

  void _clearCategory(String category) {
    final updatedEntries = List<TimestampEntry>.from(_entries);
    updatedEntries.removeWhere((e) => e.category == category);
    _onEntriesChanged(updatedEntries);
  }

  Future<void> _showDoneCompletionSheet(TimestampEntry entry) async {
    final TextEditingController doneNoteController = TextEditingController();
    File? doneImage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161922),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    size: 20,
                    color: _getCategoryColor(entry.category),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'COMPLETE MOMENT',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Add a final note or photo to close this chapter.',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              if (doneImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(
                          doneImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () => setSheetState(() => doneImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: doneNoteController,
                autofocus: true,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: null,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.none,
                decoration: InputDecoration(
                  hintText: 'What did you accomplish?',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.2),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, size: 22),
                        color: _getCategoryColor(entry.category),
                        onPressed: () async {
                          final XFile? img = await _picker.pickImage(
                            source: ImageSource.camera,
                          );
                          if (img != null)
                            setSheetState(() => doneImage = File(img.path));
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.photo_library_outlined,
                          size: 22,
                        ),
                        color: _getCategoryColor(entry.category),
                        onPressed: () async {
                          final XFile? img = await _picker.pickImage(
                            source: ImageSource.gallery,
                          );
                          if (img != null)
                            setSheetState(() => doneImage = File(img.path));
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    final String? savedPath = await _saveImage(doneImage);
                    final updatedEntries = List<TimestampEntry>.from(_entries);
                    final index = updatedEntries.indexWhere(
                      (e) => e.id == entry.id,
                    );
                    if (index != -1) {
                      updatedEntries[index] = TimestampEntry(
                        id: entry.id,
                        timestamp: entry.timestamp,
                        note: entry.note,
                        category: entry.category,
                        imagePath: entry.imagePath,
                        status: 'done',
                        doneTimestamp: DateTime.now(),
                        doneNote: doneNoteController.text.trim(),
                        doneImagePath: savedPath,
                      );
                      _onEntriesChanged(updatedEntries);
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getCategoryColor(entry.category),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'COMPLETE CHAPTER',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleEntryStatus(String id) {
    final updatedEntries = List<TimestampEntry>.from(_entries);
    final index = updatedEntries.indexWhere((e) => e.id == id);
    if (index != -1) {
      final entry = updatedEntries[index];
      if (entry.status == 'todo') {
        _showDoneCompletionSheet(entry);
      } else if (entry.status == 'done') {
        updatedEntries[index] = TimestampEntry(
          id: entry.id,
          timestamp: entry.timestamp,
          note: entry.note,
          category: entry.category,
          imagePath: entry.imagePath,
          status: 'todo',
          doneTimestamp: null,
          doneNote: null,
          doneImagePath: null,
        );
        _onEntriesChanged(updatedEntries);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomePage(
        entries: _entriesNotifier.value,
        onEntriesChanged: _onEntriesChanged,
        onDelete: _deleteEntry,
        onToggle: _toggleEntryStatus,
        getCategoryColor: _getCategoryColor,
        saveImage: _saveImage,
        uiScale: _uiScale,
        categories: _categories,
        onAddCategory: _addCategory,
      ),
      CategoryView(
        entriesNotifier: _entriesNotifier,
        onDelete: _deleteEntry,
        onToggle: _toggleEntryStatus,
        onClearCategory: _clearCategory,
        onDeleteCategory: _deleteCategory,
        uiScale: _uiScale,
        categories: _categories,
        categoryColors: _categoryIndicatorColors,
      ),
      InsightView(
        entriesNotifier: _entriesNotifier,
        uiScale: _uiScale,
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161922),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            if (index == 3) {
              _showSettingsMenu(context);
            } else {
              setState(() => _selectedIndex = index);
            }
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF6366F1),
          unselectedItemColor: Colors.white.withOpacity(0.3),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.timer_outlined),
              activeIcon: Icon(Icons.timer),
              label: 'Timeline',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph_outlined),
              activeIcon: Icon(Icons.auto_graph_rounded),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class TimestampEntry {
  final String id;
  final DateTime timestamp;
  final String note;
  final String category;
  final String? imagePath;
  final String status; // 'none', 'todo', 'done'
  final DateTime? doneTimestamp;
  final String? doneNote;
  final String? doneImagePath;
  final DateTime? targetDate;

  int? get computedDurationMinutes {
    if (status == 'done' && doneTimestamp != null) {
      return doneTimestamp!.difference(timestamp).inMinutes;
    }
    return null;
  }

  TimestampEntry({
    required this.id,
    required this.timestamp,
    required this.note,
    required this.category,
    this.imagePath,
    this.status = 'none',
    this.doneTimestamp,
    this.doneNote,
     this.doneImagePath,
    this.targetDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'note': note,
    'category': category,
    'imagePath': imagePath,
    'status': status,
    'doneTimestamp': doneTimestamp?.millisecondsSinceEpoch,
    'doneNote': doneNote,
     'doneImagePath': doneImagePath,
     'targetDate': targetDate?.millisecondsSinceEpoch,
  };

  factory TimestampEntry.fromJson(Map<String, dynamic> json) => TimestampEntry(
    id: json['id'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    note: json['note'] ?? "",
    category: json['category'] ?? "General",
    imagePath: json['imagePath'],
    status: json['status'] ?? "none",
    doneTimestamp: json['doneTimestamp'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['doneTimestamp'])
        : null,
    doneNote: json['doneNote'],
    doneImagePath: json['doneImagePath'],
       targetDate: json['targetDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['targetDate'])
        : null,
  );
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  _MarqueeTextState createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation();
    });
  }

  void _startAnimation() async {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    while (mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;
      
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 40).toInt()),
        curve: Curves.linear,
      );
      
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) break;

      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5 * _animation.value),
                blurRadius: 10 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAddHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onTap;
  final Color categoryColor;
  final double uiScale;

  _QuickAddHeaderDelegate({
    required this.onTap,
    required this.categoryColor,
    required this.uiScale,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF0D0F14),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF161922),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: categoryColor.withOpacity(0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: categoryColor.withOpacity(0.05),
                  blurRadius: 15,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Row(
              children: [
                _BlinkingDot(color: categoryColor),
                const SizedBox(width: 16),
                Text(
                  'What\'s on your mind?',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14 * uiScale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: categoryColor.withOpacity(0.5),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 82;

  @override
  double get minExtent => 82;

  @override
  bool shouldRebuild(covariant _QuickAddHeaderDelegate oldDelegate) {
    return oldDelegate.categoryColor != categoryColor || oldDelegate.uiScale != uiScale;
  }
}

class HomePage extends StatefulWidget {
  final List<TimestampEntry> entries;
  final Function(List<TimestampEntry>) onEntriesChanged;
  final Function(String) onDelete;
  final Function(String) onToggle;
  final Color Function(String) getCategoryColor;
  final Future<String?> Function(File?) saveImage;
  final double uiScale;
  final List<String> categories;
  final Function(String, Color) onAddCategory;

  const HomePage({
    super.key,
    required this.entries,
    required this.onEntriesChanged,
    required this.onDelete,
    required this.onToggle,
    required this.getCategoryColor,
    required this.saveImage,
    required this.uiScale,
    required this.categories,
    required this.onAddCategory,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late String _currentTime;
  late String _currentDate;
  late Timer _timer;
  final TextEditingController _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isTodo = false;
  DateTime? _targetDate;
  bool _showOnlyTodo = false;

  String _selectedCategory = 'General';

  Color _getCategoryColor(String category) {
    return widget.getCategoryColor(category);
  }

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _updateTime(),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(now);
        _currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
      });
    }
  }

  void _showAddCategoryDialog() {
    final TextEditingController controller = TextEditingController();
    Color selectedColor = const Color(0xFF6366F1);
    final List<Color> presetColors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161922),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'NEW CATEGORY',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Category Name',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.2),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'COLOUR',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presetColors.map((color) {
                  bool isSelected = selectedColor == color;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      widget.onAddCategory(name, selectedColor);
                      Navigator.pop(context);
                      setState(() => _selectedCategory = name);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'CREATE CATEGORY',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _saveImage(File? image) async {
    if (image == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    final fileName = path.basename(image.path);
    final savedImage = await image.copy('${directory.path}/$fileName');
    return savedImage.path;
  }

  Future<void> _pickImage(ImageSource source, {StateSetter? setSheetState}) async {
    if (source == ImageSource.camera) {
      final String? path = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (context) => const CameraPage()),
      );
      if (path != null) {
        setState(() {
          _selectedImage = File(path);
        });
        if (setSheetState != null) setSheetState(() {});
      }
    } else {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        if (setSheetState != null) setSheetState(() {});
      }
    }
  }

  void _showAddEntrySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161922),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.getCategoryColor(_selectedCategory).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: widget.getCategoryColor(_selectedCategory),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'RECORD MOMENT',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Category Selection
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...widget.categories.map((cat) {
                      bool isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedCategory = cat);
                            setSheetState(() {});
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.getCategoryColor(cat)
                                  : const Color(0xFF232832),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: GoogleFonts.inter(
                                fontSize: 13 * widget.uiScale,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    IconButton(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TODO Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 20,
                      color: _isTodo ? widget.getCategoryColor(_selectedCategory) : Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Mark as TODO',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(_isTodo ? 0.9 : 0.4),
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _isTodo,
                      onChanged: (val) {
                        setState(() => _isTodo = val);
                        setSheetState(() {});
                      },
                      activeColor: widget.getCategoryColor(_selectedCategory),
                    ),
                  ],
                ),
              ),

              if (_isTodo) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _targetDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: widget.getCategoryColor(_selectedCategory),
                            surface: const Color(0xFF161922),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _targetDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
                      });
                      setSheetState(() {});
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white.withOpacity(0.3)),
                        const SizedBox(width: 12),
                        Text(
                          'Deadline',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                        ),
                        const Spacer(),
                        Text(
                          _targetDate == null ? 'SELECT DATE' : DateFormat('yyyy-MM-dd').format(_targetDate!),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _targetDate != null ? widget.getCategoryColor(_selectedCategory) : Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),

              // Image Preview
              if (_selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.file(
                          _selectedImage!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedImage = null);
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Note Input
              TextField(
                controller: _noteController,
                maxLines: null,
                minLines: 3,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'What\'s happening?',
                  hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.2)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.camera_alt_outlined),
                          color: Colors.white.withOpacity(0.4),
                          onPressed: () => _pickImage(ImageSource.camera, setSheetState: setSheetState),
                        ),
                        IconButton(
                          icon: const Icon(Icons.photo_library_outlined),
                          color: Colors.white.withOpacity(0.4),
                          onPressed: () => _pickImage(ImageSource.gallery, setSheetState: setSheetState),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    _addTimestamp();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.getCategoryColor(_selectedCategory),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(
                    'RECORD MOMENT',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addTimestamp() async {
    final imagePath = await _saveImage(_selectedImage);
    final newEntry = TimestampEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      note: _noteController.text.trim(),
      category: _selectedCategory,
      imagePath: imagePath,
      status: _isTodo ? 'todo' : 'none',
      targetDate: _isTodo ? _targetDate : null,
    );

    final updatedEntries = List<TimestampEntry>.from(widget.entries);
    updatedEntries.insert(0, newEntry);
    widget.onEntriesChanged(updatedEntries);

    setState(() {
      _noteController.clear();
      _selectedImage = null;
      _isTodo = false;
      _targetDate = null;
    });
  }

  void _deleteEntry(String id) {
    widget.onDelete(id);
  }

  void _toggleEntryStatus(String id) {
    widget.onToggle(id);
  }

  Widget _buildUrgentCountdown() {
    final now = DateTime.now();

    TimestampEntry? selectedTodo;

    // 1. Separate TODOs into categories
    List<TimestampEntry> todayTodos = [];
    List<TimestampEntry> futureTodos = [];
    List<TimestampEntry> overdueTodos = [];
    List<TimestampEntry> noDeadlineTodos = [];

    for (var entry in widget.entries) {
      if (entry.status == 'todo') {
        if (entry.targetDate == null) {
          noDeadlineTodos.add(entry);
        } else {
          if (entry.targetDate!.year == now.year &&
              entry.targetDate!.month == now.month &&
              entry.targetDate!.day == now.day) {
            todayTodos.add(entry);
          } else if (entry.targetDate!.isAfter(now)) {
            futureTodos.add(entry);
          } else {
            overdueTodos.add(entry);
          }
        }
      }
    }

    // 2. Sorting Logic
    // Tie-breaker: creation timestamp (earliest first)
    todayTodos.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Future: Closest target date first, then earliest creation timestamp
    futureTodos.sort((a, b) {
      int dateCompare = a.targetDate!.compareTo(b.targetDate!);
      if (dateCompare != 0) return dateCompare;
      return a.timestamp.compareTo(b.timestamp);
    });

    overdueTodos.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    noDeadlineTodos.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 3. Selection Priority
    if (todayTodos.isNotEmpty) {
      selectedTodo = todayTodos.first;
    } else if (futureTodos.isNotEmpty) {
      selectedTodo = futureTodos.first;
    } else if (overdueTodos.isNotEmpty) {
      selectedTodo = overdueTodos.first;
    } else if (noDeadlineTodos.isNotEmpty) {
      selectedTodo = noDeadlineTodos.first;
    }

    if (selectedTodo == null) {
      // --- Quote Banner ---
      final quotes = [
        "Lost time is never found again.",
        "Your time is limited, don't waste it.",
        "Time is what we want most, but use worst.",
        "The way we spend our time defines who we are.",
        "Punctuality is the soul of business.",
        "Time is money.",
        "Better late than never, but never late is better.",
        "Time flies like an arrow.",
        "Master your time, master your life.",
        "Chronos watches over your moments.",
      ];
      // Rotate every 10 seconds
      final quoteIndex = (now.millisecondsSinceEpoch ~/ 10000) % quotes.length;

      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quotes[quoteIndex].toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9 * widget.uiScale,
              color: Colors.white.withOpacity(0.3),
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final bool hasDeadline = selectedTodo.targetDate != null;
    final diff = hasDeadline
        ? selectedTodo.targetDate!.difference(now)
        : Duration.zero;
    final isOverdue = hasDeadline && diff.isNegative;
    final absDuration = diff.abs();

    final h = absDuration.inHours;
    final m = absDuration.inMinutes % 60;
    final s = absDuration.inSeconds % 60;

    final timeStr = hasDeadline
        ? '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m ${s.toString().padLeft(2, '0')}s'
        : 'NO DEADLINE';

    final statusText = !hasDeadline
        ? 'TASK'
        : isOverdue
        ? 'EXPIRED'
        : 'URGENT';

    final noteText = selectedTodo.note.isNotEmpty
        ? selectedTodo.note
        : 'Untitled Task';

    final mainColor = !hasDeadline
        ? widget.getCategoryColor(selectedTodo.category).withOpacity(0.5)
        : isOverdue
        ? const Color(0xFFEF4444)
        : widget.getCategoryColor(selectedTodo.category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: mainColor,
                shape: BoxShape.circle,
                boxShadow: [
                  if (hasDeadline)
                    BoxShadow(color: mainColor.withOpacity(0.5), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _MarqueeText(
                text: '$statusText: $noteText',
                style: GoogleFonts.inter(
                  fontSize: 12 * widget.uiScale,
                  color: mainColor,
                  letterSpacing: 0.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          hasDeadline
              ? (isOverdue ? '$timeStr ago' : '$timeStr left')
              : 'NO DEADLINE',
          style: GoogleFonts.inter(
            fontSize: 10 * widget.uiScale,
            color: Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status Display
                    _buildUrgentCountdown(),
                    const SizedBox(height: 16),

                    // Header (Compact)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            _currentTime,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 48 * widget.uiScale,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -2,
                            ),
                          ),
                          Text(
                            _currentDate.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.3),
                              fontWeight: FontWeight.w800,
                              fontSize: 10 * widget.uiScale,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            
            // Pinned Quick Add Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _QuickAddHeaderDelegate(
                onTap: _showAddEntrySheet,
                categoryColor: widget.getCategoryColor(_selectedCategory),
                uiScale: widget.uiScale,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'RECENT HISTORY',
                          style: GoogleFonts.inter(
                            fontSize: 10 * widget.uiScale,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.5),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showOnlyTodo = !_showOnlyTodo),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _showOnlyTodo
                              ? widget.getCategoryColor(_selectedCategory).withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _showOnlyTodo
                                ? widget.getCategoryColor(_selectedCategory).withOpacity(0.3)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showOnlyTodo
                                  ? Icons.filter_list_rounded
                                  : Icons.filter_list_off_rounded,
                              size: 14,
                              color: _showOnlyTodo
                                  ? widget.getCategoryColor(_selectedCategory)
                                  : Colors.white.withOpacity(0.4),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TODO ONLY',
                              style: GoogleFonts.inter(
                                fontSize: 9 * widget.uiScale,
                                fontWeight: _showOnlyTodo
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _showOnlyTodo
                                    ? widget.getCategoryColor(_selectedCategory)
                                    : Colors.white.withOpacity(0.4),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.entries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        size: 48,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No records yet',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_showOnlyTodo &&
                !widget.entries.any((e) => e.status == 'todo'))
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_list_off_rounded,
                        size: 48,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No TODOs found',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final filteredEntries = _showOnlyTodo
                          ? widget.entries
                                .where((e) => e.status == 'todo')
                                .toList()
                          : widget.entries;

                      if (index >= filteredEntries.length) return null;

                      final entry = filteredEntries[index];
                      return TimestampListItem(
                        entry: entry,
                        categoryColor: _getCategoryColor(entry.category),
                        onDelete: () => _deleteEntry(entry.id),
                        onStatusToggle: () => _toggleEntryStatus(entry.id),
                        uiScale: widget.uiScale,
                      );
                    },
                    childCount: _showOnlyTodo
                        ? widget.entries.where((e) => e.status == 'todo').length
                        : widget.entries.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TimestampListItem extends StatefulWidget {
  final TimestampEntry entry;
  final Color categoryColor;
  final VoidCallback onDelete;
  final VoidCallback onStatusToggle;
  final double uiScale;

  const TimestampListItem({
    super.key,
    required this.entry,
    required this.categoryColor,
    required this.onDelete,
    required this.onStatusToggle,
    required this.uiScale,
  });

  @override
  State<TimestampListItem> createState() => _TimestampListItemState();
}

class _TimestampListItemState extends State<TimestampListItem> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getDurationString(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  Color _getAdjustedColor() {
    final hsl = HSLColor.fromColor(widget.categoryColor);
    if (widget.entry.status == 'todo') {
      double factor;
      if (widget.entry.targetDate != null) {
        final now = DateTime.now();
        final totalDuration = widget.entry.targetDate!.difference(widget.entry.timestamp).inSeconds;
        final elapsed = now.difference(widget.entry.timestamp).inSeconds;
        factor = totalDuration <= 0 ? 1.0 : (elapsed / totalDuration).clamp(0.0, 1.0);
      } else {
        final age = DateTime.now().difference(widget.entry.timestamp);
        factor = (age.inSeconds / 86400.0).clamp(0.0, 1.0);
      }
      final newSaturation = (hsl.saturation + (0.3 * factor)).clamp(0.0, 1.0);
      return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).withSaturation(newSaturation).toColor();
    } else if (widget.entry.status == 'done') {
      return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    }
    return widget.categoryColor;
  }

  @override
  Widget build(BuildContext context) {
    final bool isExpandable = widget.entry.note.length > 40 ||
        widget.entry.note.contains('\n') ||
        widget.entry.imagePath != null ||
        widget.entry.status == 'todo' ||
        widget.entry.doneNote != null ||
        widget.entry.doneImagePath != null;

    final adjustedColor = _getAdjustedColor();

    return GestureDetector(
      onTap: isExpandable ? () => setState(() => _isExpanded = !_isExpanded) : null,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final pulseValue = widget.entry.status == 'todo' ? _pulseAnimation.value : 1.0;
          return CustomPaint(
            painter: widget.entry.status == 'todo' 
                ? DashedBorderPainter(color: adjustedColor.withOpacity(0.5 * pulseValue)) 
                : null,
            child: Container(
              margin: EdgeInsets.only(bottom: 16 * widget.uiScale),
              padding: EdgeInsets.all(20 * widget.uiScale),
              decoration: BoxDecoration(
                color: widget.entry.status == 'todo'
                    ? adjustedColor.withOpacity(0.12 * pulseValue)
                    : const Color(0xFF161922),
                borderRadius: BorderRadius.circular(24),
                border: widget.entry.status == 'todo'
                    ? Border.all(color: adjustedColor.withOpacity(0.2 * pulseValue), width: 1.5)
                    : Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: widget.entry.status == 'todo'
                    ? [
                        BoxShadow(
                          color: adjustedColor.withOpacity(0.1 * pulseValue),
                          blurRadius: 15 * pulseValue,
                          spreadRadius: 2 * pulseValue,
                        ),
                      ]
                    : null,
              ),
              child: Opacity(
                opacity: widget.entry.status == 'todo' ? 1.0 : 1.0,
                child: Row(
                  children: [
                    // Status Toggle Circle
                    SizedBox(
                      width: 36,
                      child: GestureDetector(
                        onTap: widget.onStatusToggle,
                        child: widget.entry.status == 'todo'
                            ? AnimatedScale(
                                duration: const Duration(milliseconds: 200),
                                scale: 1.1,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: adjustedColor.withOpacity(0.05),
                                    border: Border.all(color: adjustedColor.withOpacity(0.5), width: 2.0),
                                    boxShadow: [BoxShadow(color: adjustedColor.withOpacity(0.1), blurRadius: 10)],
                                  ),
                                  child: Center(
                                    child: Icon(Icons.check_rounded, size: 20, color: adjustedColor.withOpacity(0.7)),
                                  ),
                                ),
                              )
                            : Container(
                                width: 14,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: adjustedColor,
                                  borderRadius: BorderRadius.circular(7),
                                  boxShadow: [BoxShadow(color: adjustedColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
                                ),
                                child: widget.entry.status == 'done' 
                                    ? const Center(child: Icon(Icons.check_rounded, size: 10, color: Colors.white)) 
                                    : null,
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: adjustedColor.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                                child: Text(widget.entry.category.toUpperCase(), style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.bold, color: adjustedColor.withOpacity(0.8), letterSpacing: 1.2)),
                              ),
                              if (widget.entry.status == 'todo') ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: adjustedColor, borderRadius: BorderRadius.circular(7)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('TODO', style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.entry.note.isEmpty ? 'Recorded Moment' : widget.entry.note,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: _isExpanded ? null : 5,
                            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.entry.timestamp), style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.4))),
                            ],
                          ),
                          // Target Date (TODO ONLY)
                          if (widget.entry.status == 'todo' && widget.entry.targetDate != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.event_available_rounded, size: 12, color: adjustedColor.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text(DateFormat('yyyy-MM-dd').format(widget.entry.targetDate!), style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.w600, color: adjustedColor.withOpacity(0.6))),
                                const Spacer(),
                                if (DateTime.now().isAfter(widget.entry.targetDate!))
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1 + (0.1 * _pulseAnimation.value)),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.red.withOpacity(0.3 + (0.2 * _pulseAnimation.value))),
                                        ),
                                        child: Text('OVERDUE', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.red)),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ],
                          // Image
                          if (widget.entry.imagePath != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(widget.entry.imagePath!), width: double.infinity, fit: BoxFit.fitWidth),
                              ),
                            ),
                          // Completed Info
                          if (widget.entry.status == 'done' && widget.entry.doneTimestamp != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('COMPLETED', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: adjustedColor, letterSpacing: 0.5)),
                                const SizedBox(width: 8),
                                Icon(Icons.timer_rounded, size: 11, color: adjustedColor.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text(_getDurationString(widget.entry.timestamp, widget.entry.doneTimestamp!), style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w500, color: adjustedColor.withOpacity(0.6))),
                              ],
                            ),
                            if (widget.entry.doneNote != null && widget.entry.doneNote!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(widget.entry.doneNote!, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            if (widget.entry.doneImagePath != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(widget.entry.doneImagePath!), width: double.infinity, fit: BoxFit.fitWidth),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete Button
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.2), size: 22),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 5,
    this.dashSpace = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height - 16, // Matching the margin set in Container
      const Radius.circular(24),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    for (final ui.PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}

class CategoryView extends StatelessWidget {
  final ValueNotifier<List<TimestampEntry>> entriesNotifier;
  final Function(String) onDelete;
  final Function(String) onToggle;
  final Function(String) onClearCategory;
  final Function(String) onDeleteCategory;
  final double uiScale;
  final List<String> categories;
  final Map<String, Color> categoryColors;

  const CategoryView({
    super.key,
    required this.entriesNotifier,
    required this.onDelete,
    required this.onToggle,
    required this.onClearCategory,
    required this.onDeleteCategory,
    required this.uiScale,
    required this.categories,
    required this.categoryColors,
  });

  final Map<String, IconData> _categoryIcons = const {
    'General': Icons.folder_outlined,
    'Work': Icons.work_outline,
    'Personal': Icons.person_outline,
    'Health': Icons.favorite_outline,
    'Study': Icons.book_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categories',
                style: GoogleFonts.inter(
                  fontSize: 28 * uiScale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Browse your moments by type',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 15 * uiScale,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ValueListenableBuilder<List<TimestampEntry>>(
                  valueListenable: entriesNotifier,
                  builder: (context, currentEntries, _) {
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final count = currentEntries
                            .where((e) => e.category == cat)
                            .length;
                        final color = categoryColors[cat] ?? Colors.grey;

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CategoryDetailView(
                                  category: cat,
                                  entriesNotifier: entriesNotifier,
                                  categoryColor: color,
                                  onDelete: onDelete,
                                  onToggle: onToggle,
                                  onClearCategory: onClearCategory,
                                  uiScale: uiScale,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161922),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: color.withOpacity(0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        _categoryIcons[cat] ??
                                            Icons.label_outline,
                                        color: color,
                                        size: 24,
                                      ),
                                    ),
                                    if (cat != 'General')
                                      IconButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor:
                                                  const Color(0xFF161922),
                                              title: Text(
                                                'Delete Category?',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              content: Text(
                                                'This will delete "$cat" and ALL associated entries. This cannot be undone.',
                                                style: GoogleFonts.inter(),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    'CANCEL',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white
                                                          .withOpacity(0.5),
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    onDeleteCategory(cat);
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text(
                                                    'DELETE',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18 * uiScale,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$count ${count == 1 ? 'entry' : 'entries'}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 13 * uiScale,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryDetailView extends StatefulWidget {
  final String category;
  final ValueNotifier<List<TimestampEntry>> entriesNotifier;
  final Color categoryColor;
  final Function(String) onDelete;
  final Function(String) onToggle;
  final Function(String) onClearCategory;
  final double uiScale;

  const CategoryDetailView({
    super.key,
    required this.category,
    required this.entriesNotifier,
    required this.categoryColor,
    required this.onDelete,
    required this.onToggle,
    required this.onClearCategory,
    required this.uiScale,
  });

  @override
  State<CategoryDetailView> createState() => _CategoryDetailViewState();
}

class _CategoryDetailViewState extends State<CategoryDetailView> {
  late Timer _timer;
  bool _showOnlyTodo = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 18 * widget.uiScale,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF161922),
                  title: Text(
                    'Clear Category?',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    'Delete all records in ${widget.category}?',
                    style: GoogleFonts.inter(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onClearCategory(widget.category);
                        Navigator.pop(context);
                      },
                      child: Text(
                        'CLEAR ALL',
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            tooltip: 'Clear All in Category',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              onPressed: () => setState(() => _showOnlyTodo = !_showOnlyTodo),
              icon: Icon(
                _showOnlyTodo
                    ? Icons.filter_list_rounded
                    : Icons.filter_list_off_rounded,
                color: _showOnlyTodo
                    ? widget.categoryColor
                    : Colors.white.withOpacity(0.4),
                size: 20,
              ),
              tooltip: 'Filter TODO Only',
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<TimestampEntry>>(
        valueListenable: widget.entriesNotifier,
        builder: (context, currentEntries, _) {
          final categoryEntries = currentEntries
              .where((e) => e.category == widget.category)
              .toList();

          final filteredEntries = _showOnlyTodo
              ? categoryEntries.where((e) => e.status == 'todo').toList()
              : categoryEntries;

          if (categoryEntries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 48,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No entries in this category',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (filteredEntries.isEmpty && _showOnlyTodo) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.filter_list_off_rounded,
                    size: 48,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No TODOs in this category',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: filteredEntries.length,
            itemBuilder: (context, index) {
              final entry = filteredEntries[index];
              return TimestampListItem(
                entry: entry,
                categoryColor: widget.categoryColor,
                onDelete: () => widget.onDelete(entry.id),
                onStatusToggle: () => widget.onToggle(entry.id),
                uiScale: widget.uiScale,
              );
            },
          );
        },
      ),
    );
  }
}

class InsightView extends StatefulWidget {
  final ValueNotifier<List<TimestampEntry>> entriesNotifier;
  final double uiScale;

  const InsightView({
    super.key, 
    required this.entriesNotifier,
    required this.uiScale,
  });

  @override
  State<InsightView> createState() => _InsightViewState();
}

class _InsightViewState extends State<InsightView> {
  String _selectedFilter = 'All Time';
  final List<String> _filters = ['All Time', 'Day', 'Week', 'Month', 'Year'];
  DateTime _referenceDate = DateTime.now();
  String _selectedCalendarCategory = 'All';
  DateTime? _selectedCalendarDay;
  final List<String> _sectionOrder = [
    'ACTIVITY CALENDAR',
    'WHERE MY TIME GOES',
  ];

  void _previousPeriod() {
    setState(() {
      if (_selectedFilter == 'Day') {
        _referenceDate = _referenceDate.subtract(const Duration(days: 1));
      } else if (_selectedFilter == 'Week') {
        _referenceDate = _referenceDate.subtract(const Duration(days: 7));
      } else if (_selectedFilter == 'Month') {
        _referenceDate = DateTime(
          _referenceDate.year,
          _referenceDate.month - 1,
          _referenceDate.day,
        );
      } else if (_selectedFilter == 'Year') {
        _referenceDate = DateTime(
          _referenceDate.year - 1,
          _referenceDate.month,
          _referenceDate.day,
        );
      }
      _selectedCalendarDay = null;
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_selectedFilter == 'Day') {
        _referenceDate = _referenceDate.add(const Duration(days: 1));
      } else if (_selectedFilter == 'Week') {
        _referenceDate = _referenceDate.add(const Duration(days: 7));
      } else if (_selectedFilter == 'Month') {
        _referenceDate = DateTime(
          _referenceDate.year,
          _referenceDate.month + 1,
          _referenceDate.day,
        );
      } else if (_selectedFilter == 'Year') {
        _referenceDate = DateTime(
          _referenceDate.year + 1,
          _referenceDate.month,
          _referenceDate.day,
        );
      }
      _selectedCalendarDay = null;
    });
  }

  void _previousMonth() {
    setState(() {
      _referenceDate = DateTime(
        _referenceDate.year,
        _referenceDate.month - 1,
        1,
      );
      _selectedCalendarDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _referenceDate = DateTime(
        _referenceDate.year,
        _referenceDate.month + 1,
        1,
      );
      _selectedCalendarDay = null;
    });
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (context) {
        DateTime tempDate = _referenceDate;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161922),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Month',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  DropdownButton<int>(
                    value: tempDate.year,
                    dropdownColor: const Color(0xFF161922),
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                    underline: Container(),
                    items: List.generate(21, (i) => 2020 + i)
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (y) {
                      if (y != null)
                        setDialogState(
                          () => tempDate = DateTime(y, tempDate.month),
                        );
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                height: 240,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected =
                        _referenceDate.year == tempDate.year &&
                        _referenceDate.month == month;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _referenceDate = DateTime(tempDate.year, month, 1);
                          _selectedCalendarDay = null;
                        });
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat('MMM').format(DateTime(2024, month)),
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.7),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getPeriodLabel() {
    if (_selectedFilter == 'Day') {
      return DateFormat('MMM d, yyyy').format(_referenceDate);
    } else if (_selectedFilter == 'Week') {
      final startOfWeek = _referenceDate.subtract(
        Duration(days: _referenceDate.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final startStr = DateFormat('MMM d').format(startOfWeek);
      final endStr = DateFormat('MMM d, yyyy').format(endOfWeek);
      return '$startStr - $endStr';
    } else if (_selectedFilter == 'Month') {
      return DateFormat('MMMM yyyy').format(_referenceDate);
    } else if (_selectedFilter == 'Year') {
      return DateFormat('yyyy').format(_referenceDate);
    }
    return '';
  }

  List<TimestampEntry> _getFilteredEntries(List<TimestampEntry> allEntries) {
    if (_selectedFilter == 'All Time') return allEntries;

    return allEntries.where((entry) {
      if (_selectedFilter == 'Day') {
        return entry.timestamp.year == _referenceDate.year &&
            entry.timestamp.month == _referenceDate.month &&
            entry.timestamp.day == _referenceDate.day;
      } else if (_selectedFilter == 'Week') {
        final startOfWeek = _referenceDate.subtract(
          Duration(days: _referenceDate.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        return entry.timestamp.isAfter(
              startOfWeek.subtract(const Duration(seconds: 1)),
            ) &&
            entry.timestamp.isBefore(endOfWeek.add(const Duration(seconds: 1)));
      } else if (_selectedFilter == 'Month') {
        return entry.timestamp.year == _referenceDate.year &&
            entry.timestamp.month == _referenceDate.month;
      } else if (_selectedFilter == 'Year') {
        return entry.timestamp.year == _referenceDate.year;
      }
      return true;
    }).toList();
  }

  Widget _buildSectionCard({
    required String title,
    Widget? selector,
    required Widget content,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.3),
              letterSpacing: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.2),
                fontSize: 12,
              ),
            ),
          ],
          if (selector != null) ...[const SizedBox(height: 20), selector],
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<List<TimestampEntry>>(
          valueListenable: widget.entriesNotifier,
          builder: (context, entries, _) {
            final filteredEntries = _getFilteredEntries(entries);
            final totalCount = filteredEntries.length;
            final categoryStats = _calculateStats(filteredEntries);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 16),

                      ..._sectionOrder.map((section) {
                        if (section == 'WHERE MY TIME GOES') {
                          return _buildSectionCard(
                            title: 'WHERE MY TIME GOES',
                            selector: Column(
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _filters.map((filter) {
                                      final isSelected =
                                          _selectedFilter == filter;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(filter),
                                          selected: isSelected,
                                          selectedColor: const Color(
                                            0xFF6366F1,
                                          ),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.05),
                                          labelStyle: GoogleFonts.inter(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                          onSelected: (selected) {
                                            if (selected)
                                              setState(
                                                () => _selectedFilter = filter,
                                              );
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: BorderSide(
                                              color: isSelected
                                                  ? const Color(0xFF6366F1)
                                                  : Colors.white.withOpacity(
                                                      0.1,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                if (_selectedFilter != 'All Time') ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        onPressed: _previousPeriod,
                                        icon: Icon(
                                          Icons.chevron_left_rounded,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withOpacity(0.05),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: _referenceDate,
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null)
                                            setState(
                                              () => _referenceDate = picked,
                                            );
                                        },
                                        child: Text(
                                          _getPeriodLabel(),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: Colors.white
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _nextPeriod,
                                        icon: Icon(
                                          Icons.chevron_right_rounded,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.white
                                              .withOpacity(0.05),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total $totalCount Moments recorded',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (categoryStats.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'COMPOSITION (100%)',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withOpacity(0.3),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 12,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Row(
                                      children: categoryStats.entries.map((
                                        stat,
                                      ) {
                                        final pct =
                                            stat.value['count'] / totalCount;
                                        const palette = [
                                          Color(0xFF6366F1),
                                          Color(0xFF10B981),
                                          Color(0xFFF59E0B),
                                          Color(0xFFEF4444),
                                          Color(0xFF06B6D4),
                                          Color(0xFF8B5CF6),
                                        ];
                                        final ci =
                                            categoryStats.keys.toList().indexOf(
                                              stat.key,
                                            ) %
                                            palette.length;
                                        return Expanded(
                                          flex: (pct * 1000).toInt(),
                                          child: Container(color: palette[ci]),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  ...categoryStats.entries.map((stat) {
                                    const palette = [
                                      Color(0xFF6366F1),
                                      Color(0xFF10B981),
                                      Color(0xFFF59E0B),
                                      Color(0xFFEF4444),
                                      Color(0xFF06B6D4),
                                      Color(0xFF8B5CF6),
                                    ];
                                    final ci =
                                        categoryStats.keys.toList().indexOf(
                                          stat.key,
                                        ) %
                                        palette.length;
                                    return _buildStatRow(
                                      stat.key,
                                      stat.value,
                                      totalCount,
                                      color: palette[ci],
                                    );
                                  }),
                                ] else ...[
                                  const SizedBox(height: 32),
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.insert_chart_outlined,
                                          color: Colors.white.withOpacity(0.2),
                                          size: 48,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No data in this period',
                                          style: GoogleFonts.inter(
                                            color: Colors.white.withOpacity(
                                              0.4,
                                            ),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        } else if (section == 'ACTIVITY CALENDAR') {
                          final categories = [
                            'All',
                            ...entries.map((e) => e.category).toSet(),
                          ];
                          return _buildSectionCard(
                            title: 'ACTIVITY CALENDAR',
                            subtitle:
                                'Visualizing consistency for specific activities',
                            selector: Column(
                              children: [
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: categories.map((cat) {
                                      final isSelected =
                                          _selectedCalendarCategory == cat;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(cat),
                                          selected: isSelected,
                                          selectedColor: const Color(
                                            0xFF6366F1,
                                          ),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.05),
                                          labelStyle: GoogleFonts.inter(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                          onSelected: (selected) {
                                            if (selected)
                                              setState(
                                                () =>
                                                    _selectedCalendarCategory =
                                                        cat,
                                              );
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: BorderSide(
                                              color: isSelected
                                                  ? const Color(0xFF6366F1)
                                                  : Colors.white.withOpacity(
                                                      0.1,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      onPressed: _previousMonth,
                                      icon: Icon(
                                        Icons.chevron_left_rounded,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withOpacity(0.05),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _showMonthPicker,
                                      child: Column(
                                        children: [
                                          Text(
                                            DateFormat(
                                              'MMMM yyyy',
                                            ).format(_referenceDate),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: Colors.white
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${entries.where((e) => e.timestamp.year == _referenceDate.year && e.timestamp.month == _referenceDate.month && (_selectedCalendarCategory == 'All' || e.category == _selectedCalendarCategory)).length} Moments recorded',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withOpacity(
                                                0.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _nextMonth,
                                      icon: Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withOpacity(0.05),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            content: Column(
                              children: [
                                _buildActivityCalendar(entries),
                                if (_selectedCalendarDay != null) ...[
                                  const SizedBox(height: 16),
                                  _buildDayDetailList(entries),
                                ],
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }).toList(),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActivityCalendar(List<TimestampEntry> entries) {
    // Generate days for the reference month
    final firstDayOfMonth = DateTime(
      _referenceDate.year,
      _referenceDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _referenceDate.year,
      _referenceDate.month + 1,
      0,
    );
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday; // 1-7 (Mon-Sun)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendar Grid
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              // Weekday Headers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                  return SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        day,
                        style: GoogleFonts.inter(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 42, // Show up to 6 weeks
                itemBuilder: (context, index) {
                  final dayOffset = index - (startWeekday - 1);
                  if (dayOffset < 0 || dayOffset >= daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final day = dayOffset + 1;
                  final currentDayDate = DateTime(
                    _referenceDate.year,
                    _referenceDate.month,
                    day,
                  );

                  // Check if this day has matching records
                  final dayEntries = entries.where((e) {
                    if (_selectedCalendarCategory != 'All' &&
                        e.category != _selectedCalendarCategory) {
                      return false;
                    }

                    final createdOnDay =
                        e.timestamp.year == currentDayDate.year &&
                        e.timestamp.month == currentDayDate.month &&
                        e.timestamp.day == currentDayDate.day;
                    if (createdOnDay) return true;

                    final targetOnDay = e.status == 'todo' &&
                        e.targetDate != null &&
                        e.targetDate!.year == currentDayDate.year &&
                        e.targetDate!.month == currentDayDate.month &&
                        e.targetDate!.day == currentDayDate.day;
                    if (targetOnDay) return true;

                    final completedOnDay = e.status == 'done' &&
                        e.doneTimestamp != null &&
                        e.doneTimestamp!.year == currentDayDate.year &&
                        e.doneTimestamp!.month == currentDayDate.month &&
                        e.doneTimestamp!.day == currentDayDate.day;
                    if (completedOnDay) return true;

                    return false;
                  }).toList();

                  final bool isActive = dayEntries.isNotEmpty;
                  final color = isActive
                      ? (_selectedCalendarCategory == 'All'
                            ? const Color(0xFF6366F1)
                            : _getCategoryColor(_selectedCalendarCategory))
                      : Colors.transparent;

                  final bool isSelected =
                      _selectedCalendarDay != null &&
                      _selectedCalendarDay?.year == currentDayDate.year &&
                      _selectedCalendarDay?.month == currentDayDate.month &&
                      _selectedCalendarDay?.day == currentDayDate.day;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCalendarDay = null;
                        } else {
                          _selectedCalendarDay = currentDayDate;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.4)
                            : (isActive
                                  ? color.withOpacity(0.2)
                                  : Colors.transparent),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : (isActive
                                    ? color.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.05)),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          day.toString(),
                          style: GoogleFonts.jetBrainsMono(
                            color: isSelected
                                ? Colors.white
                                : (isActive
                                      ? color
                                      : Colors.white.withOpacity(0.3)),
                            fontSize: 12,
                            fontWeight: isSelected || isActive
                                ? FontWeight.w800
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getAdjustedColor(
    TimestampEntry entry,
    Color baseColor, {
    String? statusOverride,
  }) {
    final status = statusOverride ?? entry.status;
    final hsl = HSLColor.fromColor(baseColor);
    if (status == 'todo') {
      double factor;
      if (entry.targetDate != null) {
        final now = DateTime.now();
        final totalDuration = entry.targetDate!
            .difference(entry.timestamp)
            .inSeconds;
        final elapsed = now.difference(entry.timestamp).inSeconds;

        if (totalDuration <= 0) {
          factor = 1.0;
        } else {
          factor = (elapsed / totalDuration).clamp(0.0, 1.0);
        }
      } else {
        final age = DateTime.now().difference(entry.timestamp);
        factor = (age.inSeconds / 86400.0).clamp(0.0, 1.0);
      }

      final newSaturation = (hsl.saturation + (0.3 * factor)).clamp(0.0, 1.0);
      return hsl
          .withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0))
          .withSaturation(newSaturation)
          .toColor();
    } else if (status == 'done') {
      return hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    }
    return baseColor;
  }

  Widget _buildDayDetailList(List<TimestampEntry> entries) {
    if (_selectedCalendarDay == null) return const SizedBox.shrink();

    // Collect all records for the day: normal entries + DONE events + TARGET dates
    final List<Map<String, dynamic>> dayRecords = [];

    for (final entry in entries) {
      if (_selectedCalendarCategory != 'All' &&
          entry.category != _selectedCalendarCategory) {
        continue;
      }

      final sameCreated =
          entry.timestamp.year == _selectedCalendarDay!.year &&
          entry.timestamp.month == _selectedCalendarDay!.month &&
          entry.timestamp.day == _selectedCalendarDay!.day;
          
      if (sameCreated) {
        dayRecords.add({
          'entry': entry,
          'time': entry.timestamp,
          'type': (entry.status == 'todo' || entry.status == 'done')
              ? 'todo_created'
              : 'moment',
        });
      }

      final sameTarget = entry.status == 'todo' &&
          entry.targetDate != null &&
          entry.targetDate!.year == _selectedCalendarDay!.year &&
          entry.targetDate!.month == _selectedCalendarDay!.month &&
          entry.targetDate!.day == _selectedCalendarDay!.day;
          
      if (sameTarget) {
        dayRecords.add({
          'entry': entry,
          'time': entry.targetDate!,
          'type': 'todo_target',
        });
      }

      final sameDone = entry.status == 'done' &&
          entry.doneTimestamp != null &&
          entry.doneTimestamp!.year == _selectedCalendarDay!.year &&
          entry.doneTimestamp!.month == _selectedCalendarDay!.month &&
          entry.doneTimestamp!.day == _selectedCalendarDay!.day;
          
      if (sameDone) {
        dayRecords.add({
          'entry': entry,
          'time': entry.doneTimestamp!,
          'type': 'done',
        });
      }
    }

    // Sort chronologically
    dayRecords.sort(
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM d, yyyy').format(_selectedCalendarDay!),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedCalendarDay = null),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dayRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No records for this day',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...dayRecords.map((record) => _DetailRecordWidget(
                  record: record,
                  getCategoryColor: _getCategoryColor,
                  getAdjustedColor: _getAdjustedColor,
                )),
        ],
      ),
    );
  }

  Map<String, Map<String, dynamic>> _calculateStats(
    List<TimestampEntry> entries,
  ) {
    if (entries.isEmpty) return {};
    final Map<String, int> counts = {};
    for (var entry in entries) {
      counts[entry.category] = (counts[entry.category] ?? 0) + 1;
    }
    return counts.map(
      (k, v) => MapEntry(k, {'percentage': v / entries.length, 'count': v}),
    );
  }

  Widget _buildStatRow(
    String category,
    Map<String, dynamic> data,
    int total, {
    Color? color,
  }) {
    final effectiveColor = color ?? _getCategoryColor(category);
    final double percentage = data['percentage'];
    final int count = data['count'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$count / $total Moments',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.3),
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.jetBrainsMono(
                  color: effectiveColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: effectiveColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: effectiveColor.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Color _getCategoryColor(String category) {
    switch (category) {
      case 'General':
        return const Color(0xFF64748B);
      case 'Work':
        return const Color(0xFF6366F1);
      case 'Personal':
        return const Color(0xFF10B981);
      case 'Health':
        return const Color(0xFFEF4444);
      case 'Study':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

}




class _DetailRecordWidget extends StatefulWidget {
  final Map<String, dynamic> record;
  final Color Function(String) getCategoryColor;
  final Color Function(TimestampEntry, Color, {String? statusOverride})
      getAdjustedColor;

  const _DetailRecordWidget({
    required this.record,
    required this.getCategoryColor,
    required this.getAdjustedColor,
  });

  @override
  State<_DetailRecordWidget> createState() => _DetailRecordWidgetState();
}

class _DetailRecordWidgetState extends State<_DetailRecordWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.record['entry'] as TimestampEntry;
    final time = widget.record['time'] as DateTime;
    final type = widget.record['type'] as String;
    final baseColor = widget.getCategoryColor(entry.category);
    final adjustedColor = widget.getAdjustedColor(
      entry,
      baseColor,
      statusOverride: (type == 'done') ? 'done' : 'todo',
    );

    Color accentColor;
    IconData typeIcon;
    String typeLabel;

    if (type == 'done') {
      accentColor = adjustedColor;
      typeIcon = Icons.check_circle_outline_rounded;
      typeLabel = 'DONE';
    } else if (type == 'todo_created') {
      accentColor = adjustedColor;
      typeIcon = Icons.radio_button_unchecked_rounded;
      typeLabel = 'TODO';
    } else if (type == 'todo_target') {
      accentColor = adjustedColor;
      typeIcon = Icons.flag_rounded;
      typeLabel = 'TARGET';
    } else {
      accentColor = baseColor;
      typeIcon = Icons.fiber_manual_record_rounded;
      typeLabel = '';
    }

    final bool isExpandable = entry.note.length > 30 ||
        (type == 'done' || type == 'todo_target') ||
        entry.doneNote != null ||
        entry.imagePath != null ||
        entry.doneImagePath != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: isExpandable ? () => setState(() => _isExpanded = !_isExpanded) : null,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(time),
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (typeLabel.isNotEmpty) ...[
                        Icon(typeIcon, size: 12, color: accentColor),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          entry.note,
                          style: GoogleFonts.inter(
                            color: (type == 'done')
                                ? Colors.white.withOpacity(0.9)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: _isExpanded ? null : 1,
                          overflow: _isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          entry.category.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: accentColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 7,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (typeLabel.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (type == 'todo_created' || type == 'todo_target') 
                                ? accentColor 
                                : accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: (type == 'done') 
                                ? Border.all(color: accentColor.withOpacity(0.3)) 
                                : null,
                          ),
                          child: Text(
                            typeLabel,
                            style: GoogleFonts.inter(
                              color: (type == 'todo_created' || type == 'todo_target') 
                                  ? Colors.white 
                                  : accentColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 7,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (entry.imagePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: Image.file(
                            File(entry.imagePath!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  if (type == 'done' && entry.doneImagePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: Image.file(
                            File(entry.doneImagePath!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  if (_isExpanded) ...[
                    const SizedBox(height: 4),
                    // DONE details
                    if (type == 'done' && entry.doneNote != null && entry.doneNote!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 14,
                                  color: accentColor.withOpacity(0.5),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'NOTE',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor.withOpacity(0.5),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.doneNote!,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Actual Duration result
                    if (entry.computedDurationMinutes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              size: 11,
                              color: accentColor.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ACTUAL: ${entry.computedDurationMinutes}m',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: accentColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Planned Context
                    if (type == 'done' || type == 'todo_target')
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
