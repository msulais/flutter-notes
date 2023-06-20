// ignore_for_file: curly_braces_in_flow_control_structures, implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:notes/pages/labels.dart';
import 'package:notes/utils/build_context.dart';
import 'package:notes/utils/string.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/database.dart';
import '../enums/image.dart';
import '../enums/note.dart';
import '../models/image.dart';
import 'images.dart';
import '../models/label.dart';
import '../models/note.dart';
import '../utils/datetime.dart';

class NotePage extends StatefulWidget {
    const NotePage({super.key, this.noteId}): isEditNote = noteId != null;

    final int? noteId;
    final bool isEditNote;

    @override
    State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {

    final _title = TextEditingController();
    final _titleFocusNode = FocusNode();
    final _content = TextEditingController();
    final _contentFocusNode = FocusNode();
    final _picker = ImagePicker();
    final _dateModified = ValueNotifier(DateTime.now());
    final _previousNote = Note.newNote(
        title: "",
        content: "",
        status: NoteStatus.active
    );
    Note _note = Note.newNote(
        title: "",
        content: "",
        status: NoteStatus.active
    );
    bool _noteLoaded = false;
    bool _noteNotExist = false;
    Timer? _timer;

    bool
    get readOnly => _note.status == NoteStatus.archive || _note.status == NoteStatus.trash;

    Future<String> _appDir() async {
        final Directory dir = await getApplicationDocumentsDirectory();
        return dir.path;
    }

    Future<void> _saveNote() async {
        if (!_noteLoaded) return;

        if (!readOnly) {
            _note.title = _title.text.trim();
            _note.content = _content.text.trim();
            _note.dateModified = DateTime.now();

            if (_note != _previousNote) _dateModified.value = DateTime.now();
        }

        if (_note.id == -1) await _note.insertDB();
        else await _note.updateDB();
    }

    void _saveNoteDelay(){
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 1), _saveNote);
    }

    void _showLabelOptions() async {
        final ColorScheme colorScheme = context.colorScheme;

        if (readOnly) return;

        _titleFocusNode.unfocus();
        _contentFocusNode.unfocus();

        List<NoteLabel> labels = (await NoteLabel.queryDB())
        ..sort((a, b) => a.name.compareTo(b.name));

        if (!mounted) return;

        Widget builder(BuildContext context){
            return StatefulBuilder(builder: (context, setState){
                Widget editLabels = OutlinedButton.icon(
                    onPressed: () async {
                        await context.navigate(builder: (context) => const LabelsPage());
                        labels = (await NoteLabel.queryDB());

                        setState(() => labels.sort((a, b) => a.name.compareTo(b.name)));
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit labels'),
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                );

                Widget labelOptions = Flexible(child: Material(
                    color: Colors.transparent,
                    child: SingleChildScrollView(child: Column(children: List.generate(labels.length, (index){
                        final bool selected = _note.labels.any((element) => element.id == labels[index].id);

                        Widget labelColor = Card(color: labels[index].color);
                        if (labels[index].color.value == Colors.transparent.value) labelColor = Card(
                            shape: RoundedRectangleBorder(
                                side: BorderSide(color: colorScheme.outline),
                                borderRadius: BorderRadius.circular(99999)
                            ),
                        );

                        Widget secondary = SizedBox(
                            width: 32,
                            height: 32,
                            child: labelColor,
                        );

                        return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: CheckboxListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(
                                    topLeft    : Radius.circular(index == 0? 12 : 0),
                                    topRight   : Radius.circular(index == 0? 12 : 0),
                                    bottomLeft : Radius.circular(index == labels.length-1? 12 : 0),
                                    bottomRight: Radius.circular(index == labels.length-1? 12 : 0),
                                )),
                                tileColor: context.colorScheme.secondaryContainer,
                                title: Text(labels[index].name),
                                secondary: secondary,
                                contentPadding: const EdgeInsets.only(left: 16, right: 16),
                                value: selected,
                                onChanged: (v) => setState((){
                                    if (selected)
                                        _note.labels.removeWhere((label) => label.id == labels[index].id);
                                    else
                                        _note.labels.add(labels[index]);
                                })
                            ),
                        );
                    }))),
                ));

                return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                            editLabels,
                            const SizedBox(height: 8),
                            labelOptions
                        ]
                    ),
                );
            });
        }

        await showModalBottomSheet(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            isScrollControlled: true,
            builder: builder
        );

        await _note.updateNoteLabels();
        _saveNote();
        setState((){});
    }

    // request permission (android only)
    Future<bool> _requestPermission(Permission permission) async {
        const List<String> names = <String>[
            'Calendar',
            'Camera',
            'Contacts',
            'Location',
            'Location Always',
            'Location When In Use',
            'Media Library',
            'Microphone',
            'Phone',
            'Photos',
            'Photos Add Only',
            'Reminders',
            'Sensors',
            'SMS',
            'Speech',
            'Storage',
            'Ignore Battery Optimizations',
            'Notification',
            'Access Media Location',
            'Activity Recognition',
            'Unknown',
            'Bluetooth',
            'Manage External Storage',
            'System Alert Window',
            'Request Install Packages',
            'App Tracking Transparency',
            'Critical Alerts',
            'Access Notification Policy',
            'Bluetooth Scan',
            'Bluetooth Advertise',
            'Bluetooth Connect',
            'Nearby Wifi Devices',
            'Videos',
            'Audio',
            'Schedule Exact Alarm'
        ];
        String permissionText = names[permission.value];

        var status = await permission.request();
        if (status == PermissionStatus.granted) return true;
        if (status == PermissionStatus.permanentlyDenied){
            if (!mounted) return false;
            bool? openSettings = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                    icon: const Icon(Icons.lock_outlined),
                    title: const Text('Permission'),
                    content: Text('The permission for "$permissionText" has been permanently denied. You can modify this permission by accessing your device settings app.'),
                    actions: [
                        TextButton(child: const Text('Close'), onPressed: () => context.navigateBack()),
                        FilledButton(child: const Text('Open settings'), onPressed: () => context.navigateBack(true)),
                    ],
                )
            );
            bool canOpened = true;
            if (openSettings == true) canOpened = await openAppSettings();

            if (!canOpened){
                if (mounted) context.showSnackBar(const Text('Error: Unable to open device settings.'));
            }
        } else {
            if (mounted) context.showSnackBar(Text('Permission for "$permissionText" has been denied'));
        }
        return false;
    }

    Future<void> _getImageFromCamera() async {
        if (!(await _requestPermission(Permission.camera))) return;

        XFile? photo = await _picker.pickImage(source: ImageSource.camera);

        if (photo == null) return;

        String path = '${(await _appDir()).replaceFirst(RegExp(r'/$'), '')}/${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}${RegExp(r'\.\w+$').firstMatch(photo.path)![0]}';
        await photo.saveTo(path);

        final NoteImage img = NoteImage(type: ImageType.file, source: path)..insertDB();

        _note.images.add(img);
    }

    Future<void> _getImageFromGallery() async {
        if (!(await _requestPermission(Permission.storage))) return;
        List<XFile> images = await _picker.pickMultiImage();
        for (int i = 0; i < images.length; i++){
            XFile image = images[i];
            String path = '${(await _appDir()).replaceFirst(RegExp(r'/$'), '')}/${(i+1).toRadixString(16)}-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}${RegExp(r'\.\w+$').firstMatch(image.path)![0]}';
            await image.saveTo(path);

            final NoteImage img = NoteImage(type: ImageType.file, source: path)..insertDB();

            _note.images.add(img);
        }
    }

    Future<void> _getImageFromLink() async {
        String link = '';

        Widget builder(BuildContext context){
            Widget textfield = TextFormField(
                decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    labelText: 'Image link',
                    isDense: true
                ),
                keyboardType: TextInputType.url,
                onChanged: (text) => link = text.trim(),
            );

            Widget actions = Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                    TextButton(child: const Text('Cancel'), onPressed: () => context.navigateBack()),
                    const SizedBox(width: 8),
                    FilledButton(child: const Text('Add'), onPressed: () => context.navigateBack(true)),
                ]
            );

            return Padding(
                padding: context.mediaQueryData.viewInsets.add(const EdgeInsets.all(16.0)),
                child: SingleChildScrollView(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                        textfield,
                        const SizedBox(height: 16),
                        actions
                    ]
                ))
            );
        }

        bool? addLink = await showModalBottomSheet(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: builder
        );

        if (addLink == true && link.isNotEmpty){
            final NoteImage img = NoteImage(type: ImageType.network, source: link)..insertDB();
            _note.images.add(img);
        }
    }

    void _addImage() async {
        final ColorScheme colorScheme = context.colorScheme;

        String? imgType = await showDialog(
            context: context,
            builder: (context) {
                List options = [
                    [Icons.photo_camera_outlined, 'Camera' ],
                    [Icons.collections_outlined , 'Gallery'],
                    [Icons.link_outlined        , 'Link'   ],
                ];

                Widget content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        ...List.generate(options.length, (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: ListTile(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(
                                    topLeft    : Radius.circular(index == 0? 12 : 0),
                                    topRight   : Radius.circular(index == 0? 12 : 0),
                                    bottomLeft : Radius.circular(index == options.length-1? 12 : 0),
                                    bottomRight: Radius.circular(index == options.length-1? 12 : 0),
                                )),
                                tileColor: colorScheme.secondaryContainer,
                                leading: Icon(options[index][0], color: colorScheme.onSecondaryContainer),
                                title: Text(options[index][1], style: TextStyle(color: colorScheme.onSecondaryContainer)),
                                onTap: () => context.navigateBack(options[index][1]),
                            ),
                        ))
                    ]
                );

                return AlertDialog(
                    icon: const Icon(Icons.image_outlined),
                    title: const Text('Image source'),
                    scrollable: true,
                    content: content,
                    actions: [
                        TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => context.navigateBack()
                        )
                    ],
                );
            }
        );

        if (imgType == null) return;

        switch (imgType){
            case 'Camera' : await _getImageFromCamera (); break;
            case 'Gallery': await _getImageFromGallery(); break;
            case 'Link'   : await _getImageFromLink   (); break;
        }

        _saveNote();
        setState((){});
    }

    void _showDetails(){
        final TextTheme textTheme = context.textTheme;

        Widget builder(BuildContext context){
            Widget header = SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text('Note details',
                      style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Plus Jakarta Sans'
                      )
                  ),
                ),
            );

            final List<String> title = _note.title.trim().split(RegExp(r'\s+'))..removeWhere((t) => t.trim().isEmpty);
            final List<String> content = _note.content.trim().split(RegExp(r'\s+'))..removeWhere((t) => t.trim().isEmpty);

            List<ListTile> listTiles = <List<dynamic>>[
                [Icons.title_outlined, 'Title', _note.title],
                if (_note.labels.isNotEmpty) [Icons.label_outlined, 'Labels', [for (NoteLabel label in _note.labels) label.name].join(', ')],
                if (_note.images.isNotEmpty) [Icons.image_outlined, 'Images', '${_note.images.length} image${_note.images.length > 1? 's': ''}'],
                [Icons.today_outlined, 'Date created', _note.dateCreated.inDateTimeString()],
                [Icons.edit_calendar_outlined, 'Date modified', _dateModified.value.inDateTimeString()],
                if (readOnly) [Icons.info_outline_rounded, 'Status', _note.status.name.titleCase()],
                [Icons.text_fields_outlined, 'Word count', 'Words: ${title.length + content.length}, Characters: ${
                    _note.title.length + _note.content.length
                }'],
            ].map<ListTile>((option) => ListTile(
                leading: Icon(option[0]),
                title: Text(option[1]),
                subtitle: SelectableText(option[2])
            )).toList();

            return SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                    header,
                    ...listTiles
                ]
            ));
        }

        showModalBottomSheet(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            builder: builder
        );
    }

    void _archive(){
        setState(() => _note.setStatus(NoteStatus.archive));
        context.showSnackBar(const Text('Note archived'));
        _saveNote();
    }

    void _unarchive(){
        setState(() => _note.setStatus(NoteStatus.active));
        context.showSnackBar(const Text('Note unarchived'));
        _saveNote();
    }

    void _delete(){
        setState(() => _note.setStatus(NoteStatus.trash));
        context.showSnackBar(const Text('Note moved to trash'));
        _saveNote();
    }

    void _restore(){
        setState(() => _note.setStatus(NoteStatus.active));
        context.showSnackBar(const Text('Note restored'));
        _saveNote();
    }

    void _pin(){
        setState(() => _note.setStatus(NoteStatus.pin));
        context.showSnackBar(const Text('Note pinned'));
        _saveNote();
    }

    void _unPin(){
        setState(() => _note.setStatus(NoteStatus.active));
        context.showSnackBar(const Text('Note unpinned'));
        _saveNote();
    }

    void _showFullScreenImages(int index) async {
        await context.navigate(builder: (context) => ImagesPage(
            note: _note,
            index: index,
            onChanged: _saveNote,
        ));
        setState((){});
    }

    void _getNote() async {
        if (widget.isEditNote){
            List<Note> notes = await Note.queryDB(DatabaseQueryOptions(
                Note.databaseTable,
                where: "id = ?",
                whereArgs: [widget.noteId]
            ));

            if (notes.isEmpty)
                setState(() => _noteNotExist = true);
            else
                _note = notes.first;

            _title.text = _note.title;
            _content.text = _note.content;

            _previousNote.copy(_note);
        }

        setState(() => _noteLoaded = true);
    }

    @override
    void initState(){
        super.initState();

        WidgetsBinding.instance.addPostFrameCallback((_) {
            _getNote();
        });
        _title.addListener(_saveNoteDelay);
        _content.addListener(_saveNoteDelay);
    }

    @override
    void dispose(){
        _timer?.cancel();
        _content.removeListener((){});
        _title.removeListener((){});
        _content.dispose();
        _title.dispose();
        _titleFocusNode.dispose();
        _contentFocusNode.dispose();
        super.dispose();
    }

    Widget _appBar(){
        final TextTheme textTheme = context.textTheme;

        Widget leading = IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
                await _saveNote();
                if (mounted) context.navigateBack();
            },
        );

        Widget action = IconButton(
            tooltip: 'Unpin',
            icon: const Icon(MdiIcons.pinOffOutline),
            onPressed: _unPin,
        );
        if (_note.status == NoteStatus.active) action = IconButton(
            tooltip: 'pin',
            icon: const Icon(MdiIcons.pinOutline),
            onPressed: _pin,
        );
        if (_note.status == NoteStatus.archive) action = IconButton(
            tooltip: 'Unarchive',
            icon: const Icon(Icons.unarchive_outlined),
            onPressed: _unarchive,
        );

        if (_note.status == NoteStatus.trash) action = IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore_outlined),
            onPressed: _restore,
        );

        Widget additions = Container();
        if (!readOnly) additions = PopupMenuButton(
            icon: const Icon(Icons.add_box_outlined),
            itemBuilder: (context) {
                const List<List<dynamic>> options = [
                    [Icons.add_photo_alternate_outlined, 'Image'],
                    [Icons.new_label_outlined, 'Label'],
                ];
                return options.map<PopupMenuEntry>((option) => PopupMenuItem(
                    value: option[1],
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(option[0]),
                        title: Text(option[1], style: textTheme.labelLarge),
                    )
                )).toList();
            },
            onOpened: (){
                _titleFocusNode.unfocus();
                _contentFocusNode.unfocus();
            },
            onSelected: (value){ switch (value){
                case 'Image'   : return _addImage();
                case 'Label'   : return _showLabelOptions();
            }},
        );

        Widget noteMenu = PopupMenuButton(
            itemBuilder: (context){
                final List<dynamic> options = [
                    [Icons.info_outline_rounded, 'Details'],
                    if (!readOnly) [Icons.archive_outlined, 'Archive'],
                    if (_note.status != NoteStatus.trash) [Icons.delete_outlined, 'Delete'],
                ];
                return options.map<PopupMenuEntry<String>>((option) => PopupMenuItem(
                    value: option[1],
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(option[0]),
                        title: Text(option[1], style: textTheme.labelLarge),
                    )
                )).toList();
            },
            onOpened: (){
                _titleFocusNode.unfocus();
                _contentFocusNode.unfocus();
            },
            onSelected: (value) => switch (value){
                'Details' => _showDetails(),
                'Archive' => _archive(),
                'Delete'  => _delete(),
                _ => (){}()
            },
        );

        return SliverAppBar(
            leading: leading,
            pinned: true,
            actions: _noteNotExist? null : <Widget>[
                action,
                additions,
                noteMenu
            ],
        );
    }

    Widget _body(){
        final TextTheme textTheme = context.textTheme;
        final ColorScheme colorScheme = context.colorScheme;
        final ThemeData themeData = context.themeData;

        Widget images = Container();
        if (_note.images.isNotEmpty){
            Widget framerBuilder(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded){
                return ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: child
                );
            }

            Widget errorBuilder(BuildContext context, Object error, StackTrace? stackTrace){
                return const Center(child: Icon(Icons.image_not_supported_outlined));
            }

            Widget loadingBuilder(BuildContext context, Widget child, ImageChunkEvent? loadingProgress){
                if (loadingProgress != null) return const Center(child: CircularProgressIndicator());
                return child;
            }

            images = SizedBox(
                height: 200.0,
                child: ListView.separated(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                    itemCount: _note.images.length,
                    scrollDirection: Axis.horizontal,
                    separatorBuilder: (context, index) => const SizedBox(width: 8.0),
                    itemBuilder: (context, index){
                        NoteImage image = _note.images[index];
                        Widget imageWidget;
                        switch (image.type){
                            case ImageType.file: imageWidget = Image.file(
                                File(image.source),
                                fit: BoxFit.fitHeight,
                                filterQuality: FilterQuality.high,
                                frameBuilder: framerBuilder,
                                errorBuilder: errorBuilder,
                            ); break;
                            case ImageType.network: imageWidget = Image.network(
                                image.source,
                                fit: BoxFit.fitHeight,
                                filterQuality: FilterQuality.high,
                                loadingBuilder: loadingBuilder,
                                frameBuilder: framerBuilder,
                                errorBuilder: errorBuilder,
                            ); break;
                        }

                        return GestureDetector(
                            onTap: () => _showFullScreenImages(index),
                            child: imageWidget
                        );
                    }
                ),
            );
        }

        Widget labels = Container();
        if (_note.labels.isNotEmpty) labels = Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16, bottom: 8),
            child: Wrap(
                spacing: 8.0,
                children: _note.labels.map<Widget>((label){
                    ColorScheme color = label.colorScheme(themeData.brightness);
                    bool isTransparent = label.color.value == Colors.transparent.value;
                    return ActionChip(
                        side: isTransparent? null : BorderSide(color: color.primaryContainer),
                        label: Text(label.name),
                        backgroundColor: isTransparent? null : color.primaryContainer,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        labelStyle: textTheme.labelSmall?.copyWith(color: isTransparent? null : color.onPrimaryContainer),
                        onPressed: _showLabelOptions,
                    );
                }).toList(),
            ),
        );

        Widget title = Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 16, right: 16),
            child: TextFormField(
                controller: _title,
                focusNode: _titleFocusNode,
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Title ...',
                    isCollapsed: true
                ),
                style: textTheme.headlineMedium!.copyWith(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.bold,
                    fontFamilyFallback: ['Roboto'],
                    color: colorScheme.primary
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                minLines: null,
                readOnly: readOnly,
                showCursor: !readOnly,
            ),
        );

        Widget dateModified = Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8),
            child: ValueListenableBuilder<DateTime>(
                valueListenable: _dateModified,
                builder: (context, dateModified, child) {
                    return Text(
                        dateModified.inString(),
                        style: textTheme.labelLarge
                    );
                }
            ),
        );

        Widget content = Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
                controller: _content,
                focusNode: _contentFocusNode,
                decoration: const InputDecoration.collapsed(hintText: 'Type something ...'),
                textCapitalization: TextCapitalization.sentences,
                readOnly: readOnly,
                style: const TextStyle(height: 1.3),
                showCursor: !readOnly,
                maxLines: null,
            ),
        );

        Widget body = SliverList(delegate: SliverChildListDelegate([
            images,
            labels,
            title,
            dateModified,
            const Divider(height: 1),
            content
        ]));

        if (context.isBigScreen){
            body = SliverList(delegate: SliverChildListDelegate([
                images,
                labels,
                title,
                dateModified,
                const Divider(height: 1),
                content
            ]));
        }

        if (!_noteLoaded){
            body = const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }

        if (_noteNotExist){
            body = SliverFillRemaining(child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                    Icon(Icons.sticky_note_2_outlined, size: textTheme.displayLarge?.fontSize),
                    const SizedBox(height: 16,),
                    Text('Note not exist', style: textTheme.titleLarge)
                ]
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
        return WillPopScope(
            onWillPop: () async {
                await _saveNote();
                return Future.value(true);
            },
            child: Scaffold(
                body: _body(),
            ),
        );
    }
}