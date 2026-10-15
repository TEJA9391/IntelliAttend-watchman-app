# IntelliAttend Faculty — Support Module — Enterprise Technical Documentation

> **App:** `intelli_attend_faculty` (v1.0.0+1)
> **Module:** Support (About App, Help Center, Report Issue, Live Support Chat)
> **Documentation Level:** Enterprise architecture — suitable for onboarding, maintenance, audits, and feature development.
> **Companion Docs:** `docs/technical/PROFILE_MODULE.md`, `docs/technical/HOME_MODULE.md`, `docs/technical/ANALYTICS_MODULE.md`, `docs/technical/PROJECT_OVERVIEW.md`, `docs/technical/TECH_STACK.md`
> **Cross-reference:** The Profile module doc covers these pages at a summary level in §10 ("Help & Support Pages") and its Appendices A-7/A-8. This document is the dedicated deep-dive.

---

## Table of Contents

1. [Module Overview](#1-module-overview)
2. [Layered Architecture & Data Flow](#2-layered-architecture--data-flow)
3. [State Management Wiring](#3-state-management-wiring)
4. [Screen Structure — Widget Trees](#4-screen-structure--widget-trees)
5. [`AboutAppPage` — Static Branding Surface](#5-aboutapppage--static-branding-surface)
6. [`HelpCenterPage` — Searchable FAQ & Category Grid](#6-helpcenterpage--searchable-faq--category-grid)
7. [`ReportIssuePage` — Simulated Issue Form](#7-reportissuepage--simulated-issue-form)
8. [`LiveSupportChatPage` — Keyword-Matching Mock Chat](#8-livesupportchatpage--keyword-matching-mock-chat)
9. [Simulated Support Analysis — Real vs Simulated](#9-simulated-support-analysis--real-vs-simulated)
10. [Data Models & DTOs](#10-data-models--dtos)
11. [Backend API Reference](#11-backend-api-reference)
12. [WebSocket Real-Time Protocol](#12-websocket-real-time-protocol)
13. [Navigation Map](#13-navigation-map)
14. [Sequence Diagrams](#14-sequence-diagrams)
15. [Error Handling & Edge Cases](#15-error-handling--edge-cases)
16. [Performance Engineering](#16-performance-engineering)
17. [Security](#17-security)
18. [Dependencies Used](#18-dependencies-used)
19. [File Inventory](#19-file-inventory)
20. [Appendix A — Known Design Notes & Technical Debt](#20-appendix-a--known-design-notes--technical-debt)

---

## 1. Module Overview

### 1.1 Purpose

The **Support Module** is a set of four self-contained push screens under `lib/Presentation/Features/Support/` that form the app's user-facing help surface: an **About** page, a **Help Center** (FAQ + categories + live-chat CTA), a **Report an Issue** form, and a **Live Support Chat** (labelled "IntelliBot"). The module is **100 % presentation-layer code**: it contains no networking, no services, no repositories, no models, and no state beyond local `State` — every interactive outcome is either static content or a simulated delay.

### 1.2 Business Goal

- Give faculty a **credible support story** without standing up a support backend: static FAQs, a plausible issue-reporting form, and a "live" chat that is actually a keyword-matching mock bot.
- Provide **self-service** for the three most common questions (attendance workflow, offline sync, data security) so the support inbox is not flooded with onboarding questions.
- Present an **institutional veneer** (mission statement, copyright, "24/7 support team") that matches the product's marketing.

### 1.3 Problem Statement

- A real helpdesk (ticketing, live agents, WebSocket chat) is expensive and out of scope for the current release; the product needs a **zero-backend** substitute that is indistinguishable at the UI level.
- Faculty support queries are largely repetitive; FAQ + keyword chat cover the majority at near-zero cost.
- The About page must communicate version/build info, but the team never wired `package_info_plus`, so the version is hard-coded and drifts from the real package version.

### 1.4 Solution

- Four `StatefulWidget`/`StatelessWidget` screens, all reachable via anonymous `MaterialPageRoute`s from the Profile tab and dashboard surfaces.
- Help Center: 5 hard-coded FAQ entries (`help_center_page.dart:14–35`), a 4-item category grid whose tap **fills the search box** rather than navigating, and a gradient "Still need help?" CTA that pushes the chat.
- Report Issue: a validated form that on submit awaits `Future.delayed(Duration(seconds: 2))` (`report_issue_page.dart:31`) and shows a success dialog — **no server call**.
- Live Support Chat: a 2-second `Timer` "typing" delay then `_getBotResponse` (`live_support_chat_page.dart:56–69`), a pure `contains(...)` keyword match. **No WebSocket, no agent, no persistence.**

### 1.5 Target Users

- **Faculty members** — reached from Profile → "Help & Support" (About / Help Center / Report an Issue), the dashboard "Support" quick action (Help Center), and the drawer's "AI Faculty Assistant" (Live Support Chat).

### 1.6 Faculty Workflow (Support-driven)

```
Profile tab → Help & Support
   ├─ About IntelliAttend → AboutAppPage   (static version/branding)
   ├─ Help Center → HelpCenterPage
   │     ├─ search box filters 5 FAQs client-side
   │     ├─ category tiles fill the search box
   │     └─ "Contact Live Support" → LiveSupportChatPage
   └─ Report an Issue → ReportIssuePage     (simulated 2 s submit → success dialog)

Dashboard Home → Quick Actions "Support" → HelpCenterPage   (dashboard_sections.dart:149–151)
AppDrawer → SECURITY & CLOUD → "AI Faculty Assistant" → LiveSupportChatPage   (app_drawer.dart:125–128)
```

---

## 2. Layered Architecture & Data Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│  PRESENTATION (100 % of the module — no service/repository/model layer)     │
│                                                                              │
│  AboutAppPage (StatelessWidget)        — pure static markup                  │
│  HelpCenterPage (StatefulWidget)       — local _faqs list + search filter    │
│  ReportIssuePage (StatefulWidget)      — local form state + simulated delay  │
│  LiveSupportChatPage (StatefulWidget)  — local _messages list + mock bot     │
│                                                                              │
│  State held ONLY in State objects: TextEditingControllers, _isSubmitting,    │
│  _isTyping, _messages, _filteredFaqs.  No singletons, no Provider.           │
└──────────────┬───────────────────────────────────────────────────────────────┘
               │ Navigator.push(MaterialPageRoute) — anonymous routes only
               │ NO ApiClient · NO Dio · NO Firebase · NO WebSocket · NO Hive
               ▼
   (No backend interaction exists. All "async" work is Future.delayed / Timer.)
```

### 2.1 Data flow characteristics

```
HelpCenterPage:
   _faqs (hard-coded list) ──► _filteredFaqs getter (search query filter) ──► ListView

ReportIssuePage:
   _submitIssue() → validate() → Future.delayed(2s) → _showSuccessDialog()
                       └─ nothing leaves the device

LiveSupportChatPage:
   _handleSendMessage() → append user msg → Timer(2s) → _getBotResponse(msg)
                              └─ string.contains() branch → append bot msg
```

There is **no data flow beyond widget state**. This is the defining architectural fact of the module: it is a static/simulated surface with zero I/O.

---

## 3. State Management Wiring

| Concern | Mechanism |
|---|---|
| Help Center search query | `TextEditingController _searchController` + `setState` on `onChanged` (help_center_page.dart:13, 114) |
| Help Center FAQ list | Local hard-coded `List<Map<String, String>> _faqs` (help_center_page.dart:14–35) |
| Report form fields | `_subjectController`, `_descriptionController`, `_selectedCategory` (report_issue_page.dart:13–15) |
| Report submitting flag | `bool _isSubmitting` + `setState` (report_issue_page.dart:16, 28, 34) |
| Chat transcript | Local `List<Map<String, dynamic>> _messages` in State (live_support_chat_page.dart:15–21) |
| Chat typing flag | `bool _isTyping` + `setState` (live_support_chat_page.dart:22) |

- The module uses **only local `StatefulWidget` state**. There is no `Provider`, no `ChangeNotifier`, no `ValueNotifier`, no singleton, no DI. `context.read` / `context.watch` appear **nowhere** in the four files.
- The chat's "typing..." and reply are produced by a raw `Timer`, not a stream or service — the bot has no memory beyond the in-memory `_messages` list and no personality beyond `String.contains()`.

---

## 4. Screen Structure — Widget Trees

### 4.1 `AboutAppPage` (StatelessWidget)

```
Scaffold (bg: AppTheme.bg)
└─ AppBar (transparent, elevation 0, back arrow → Navigator.pop, title "About IntelliAttend")
└─ body: SingleChildScrollView(padding h24 v32, center-aligned Column)
   ├─ Logo placeholder Container 120×120 (primary 0.1 tint, radius 32, glow shadow)
   │    └─ Icons.school_rounded (64, primary)
   ├─ "IntelliAttend Faculty" (26 w900)
   ├─ "Version 2.4.0 (Build 108)" (slate500, 14)          ← hard-coded (A-1)
   ├─ _buildSection("Our Mission", mission text, maxLines 5 ellipsis)
   ├─ _buildInfoCard: Container(radius 24, surface, border)
   │    ├─ _buildInfoRow(language_rounded, "Official Website", "www.intelliattend.com")
   │    ├─ Divider + _buildInfoRow(privacy_tip, "Privacy Policy", "View Document")
   │    └─ Divider + _buildInfoRow(description, "Terms of Service", "View Document")
   │         └─ rows are PLAIN Rows — no onTap, no url_launcher (A-2)
   ├─ "© 2026 IntelliAttend Technologies" (12 w900)
   └─ "Made with … for Educators Worldwide" (11, 0.6 alpha; renders a heart glyph)
```

### 4.2 `HelpCenterPage` (StatefulWidget)

```
Scaffold (bg: AppTheme.bg)
└─ AppBar (back arrow → pop, title "Help Center", centerTitle)
└─ body: Column
   ├─ RepaintBoundary(_buildSearchBar)      TextField w/ search + clear suffix
   │    └─ onChanged → setState (re-runs _filteredFaqs)
   └─ Expanded(RepaintBoundary(ListView padding 24))
        ├─ "Popular Categories" header
        ├─ _buildCategoriesGrid: GridView(2 cols, aspect 2.2, NeverScrollable)
        │    ├─ Account     (account_circle_outlined)
        │    ├─ Attendance  (qr_code_scanner_rounded)
        │    ├─ Analytics   (analytics_outlined)
        │    └─ Security    (security_rounded)
        │         └─ onTap → setState(searchController.text = category name)   (A-3)
        ├─ "Frequently Asked Questions" header
        ├─ _filteredFaqs.isEmpty → "No FAQs found for your search."
        │    else ..._filteredFaqs.map(_buildFaqTile)  ExpansionTile (question/answer)
        └─ _buildContactSupport: gradient Container (primary→0.8), support_agent icon,
             "Still need help?", "Our support team is available 24/7 …",
             ElevatedButton "Contact Live Support" → push LiveSupportChatPage
```

### 4.3 `ReportIssuePage` (StatefulWidget)

```
Scaffold (bg: AppTheme.bg)
└─ AppBar (back arrow → pop, title "Report an Issue")
└─ body: RepaintBoundary(SingleChildScrollView padding 24 → Form(_formKey, Column))
   ├─ _SectionTitle "Issue Category" → _buildCategoryDropdown
   │    DropdownButton<String> default "Technical Bug", 5 options (report_issue_page.dart:18–24)
   ├─ _SectionTitle "Subject" → _buildTextField
   │    hint "E.g., QR code not loading", validator: empty → "Please enter a subject"
   ├─ _SectionTitle "Detailed Description" → _buildTextField(maxLines: 6)
   │    validator: empty → "Please enter a description"
   ├─ _buildSubmitButton: full-width 56 ElevatedButton
   │    _isSubmitting ? disabled + CircularProgressIndicator : "Submit Report"
   └─ "By submitting, you agree to our Support Terms" (slate500, 12)
```

### 4.4 `LiveSupportChatPage` (StatefulWidget)

```
Scaffold (bg: AppTheme.bg)
└─ AppBar (surface bg, CLOSE icon → pop, title Row: smart_toy avatar chip + Column)
   │    ├─ "IntelliBot" (16 w900)
   │    └─ _isTyping ? "Typing..." (primary) : "Online Assistant" (greenOnline)
└─ body: Column
   ├─ Expanded(RepaintBoundary(ListView.builder padding 20, controller _scrollController))
   │    └─ itemBuilder → _buildMessageBubble(msg)
   │         Align (bot left / user right), maxWidth 75% viewport,
   │         bot = surface + border / user = primary, tail-corner radius 4,
   │         text maxLines 50 ellipsis, TimeOfDay.fromDateTime footer (10)
   ├─ if (_isTyping) _buildTypingIndicator (3 animated-ish dots — static Circles)
   └─ _buildMessageInput: surface Container + safe-area bottom padding
        Row [ TextField("Type a message...", onSubmitted)  |  send CircleAvatar IconButton ]
```

---

## 5. `AboutAppPage` — Static Branding Surface

**File:** `lib/Presentation/Features/Support/about_app_page.dart` (188 LOC)

- `const AboutAppPage({Key? key})` — a `StatelessWidget`; zero fields, zero I/O.
- Version string **"Version 2.4.0 (Build 108)"** is a hard-coded literal at about_app_page.dart:67. `pubspec.yaml:5` declares **`1.0.0+1`**. No `PackageInfo.fromPlatform()` is used anywhere in the page (see A-1 and PROFILE_MODULE.md A-7).
- Mission copy at about_app_page.dart:78; rendered with `maxLines: 5` + `TextOverflow.ellipsis` — a long string can be silently truncated on narrow screens.
- Info card (about_app_page.dart:136–157): three `_buildInfoRow`s. Each row is a plain `Row` of icon + label + value + chevron — **there is no `InkWell`, `onTap`, or `url_launcher` call**, so "Privacy Policy" / "Terms of Service" ("View Document") and the website row are display-only (A-2).
- Footer: `"© 2026 IntelliAttend Technologies"` (line 84) and a "Made with … for Educators Worldwide" tagline (line 93, includes a heart glyph). The copyright year is another hard-coded value that will silently age (A-4).

---

## 6. `HelpCenterPage` — Searchable FAQ & Category Grid

**File:** `lib/Presentation/Features/Support/help_center_page.dart` (286 LOC)

### 6.1 FAQ data (help_center_page.dart:14–35)

Five static entries stored as `List<Map<String, String>>`:

| # | Question (key `question`) | Answer summary (key `answer`) |
|---|---|---|
| 1 | "How do I take attendance?" | Dashboard → select class → "Go Live" QR session |
| 2 | "Can I edit attendance later?" | Reports section, toggle status per student |
| 3 | "What if a student doesn't have a phone?" | "Manual Entry" option within live session / reports |
| 4 | "How do I sync offline data?" | Auto-sync on connection; manual sync from **"Profile -> Sync Settings"** — a screen that **does not exist** in the codebase (A-5) |
| 5 | "Is my data secure?" | Claims end-to-end encryption + enforced biometric login (unverifiable from this module; A-6) |

### 6.2 Search filter (help_center_page.dart:37–44)

```dart
List<Map<String, String>> get _filteredFaqs {
  final query = _searchController.text.toLowerCase();
  if (query.isEmpty) return _faqs;
  return _faqs.where((faq) {
    return faq["question"]!.toLowerCase().contains(query) ||
           faq["answer"]!.toLowerCase().contains(query);
  }).toList();
}
```

- Case-insensitive substring match against **both** question and answer.
- `TextField.onChanged` calls `setState(() {})` (line 114), so every keystroke re-runs the getter.
- Empty result → inline "No FAQs found for your search." (lines 81–88).

### 6.3 Category grid (help_center_page.dart:144–195)

- Four tiles: **Account**, **Attendance**, **Analytics**, **Security**.
- Tap behaviour (lines 163–168) is **not** navigation: it sets `_searchController.text = category name`. This populates the search box; whether it actually filters anything depends on the FAQ text matching the category word (e.g., "Security" matches FAQ 5; "Analytics" matches nothing — A-3).
- `GridView.builder` with `shrinkWrap: true` + `NeverScrollableScrollPhysics` inside the outer `ListView`.

### 6.4 Contact CTA (help_center_page.dart:235–296)

- Gradient promo card: "Still need help?", "Our support team is available 24/7 to assist you…", and a white `ElevatedButton` "Contact Live Support" that pushes `LiveSupportChatPage` (lines 277–292). The "24/7 team" claim is unsupported by any real backend (A-7).

---

## 7. `ReportIssuePage` — Simulated Issue Form

**File:** `lib/Presentation/Features/Support/report_issue_page.dart` (230 LOC)

### 7.1 Form contract

- Category dropdown, 5 hard-coded options (lines 18–24): `Technical Bug`, `Attendance Sync Issue`, `User Interface Glitch`, `Feature Request`, `Other`. Default `"Technical Bug"` (line 13).
- Subject: single-line `TextFormField`, required validator `"Please enter a subject"` (line 123).
- Description: 6-line field, required validator `"Please enter a description"` (line 132).
- Both fields are wrapped in styled `Container`s; `Form` keyed by `_formKey`.

### 7.2 Submit flow — the simulation (lines 26–38)

```dart
void _submitIssue() async {
  if (_formKey.currentState!.validate()) {
    setState(() => _isSubmitting = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isSubmitting = false);
      _showSuccessDialog();
    }
  }
}
```

- The literal code comment **`// Simulate API call`** (line 30) confirms intent: there is **no Dio/ApiClient, no repository, no persistence, no ticket ID**.
- During the 2 s window the button is disabled and shows an inline white `CircularProgressIndicator` (lines 207, 212–217).
- Success dialog (`_showSuccessDialog`, lines 40–83): `barrierDismissible: false`, green check icon, "Report Submitted", "…our support team will review your report…", "Done" button pops the dialog **and** the page (lines 73–76).
- The form footer claims "By submitting, you agree to our Support Terms" (line 139) — a contract implication with no Terms artifact anywhere in the app (A-8).

---

## 8. `LiveSupportChatPage` — Keyword-Matching Mock Chat

**File:** `lib/Presentation/Features/Support/live_support_chat_page.dart` (248 LOC)

### 8.1 Chat surface

- Transcript: local `List<Map<String, dynamic>> _messages`, seeded with one bot greeting on construction (lines 15–21). Each message is `{"text": String, "isBot": bool, "time": DateTime}`.
- Header "IntelliBot" with a live presence sub-label that flips to "Typing..." while `_isTyping` (lines 116–123).
- `_scrollToBottom()` (lines 71–81) uses a `Timer(Duration(milliseconds: 100))` to animate after layout settles.
- Bubbles: bot left (surface + border), user right (primary, white text); max width 75 % of viewport; timestamp from `TimeOfDay` (line 184).

### 8.2 Simulated bot turn (lines 24–54)

```dart
// Simulated Bot Response
Timer(const Duration(seconds: 2), () {
  if (mounted) {
    setState(() {
      _isTyping = false;
      _messages.add({
        "text": _getBotResponse(userMessage),
        "isBot": true,
        "time": DateTime.now(),
      });
    });
    _scrollToBottom();
  }
});
```

### 8.3 Keyword-matching rules — `_getBotResponse` (lines 56–69)

The bot normalises to lowercase then evaluates **in order**, first match wins:

```dart
if (message.contains("attendance")) {                     // line 58
  return "To take attendance, go to the Dashboard, select your class, and click 'Go Live'. …";
} else if (message.contains("report") || message.contains("analytics")) {   // line 60
  return "The Reports Center provides real-time analytics … export them as PDF or CSV from the top-right menu.";
} else if (message.contains("sync") || message.contains("offline")) {       // line 62
  return "The app syncs automatically. … check your sync status in Profile > Sync Settings.";  // phantom screen (A-5)
} else if (message.contains("hello") || message.contains("hi")) {           // line 64
  return "Hi there! I'm here to help …";
} else {                                                                    // line 66
  return "I'm not sure about that, but I'm learning! … check the Help Center …";
}
```

Rules observed:

- Branch ordering matters: any message containing "attendance" (e.g., "report attendance") hits branch 1; "reports analytics" hits branch 2; "hi, I have a report" hits branch 2 before branch 4.
- No scoring, no stemming, no intents — pure substring containment.
- The "Profile > Sync Settings" answer (line 63) duplicates the phantom reference from FAQ 4 (A-5).

### 8.4 What it is not

- **Not a WebSocket.** `dart:async` is imported only for `Timer`; there is no `WebSocket`, `Socket`, `dio`, `firebase`, or stream.
- **Not a live agent.** The "Online Assistant" presence label is decorative; the only producer of bot text is `_getBotResponse`.
- **No persistence.** Closing the page discards the transcript; there is no history, no handoff, no ticket.

---

## 9. Simulated Support Analysis — Real vs Simulated

This is the single most important section of the module: **nothing in the Support module touches the network**. Evidence-based matrix:

| Feature | Status | Evidence |
|---|---|---|
| About version/build display | **SIMULATED (hard-coded)** | `"Version 2.4.0 (Build 108)"` literal at `about_app_page.dart:67`; `pubspec.yaml:5` declares `1.0.0+1`. No `PackageInfo`/`package_info_plus` usage in the page |
| About website / Privacy / Terms rows | **SIMULATED (display-only)** | Plain `Row`s in `_buildInfoRow` (`about_app_page.dart:159–192`); no `onTap`, no `url_launcher` import |
| Help Center FAQ content | **STATIC (local data)** | Hard-coded list `help_center_page.dart:14–35`; no fetch, no CMS |
| Help Center search | **REAL logic, no backend** | Client-side filter `_filteredFaqs` (`help_center_page.dart:37–44`) — works, but operates only on static data |
| Category grid navigation | **SIMULATED (search-box fill)** | `onTap` sets `_searchController.text` (`help_center_page.dart:163–168`) instead of navigating |
| "24/7 support team" claim | **SIMULATED (marketing copy)** | Static text `help_center_page.dart:267`; no live support system exists |
| Report Issue submit | **SIMULATED** | `await Future.delayed(const Duration(seconds: 2))` + comment `// Simulate API call` (`report_issue_page.dart:30–31`); no API, no repository, no ticket ID |
| Report success dialog | **SIMULATED** | `_showSuccessDialog` (`report_issue_page.dart:40–83`) renders from the 2 s timer, not a server response |
| "Support Terms" agreement | **SIMULATED (unfounded)** | Static caption `report_issue_page.dart:139`; no Terms artifact in the repo |
| Live chat bot reply | **SIMULATED** | `Timer(Duration(seconds: 2))` + comment `// Simulated Bot Response` (`live_support_chat_page.dart:40–41`); reply from `_getBotResponse` keyword match |
| Live chat presence "Online Assistant" | **SIMULATED (decorative)** | Static label toggled only by `_isTyping` (`live_support_chat_page.dart:117`) |
| WebSocket / socket transport | **ABSENT** | No `WebSocket`/`Socket`/stream/dio/Firebase imports in any of the four files |
| Backend API usage | **NONE** | Grep for `api/v1`, `http`, `dio`, `ApiClient`, `Firebase` across `lib/Presentation/Features/Support/` returns **zero** hits |
| Persistence | **NONE** | No Hive, no SharedPreferences, no secure storage in the module |

**Bottom line:** the Support module is an entirely client-side, zero-I/O surface. The only "real" computation in the module is the client-side FAQ substring search. Everything else — version info, submit latency, chat replies, presence, service promises — is simulated. No faculty-reported data ever leaves the device; conversely, no real helpdesk ever receives the "reports" or the chat.

---

## 10. Data Models & DTOs

The module defines **no models, no DTOs, no serialization** and reuses none. The two data containers are untyped maps held in widget state:

| Container | Type | Location |
|---|---|---|
| `_faqs` | `List<Map<String, String>>` with keys `question` / `answer` | `help_center_page.dart:14` |
| `_messages` | `List<Map<String, dynamic>>` with keys `text` / `isBot` / `time` | `live_support_chat_page.dart:15` |

Both are stringly-typed ad-hoc maps — there is no `fromJson`, no type safety, and no shared contract (A-9).

---

## 11. Backend API Reference

| Endpoint | Verb | Used by | Notes |
|---|---|---|---|
| — | — | — | **None.** The Support module makes zero API calls. |

The module imports only `flutter/material` and `theme/app_theme.dart` (plus `live_support_chat_page.dart` inside `help_center_page.dart`). `ApiClient().dio`, `FirebaseAuth`, and the `https://api-dev.balaseetharamanjaneya.com` base are **not referenced by any Support file**. If issue reporting or live chat is ever to be real, new endpoints (e.g., `POST /api/v1/support/issues`, `WS /api/v1/support/chat`) would need to be defined — none exist today.

---

## 12. WebSocket Real-Time Protocol

The Support module opens **no WebSocket channels** and has no real-time transport of any kind. The "Live Support Chat" is a misnomer: "live" refers only to the presence/typing affordances and the 2 s simulated latency. A repo-wide search for `WebSocket`/`socket` across the four Support files returns nothing. This contradicts the surface-level impression created by the page title, "Online Assistant" status, and "24/7" copy — see §9 and A-7.

---

## 13. Navigation Map

```
DashboardScreen — Home tab
   └─ Quick Actions row (dashboard_sections.dart:135–152)
        └─ "Support" (help_outline_rounded) ──► HelpCenterPage     (dashboard_sections.dart:149–151)
             └─ "Contact Live Support" ──► LiveSupportChatPage     (help_center_page.dart:278–281)

ProfileScreen — "HELP & SUPPORT" section (profile_screen.dart:237–248)
   ├─ "About IntelliAttend" (info_outline)  ──► AboutAppPage       (profile_screen.dart:237–240)
   ├─ "Help Center" (help_outline)          ──► HelpCenterPage     (profile_screen.dart:241–244)
   └─ "Report an Issue" (mail_outline)      ──► ReportIssuePage    (profile_screen.dart:245–248)

AppDrawer — SECURITY & CLOUD (app_drawer.dart:125–128)
   └─ "AI Faculty Assistant" (psychology_rounded) ──► LiveSupportChatPage  (pops drawer first)

All routes are anonymous MaterialPageRoutes; every page returns via Navigator.pop
(AppBar back / chat close icon). No deep links, no named routes, no tabs.
```

Note the semantic asymmetry (A-10): the dashboard calls it **"Support"**, the drawer calls the chat **"AI Faculty Assistant"**, and the chat header calls itself **"IntelliBot"** — three names for one product surface.

---

## 14. Sequence Diagrams

### 14.1 Help Center search

```
HelpCenterPage build
   └─ _filteredFaqs getter reads _searchController.text (empty → all 5)
        └─ ListView renders FAQ ExpansionTiles
User types "offline" → TextField.onChanged → setState
   └─ _filteredFaqs: faq.answer.toLowerCase().contains("offline")
        ├─ FAQ 4 match → tile shown
        └─ others filtered out
User taps clear (x) → controller.clear() + setState → all 5 restored
User taps category "Security" → setState(searchController.text = "Security")
   └─ filter runs → only FAQ 5 matches (see A-3)
```

### 14.2 Submit issue (simulated)

```
ReportIssuePage "Submit Report" tap
   └─ _formKey.currentState!.validate()
        ├─ invalid (empty subject/description) → inline validator messages
        └─ valid → setState(_isSubmitting = true)
             └─ await Future.delayed(2s)                       // NO network
                  └─ (mounted guard) setState(_isSubmitting = false)
                       └─ _showSuccessDialog() (barrierDismissible: false)
                            └─ "Done" → Navigator.pop (dialog) + Navigator.pop (page)
                                        → back to Profile tab
   (Nothing was persisted; no ticket exists server-side — A-8)
```

### 14.3 Live chat turn (simulated)

```
LiveSupportChatPage — user types "How do I report a bug?" + send
   └─ _handleSendMessage
        ├─ trim empty guard
        ├─ _messages.add(user msg); _messageController.clear(); _isTyping = true
        ├─ _scrollToBottom()
        └─ Timer(2s) → mounted → _isTyping = false
             └─ _getBotResponse("how do i report a bug?")
                  ├─ contains("attendance")? no
                  ├─ contains("report")||contains("analytics")? YES  → branch 2
                  │    "The Reports Center provides real-time analytics … PDF or CSV …"
                  └─ _messages.add(bot msg); _scrollToBottom()
   (No server, no agent, no transcript persistence)
```

---

## 15. Error Handling & Edge Cases

| Case | Handling |
|---|---|
| Empty search query | `_filteredFaqs` returns all 5 FAQs |
| Search with no matches | Inline "No FAQs found for your search." (help_center_page.dart:81–88) |
| Empty chat message / whitespace-only | `_handleSendMessage` early-returns (live_support_chat_page.dart:25) |
| `setState` after unmount in chat | `mounted` guard inside the 2 s `Timer` (live_support_chat_page.dart:42) |
| `setState` after unmount in report form | `mounted` guard after the 2 s delay (report_issue_page.dart:33) |
| Invalid report form | Form validators surface per-field messages; no submit occurs |
| Scrolling during message burst | `_scrollToBottom` guards `_scrollController.hasClients` (line 73) |
| `_filteredFaqs` null keys | Null-safe via `!` operators — a malformed FAQ map would throw (no guard; A-9) |
| Network / backend failures | **Not applicable** — there is no backend to fail |
| Keyboard overlap in chat | Input bar adds `MediaQuery.padding.bottom` to its padding (line 223) |

Notably, because all async work is `Timer`/`Future.delayed`, the only realistic failure modes are unmount timing (both guarded) — there is **no offline story to handle** and no error surface for the (nonexistent) backend.

---

## 16. Performance Engineering

- **Zero network**: no requests, no latency budget, no caching concerns — the module cannot be slow on I/O grounds.
- **Scoped repaints**: both `HelpCenterPage` and `LiveSupportChatPage` wrap their scrollable content in `RepaintBoundary` (help_center_page.dart:69, 71; live_support_chat_page.dart:132, 221), and `ReportIssuePage` wraps its form (report_issue_page.dart:106) — typing/animations stay isolated.
- **Search cost**: `_filteredFaqs` runs a 5-item scan per keystroke — trivial, but done via `setState` on every `onChanged` (help_center_page.dart:114) rather than a debounced listener (A-11).
- **Chat list**: `ListView.builder` over the transcript; bubbles cap text at `maxLines: 50` with ellipsis, so pathological messages can't blow up layout.
- **No heavy dependencies**: no images, no fonts, no charts in the Support folder; all four screens are text/container UI.
- **Low-risk surface**: no timers leak (each is fire-and-forget inside `mounted` checks), no streams, no controllers left undisposed (the `TextEditingController`s are never explicitly disposed — a minor leak-class note; see A-11).

---

## 17. Security

- **No PII transmission**: because the module performs zero I/O, faculty names, emails, issue descriptions, and chat text **never leave the device**. This is the strongest security property of the module — but it is a side effect of non-implementation, not of design (A-8).
- **In-memory only**: `_messages` and form fields live in `State` and vanish on navigation; no Hive/SecureStorage writes.
- **No secrets**: no keys, tokens, or credentials in any Support file.
- **Misleading-trust surface**: the module *implies* a real contract where none exists — "By submitting, you agree to our Support Terms" (report_issue_page.dart:139) and "end-to-end encryption for all attendance records" (help_center_page.dart:33). If a future build wires these surfaces to a real backend, PII (emails, free-text descriptions, chat logs) will suddenly be transmitted and must get transport (JWT via `ApiClient`) and retention review. The current privacy posture is "nothing is collected" only because nothing is connected (A-8).
- **Hard-coded branding**: the version/copyright literals are not user input and are not injectable; they are simply stale (A-1, A-4).

---

## 18. Dependencies Used

| Package | Where used in Support module |
|---|---|
| `flutter/material` | All four screens (layout, forms, dialogs, timers) |
| `intelli_attend_faculty/theme/app_theme.dart` | Theme tokens (`AppTheme.bg`, `.primary`, `.surface`, `.text`, `.slate500`, `.greenOnline`, `.border`) across all four screens |
| `live_support_chat_page.dart` (intra-module) | Imported by `help_center_page.dart:3` for the Contact CTA |

The module adds **no pub.dev packages of its own**. Notably absent despite being declared in `pubspec.yaml`: `dio`, `provider`, `firebase_*`, `package_info_plus` (declared `^8.0.0`, used by `hardware_service.dart:60` and `login_screen.dart:46`, **dead-imported** in `profile_screen.dart:13`, and not used by any Support file — see PROFILE_MODULE.md A-7), `url_launcher` (would be the natural fit for the About-page links — not imported, A-2).

---

## 19. File Inventory

> Line counts = non-blank lines (`Measure-Object -Line`), verified.

### 19.1 Support feature — `lib/Presentation/Features/Support/`

| File | LOC | Role |
|---|---|---|
| `about_app_page.dart` | 188 | Static About: logo, hard-coded version, mission, display-only info rows |
| `help_center_page.dart` | 286 | Searchable static FAQ (5), category grid, live-chat CTA |
| `report_issue_page.dart` | 230 | Issue form with simulated 2 s submit + success dialog |
| `live_support_chat_page.dart` | 248 | Mock chat (IntelliBot) with keyword-matching responses |
| **Total** | **952** | |

### 19.2 Navigation entry points (outside the module)

| File | LOC | Entry |
|---|---|---|
| `lib/Presentation/Features/Profile/profile_screen.dart` | 968 | Help & Support section → About/Help/Report (lines 237–248) |
| `lib/Presentation/Features/Faculty/Components/dashboard_sections.dart` | 186 | Quick Action "Support" → HelpCenterPage (lines 149–151) |
| `lib/Presentation/Widgets/app_drawer.dart` | 375 | "AI Faculty Assistant" → LiveSupportChatPage (lines 125–128) |

### 19.3 Services / data layer

| File | LOC | Role |
|---|---|---|
| — | — | **None.** The module defines and consumes no services, repositories, or models. |

---

## 20. Appendix A — Known Design Notes & Technical Debt

### A-1. Hard-coded version string drifts from pubspec (HIGH)

`AboutAppPage` renders **"Version 2.4.0 (Build 108)"** as a literal (about_app_page.dart:67) while `pubspec.yaml:5` declares **1.0.0+1**. `package_info_plus` (`^8.0.0`) is available in the project (used by `hardware_service.dart:60`, `login_screen.dart:46`) but not imported here; `profile_screen.dart:13` even imports it unused. The About page should read `PackageInfo.fromPlatform()`; until then every release silently misreports its version. (Cross-ref: PROFILE_MODULE.md A-7.)

### A-2. About-page info rows are display-only (LOW)

"Official Website", "Privacy Policy" ("View Document"), and "Terms of Service" ("View Document") are plain `Row`s with a chevron that implies a tappable link (about_app_page.dart:146–153, 159–192). There is no `onTap` and `url_launcher` is not imported — the rows are dead UI that misleads users into tapping nothing.

### A-3. Category tiles "navigate" by filling the search box (LOW)

Tapping Account/Attendance/Analytics/Security sets `_searchController.text` (help_center_page.dart:163–168) instead of navigating or expanding FAQs. Only categories whose word appears in FAQ text actually surface results ("Security" matches FAQ 5; "Analytics" matches nothing) — a user tapping "Analytics" sees an empty FAQ list and no guidance.

### A-4. Hard-coded copyright year and tagline (LOW)

"© 2026 IntelliAttend Technologies" (about_app_page.dart:84) and the footer in `profile_screen.dart:263` duplicate a year literal that will age; the About page also carries a heart-glyph tagline ("Made with … for Educators Worldwide", line 93). These should derive from a constant or build metadata.

### A-5. Phantom "Profile → Sync Settings" references (MEDIUM)

FAQ 4 (help_center_page.dart:29) and the bot's sync answer (live_support_chat_page.dart:63) both direct users to **"Profile -> Sync Settings"**. No such screen or setting exists anywhere in the codebase (repo-wide search returns only these two copy strings). The app does sync automatically via `FacultyHydrationService`, but there is no manual sync UI — the instructions are fiction and will confuse power users.

### A-6. Unverifiable security claims in FAQ (MEDIUM)

FAQ 5 asserts "end-to-end encryption for all attendance records" and "Biometric login is also enforced" (help_center_page.dart:33). `local_auth` is a project dependency, but nothing in this module verifies either claim; from the Support module's perspective these are marketing copy with no evidence. Product should confirm before publishing security claims.

### A-7. "24/7 support team" / live chat promises are unfounded (MEDIUM)

The Help Center CTA card states "Our support team is available 24/7" (help_center_page.dart:267) and routes to a chat whose only responder is a keyword bot (§9). Users who type an off-list question receive "I'm not sure about that, but I'm learning!" (line 67) with no escalation path, no email, no phone. If the product is not actually staffing support, the copy overpromises.

### A-8. Report Issue and Live Chat are fully simulated (HIGH — product trust)

`_submitIssue` awaits `Future.delayed(2s)` behind the explicit comment `// Simulate API call` (report_issue_page.dart:30–31); the chat reply comes from a `Timer(2s)` behind `// Simulated Bot Response` (live_support_chat_page.dart:40–41). No ticket is created, no chat is persisted, no agent is reachable, and no report or message ever leaves the device. The "Support Terms" agreement line (report_issue_page.dart:139) and the success-dialog "our support team will review your report" copy (line 62) imply a real SLA that does not exist. Recommend either standing up a real issue/chat backend or relabelling the surface as "feedback" / "demo assistant". (Cross-ref: PROFILE_MODULE.md A-8.)

### A-9. Stringly-typed ad-hoc data containers (LOW)

FAQs and chat messages are untyped `Map` literals (`help_center_page.dart:14`, `live_support_chat_page.dart:15`) accessed via `!`/`as` casts with no validation. A malformed entry would throw at runtime; there is no model, enum, or shared contract to catch schema drift.

### A-10. Naming inconsistency across entry points (LOW)

Dashboard labels it **"Support"** (dashboard_sections.dart:149), the drawer labels the same chat **"AI Faculty Assistant"** (app_drawer.dart:126), the chat header says **"IntelliBot"** with status **"Online Assistant"** (live_support_chat_page.dart:109, 117). Four names for one surface; the module doc and Profile doc (PROFILE_MODULE.md A-10) both flag related IA drift elsewhere in the app.

### A-11. Missing controller disposal + per-keystroke search (LOW)

`TextEditingController`s in `HelpCenterPage` (line 13), `ReportIssuePage` (lines 14–15), and `LiveSupportChatPage` (line 13) are never `dispose()`d — minor but inconsistent with Flutter hygiene. The Help Center re-filters on every keystroke via raw `setState` (line 114) with no debounce; trivial at 5 FAQs, it would not scale to a CMS-backed FAQ list.

---

*End of Support Module technical documentation. Companion: `PROFILE_MODULE.md`, `HOME_MODULE.md`, `ANALYTICS_MODULE.md`, `PROJECT_OVERVIEW.md`, `TECH_STACK.md`.*
