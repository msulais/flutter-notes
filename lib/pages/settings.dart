import 'package:flutter/material.dart';
import 'package:notes/utils/build_context.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/string.dart';
import '../utils/color.dart';

class SettingsPage extends StatefulWidget {
    const SettingsPage({super.key});

    @override
    State<SettingsPage> createState() => _SettingsPageState();
} class _SettingsPageState extends State<SettingsPage> {

    void _showAboutApp() async {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();

        if (!mounted) return;

        showAboutDialog(
            context: context,
            applicationIcon: Image.asset('assets/images/icon-768x768.png', height: 48, filterQuality: FilterQuality.high),
            applicationName: 'Notes',
            applicationVersion: packageInfo.version,
            applicationLegalese: '©${DateTime.now().year} Redmerah'
        );
    }

    void _rateApp() async {
        Uri appUrl = Uri(
            scheme: 'https',
            host: 'play.google.com',
            path: 'store/apps/details',
            queryParameters: {'id': 'com.redmerah.notes'}
        );
        if (await canLaunchUrl(appUrl)) await launchUrl(appUrl, mode: LaunchMode.externalApplication);
    }

    void _sendFeedback() async {
        Uri email = Uri(scheme: 'mailto', path: 'daundua2@gmail.com');
        if (await canLaunchUrl(email)) await launchUrl(email);
    }

    void _changeTheme() {
        const List<List<dynamic>> options = [
            ['System', ThemeMode.system],
            ['Light' , ThemeMode.light ],
            ['Dark'  , ThemeMode.dark  ]
        ];

        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                scrollable: true,
                icon: const Icon(Icons.brightness_4_outlined),
                title: const Text('Theme'),
                actions: [
                    TextButton(child: const Text('Close'), onPressed: () => context.navigateBack())
                ],
                content: Material(
                    color: Colors.transparent,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(options.length, (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: RadioListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(
                                    topLeft    : Radius.circular(index == 0? 12 : 0),
                                    topRight   : Radius.circular(index == 0? 12 : 0),
                                    bottomLeft : Radius.circular(index == options.length-1? 12 : 0),
                                    bottomRight: Radius.circular(index == options.length-1? 12 : 0),
                                )),
                                tileColor: context.colorScheme.secondaryContainer,
                                title: Text(options[index][0], style: TextStyle(color: context.colorScheme.onSecondaryContainer)),
                                value: options[index][1],
                                groupValue: context.settings(true).theme,
                                onChanged: (value){
                                    context.settings().theme = value;
                                    context.changeSystemUI();
                                }
                            ),
                        ))
                    ),
                )
            )
        );
    }

    void _changeColor(){
        const List options = [
            ['Pink'       , Colors.pink      ],
            ['Red'        , Colors.red       ],
            ['Deep orange', Colors.deepOrange],
            ['Orange'     , Colors.orange    ],
            ['Amber'      , Colors.amber     ],
            ['Yellow'     , Colors.yellow    ],
            ['Lime'       , Colors.lime      ],
            ['Light green', Colors.lightGreen],
            ['Green'      , Colors.green     ],
            ['Teal'       , Colors.teal      ],
            ['Cyan'       , Colors.cyan      ],
            ['Light blue' , Colors.lightBlue ],
            ['Blue'       , Colors.blue      ],
            ['Indigo'     , Colors.indigo    ],
            ['Deep purple', Colors.deepPurple],
            ['Purple'     , Colors.purple    ],
            ['Grey'       , Colors.grey      ],
            ['Blue grey'  , Colors.blueGrey  ],
            ['Brown'      , Colors.brown     ],
        ];

        var settings = context.settings();

        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                scrollable: true,
                icon: const Icon(Icons.palette_outlined),
                title: const Text('App color'),
                content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500.0),
                    child: Wrap(
                        spacing: 8.0,
                        alignment: WrapAlignment.spaceEvenly,
                        children: List.generate(options.length, (index){
                            bool selected = settings.color.value == options[index][1].value;
                            return IconButton(
                                tooltip: options[index][0],
                                onPressed: (){
                                    settings.color = options[index][1];
                                    context.changeSystemUI();
                                },
                                icon: Container(
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: options[index][1],
                                    ),
                                    width: 40,
                                    height: 40,
                                    child: selected? Icon(Icons.done_outlined, color: (options[index][1] as Color).contrastColor) : null,
                                )
                            );
                        })
                    ),
                ),
                actions: [
                    TextButton(onPressed: () => context.navigateBack(), child: const Text('Close'))
                ],
            )
        );
    }

    Widget _appBar() {
        Widget title = const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.w600, fontFamily: "Plus Jakarta Sans")
        );

        Widget leading = IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.navigateBack()
        );

        Widget appBar = SliverAppBar.large(
            leadingWidth: 56.0,
            title: title,
            leading: leading,
        );

        if (context.isBigScreen) {
            appBar = SliverAppBar(
                leadingWidth: 56.0,
                title: title,
                leading: leading,
                pinned: true,
            );
        }

        return appBar;
    }

    Widget _body() {
        var settings = context.settings(true);
        var colorScheme = context.colorScheme;

        List<Widget> general = [
            ListTile(
                leading: const Icon(Icons.brightness_4_outlined),
                title: const Text('Theme'),
                subtitle: Text(
                    settings.theme.name.titleCase(),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                onTap: _changeTheme,
            ),
            ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('App color'),
                subtitle: Text(<List>[
                    ['Pink'       , Colors.pink      ],
                    ['Red'        , Colors.red       ],
                    ['Deep orange', Colors.deepOrange],
                    ['Orange'     , Colors.orange    ],
                    ['Amber'      , Colors.amber     ],
                    ['Yellow'     , Colors.yellow    ],
                    ['Lime'       , Colors.lime      ],
                    ['Light green', Colors.lightGreen],
                    ['Green'      , Colors.green     ],
                    ['Teal'       , Colors.teal      ],
                    ['Cyan'       , Colors.cyan      ],
                    ['Light blue' , Colors.lightBlue ],
                    ['Blue'       , Colors.blue      ],
                    ['Indigo'     , Colors.indigo    ],
                    ['Deep purple', Colors.deepPurple],
                    ['Purple'     , Colors.purple    ],
                    ['Grey'       , Colors.grey      ],
                    ['Blue grey'  , Colors.blueGrey  ],
                    ['Brown'      , Colors.brown     ],
                ].firstWhere((element) => element[1].value == settings.color.value)[0]),
                trailing: SizedBox(
                    width: 32,
                    height: 32,
                    child: Card(color: settings.color),
                ),
                onTap: _changeColor,
            ),
        ];

        List<Widget> others = List.generate(3, (index) {
            List options = [
                ['Rate & review app', Icons.star_outline, _rateApp],
                ['About', Icons.info_outline_rounded, _showAboutApp],
                ['Send feedback', Icons.chat_outlined, _sendFeedback],
            ];
            return ListTile(
                leading: Icon(options[index][1]),
                title: Text(options[index][0]),
                onTap: options[index][2],
            );
        });

        Widget body = SliverList(delegate: SliverChildListDelegate([
            ...general,
            const Divider(indent: 16, endIndent: 16),
            ...others
        ]));

        if (context.isBigScreen){
            body = SliverList(delegate: SliverChildListDelegate([Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Flexible(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: ListTileTheme(
                        data: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: Column(children: [
                            ...general,
                            const Divider(indent: 16, endIndent: 16),
                            ...others
                        ]),
                    ),
                ))]
            )]));
        }

        body = CustomScrollView(slivers: [
            _appBar(),
            body
        ]);

        return SafeArea(
            top: false,
            child: body
        );
    }

    @override
    Widget build(BuildContext context){
        context.changeSystemUI();
        return Scaffold(body: _body());
    }
}