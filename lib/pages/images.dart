// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:io';

import 'package:flutter/material.dart';

import '../enums/image.dart';
import '../models/image.dart';
import '../models/note.dart';
import '../utils/build_context.dart';

class ImagesPage extends StatefulWidget {
    const ImagesPage({
        super.key,
        required this.note,
        required this.index,
        required this.onChanged
    });

    final Note note;
    final int index;
    final VoidCallback onChanged;

    @override
    State<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {

    late PageController _pageController;

    void _deleteImage() async {
        bool delete = await showDialog<bool?>(
            context: context,
            builder: (context) => AlertDialog(
                icon: const Icon(Icons.delete_outlined),
                title: const Text('Delete image'),
                content: const Text('Are you sure want to delete this image?'),
                actions: [
                    TextButton(
                        onPressed: () => context.navigateBack(false),
                        child: const Text('Cancel')
                    ),
                    FilledButton(
                        onPressed: () => context.navigateBack(true),
                        child: const Text('Delete')
                    ),
                ],
            )
        ) ?? false;

        if (delete != true) return;

        await widget.note.images[_pageController.page!.toInt()].deleteDB();

        setState((){
            int length = widget.note.images.length;
            widget.note.images.removeAt(_pageController.page!.toInt());

            if (length == _pageController.page!.toInt() + 1){
                _pageController.jumpToPage(length-2);
            }
        });

        widget.onChanged();
        if (widget.note.images.isEmpty && mounted) context.navigateBack();
    }

    @override
    void initState(){
        super.initState();
        _pageController = PageController(initialPage: widget.index);
    }

    @override
    void dispose(){
        _pageController.dispose();
        super.dispose();
    }

    AppBar _appBar(){
        Widget leading = IconButton(
            onPressed: () => context.navigateBack(),
            icon: const Icon(Icons.arrow_back)
        );

        Widget title = Text('${widget.index + 1}/${widget.note.images.length}');
        if (_pageController.hasClients){
            title = Text('${_pageController.page!.toInt() + 1}/${widget.note.images.length}');
        }

        List<Widget> actions = <Widget>[
            IconButton.outlined(
                onPressed: (){
                    _pageController.animateToPage(
                        _pageController.page!.toInt() - 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease
                    ).then((_) => setState((){}));
                },
                icon: const Icon(Icons.chevron_left_outlined)
            ),
            IconButton.outlined(
                onPressed: (){
                    _pageController.animateToPage(
                        _pageController.page!.toInt() + 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.ease
                    ).then((_) => setState((){}));
                },
                icon: const Icon(Icons.chevron_right_outlined)
            ),
            IconButton(
                icon: const Icon(Icons.delete_outlined),
                onPressed: _deleteImage,
            )
        ];

        return AppBar(
            leading: leading,
            title: title,
            actions: [...actions, const SizedBox(width: 8.0)],
        );
    }

    Widget _body(){
        Widget images = PageView.builder(
            physics: const NeverScrollableScrollPhysics(),
            allowImplicitScrolling: true,
            controller: _pageController,
            itemCount: widget.note.images.length,
            itemBuilder: (BuildContext context, int index){
                NoteImage image = widget.note.images[index];

                Widget framerBuilder(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded){
                    return SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: InteractiveViewer(
                            maxScale: 10.0,
                            child: child,
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

                return switch (image.type){
                    ImageType.file => Image.file(
                        File(image.source),
                        filterQuality: FilterQuality.high,
                        frameBuilder: framerBuilder,
                        errorBuilder: errorBuilder,
                    ),
                    ImageType.network => Image.network(
                        image.source,
                        filterQuality: FilterQuality.high,
                        loadingBuilder: loadingBuilder,
                        frameBuilder: framerBuilder,
                        errorBuilder: errorBuilder,
                    )
                };
            }
        );

        return images;
    }

    @override
    Widget build(BuildContext context) {
        context.changeSystemUI();

        return Scaffold(
            appBar: _appBar(),
            body: _body(),
        );
    }
}