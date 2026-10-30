import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class QuestionDisplay extends StatefulWidget {
  final String question;
  final String? answerMessage;
  final int skipVotes;
  final double? deadlineTs; // epoch seconds; null = no active timer
  final int totalSeconds; // used for progress arc
  final String? hint; // chosung / hint string (already formatted)

  const QuestionDisplay({
    required this.question,
    this.answerMessage,
    this.skipVotes = 0,
    this.deadlineTs,
    this.totalSeconds = 30,
    this.hint,
    super.key,
  });

  @override
  State<QuestionDisplay> createState() => _QuestionDisplayState();
}

class _QuestionDisplayState extends State<QuestionDisplay> {
  Timer? _ticker;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(QuestionDisplay old) {
    super.didUpdateWidget(old);
    if (old.deadlineTs != widget.deadlineTs) _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _updateRemaining();
    if (widget.deadlineTs != null && widget.answerMessage == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        _updateRemaining();
      });
    }
  }

  void _updateRemaining() {
    if (widget.deadlineTs == null) {
      setState(() => _remaining = 0);
      return;
    }
    final rem = (widget.deadlineTs! - DateTime.now().millisecondsSinceEpoch / 1000)
        .ceil()
        .clamp(0, widget.totalSeconds);
    setState(() => _remaining = rem);
    if (rem <= 0) _ticker?.cancel();
  }

  Color get _timerColor {
    final total = widget.totalSeconds;
    if (_remaining > total * 0.5) return AppColors.timerGreen;
    if (_remaining > total * 0.25) return AppColors.timerOrange;
    return AppColors.timerRed;
  }

  @override
  Widget build(BuildContext context) {
    final hasAnswer = widget.answerMessage != null;
    final hasHint = widget.hint != null && !hasAnswer;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primary_,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              if (widget.skipVotes > 0)
                _InfoChip(
                  icon: Icons.skip_next_rounded,
                  label: '스킵 ${widget.skipVotes}표',
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              const Spacer(),
              if (widget.deadlineTs != null)
                _CircleTimer(
                  remaining: _remaining,
                  total: widget.totalSeconds,
                  color: _timerColor,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Question text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.question,
              key: ValueKey(widget.question),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),

          // Hint
          if (hasHint) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '힌트: ${widget.hint}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Answer reveal banner
          if (hasAnswer) ...[
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey(widget.answerMessage),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.answerMessage!.contains('정답')
                      ? Colors.green.withValues(alpha: 0.25)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.answerMessage!.contains('정답')
                        ? Colors.greenAccent.withValues(alpha: 0.6)
                        : Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.answerMessage!.contains('정답')
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      color: widget.answerMessage!.contains('정답')
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.answerMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleTimer extends StatelessWidget {
  final int remaining;
  final int total;
  final Color color;

  const _CircleTimer(
      {required this.remaining, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final progress = (remaining / math.max(1, total)).clamp(0.0, 1.0);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(64, 64),
            painter: _ArcPainter(progress: progress, color: color),
          ),
          Text(
            '$remaining',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: c, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: c, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
