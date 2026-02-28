import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const JobPortalApp());

// --- STYLE THEME ---
class AppTheme {
  static const Color primaryBlue = Color(0xFF0A66C2);
  static const Color backgroundLight = Color(0xFFF3F2EF);
  
  static ThemeData get theme => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue, surface: backgroundLight),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 1),
    cardTheme: CardTheme(
      color: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
    ),
  );
}

class JobPortalApp extends StatelessWidget {
  const JobPortalApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'Universal Jobs', theme: AppTheme.theme, home: const MainLayout(), debugShowCheckedModeBanner: false);
}

// --- MAIN LAYOUT (BOTTOM NAV) ---
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = <Widget>[JobSearchScreen(), SavedJobsScreen(), UserProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- 1. SEARCH & FEED SCREEN ---
class JobSearchScreen extends StatefulWidget {
  const JobSearchScreen({super.key});
  @override
  State<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends State<JobSearchScreen> {
  List<dynamic> jobs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchJobs(""); 
  }

  Future<void> fetchJobs(String query) async {
    setState(() => isLoading = true);
    final url = query.isEmpty ? 'http://10.0.2.2:8000/api/jobs' : 'http://10.0.2.2:8000/api/jobs?q=$query';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) setState(() { jobs = json.decode(response.body); isLoading = false; });
    } catch (e) { setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search roles or companies...', prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true, fillColor: Colors.white,
              ),
              onSubmitted: (value) => fetchJobs(value),
            ),
          ),
          Expanded(
            child: isLoading ? const Center(child: CircularProgressIndicator())
                : ListView.builder(itemCount: jobs.length, itemBuilder: (context, index) => JobCard(job: jobs[index])),
          ),
        ],
      ),
    );
  }
}

// --- JOB CARD (WITH BOTTOM SHEET) ---
class JobCard extends StatelessWidget {
  final dynamic job;
  const JobCard({super.key, required this.job});

  Future<void> _launchApplyLink(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) debugPrint('Could not launch $url');
  }

  void _showAllApplyOptions(BuildContext context, List<dynamic> sources) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text('Choose how to apply', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ...sources.map((source) => ListTile(
                leading: const Icon(Icons.open_in_new, color: AppTheme.primaryBlue),
                title: Text(source['source_name']),
                trailing: source['is_easy_apply'] ? const Icon(Icons.bolt, color: Colors.amber) : null,
                onTap: () { Navigator.pop(context); _launchApplyLink(source['url']); },
              )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = List.from(job['sources'] ?? []);
    if (sources.isEmpty) return const SizedBox();
    final primarySource = sources.firstWhere((s) => s['source_name'] == 'Company Site', orElse: () => sources.first);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.network(job['logo'], width: 40, height: 40, errorBuilder: (c, e, s) => const Icon(Icons.business, size: 40)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${job['company']} • ${job['location']}', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                    onPressed: () => _launchApplyLink(primarySource['url']),
                    child: Text('Apply via ${primarySource['source_name']}'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => _showAllApplyOptions(context, sources))
              ],
            )
          ],
        ),
      ),
    );
  }
}

// --- 2. SAVED JOBS SCREEN ---
class SavedJobsScreen extends StatelessWidget {
  const SavedJobsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: AppTheme.primaryBlue, indicatorColor: AppTheme.primaryBlue,
              tabs: [Tab(text: "Saved (1)"), Tab(text: "Applied (0)"), Tab(text: "Interviews (0)")],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Card(child: ListTile(title: Text("ServiceNow Developer"), subtitle: Text("Deloitte • Hyderabad"), trailing: Icon(Icons.bookmark, color: AppTheme.primaryBlue))),
                    ],
                  ),
                  const Center(child: Text("Jobs you applied to will appear here.")),
                  const Center(child: Text("Upcoming interviews will appear here.")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. USER PROFILE SCREEN ---
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Center(child: CircleAvatar(radius: 50, backgroundColor: AppTheme.primaryBlue, child: Icon(Icons.person, size: 50, color: Colors.white))),
          const SizedBox(height: 16),
          const Center(child: Text("Welcome, User", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
          const Center(child: Text("IT Professional • Hyderabad", style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 32),
          const Text("Resume", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text("My_Resume.pdf"), subtitle: const Text("Updated recently"),
              trailing: IconButton(icon: const Icon(Icons.upload_file), onPressed: () {}),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(title: const Text("Job Alerts"), subtitle: const Text("Get notified for new roles"), value: true, onChanged: (bool value) {}, activeColor: AppTheme.primaryBlue),
        ],
      ),
    );
  }
}
