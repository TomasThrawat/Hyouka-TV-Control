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
  'phoneRemote': {'en':'Hyouka Remote','ar':'ريموت Hyouka'},
  'phoneRemoteHint': {'en':'Connect once, then use the keyboard icon whenever a TV text field is open.','ar':'اربط التلفزيون مرة واحدة، وبعدها استخدم أيقونة الكيبورد وقت ما تفتح خانة كتابة على التلفزيون.'},
  'findTv': {'en':'Find my TV','ar':'البحث عن التلفزيون'},
  'searchingTvs': {'en':'Looking for TVs on this Wi-Fi…','ar':'بدور على تلفزيونات على نفس شبكة Wi-Fi…'},
  'noTvsFound': {'en':'No Hyouka TV found. Make sure the TV app is open and both devices use the same Wi-Fi.','ar':'مش لاقي تلفزيون Hyouka. افتح التطبيق على التلفزيون واتأكد إن الجهازين على نفس شبكة Wi-Fi.'},
  'pairTv': {'en':'Pair TV once','ar':'ربط التلفزيون مرة واحدة'},
  'pairTvPrompt': {'en':'Enter the six-digit code shown on the TV. You only need to do this once.','ar':'اكتب الرمز المكوّن من 6 أرقام الظاهر على التلفزيون. هتعمل الخطوة دي مرة واحدة بس.'},
  'pairing': {'en':'Pairing…','ar':'جاري الربط…'},
  'pairedWith': {'en':'Connected to','ar':'متصل بـ'},
  'notPaired': {'en':'No TV paired yet','ar':'لسه مفيش تلفزيون مربوط'},
  'keyboardAction': {'en':'Keyboard','ar':'كيبورد'},
  'typeOnTv': {'en':'Type on TV','ar':'اكتب على التلفزيون'},
  'typeHint': {'en':'Type here. Text appears in the focused TV text field as you type.','ar':'اكتب هنا، والنص هيظهر في خانة الكتابة المحددة على التلفزيون أثناء الكتابة.'},
  'done': {'en':'Done','ar':'تم'},
  'cancel': {'en':'Cancel','ar':'إلغاء'},
  'refreshDevices': {'en':'Find TVs','ar':'بحث عن تلفزيون'},
  'forgetTv': {'en':'Disconnect TV','ar':'فصل التلفزيون'},
  'keyboardSetupTv': {'en':'On the TV, select Hyouka Remote Keyboard once in the keyboard picker.','ar':'على التلفزيون، اختار Hyouka Remote Keyboard مرة واحدة من قائمة لوحات المفاتيح.'},
  'tvPairCodeHint': {'en':'Enter this code once in Hyouka Remote on your phone. After pairing, use the keyboard icon on the phone.','ar':'اكتب الرمز ده مرة واحدة في تطبيق Hyouka Remote على الموبايل. بعد الربط استخدم أيقونة الكيبورد على الموبايل.'},
  'textFieldNeeded': {'en':'Open a text field on the TV first.','ar':'افتح خانة كتابة على التلفزيون الأول.'},
  'keyboard': {'en':'Phone keyboard','ar':'كيبورد الموبايل'},
  'keyboardTitle': {'en':'Type on your TV from your phone','ar':'اكتب على التلفزيون من موبايلك'},
  'keyboardSubtitle': {'en':'Pair once in the phone app. After that, tap its keyboard icon whenever a TV text field is open.','ar':'اربط من تطبيق الموبايل مرة واحدة. بعد كده اضغط أيقونة الكيبورد وقت ما تفتح خانة كتابة على التلفزيون.'},
  'chooseKeyboard': {'en':'Choose Hyouka keyboard','ar':'اختيار كيبورد Hyouka'},
  'keyboardEnableHint': {'en':'Select Hyouka Remote Keyboard in the system keyboard picker.','ar':'اختار Hyouka Remote Keyboard من قائمة لوحات المفاتيح.'},
  'keyboardPickHint': {'en':'Choose Hyouka Remote Keyboard in the picker to receive text.','ar':'اختار Hyouka Remote Keyboard من القائمة لاستقبال النص.'},
  'keyboardSelected': {'en':'Hyouka Remote Keyboard is selected.','ar':'كيبورد Hyouka هو لوحة المفاتيح المختارة.'},
  'startPhoneKeyboard': {'en':'Start phone keyboard','ar':'تشغيل كيبورد الموبايل'},
  'stopPhoneKeyboard': {'en':'Stop sharing','ar':'إيقاف المشاركة'},
  'phoneAddress': {'en':'Open this address on your phone','ar':'افتح العنوان ده على موبايلك'},
  'pairingCode': {'en':'Pairing code','ar':'رمز الاقتران'},
  'keyboardHint': {'en':'Keep a text field focused on the TV. Open the address on your phone, enter the code, type, then tap Send. Both devices must be on the same Wi-Fi network.','ar':'سيب خانة الكتابة مفتوحة ومحددة على التلفزيون. افتح العنوان من موبايلك، واكتب رمز الاقتران، وبعدها اكتب واضغط إرسال. لازم الجهازين يكونوا على نفس شبكة Wi-Fi.'},
  'keyboardStarting': {'en':'Starting the local keyboard server…','ar':'جاري تشغيل خادم الكيبورد المحلي…'},
  'keyboardRunning': {'en':'Waiting for your phone…','ar':'في انتظار اتصال الموبايل…'},
  'keyboardNotRunning': {'en':'Phone keyboard is stopped.','ar':'كيبورد الموبايل متوقف.'},
  'keyboardNoAddress': {'en':'No local network address found. Connect the TV to Wi-Fi or Ethernet.','ar':'مش لاقي عنوان شبكة محلية. وصّل التلفزيون بالـ Wi-Fi أو Ethernet.'},
  'keyboardNotConnected': {'en':'The TV input method is not active. Select Hyouka Remote Keyboard first.','ar':'لوحة إدخال Hyouka مش نشطة. اختارها الأول من قائمة لوحات المفاتيح.'},
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
  bool? isTelevision;

  @override
  void initState() {
    super.initState();
    _load();
    _detectDeviceMode();
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

  Future<void> _detectDeviceMode() async {
    try {
      final result = await native.invokeMethod<bool>('isTelevision');
      if (mounted) setState(() => isTelevision = result ?? false);
    } catch (_) {
      if (mounted) setState(() => isTelevision = false);
    }
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
      child: isTelevision == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : isTelevision!
              ? TvHome(
                  language: language,
                  themeKey: themeKey,
                  onLanguage: (value) { setState(() => language = value); _save(); },
                  onTheme: (value) { setState(() => themeKey = value); _save(); },
                )
              : PhoneRemoteHome(language: language, themeKey: themeKey),
    ),
  );
}


class PhoneRemoteHome extends StatefulWidget {
  const PhoneRemoteHome({required this.language, required this.themeKey, super.key});
  final String language;
  final String themeKey;

  @override
  State<PhoneRemoteHome> createState() => _PhoneRemoteHomeState();
}

class _PhoneRemoteHomeState extends State<PhoneRemoteHome> {
  Map<String, dynamic> paired = {};
  List<Map<String, dynamic>> devices = [];
  bool busy = true;
  bool searching = false;
  String? error;

  String t(String key) => tr(key, widget.language);
  bool get isPaired => paired['paired'] == true;

  @override
  void initState() {
    super.initState();
    _loadRemote();
  }

  Future<void> _loadRemote() async {
    try {
      paired = await nativeMap('phoneRemoteStatus');
      if (mounted) setState(() => busy = false);
      await _discover();
    } catch (e) {
      if (mounted) setState(() { busy = false; error = e.toString(); });
    }
  }

  Future<void> _discover() async {
    if (mounted) setState(() { searching = true; error = null; });
    try {
      final raw = await native.invokeListMethod<dynamic>('discoverRemoteTvs') ?? [];
      final found = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() => devices = found);

      if (isPaired) {
        final savedTvId = paired['tvId']?.toString();
        for (final device in found) {
          if (device['tvId']?.toString() == savedTvId) {
            await native.invokeMethod<bool>('updateRemoteTvAddress', {
              'host': device['host'],
              'port': device['port'],
              'tvId': device['tvId'],
            });
            paired = await nativeMap('phoneRemoteStatus');
            break;
          }
        }
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> _pair(Map<String, dynamic> device) async {
    final pinController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('pairTv')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t('pairTvPrompt')),
          const SizedBox(height: 14),
          TextField(
            controller: pinController,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t('cancel'))),
          FilledButton(
            onPressed: () {
              final value = pinController.text.trim();
              if (RegExp(r'^d{6}$').hasMatch(value)) Navigator.pop(dialogContext, value);
            },
            child: Text(t('pairTv')),
          ),
        ],
      ),
    );
    pinController.dispose();
    if (pin == null) return;

    setState(() { busy = true; error = null; });
    try {
      paired = await nativeMap('pairRemoteTv', {
        'host': device['host'],
        'port': device['port'],
        'tvId': device['tvId'],
        'name': device['name'],
        'pin': pin,
      });
      if (!mounted) return;
      setState(() { busy = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("\u0024{t('pairedWith')} \u0024{paired['name']?.toString() ?? t('app')}")));
    } on PlatformException catch (e) {
      if (mounted) setState(() { busy = false; error = e.message ?? e.code; });
    } catch (e) {
      if (mounted) setState(() { busy = false; error = e.toString(); });
    }
  }

  Future<void> _forgetTv() async {
    await native.invokeMethod<bool>('forgetRemoteTv');
    if (!mounted) return;
    setState(() { paired = {'paired': false}; });
    await _discover();
  }

  Future<void> _openKeyboard() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => PhoneKeyboardSheet(language: widget.language),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('phoneRemote'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: t('refreshDevices'),
            onPressed: searching ? null : _discover,
            icon: searching
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
          if (isPaired)
            IconButton(
              tooltip: t('forgetTv'),
              onPressed: _forgetTv,
              icon: const Icon(Icons.link_off_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isPaired
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(Icons.tv_rounded, size: 46, color: theme.colorScheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 20),
                        Text(t('pairedWith'), style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          paired['name']?.toString() ?? 'Hyouka TV',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Text(t('phoneRemoteHint'), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed: _openKeyboard,
                          icon: const Icon(Icons.keyboard_rounded, size: 24),
                          label: Text(t('keyboardAction')),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(60),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        Icon(Icons.tv_rounded, size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(t('notPaired'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(t('phoneRemoteHint'), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 24),
                        if (error != null) errorPanel(context, error!),
                        if (searching || busy)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (devices.isEmpty)
                          Text(t('noTvsFound'), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)
                        else ...[
                          Text(t('findTv'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          ...devices.map((device) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.tv_rounded),
                              title: Text(device['name']?.toString() ?? 'Hyouka TV'),
                              subtitle: Text(t('pairTvPrompt')),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _pair(device),
                            ),
                          )),
                        ],
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: searching ? null : _discover,
                          icon: const Icon(Icons.search_rounded),
                          label: Text(t('findTv')),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget errorPanel(BuildContext context, String message) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );
}

class PhoneKeyboardSheet extends StatefulWidget {
  const PhoneKeyboardSheet({required this.language, super.key});
  final String language;

  @override
  State<PhoneKeyboardSheet> createState() => _PhoneKeyboardSheetState();
}

class _PhoneKeyboardSheetState extends State<PhoneKeyboardSheet> {
  final TextEditingController controller = TextEditingController();
  Timer? sendTimer;
  String? error;
  bool finishing = false;

  String t(String key) => tr(key, widget.language);

  void _queueText(String value) {
    sendTimer?.cancel();
    sendTimer = Timer(const Duration(milliseconds: 70), () async {
      try {
        await native.invokeMethod<bool>('sendRemoteComposition', {'text': value});
        if (mounted) setState(() => error = null);
      } on PlatformException catch (e) {
        if (mounted) setState(() => error = e.message ?? e.code);
      } catch (e) {
        if (mounted) setState(() => error = e.toString());
      }
    });
  }

  Future<void> _finish() async {
    if (finishing) return;
    finishing = true;
    sendTimer?.cancel();
    try {
      await native.invokeMethod<bool>('finishRemoteComposition');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    sendTimer?.cancel();
    unawaited(native.invokeMethod<bool>('finishRemoteComposition').then<void>((_) {}));
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset > 0 ? 8 : 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(t('typeOnTv'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            IconButton(onPressed: _finish, icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 8),
          Text(t('typeHint'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onChanged: _queueText,
            onSubmitted: (_) => _finish(),
            decoration: InputDecoration(
              hintText: t('typeOnTv'),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(onPressed: _finish, icon: const Icon(Icons.send_rounded)),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: _finish, child: Text(t('done'))),
          ),
        ],
      ),
    );
  }
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
  Map<String, dynamic> keyboardStatus = {};
  bool keyboardBusy = false;
  Timer? keyboardPollTimer;

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
    WidgetsBinding.instance.addPostFrameCallback((_) { refresh(); _ensureRemoteKeyboardServer(); });
  }

  @override
  void dispose() {
    brightnessTimer?.cancel();
    mediaTimer?.cancel();
    systemTimer?.cancel();
    alarmTimer?.cancel();
    keyboardPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureRemoteKeyboardServer() async {
    try {
      keyboardStatus = await nativeMap('ensureRemoteKeyboardServer');
      if (mounted) setState(() {});
      _pollKeyboardStatus();
    } on PlatformException catch (e) {
      if (mounted) setState(() => keyboardStatus = {'error': e.message ?? e.code});
    } catch (e) {
      if (mounted) setState(() => keyboardStatus = {'error': e.toString()});
    }
  }

  Future<void> refreshKeyboardStatus() async {
    try {
      final next = await nativeMap('remoteKeyboardStatus');
      if (mounted) setState(() => keyboardStatus = next);
    } catch (e) {
      if (mounted) setState(() => keyboardStatus = {'error': e.toString()});
    }
  }

  void _pollKeyboardStatus() {
    keyboardPollTimer?.cancel();
    keyboardPollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) { timer.cancel(); return; }
      try {
        final next = await nativeMap('remoteKeyboardStatus');
        if (!mounted) { timer.cancel(); return; }
        setState(() => keyboardStatus = next);
        if (next['running'] == true || next['error'] != null) {
          timer.cancel();
          keyboardPollTimer = null;
        }
      } catch (e) {
        if (mounted) setState(() => keyboardStatus = {'error': e.toString()});
        timer.cancel();
        keyboardPollTimer = null;
      }
    });
  }

  void _pollImeSelection() {
    keyboardPollTimer?.cancel();
    var checks = 0;
    keyboardPollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      checks += 1;
      if (!mounted) { timer.cancel(); return; }
      try {
        final next = await nativeMap('remoteKeyboardStatus');
        if (!mounted) { timer.cancel(); return; }
        setState(() => keyboardStatus = next);
        if (next['keyboardSelected'] == true || checks >= 15) {
          timer.cancel();
          keyboardPollTimer = null;
        }
      } catch (_) {
        timer.cancel();
        keyboardPollTimer = null;
      }
    });
  }

  Future<void> chooseKeyboard() async {
    setState(() => keyboardBusy = true);
    try {
      await native.invokeMethod<bool>('showKeyboardPicker');
      _pollImeSelection();
    } on PlatformException catch (e) {
      if (mounted) setState(() => keyboardStatus = {'error': e.message ?? e.code});
    } finally {
      if (mounted) setState(() => keyboardBusy = false);
    }
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
            nav(1, Icons.keyboard_rounded, t('keyboard')),
            nav(2, Icons.settings_rounded, t('settings')),
            nav(3, Icons.info_outline_rounded, t('device')),
            const Spacer(),
            Padding(padding: const EdgeInsets.all(12), child: Text(t('help'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall)),
          ]),
        ),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: page == 0 ? controls() : page == 1 ? keyboardPage() : page == 2 ? settingsPage() : devicePage(),
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
        onPressed: () { setState(() => page = index); if (index == 1) refreshKeyboardStatus(); },
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
        Expanded(child: Slider(value: value.clamp(0, 100).toDouble(), min: 0, max: 100, divisions: 100, label: '\u0024value%', onChanged: (v) => changed(v.round()))),
        const Icon(Icons.add_rounded, size: 18),
      ]),
      Align(alignment: AlignmentDirectional.centerEnd, child: Text('\u0024value%')),
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

  Widget keyboardPage() {
    final running = keyboardStatus['running'] == true;
    final enabled = keyboardStatus['keyboardEnabled'] == true;
    final selected = keyboardStatus['keyboardSelected'] == true;
    final pin = keyboardStatus['pin']?.toString();

    return SingleChildScrollView(
      key: const ValueKey('keyboard'),
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('keyboard'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(t('tvPairCodeHint'), style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.keyboard_rounded, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(
              selected ? t('keyboardSelected') : (enabled ? t('keyboardPickHint') : t('keyboardEnableHint')),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            )),
            Icon(Icons.circle, size: 11, color: running ? Colors.green : Colors.orange),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: keyboardBusy ? null : chooseKeyboard,
            icon: const Icon(Icons.settings_rounded),
            label: Text(t('chooseKeyboard')),
          ),
          if (keyboardStatus['error'] != null) ...[
            const SizedBox(height: 12),
            errorPanel(keyboardStatus['error'].toString()),
          ],
          if (pin != null && pin.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(t('pairingCode'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SelectableText(pin, style: Theme.of(context).textTheme.headlineLarge?.copyWith(letterSpacing: 9, fontWeight: FontWeight.w900)),
          ],
          const SizedBox(height: 18),
          Text(t('keyboardSetupTv'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(running ? t('keyboardRunning') : t('keyboardStarting'), style: Theme.of(context).textTheme.bodySmall),
        ])),
      ]),
    );
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
      Expanded(child: Text("\u0024{t('failed')}: \u0024message")),
      TextButton(onPressed: refresh, child: Text(t('retry'))),
    ]),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HyoukaTvControlApp());
}
