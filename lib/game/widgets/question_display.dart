import 'package:flutter/material.dart';

import '../handlers/korean_initials_helper.dart';

class QuestionDisplay extends StatelessWidget {
  final String question;
  final String? answerMessage;
  final int remainingQuestions;
  final int skipVotes;
  final int remainingTime; // 남은 시간 추가
  final String? initialHint; // 초성 힌트 추가

  const QuestionDisplay({
    required this.question,
    this.answerMessage,
    required this.remainingQuestions,
    required this.skipVotes,
    required this.remainingTime,
    this.initialHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.0),
      color: Colors.blue[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '남은 시간: $remainingTime초',
              style: TextStyle(fontSize: 16, color: remainingTime <= 20 ? Colors.red : Colors.black),
            ),
            SizedBox(height: 10),
            Text(
              question,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (initialHint != null && remainingTime <= 20)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '초성 힌트: ${KoreanInitials.getInitials(initialHint!)}',
                  style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            if (answerMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  answerMessage!,
                  style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 10),
            Text(
              '남은 문제: $remainingQuestions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (skipVotes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '스킵 투표 수: $skipVotes',
                  style: TextStyle(fontSize: 16, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}