import 'package:flutter/material.dart';
import 'package:programming_engine/programming_engine.dart';

import 'models/journey_simulator.dart';
import 'models/notes_store.dart';
import 'models/review_form_state.dart';
import 'models/review_notes.dart';
import 'models/url_state_codec.dart';
import 'platform/browser_bridge.dart';
import 'theme/app_colors.dart';
import 'theme/review_theme.dart';
import 'widgets/feedback_tab.dart';
import 'widgets/journey_tab.dart';
import 'widgets/plan_tab.dart';
import 'widgets/profile_form.dart';
import 'widgets/stamp_footer.dart';

final class ReviewApp extends StatelessWidget {
  const ReviewApp({this.browserBridge, super.key});

  final BrowserBridge? browserBridge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women’s Gym · Generator Review',
      debugShowCheckedModeBanner: false,
      theme: buildReviewTheme(),
      home: ReviewHome(browserBridge: browserBridge ?? createBrowserBridge()),
    );
  }
}

final class ReviewHome extends StatefulWidget {
  const ReviewHome({required this.browserBridge, super.key});

  final BrowserBridge browserBridge;

  @override
  State<ReviewHome> createState() => _ReviewHomeState();
}

final class _ReviewHomeState extends State<ReviewHome> {
  static const _config = ProgrammingConfig();

  late final NotesStore _notesStore;
  late ReviewFormState _form;
  late Result<Plan> _planResult;
  late ReviewNotes _notes;
  JourneyResult? _journey;
  int _journeyWeeks = 6;
  JourneyPattern _journeyPattern = JourneyPattern.honestNovice;

  Plan? get _plan => _planResult.valueOrNull;

  @override
  void initState() {
    super.initState();
    _notesStore = LocalStorageNotesStore(widget.browserBridge);
    _form =
        UrlStateCodec.decode(widget.browserBridge.fragment) ??
        ReviewFormState.defaults;
    _planResult = assemblePlan(_form.toProfile(), _config, catalogV1);
    _notes = _plan == null
        ? ReviewNotes()
        : _notesStore.load(_notesStorageKey(_plan!, _form));
    _journey = _plan == null
        ? null
        : simulateJourney(
            plan: _plan!,
            form: _form,
            weeks: _journeyWeeks,
            pattern: _journeyPattern,
          );
    widget.browserBridge.replaceFragment(UrlStateCodec.encode(_form));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 980;
    final profile = ProfileForm(state: _form, onChanged: _updateForm);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          backgroundColor: AppColors.paper,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: compact ? 0 : 24,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Women’s Gym',
                style: TextStyle(
                  fontFamily: 'YoungSerif',
                  color: AppColors.roseDeep,
                  fontSize: 23,
                ),
              ),
              Text(
                'GENERATOR REVIEW · REAL ENGINE OUTPUT',
                style: TextStyle(
                  color: AppColors.inkFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Tooltip(
                  message: 'Profile state is encoded in this URL',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.sageSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.link_rounded,
                            size: 16,
                            color: AppColors.sage,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Shareable',
                            style: TextStyle(
                              color: AppColors.sage,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        drawer: compact
            ? Drawer(
                width: 370,
                backgroundColor: AppColors.cream,
                child: SafeArea(child: profile),
              )
            : null,
        body: compact
            ? _results()
            : Row(
                children: <Widget>[
                  SizedBox(width: 370, child: profile),
                  const VerticalDivider(width: 1),
                  Expanded(child: _results()),
                ],
              ),
      ),
    );
  }

  Widget _results() {
    final plan = _plan;
    return Column(
      children: <Widget>[
        const TabBar(
          tabs: <Tab>[
            Tab(icon: Icon(Icons.view_week_outlined), text: 'Plan'),
            Tab(icon: Icon(Icons.show_chart_rounded), text: 'Journey'),
            Tab(icon: Icon(Icons.rate_review_outlined), text: 'Feedback'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: <Widget>[
              PlanTab(result: _planResult),
              plan == null || _journey == null
                  ? const _UnavailableTab(
                      message:
                          'Journey simulation is unavailable until the plan assembles.',
                    )
                  : JourneyTab(
                      form: _form,
                      weeks: _journeyWeeks,
                      pattern: _journeyPattern,
                      result: _journey!,
                      onWeeksChanged: _setJourneyWeeks,
                      onPatternChanged: _setJourneyPattern,
                    ),
              plan == null
                  ? const _UnavailableTab(
                      message:
                          'Feedback is unavailable until the plan assembles.',
                    )
                  : FeedbackTab(
                      plan: plan,
                      notes: _notes,
                      onChanged: _saveNotes,
                      onExport: _exportNotes,
                      onCopy: _copyNotes,
                    ),
            ],
          ),
        ),
        StampFooter(plan: plan),
      ],
    );
  }

  void _updateForm(ReviewFormState form) {
    final result = assemblePlan(form.toProfile(), _config, catalogV1);
    final plan = result.valueOrNull;
    final notes = plan == null
        ? ReviewNotes()
        : _notesStore.load(_notesStorageKey(plan, form));
    final journey = plan == null
        ? null
        : simulateJourney(
            plan: plan,
            form: form,
            weeks: _journeyWeeks,
            pattern: _journeyPattern,
          );
    widget.browserBridge.replaceFragment(UrlStateCodec.encode(form));
    setState(() {
      _form = form;
      _planResult = result;
      _notes = notes;
      _journey = journey;
    });
  }

  void _setJourneyWeeks(int weeks) {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _journeyWeeks = weeks;
      _journey = simulateJourney(
        plan: plan,
        form: _form,
        weeks: weeks,
        pattern: _journeyPattern,
      );
    });
  }

  void _setJourneyPattern(JourneyPattern pattern) {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _journeyPattern = pattern;
      _journey = simulateJourney(
        plan: plan,
        form: _form,
        weeks: _journeyWeeks,
        pattern: pattern,
      );
    });
  }

  void _saveNotes(ReviewNotes notes) {
    final plan = _plan;
    if (plan == null) return;
    _notesStore.save(_notesStorageKey(plan, _form), notes);
    setState(() => _notes = notes);
  }

  String? _exportPayload() {
    final plan = _plan;
    if (plan == null) return null;
    return createNotesExportJson(
      form: _form,
      plan: plan,
      notes: _notes,
      journeyWeeks: _journeyWeeks,
      journeyPattern: _journeyPattern.name,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  void _exportNotes() {
    final plan = _plan;
    final payload = _exportPayload();
    if (plan == null || payload == null) return;
    widget.browserBridge.downloadTextFile(
      fileName: 'generator-review-${plan.stamps.profileHash}.json',
      content: payload,
      mimeType: 'application/json',
    );
    _showMessage('Notes JSON downloaded');
  }

  Future<void> _copyNotes() async {
    final payload = _exportPayload();
    if (payload == null) return;
    await widget.browserBridge.copyText(payload);
    if (mounted) _showMessage('Notes JSON copied to clipboard');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _notesStorageKey(Plan plan, ReviewFormState form) =>
      '${plan.reference}|unit=${form.unitSystem.name}|'
      'bodyMassKg=${form.bodyMassKg}';
}

final class _UnavailableTab extends StatelessWidget {
  const _UnavailableTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
