import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'pages/home.dart';
import 'data/settings.dart';
import 'utils/build_context.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();

    var settings = Settings();
    await settings.readFile();

    runApp(MultiProvider(
        providers: [
            ChangeNotifierProvider.value(value: settings),
        ],
        child: const MyApp(),
    ));
}

class MyApp extends StatefulWidget {
    const MyApp({super.key});

    @override
    State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {

    ThemeData _themeData(ColorScheme colorScheme){
        return ThemeData(
            colorScheme: colorScheme,
            useMaterial3: true,
            snackBarTheme: const SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
            ),
            appBarTheme: AppBarTheme(titleTextStyle: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontFamily: 'Plus Jakarta Sans'
            )),
            dialogTheme: DialogTheme(titleTextStyle: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontFamily: 'Plus Jakarta Sans'
            )),
        );
    }

    @override
    void initState(){
        super.initState();
        WidgetsBinding.instance.addObserver(this);
    }

    @override
    void didChangeAppLifecycleState(AppLifecycleState state) async {
        if (state == AppLifecycleState.resumed) {
            context.changeSystemUI();
            setState((){});
        }
    }

    @override
    void dispose(){
        WidgetsBinding.instance.removeObserver(this);
        super.dispose();
    }

    @override
    Widget build(BuildContext context){
        final Settings settings = context.settings(true);
        ColorScheme lightColorScheme = ColorScheme.fromSeed(
            seedColor: settings.color,
            brightness: Brightness.light
        );
        ColorScheme darkColorScheme = ColorScheme.fromSeed(
            seedColor: settings.color,
            brightness: Brightness.dark
        );

        context.changeSystemUI();

        return MaterialApp(
            title: 'Notes',
            debugShowCheckedModeBanner: false,
            themeMode: settings.theme,
            theme: _themeData(lightColorScheme),
            darkTheme: _themeData(darkColorScheme),
            home: const HomePage(),
        );
    }
}