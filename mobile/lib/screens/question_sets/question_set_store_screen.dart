import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../core/app_theme.dart';
import '../../models/question_set.dart';
import '../../providers/auth_provider.dart';
import '../../providers/question_set_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/question_set_service.dart';

class QuestionSetStoreScreen extends ConsumerStatefulWidget {
  const QuestionSetStoreScreen({super.key});

  @override
  ConsumerState<QuestionSetStoreScreen> createState() =>
      _QuestionSetStoreScreenState();
}

class _QuestionSetStoreScreenState
    extends ConsumerState<QuestionSetStoreScreen> {
  final _searchCtrl = TextEditingController();
  String _sort = 'popular';
  String? _selectedTag;
  List<QuestionSetBrief> _sets = [];
  bool _loading = false;
  bool _hasMore = true;
  final Set<String> _downloadedIds = {};

  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final results = await QuestionSetService.instance.browsePublicSets(
        query: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        tag: _selectedTag,
        sort: _sort,
        offset: reset ? 0 : _sets.length,
        limit: _limit,
      );
      setState(() {
        if (reset) {
          _sets = results;
        } else {
          _sets.addAll(results);
        }
        _hasMore = results.length == _limit;
      });
    } catch (e) {
      if (mounted) AppSnackBar.show(context, '불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(QuestionSetBrief set) async {
    try {
      await QuestionSetService.instance.cloneQuestionSet(set.id);
      setState(() => _downloadedIds.add(set.id));
      ref.invalidate(myQSetsProvider);
      if (mounted) {
        AppSnackBar.show(context, '"${set.name}" 다운로드 완료! 내 맵에서 확인하세요.',
            backgroundColor: AppColors.accent);
      }
    } catch (e) {
      if (mounted) AppSnackBar.show(context, '다운로드 실패: $e');
    }
  }

  void _showCodeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CodeDownloadSheet(
        onDownloaded: () {
          ref.invalidate(myQSetsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    // until loaded only '전체' is shown
    final themes = ref.watch(categoriesProvider).valueOrNull ?? const <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('맵 스토어'),
        actions: [
          TextButton.icon(
            onPressed: _showCodeDialog,
            icon: const Icon(Icons.qr_code_rounded, color: Colors.white, size: 18),
            label: const Text('코드로 받기',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + sort bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '맵 이름 검색...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _fetch(reset: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _fetch(reset: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SortChip(
                      label: '인기순',
                      selected: _sort == 'popular',
                      onTap: () {
                        setState(() => _sort = 'popular');
                        _fetch(reset: true);
                      },
                    ),
                    const SizedBox(width: 8),
                    _SortChip(
                      label: '최신순',
                      selected: _sort == 'recent',
                      onTap: () {
                        setState(() => _sort = 'recent');
                        _fetch(reset: true);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Theme filter
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ThemeChip(
                        label: '전체',
                        selected: _selectedTag == null,
                        onTap: () {
                          setState(() => _selectedTag = null);
                          _fetch(reset: true);
                        },
                      ),
                      ...themes.map((t) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _ThemeChip(
                              label: t,
                              selected: _selectedTag == t,
                              onTap: () {
                                setState(() =>
                                    _selectedTag = _selectedTag == t ? null : t);
                                _fetch(reset: true);
                              },
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          const Divider(height: 1),

          // Results list
          Expanded(
            child: _sets.isEmpty && _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _sets.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48, color: AppColors.textSecondary),
                            SizedBox(height: 12),
                            Text('검색 결과가 없습니다',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetch(reset: true),
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: _sets.length + (_hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _sets.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: TextButton(
                                    onPressed: _loading ? null : _fetch,
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                                strokeWidth: 2))
                                        : const Text('더 불러오기'),
                                  ),
                                ),
                              );
                            }
                            final set = _sets[i];
                            final isOwn = set.creatorId == uid;
                            final downloaded = _downloadedIds.contains(set.id);
                            return _StoreCard(
                              set: set,
                              isOwn: isOwn,
                              downloaded: downloaded,
                              onDownload: () async => _download(set),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Store map card ────────────────────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  final QuestionSetBrief set;
  final bool isOwn;
  final bool downloaded;
  final Future<void> Function() onDownload;

  const _StoreCard({
    required this.set,
    required this.isOwn,
    required this.downloaded,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        set.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            set.creatorNickname,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Download button
                if (isOwn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('내 맵',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  )
                else if (downloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 14, color: AppColors.accent),
                        SizedBox(width: 4),
                        Text('완료',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else
                  _DownloadButton(onTap: onDownload),
              ],
            ),
            if (set.description != null && set.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                set.description!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (set.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: set.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(t,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.quiz_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${set.itemCount}문제',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.play_circle_outline_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${set.playCount}회 플레이',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final Future<void> Function() onTap;
  const _DownloadButton({required this.onTap});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                await widget.onTap();
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: _loading ? null : AppColors.primary_,
          color: _loading ? Colors.grey.shade200 : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2))
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_rounded, size: 15, color: Colors.white),
                  SizedBox(width: 4),
                  Text('다운로드',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}

// ── Code-based download bottom sheet ─────────────────────────────────────

class _CodeDownloadSheet extends StatefulWidget {
  final VoidCallback onDownloaded;
  const _CodeDownloadSheet({required this.onDownloaded});

  @override
  State<_CodeDownloadSheet> createState() => _CodeDownloadSheetState();
}

class _CodeDownloadSheetState extends State<_CodeDownloadSheet> {
  final _codeCtrl = TextEditingController();
  bool _searching = false;
  bool _downloading = false;
  QuestionSetDetail? _preview;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 8) {
      setState(() => _error = '코드는 8자리입니다.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _preview = null;
    });
    try {
      final detail = await QuestionSetService.instance.getByCode(code);
      setState(() => _preview = detail);
    } catch (e) {
      setState(() {
        if (e is ApiException && e.statusCode == 404) {
          _error = '맵을 찾을 수 없어요. 코드를 확인해주세요.';
        } else if (e is ApiException && e.statusCode == 403) {
          _error = '비공개 맵이에요.';
        } else {
          _error = '검색 실패: $e';
        }
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _download() async {
    if (_preview == null) return;
    setState(() => _downloading = true);
    try {
      await QuestionSetService.instance.cloneQuestionSet(_preview!.id);
      widget.onDownloaded();
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.show(context, '"${_preview!.name}" 다운로드 완료! 내 맵에서 확인하세요.',
            backgroundColor: AppColors.accent);
      }
    } catch (e) {
      if (mounted) AppSnackBar.show(context, '다운로드 실패: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('코드로 맵 받기',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('공유받은 8자리 코드를 입력하세요',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),

          // Code input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    hintText: 'AB12CDEF',
                    prefixIcon: const Icon(Icons.tag_rounded,
                        color: AppColors.primary),
                    errorText: _error,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 8,
                  style: const TextStyle(
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _searching ? null : _search,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                child: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('검색'),
              ),
            ],
          ),

          // Preview
          if (_preview != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _preview!.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  if (_preview!.description != null &&
                      _preview!.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(_preview!.description!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                          icon: Icons.quiz_outlined,
                          label: '${_preview!.itemCount}문제'),
                      _InfoChip(
                          icon: Icons.person_outline_rounded,
                          label: _preview!.creatorNickname),
                      ..._preview!.tags.map((t) =>
                          _InfoChip(icon: Icons.label_outline_rounded, label: t)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _download,
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.download_rounded),
                label: Text(_downloading ? '다운로드 중...' : '내 맵으로 다운로드'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Helper chips ──────────────────────────────────────────────────────────

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color:
                  selected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.normal,
              fontSize: 13),
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.accent.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.accent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textSecondary,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.normal,
              fontSize: 12),
        ),
      ),
    );
  }
}
