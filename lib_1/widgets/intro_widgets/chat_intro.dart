import 'package:flutter/material.dart';

const String chatFeatureKey = 'whatsapp_chat';
const IconData chatFeatureIcon = Icons.chat_bubble;
const String chatFeatureTitle = 'Chat';
const String chatFeatureSubtitle = 'Real-time messaging with friends, group chats, and instant voice calls.';

List<Map<String, dynamic>> get chatIntroSteps => [
  {
    'icon': Icons.chat_bubble_rounded,
    'title': 'Instant Messaging',
    'description': 'Send messages, photos, and files instantly with your friends and study groups.',
    'color': const Color(0xFF1A237E),
  },
  {
    'icon': Icons.group_rounded,
    'title': 'Group Chats',
    'description': 'Create group conversations for your classes, study groups, and project teams.',
    'color': const Color(0xFF283593),
  },
  {
    'icon': Icons.voice_chat_rounded,
    'title': 'Voice & Video Calls',
    'description': 'Make crystal-clear voice and video calls right inside the app.',
    'color': const Color(0xFF3F51B5),
  },
  {
    'icon': Icons.favorite_rounded,
    'title': 'Stay Connected',
    'description': 'Never miss a message with real-time notifications and read receipts.',
    'color': const Color(0xFF5C6BC0),
  },
];