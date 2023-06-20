// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../models/label.dart';
import '../utils/color.dart';
import '../utils/build_context.dart';

class LabelsPage extends StatefulWidget {
    const LabelsPage({super.key});

    @override
    State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {

    final List<NoteLabel> _labels = <NoteLabel>[];

    Future<NoteLabel> _addOrEditLabel(NoteLabel fromLabel) async {
        final ColorScheme colorScheme = context.colorScheme;
        String previousName = fromLabel.name;
        NoteLabel label = NoteLabel.from(fromLabel);

        Widget builder(BuildContext context){
            return StatefulBuilder(builder: (context, setState){
                Widget name = Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                    child: TextFormField(
                        initialValue: label.name,
                        autofocus: true,
                        onChanged: (value){ label.name = value.trim(); },
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            labelText: 'Label',
                            isDense: true,
                            hintText: previousName,
                            suffixIcon: IconButton(
                                onPressed: () => context.navigateBack(),
                                icon: const Icon(Icons.check_circle_outlined)
                            ),
                        ),
                    ),
                );

                Widget colors = SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(children: [
                            IconButton(
                                onPressed: () => setState(() => label.color = Colors.transparent),
                                icon: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(99999),
                                        color: Colors.transparent,
                                        border: Border.all(color: colorScheme.outline)
                                    ),
                                    child: Colors.transparent.value == label.color.value
                                        ? Icon(Icons.done, color: colorScheme.onBackground, size: 16.0)
                                        : null
                                )
                            ),
                            ...NoteLabel.colors.map<Widget>((color) => IconButton(
                                onPressed: () => setState(() => label.color = color),
                                icon: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(99999),
                                        color: color,
                                    ),
                                    child: color.value == label.color.value
                                        ? Icon(Icons.done, color: color.contrastColor, size: 16.0)
                                        : null
                                )
                            )).toList(),
                        ]),
                    )
                );

                return Padding(
                    padding: context.mediaQueryData.viewInsets,
                    child: SingleChildScrollView(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            name,
                            colors
                        ],
                    )),
                );
            });
        }

        await showModalBottomSheet(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: builder
        );

        return label;
    }

    void _addLabel() async {
        NoteLabel label = NoteLabel(id: -1, name: '', color: Colors.transparent);
        label = await _addOrEditLabel(label);

        if (label.name.isEmpty) return;

        setState((){
            _labels.add(label);
            _labels.sort((a, b) => a.name.compareTo(b.name));
        });
        label.insertDB();
    }

    void _getLabels() async {
        _labels.clear();
        List<NoteLabel> labels = (await NoteLabel.queryDB())..sort((a, b) => a.name.compareTo(b.name));
        setState((){
            _labels.addAll(labels);
        });
    }

    void _editLabel(NoteLabel label, int index) async {
        label = await _addOrEditLabel(label);

        setState((){
            if (label.name.isEmpty){
                _labels.removeAt(index);
                label.deleteDB();
            } else {
                _labels[index] = label;
                label.updateDB();
            }
            _labels.sort((a, b) => a.name.compareTo(b.name));
        });
    }

    void _deleteLabel(NoteLabel label, int index) async {
        await label.deleteDB();

        setState((){
            _labels.removeAt(index);
        });

        void undoLabel(){
            setState((){
                label.insertDB();
                _labels.add(label);
                _labels.sort((a, b) => a.name.compareTo(b.name));
            });
        }

        if (!mounted) return;

        context.showSnackBar(
            Text('Label "${label.name}" deleted'),
            action: SnackBarAction(
                label: "Undo",
                onPressed: undoLabel
            ),
        );
    }

    @override
    void initState(){
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_){
            _getLabels();
        });
    }

    Widget _appBar() {
        Widget leading = IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.navigateBack()
        );

        Widget title = const Text(
            'Labels',
            style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Plus Jakarta Sans')
        );

        Widget appBar = SliverAppBar.large(
            title: title,
            leading: leading,
        );

        if (context.isBigScreen){
            appBar = SliverAppBar(
                title: title,
                leading: leading,
                pinned: true,
            );
        }

        return appBar;
    }

    Widget _body(){
        final TextTheme textTheme = context.textTheme;
        final ColorScheme colorScheme = context.colorScheme;

        Widget body = SliverList(delegate: SliverChildListDelegate([
            ...List.generate(_labels.length, (index){
                NoteLabel label = _labels[index];

                Widget labelColor = Card(color: label.color);
                if (label.color.value == Colors.transparent.value) labelColor = Card(
                    shape: RoundedRectangleBorder(
                        side: BorderSide(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(99999)
                    ),
                );

                Widget leading = SizedBox(
                    width: 32,
                    height: 32,
                    child: labelColor,
                );

                Widget trailing = IconButton(
                    tooltip: "Delete",
                    onPressed: () => _deleteLabel(label, index),
                    icon: const Icon(Icons.delete_outlined)
                );

                Widget item = Column(children: [
                    if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                        title: Text(label.name),
                        contentPadding: const EdgeInsets.only(left: 16, right: 16),
                        leading: leading,
                        trailing: trailing,
                        onTap: () => _editLabel(label, index),
                    ),
                ]);

                if (context.isBigScreen){
                    item = Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[Flexible(child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: ListTileTheme(
                                data: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                child: item
                            ),
                        ))],
                    );
                }

                return item;
            }),
            const SizedBox(height: 96.0),
        ]));

        if (_labels.isEmpty){
            body = SliverFillRemaining(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                    Icon(Icons.label_outlined, size: textTheme.displayLarge?.fontSize),
                    const SizedBox(height: 16,),
                    Text('No labels', style: textTheme.titleLarge)
                ],
            )));
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
    Widget build(BuildContext context) {
        context.changeSystemUI();

        return Scaffold(
            body: _body(),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: _addLabel,
                icon: const Icon(Icons.new_label_outlined),
                label: const Text("New label")
            ),
        );
    }
}