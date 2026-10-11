import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel native = MethodChannel('hyouka.tvcontrol/system');

Future<Map<String, dynamic>> nativeMap(String method, [Map<String, Object?> args = const {}]) async =>
    await native.invokeMapMethod<String, dynamic>(method, args) ?? <String, dynamic>{};

Future<void> nativeVoid(String method, [Map<String, Object?> args = const {}]) =>
    native.invokeMethod<void>(method, args);

const words = <String, Map<String, String>>{
  'app': {'en':'Hyouka TV Control','ar':'هيوكا للتحكم بالتلفزيون'},
  'home': {'en':'Controls','ar':'التحكم'},
  'settings': {'en':'Settings','ar':'الإعدادات'},
  'device': {'en':'TV status','ar':'حالة التلفزيون'},
  'welcome': {'en':'Your TV, your way','ar':'تحكّم في تلفزيونك بطريقتك'},
  'subtitle': {'en':'Quick system controls for your living room.','ar':'تحكم سريع في إعدادات التلفزيون.'},
  'connected': {'en':'Shizuku connected','ar':'Shizuku متصل'},
  'notConnected': {'en':'Shizuku not running','ar':'Shizuku غير شغال'},
  'needsPermission': {'en':'Permission required','ar':'مطلوب إذن'},
  'connect': {'en':'Connect Shizuku','ar':'اتصال بـ Shizuku'},
  'refresh': {'en':'Refresh','ar':'تحديث'},
  'brightness': {'en':'Brightness','ar':'السطوع'},
  'brightnessHint': {'en':'Android display brightness','ar':'سطوع شاشة أندرويد'},
  'media': {'en':'Media volume','ar':'صوت الوسائط'},
  'systemSound': {'en':'System sounds','ar':'أصوات النظام'},
  'alarm': {'en':'Alarm volume','ar':'صوت المنبّه'},
  'presets': {'en':'Quick picture & sound presets','ar':'أوضاع سريعة للصورة والصوت'},
  'cinema': {'en':'Cinema','ar':'سينما'},
  'standard': {'en':'Standard','ar':'عادي'},
  'night': {'en':'Night','ar':'ليلي'},
  'cinemaHint': {'en':'Softer picture, balanced sound','ar':'سطوع هادئ وصوت متوازن'},
  'standardHint': {'en':'Everyday settings','ar':'إعداد يومي'},
  'nightHint': {'en':'Lower brightness and volume','ar':'سطوع وصوت أقل بالليل'},
  'timeout': {'en':'Screen-off timeout','ar':'مهلة إطفاء الشاشة'},
  'timeoutHint': {'en':'May be limited by TV firmware','ar':'قد يقيّد النظام هذا الإعداد'},
  'one': {'en':'1 minute','ar':'دقيقة'},
  'five': {'en':'5 minutes','ar':'5 دقائق'},
  'fifteen': {'en':'15 minutes','ar':'15 دقيقة'},
  'thirty': {'en':'30 minutes','ar':'30 دقيقة'},
  'sixty': {'en':'60 minutes','ar':'60 دقيقة'},
  'language': {'en':'Language','ar':'اللغة'},
  'appearance': {'en':'Appearance','ar':'المظهر'},
  'pureBlack': {'en':'Pure Black','ar':'أسود خالص'},
  'white': {'en':'White','ar':'أبيض'},
  'cozy': {'en':'Cozy','ar':'دافئ'},
  'materialYou': {'en':'Material You','ar':'Material You'},
  'english': {'en':'English','ar':'الإنجليزية'},
  'arabic': {'en':'Arabic','ar':'العربية'},
  'about': {'en':'About this TV','ar':'عن التلفزيون'},
  'model': {'en':'Manufacturer / model','ar':'الشركة / الموديل'},
  'android': {'en':'Android version','ar':'إصدار أندرويد'},
  'api': {'en':'Android API','ar':'مستوى API'},
  'uid': {'en':'Shizuku service UID','ar':'معرّف خدمة Shizuku'},
  'service': {'en':'Privileged service','ar':'الخدمة ذات الصلاحيات'},
  'available': {'en':'Available','ar':'متاحة'},
  'unavailable': {'en':'Unavailable','ar':'غير متاحة'},
  'aboutHint': {'en':'Brightness depends on TV firmware. This app does not power off the TV.','ar':'السطوع حسب دعم نظام التلفزيون. التطبيق لا يطفئ التلفزيون.'},
  'help': {'en':'Use the remote D-pad to move; press OK to select.','ar':'استخدم أسهم الريموت للتنقل وزر OK للاختيار.'},
  'failed': {'en':'Control failed','ar':'فشل التحكم'},
  'retry': {'en':'Try again','ar':'حاول تاني'},
  'noData': {'en':'Connect Shizuku to read and change system controls.','ar':'اتصل بـ Shizuku لتغيير إعدادات النظام.'},
  'serviceUnavailable': {'en':'TV control service is not connected','ar':'خدمة التحكم بالتلفزيون غير متصلة'},
  'startShizuku': {'en':'Start Shizuku, then grant this app permission.','ar':'شغّل Shizuku ثم امنح التطبيق الإذن.'},
};
String tr(String key, String language) => words[key]?[language] ?? words[key]?['en'] ?? key;

class HyoukaTvControlApp extends StatefulWidget {
  const HyoukaTvControlApp({super.key});
  @override
  State<HyoukaTvControlApp> createState() => _HyoukaTvControlAppState();
}

class _HyoukaTvControlAppState extends State<HyoukaTvControlApp> {
  String language = 'en';
  String themeKey = 'pureBlack';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await nativeMap('getPreferences');
      if (!mounted) return;
      setState(() {
        if (prefs['language'] == 'ar' || prefs['language'] == 'en') language = prefs['language'] as String;
        if (const {'pureBlack','white','cozy','materialYou'}.contains(prefs['theme'])) themeKey = prefs['theme'] as String;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try { await nativeVoid('savePreferences', {'language': language, 'theme': themeKey}); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: tr('app', language),
    debugShowCheckedModeBanner: false,
    theme: makeTheme(themeKey),
    home: Directionality(
      textDirection: language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: TvHome(
        language: language,
        themeKey: themeKey,
        onLanguage: (value) { setState(() => language = value); _save(); },
        onTheme: (value) { setState(() => themeKey = value); _save(); },
      ),
    ),
  );
}

ThemeData makeTheme(String key) {
  final isWhite = key == 'white';
  final isCozy = key == 'cozy';
  final isBlack = key == 'pureBlack';
  final brightness = isWhite ? Brightness.light : Brightness.dark;
  final seed = switch (key) {
    'white' => const Color(0xFF343A46),
    'cozy' => const Color(0xFFD9A86C),
    'materialYou' => const Color(0xFFB8C5FF),
    _ => Colors.white,
  };
  final background = isBlack ? Colors.black : isWhite ? const Color(0xFFF6F7FA) : isCozy ? const Color(0xFF211B16) : const Color(0xFF171922);
  final surface = isBlack ? Colors.black : isWhite ? Colors.white : isCozy ? const Color(0xFF30261E) : const Color(0xFF222532);
  final foreground = isWhite ? const Color(0xFF171923) : Colors.white;
  final accent = isBlack ? Colors.white : seed;
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness).copyWith(
    primary: accent,
    onPrimary: isBlack ? Colors.black : (isWhite ? Colors.white : const Color(0xFF171923)),
    surface: surface,
    onSurface: foreground,
    secondary: isCozy ? const Color(0xFFFFD9AA) : seed,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: foreground.withValues(alpha: 0.14),
    focusColor: accent.withValues(alpha: 0.22),
  );
}

class TvHome extends StatefulWidget {
  const TvHome({required this.language, required this.themeKey, required this.onLanguage, required this.onTheme, super.key});
  final String language;
  final String themeKey;
  final ValueChanged<String> onLanguage;
  final ValueChanged<String> onTheme;
  @override
  State<TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends State<TvHome> {
  int page = 0;
  bool busy = false;
  Map<String, dynamic> status = {};
  Map<String, dynamic> dashboard = {};
  String? error;
  Timer? brightnessTimer, mediaTimer, systemTimer, alarmTimer;

  String t(String key) => tr(key, widget.language);
  bool get permitted => status['permissionGranted'] == true;
  bool get running => status['running'] == true;
  bool get connected => status['serviceConnected'] == true;
  int val(String key, [int fallback = 0]) => (dashboard[key] as num?)?.round() ?? fallback;
  int get brightness => val('brightness', 50);
  int get media => val('mediaVolume', 40);
  int get systemVolume => val('systemVolume', 40);
  int get alarmVolume => val('alarmVolume', 40);
  int get timeoutMs => val('timeoutMs', 600000);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void dispose() {
    brightnessTimer?.cancel();
    mediaTimer?.cancel();
    systemTimer?.cancel();
    alarmTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    if (mounted) setState(() => busy = true);
    try {
      status = await nativeMap('checkStatus');
      error = null;
      if (permitted) {
        dashboard = await nativeMap('readDashboard');
        status = await nativeMap('checkStatus');
      }
    } on PlatformException catch (e) {
      error = e.message ?? e.code;
    } catch (e) { error = e.toString(); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> connect() async {
    setState(() { busy = true; error = null; });
    try {
      status = await nativeMap('requestShizukuPermission');
      if (permitted && connected) {
        dashboard = await nativeMap('readDashboard');
        status = await nativeMap('checkStatus');
      } else if (!running || !permitted) {
        error = t('startShizuku');
      } else {
        error = status['serviceFailure'] as String? ?? t('serviceUnavailable');
      }
    } on PlatformException catch (e) { error = e.message ?? e.code; }
    catch (e) { error = e.toString(); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> setBrightness(int value) async {
    try {
      await nativeVoid('setBrightness', {'value': value});
      if (mounted) setState(() { dashboard['brightness'] = value; error = null; });
    } on PlatformException catch (e) { if (mounted) setState(() => error = e.message ?? e.code); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
  }

  Future<void> setVolume(int stream, int value) async {
    try {
      await nativeVoid('setVolume', {'stream': stream, 'value': value});
      if (!mounted) return;
      setState(() {
        if (stream == 3) dashboard['mediaVolume'] = value;
        if (stream == 1) dashboard['systemVolume'] = value;
        if (stream == 4) dashboard['alarmVolume'] = value;
        error = null;
      });
    } on PlatformException catch (e) { if (mounted) setState(() => error = e.message ?? e.code); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
  }

  Future<void> applyPreset(String preset) async {
    final values = switch (preset) {
      'cinema' => (35, 45, 35),
      'night' => (20, 25, 20),
      _ => (65, 60, 45),
    };
    setState(() { busy = true; error = null; });
    try {
      await nativeVoid('setBrightness', {'value': values.$1});
      await nativeVoid('setVolume', {'stream': 3, 'value': values.$2});
      await nativeVoid('setVolume', {'stream': 1, 'value': values.$3});
      dashboard = await nativeMap('readDashboard');
    } on PlatformException catch (e) { error = e.message ?? e.code; }
    catch (e) { error = e.toString(); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> setTimeout(int value) async {
    try {
      await nativeVoid('setScreenTimeout', {'value': value});
      if (mounted) setState(() { dashboard['timeoutMs'] = value; error = null; });
    } on PlatformException catch (e) { if (mounted) setState(() => error = e.message ?? e.code); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(child: Row(children: [
        Container(
          width: 190,
          decoration: BoxDecoration(border: BorderDirectional(end: BorderSide(color: theme.dividerColor))),
          child: Column(children: [
            const SizedBox(height: 22),
            Icon(Icons.tv_rounded, size: 44, color: theme.colorScheme.primary),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(t('app'), textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 18),
            nav(0, Icons.tune_rounded, t('home')),
            nav(1, Icons.settings_rounded, t('settings')),
            nav(2, Icons.info_outline_rounded, t('device')),
            const Spacer(),
            Padding(padding: const EdgeInsets.all(12), child: Text(t('help'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall)),
          ]),
        ),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: page == 0 ? controls() : page == 1 ? settingsPage() : devicePage(),
        )),
      ])),
    );
  }

  Widget nav(int index, IconData icon, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: SizedBox(
      width: double.infinity, height: 58,
      child: FilledButton.tonalIcon(
        autofocus: index == 0,
        onPressed: () => setState(() => page = index),
        icon: Icon(icon), label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: page == index ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
          foregroundColor: page == index ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    ),
  );

  Widget controls() => SingleChildScrollView(
    key: const ValueKey('controls'),
    padding: const EdgeInsets.fromLTRB(28, 24, 30, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('welcome'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5), Text(t('subtitle'), style: Theme.of(context).textTheme.bodyLarge),
        ])),
        statusPill(),
        const SizedBox(width: 8),
        IconButton.filledTonal(onPressed: busy ? null : refresh, tooltip: t('refresh'), icon: const Icon(Icons.refresh_rounded)),
      ]),
      if (error != null) ...[const SizedBox(height: 14), errorPanel(error!)],
      const SizedBox(height: 20),
      if (!permitted || !connected)
        connectPanel()
      else ...[
        LayoutBuilder(builder: (context, constraints) {
          final cards = <Widget>[
            sliderPanel(t('brightness'), t('brightnessHint'), Icons.brightness_6_rounded, brightness, (v) {
              setState(() => dashboard['brightness'] = v);
              brightnessTimer?.cancel();
              brightnessTimer = Timer(const Duration(milliseconds: 180), () => setBrightness(v));
            }),
            sliderPanel(t('media'), t('sound'), Icons.volume_up_rounded, media, (v) {
              setState(() => dashboard['mediaVolume'] = v);
              mediaTimer?.cancel();
              mediaTimer = Timer(const Duration(milliseconds: 180), () => setVolume(3, v));
            }),
            sliderPanel(t('systemSound'), t('systemSound'), Icons.notifications_active_outlined, systemVolume, (v) {
              setState(() => dashboard['systemVolume'] = v);
              systemTimer?.cancel();
              systemTimer = Timer(const Duration(milliseconds: 180), () => setVolume(1, v));
            }),
            sliderPanel(t('alarm'), t('sound'), Icons.alarm_rounded, alarmVolume, (v) {
              setState(() => dashboard['alarmVolume'] = v);
              alarmTimer?.cancel();
              alarmTimer = Timer(const Duration(milliseconds: 180), () => setVolume(4, v));
            }),
          ];
          final wide = constraints.maxWidth > 1050;
          if (wide) return Wrap(spacing: 14, runSpacing: 14, children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 42) / 3, child: c)).toList());
          return Wrap(spacing: 12, runSpacing: 12, children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c)).toList());
        }),
        const SizedBox(height: 20),
        Text(t('presets'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          preset('cinema', Icons.movie_filter_rounded, t('cinema'), t('cinemaHint')),
          preset('standard', Icons.tv_rounded, t('standard'), t('standardHint')),
          preset('night', Icons.dark_mode_rounded, t('night'), t('nightHint')),
        ]),
        const SizedBox(height: 20),
        timeoutPanel(),
        const SizedBox(height: 14),
        Text(t('help'), style: Theme.of(context).textTheme.bodySmall),
      ],
    ]),
  );

  Widget statusPill() {
    final color = connected ? Colors.green : Colors.orange;
    final label = connected
        ? t('connected')
        : (!running ? t('notConnected') : (!permitted ? t('needsPermission') : t('serviceUnavailable')));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, color: color, size: 10),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ]),
    );
  }

  Widget connectPanel() => panel(Row(children: [
    Icon(Icons.admin_panel_settings_outlined, size: 44, color: Theme.of(context).colorScheme.primary),
    const SizedBox(width: 16),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('connect'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(!running || !permitted ? t('startShizuku') : t('serviceUnavailable')),
    ])),
    const SizedBox(width: 12),
    FilledButton.icon(
      autofocus: true,
      onPressed: busy ? null : connect,
      icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link_rounded),
      label: Text(t('connect')),
    ),
  ]));

  Widget sliderPanel(String title, String subtitle, IconData icon, int value, ValueChanged<int> changed) => panel(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [Icon(icon, size: 27), const SizedBox(width: 10), Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)))]),
      const SizedBox(height: 7),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.remove_rounded, size: 18),
        Expanded(child: Slider(value: value.clamp(0, 100).toDouble(), min: 0, max: 100, divisions: 100, label: value.toString() + '%', onChanged: (v) => changed(v.round()))),
        const Icon(Icons.add_rounded, size: 18),
      ]),
      Align(alignment: AlignmentDirectional.centerEnd, child: Text(value.toString() + '%')),
    ],
  ));

  Widget preset(String key, IconData icon, String title, String subtitle) => SizedBox(
    width: 255, height: 88,
    child: OutlinedButton(
      onPressed: busy ? null : () => applyPreset(key),
      style: OutlinedButton.styleFrom(alignment: AlignmentDirectional.centerStart, padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      child: Row(children: [
        Icon(icon, size: 30), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]),
    ),
  );

  Widget timeoutPanel() {
    const values = <int>[60000, 300000, 900000, 1800000, 3600000];
    const keys = <String>['one', 'five', 'fifteen', 'thirty', 'sixty'];
    final selected = values.contains(timeoutMs) ? timeoutMs : 600000;
    return panel(Row(children: [
      const Icon(Icons.timer_outlined, size: 30), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('timeout'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), Text(t('timeoutHint'), style: Theme.of(context).textTheme.bodySmall),
      ])),
      const SizedBox(width: 12),
      DropdownButton<int>(
        value: selected,
        items: List.generate(values.length, (i) => DropdownMenuItem<int>(value: values[i], child: Text(t(keys[i])))),
        onChanged: busy ? null : (v) { if (v != null) setTimeout(v); },
      ),
    ]));
  }

  Widget settingsPage() {
    final themes = <(String, String, IconData)>[
      ('pureBlack', t('pureBlack'), Icons.contrast_rounded),
      ('white', t('white'), Icons.light_mode_outlined),
      ('cozy', t('cozy'), Icons.local_cafe_outlined),
      ('materialYou', t('materialYou'), Icons.palette_outlined),
    ];
    return SingleChildScrollView(
      key: const ValueKey('settings'),
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('settings'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 22),
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('language'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, children: [
            choice(t('english'), widget.language == 'en', () => widget.onLanguage('en')),
            choice(t('arabic'), widget.language == 'ar', () => widget.onLanguage('ar')),
          ]),
        ])),
        const SizedBox(height: 16),
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('appearance'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: themes.map((item) => SizedBox(
            width: 220, height: 70,
            child: OutlinedButton.icon(
              onPressed: () => widget.onTheme(item.$1),
              icon: Icon(item.$3), label: Text(item.$2),
              style: OutlinedButton.styleFrom(backgroundColor: widget.themeKey == item.$1 ? Theme.of(context).colorScheme.primaryContainer : null),
            ),
          )).toList()),
        ])),
        const SizedBox(height: 16),
        panel(Row(children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Text(t('connect'), style: Theme.of(context).textTheme.titleMedium)),
          FilledButton.tonal(onPressed: busy ? null : connect, child: Text(t('connect'))),
        ])),
      ]),
    );
  }

  Widget choice(String label, bool selected, VoidCallback onPressed) => SizedBox(
    height: 56,
    child: FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: selected ? Theme.of(context).colorScheme.primaryContainer : null, padding: const EdgeInsets.symmetric(horizontal: 22)),
      child: Text(label),
    ),
  );

  Widget devicePage() {
    final info = <(String, String, IconData)>[
      ('model', dashboard['device']?.toString() ?? status['model']?.toString() ?? '—', Icons.tv_rounded),
      ('android', status['androidVersion']?.toString() ?? '—', Icons.android_rounded),
      ('api', status['api']?.toString() ?? '—', Icons.code_rounded),
      ('uid', status['uid']?.toString() ?? '—', Icons.verified_user_outlined),
      ('service', connected ? t('available') : t('unavailable'), Icons.settings_ethernet_rounded),
    ];
    return SingleChildScrollView(
      key: const ValueKey('device'),
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('device'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 22),
        panel(Column(children: info.map((i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(i.$3, size: 25), const SizedBox(width: 14),
            Expanded(child: Text(t(i.$1), style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(width: 18),
            Flexible(child: Text(i.$2, textAlign: TextAlign.end)),
          ]),
        )).toList())),
        const SizedBox(height: 16),
        panel(Row(children: [
          const Icon(Icons.info_outline_rounded, size: 28), const SizedBox(width: 12),
          Expanded(child: Text(t('aboutHint'))),
          OutlinedButton.icon(onPressed: busy ? null : refresh, icon: const Icon(Icons.refresh_rounded), label: Text(t('refresh'))),
        ])),
        if (error != null) ...[const SizedBox(height: 14), errorPanel(error!)],
      ]),
    );
  }

  Widget panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: child,
  );

  Widget errorPanel(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25),
      border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
      const SizedBox(width: 10),
      Expanded(child: Text(t('failed') + ': ' + message)),
      TextButton(onPressed: refresh, child: Text(t('retry'))),
    ]),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HyoukaTvControlApp());
}
