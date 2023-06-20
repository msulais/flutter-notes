// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/utils/build_context.dart';

import '../enums/database.dart';
import '../enums/image.dart';
import '../enums/note.dart';
import '../enums/settings.dart';
import 'note.dart';
import 'search.dart';
import '../models/label.dart';
import '../data/database.dart';
import '../models/note.dart';
import '../data/settings.dart';
import '../widgets/drawer.dart';

class SearchTypeOptions {
    bool images    = false;
    bool labels    = false;

    bool
    get isAll => !images && !labels;

    static const imagesTypeKey = 'images';
    static const labelsTypeKey = 'labels';
}

class HomePage extends StatefulWidget {
    const HomePage({super.key});

    @override
    State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

    final _typeOptions = SearchTypeOptions();
    final _labels = <NoteLabel>[];
    final _selectedLabels = <NoteLabel>[];
    final _selectedNoteIds = <int>[];
    List<Note> _pinnedNotes = [];
    List<Note> _unpinnedNotes = [];
    bool _isLoading = true;
    bool _isEditing = false;

    bool
    get isEmpty => _pinnedNotes.isEmpty && _unpinnedNotes.isEmpty;

    void _addNote() async {
        await context.navigate(builder: (context) => const NotePage());
        _update();
    }

    void _editNote(Note note) async {
        await context.navigate(builder: (context) => NotePage(noteId: note.id));
        _update();
    }

    void _selectNote(Note note){
        setState((){
            if (_selectedNoteIds.contains(note.id)) _selectedNoteIds.remove(note.id);
            else _selectedNoteIds.add(note.id);

            _isEditing = _selectedNoteIds.isNotEmpty;
        });
    }

    void _update() async {
        final Settings settings = context.settings();

        String conditions = '(status = ? OR status = ?)';
        List<String> additionConditions = [];

        List<dynamic> args = [NoteStatus.pin.name, NoteStatus.active.name];
        List<dynamic> additionArgs = [];

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

        List<Note> pinnedNotes   = notes.where((element) => element.status == NoteStatus.pin).toList();
        List<Note> unpinnedNotes = notes.where((element) => element.status != NoteStatus.pin).toList();

        switch (settings.sortBy){
            case SortBy.title:
                pinnedNotes  .sort((a, b) => a.title.compareTo(b.title));
                unpinnedNotes.sort((a, b) => a.title.compareTo(b.title));
            case SortBy.dateCreated:
                pinnedNotes  .sort((a, b) => a.dateCreated.isAfter(b.dateCreated)? -1 : 1);
                unpinnedNotes.sort((a, b) => a.dateCreated.isAfter(b.dateCreated)? -1 : 1);
            case SortBy.dateModified:
                pinnedNotes  .sort((a, b) => a.dateModified.isAfter(b.dateModified)? -1 : 1);
                unpinnedNotes.sort((a, b) => a.dateModified.isAfter(b.dateModified)? -1 : 1);
            case SortBy.label:
                pinnedNotes  .sort((a, b) => a.labels.length > b.labels.length? -1 : 1);
                unpinnedNotes.sort((a, b) => a.labels.length > b.labels.length? -1 : 1);
            case SortBy.image:
                pinnedNotes  .sort((a, b) => a.images.length > b.images.length? -1 : 1);
                unpinnedNotes.sort((a, b) => a.images.length > b.images.length? -1 : 1);
        }

        if (settings.sortMode == SortMode.descending){
            pinnedNotes   = pinnedNotes  .reversed.toList();
            unpinnedNotes = unpinnedNotes.reversed.toList();
        }

        List<NoteLabel> labels = (await NoteLabel.queryDB())..sort((a, b) => a.name.compareTo(b.name));
        _labels.clear();

        setState((){
            _pinnedNotes   = List.from(pinnedNotes);
            _unpinnedNotes = List.from(unpinnedNotes);
            _labels.addAll(labels);
            _isLoading = false;
        });
    }

    void _cancelEditingMode(){
        setState(() {
            _isEditing = false;
            _selectedNoteIds.clear();
        });
    }

    void _pinUnpinSelectedNotes() async {
        int pin = 0, unpin = 0;
        for (Note note in _pinnedNotes){
            if (_selectedNoteIds.contains(note.id)){
                note.setStatus(NoteStatus.active);
                ++unpin;
                await note.updateDB();
            }
        }
        for (Note note in _unpinnedNotes){
            if (_selectedNoteIds.contains(note.id)){
                note.setStatus(NoteStatus.pin);
                ++pin;
                await note.updateDB();
            }
        }
        if (mounted && (pin > 0 || unpin > 0)) context.showSnackBar(Text([
            if (pin   > 0)   '$pin note${pin   > 1? 's': ''} pinned',
            if (unpin > 0) '$unpin note${unpin > 1? 's': ''} unpinned'
        ].join(', ')));
        _cancelEditingMode();
        _update();
    }

    void _archiveSelectedNotes() async {
        int archive = 0;
        for (Note note in (List.from(_pinnedNotes) + List.from(_unpinnedNotes))){
            if (_selectedNoteIds.contains(note.id)){
                note.setStatus(NoteStatus.archive);
                ++archive;
                await note.updateDB();
            }
        }
        if (mounted && archive > 0) context.showSnackBar(
            Text('$archive note${archive > 1? 's': ''} archived')
        );
        _cancelEditingMode();
        _update();
    }

    void _deleteSelectedNotes() async {
        int trash = 0;
        for (Note note in (List.from(_pinnedNotes) + List.from(_unpinnedNotes))){
            if (_selectedNoteIds.contains(note.id)){
                note.setStatus(NoteStatus.trash);
                ++trash;
                await note.updateDB();
            }
        }
        if (mounted && trash > 0) context.showSnackBar(
            Text('$trash note${trash > 1? 's': ''} moved to trash')
        );
        _cancelEditingMode();
        _update();
    }

    void _sort() async {
        final Settings settings = context.settings();
        final ColorScheme colorScheme = context.colorScheme;

        Widget builder(BuildContext context){
            List<Widget> actions = [TextButton(
                child: const Text('Done'),
                onPressed: () => context.navigateBack()
            )];

            Widget content = Material(
                color: Colors.transparent,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        ...List.generate(SortBy.values.length, (index){
                            Widget title = Text((() => switch (SortBy.values[index]){
                                SortBy.title        =>'Title',
                                SortBy.dateCreated  => 'Date created',
                                SortBy.dateModified => 'Date modified',
                                SortBy.label        => 'Label',
                                SortBy.image        => 'Image'
                            })(), style: TextStyle(color: colorScheme.onSecondaryContainer));

                            ShapeBorder shape = RoundedRectangleBorder(borderRadius: BorderRadius.only(
                                topLeft    : Radius.circular(index == 0? 12 : 0),
                                topRight   : Radius.circular(index == 0? 12 : 0),
                                bottomLeft : Radius.circular(index == SortBy.values.length-1? 12 : 0),
                                bottomRight: Radius.circular(index == SortBy.values.length-1? 12 : 0),
                            ));

                            return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: RadioListTile(
                                    shape: shape,
                                    tileColor: colorScheme.secondaryContainer,
                                    title: title,
                                    value: SortBy.values[index],
                                    groupValue: settings.sortBy,
                                    onChanged: (value) => settings.sortBy = value ?? settings.sortBy
                                ),
                            );
                        }),
                        const SizedBox(height: 12),
                        ...List.generate(SortMode.values.length, (index){
                            Widget title = Text((() => switch (SortMode.values[index]){
                                SortMode.ascending => 'Ascending',
                                SortMode.descending => 'Descending'
                            })(), style: TextStyle(color: colorScheme.onSecondaryContainer));

                            ShapeBorder shape = RoundedRectangleBorder(borderRadius: BorderRadius.only(
                                topLeft    : Radius.circular(index == 0? 12 : 0),
                                topRight   : Radius.circular(index == 0? 12 : 0),
                                bottomLeft : Radius.circular(index == SortMode.values.length-1? 12 : 0),
                                bottomRight: Radius.circular(index == SortMode.values.length-1? 12 : 0),
                            ));

                            return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: RadioListTile(
                                    shape: shape,
                                    tileColor: colorScheme.secondaryContainer,
                                    title: title,
                                    value: SortMode.values[index],
                                    groupValue: settings.sortMode,
                                    onChanged: (value) => settings.sortMode = value ?? settings.sortMode
                                ),
                            );
                        }),
                    ]
                ),
            );

            return AlertDialog(
                scrollable: true,
                icon: const Icon(Icons.swap_vert_outlined),
                title: const Text('Sort by'),
                actions: actions,
                content: content
            );
        }

        await showDialog(
            context: context,
            builder: builder
        );

        _update();
    }

    void _openSearch() async {
        await context.navigate(builder: (context) => const SearchPage());
        _update();
    }

    void _onNoteDismissed(DismissDirection direction, Note note) async {
        if (direction == DismissDirection.startToEnd){
            note.setStatus(NoteStatus.trash);
            await note.updateDB();
            if (mounted) context.showSnackBar(const Text("Note moved to trash"));
        }

        else if (direction == DismissDirection.endToStart){
            note.setStatus(NoteStatus.archive);
            await note.updateDB();
            if (mounted) context.showSnackBar(const Text("Note archived"));
        }

        setState((){
            _pinnedNotes.removeWhere((n) => n.id == note.id);
            _unpinnedNotes.removeWhere((n) => n.id == note.id);
        });
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

    Widget _noteListTile(Note note){
        final TextTheme textTheme = context.textTheme;
        final ColorScheme colorScheme = context.colorScheme;
        bool selected = _selectedNoteIds.contains(note.id);
        String titleText   = note.title  .replaceAll(RegExp(r'[\n ]+'), ' ').trim();
        String contentText = note.content.replaceAll(RegExp(r'[\n ]+'), ' ').trim();

        Widget? leading;
        if (_isEditing) leading = Icon(selected
            ? Icons.check_box_outlined
            : Icons.check_box_outline_blank_outlined
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

        Widget labels = Wrap(
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

        Widget subtitle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (titleText.isNotEmpty && contentText.isNotEmpty) Text(
                    contentText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                ),
                labels
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

        Widget noteWidget = ListTile(
            minVerticalPadding: 16,
            minLeadingWidth: 0,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            leading: leading,
            tileColor: selected? colorScheme.secondaryContainer : null,
            onLongPress: () => _selectNote(note),
            onTap: () => _isEditing? _selectNote(note) : _editNote(note),
        );

        if (_isEditing) return noteWidget;

        Widget background = Container(
            color: colorScheme.error,
            padding: const EdgeInsets.all(16.0),
            child: Row(children: [
                Icon(Icons.delete_outlined, color: colorScheme.onError),
            ]),
        );

        Widget secondaryBackground = Container(
            color: colorScheme.tertiary,
            padding: const EdgeInsets.all(16.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Icon(Icons.archive_outlined, color: colorScheme.onTertiary),
            ]),
        );

        return Dismissible(
            key: ValueKey(note.id),
            background: background,
            secondaryBackground: secondaryBackground,
            onDismissed: (direction) => _onNoteDismissed(direction, note),
            child: noteWidget
        );
    }

    Widget _appBar(){
        Widget? leading = _isEditing? IconButton(
            onPressed: _cancelEditingMode,
            icon: const Icon(Icons.clear)
        ) : null;

        List<Widget> actions = [
            IconButton(
                tooltip: 'Search',
                onPressed: _openSearch,
                icon: const Icon(Icons.search_outlined)
            ),
            IconButton(
                tooltip: 'Sort',
                icon: const Icon(Icons.swap_vert),
                onPressed: _sort
            ),
        ];

        if (_isEditing) actions = [
            IconButton(
                tooltip: 'Pin/unpin',
                onPressed: _pinUnpinSelectedNotes,
                icon: const Icon(Icons.push_pin_outlined)
            ),
            IconButton(
                tooltip: 'Archive',
                onPressed: _archiveSelectedNotes,
                icon: const Icon(Icons.archive_outlined)
            ),
            IconButton(
                tooltip: 'Deleted',
                onPressed: _deleteSelectedNotes,
                icon: const Icon(Icons.delete_outlined)
            ),
        ];

        return SliverAppBar(
            leading: leading,
            pinned: true,
            title: Text(_isEditing? '${_selectedNoteIds.length}' : 'Notes'),
            actions: [...actions, const SizedBox(width: 8.0)],
        );
    }

    Widget _body(){
        final TextTheme textTheme = context.textTheme;
        final ColorScheme colorScheme = context.colorScheme;
        final List<dynamic> options = [
            ['Images', _typeOptions.images, SearchTypeOptions.imagesTypeKey],
            ['Labels', _typeOptions.labels, SearchTypeOptions.labelsTypeKey],
        ];

        Widget typeOptions = SizedBox(
            height: 50.0,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index){
                    return FilterChip(
                        label: Text(options[index][0]),
                        selected: options[index][1],
                        onSelected: (_) => _selectTypeOption(options[index][2])
                    );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 8.0),
                itemCount: options.length
            ),
        );

        Widget labels = SizedBox(
            height: 50.0,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index){
                    ColorScheme color = _labels[index].colorScheme(Theme.of(context).brightness);
                    bool isTransparent = _labels[index].color.value == Colors.transparent.value;
                    return FilterChip(
                        side:BorderSide(color: isTransparent? color.outline : color.primaryContainer),
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

        Widget body = const SliverFillRemaining();

        if (isEmpty){
            body = SliverFillRemaining(child: SizedBox(
                width: double.infinity,
                child: Column(children: [
                    if (!_isEditing) typeOptions,
                    if (!_isEditing && _typeOptions.labels && _labels.isNotEmpty) labels,
                    if (!_isEditing) const Divider(),
                    Expanded(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                            Icon(Icons.sticky_note_2_outlined, size: textTheme.displayLarge?.fontSize),
                            const SizedBox(height: 16,),
                            Text('No notes', style: textTheme.titleLarge)
                        ]
                    )),
                ]),
            ));
        }

        if (!isEmpty){
            body = SliverList(delegate: SliverChildListDelegate([
                if (!_isEditing) typeOptions,
                if (!_isEditing && _typeOptions.labels && _labels.isNotEmpty) labels,
                if (!_isEditing) const Divider(),
                if (_pinnedNotes.isNotEmpty) ...[
                    label('Pinned', Icons.push_pin_outlined),
                    ...List.generate(_pinnedNotes.length, (i) => Column(children: [
                        if (i > 0) const Divider(height: 1),
                        _noteListTile(_pinnedNotes[i]),
                    ])),
                    if (_unpinnedNotes.isNotEmpty) label('Others', Icons.sticky_note_2_outlined),
                ],
                ...List.generate(_unpinnedNotes.length, (i) => Column(children: [
                    if (i > 0) const Divider(height: 1),
                    _noteListTile(_unpinnedNotes[i]),
                ])),
                const SizedBox(height: 88)
            ]));
        }

        if (_isLoading) {
            body = const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }

        body = CustomScrollView(slivers: [
            _appBar(),
            body
        ]);

        if (context.isBigScreen) {
            body = Row(children: [
                NavigationDrawerWidget(
                    selectedIndex: 0,
                    onLabelChanged: _update,
                ),
                Flexible(child: body),
            ]);
        }

        return SafeArea(
            top: false,
            child: body
        );
    }

    @override
    Widget build(BuildContext context) {
        context.changeSystemUI();

        return Scaffold(
            drawer: context.isBigScreen? null : NavigationDrawerWidget(
                selectedIndex: 0,
                onLabelChanged: _update,
            ),
            floatingActionButton: _isEditing? null : FloatingActionButton.extended(
                onPressed: _addNote,
                icon: const Icon(Icons.add),
                label: const Text('New note')
            ),
            drawerEnableOpenDragGesture: !_isEditing,
            body: _body()
        );
    }
}