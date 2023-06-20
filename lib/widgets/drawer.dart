import 'package:flutter/material.dart';
import 'package:notes/utils/build_context.dart';

import '../pages/labels.dart';
import '../pages/settings.dart';
import '../pages/home.dart';
import '../pages/archive.dart';
import '../pages/trash.dart';

class NavigationDrawerWidget extends StatelessWidget {
    const NavigationDrawerWidget({super.key, required this.selectedIndex, required this.onLabelChanged});

    final int selectedIndex;
    final VoidCallback onLabelChanged;

    @override
    Widget build(BuildContext context) {
        const List<List<dynamic>> mainRoutes = [
            ["Notes", Icons.sticky_note_2_outlined],
            ["Archive", Icons.archive_outlined],
            ["Trash", Icons.delete_outlined],
        ];
        final ColorScheme colorScheme = context.colorScheme;
        final TextTheme textTheme = context.textTheme;

        Widget header = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Text('Notes', style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.5,
                fontFamily: 'Plus Jakarta Sans'
            )),
        );

        List<Widget> children = <Widget>[
            const SizedBox(height: 28),
            header,
            const SizedBox(height: 16),
            ...mainRoutes.map<NavigationDrawerDestination>((nav) => NavigationDrawerDestination(
                icon: Icon(nav[1]),
                label: Text(nav[0])
            )).toList(),
            const Divider(endIndent: 28, indent: 28),
            const NavigationDrawerDestination(
                icon: Icon(Icons.label_outlined),
                label: Text('Labels')
            ),
            const Divider(endIndent: 28, indent: 28),
            const NavigationDrawerDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('Settings')
            ),
            const SizedBox(height: 16),
        ];

        return SafeArea(top: false, child: NavigationDrawer(
            selectedIndex: selectedIndex,
            children: children,
            onDestinationSelected: (index){

                if (!context.isBigScreen) context.navigateBack();
                if (index == selectedIndex) return;

                switch (index){
                    case 0: context.navigate(builder: (context) => const HomePage(), replace: true);
                    case 1: context.navigate(builder: (context) => const ArchivePage(), replace: true);
                    case 2: context.navigate(builder: (context) => const TrashPage(), replace: true);
                    case 3:
                        context.navigate(builder: (context) => const LabelsPage());
                        onLabelChanged();
                    case 4: context.navigate(builder: (context) => const SettingsPage());
                }
            },
        ));
    }
}