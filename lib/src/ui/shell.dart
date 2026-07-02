import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../services/local_ledger_repository.dart';
import 'edit_entry_sheet.dart';
import 'pages/calendar_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/summary_page.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

class LedgerShell extends StatefulWidget {
  const LedgerShell({super.key, required this.repository});
  final LocalLedgerRepository? repository;

  @override
  State<LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<LedgerShell> {
  int _index = 0;
  DateTime? _calendarSelectedDay;

  @override
  Widget build(BuildContext context) {
    final state = LedgerScope.of(context);
    _calendarSelectedDay ??= state.now;
    final pages = [
      HomePage(
        state: state,
        openCalendar: () => setState(() => _index = 1),
        openSummary: () => setState(() => _index = 3),
        openSettings: () => setState(() => _index = 4),
      ),
      CalendarPage(
        state: state,
        initialSelectedDay: _calendarSelectedDay,
        onSelectedDayChanged: (day) =>
            setState(() => _calendarSelectedDay = dateOnly(day)),
      ),
      SummaryPage(state: state, repository: widget.repository),
      SettingsPage(state: state, repository: widget.repository),
    ];
    final pageIndex = _index > 1 ? _index - 1 : _index;
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: pages[pageIndex],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: SizedBox(
          height: 56,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ledgerContentMaxWidth,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: LedgerColors.surfaceRaised.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: LedgerColors.hairline),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavButton(
                      label: '首页',
                      icon: Icons.home_outlined,
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                    ),
                    _NavButton(
                      label: '日历',
                      icon: Icons.calendar_month_outlined,
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                    ),
                    Expanded(
                      child: Center(
                        child: Semantics(
                          button: true,
                          label: '新增工时记录',
                          child: InkWell(
                            onTap: () => showEditWorkEntrySheet(
                              context,
                              state,
                              day: _index == 1
                                  ? _calendarSelectedDay ?? state.now
                                  : state.now,
                            ),
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: LedgerColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  '＋',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _NavButton(
                      label: '汇总',
                      icon: Icons.query_stats_outlined,
                      selected: _index == 3,
                      onTap: () => setState(() => _index = 3),
                    ),
                    _NavButton(
                      label: '设置',
                      icon: Icons.tune_outlined,
                      selected: _index == 4,
                      onTap: () => setState(() => _index = 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(
            color: selected ? LedgerColors.primaryBlueSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? LedgerColors.primaryBlue : LedgerColors.muted,
                size: 16,
              ),
              const SizedBox(height: 1),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: cappedTextScaler(context, maxScale: 1.2),
                  style: TextStyle(
                    color: selected
                        ? LedgerColors.primaryBlue
                        : LedgerColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
