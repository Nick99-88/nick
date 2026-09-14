import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../widgets/intro_widgets/chatting_rooms_intro.dart';
import '../../widgets/intro_widgets/intro_check.dart';
import '../models/rtc_room_model.dart';
import '../services/rtc_room_service.dart';
import 'rtc_create_room_screen.dart';
import 'rtc_active_room_screen.dart';
import 'rtc_moderator_room_screen.dart';
import 'rtc_participant_room_screen.dart';
import 'rtc_recordings_history_screen.dart';

class RtcLobbyScreen extends StatefulWidget {
  final bool showInstitutionalTab;
  const RtcLobbyScreen({super.key, this.showInstitutionalTab = true});

  @override
  State<RtcLobbyScreen> createState() => _RtcLobbyScreenState();
}

class _RtcLobbyScreenState extends State<RtcLobbyScreen>
    with SingleTickerProviderStateMixin {
  final _roomService = RtcRoomService();
  final _searchController = TextEditingController();
  late TabController _tabController;
  List<RtcRoom> _publicRooms = [];
  List<RtcRoom> _friendRooms = [];
  List<RtcRoom> _institutionalRooms = [];
  bool _isLoadingPublic = false;
  bool _isLoadingFriends = false;
  bool _isLoadingInstitutional = false;
  bool _isSearching = false;
  String _lastVerifiedControlType = 'all_access';
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _getTabCount(),
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _fetchRoomsForTab(0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  int _getTabCount() {
    int count = 2;
    if (widget.showInstitutionalTab) count++;
    return count;
  }

  List<String> get _tabLabels {
    final tabs = <String>['Public', 'Friends'];
    if (widget.showInstitutionalTab) tabs.add('Institutional');
    return tabs;
  }

  List<IconData> get _tabIcons {
    final icons = <IconData>[Icons.public, Icons.people];
    if (widget.showInstitutionalTab) icons.add(Icons.school);
    return icons;
  }

  List<RtcRoom> get _currentRooms {
    switch (_currentTab) {
      case 0:
        return _publicRooms;
      case 1:
        return _friendRooms;
      case 2:
        return _institutionalRooms;
      default:
        return _publicRooms;
    }
  }

  bool get _isLoading {
    switch (_currentTab) {
      case 0:
        return _isLoadingPublic;
      case 1:
        return _isLoadingFriends;
      case 2:
        return _isLoadingInstitutional;
      default:
        return _isLoadingPublic;
    }
  }

  String get _emptyTitle {
    switch (_currentTab) {
      case 0:
        return 'No active public rooms';
      case 1:
        return 'No friend rooms active';
      case 2:
        return 'No institutional rooms active';
      default:
        return 'No rooms found';
    }
  }

  String get _emptySubtitle {
    switch (_currentTab) {
      case 0:
        return 'Create a room to get started';
      case 1:
        return 'Your friends haven\'t started any rooms yet';
      case 2:
        return 'No one in your institution has started a room';
      default:
        return '';
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() => _currentTab = _tabController.index);
      _fetchRoomsForTab(_tabController.index);
    }
  }

  Future<void> _fetchRoomsForTab(int index) async {
    setState(() {
      switch (index) {
        case 0:
          _isLoadingPublic = true;
          break;
        case 1:
          _isLoadingFriends = true;
          break;
        case 2:
          _isLoadingInstitutional = true;
          break;
      }
    });
    try {
      switch (index) {
        case 0:
          _publicRooms = await _roomService.getPublicRooms();
          break;
        case 1:
          _friendRooms = await _roomService.getFriendRooms();
          break;
        case 2:
          _institutionalRooms = await _roomService.getInstitutionalRooms();
          break;
      }
    } catch (e) {
      debugPrint('Error loading rooms for tab $index: $e');
    } finally {
      if (mounted) {
        setState(() {
          switch (index) {
            case 0:
              _isLoadingPublic = false;
              break;
            case 1:
              _isLoadingFriends = false;
              break;
            case 2:
              _isLoadingInstitutional = false;
              break;
          }
        });
      }
    }
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim().toUpperCase();
    if (query.isEmpty) {
      _showErrorSnackBar('Please enter a Room ID to search.');
      return;
    }
    setState(() => _isSearching = true);
    try {
      final result = await _roomService.verifyRoom(query);
      if (result['active'] == true) {
        final bool requiresPw = result['requires_password'] ?? false;
        final String roomName = result['name'] ?? 'Room';
        _lastVerifiedControlType = result['control_type'] ?? 'all_access';
        if (requiresPw) {
          _promptPassword(query, roomName);
        } else {
          _joinRoom(query, null);
        }
      } else {
        _showErrorSnackBar('Room ID "$query" is not active or does not exist.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to verify room: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _promptPassword(String roomId, String roomName) {
    final pwController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          title: Text(
            'Enter Password',
            style: TextStyle(
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Room: ',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    TextSpan(
                      text: roomName,
                      style: const TextStyle(
                        color: Color(0xFF1A237E),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pwController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1A237E)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF1A237E), width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final pw = pwController.text.trim();
                if (pw.isEmpty) return;
                Navigator.pop(context);
                _joinRoom(roomId, pw);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('JOIN'),
            ),
          ],
        );
      },
    );
  }

  void _joinRoom(String roomId, String? password) {
    Widget screen;
    if (_lastVerifiedControlType == 'creator_only') {
      screen = RtcActiveRoomScreen(roomId: roomId, roomPassword: password);
    } else if (_lastVerifiedControlType == 'all_access') {
      screen = RtcModeratorRoomScreen(roomId: roomId, roomPassword: password);
    } else {
      screen = RtcParticipantRoomScreen(roomId: roomId, roomPassword: password);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _fetchRoomsForTab(_currentTab));
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A237E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntroCheck(
      featureKey: chatRoomsFeatureKey,
      featureIcon: chatRoomsFeatureIcon,
      featureTitle: chatRoomsFeatureTitle,
      featureSubtitle: chatRoomsFeatureSubtitle,
      steps: chatRoomsIntroSteps,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Starlight Rooms',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.forum, color: Color(0xFF1A237E), size: 22),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library_outlined, color: Color(0xFF1A237E)),
            tooltip: 'My Recordings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RtcRecordingsHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Color(0xFF1A237E)),
            onPressed: () => _fetchRoomsForTab(_currentTab),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF1A237E),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: const Color(0xFF1A237E),
            unselectedLabelColor: Colors.grey[400],
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 13,
            ),
            tabs: List.generate(
              _tabLabels.length,
              (i) => Tab(
                icon: Icon(_tabIcons[i], size: 18),
                text: _tabLabels[i],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RtcCreateRoomScreen(),
            ),
          ).then((_) => _fetchRoomsForTab(_currentTab));
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('CREATE ROOM',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? _buildLoadingSkeleton()
                : _currentRooms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A237E).withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _currentTab == 1
                                      ? Icons.people_outline
                                      : _currentTab == 2
                                          ? Icons.school_outlined
                                          : Icons.forum_outlined,
                                  size: 48,
                                  color: const Color(0xFF1A237E).withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _emptyTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _emptySubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF1A237E),
                        onRefresh: () => _fetchRoomsForTab(_currentTab),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: _currentRooms.length,
                          itemBuilder: (context, index) {
                            return _buildRoomCard(context, _currentRooms[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140, height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80, height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 40, height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 50, height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search by Room ID...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF1A237E), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  )
                : _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _loadCurrentTab();
                        },
                      )
                    : null,
          ),
          onSubmitted: (_) => _handleSearch(),
        ),
      ),
    );
  }

  void _loadCurrentTab() {
    _fetchRoomsForTab(_currentTab);
  }

  Widget _buildRoomCard(BuildContext context, RtcRoom room) {
    IconData typeIcon;
    Color typeColor;
    switch (room.type) {
      case 'one_speaker':
        typeIcon = Icons.headset;
        typeColor = const Color(0xFF1A237E);
        break;
      case 'one_video':
        typeIcon = Icons.videocam;
        typeColor = const Color(0xFF283593);
        break;
      case 'all_speakers_one_video':
        typeIcon = Icons.group_work;
        typeColor = const Color(0xFF1A237E);
        break;
      default:
        typeIcon = Icons.group;
        typeColor = const Color(0xFF1A237E);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _lastVerifiedControlType = room.controlType;
            if (room.requiresPassword) {
              _promptPassword(room.roomId, room.name);
            } else {
              _joinRoom(room.roomId, null);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1A237E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          room.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: typeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${room.activeParticipantsCount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      ],
                    ),
                    if (room.requiresPassword) ...[
                      const SizedBox(height: 6),
                      Icon(Icons.lock, size: 14, color: Colors.amber[700]),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room.roomId,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ),
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