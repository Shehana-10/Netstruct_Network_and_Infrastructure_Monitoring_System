import 'package:flutter/material.dart';
import 'package:fyp/services/auth_service.dart';
import 'package:fyp/services/notification_service.dart';
import 'package:fyp/services/user_service.dart';
import 'package:fyp/widgets/account_menu.dart';
import 'package:fyp/widgets/notification_menu.dart';

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  const CustomAppBar({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();
  int _unreadNotifications = 0;
  bool _soundEnabled = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotifications();
  }

  Future<void> _loadUserData() async {
    final data = await _userService.getUserData();
    setState(() => _userData = data);
  }

  Future<void> _loadNotifications() async {
    final notifications = await _notificationService.getUnreadNotifications();
    setState(() => _unreadNotifications = notifications.length);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      title: Image.asset('assets/images/netstruct_logo.png', height: 50),
      actions: <Widget>[
        IconButton(
          icon: Icon(
            _soundEnabled ? Icons.volume_up : Icons.volume_off,
            color: Colors.white,
          ),
          onPressed: _toggleSound,
        ),
        if (_userData != null && MediaQuery.of(context).size.width > 600)
          _buildWelcomeText(),
        NotificationMenu(
          unreadCount: _unreadNotifications,
          notificationService: _notificationService,
        ),
        AccountMenu(userData: _userData, authService: AuthService()),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff19084C),
              Color.fromARGB(255, 101, 26, 117),
              Color.fromARGB(255, 101, 25, 118),
              Color.fromARGB(255, 99, 26, 80),
              Color.fromARGB(255, 163, 42, 131),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 4,
    );
  }

  Widget _buildWelcomeText() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Welcome, ',
                style: TextStyle(fontSize: 18, color: Colors.blueGrey),
              ),
              TextSpan(
                text: _userData?['username']?.split(' ')[0] ?? 'User',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSound() {
    setState(() => _soundEnabled = !_soundEnabled);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _soundEnabled
              ? 'Notification sounds enabled'
              : 'Notification sounds disabled',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
