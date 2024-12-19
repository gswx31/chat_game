import 'package:flutter/material.dart';
class KoreanInitials {
  static String getInitials(String text) {
    // Unicode ranges and initial Jamo for Korean characters
    int baseCode = 44032; // '가'
    List<String> initials = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];

    // Extracts initial consonants from the given text
    return text.runes.map((int rune) {
      if (rune >= baseCode && rune <= 55203) { // Range of Hangul Syllables
        int index = (rune - baseCode) ~/ 588;
        return initials[index];
      }
      return String.fromCharCode(rune); // Return the character itself if it's not a Hangul syllable
    }).join();
  }
}


