import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lionsmarket/msg_controller.dart';
import 'package:lionsmarket/webview_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void launchURL() async {
  const url = "lionsmarket://kr.sogeum.lionsmarket";
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw "Could not launch $url";
  }
}

Future<void> _requestLocationPermission() async {
  await Permission.location.request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Firebase 연동 시 필히 import
  await Firebase.initializeApp(); // Firebase State 초기화
  bool data = await fetchData();

  if (kDebugMode) {
    print(data);
  }

  await _requestLocationPermission();

  // Throw & Catch Exception
  runZonedGuarded(
        () async {
      runApp(MyApp());
    },
        (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack);
    },
  );

  await SystemChrome.setPreferredOrientations(
    [
      // 어플리케이션 화면 세로 고정
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light,
  );
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '라이온스마켓',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(),
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: analytics)],
      initialBinding: BindingsBuilder.put(
            () => MsgController(),
        permanent: true,
      ),
    );
  }
}

Future<bool> fetchData() async {
  bool data = false;

  await Future.delayed(const Duration(seconds: 3), () {
    data = true;
  });

  return data;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        scrollDirection: Axis.vertical,
        child: SizedBox(
          height: MediaQuery.of(context).size.height -
              MediaQuery.of(context).viewInsets.bottom,
          child: const WebviewController(),
        ),
      ),
    );
  }
}