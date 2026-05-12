import 'package:flutter/material.dart';

import '../app/ledger_state.dart';
import '../services/local_ledger_repository.dart';
import 'edit_entry_sheet.dart';
import 'pages/calendar_page.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/summary_page.dart';
import 'scope.dart';
import 'theme.dart';

class LedgerShell extends StatefulWidget {
  const LedgerShell({super.key, required this.repository});
  final LocalLedgerRepository? repository;

  @override
  State<LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<LedgerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = LedgerScope.of(context);
    final pages = [
      HomePage(state: state, openCalendar: () => setState(() => _index = 1), openSummary: () => setState(() => _index = 3)),
      CalendarPage(state: state),
      SummaryPage(state: state, repository: widget.repository),
      SettingsPage(state: state, repository: widget.repository),
    ];
    final pageIndex = _index > 1 ? _index - 1 : _index;
    return Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: pages[pageIndex]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: SizedBox(
          height: 86,
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: LedgerColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: LedgerColors.hairline),
            boxShadow: const [BoxShadow(color: Color(0x1A5D3E1E), blurRadius: 24, offset: Offset(0, 12))],
          ),
          child: Row(
            children: [
              _NavButton(label: '首页', icon: Icons.home_outlined, selected: _index == 0, onTap: () => setState(() => _index = 0)),
              _NavButton(label: '日历', icon: Icons.calendar_month_outlined, selected: _index == 1, onTap: () => setState(() => _index = 1)),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: '新增工时记录',
                    child: InkWell(
                      onTap: () => showEditWorkEntrySheet(context, state),
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(color: LedgerColors.charcoal, shape: BoxShape.circle),
                        child: const Center(child: Text('＋', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                ),
              ),
              _NavButton(label: '汇总', icon: Icons.query_stats_outlined, selected: _index == 3, onTap: () => setState(() => _index = 3)),
              _NavButton(label: '设置', icon: Icons.tune_outlined, selected: _index == 4, onTap: () => setState(() => _index = 4)),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.icon, required this.selected, required this.onTap});
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: selected ? LedgerColors.warningCopper : LedgerColors.muted, size: 22),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: selected ? LedgerColors.ink : LedgerColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
