import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'food_records.dart';
import 'chat_router.dart';
import 'chat_action.dart';
import 'models.dart';
import 'ai_service.dart' show AiComplexity, AiTask, ValoraAiService;
import 'backend_api.dart';
import 'google_sign_in.dart';

/// In-memory product state plus explicitly connected API and AI services.
class SessionController extends ChangeNotifier {
  ChatAction? pendingChatAction;
  String _actionSnapshot = '';
  bool chatActionApplied = false, chatActionBusy = false;
  String chatActionMessage = '';

  void cancelChatAction() {
    if (chatActionBusy || chatActionApplied) return;
    pendingChatAction = null;
    chatActionMessage = 'Change cancelled.';
    notifyListeners();
  }

  Future<void> confirmChatAction() async {
    final action = pendingChatAction;
    if (action == null || chatActionBusy) return;
    if (!chatActionApplied && jsonEncode(profile.toJson()) != _actionSnapshot) {
      pendingChatAction = null;
      chatActionMessage =
          'Your preferences changed. Send the request again to review the latest values.';
      notifyListeners();
      return;
    }
    if (backendApi != null && (!signedIn || !accountLoaded || !onboarded)) {
      chatActionMessage = 'Load your account before confirming this change.';
      notifyListeners();
      return;
    }
    final epoch = _accountEpoch;
    chatActionBusy = true;
    if (!chatActionApplied) {
      chatActionApplied = true;
      updateProfile(() => action.apply(profile));
    }
    notifyListeners();
    await saveAccountData();
    if (_disposed || epoch != _accountEpoch) return;
    chatActionBusy = false;
    if (saveError.isNotEmpty || hasUnsavedChanges) {
      chatActionMessage = 'Change applied here but not saved. Retry saving.';
    } else {
      chatActionMessage = backendApi == null
          ? 'Changed for this preview session.'
          : 'Preferences saved.';
      chat.add(
        ChatEntry(
          '${action.label}: ${action.current(profile)}. $chatActionMessage',
          false,
        ),
      );
      pendingChatAction = null;
      chatActionApplied = false;
    }
    notifyListeners();
  }

  Profile profile = Profile();
  final pantry = <PantryItem>[
    const PantryItem(id: 1, name: 'Rice', amount: '~1 kg'),
    const PantryItem(id: 2, name: 'Chickpeas', amount: '1 can'),
    const PantryItem(id: 3, name: 'Onion', amount: '2 left'),
  ];
  final intake = <Intake>[];
  final days = List.generate(5, (_) => DayDraft());
  final chat = <ChatEntry>[];
  final pausedFacts = <String>{};
  final factSources = <String, String>{};
  int _nextItem = 4;
  int day = 0, selectedGrocer = 0, selectedPrepared = 0;
  bool onboarded = false, quoteStale = false, planReviewed = false;
  bool conversation = false, notificationsEnabled = true;
  ChatFocus focus = ChatFocus.plan;
  String request = '',
      aiReply = '',
      aiError = '',
      frequency = 'Daily',
      quietStart = '22:00',
      quietEnd = '07:00';
  final notificationCategories = <String>{
    'Plan ready',
    'Pantry check',
    'Meal check-in',
  };
  DateTime _firstDate = DateUtilsLocal.tomorrow();
  DateTime get firstDate => _firstDate;
  ValoraAiService? aiService;
  BackendApi? backendApi;
  GoogleSignInService? googleSignIn;
  bool signedIn = false;
  bool authResolved = false;
  bool signingIn = false;
  bool aiBusy = false;
  bool? cloudAiConsent;
  bool aiSettingsBusy = false;
  int modelDownloadProgress = -1;
  bool modelInstalled = false;
  String aiSettingsMessage = '';
  bool shareFoodContext = false;
  final _aiHistory = <ChatEntry>[];
  String? _failedPrompt;
  bool get canRetryChat => _failedPrompt != null && !aiBusy;

  void setShareFoodContext(bool value) {
    if (aiBusy) return;
    shareFoodContext = value;
    notifyListeners();
  }

  void clearChat() {
    if (aiBusy || chatActionBusy) return;
    pendingChatAction = null;
    chatActionApplied = false;
    chatActionMessage = '';
    chat.clear();
    _aiHistory.clear();
    _failedPrompt = null;
    aiError = aiReply = request = '';
    conversation = false;
    notifyListeners();
  }

  Future<void> retryChat() async {
    final prompt = _failedPrompt;
    if (prompt == null || aiBusy) return;
    if (chat.isNotEmpty && chat.last.isError) chat.removeLast();
    await _submitAiConversation(prompt, retry: true);
  }

  String _conversationContext() {
    String clip(String value, int max) =>
        value.length <= max ? value : value.substring(0, max);
    List<String> selected(Set<String> values) =>
        values.take(10).map((s) => clip(s, 80)).toList();
    final history = _aiHistory
        .map(
          (entry) => {
            'role': entry.isUser ? 'user' : 'assistant',
            'text': clip(entry.text, 1000),
            'truncated': entry.text.length > 1000,
          },
        )
        .toList();
    final context = <String, dynamic>{
      'history': history,
      'historyMayBePartial': true,
      'foodContextIncluded': shareFoodContext,
      'foodContextIsUnsaved': shareFoodContext && hasUnsavedChanges,
      if (shareFoodContext)
        'foodPreferences': {
          if (!pausedFacts.contains('pattern'))
            'eatingPattern': clip(profile.pattern, 80),
          if (!pausedFacts.contains('cuisines')) ...{
            'cuisines': selected(profile.cuisines),
            'otherCuisine': clip(profile.otherCuisine, 160),
          },
          if (!pausedFacts.contains('exclusions'))
            'foodsToAvoid': clip(profile.exclusions, 400),
          'reportedAllergies': selected(
            profile.allergies
                .where((a) => !pausedFacts.contains('allergy:$a'))
                .toSet(),
          ),
          if (!pausedFacts.contains('allergy:Other') &&
              profile.allergies.contains('Other'))
            'otherReportedAllergy': clip(profile.otherAllergy, 160),
          'coverage': clip(profile.coverage, 80),
          'weeklyBudgetInr': profile.budget,
          'cookingMinutes': profile.cookingMinutes,
          'safetyFactsPaused': safetyPaused,
        },
    };
    while (jsonEncode(context).length > 18000 && history.isNotEmpty) {
      history.removeRange(0, history.length >= 2 ? 2 : 1);
    }
    if (jsonEncode(context).length > 18000) context.remove('foodPreferences');
    return jsonEncode(context);
  }

  bool accountLoading = false, accountLoaded = false, savingAccount = false;
  String accountError = '', saveError = '', timeZone = 'Asia/Kolkata';
  String authError = '';
  String locale = 'en-IN';
  int _accountEpoch = 0, _revision = 0, _savedRevision = 0;
  int get accountGeneration => _accountEpoch;
  int foodRecordsGeneration = 0;
  int _foodVersion = 0, _foodRevision = 0, _savedFoodRevision = 0;
  Map<String, dynamic>? _pendingFoodWrite;
  int _pendingFoodRevision = 0;
  bool foodConflict = false, foodReloading = false;
  String foodEditError = '';
  bool _disposed = false;
  Timer? _saveTimer;
  Future<void>? _saveWork;
  final _memory = <String, Map<String, dynamic>>{};
  final _removedMemoryKeys = <String>{};
  bool get hasUnsavedChanges =>
      _revision != _savedRevision || _foodRevision != _savedFoodRevision;

  FoodRecords get _foodRecords => FoodRecords(pantry, intake, days, firstDate);

  void _restoreFood(FoodRecords records) {
    pantry
      ..clear()
      ..addAll(records.pantry);
    intake
      ..clear()
      ..addAll(records.intake);
    days
      ..clear()
      ..addAll(records.days);
    _firstDate = records.startDate;
    _nextItem = pantry.fold<int>(0, (value, item) => max(value, item.id)) + 1;
    day = 0;
    invalidate();
  }

  bool _editFood(VoidCallback edit) {
    if (foodConflict ||
        foodReloading ||
        (backendApi != null && (!signedIn || !accountLoaded || !onboarded))) {
      foodEditError = foodConflict
          ? 'Load the saved food records before making more changes.'
          : 'Wait for your account records to load.';
      notifyListeners();
      return false;
    }
    final before = _foodRecords.toJson();
    final selectedDay = day;
    final reviewed = planReviewed, stale = quoteStale;
    edit();
    if (!_foodRecords.fitsRequest) {
      _restoreFood(FoodRecords.fromJson(before));
      day = selectedDay;
      planReviewed = reviewed;
      quoteStale = stale;
      foodEditError =
          'Your saved food records have reached their storage limit.';
      notifyListeners();
      return false;
    }
    foodEditError = '';
    if (backendApi != null) {
      _foodRevision++;
      _scheduleAccountSave();
    }
    notifyListeners();
    return true;
  }

  /// Called only after the user chooses to discard conflicting local food edits.
  Future<void> reloadSavedFoodRecords() async {
    final api = backendApi;
    if (api == null ||
        savingAccount ||
        foodReloading ||
        !signedIn ||
        !accountLoaded)
      return;
    final epoch = _accountEpoch;
    var restored = false;
    foodReloading = true;
    notifyListeners();
    try {
      final data = await api.getFoodState();
      final state = data['state'] as Map<String, dynamic>?;
      final records = state == null
          ? FoodRecords.empty()
          : FoodRecords.fromJson(state);
      if (_disposed || epoch != _accountEpoch) return;
      _restoreFood(records);
      foodRecordsGeneration++;
      _foodVersion = data['version'] as int;
      _foodRevision = _savedFoodRevision = 0;
      if (state == null) _foodRevision = 1;
      _pendingFoodWrite = null;
      foodConflict = false;
      foodEditError = saveError = '';
      restored = true;
    } catch (_) {
      if (!_disposed && epoch == _accountEpoch) {
        saveError =
            'Could not load saved food records. Your local changes are still here.';
      }
    } finally {
      if (!_disposed && epoch == _accountEpoch) {
        foodReloading = false;
        if (restored && hasUnsavedChanges) _scheduleAccountSave();
        notifyListeners();
      }
    }
  }

  Map<String, dynamic> _preferencesJson() => {
    'locale': locale,
    'currency': 'INR',
    'notificationsEnabled': notificationsEnabled,
    'notificationFrequency': frequency,
    'notificationCategories': notificationCategories.toList(),
    'quietStart': quietStart,
    'quietEnd': quietEnd,
    'timeZone': timeZone,
  };

  Future<void> loadAccountData() async {
    final api = backendApi;
    if (api == null || accountLoading) return;
    final epoch = _accountEpoch;
    accountLoading = true;
    accountError = '';
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        api.getProfile(),
        api.getPreferences(),
        api.getMemory(),
        api.getFoodState(),
      ]);
      if (_disposed || epoch != _accountEpoch) return;
      final savedProfile = results[0] as Map<String, dynamic>?;
      final restored = Profile();
      if (savedProfile != null) restored.restore(savedProfile);
      final preferences = results[1] as Map<String, dynamic>?;
      final records = results[2] as List<Map<String, dynamic>>;
      final food = results[3] as Map<String, dynamic>;
      final foodState = food['state'] as Map<String, dynamic>?;
      final foodRecords = foodState == null
          ? FoodRecords.empty()
          : FoodRecords.fromJson(foodState);
      _restoreFood(foodRecords);
      foodRecordsGeneration++;
      _foodVersion = food['version'] as int;
      _foodRevision = _savedFoodRevision = 0;
      _pendingFoodWrite = null;
      foodConflict = false;
      foodEditError = '';
      profile = restored;
      if (preferences != null) {
        locale = preferences['locale'] as String;
        notificationsEnabled = preferences['notificationsEnabled'] as bool;
        frequency = preferences['notificationFrequency'] as String;
        notificationCategories
          ..clear()
          ..addAll(
            (preferences['notificationCategories'] as List).cast<String>(),
          );
        quietStart = (preferences['quietStart'] as String).substring(0, 5);
        quietEnd = (preferences['quietEnd'] as String).substring(0, 5);
        timeZone = preferences['timeZone'] as String;
      }
      _memory.clear();
      _removedMemoryKeys.clear();
      pausedFacts.clear();
      factSources.clear();
      for (final record in records) {
        final key = record['key'] as String;
        _memory[key] = record;
        factSources[key] = record['source'] as String;
        if (record['status'] == 'paused') pausedFacts.add(key);
      }
      onboarded = savedProfile != null && restored.acknowledged;
      accountLoaded = true;
      _revision = _savedRevision = 0;
      quoteStale = true;
      if (foodState == null) {
        _foodRevision = 1;
        if (onboarded) _scheduleAccountSave();
      }
    } catch (_) {
      if (!_disposed && epoch == _accountEpoch) {
        accountError =
            'Could not load your saved details. Check your connection and retry.';
      }
    } finally {
      if (!_disposed && epoch == _accountEpoch) {
        accountLoading = false;
        notifyListeners();
      }
    }
  }

  void _queueAccountSave() {
    if (backendApi == null || !signedIn || !accountLoaded || !onboarded) return;
    _revision++;
    _scheduleAccountSave();
  }

  void _scheduleAccountSave() {
    if (!foodConflict) saveError = '';
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 450),
      () => saveAccountData(),
    );
  }

  Future<void> saveAccountData() {
    if (foodReloading) return Future<void>.value();
    _saveTimer?.cancel();
    if (_saveWork != null) return _saveWork!;
    final work = _persistAccount();
    _saveWork = work;
    return work.whenComplete(() {
      if (identical(_saveWork, work)) _saveWork = null;
    });
  }

  Future<void> _persistAccount() async {
    final api = backendApi;
    if (api == null || !signedIn || !accountLoaded) return;
    final epoch = _accountEpoch;
    savingAccount = true;
    saveError = foodConflict
        ? 'Food records changed on another device. Load the saved version to continue.'
        : '';
    notifyListeners();
    try {
      while (_savedRevision != _revision ||
          (!foodConflict && _savedFoodRevision != _foodRevision)) {
        if (!foodConflict && _savedFoodRevision != _foodRevision) {
          if (_pendingFoodWrite == null) {
            final random = Random.secure();
            _pendingFoodRevision = _foodRevision;
            _pendingFoodWrite = {
              'expectedVersion': _foodVersion,
              'mutationId': List.generate(
                16,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
              ).join(),
              'state': _foodRecords.toJson(),
            };
          }
          final version = await api.saveFoodState(_pendingFoodWrite!);
          if (_disposed || epoch != _accountEpoch) return;
          _foodVersion = version;
          _savedFoodRevision = _pendingFoodRevision;
          _pendingFoodWrite = null;
        }
        if (_savedRevision == _revision) continue;
        final revision = _revision;
        final profileData = profile.toJson();
        final preferences = _preferencesJson();
        final snapshot = facts
            .map(
              (f) => <String, dynamic>{
                'key': f.key,
                'label': f.label,
                'value': f.value,
                'source': factSources[f.key] ?? f.source,
                'safetyRelevant': f.safety,
                'status': pausedFacts.contains(f.key) ? 'paused' : 'active',
              },
            )
            .toList();
        await api.saveProfile(profileData);
        if (_disposed || epoch != _accountEpoch) return;
        await api.savePreferences(preferences);
        if (_disposed || epoch != _accountEpoch) return;
        final retained = snapshot.map((f) => f['key'] as String).toSet();
        for (final entry in _memory.entries.toList()) {
          if (!retained.contains(entry.key)) {
            await api.deleteMemory(entry.value['id'] as String);
            if (_disposed || epoch != _accountEpoch) return;
            _memory.remove(entry.key);
          }
        }
        for (final fact in snapshot) {
          final response = await api.saveMemory(fact);
          if (_disposed || epoch != _accountEpoch) return;
          _memory[fact['key'] as String] =
              response['data'] as Map<String, dynamic>;
        }
        _savedRevision = revision;
      }
    } catch (error) {
      if (!_disposed && epoch == _accountEpoch) {
        if (error is BackendException &&
            error.message == 'food_state_conflict') {
          foodConflict = true;
          saveError =
              'Food records changed on another device. Load the saved version to continue.';
        } else {
          saveError =
              'Your latest changes are not saved. Check your connection and retry.';
        }
      }
    } finally {
      if (!_disposed && epoch == _accountEpoch) {
        savingAccount = false;
        notifyListeners();
      }
    }
  }

  static bool _profileFactKey(String key) =>
      const [
        'pattern',
        'goals',
        'cuisines',
        'health',
        'exclusions',
      ].contains(key) ||
      key.startsWith('allergy:');

  void _clearAccountState() {
    pendingChatAction = null;
    chatActionApplied = chatActionBusy = false;
    chatActionMessage = '';
    _accountEpoch++;
    _saveTimer?.cancel();
    _saveWork = null;
    profile = Profile();
    pantry.clear();
    intake.clear();
    chat.clear();
    days
      ..clear()
      ..addAll(List.generate(5, (_) => DayDraft()));
    pausedFacts.clear();
    factSources.clear();
    _memory.clear();
    _removedMemoryKeys.clear();
    day = selectedGrocer = selectedPrepared = 0;
    _nextItem = 1;
    onboarded = conversation = planReviewed = false;
    quoteStale = true;
    focus = ChatFocus.plan;
    request = aiReply = aiError = '';
    shareFoodContext = false;
    _aiHistory.clear();
    _failedPrompt = null;
    frequency = 'Daily';
    quietStart = '22:00';
    quietEnd = '07:00';
    locale = 'en-IN';
    timeZone = 'Asia/Kolkata';
    notificationsEnabled = true;
    notificationCategories
      ..clear()
      ..addAll(['Plan ready', 'Pantry check', 'Meal check-in']);
    cloudAiConsent = null;
    aiBusy = aiSettingsBusy = false;
    accountLoaded = accountLoading = savingAccount = false;
    accountError = saveError = aiSettingsMessage = '';
    _revision = _savedRevision = 0;
    _foodVersion = _foodRevision = _savedFoodRevision = 0;
    _pendingFoodWrite = null;
    foodConflict = foodReloading = false;
    foodEditError = '';
    _firstDate = DateUtilsLocal.tomorrow();
  }

  @override
  void dispose() {
    _disposed = true;
    _accountEpoch++;
    _saveTimer?.cancel();
    super.dispose();
  }

  List<MealType> get plannedTypes => switch (profile.coverage) {
    'Dinner only' => [MealType.dinner],
    'Lunch & dinner' => [MealType.lunch, MealType.dinner],
    _ => MealType.values,
  };
  List<MealType> get activeTypes =>
      plannedTypes.where((type) => !slot(type).removed).toList();
  MealSlot slot(MealType type) => days[day].slots[type]!;
  bool get hasHealth =>
      profile.health.any((v) => v != 'None' && v != 'Prefer not to say');
  bool get safetyPaused =>
      facts.any((f) => f.safety && pausedFacts.contains(f.key));

  String? get foodHoldReason {
    if (safetyPaused)
      return 'A food detail is paused. Review it before using a meal plan.';
    if (profile.allergies.isNotEmpty || profile.exclusions.trim().isNotEmpty) {
      return 'Your food rules need verified ingredient and allergen information before suitable meals can be shown.';
    }
    if (hasHealth)
      return 'Your shared health context needs a review before this example plan can be used.';
    return null;
  }

  String? get holdReason {
    if (foodHoldReason != null) return foodHoldReason;
    if (profile.cookingMinutes < 25)
      return 'This example takes about 25 minutes, above your cooking-time limit.';
    if (profile.budget < 640)
      return 'This example grocery estimate exceeds your weekly budget.';
    return null;
  }

  bool get canUseQuote =>
      holdReason == null &&
      !quoteStale &&
      day == 0 &&
      activeTypes.length == 3 &&
      profile.coverage == 'Breakfast, lunch & dinner';
  String get planStatus => holdReason != null
      ? 'Needs a check'
      : quoteStale || day != 0
      ? 'Needs a new quote'
      : '3 meals ready';

  void updateProfile(VoidCallback edit, {bool affectsPlan = true}) {
    edit();
    if (onboarded && affectsPlan) invalidate();
    _queueAccountSave();
    notifyListeners();
  }

  void toggle(Set<String> values, String value) => updateProfile(() {
    if (!values.remove(value)) values.add(value);
  });
  void toggleHealth(String value) => updateProfile(() {
    if (profile.health.remove(value)) return;
    if (value == 'None' || value == 'Prefer not to say') {
      profile.health.clear();
    } else {
      profile.health.removeAll({'None', 'Prefer not to say'});
    }
    profile.health.add(value);
  });
  void toggleCuisine(String value) => updateProfile(() {
    if (profile.cuisines.remove(value)) return;
    if (value == 'Anything')
      profile.cuisines.clear();
    else
      profile.cuisines.remove('Anything');
    profile.cuisines.add(value);
  });
  String? validateProfile() {
    final p = profile;
    if (p.goals.isEmpty)
      return 'Choose at least one thing you would like help with.';
    if (p.cuisines.isEmpty) return 'Choose a cuisine or select Anything.';
    if ((p.goals.contains('Other') && p.otherGoal.trim().isEmpty) ||
        (p.allergies.contains('Other') && p.otherAllergy.trim().isEmpty) ||
        (p.health.contains('Other') && p.otherHealth.trim().isEmpty) ||
        (p.cuisines.contains('Other') && p.otherCuisine.trim().isEmpty)) {
      return 'Fill in the detail for each selected Other option.';
    }
    if (!p.acknowledged) return 'Please review the acknowledgement below.';
    return null;
  }

  Future<void> completeOnboarding() async {
    if (validateProfile() != null || savingAccount) return;
    final epoch = _accountEpoch;
    if (backendApi != null) {
      _revision++;
      await saveAccountData();
      if (_disposed ||
          epoch != _accountEpoch ||
          saveError.isNotEmpty ||
          hasUnsavedChanges)
        return;
    }
    onboarded = true;
    quoteStale = profile.coverage != 'Breakfast, lunch & dinner';
    notifyListeners();
  }

  void invalidate() {
    quoteStale = true;
    planReviewed = false;
  }

  void selectDay(int value) {
    if (value < 0 || value >= days.length) return;
    day = value;
    planReviewed = false;
    notifyListeners();
  }

  void rotate(String direction) {
    if (holdReason != null) return;
    _editFood(() {
      for (final type in plannedTypes) {
        final meal = slot(type);
        meal.option = switch (direction) {
          'italian' => (1 - day) % 5,
          'quick' => (3 - day) % 5,
          _ => (meal.option + 1) % 5,
        };
        meal.removed = false;
      }
      invalidate();
    });
  }

  bool rotateFromText(String text) {
    final v = text.toLowerCase();
    if (v.contains('italian')) {
      rotate('italian');
      return true;
    }
    if (v.contains('quick') || v.contains('simple')) {
      rotate('quick');
      return true;
    }
    if (v.contains('different')) {
      rotate('different');
      return true;
    }
    return false;
  }

  void swap(MealType type) {
    _editFood(() {
      slot(type).option = (slot(type).option + 1) % 5;
      invalidate();
    });
  }

  void setServings(MealType type, int value) {
    if (value < 1 || value > 4 || value == slot(type).servings) return;
    _editFood(() {
      slot(type).servings = value;
      invalidate();
    });
  }

  void removeMeal(MealType type, bool removed) {
    _editFood(() {
      slot(type).removed = removed;
      invalidate();
    });
  }

  void startNewDraft() => _editFood(() {
    days
      ..clear()
      ..addAll(List.generate(5, (_) => DayDraft()));
    _firstDate = DateUtilsLocal.tomorrow();
    day = 0;
    invalidate();
  });

  bool reviewPlan() {
    if (!canUseQuote) return false;
    planReviewed = true;
    notifyListeners();
    return true;
  }

  void selectGrocer(int value) {
    selectedGrocer = value;
    notifyListeners();
  }

  void selectPrepared(int value) {
    selectedPrepared = value;
    notifyListeners();
  }

  String? savePantry({
    int? id,
    required String name,
    required String amount,
    required PantryKind kind,
  }) {
    if (name.trim().isEmpty || amount.trim().isEmpty)
      return 'Add an item and its amount.';
    if (name.trim().length > 200 || amount.trim().length > 200)
      return 'Keep each detail within 200 characters.';
    if (id == null && pantry.length >= 500)
      return 'Your pantry is full (500 items). Remove an item first.';
    if (id != null && !pantry.any((item) => item.id == id))
      return 'This item is no longer in your pantry. Open it again.';
    if (id == null && _nextItem > 2147483647)
      return 'Could not allocate another pantry item.';
    final changed = _editFood(() {
      final item = PantryItem(
        id: id ?? _nextItem++,
        name: name.trim(),
        amount: amount.trim(),
        kind: kind,
      );
      final index = pantry.indexWhere((p) => p.id == id);
      if (index >= 0)
        pantry[index] = item;
      else
        pantry.add(item);
      invalidate();
    });
    return changed ? null : foodEditError;
  }

  String? removePantry(int id) {
    final changed = _editFood(() {
      pantry.removeWhere((p) => p.id == id);
      invalidate();
    });
    return changed ? null : foodEditError;
  }

  String? recordIntake({
    required String name,
    required String portion,
    int? sourceId,
    String? remaining,
  }) {
    if (name.trim().isEmpty || portion.trim().isEmpty)
      return 'Add a meal and portion.';
    if (name.trim().length > 200 ||
        portion.trim().length > 200 ||
        (remaining?.trim().length ?? 0) > 200)
      return 'Keep each detail within 200 characters.';
    if (intake.length >= 5000)
      return 'Your saved meal log has reached its limit of 5000 entries.';
    final index = pantry.indexWhere((p) => p.id == sourceId);
    if (sourceId != null && index < 0)
      return 'The linked pantry item changed. Reopen this meal form.';
    if (sourceId != null && (remaining == null || remaining.trim().isEmpty))
      return 'Confirm the remaining pantry amount.';
    final source = index < 0 ? null : pantry[index];
    final changed = _editFood(() {
      intake.insert(
        0,
        Intake(
          name: name.trim(),
          portion: portion.trim(),
          at: DateTime.now(),
          sourceName: source?.name,
          remaining: source == null ? null : remaining?.trim(),
        ),
      );
      if (source != null && remaining != null && remaining.trim().isNotEmpty) {
        pantry[index] = PantryItem(
          id: source.id,
          name: source.name,
          amount: remaining.trim(),
          kind: source.kind,
        );
        invalidate();
      }
    });
    return changed ? null : foodEditError;
  }

  Future<void> submitChat(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || aiBusy || chatActionBusy) return;
    final action = parseChatAction(clean);
    if (action != null) {
      conversation = true;
      if (pendingChatAction != null) {
        chat.add(
          const ChatEntry('Finish or cancel the current change first.', false),
        );
      } else {
        pendingChatAction = action;
        chatActionApplied = false;
        _actionSnapshot = jsonEncode(profile.toJson());
        chatActionMessage =
            '${action.label}: ${action.current(profile)} → ${action.value}';
        chat.add(ChatEntry(clean, true));
      }
      notifyListeners();
      return;
    }
    final saved = savedChatFocus(clean);
    if (saved != null) {
      request = clean;
      focus = saved;
      conversation = false;
      notifyListeners();
      return;
    }
    if (aiService != null) {
      await _submitAiConversation(clean);
      return;
    }
    conversation = true;
    chat.add(ChatEntry(clean, true));
    chat.add(
      const ChatEntry(
        'Your message is here. The planning agent is not connected in this preview, so no calculation or saved detail has changed.',
        false,
      ),
    );
    notifyListeners();
  }

  void connectBackend({
    required String baseUrl,
    required GoogleSignInService auth,
  }) {
    _clearAccountState();
    final api = BackendApi(baseUrl: baseUrl, accessToken: auth.accessToken);
    backendApi?.close();
    googleSignIn?.close();
    backendApi = api;
    googleSignIn = auth;
    cloudAiConsent = null;
    modelInstalled = false;
    aiService = ValoraAiService(
      api,
      onDeviceEnabled:
          !kIsWeb &&
          defaultTargetPlatform != TargetPlatform.windows &&
          defaultTargetPlatform != TargetPlatform.linux &&
          defaultTargetPlatform != TargetPlatform.macOS,
    );
    notifyListeners();
    _restoreAuthSession(auth);
  }

  Future<void> _restoreAuthSession(GoogleSignInService auth) async {
    final epoch = _accountEpoch;
    try {
      final token = await auth.accessToken();
      if (_disposed || epoch != _accountEpoch) return;
      signedIn = token != null;
      if (signedIn) await _startAccountSession();
    } catch (_) {
      if (_disposed || epoch != _accountEpoch) return;
      final stored = await auth.signedIn;
      if (_disposed || epoch != _accountEpoch) return;
      signedIn = stored;
      if (signedIn)
        accountError =
            'Could not restore your session. Check your connection and retry.';
    } finally {
      if (!_disposed && epoch == _accountEpoch) {
        authResolved = true;
        notifyListeners();
      }
    }
    if (!_disposed && epoch == _accountEpoch && signedIn) refreshAiSettings();
  }

  Future<void> _startAccountSession() async {
    final auth = googleSignIn!;
    final baseUrl = backendApi!.baseUrl;
    final epoch = _accountEpoch;
    final previous = backendApi;
    backendApi = BackendApi(
      baseUrl: baseUrl,
      onUnauthorized: () {
        if (!_disposed && epoch == _accountEpoch) signOut();
      },
      accessToken: () async {
        if (_disposed || epoch != _accountEpoch)
          throw const BackendException('session_changed');
        final token = await auth.accessToken();
        if (_disposed || epoch != _accountEpoch)
          throw const BackendException('session_changed');
        return token;
      },
    );
    previous?.close();
    aiService = ValoraAiService(
      backendApi!,
      onDeviceEnabled:
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS),
    );
    await loadAccountData();
  }

  Future<void> signInWithGoogle() async {
    final auth = googleSignIn;
    if (auth == null || signingIn) return;
    authError = '';
    signingIn = true;
    notifyListeners();
    try {
      await auth.signIn();
    } finally {
      if (!_disposed) {
        signingIn = false;
        notifyListeners();
      }
    }
  }

  Future<void> handleAuthCallback(Uri uri) async {
    final auth = googleSignIn;
    if (auth == null) return;
    bool completed;
    try {
      completed = await auth.handleCallback(uri);
    } catch (_) {
      if (!_disposed && !signedIn) {
        authError = 'Sign-in did not complete. Please try again.';
        notifyListeners();
      }
      return;
    }
    if (completed && !_disposed) {
      _clearAccountState();
      signedIn = true;
      authResolved = true;
      notifyListeners();
      await _startAccountSession();
      await refreshAiSettings();
    }
  }

  Future<void> signOut() async {
    _clearAccountState();
    signedIn = false;
    authResolved = true;
    signingIn = true;
    notifyListeners();
    try {
      await googleSignIn?.signOut();
    } finally {
      if (!_disposed) {
        signingIn = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshAiSettings() async {
    final api = backendApi;
    final epoch = _accountEpoch;
    if (api == null || aiSettingsBusy) return;
    aiSettingsBusy = true;
    aiSettingsMessage = '';
    notifyListeners();
    try {
      if (aiService?.onDeviceEnabled == true) {
        try {
          final installed = await aiService!.isLocalModelInstalled();
          if (_disposed || epoch != _accountEpoch) return;
          modelInstalled = installed;
        } catch (_) {
          modelInstalled = false;
        }
      }
      if (aiService?.localOnly == true) return;
      final consent = await api.getCloudAiConsent();
      if (_disposed || epoch != _accountEpoch) return;
      cloudAiConsent = consent;
    } catch (e) {
      if (_disposed || epoch != _accountEpoch) return;
      aiSettingsMessage = _friendlyAiError(e);
    } finally {
      if (!_disposed && epoch == _accountEpoch) {
        aiSettingsBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> setCloudAiConsent(bool enabled) async {
    final epoch = _accountEpoch;
    final api = backendApi;
    if (api == null || aiSettingsBusy) return;
    aiSettingsBusy = true;
    final previous = cloudAiConsent;
    cloudAiConsent = null;
    aiSettingsMessage = '';
    notifyListeners();
    try {
      final consent = await api.setCloudAiConsent(enabled);
      if (_disposed || epoch != _accountEpoch) return;
      cloudAiConsent = consent;
      aiSettingsMessage = enabled
          ? 'Cloud AI enabled. Prompts sent to the configured AI provider are not stored by Valora.'
          : 'Cloud AI disabled.';
    } catch (e) {
      if (_disposed || epoch != _accountEpoch) return;
      cloudAiConsent = previous;
      aiSettingsMessage = _friendlyAiError(e);
    } finally {
      if (!_disposed && epoch == _accountEpoch) {
        aiSettingsBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> installGemma() async {
    final service = aiService;
    if (service == null || !service.onDeviceEnabled || aiSettingsBusy) return;
    aiSettingsBusy = true;
    modelDownloadProgress = 0;
    aiSettingsMessage = 'Downloading Gemma… Keep Valora open and use Wi-Fi.';
    notifyListeners();
    try {
      await service.installLocalModel(
        onProgress: (value) {
          modelDownloadProgress = value;
          notifyListeners();
        },
      );
      modelInstalled = true;
      aiSettingsMessage = 'Gemma is ready on this device.';
    } catch (e, stackTrace) {
      debugPrint('Gemma model download failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      aiSettingsMessage =
          'Gemma could not finish downloading. Check your Wi-Fi, free storage, and allow the download notification, then try again.';
    } finally {
      aiSettingsBusy = false;
      modelDownloadProgress = -1;
      notifyListeners();
    }
  }

  String _friendlyAiError(Object error) => switch (error) {
    BackendException(:final message)
        when message == 'Sign in to connect to your saved Valora data.' =>
      'Sign in to manage cloud AI settings.',
    BackendException(:final message) when message == 'unauthorized' =>
      'Your sign-in has expired. Sign in again.',
    BackendException(:final message)
        when message == 'ai_provider_unavailable' =>
      'Cloud AI is not configured yet.',
    _ => 'Could not load AI settings. Check the API connection and try again.',
  };

  Future<void> submitAiChat(String text) => submitChat(text);

  Future<void> _submitAiConversation(String text, {bool retry = false}) async {
    final epoch = _accountEpoch;
    final clean = text.trim();
    final service = aiService;
    if (clean.isEmpty || service == null || aiBusy) return;
    conversation = true;
    aiBusy = true;
    aiError = '';
    if (!retry) chat.add(ChatEntry(clean, true));
    _failedPrompt = null;
    notifyListeners();
    try {
      final complexity = _requiresCloudAi(clean)
          ? AiComplexity.complex
          : AiComplexity.routine;
      final reply = await service.respond(
        task: AiTask.conversation,
        complexity: complexity,
        prompt: clean,
        context: _conversationContext(),
      );
      if (_disposed || epoch != _accountEpoch) return;
      aiReply = reply.source;
      chat.add(ChatEntry(reply.text, false, source: reply.source));
      _aiHistory.addAll([ChatEntry(clean, true), ChatEntry(reply.text, false)]);
      if (_aiHistory.length > 8)
        _aiHistory.removeRange(0, _aiHistory.length - 8);
    } catch (error) {
      if (_disposed || epoch != _accountEpoch) return;
      final code = error is BackendException ? error.message : '';
      _failedPrompt = clean;
      aiError = switch (code) {
        'local_ai_model_not_installed' =>
          'Download Gemma on this device in AI settings before sending chat messages.',
        'local_ai_inference_failed' =>
          'Gemma could not answer this on-device request. Try a shorter message or another request.',
        'on_device_ai_unsupported_platform' =>
          'On-device Gemma testing is available in the Android and iOS apps.',
        'cloud_ai_consent_required' =>
          'To get an AI reply, enable cloud AI in AI settings or download Gemma for routine requests.',
        'local_ai_failed_consent_required' =>
          'Gemma could not answer on this device. Enable cloud AI in AI settings to use the fallback, then retry.',
        'ai_provider_unavailable' =>
          'Cloud AI is unavailable. Check the provider setup or retry shortly.',
        'ai_provider_request_failed' =>
          'The cloud provider could not complete this request. Please retry shortly.',
        'unauthorized' => 'Your sign-in expired. Sign in again to continue.',
        'message_too_long' =>
          'Please shorten your message to 12,000 characters or fewer.',
        _ =>
          'Could not get an AI reply. Your message is still here; check your connection and retry.',
      };
    } finally {
      if (!_disposed && epoch == _accountEpoch) {
        if (aiError.isNotEmpty)
          chat.add(ChatEntry(aiError, false, isError: true));
        aiBusy = false;
        notifyListeners();
      }
    }
  }

  bool _requiresCloudAi(String text) =>
      RegExp(
        r'\b(analy[sz]e|compare|extract|summari[sz]e|document|report|long|detailed|complex)\b',
        caseSensitive: false,
      ).hasMatch(text) ||
      text.length > 1200;

  void openFocus(ChatFocus value) {
    focus = value;
    conversation = false;
    request = '';
    notifyListeners();
  }

  void backToSpace() {
    conversation = false;
    request = '';
    notifyListeners();
  }

  List<SavedFact> get facts {
    final p = profile;
    final result = <SavedFact>[
      SavedFact(
        'pattern',
        'Eating pattern',
        p.pattern,
        'Shared by you',
        safety: true,
      ),
      SavedFact(
        'goals',
        'Goals',
        p.resolved(p.goals, p.otherGoal),
        'Shared by you',
      ),
      SavedFact(
        'cuisines',
        'Cuisine preferences',
        p.resolved(p.cuisines, p.otherCuisine),
        'Shared by you',
      ),
      if (p.exclusions.trim().isNotEmpty)
        SavedFact(
          'exclusions',
          'Foods to avoid',
          p.exclusions,
          factSources['exclusions'] ?? 'Shared by you',
          safety: true,
        ),
      ...p.allergies.map(
        (a) => SavedFact(
          'allergy:$a',
          'Reported allergy',
          a == 'Other' ? p.otherAllergy : a,
          factSources['allergy:$a'] ?? 'Shared by you',
          safety: true,
        ),
      ),
      if (hasHealth)
        SavedFact(
          'health',
          'Health context',
          p.resolved(p.health, p.otherHealth),
          factSources['health'] ?? 'Shared by you',
          safety: true,
        ),
    ];
    result.addAll(
      _memory.entries
          .where(
            (e) =>
                !_profileFactKey(e.key) && !_removedMemoryKeys.contains(e.key),
          )
          .map(
            (e) => SavedFact(
              e.key,
              e.value['label'] as String,
              e.value['value'] as String,
              e.value['source'] as String,
              safety: e.value['safetyRelevant'] as bool,
            ),
          ),
    );
    return result
        .where((f) => f.value.isNotEmpty)
        .map(
          (f) => SavedFact(
            f.key,
            f.label,
            f.value,
            factSources[f.key] ?? f.source,
            safety: f.safety,
          ),
        )
        .toList();
  }

  void pauseFact(String key) {
    if (!pausedFacts.remove(key)) pausedFacts.add(key);
    invalidate();
    _queueAccountSave();
    notifyListeners();
  }

  void removeFact(String key) {
    if (key.startsWith('allergy:')) {
      final allergy = key.substring(8);
      profile.allergies.remove(allergy);
      if (allergy == 'Other') profile.otherAllergy = '';
    } else {
      switch (key) {
        case 'health':
          profile.health.clear();
          profile.otherHealth = '';
          break;
        case 'exclusions':
          profile.exclusions = '';
          break;
        case 'goals':
          profile.goals.clear();
          break;
        case 'cuisines':
          profile.cuisines.clear();
          break;
        default:
          if (!_memory.containsKey(key)) return;
          _removedMemoryKeys.add(key);
      }
    }
    pausedFacts.remove(key);
    factSources.remove(key);
    invalidate();
    _queueAccountSave();
    notifyListeners();
  }

  void confirmSampleFact(String kind, String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    String key;
    if (kind == 'Reported allergy') {
      final known = [
        'Peanuts',
        'Tree nuts',
        'Milk',
        'Eggs',
        'Wheat',
      ].where((v) => v.toLowerCase() == clean.toLowerCase());
      final allergy = known.isEmpty ? 'Other' : known.first;
      profile.allergies.add(allergy);
      if (allergy == 'Other') {
        profile.otherAllergy = {
          profile.otherAllergy.trim(),
          clean,
        }.where((v) => v.isNotEmpty).join(', ');
      }
      key = 'allergy:$allergy';
    } else if (kind == 'Health context') {
      profile.health.removeAll({'None', 'Prefer not to say'});
      profile.health.add('Other');
      profile.otherHealth = {
        profile.otherHealth.trim(),
        clean,
      }.where((v) => v.isNotEmpty).join(', ');
      key = 'health';
    } else {
      profile.exclusions = [
        profile.exclusions,
        clean,
      ].where((v) => v.isNotEmpty).join(', ');
      key = 'exclusions';
    }
    factSources[key] = 'Sample source · page 1 · confirmed by you';
    invalidate();
    _queueAccountSave();
    notifyListeners();
  }

  void updateNotifications(VoidCallback edit) {
    edit();
    _queueAccountSave();
    notifyListeners();
  }

  Recipe recipe(MealType type) {
    final index = (slot(type).option + day) % 5;
    final vegan = profile.pattern == 'Vegan';
    final recipes = switch (type) {
      MealType.breakfast => [
        Recipe(
          vegan ? 'Fruit & oat bowl' : 'Yogurt, banana & oats',
          ['Oats', vegan ? 'Seasonal fruit' : 'Yogurt', 'Banana'],
          10,
          ['Prepare the oats.', 'Top with fruit and serve.'],
        ),
        const Recipe(
          'Tomato & basil toast',
          ['Bread', 'Tomato', 'Basil'],
          15,
          ['Toast the bread.', 'Add sliced tomato and basil.'],
        ),
        Recipe(
          vegan
              ? 'Banana oat pancakes'
              : profile.pattern == 'Vegetarian'
              ? 'Paneer toast & fruit'
              : 'Egg toast & fruit',
          vegan
              ? ['Oats', 'Banana', 'Plant milk']
              : [
                  'Bread',
                  profile.pattern == 'Vegetarian' ? 'Paneer' : 'Eggs',
                  'Fruit',
                ],
          20,
          ['Prepare the ingredients.', 'Cook the base and serve with fruit.'],
        ),
        const Recipe(
          'Apple & cinnamon oats',
          ['Oats', 'Apple', 'Cinnamon'],
          10,
          ['Cook the oats.', 'Add apple and cinnamon.'],
        ),
        const Recipe(
          'Avocado toast & tomatoes',
          ['Bread', 'Avocado', 'Tomato'],
          10,
          ['Toast the bread.', 'Top with avocado and tomato.'],
        ),
      ],
      MealType.lunch => [
        const Recipe(
          'Chickpea rice bowl',
          ['Rice', 'Chickpeas', 'Cucumber'],
          20,
          ['Cook the rice.', 'Combine with chickpeas and cucumber.'],
        ),
        const Recipe(
          'Tomato pasta & greens',
          ['Pasta', 'Tomato', 'Leafy greens'],
          25,
          ['Cook the pasta.', 'Make a tomato sauce and add greens.'],
        ),
        Recipe(
          vegan ? 'Hummus wrap & salad' : 'Paneer wrap & salad',
          [vegan ? 'Hummus' : 'Paneer', 'Flatbread', 'Salad leaves'],
          20,
          ['Prepare the filling.', 'Fill the flatbread and serve with salad.'],
        ),
        const Recipe(
          'Lentil salad & flatbread',
          ['Lentils', 'Cucumber', 'Flatbread'],
          20,
          [
            'Prepare the lentils.',
            'Toss with cucumber and serve with flatbread.',
          ],
        ),
        const Recipe(
          'Vegetable quinoa bowl',
          ['Quinoa', 'Vegetables', 'Chickpeas'],
          25,
          ['Cook the quinoa.', 'Prepare the vegetables and combine.'],
        ),
      ],
      MealType.dinner => [
        const Recipe(
          'One-pan veggie khichdi',
          ['Rice', 'Lentils', 'Vegetables'],
          25,
          [
            'Rinse rice and lentils.',
            'Cook together with vegetables until tender.',
          ],
        ),
        Recipe(
          vegan ? 'Tomato & bean pasta' : 'Quick pesto pasta',
          ['Pasta', vegan ? 'Beans' : 'Basil pesto', 'Vegetables'],
          25,
          ['Cook the pasta.', 'Prepare the sauce and combine with vegetables.'],
        ),
        const Recipe(
          'Vegetable noodles & tofu',
          ['Noodles', 'Tofu', 'Vegetables'],
          25,
          ['Prepare noodles and vegetables.', 'Cook the tofu and combine.'],
        ),
        const Recipe(
          'Chickpea tomato stew',
          ['Chickpeas', 'Tomato', 'Onion'],
          20,
          ['Cook the onion and tomato.', 'Add chickpeas and simmer.'],
        ),
        const Recipe(
          'Roasted vegetables & couscous',
          ['Vegetables', 'Couscous', 'Olive oil'],
          25,
          ['Roast the vegetables.', 'Prepare couscous and combine.'],
        ),
      ],
    };
    return recipes[index];
  }

  List<String> get ingredients =>
      activeTypes.expand((t) => recipe(t).ingredients).toSet().toList();
  static const grocers = [
    GroceryOffer('Market Basket', 'Tomorrow, 8–10 AM', 580, 60),
    GroceryOffer('Quick Cart', 'Tonight, 9–10 PM', 620, 68),
  ];
  List<(String, String)> get basket => [
    ('Rolled oats', '500 g'),
    (profile.pattern == 'Vegan' ? 'Plant yogurt' : 'Plain yogurt', '400 g'),
    ('Bananas', '3 pcs'),
    ('Cucumber', '1 pc'),
    ('Mixed vegetables', '500 g'),
  ];
  List<PreparedOffer> get prepared {
    final italian =
        !pausedFacts.contains('cuisines') &&
        profile.cuisines.contains('Italian');
    final vegan = profile.pattern == 'Vegan';
    return [
      PreparedOffer(
        vegan
            ? 'Tofu and vegetable rice bowl'
            : italian
            ? 'Roasted vegetable pasta bowl'
            : 'Paneer rice bowl',
        vegan
            ? 'Green Wok'
            : italian
            ? 'Little Basil Kitchen'
            : 'Saffron Table',
        vegan
            ? 'Asian'
            : italian
            ? 'Italian'
            : 'Indian',
        vegan
            ? 'Rice, tofu, vegetables, soy sauce'
            : italian
            ? 'Pasta, roasted vegetables, tomato sauce'
            : 'Rice, paneer, tomato, spices',
        vegan ? 269 : 279,
        30,
        '30–40 min',
        'Closest example to your cuisine choice',
      ),
      const PreparedOffer(
        'Chickpea and grain bowl',
        'Harvest Bowl Co.',
        'Mediterranean',
        'Whole grains, chickpeas, vegetables, dressing',
        249,
        25,
        '25–35 min',
        'Vegetable-forward option',
      ),
      const PreparedOffer(
        'Dal, rice and vegetables',
        'Everyday Kitchen',
        'Indian',
        'Lentils, rice, seasonal vegetables, spices',
        219,
        20,
        '35–45 min',
        'Lowest example total',
      ),
    ];
  }
}

class DateUtilsLocal {
  static DateTime offset(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);
  static DateTime tomorrow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }
}
