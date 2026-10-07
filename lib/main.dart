import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/i18n.dart';
import 'core/providers.dart';
import 'core/push.dart';
import 'core/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await AppLanguage.restore();

  late final Session session;
  final api = ApiClient(onUnauthorized: () => session.expire());
  session = Session(api);

  final push = PushService(api);
  await push.init();
  session
    ..onSignedIn = push.register
    ..beforeSignOut = push.unregister;
  session.restore();

  runApp(
    ProviderScope(
      overrides: [sessionProvider.overrideWithValue(session)],
      child: CustomerApp(session: session, push: push),
    ),
  );
}
