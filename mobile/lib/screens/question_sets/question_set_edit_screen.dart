import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../models/question_set.dart';
import '../../providers/question_set_provider.dart';
import '../../providers/room_provider.dart';
import '../../services/question_set_service.dart';

class QuestionSetEditScreen extends ConsumerStatefulWidget {
  final String? setId;
  const QuestionSetEditScreen({super.key, this.setId});

  @override
  ConsumerState<QuestionSetEditScreen> createState() =>
      _QuestionSetEditScreenState();
}

class _QuestionSetEditScreenState extends ConsumerState<QuestionSetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isPublic = true;
  final Set<String> _selectedTags = {};
  final List<_LocalQuestion> _questions = [];
  bool _loading = false;
  String? _shareCode;

  bool get _isCreate => widget.setId == null;

  @override
  void initState() {
    super.initState();
    if (!_isCreate) _loadExisting();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final detail =
          await QuestionSetService.instance.getQuestionSet(widget.setId!);
      if (!mounted) return;
      _nameCtrl.text = detail.name;
      _descCtrl.text = detail.description ?? '';
      _isPublic = detail.isPublic;
      _shareCode = detail.code;
      _selectedTags.addAll(detail.tags);
      _questions.addAll(
          detail.items.map((item) => _LocalQuestion.fromItem(item)));
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('불러오기 실패: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('문제를 최소 1개 이상 추가해주세요.'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isCreate) {
        await QuestionSetService.instance.createQuestionSet(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          isPublic: _isPublic,
          tags: _selectedTags.toList(),
          items: _questions.map((q) => q.toCreateMap()).toList(),
        );
        if (mounted) {
          ref.invalidate(myQSetsProvider);
          Navigator.pop(context);
          AppSnackBar.show(context, '맵이 생성되었습니다!', backgroundColor: AppColors.accent);
        }
      } else {
        await QuestionSetService.instance.updateQuestionSet(
          widget.setId!,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          isPublic: _isPublic,
          tags: _selectedTags.toList(),
        );
        if (mounted) {
          ref.invalidate(myQSetsProvider);
          Navigator.pop(context);
          AppSnackBar.show(context, '저장되었습니다.', backgroundColor: AppColors.accent);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showQuestionDialog({_LocalQuestion? existing, int? index}) async {
    final List<String> categories;
    try {
      categories = await ref.read(categoriesProvider.future);
    } catch (e) {
      ref.invalidate(categoriesProvider); // try again on the next tap
      if (mounted) AppSnackBar.show(context, '카테고리를 불러오지 못했어요: $e');
      return;
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuestionDialog(
        existing: existing,
        categories: categories,
        onSave: (q) async {
          if (_isCreate) {
            setState(() {
              if (index != null) {
                _questions[index] = q;
              } else {
                _questions.add(q);
              }
            });
          } else {
            try {
              if (existing == null) {
                final item = await QuestionSetService.instance.addQuestion(
                  widget.setId!,
                  prompt: q.prompt,
                  answer: q.answer,
                  acceptedAnswers: q.acceptedAnswers,
                  category: q.category,
                  difficulty: q.difficulty,
                  hint: q.hint,
                );
                if (mounted) {
                  setState(() => _questions.add(_LocalQuestion.fromItem(item)));
                }
              } else {
                final item = await QuestionSetService.instance.updateQuestion(
                  widget.setId!,
                  existing.id!,
                  prompt: q.prompt,
                  answer: q.answer,
                  acceptedAnswers: q.acceptedAnswers,
                  category: q.category,
                  difficulty: q.difficulty,
                  hint: q.hint,
                );
                if (mounted) {
                  setState(() => _questions[index!] =
                      _LocalQuestion.fromItem(item));
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('저장 실패: $e'),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteQuestion(int index) async {
    final q = _questions[index];
    if (!_isCreate && q.id != null) {
      try {
        await QuestionSetService.instance
            .deleteQuestion(widget.setId!, q.id!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
    }
    setState(() => _questions.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    // the room categories; a tag they no longer have (older maps) stays visible so it can
    // be switched off
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <String>[];
    final themes = [
      ...categories,
      ..._selectedTags.where((t) => !categories.contains(t)),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? '새 맵 만들기' : '맵 편집'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('저장',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuestionDialog(),
        icon: const Icon(Icons.add),
        label: const Text('문제 추가'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Share code (edit mode only)
              if (!_isCreate && _shareCode != null) ...[
                _ShareCodeCard(code: _shareCode!),
                const SizedBox(height: 20),
              ],

              // Name
              const _SectionLabel('맵 이름'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: '예: 한국사 완전정복',
                  prefixIcon:
                      Icon(Icons.map_rounded, color: AppColors.primary),
                ),
                maxLength: 80,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '맵 이름을 입력해주세요.' : null,
              ),
              const SizedBox(height: 16),

              // Description
              const _SectionLabel('설명 (선택)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  hintText: '이 맵에 대한 간단한 설명',
                ),
                maxLength: 300,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Tags
              const _SectionLabel('테마'),
              const SizedBox(height: 4),
              const Text(
                '해당되는 테마를 모두 선택하세요',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: themes.map((t) {
                  final on = _selectedTags.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: on,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedTags.add(t);
                      } else {
                        _selectedTags.remove(t);
                      }
                    }),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: on ? AppColors.primary : AppColors.textSecondary,
                      fontWeight:
                          on ? FontWeight.w700 : FontWeight.normal,
                    ),
                    side: BorderSide(
                        color: on
                            ? AppColors.primary
                            : Colors.grey.shade300),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Public toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  title: const Text('공개 맵',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    '다른 사용자도 이 맵을 검색하고 사용할 수 있습니다',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: AppColors.primary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 28),

              // Questions section header
              Row(
                children: [
                  const Expanded(child: _SectionLabel('문제 목록')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_questions.length}문제',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_questions.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.quiz_outlined,
                            size: 44, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text(
                          '아직 문제가 없어요\n아래 버튼으로 문제를 추가해보세요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),

              // Question cards
              ...List.generate(_questions.length, (i) {
                final q = _questions[i];
                return _QuestionCard(
                  question: q,
                  index: i,
                  onEdit: () => _showQuestionDialog(existing: q, index: i),
                  onDelete: () => _deleteQuestion(i),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final _LocalQuestion question;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficultyColor(question.difficulty);
    final label = kDifficultyLabels[question.difficulty] ?? '중';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Badge(label: question.category, color: AppColors.primary),
                        const SizedBox(width: 6),
                        _Badge(label: label, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '정답: ${question.answer}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 19, color: AppColors.primary),
                    onPressed: onEdit,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 2),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 19, color: AppColors.danger),
                    onPressed: onDelete,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ShareCodeCard extends StatelessWidget {
  final String code;
  const _ShareCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3A0CA3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('공유 코드',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                Text(
                  code,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded,
                color: Colors.white70, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('코드가 복사되었습니다.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ));
            },
            tooltip: '코드 복사',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary),
    );
  }
}

// ── Local question model (in-memory editing) ──────────────────────────────

class _LocalQuestion {
  String? id;
  String prompt;
  String answer;
  List<String> acceptedAnswers;
  String category;
  int difficulty;
  String? hint;

  _LocalQuestion({
    this.id,
    required this.prompt,
    required this.answer,
    required this.acceptedAnswers,
    required this.category,
    required this.difficulty,
    this.hint,
  });

  factory _LocalQuestion.fromItem(QuestionSetItem item) => _LocalQuestion(
        id: item.id,
        prompt: item.prompt,
        answer: item.answer,
        acceptedAnswers: item.acceptedAnswers,
        category: item.category,
        difficulty: item.difficulty,
        hint: item.hint,
      );

  Map<String, dynamic> toCreateMap() => {
        'prompt': prompt,
        'answer': answer,
        'accepted_answers': acceptedAnswers,
        'category': category,
        'difficulty': difficulty,
        if (hint != null && hint!.isNotEmpty) 'hint': hint,
      };
}

// ── Question add / edit bottom sheet ─────────────────────────────────────

class _QuestionDialog extends StatefulWidget {
  final _LocalQuestion? existing;
  final List<String> categories;
  final Future<void> Function(_LocalQuestion) onSave;

  const _QuestionDialog(
      {this.existing, required this.categories, required this.onSave});

  @override
  State<_QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<_QuestionDialog> {
  final _promptCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  late String _category = widget.categories.first;
  int _difficulty = 2;
  bool _saving = false;
  String? _promptError;
  String? _answerError;
  String? _extraError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _promptCtrl.text = e.prompt;
      _answerCtrl.text = e.answer;
      _category = e.category;
      _difficulty = e.difficulty;
      _hintCtrl.text = e.hint ?? '';
      if (e.acceptedAnswers.isNotEmpty) {
        _extraCtrl.text = e.acceptedAnswers.join(', ');
      }
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _answerCtrl.dispose();
    _extraCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prompt = _promptCtrl.text.trim();
    final answer = _answerCtrl.text.trim();
    setState(() {
      _promptError = prompt.isEmpty ? '문제 내용을 입력해주세요.' : null;
      _answerError = answer.isEmpty ? '정답을 입력해주세요.' : null;
    });
    if (prompt.isEmpty || answer.isEmpty) return;

    final extraText = _extraCtrl.text.trim();
    final accepted = extraText.isEmpty
        ? <String>[]
        : extraText
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    // 서버는 추가 정답을 최대 10개까지만 받는다 (넘으면 422).
    if (accepted.length > 10) {
      setState(() => _extraError = '추가 정답은 10개까지만 넣을 수 있어요.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(_LocalQuestion(
        id: widget.existing?.id,
        prompt: prompt,
        answer: answer,
        acceptedAnswers: accepted,
        category: _category,
        difficulty: _difficulty,
        hint: _hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim(),
      ));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.existing == null ? '문제 추가' : '문제 편집',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),

          // Prompt
          TextField(
            controller: _promptCtrl,
            decoration: InputDecoration(
              labelText: '문제 내용 *',
              prefixIcon:
                  const Icon(Icons.quiz_rounded, color: AppColors.primary),
              errorText: _promptError,
            ),
            maxLength: 500,
            maxLines: 3,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_promptError != null) setState(() => _promptError = null);
            },
          ),
          const SizedBox(height: 12),

          // Answer
          TextField(
            controller: _answerCtrl,
            decoration: InputDecoration(
              labelText: '정답 *',
              prefixIcon: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.accent),
              errorText: _answerError,
            ),
            maxLength: 120,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_answerError != null) setState(() => _answerError = null);
            },
          ),
          const SizedBox(height: 12),

          // Extra accepted answers
          TextField(
            controller: _extraCtrl,
            decoration: InputDecoration(
              labelText: '추가 정답 (쉼표로 구분, 선택)',
              hintText: '예: H₂O, 에이치투오',
              prefixIcon: const Icon(Icons.add_circle_outline,
                  color: AppColors.textSecondary),
              errorText: _extraError,
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_extraError != null) setState(() => _extraError = null);
            },
          ),
          const SizedBox(height: 20),

          // Category
          const Text('카테고리',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            // an older map may use a category that is not in the list
            items: [
              if (!widget.categories.contains(_category)) _category,
              ...widget.categories,
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 20),

          // Difficulty
          const Text('난이도',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [1, 2, 3].map((d) {
              final label = kDifficultyLabels[d] ?? '';
              final selected = _difficulty == d;
              final color = difficultyColor(d);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _difficulty = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withValues(alpha: 0.15)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? color : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected ? color : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Hint
          TextField(
            controller: _hintCtrl,
            decoration: const InputDecoration(
              labelText: '힌트 (선택 — 없으면 초성 자동 생성)',
              prefixIcon:
                  Icon(Icons.lightbulb_outline, color: AppColors.warning),
            ),
            maxLength: 120,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(widget.existing == null ? '추가하기' : '저장하기'),
            ),
          ),
        ],
      ),
    );
  }
}
