import 'package:flutter/material.dart';

class PatientDashboard extends StatelessWidget {
  const PatientDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Patient'),
      ),
      body: const Center(
        child: Text('Dashboard Patient - En cours de développement'),
      ),
    );
  }
}