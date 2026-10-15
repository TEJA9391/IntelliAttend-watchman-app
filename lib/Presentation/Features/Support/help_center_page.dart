import 'package:flutter/material.dart';
import 'package:intelli_attend_faculty/Theme/app_theme.dart';
import 'live_support_chat_page.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({Key? key}) : super(key: key);

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, String>> _faqs = [
    {
      "question": "How do I take attendance?",
      "answer": "Navigate to the Dashboard, select your class, and click 'Go Live' to start the QR-based attendance session. Students can then scan the code from their app."
    },
    {
      "question": "Can I edit attendance later?",
      "answer": "Yes, go to the 'Reports' section, select the class date, and you can manually toggle the attendance status of any student."
    },
    {
      "question": "What if a student doesn't have a phone?",
      "answer": "You can manually mark them as present using the 'Manual Entry' option within the live session or later in the reports."
    },
    {
      "question": "How do I sync offline data?",
      "answer": "The app automatically syncs when it detects an internet connection. You can also trigger a manual sync from the Profile -> Sync Settings."
    },
    {
      "question": "Is my data secure?",
      "answer": "We use end-to-end encryption for all attendance records. Biometric login is also enforced for faculty access."
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _faqs;
    return _faqs.where((faq) {
      return faq["question"]!.toLowerCase().contains(query) ||
             faq["answer"]!.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Help Center",
          style: TextStyle(
            color: AppTheme.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          RepaintBoundary(child: _buildSearchBar()),
          Expanded(
            child: RepaintBoundary(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSectionHeader("Popular Categories"),
                  const SizedBox(height: 16),
                  _buildCategoriesGrid(),
                  const SizedBox(height: 32),
                  _buildSectionHeader("Frequently Asked Questions"),
                  const SizedBox(height: 16),
                  if (_filteredFaqs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text("No FAQs found for your search.", 
                          style: TextStyle(color: AppTheme.textSecondary(context))),
                      ),
                    )
                  else
                    ..._filteredFaqs.map((faq) => _buildFaqTile(faq["question"]!, faq["answer"]!)).toList(),
                  const SizedBox(height: 32),
                  _buildContactSupport(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() {}),
          style: TextStyle(color: AppTheme.text(context)),
          decoration: InputDecoration(
            hintText: "Search for help...",
            hintStyle: TextStyle(color: AppTheme.slate500(context)),
            prefixIcon: Icon(Icons.search, color: AppTheme.primary(context)),
            suffixIcon: _searchController.text.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18), 
                  onPressed: () { _searchController.clear(); setState(() {}); })
              : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.text(context),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    final categories = [
      {"icon": Icons.account_circle_outlined, "name": "Account"},
      {"icon": Icons.qr_code_scanner_rounded, "name": "Attendance"},
      {"icon": Icons.analytics_outlined, "name": "Analytics"},
      {"icon": Icons.security_rounded, "name": "Security"},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () {
            setState(() {
              _searchController.text = categories[index]["name"] as String;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                Icon(categories[index]["icon"] as IconData, color: AppTheme.primary(context), size: 24),
                const SizedBox(width: 12),
                Text(
                  categories[index]["name"] as String,
                  style: TextStyle(
                    color: AppTheme.text(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.text(context),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: AppTheme.primary(context),
        collapsedIconColor: AppTheme.slate500(context),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSupport() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary(context), AppTheme.primary(context).withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary(context).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.support_agent_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text(
            "Still need help?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Our support team is available 24/7 to assist you with any technical issues.",
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LiveSupportChatPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary(context),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              "Contact Live Support",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

