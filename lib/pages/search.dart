// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/utils/build_context.dart';

import '../enums/database.dart';
import '../enums/image.dart';
import '../enums/note.dart';
import 'note.dart';
import 'home.dart';
import '../models/label.dart';
import '../data/database.dart';
import '../models/note.dart';

class SearchPage extends StatefulWidget {
    const SearchPage({super.key});

    @override
    State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {

    final _typeOptions = SearchTypeOptions();
    final _search = TextEditingController();
    final _notes = <Note>[];
    final _archives = <Note>[];
    final _trash = <Note>[];
    final _labels = <NoteLabel>[];
    final _selectedLabels = <NoteLabel>[];
    bool _isLoading = true;
    Timer? _timer;

    void _editNote(Note note) async {
        await context.navigate(builder: (builder) => NotePage(noteId: note.id));
        _update();
    }

    void _update() async {
        List<String> searchTexts = _search
            .text
            .toLowerCase()
            .trim()
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_')
            .replaceAll(RegExp(r' +'), ' ')
            .split(' ')
            ..removeWhere((text) => text.trim().isEmpty)
        ;

        String conditions = '(${[
            [for (int i = 0; i < searchTexts.length; i++) 'LOWER(title) LIKE ?'  ].join(' OR '),
            [for (int i = 0; i < searchTexts.length; i++) 'LOWER(content) LIKE ?'].join(' OR ')
        ].join(' OR ')})';
        List<String> additionConditions = [];

        List<dynamic> args = [
            ...searchTexts.map((e) => '%$e%'),
            ...searchTexts.map((e) => '%$e%'),
        ];
        List<dynamic> additionArgs = [];

        if (_search.text.trim().replaceAll(RegExp(r' +'), ' ').isEmpty){
            conditions = '(1 = 1)';
            args = [];
        }

        if (_typeOptions.images){
            additionConditions.add('LENGTH(images) > ?');
            additionArgs.add(2);
        }

        if (_typeOptions.labels){
            if (_selectedLabels.isEmpty){
                additionConditions.add('LENGTH(labels) > ?');
                additionArgs.add(2);
            } else {
                // TODO: make commented code below work

                // NOTE:
                // Commented code below is not working and I don't know why.
                // The code is used to get note by specific label name.

                // List<String> labels = _selectedLabels.map((e) => e.name).toList();
                // additionConditions.add([for (int i = 0; i < labels.length; i++) 'LOWER(labels) LIKE ?'].join(' OR '));
                // additionArgs.addAll(labels.map((label) => '%${label.toLowerCase()}%'));
            }
        }

        if (additionConditions.isNotEmpty){
            conditions = [conditions, '(${additionConditions.join(' OR ')})'].join(' AND ');
            args.addAll(additionArgs);
        }

        List<Note> notes = await Note.queryDB(DatabaseQueryOptions(
            DatabaseTables.notes,
            where: conditions,
            whereArgs: args
        ))..removeWhere((note){
            if (note.isEmpty || note.shouldDeleted){
                note.deleteDB();
                return true;
            }

            // TODO: remove this block if the commented code above fixed
            if (_typeOptions.labels && _selectedLabels.isNotEmpty){
                bool contain = false;
                for (NoteLabel label in note.labels){
                    if (_selectedLabels.any((lb) => lb.id == label.id)) {
                        contain = true;
                        break;
                    }
                }
                return !contain;
            }

            return false;
        });

        List<NoteLabel> labels = (await NoteLabel.queryDB())..sort((a, b) => a.name.compareTo(b.name));

        setState((){
            _labels.clear();
            _labels.addAll(labels);
            _notes   .clear();
            _archives.clear();
            _trash   .clear();
            for (Note note in notes){
                switch (note.status){
                    case NoteStatus.pin    : _notes   .add(note); break;
                    case NoteStatus.active : _notes   .add(note); break;
                    case NoteStatus.trash  : _trash   .add(note); break;
                    case NoteStatus.archive: _archives.add(note); break;
                }
            }
            _isLoading = false;
        });
    }

    void _updateDelay(){
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 1), _update);
    }

    void _selectTypeOption(String type){
        switch (type){
            case SearchTypeOptions.imagesTypeKey: _typeOptions.images = !_typeOptions.images;
            case SearchTypeOptions.labelsTypeKey: _typeOptions.labels = !_typeOptions.labels;
        }
        _update();
    }

    void _selectUnselectLabel(NoteLabel label){
        if (_selectedLabels.any((lb) => lb.id == label.id))
            _selectedLabels.removeWhere((lb) => lb.id == label.id);
        else
            _selectedLabels.add(label);
        _update();
    }

    @override
    void initState(){
        super.initState();
        WidgetsBinding.instance.addPostFrameCallback((_){
            _update();
        });
    }

    @override
    void dispose(){
        _search.dispose();
        _timer?.cancel();
        super.dispose();
    }

    Widget _noteListTile(Note note){
        final ColorScheme colorScheme = context.colorScheme;
        final TextTheme textTheme = context.textTheme;
        String titleText   = note.title  .replaceAll(RegExp(r'[\n ]+'), ' ').trim();
        String contentText = note.content.replaceAll(RegExp(r'[\n ]+'), ' ').trim();
        String searchRegex = RegExp.escape(_search.text).toLowerCase().trim().replaceAll(RegExp(r' +'), '|');
        TextStyle matchStyle = TextStyle(
            color: colorScheme.onTertiary,
            backgroundColor: colorScheme.tertiary
        );

        Widget title = Text(
            titleText.isEmpty? contentText : titleText,
            style: textTheme.titleLarge?.copyWith(
                fontFamily: 'Plus Jakarta Sans',
                fontFamilyFallback: ['Roboto'],
                fontWeight: FontWeight.bold,
                color: colorScheme.primary
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
        );

        bool matchTitle = RegExp(searchRegex).hasMatch((titleText.isEmpty? contentText : titleText).toLowerCase()) && searchRegex.isNotEmpty;
        if (matchTitle) title = RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
                style: textTheme.titleLarge?.copyWith(
                    fontFamily: 'Plus Jakarta Sans',
                    fontFamilyFallback: ['Roboto'],
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary
                ),
                children: (){
                    String text = titleText.isEmpty? contentText : titleText;
                    List<RegExpMatch> matches = RegExp(searchRegex, caseSensitive: false).allMatches(text).toList();
                    List<InlineSpan> texts = [TextSpan(text: text)];

                    if (matches.isNotEmpty) texts.clear();
                    for (int i = 0; i < matches.length; i++){
                        if (i == 0) {
                            texts.addAll([
                                TextSpan(text: text.substring(0, matches[i].start)),
                                TextSpan(text: matches[i].group(0), style: matchStyle),
                                if (matches.length == 1) TextSpan(text: text.substring(matches[i].end)),
                            ]);
                        } else if (i == matches.length){
                            texts.addAll([
                                TextSpan(text: text.substring(matches[i-1].end, matches[i].start)),
                                TextSpan(text: matches[i].group(0), style: matchStyle),
                                TextSpan(text: text.substring(matches[i].end)),
                            ]);
                        } else {
                            texts.addAll([
                                TextSpan(text: text.substring(matches[i-1].end, matches[i].start)),
                                TextSpan(text: matches[i].group(0), style: matchStyle)
                            ]);
                        }
                    }

                    return texts;
                }()
            ),
        );

        Widget? labels;
        if (note.labels.isNotEmpty) labels = Wrap(
            spacing: 8.0,
            children: note.labels.map<Widget>((label){
                ColorScheme color = label.colorScheme(Theme.of(context).brightness);
                bool isTransparent = label.color.value == Colors.transparent.value;
                return Chip(
                    side: isTransparent? null : BorderSide(color: color.primaryContainer),
                    label: Text(label.name),
                    backgroundColor: isTransparent? null : color.primaryContainer,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    labelStyle: textTheme.labelSmall?.copyWith(color: isTransparent
                        ? null
                        : color.onPrimaryContainer
                    ),
                );
            }).toList(),
        );

        Widget? content;

        bool matchContent = RegExp(searchRegex).hasMatch(contentText.toLowerCase()) && searchRegex.isNotEmpty;
        if (titleText.isNotEmpty && contentText.isNotEmpty && matchContent) content = RichText(
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
                style: TextStyle(color: textTheme.bodySmall!.color),
                children: (){
                    String text = contentText;
                    List<RegExpMatch> matches = RegExp(searchRegex, caseSensitive: false).allMatches(text).toList();
                    List<InlineSpan> texts = [TextSpan(text: text)];

                    if (matches.isNotEmpty) texts.clear();
                    for (int i = 0; i < matches.length; i++){
                        if (i == 0) {
                            texts.addAll([
                                TextSpan(text: text.substring(0, matches[i].start)),
                                TextSpan(text: matches[i].group(0), style: matchStyle),
                                if (matches.length == 1) TextSpan(text: text.substring(matches[i].end)),
                            ]);
                        } else if (i == matches.length){
                            texts.addAll([
                                TextSpan(text: text.substring(matches[i-1].end, matches[i].start)),
                                TextSpan(text: matches[i].group(0), style: matchStyle),
                                TextSpan(text: text.substring(matches[i].end)),
                            ]);
                        } else {
                            texts.addAll([
                                TextSpan(text: text.substring(matches[i-1].end, matches[i].start)),
                                TextSpan(text: matches[i].group(0), style: matchStyle)
                            ]);
                        }
                    }

                    return texts;
                }()
            ),
        );
        else if (titleText.isNotEmpty && contentText.isNotEmpty) content = Text(
            contentText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
        );

        Widget? subtitle;
        if ((titleText.isNotEmpty && contentText.isNotEmpty) || labels != null) subtitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (content != null) content,
                labels ?? Container()
            ]
        );

        Widget? trailing;
        if (note.images.isNotEmpty){
            Widget framerBuilder(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded){
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: AspectRatio(
                            aspectRatio: 1,
                            child: child
                        )
                    ),
                );
            }

            Widget errorBuilder(BuildContext context, Object error, StackTrace? stackTrace){
                return const Center(child: Icon(Icons.image_not_supported_outlined));
            }

            Widget loadingBuilder(BuildContext context, Widget child, ImageChunkEvent? loadingProgress){
                if (loadingProgress != null) return const Center(child: CircularProgressIndicator());
                return child;
            }

            switch (note.images[0].type){
                case ImageType.file: trailing = Image.file(
                    File(note.images[0].source),
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.cover,
                    frameBuilder: framerBuilder,
                    errorBuilder: errorBuilder,
                ); break;
                case ImageType.network: trailing = Image.network(
                    note.images[0].source,
                    filterQuality: FilterQuality.high,
                    fit: BoxFit.cover,
                    loadingBuilder: loadingBuilder,
                    frameBuilder: framerBuilder,
                    errorBuilder: errorBuilder,
                ); break;
            }
        }

        return ListTile(
            minVerticalPadding: 16,
            minLeadingWidth: 0,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            onTap: () => _editNote(note),
        );
    }

    Widget _appBar(){
        Widget suffix = IconButton(
            onPressed: () => context.navigateBack(),
            icon: const Icon(Icons.clear_outlined)
        );

        Widget title = TextFormField(
            controller: _search,
            autofocus: true,
            onChanged: (text) => _updateDelay(),
            decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(12.0, 11.0, 12.0, 8.0),
                isCollapsed: true,
                hintText: 'Search note',
                prefixIcon: const Icon(Icons.search_outlined),
                suffixIcon: suffix
            ),
        );

        return SliverAppBar(
            automaticallyImplyLeading: false,
            title: title,
            pinned: true,
        );
    }

    Widget _body(){
        final TextTheme textTheme = context.textTheme;
        final ColorScheme colorScheme = context.colorScheme;
        final List<dynamic> options = [
            ['Images'   , _typeOptions.images   , SearchTypeOptions.imagesTypeKey   ],
            ['Labels'   , _typeOptions.labels   , SearchTypeOptions.labelsTypeKey   ],
        ];

        Widget label(String text, IconData icon){
            TextStyle style = textTheme.labelLarge!;
            return Row(children: [
                Container(
                    margin: const EdgeInsets.only(left: 16.0, top: 16.0),
                    padding: const EdgeInsets.only(bottom: 4.0, left: 4.0, right: 8.0),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(
                        width: 2.0,
                        color: colorScheme.outline
                    ))),
                    child: Row(children: [
                        Icon(icon, size: style.fontSize! + 4.0),
                        const SizedBox(width: 8),
                        Text(text, style: style),
                    ]),
                ),
            ]);
        }

        Widget typeOptions = SizedBox(
            height: 50.0,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) => FilterChip(
                    label: Text(options[index][0]),
                    selected: options[index][1],
                    onSelected: (_) => _selectTypeOption(options[index][2])
                ),
                separatorBuilder: (context, index) => const SizedBox(width: 8.0),
                itemCount: options.length
            ),
        );

        Widget body = const SliverFillRemaining();

        Widget labels = SizedBox(
            height: 50.0,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index){
                    ColorScheme color = _labels[index].colorScheme(Theme.of(context).brightness);
                    bool isTransparent = _labels[index].color.value == Colors.transparent.value;
                    return FilterChip(
                        side: BorderSide(color: isTransparent? color.outline : color.primaryContainer),
                        label: Text(_labels[index].name),
                        iconTheme: IconThemeData(color: isTransparent? color.onBackground : color.onPrimaryContainer),
                        backgroundColor: isTransparent? Colors.transparent : color.primaryContainer,
                        selectedColor: isTransparent? Colors.transparent : color.primaryContainer,
                        selected: _selectedLabels.any((element) => element.id == _labels[index].id),
                        onSelected: (_) => _selectUnselectLabel(_labels[index])
                    );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8.0),
                itemCount: _labels.length
            ),
        );

        if (_notes.isEmpty && _archives.isEmpty && _trash.isEmpty){
            body = SliverFillRemaining(child: SizedBox(
                width: double.infinity,
                child: Column(children: [
                    typeOptions,
                    if (_typeOptions.labels && _labels.isNotEmpty) labels,
                    const Divider(),
                    Expanded(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                            Icon(Icons.search_outlined, size: textTheme.displayLarge?.fontSize),
                            const SizedBox(height: 16,),
                            Text('Not found', style: textTheme.titleLarge)
                        ]
                    )),
                ]),
            ));
        }

        if (_notes.isNotEmpty || _archives.isNotEmpty || _trash.isNotEmpty){
            body = SliverList(delegate: SliverChildListDelegate([
                typeOptions,
                if (_typeOptions.labels && _labels.isNotEmpty) labels,
                const Divider(),
                if (_notes.isNotEmpty) ...[
                    label('Notes', Icons.sticky_note_2_outlined),
                    ...List.generate(_notes.length, (i) => Column(children: [
                        if (i > 0) const Divider(height: 1),
                        _noteListTile(_notes[i]),
                    ])),
                ],
                if (_archives.isNotEmpty) ...[
                    label('Archives', Icons.archive_outlined),
                    ...List.generate(_archives.length, (i) => Column(children: [
                        if (i > 0) const Divider(height: 1),
                        _noteListTile(_archives[i]),
                    ])),
                ],
                if (_trash.isNotEmpty) ...[
                    label('Trash', Icons.delete_outlined),
                    ...List.generate(_trash.length, (i) => Column(children: [
                        if (i > 0) const Divider(height: 1),
                        _noteListTile(_trash[i]),
                    ])),
                ],
            ]));
        }

        if (_isLoading) {
            body = const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
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
        );
    }
}