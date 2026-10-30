import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/qloo_session.dart';
import '../core/session_controller.dart';

class QlooHome extends StatefulWidget {
  const QlooHome({
    super.key,
    required this.session,
    this.embedded = false,
    this.initialMinutes = 40,
    this.initialPattern = 'vegetarian',
    this.blockedReason,
    this.contextRevision = '',
    this.onConsentChanged,
    this.onTastesSaved,
  });
  final bool embedded;
  final int initialMinutes;
  final String initialPattern;
  final String? blockedReason;
  final String contextRevision;
  final Future<void> Function()? onConsentChanged;
  final Future<void> Function()? onTastesSaved;
  final QlooSession session;
  @override
  State<QlooHome> createState() => _QlooHomeState();
}

class _QlooHomeState extends State<QlooHome> {
  final _query = TextEditingController();
  final _refine = TextEditingController();
  bool _busy = true, _mild = true, _soft = false;
  int _minutes = 40, _budget = 300;
  String _kind = 'cuisine', _pattern = 'vegetarian';
  String? _error, _notice;
  List<Map<String, dynamic>> _selected = [], _choices = [];
  Map<String, dynamic>? _result;
  int _epoch = 0, _revision = 0;
  QlooSession get api => widget.session;
  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes.clamp(10, 120);
    _pattern =
        ['vegan', 'vegetarian', 'omnivore'].contains(widget.initialPattern)
        ? widget.initialPattern
        : 'vegetarian';
    _initialize();
  }

  Future<void> _initialize() => _run(() async {
    await api.initialize();
    if (api.signedIn) {
      final data = await api.request('GET', '/v1/qloo/tastes');
      _selected = (data['selections'] as List).cast<Map<String, dynamic>>();
    }
  });
  Future<void> _run(Future<void> Function() action) async {
    if (!mounted) return;
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted && epoch == _epoch)
        _error = e is QlooApiException
            ? e.toString()
            : 'Connection failed. Please retry.';
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  Future<void> _search() => _run(() async {
    _choices = [];
    final data = await api.request('POST', '/v1/qloo/search', {
      'query': _query.text.trim(),
      'kind': _kind,
    });
    if (!mounted) return;
    _choices = (data['choices'] as List).cast<Map<String, dynamic>>();
    if (_choices.isEmpty)
      _notice =
          'No Qloo matches. Try another public cuisine, restaurant or cultural interest.';
  });
  Map<String, dynamic> get _constraints => {
    'eatingPattern': _pattern,
    'budgetInr': _budget,
    'minutes': _minutes,
    'mild': _mild,
    'soft': _soft,
  };
  Future<void> _recommend({bool refine = false}) => _run(() async {
    final revision = _revision;
    _result = null;
    final data = await api.request('POST', '/v1/qloo/recommend', {
      'selections': _selected,
      'constraints': _constraints,
      'refinement': refine ? _refine.text.trim() : '',
    });
    if (!mounted || revision != _revision || widget.blockedReason != null)
      return;
    _result = data;
    final c = data['constraints'] as Map<String, dynamic>;
    _minutes = c['minutes'] as int;
    _mild = c['mild'] as bool;
    _soft = c['soft'] as bool;
  });
  Future<void> _save() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remember these tastes?'),
        content: const Text(
          'Save these public tastes for Discover and your meal agent. This refreshes meal personalization; preparation controls still apply only to this search.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save tastes'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final epoch = _epoch;
    await _run(() async {
      await api.request('PUT', '/v1/qloo/tastes', {'selections': _selected});
      if (!mounted || epoch != _epoch || !api.signedIn) return;
      await widget.onTastesSaved?.call();
      if (!mounted || epoch != _epoch) return;
      _notice = 'Your selected tastes are saved.';
    });
  }

  void _invalidate() {
    _revision++;
    _result = null;
  }

  @override
  void didUpdateWidget(covariant QlooHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.blockedReason != widget.blockedReason ||
        oldWidget.initialMinutes != widget.initialMinutes ||
        oldWidget.initialPattern != widget.initialPattern) {
      _invalidate();
      _minutes = widget.initialMinutes.clamp(10, 120);
      _pattern =
          ['vegan', 'vegetarian', 'omnivore'].contains(widget.initialPattern)
          ? widget.initialPattern
          : 'vegetarian';
    }
  }

  @override
  void dispose() {
    _epoch++;
    _query.dispose();
    _refine.dispose();
    if (!widget.embedded) api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(
            backgroundColor: const Color(0xfff7f6f0),
            title: const Text(
              'valora / Qloo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (api.signedIn)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          try {
                            await api.logout();
                          } finally {
                            _selected = [];
                            _choices = [];
                            _result = null;
                            _query.clear();
                            _refine.clear();
                          }
                        }),
                  child: const Text('Sign out'),
                ),
              const SizedBox(width: 20),
            ],
          ),
    body: SelectionArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MUMBAI · MEALS & DINING',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff245a43),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Food you know.\nSomething new to love.',
                    style: TextStyle(
                      fontSize: 42,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Discover food through your public tastes. Saved tastes also personalize your meal plan and chat.',
                  ),
                  const SizedBox(height: 24),
                  if (widget.blockedReason != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(widget.blockedReason!),
                    ),
                  if (_busy)
                    Semantics(
                      label: 'Loading, please wait',
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xff9c211b)),
                        ),
                      ),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(liveRegion: true, child: Text(_notice!)),
                    ),
                  if (!api.signedIn) ...[
                    _panel('Your tastes, your choices', [
                      const Text(
                        'Sign in with Google to keep your taste selections private to your account. We use public taste signals for Qloo discovery; medical details are not needed.',
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _run(api.start),
                          icon: const Icon(Icons.login),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Live Qloo access is required. No sample restaurants are shown as real recommendations.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ]),
                  ] else ...[
                    _panel('1. Start with what you enjoy', [
                      const Text(
                        'Search public cuisines or restaurants you love. Music and films are optional. Select the correct Qloo match before continuing.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _kind,
                        decoration: const InputDecoration(
                          labelText: 'Taste category',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cuisine',
                            child: Text('Cuisine'),
                          ),
                          DropdownMenuItem(
                            value: 'restaurant',
                            child: Text('Restaurant'),
                          ),
                          DropdownMenuItem(
                            value: 'artist',
                            child: Text('Music artist (optional)'),
                          ),
                          DropdownMenuItem(
                            value: 'movie',
                            child: Text('Film (optional)'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _kind = v!;
                                _choices = [];
                              }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _query,
                        enabled: !_busy,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Public taste to look up',
                          hintText: 'For example, Indian or Italian',
                        ),
                        onSubmitted: (_) {
                          if (!_busy && _query.text.trim().length >= 2)
                            _search();
                        },
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _search,
                        icon: const Icon(Icons.search),
                        label: const Text('Find Qloo matches'),
                      ),
                      if (_choices.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Which match did you mean?'),
                        for (final s in _choices)
                          ListTile(
                            title: Text(s['label'] as String),
                            subtitle: Text(
                              s['kind'] == 'tag'
                                  ? 'Cuisine tag'
                                  : 'Public entity',
                            ),
                            trailing: IconButton(
                              tooltip: 'Select ${s['label']}',
                              onPressed: _busy || _selected.length >= 10
                                  ? null
                                  : () => setState(() {
                                      if (!_selected.any(
                                        (v) => v['id'] == s['id'],
                                      ))
                                        _selected.add(s);
                                      _choices = [];
                                      _invalidate();
                                    }),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in _selected)
                            InputChip(
                              label: Text(s['label'] as String),
                              onDeleted: _busy
                                  ? null
                                  : () => setState(() {
                                      _selected.remove(s);
                                      _invalidate();
                                    }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.bookmark_outline),
                        label: const Text('Review & save tastes'),
                      ),
                    ]),
                    _panel('2. Make it practical', [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _pattern,
                        decoration: const InputDecoration(
                          labelText: 'Eating pattern',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'vegetarian',
                            child: Text('Vegetarian'),
                          ),
                          DropdownMenuItem(
                            value: 'vegan',
                            child: Text('Vegan'),
                          ),
                          DropdownMenuItem(
                            value: 'omnivore',
                            child: Text('Omnivore'),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _pattern = v!;
                                _invalidate();
                              }),
                      ),
                      const SizedBox(height: 16),
                      Text('Cooking time: up to $_minutes minutes'),
                      Slider(
                        value: _minutes.toDouble(),
                        min: 10,
                        max: 120,
                        divisions: 22,
                        label: '$_minutes minutes',
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _minutes = v.round();
                                _invalidate();
                              }),
                      ),
                      Text('Budget target: ₹$_budget per meal'),
                      Slider(
                        value: _budget.toDouble(),
                        min: 0,
                        max: 2000,
                        divisions: 40,
                        label: '₹$_budget',
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _budget = v.round();
                                _invalidate();
                              }),
                      ),
                      const Text(
                        'Prices are unverified. We cannot promise that a result fits this budget.',
                        style: TextStyle(fontSize: 16),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prefer mild food'),
                        value: _mild,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _mild = v;
                                _invalidate();
                              }),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Prefer soft preparations'),
                        subtitle: const Text(
                          'A preparation preference, not a swallowing assessment.',
                        ),
                        value: _soft,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() {
                                _soft = v;
                                _invalidate();
                              }),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _busy ||
                                widget.blockedReason != null ||
                                _selected.isEmpty
                            ? null
                            : () => _recommend(),
                        icon: const Icon(Icons.restaurant_menu),
                        label: const Text('Discover meals & dining'),
                      ),
                    ]),
                    _panel('3. Refine this search', [
                      const Text(
                        'Refinement requires your existing Nebius cloud AI consent. Your refinement text goes to NVIDIA Nemotron via Nebius. Do not include health or medication details. Qloo receives selected public tastes and the search region.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _refine,
                        enabled: !_busy,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'What would you change?',
                          hintText: 'Milder and quicker',
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed:
                            _busy ||
                                widget.blockedReason != null ||
                                _selected.isEmpty
                            ? null
                            : () => _recommend(refine: true),
                        child: const Text('Refine my options'),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Refinement narrows preparation preferences for this search. It does not save lasting changes.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ]),
                    if (_result != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Your shortlist',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Text(
                        'Source: live Qloo · ${_result!['toolCalls']} discovery / AI calls',
                      ),
                      Text(
                        'Returned Qloo affinities: ' +
                            ((_result!['affinityTags'] as List? ?? [])
                                .map((t) => t['label'])
                                .join(', ')),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns = [
                            _results(
                              'Dining in Mumbai',
                              (_result!['dining'] as List)
                                  .cast<Map<String, dynamic>>(),
                              false,
                            ),
                            _results(
                              'Prepare at home',
                              (_result!['meals'] as List)
                                  .cast<Map<String, dynamic>>(),
                              true,
                            ),
                          ];
                          return c.maxWidth > 800
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: columns[0]),
                                    const SizedBox(width: 20),
                                    Expanded(child: columns[1]),
                                  ],
                                )
                              : Column(children: columns);
                        },
                      ),
                      _panel('What still needs checking', [
                        for (final message
                            in _result!['unmetConstraints'] as List)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('• $message'),
                          ),
                      ]),
                    ],
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const Text(
                    'Qloo provides cultural taste affinities. Valora maps cuisine affinities to its original recipe catalog. This experience does not provide medication checks, clinical diets, verified allergen safety or ordering.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _panel(String title, List<Widget> children) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffd9dfd5)),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
  Widget _results(
    String title,
    List<Map<String, dynamic>> cards,
    bool recipe,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      if (cards.isEmpty)
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'No verified catalog matches for these tastes and preferences. Try adjusting your search.',
          ),
        ),
      for (final c in cards)
        _panel(c['name'] as String, [
          if (recipe)
            Text(
              '${c['minutes']} minutes · ${c['servings']} serving · ${c['cuisine']}',
            ),
          if (!recipe && c['address'] != null) Text(c['address'] as String),
          if (!recipe)
            Text(
              c['priceCategory'] == null
                  ? 'Qloo price category: unknown'
                  : 'Qloo price category: ${c['priceCategory']} (not an INR price)',
            ),
          Text(c['explanation'] as String),
          if (recipe) ...[
            const SizedBox(height: 12),
            Text('Preparation: ${c['texture']}'),
            Text(c['spiceAdjustment'] as String),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ingredients & steps'),
              children: [
                for (final i in c['ingredients'] as List)
                  Align(alignment: Alignment.centerLeft, child: Text('• $i')),
                const SizedBox(height: 12),
                for (final step in (c['steps'] as List).indexed)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${step.$1 + 1}. ${step.$2}'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text('Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final e in c['evidence'] as List)
            Text(
              '${e['source']} · ${e['id']}',
              style: const TextStyle(fontSize: 14),
            ),
          if (recipe)
            Text(
              'License: ${c['license']} · ${c['reviewStatus']}',
              style: const TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 12),
          for (final u in c['unknowns'] as List)
            Text('• $u', style: const TextStyle(fontSize: 16)),
        ]),
    ],
  );
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.session});
  final SessionController session;
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late final api = QlooSession(
    api: widget.session.backendApi!,
    isSignedIn: () => widget.session.signedIn,
    generation: () => widget.session.accountGeneration,
  );
  @override
  Widget build(BuildContext context) => QlooHome(
    session: api,
    embedded: true,
    contextRevision: jsonEncode(widget.session.profile.toJson()),
    initialMinutes: widget.session.profile.cookingMinutes,
    initialPattern: widget.session.profile.pattern.toLowerCase(),
    onTastesSaved: () async {
      final s = widget.session;
      final epoch = s.accountGeneration;
      if (!s.signedIn || !mounted) return;
      s.firstDayPlanner?.preferencesChanged();
      if (epoch == s.accountGeneration && s.signedIn && mounted)
        s.firstDayPlanner?.preferencesSaved();
    },
  );
}
