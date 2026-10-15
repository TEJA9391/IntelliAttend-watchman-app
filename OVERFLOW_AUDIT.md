# Layout Overflow Audit — IntelliAttend Faculty Mobile App

**Date:** 2026-07-17
**Scope:** All `.dart` files under `lib/`
**Pattern Categories:**
1. Fixed heights on Containers/SizedBox without scroll wrapping
2. Hardcoded widths that don't adapt to screen size
3. Nested Rows without Expanded/Flexible
4. Long Columns without SingleChildScrollView
5. Row with 3+ children (no Expanded/Flexible)
6. Large SizedBox heights (≥100px)
7. Text without overflow handling
8. Fixed-width Container/BoxConstraints in Row
9. Unconstrained PageView
10. Missing SafeArea

---

## Category 1: Fixed Heights (Rigid layout — overflow risk on small screens)

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `schedule_section.dart` | 279 | `height: 315` | Schedule card is a fixed 315px tall Container inside a PageView. On short screens (e.g., 480px height), the PageView + surrounding UI will overflow. |
| `schedule_section.dart` | 313 | `height: 175` | Schedule skeleton loader has a fixed 175px height. |
| `schedule_section.dart` | 477 | `height: 156` | Schedule card inner section fixed at 156px. |
| `schedule_section.dart` | 585 | `height: 156` | Another schedule section with fixed 156px height. |
| `attendance_code_screen.dart` | 479 | `height: 200` | QR code container fixed at 200x200. |
| `attendance_code_screen.dart` | 491 | `height: 160` | Countdown timer fixed at 160px. |
| `attendance_code_screen.dart` | 866 | `height: 160` | Second QR code area fixed at 160px. |
| `attendance_code_screen.dart` | 875 | `height: 140` | Info section fixed at 140px. |
| `attendance_code_screen.dart` | 887 | `height: 140` | Another info section fixed at 140px. |
| `analytics_screen.dart` | 177 | `SizedBox(height: 200, child: chart)` | Chart card fixed at 200px inside a Column, no scroll wrapper visible in snippet. |
| `reports_screen.dart` | 235-239 | `shimmerBase, shimmerHighlight, height: 320/260/200` | Shimmer loading placeholders with fixed heights up to 320px. |
| `profile_screen.dart` | 628 | `height: 230` | Profile header card fixed at 230px tall. |
| `overview_tab.dart` | 95 | `height: 150` | Gauge chart fixed at 150px. |
| `overview_tab.dart` | 255 | `height: 140` | Day chart fixed at 140px. |
| `attendance_chart.dart` | 48 | `height: 200` | Chart area fixed at 200px. |
| `report_distribution_chart.dart` | 53 | `height: 180` | Empty-state chart placeholder fixed at 180px. |
| `report_distribution_chart.dart` | 69 | `height: 180` | Doughnut chart fixed at 180px. |
| `analytics_tab.dart` | 175 | `height: 180` | Line chart fixed at 180px. |
| `analytics_tab.dart` | 260 | `height: 180` | Weekly trend chart fixed at 180px. |
| `unified_auth_gate.dart` | 156 | `height: 200` | Splash logo fixed at 200px. |
| `login_screen.dart` | 181 | `height: 200` | Login logo fixed at 200px. |
| `fingerprint_scan_overlay.dart` | 70 | `height: 150` | Fingerprint scan area fixed at 150px. |
| `compromised_device_screen.dart` | 22 | `height: 100` | Warning icon area fixed at 100px. |

### MODERATE RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `session_control_section.dart` | 159, 291, 393, 516 | `height: 128` (×4) | Session control stat cards each have 128px fixed height in a row. |
| `registration_screen.dart` | 99 | `height: 120` | Registration logo fixed at 120px. |
| `about_app_page.dart` | 37 | `height: 120` | App logo fixed at 120px. |
| `report_helper_widgets.dart` | 336 | `height: 100` | Loading spinner fixed at 100px. |
| `students_tab.dart` | 82 | `height: 36` | Filter chip bar fixed at 36px. |

---

## Category 2: Hardcoded Widths

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `schedule_section.dart` | 294 | `width: 390` | Schedule card is hardcoded to 390px wide. Will NOT overflow on 360-400px wide phones (most are ≥360dp), but will be clipped or not fill on smaller/wider screens. |
| `schedule_section.dart` | 445 | `width: 390` | Another schedule skeleton at 390px. |
| `profile_screen.dart` | 627 | `width: 360` | Profile header card hardcoded to 360px. |
| `attendance_code_screen.dart` | 478 | `width: 200` | QR code area is 200x200 fixed. |
| `attendance_code_screen.dart` | 490 | `width: 160` | Timer area fixed at 160px. |
| `attendance_code_screen.dart` | 865 | `width: 160` | Second QR area 160px. |
| `attendance_code_screen.dart` | 874 | `width: 140` | Info block 140px. |
| `attendance_code_screen.dart` | 886 | `width: 140` | Info block 140px. |
| `login_screen.dart` | 180 | `width: 240` | Logo 240px wide. |
| `unified_auth_gate.dart` | 155 | `width: 240` | Splash logo 240px. |
| `registration_screen.dart` | 98 | `width: 140` | Registration logo 140px. |
| `about_app_page.dart` | 36 | `width: 120` | About logo 120px. |
| `onboarding_tooltip.dart` | 59 | `width: 200` | Tooltip fixed at 200px. |
| `smart_board_screen.dart` | 192 | `width: 120, height: 120` | QR code 120x120. |
| `reports_controller.dart` | 877 | `width: 100` | Dialog width 100px. |

### MODERATE RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `session_control_section.dart` | 158, 290, 392, 515 | `width: 128` | Stat icons 128px wide. |
| `session_control_section.dart` | 468 | `width: 120` | Skeleton loader 120px. |
| `session_control_section.dart` | 749 | `width: 120` | Skeleton loader 120px. |

---

## Category 3: Rows Without Expanded/Flexible (overflow risk with dynamic content)

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `live_monitor_screen.dart` | 40+ | AppBar `title: Row(...)` with Column children, no Expanded | AppBar title Row contains a Column of Text widgets. If course name is long, overflow occurs. No `overflow` or `maxLines` on title Text. |
| `live_support_chat_page.dart` | 94 | `title: Row(...)` with Container + Column | AppBar title Row has icon + Column of two Text widgets. If "IntelliBot" or status text is long, no overflow protection. |
| `realtime_attendance_page.dart` | 101-115 | `Row` with two Text children: "RECENT LOGS" + "AUTO-SYNC ON" | The Row uses `mainAxisAlignment: MainAxisAlignment.spaceBetween` — if both texts are present, this is fine, but "RECENT LOGS" with `letterSpacing: 1.5` could be wide on small screens. |
| `reports_controller.dart` | 877 | `width: 100` inside a Row | Fixed-width Container in Row without Expanded wrapper. |
| `overview_tab.dart` | 77 | `Row` with "Overall Attendance" + LIVE badge | Two children in a Row — "Overall Attendance" is not wrapped in Expanded. Long text could overflow. |
| `defaulter_tab.dart` | 204 | `Row` with 3 `Expanded` action buttons | This is fine — uses Expanded correctly. |
| `live_monitor_screen.dart` | 274 | `Row` with CircleAvatar + Expanded(Column) + Icon | This Row uses Expanded correctly. |

### MODERATE RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `help_center_page.dart` | 177-189 | `Row` with Icon + Text in category grid | Text is not in Expanded, but categories are short ("Account", "Attendance"). Low risk. |
| `about_app_page.dart` | 159-184 | `Row` with Icon + Expanded(Text) + Text + Icon | Uses Expanded correctly for the title, but the `value` Text at line 173 has no overflow handling. |
| `recent_reports_list.dart` | 103-172 | `Row` with Container + Expanded(Column) + Column | Uses Expanded correctly. |
| `report_helper_widgets.dart` | 67-112 | `Row` with Column + Container | Two children: Column and Container (count badge). Column contains title and subtitle — no Expanded on Column, but both texts are short. |
| `report_kpi_card.dart` | 117-166 | `Row` with Flexible(Text) + Container | Uses Flexible correctly for the value text. |
| `sessions_tab.dart` | 78-102 | `Row` with Container + Expanded(Column) + Column | Uses Expanded correctly. |

---

## Category 4: Long Columns Without SingleChildScrollView

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `realtime_attendance_page.dart` | 93-131 | `Column` with `_buildLiveIndicator`, `_buildMainStatsCard`, `Row`, `Expanded(ListView)`, `_buildBottomControls` | The Column has an `Expanded(ListView)` which is correct for scrollable content. However, `_buildMainStatsCard` (line 176-260) is a large Column inside a Container — if the screen is very short, the non-Expanded children (LiveIndicator ~40px + MainStatsCard ~250px + Row ~20px + BottomControls ~50px = ~360px) could overflow before the Expanded ListView gets any space. |
| `reports_screen.dart` | 207 | `return SingleChildScrollView(...)` | This is fine — uses scroll. |
| `login_screen.dart` | 170-282 | `SafeArea > SingleChildScrollView` | This is fine. |
| `help_center_page.dart` | 67-99 | `Column` with search bar + `Expanded(ListView)` | Correct usage. |
| `defaulter_tab.dart` | 49-64 | `Column` with header + chips + `Expanded(ListView)` | Correct usage. |
| `eligibility_tab.dart` | 46-63 | `Column` with header + chips + `Expanded(ListView)` | Correct usage. |
| `students_tab.dart` | 58-73 | `Column` with chips + `Expanded(ListView)` | Correct usage. |

### MODERATE RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `department_performance.dart` | 56-96 | `Column` with title + dynamic department items (via `for` loop) | No scroll wrapper. If many departments, this could overflow. However, it's used inside `OverviewTab` which has a `SingleChildScrollView`, so this is fine in context. |
| `export_stats_card.dart` | 64-131 | `Column` with title + `GridView.count` | GridView uses `shrinkWrap: true` + `NeverScrollableScrollPhysics()`. Safe as long as parent scrolls. |
| `overview_tab.dart` | 127-140 | `GridView.count` with `shrinkWrap: true` | Safe — parent is `SingleChildScrollView`. |

---

## Category 5: Row With 3+ Children

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `defaulter_tab.dart` | 220-242 | `Row` with 3 `Expanded` action buttons | Uses Expanded — safe. |
| `analytics_tab.dart` | 389-399 | `Row` with 2 `Expanded` export buttons | Uses Expanded — safe. |
| `analytics_tab.dart` | 104-109 | `Row` with 2 `_buildMiniStat` widgets + `SizedBox(width: 20)` | Two stat rows in a Row. `_buildMiniStat` returns a Row itself. The parent Row has 3 children (stat, spacer, stat) — no Expanded, but stats are short. Low risk. |
| `login_devices_screen.dart` | Row with device info items | Multiple device entries use Rows with Expanded. |
| `seating_arrangement_widget.dart` | Various | Seat grid items use Rows inside cards. |

### MODERATE RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `live_monitor_screen.dart` | 650-670 | Action buttons Row | Uses Expanded — safe. |
| `manual_attendance_screen.dart` | Similar pattern | Uses Expanded for buttons. |
| `attendance_code_screen.dart` | Various | Multiple Row widgets with icons and text. |

---

## Category 6: Large SizedBox Heights (≥100px)

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `schedule_section.dart` | 279 | `height: 315` | Very large fixed height. |
| `reports_screen.dart` | 235 | `height: 320` | Shimmer loading placeholder 320px tall. |
| `reports_screen.dart` | 237 | `height: 260` | Shimmer 260px. |
| `reports_screen.dart` | 239 | `height: 200` | Shimmer 200px. |
| `profile_screen.dart` | 628 | `height: 230` | Profile header. |
| `analytics_screen.dart` | 177 | `height: 200` | Chart container. |
| `unified_auth_gate.dart` | 156 | `height: 200` | Splash logo. |
| `login_screen.dart` | 181 | `height: 200` | Login logo. |
| `attendance_code_screen.dart` | 479 | `height: 200` | QR code. |
| `attendance_history_screen.dart` | 267 | `height: 100` | Spacer. |
| `my_class_screen.dart` | 560 | `height: 100` | Spacer. |
| `dashboard_screen.dart` | 384 | `height: 100` | Spacer. |

### LOW RISK (acceptable pattern — spacer/indicator)

| File | Line | Code | Risk |
|------|------|------|------|
| `session_control_section.dart` | 159, 291, 393, 516 | `height: 128` | Icon boxes. |
| `registration_screen.dart` | 99 | `height: 120` | Logo. |
| `about_app_page.dart` | 37 | `height: 120` | Logo. |
| `fingerprint_scan_overlay.dart` | 70 | `height: 150` | Scan area. |

---

## Category 7: Text Without Overflow Handling

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `live_monitor_screen.dart` | 44 | `Text(widget.courseName, ...)` | Course name text in AppBar with no overflow/maxLines. Long course names will overflow. |
| `live_monitor_screen.dart` | 59 | `Text(widget.courseName, ...)` | Second reference to course name. |
| `live_monitor_screen.dart` | 64 | `Text("Section ${widget.section}", ...)` | Section text — low risk but no overflow. |
| `realtime_attendance_page.dart` | 59 | `Text(widget.courseName, ...)` | Course name in AppBar, no overflow. |
| `realtime_attendance_page.dart` | 64 | `Text("Section ${widget.section}", ...)` | Section text, no overflow. |
| `realtime_attendance_page.dart` | 286 | `Text(student.name, ...)` | Student name in tile, no overflow. If name is very long, could overflow Row. |
| `realtime_attendance_page.dart` | 291 | `Text("Checked in • ${_formatTime(...)}" ...)` | Status text, no overflow. |
| `live_support_chat_page.dart` | 108-110 | `Text("IntelliBot", ...)` | AppBar title text — no overflow. |
| `live_support_chat_page.dart` | 116-118 | `Text(_isTyping ? "Typing..." : "Online Assistant", ...)` | Status text — no overflow. |
| `live_support_chat_page.dart` | 172-178 | `Text(msg["text"], ...)` | Chat message bubble — no overflow/maxLines. User could type very long messages. |
| `help_center_page.dart` | 181-187 | `Text(categories[index]["name"], ...)` | Category name — short, but no overflow. |
| `help_center_page.dart` | 219-225 | `Text(answer, ...)` | FAQ answer text — no overflow. ExpansionTile children, so content is hidden by default. |
| `help_center_page.dart` | 264-269 | `Text("Our support team is available 24/7 ...")` | Description text — no overflow. |
| `about_app_page.dart` | 56-62 | `Text("IntelliAttend Faculty", ...)` | App title — no overflow. |
| `about_app_page.dart` | 66-71 | `Text("Version 2.4.0 (Build 108)", ...)` | Version text — no overflow. |
| `about_app_page.dart` | 83-88 | `Text("© 2026 IntelliAttend Technologies", ...)` | Copyright — no overflow. |
| `about_app_page.dart` | 92-96 | `Text("Made with ❤️ for Educators Worldwide", ...)` | Tagline — no overflow. |
| `about_app_page.dart` | 121-128 | `Text(content, ...)` | Mission text — no overflow. |
| `about_app_page.dart` | 173-178 | `Text(value, ...)` | Info card value text — no overflow. |
| `report_issue_page.dart` | 52-57 | `Text("Report Submitted", ...)` | Dialog title — no overflow. |
| `report_issue_page.dart` | 61-67 | `Text("Thank you for your feedback! ...")` | Dialog body — no overflow. |
| `report_issue_page.dart` | 231-237 | `Text(title, ...)` | Section title — no overflow. |
| `report_issue_page.dart` | 136-141 | `Text("By submitting, you agree ...")` | Fine print — no overflow. |
| `lock_screen.dart` | Various | Text widgets for lock screen prompts — no overflow. |
| `qr_scanner_screen.dart` | Various | Text widgets for scanner UI — no overflow. |
| `student_directory_screen.dart` | Various | Text widgets — may have long student names. |
| `course_topics_screen.dart` | Various | Text widgets for topic names. |
| `attendance_code_screen.dart` | 185 | `Text("Session Activated Successfully!")` | No overflow. |
| `attendance_code_screen.dart` | 314 | `Text("OTP expired. Tap Rotate to get a new code.")` | No overflow. |
| `attendance_code_screen.dart` | 416 | `Text("Attendance code refreshed")` | No overflow. |
| `attendance_code_screen.dart` | 907 | `Text("${_secondsLeft}s")` | Countdown — short, safe. |
| `login_devices_screen.dart` | 56-70 | Dialog texts — no overflow. |
| `settings_screen.dart` | 172, 184 | SnackBar texts — no overflow. |
| `smart_board_screen.dart` | 216 | `Text(isExpired ? "Refresh Code" : "Wait for Expiry")` | No overflow. |
| `report_helper_widgets.dart` | 28-30 | `Text("LIVE", ...)` | No overflow. |
| `report_helper_widgets.dart` | 44-46 | `Text("${(pct * 100).toStringAsFixed(1)}% Avg", ...)` | No overflow. |
| `report_helper_widgets.dart` | 101-103 | `Text("$count Students", ...)` | No overflow. |
| `report_helper_widgets.dart` | 160-166 | `Text(student['name'] ?? 'Unknown Student', ...)` | Student name — no overflow! If name is long, will overflow Row. |
| `report_helper_widgets.dart` | 173-178 | `Text("${student['attended']} / ${student['total']} Classes", ...)` | No overflow. |
| `report_helper_widgets.dart` | 188-194 | `Text("${(data['percentage'] * 100).toInt()}%", ...)` | No overflow — percentage is short. |
| `report_helper_widgets.dart` | 343 | `Text("$studentName ($studentId)", ...)` | Dialog text — no overflow. |
| `report_helper_widgets.dart` | 352-354 | `Text("No past sessions found ...")` | No overflow. |
| `report_helper_widgets.dart` | 358 | `Text("Select Session:", ...)` | No overflow. |
| `report_helper_widgets.dart` | 383 | `Text("Correction Reason:", ...)` | No overflow. |
| `report_helper_widgets.dart` | 461-463 | `Text(success ? "..." : "...")` | No overflow. |
| `report_helper_widgets.dart` | 474-475 | `msg = "Already marked present by $source"` | No overflow. |
| `recent_reports_list.dart` | 48-53 | `Text("Latest session attendance records", ...)` | No overflow. |
| `recent_reports_list.dart` | 65-66 | `Text("No reports yet", ...)` | No overflow. |
| `recent_reports_list.dart` | 130-135 | `Text("$formattedDate · $present/$total students", ...)` | No overflow. |
| `department_performance.dart` | 68-73 | `Text("Attendance rates by course/department", ...)` | No overflow. |
| `department_performance.dart` | 85-86 | `Text("No department data", ...)` | No overflow. |
| `department_performance.dart` | 143-149 | `Text("${pct.toStringAsFixed(1)}%", ...)` | No overflow — percentage is short. |
| `export_stats_card.dart` | 67-73 | `Text("Export Statistics", ...)` | No overflow. |
| `export_stats_card.dart` | 76-81 | `Text("Key metrics for the selected course", ...)` | No overflow. |
| `export_stats_card.dart` | 106-113 | `Text(stat.value, ...)` | Wrapped in FittedBox — safe! |
| `export_stats_card.dart` | 115-122 | `Text(stat.label, ...)` | Has maxLines: 1, overflow: TextOverflow.ellipsis — safe! |
| `report_distribution_chart.dart` | 34-40 | `Text("Report Distribution", ...)` | No overflow. |
| `report_distribution_chart.dart` | 43-48 | `Text("Breakdown by category", ...)` | No overflow. |
| `report_distribution_chart.dart` | 129-134 | `Text("${item['name']}", ...)` | No overflow. |
| `report_distribution_chart.dart` | 137-143 | `Text("${item['value']}", ...)` | No overflow. |
| `analytics_tab.dart` | 65 | `Text("Overall Attendance", ...)` | No overflow. |
| `analytics_tab.dart` | 83 | `Text("${avg.toStringAsFixed(1)}%", ...)` | No overflow — percentage. |
| `analytics_tab.dart` | 87 | `Text("average", ...)` | No overflow. |
| `analytics_tab.dart` | 121 | `Text(label, ...)` | No overflow. |
| `analytics_tab.dart` | 123 | `Text(value, ...)` | No overflow. |
| `analytics_tab.dart` | 167 | `Text("Student Attendance", ...)` | No overflow. |
| `analytics_tab.dart` | 172 | `Text("${displayStudents.length} students · Top performers", ...)` | No overflow. |
| `analytics_tab.dart` | 252 | `Text("Weekly Trend", ...)` | No overflow. |
| `analytics_tab.dart` | 257 | `Text("Attendance % by week", ...)` | No overflow. |
| `analytics_tab.dart` | 330 | `Text(subtitle, ...)` | No overflow. |
| `analytics_tab.dart` | 369 | `Text(value, ...)` | No overflow — numeric. |
| `analytics_tab.dart` | 370 | `Text(label, ...)` | No overflow — short. |
| `analytics_tab.dart` | 387 | `Text("Quick Actions", ...)` | No overflow. |
| `analytics_tab.dart` | 421 | `Text(label, ...)` | No overflow. |
| `actions_tab.dart` | 20 | `Text("Quick Actions", ...)` | No overflow. |
| `actions_tab.dart` | 59 | `Text(title, ...)` | No overflow. |
| `actions_tab.dart` | 61 | `Text(subtitle, ...)` | No overflow. |
| `actions_tab.dart` | 76 | `Text("No at-risk students to notify")` | No overflow. |
| `overview_tab.dart` | 29 | `Text("No data yet", ...)` | No overflow. |
| `overview_tab.dart` | 31 | `Text("Start sessions to see analytics", ...)` | No overflow. |
| `overview_tab.dart` | 79 | `Text("Overall Attendance", ...)` | No overflow. |
| `overview_tab.dart` | 87 | `Text("LIVE", ...)` | No overflow. |
| `overview_tab.dart` | 114 | `Text("${avg.toStringAsFixed(1)}%", ...)` | No overflow. |
| `overview_tab.dart` | 115 | `Text("Average", ...)` | No overflow. |
| `overview_tab.dart` | 161 | `Text(value, ...)` | No overflow. |
| `overview_tab.dart` | 162 | `Text(label, ...)` | No overflow. |
| `overview_tab.dart` | 199 | `Text(course['short_name'] ?? course['code'] ?? '', ...)` | Course name — no overflow! Could be long. |
| `overview_tab.dart` | 201 | `Text("$sessions sessions", ...)` | No overflow. |
| `overview_tab.dart` | 208 | `Text("${avg.toStringAsFixed(1)}%", ...)` | No overflow. |
| `overview_tab.dart` | 252 | `Text("Day of Week", ...)` | No overflow. |
| `sessions_tab.dart` | 28 | `Text("No sessions yet", ...)` | No overflow. |
| `sessions_tab.dart` | 30 | `Text("Sessions will appear after you conduct them", ...)` | No overflow. |
| `sessions_tab.dart` | 90 | `Text(courseCode, ...)` | Course code — no overflow. |
| `sessions_tab.dart` | 92 | `Text("$sectionId · $formattedDate", ...)` | No overflow. |
| `sessions_tab.dart` | 99 | `Text("$present / $total", ...)` | No overflow. |
| `sessions_tab.dart` | 100 | `Text("${pct.toStringAsFixed(0)}%", ...)` | No overflow. |
| `students_tab.dart` | 157 | `Text("$attended / $total classes", ...)` | No overflow. |
| `students_tab.dart` | 164 | `Text("$pctInt%", ...)` | No overflow. |
| `students_tab.dart` | 201 | `Text(message, ...)` | No overflow. |
| `defaulter_tab.dart` | 91 | `Text("DEFAULTER ALERT", ...)` | No overflow. |
| `defaulter_tab.dart` | 93 | `Text("$count students below 75% threshold", ...)` | No overflow. |
| `defaulter_tab.dart` | 95 | `Text("Avg deficit: ${avgDeficit.toStringAsFixed(1)}%", ...)` | No overflow. |
| `defaulter_tab.dart` | 193 | `Text("Need $classesNeeded more", ...)` | No overflow. |
| `defaulter_tab.dart` | 266 | `Text(label, ...)` | No overflow. |
| `defaulter_tab.dart` | 281 | `Text("No defaulters!", ...)` | No overflow. |
| `defaulter_tab.dart` | 283 | `Text("All students are above 75% attendance", ...)` | No overflow. |
| `eligibility_tab.dart` | 89 | `Text("${eligibleCount}", ...)` | No overflow — number. |
| `eligibility_tab.dart` | 98 | `Text("ELIGIBILITY CHECK", ...)` | No overflow. |
| `eligibility_tab.dart` | 100 | `Text("$eligibleCount of $total students above 75%", ...)` | No overflow. |
| `eligibility_tab.dart` | 193 | `Text("$pctInt%", ...)` | No overflow. |
| `eligibility_tab.dart` | 183 | `Text("Eligible", ...)` | No overflow. |
| `eligibility_tab.dart` | 220 | `Text("No $type found", ...)` | No overflow. |

---

## Category 8: Fixed-Width Container in Row

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `schedule_section.dart` | 294 | `Container(width: 390, ...)` in a PageView | Fixed 390px width — will not fill wider screens, will overflow on very narrow screens. |
| `schedule_section.dart` | 445 | `Container(width: 390, ...)` | Same issue. |
| `profile_screen.dart` | 627 | `Container(width: 360, ...)` | Fixed 360px — will overflow on narrower screens or not fill wider ones. |
| `attendance_code_screen.dart` | 478 | `Container(width: 200, height: 200)` | Fixed 200x200 — safe for QR code, but not responsive. |

### MODERATE RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `overview_tab.dart` | 210-211 | `Container(width: 60, ...)` | Progress bar fixed at 60px — acceptable for progress indicator. |
| `students_tab.dart` | 166-167 | `Container(width: 50, ...)` | Progress bar fixed at 50px — acceptable. |
| `eligibility_tab.dart` | 194-195 | `Container(width: 48, ...)` | Progress bar fixed at 48px — acceptable. |
| `report_kpi_card.dart` | 193-194 | `Container(width: 50, height: 24)` | Sparkline fixed at 50x24 — acceptable for decorative element. |

---

## Category 9: Unconstrained PageView

### HIGH RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `schedule_section.dart` | ~280 | `PageView` with fixed-height children (315px) | PageView children have fixed heights. If the PageView is inside a non-scrollable Column with other tall widgets, the total height may overflow. The PageView itself is unconstrained vertically. |
| `my_class_screen.dart` | ~48 | `PageController(viewportFraction: 0.35)` | Tab page controller with small viewport fraction — could cause horizontal overflow if tab items are wide. |

### MODERATE RISK

| File | Line | Code | Risk |
|------|------|------|------|
| `attendance_code_screen.dart` | ~536 | `SingleChildScrollView(scrollDirection: Axis.horizontal)` wrapping a Row | Horizontal scroll is used, which is fine. |

---

## Category 10: Missing SafeArea

### Files WITHOUT SafeArea (potential status bar / notch overlap):

| File | Line | Risk |
|------|------|------|
| `help_center_page.dart` | 48 | Scaffold body does not use SafeArea. AppBar handles top, but bottom content could overlap on devices with home indicator. |
| `live_support_chat_page.dart` | 85 | Scaffold body uses Column but no SafeArea. Bottom message input uses `MediaQuery.of(context).padding.bottom` to compensate — this is correct. |
| `about_app_page.dart` | 9 | No SafeArea — body is SingleChildScrollView inside AppBar. Bottom could overlap on notch devices. |
| `report_issue_page.dart` | 85 | No SafeArea — body is SingleChildScrollView. |
| `department_performance.dart` | 42 | Component-level widget, used inside scrollable parent. Safe. |
| `recent_reports_list.dart` | 15 | Component-level widget, used inside scrollable parent. Safe. |
| `export_stats_card.dart` | 50 | Component-level widget. Safe. |
| `attendance_chart.dart` | 28 | Component-level widget. Safe. |
| `report_distribution_chart.dart` | 17 | Component-level widget. Safe. |
| `report_kpi_card.dart` | 69 | Component-level widget. Safe. |
| `sessions_tab.dart` | 36 | ListView — safe. |
| `students_tab.dart` | 62 | Expanded ListView — safe. |
| `defaulter_tab.dart` | 56 | Expanded ListView — safe. |
| `eligibility_tab.dart` | 53 | Expanded ListView — safe. |

### Files WITH SafeArea (correct):

| File | Line |
|------|------|
| `login_screen.dart` | 170 |
| `dashboard_screen.dart` | 356 |
| `attendance_history_screen.dart` | 248 |
| `send_message_screen.dart` | 301, 398, 534 |
| `student_profile_screen.dart` | 449 |
| `realtime_attendance_page.dart` | 82 |
| `course_topics_screen.dart` | 118 |
| `live_monitor_screen.dart` | 40 |
| `smart_board_screen.dart` | 40 |
| `manual_attendance_screen.dart` | 33 |
| `attendance_code_screen.dart` | 499 |
| `qr_scanner_screen.dart` | 109, 158 |

---

## Summary: Top 20 Highest-Risk Locations

1. **`schedule_section.dart:279`** — `height: 315` fixed Container in PageView
2. **`schedule_section.dart:294, 445`** — `width: 390` hardcoded width
3. **`profile_screen.dart:627-628`** — `width: 360, height: 230` fixed dimensions
4. **`reports_screen.dart:235`** — `height: 320` shimmer placeholder
5. **`attendance_code_screen.dart:478-491`** — `width: 200, height: 200` and `width: 160, height: 160`
6. **`attendance_code_screen.dart:865-887`** — Multiple fixed `width: 140-160, height: 140-160`
7. **`live_monitor_screen.dart:44, 59`** — `Text(widget.courseName)` no overflow
8. **`realtime_attendance_page.dart:59, 286, 291`** — `Text(widget.courseName)` / `Text(student.name)` no overflow
9. **`live_support_chat_page.dart:172-178`** — Chat message `Text(msg["text"])` no overflow/maxLines
10. **`live_support_chat_page.dart:108-118`** — AppBar title texts no overflow
11. **`analytics_screen.dart:177`** — `height: 200` chart container
12. **`login_screen.dart:180-181`** — `width: 240, height: 200` logo
13. **`unified_auth_gate.dart:155-156`** — `width: 240, height: 200` splash logo
14. **`overview_tab.dart:199`** — `Text(course['short_name'] ?? ...)` no overflow
15. **`report_helper_widgets.dart:160-166`** — `Text(student['name'])` no overflow in Row
16. **`about_app_page.dart:173-178`** — `Text(value)` in Row no overflow
17. **`session_control_section.dart:158-159, 290-291, 392-393, 515-516`** — `width: 128, height: 128` ×4
18. **`realtime_attendance_page.dart:93-131`** — Column with non-Expanded children totaling ~360px before Expanded ListView
19. **`report_issue_page.dart:61-67`** — Dialog body text no overflow
20. **`help_center_page.dart:264-269`** — Long description text no overflow

---

## Patterns That Are SAFE (well-handled)

These locations correctly use overflow protection:

- `attendance_history_screen.dart` — Extensive use of `maxLines` + `overflow: TextOverflow.ellipsis` throughout
- `my_class_screen.dart` — Uses `maxLines` + `overflow: TextOverflow.ellipsis` on most Text widgets
- `resources_screen.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis` on file names
- `courses_screen.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `dashboard_header.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `faculty_timetable_screen.dart` — Uses `maxLines: 1-2, overflow: TextOverflow.ellipsis`
- `export_attendance_screen.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `send_message_screen.dart` — Uses `maxLines: 2, overflow: TextOverflow.ellipsis`
- `send_notice_screen.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `present_students_screen.dart`, `absent_students_screen.dart`, `late_students_screen.dart`, `leave_students_screen.dart` — All use `maxLines: 1, overflow: TextOverflow.ellipsis`
- `login_devices_screen.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `defaulter_tab.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `eligibility_tab.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `students_tab.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `report_kpi_card.dart` — Uses `FittedBox` + `maxLines: 1, overflow: TextOverflow.ellipsis`
- `export_stats_card.dart` — Uses `FittedBox` + `maxLines: 1, overflow: TextOverflow.ellipsis`
- `recent_reports_list.dart` — Uses `maxLines: 1, overflow: TextOverflow.ellipsis`
- `attendance_chart.dart` — Uses `overflow: TextOverflow.ellipsis` + `FittedBox`
- `seating_arrangement_widget.dart` — Uses `maxLines: 2`
- `realtime_attendance_page.dart:146-171` — Uses `FittedBox(fit: BoxFit.scaleDown)` on live indicator Row
- `overview_tab.dart:210` — Progress bar uses fixed width (acceptable for visual element)
