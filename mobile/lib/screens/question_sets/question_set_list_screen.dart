import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_theme.dart';
import '../../core/router.dart';
import '../../models/question_set.dart';
import '../../providers/question_set_provider.dart';
import '../../services/question_set_service.dart';

class QuestionSetListScreen extends ConsumerWidget {
  const QuestionSetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(myQSetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 맵'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(Routes.questionSetStore),
            icon: const Icon(Icons.store_rounded, color: Colors.white, size: 18),
            label: const Text('맵 스토어',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.questionSetCreate),
        icon: const Icon(Icons.add),
        label: const Text('새 맵 만들기'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: setsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              const Text('불러오기 실패',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('$e',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(myQSetsProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (sets) {
          if (sets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.map_outlined,
                        size: 44, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text('아직 만든 맵이 없어요',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('오른쪽 아래 버튼으로 새 맵을 만들어보세요!',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myQSetsProvider),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: sets.length,
              itemBuilder: (_, i) => _SetCard(
                set: sets[i],
                onDeleted: () => ref.invalidate(myQSetsProvider),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  final QuestionSetBrief set;
  final VoidCallback onDeleted;

  const _SetCard({required this.set, required this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(set.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              SizedBox(height: 4),
              Text('삭제', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        confirmDismiss: (_) => ConfirmDialog.show(
          context,
          title: '맵 삭제',
          content: '"${set.name}" 맵을 삭제할까요?\n되돌릴 수 없습니다.',
          confirmLabel: '삭제',
        ),
        onDismissed: (_) async {
          try {
            await QuestionSetService.instance.deleteQuestionSet(set.id);
            onDeleted();
          } catch (e) {
            if (context.mounted) AppSnackBar.show(context, '삭제 실패: $e');
          }
        },
        child: GestureDetector(
          onTap: () => context.push(Routes.questionSetEdit(set.id)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        set.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${set.itemCount}문제',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (set.description != null && set.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    set.description!,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (set.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: set.tags
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      set.isPublic
                          ? Icons.public_rounded
                          : Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      set.isPublic ? '공개' : '비공개',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.play_circle_outline_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${set.playCount}회 플레이',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const Spacer(),
                    const Text('편집 →',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
