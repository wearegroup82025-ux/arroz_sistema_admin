import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: const Column(
        children: [
          SizedBox(height: 30),
          CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 60),
          ),
          SizedBox(height: 20),
          Text(
            "Juan Dela Cruz",
            style: TextStyle(fontSize: 22),
          ),
          Text("juan@email.com"),
        ],
      ),
    );
  }
}