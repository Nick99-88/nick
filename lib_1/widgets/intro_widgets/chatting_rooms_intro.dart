import 'package:flutter/material.dart';

const String chatRoomsFeatureKey = 'chatting_rooms';
const IconData chatRoomsFeatureIcon = Icons.forum;
const String chatRoomsFeatureTitle = 'Chatting Rooms';
const String chatRoomsFeatureSubtitle = 'Join public rooms, connect with friends, and collaborate in real-time voice and video.';

List<Map<String, dynamic>> get chatRoomsIntroSteps => [
  {
    'icon': Icons.public_rounded,
    'title': 'Join Public Rooms',
    'description': 'Explore and join live public rooms for group discussions, study sessions, and collaborative work.',
    'color': const Color(0xFF1A237E),
  },
  {
    'icon': Icons.people_rounded,
    'title': 'Private Friend Rooms',
    'description': 'Create private rooms with friends and enjoy secure one-on-one or group conversations.',
    'color': const Color(0xFF283593),
  },
  {
    'icon': Icons.school_rounded,
    'title': 'Institutional Rooms',
    'description': 'Access institution-only rooms for class discussions, teacher meetings, and academic collaboration.',
    'color': const Color(0xFF3F51B5),
  },
  {
    'icon': Icons.headset_rounded,
    'title': 'Voice & Video',
    'description': 'Switch between voice-only and video modes for the best communication experience.',
    'color': const Color(0xFF5C6BC0),
  },
];