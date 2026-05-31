import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/sl_theme.dart';
import '../../core/fast_backdrop_filter.dart';

class SongsScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const SongsScreen({super.key, required this.houseId, required this.myName});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _songsSub;
  StreamSubscription<DatabaseEvent>? _themeSub;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  List<Map<String, dynamic>> _songs = [];
  String? _themeId;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  void _loadSongs() {
    _songsSub?.cancel();
    _themeSub?.cancel();

    _songsSub = _dbRef
        .child('houses/${widget.houseId}/couple_songs/list')
        .onValue
        .listen((event) {
      final raw = event.snapshot.value;
      if (raw is Map) {
        final data = Map<dynamic, dynamic>.from(raw);
        final List<Map<String, dynamic>> loaded = [];
        data.forEach((key, value) {
          if (value is! Map) return;
          final item = Map<String, dynamic>.from(value);
          item['id'] = key;
          loaded.add(item);
        });
        loaded.sort(
            (a, b) => (b['ts'] as int? ?? 0).compareTo(a['ts'] as int? ?? 0));
        if (mounted) {
          setState(() {
            _songs = loaded;
          });
        }
      } else {
        if (mounted) setState(() => _songs = []);
      }
    });

    _themeSub = _dbRef
        .child('houses/${widget.houseId}/couple_songs/theme')
        .onValue
        .listen((event) {
      if (mounted) {
        setState(() {
          _themeId = event.snapshot.value as String?;
        });
      }
    });
  }

  Future<void> _addSong() async {
    final title = _titleController.text.trim();
    String link = _linkController.text.trim();
    final note = _noteController.text.trim();

    if (title.isEmpty || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('util_nhptnbihtv_10e97f'))));
      return;
    }

    if (!link.startsWith('http://') && !link.startsWith('https://')) {
      link = 'https://$link';
    }

    await _dbRef
        .child('houses/${widget.houseId}/couple_songs/list')
        .push()
        .set({
      'a': widget.myName,
      'title': title,
      'link': link,
      'note': note,
      'ts': ServerValue.timestamp,
      'time': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
    });
    if (!mounted) return;

    _titleController.clear();
    _linkController.clear();
    _noteController.clear();
    FocusScope.of(context).unfocus();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('util_lubiht_50fa83'))));
    }
  }

  Future<void> _deleteSong(String id) async {
    await _dbRef
        .child('houses/${widget.houseId}/couple_songs/list/$id')
        .remove();
    if (_themeId == id) {
      await _dbRef
          .child('houses/${widget.houseId}/couple_songs/theme')
          .remove();
    }
  }

  Future<void> _setTheme(String id) async {
    await _dbRef.child('houses/${widget.houseId}/couple_songs/theme').set(id);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('util_chathmlink_42e3cb'))));
      }
    }
  }

  @override
  void dispose() {
    _songsSub?.cancel();
    _themeSub?.cancel();
    _titleController.dispose();
    _linkController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? themeSong;
    if (_themeId != null) {
      try {
        themeSong = _songs.firstWhere((s) => s['id'] == _themeId);
      } catch (_) {}
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          context.tr('util_bihtimnh_28711e'),
          style: SLTheme.quicksand(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.1,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: FastBackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildInputArea(),
              if (themeSong != null) _buildThemeSongCard(themeSong),
              Expanded(child: _buildSongsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: SLSpacing.all20,
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildTextField(
              _titleController, context.tr('util_tnbihtvdpe_28f4a6'), Icons.music_note),
          SLSpacing.h8,
          _buildTextField(_linkController, 'Link audio', Icons.link),
          SLSpacing.h8,
          _buildTextField(
              _noteController, context.tr('util_ghichknimt_6caeba'), Icons.notes,
              maxLines: 2),
          SLSpacing.h16,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
                elevation: 0,
              ),
              onPressed: _addSong,
              child: Text(
                context.tr('util_lubiht_262042'),
                style: SLTheme.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2980),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: SLRadius.lgAll,
        border: Border.all(
          color: const Color(0xFFFF8AA0).withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        cursorColor: const Color(0xFFD81B60),
        style: SLTheme.quicksand(
          color: const Color(0xFF243041),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: SLTheme.quicksand(color: const Color(0xFFB55A73)),
          prefixIcon: Icon(icon, color: const Color(0xFFD81B60)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildThemeSongCard(Map<String, dynamic> song) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: SLSpacing.all20,
      decoration: BoxDecoration(
        color: Colors.yellowAccent.withValues(alpha: 0.2),
        borderRadius: SLRadius.xlAll,
        border: Border.all(color: Colors.yellowAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.yellowAccent, size: 30),
          SLSpacing.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('util_bihtch_82a698'),
                  style: SLTheme.quicksand(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
                Text(
                  song['title'] ?? '',
                  style: SLTheme.quicksand(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _openLink(song['link']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: SLRadius.lgAll,
              ),
              child: Text(
                'NGHE',
                style: SLTheme.quicksand(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A2980),
                    fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSongsList() {
    return _songs.isEmpty
        ? Center(
            child: Text(
              context.tr('util_chacbihtno_1a5789'),
              style: SLTheme.quicksand(
                  color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              final song = _songs[index];
              final isTheme = song['id'] == _themeId;
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: SLSpacing.all16,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song['title'] ?? '',
                                style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16),
                              ),
                              if ((song['note'] ?? '').isNotEmpty)
                                Text(
                                  song['note'],
                                  style: SLTheme.quicksand(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              SLSpacing.h4,
                              Text(
                                '👤 ${song['a'] ?? ''} • ${song['time'] ?? ''}',
                                style: SLTheme.quicksand(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.star,
                                  color: isTheme
                                      ? Colors.yellowAccent
                                      : Colors.white30,
                                  size: 20),
                              onPressed: () => _setTheme(song['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new,
                                  color: Colors.white70, size: 20),
                              onPressed: () => _openLink(song['link']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white30, size: 20),
                              onPressed: () => _deleteSong(song['id']),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }
}
