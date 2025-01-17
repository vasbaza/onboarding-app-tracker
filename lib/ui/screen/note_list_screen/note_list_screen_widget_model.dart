import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:elementary/elementary.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/domain/note/note.dart';
import 'package:time_tracker/domain/tag/tag.dart';
import 'package:time_tracker/ui/screen/note_list_screen/note_list_screen.dart';
import 'package:time_tracker/ui/screen/note_list_screen/note_list_screen_model.dart';
import 'package:time_tracker/ui/screen/note_list_screen/widgets/note_input_field.dart';
import 'package:time_tracker/ui/screen/tag_screen/tag_list_screen.dart';
import 'package:time_tracker/ui/widgets/dialog/input_dialog.dart';
import 'package:time_tracker/ui/widgets/snackbar/snack_bars.dart';

part 'i_note_list_widget_model.dart';

/// Factory for [NoteListScreenWidgetModel]
NoteListScreenWidgetModel noteListScreenWidgetModelFactory(
  BuildContext context,
) {
  final model = context.read<NoteListScreenModel>();
  return NoteListScreenWidgetModel(model);
}

/// Widget Model for [NoteListScreen]
class NoteListScreenWidgetModel
    extends WidgetModel<NoteListScreen, NoteListScreenModel>
    implements INoteListWidgetModel {
  late final StreamSubscription rawNoteStreamSubscription;
  late final StreamSubscription rawTagStreamSubscription;
  final _noteListState = EntityStateNotifier<List<Note>>();

  @override
  ListenableState<EntityState<List<Note>>> get noteListState => _noteListState;

  NoteListScreenWidgetModel(
    NoteListScreenModel model,
  ) : super(model);

  @override
  void initWidgetModel() {
    super.initWidgetModel();
    _initState();
  }

  @override
  void dispose() {
    rawNoteStreamSubscription.cancel();
    rawTagStreamSubscription.cancel();
    super.dispose();
  }

  @override
  void onErrorHandle(Object error) {
    super.onErrorHandle(error);
    hideCurrentSnackBar();
    showSimpleSnackBar(error.toString());
  }

  @override
  Future<void> loadAllNotes() async {
    final previousState = _noteListState.value?.data;
    _noteListState.loading();
    try {
      final sortedNotes = await model.loadAllNotes()
        ..sort();
      _noteListState.content(sortedNotes);
    } on Exception catch (e) {
      _noteListState.error(e, previousState);
    }
  }

  // ToDo(Bazarova): грязная функция
  @override
  Future<Note?> moveNoteToTrash(int index) async {
    final noteToDelete = _noteListState.value?.data?.elementAt(index);
    _noteListState.value?.data?.remove(noteToDelete);

    final newState = _noteListState.value?.data;
    if (newState != null) {
      _noteListState.content(newState);
    }

    if (noteToDelete != null) {
      await model.deleteNote(noteToDelete);
      final shouldDelete = await showCancelDeleteSnackBar(noteToDelete);
      if (shouldDelete) {
      } else {
        await _addNote(noteToDelete);
        _noteListState.value?.data?.add(noteToDelete);
      }
    }
  }

  @override
  void onTapTags() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const TagListScreen()),
    );
  }

  @override
  Future<bool> showCancelDeleteSnackBar(Note deletedNote) async {
    var shouldDelete = true;

    hideCurrentSnackBar();

    await showRevertSnackBar(
      title: 'Заметка ${deletedNote.title} удалена',
      onRevert: () => shouldDelete = false,
    )?.closed;

    return shouldDelete;
  }

  @override
  Future<void> showAddNoteDialog() async => showDialog<void>(
        context: context,
        builder: (context) {
          String? title;
          Tag? tag;

          final tags = model.rawTagSubject.value.docs
              .map((rawTag) => Tag.fromDatabase(rawTag))
              .toList();

          void onSubmit() {
            if (title != null) {
              tag ??= _returnTagIfTitleInTags(tags, title!);
              final newNote = Note(
                startTimestamp: DateTime.now().millisecondsSinceEpoch,
                id: 'default',
                title: title!,
                tag: tag,
              );
              Navigator.pop(context);
              _addNoteAndFinishTheLastNote(newNote);
            }
          }

          void onChanged(String inputText) => title = inputText;
          void onChooseTag(Tag chosenTag) => tag = chosenTag;
          void onSelectedTag(Tag tag) => onChooseTag(tag);

          return InputDialog(
            inputField: NoteInputField(
              onSelected: onSelectedTag,
              tagList: tags,
              onChanged: onChanged,
            ),
            onSubmit: onSubmit,
            title: 'Введите название задачи',
            submitButtonText: 'Ввести',
          );
        },
      );

  // ToDo(Bazarova): дублирование с функицей showAddNoteDialog
  @override
  Future<void> showEditNoteDialog(Note noteToEdit) async => showDialog<void>(
        context: context,
        builder: (context) {
          String? title;
          Tag? tag;

          final tags = model.rawTagSubject.value.docs
              .map((rawTag) => Tag.fromDatabase(rawTag))
              .toList();

          void onSubmit() {
            if (title != null && title != '' && title != noteToEdit.title) {
              tag ??= _returnTagIfTitleInTags(tags, title!);
              final newNoteData = <String, dynamic>{
                'title': title,
                'tag': tag?.toJson(),
              };
              _editNote(noteToEdit, newNoteData);
              Navigator.pop(context);
            }
          }

          void onChanged(String inputText) => title = inputText;
          void onChooseTag(Tag chosenTag) => tag = chosenTag;
          void onSelectedTag(Tag tag) => onChooseTag(tag);

          return InputDialog(
            inputField: NoteInputField(
              onSelected: onSelectedTag,
              tagList: tags,
              onChanged: onChanged,
            ),
            onSubmit: onSubmit,
            submitButtonText: 'Ввести',
          );
        },
      );

  void _noteStreamListener(QuerySnapshot snapshot) {
    final notes = snapshot.docs
        .map((rawNote) => Note.fromDatabase(rawNote))
        .toList()
      ..sort();
    _noteListState.content(notes);
  }

  void _tagStreamListener(QuerySnapshot snapshot) {
    final tags =
        snapshot.docs.map((rawTag) => Tag.fromDatabase(rawTag)).toList();
    final currentState = _noteListState.value?.data;
    if (currentState != null) {
      final newState = currentState
          .map((e) => e.copyWith(
                tag:
                    tags.firstWhereOrNull((element) => element.id == e.tag?.id),
                title: e.tag?.title ?? e.title,
              ))
          .toList();
      _noteListState.content(newState);
    }
  }

  Future<void> _finishNote(Note newNote) async {
    final notesCount = _noteListState.value?.data?.length ?? 0;
    if (notesCount >= 1) {
      await model.finishNote(
        newNote.startTimestamp,
      );
    }
  }

  // ToDo(Bazarova): грязная функция
  Future<void> _addNoteAndFinishTheLastNote(Note newNote) async {
    await _finishNote(newNote);
    await _addNote(newNote);
  }

  Future<void> _addNote(Note newNote) async {
    _noteListState.value?.data?.add(newNote);

    final newState = (_noteListState.value?.data?..sort()) ?? [];
    _noteListState.content(newState);

    try {
      await model.addNote(newNote);
    } on Exception catch (_) {
      final currentState = (_noteListState.value?.data ?? [newNote])
        ..remove(newNote);
      _noteListState.content(currentState);
    }
  }

  Future<void> _editNote(
    Note noteToEdit,
    Map<String, dynamic> newNoteData,
  ) async {
    final index = _noteListState.value?.data?.indexOf(noteToEdit);
    if (index != null) {
      try {
        await model.editNote(noteId: noteToEdit.id, newNoteData: newNoteData);
      } on FirebaseException catch (_) {
        throw Exception('Cannot edit note');
      }
    }
  }

  Tag? _returnTagIfTitleInTags(List<Tag> tags, String title) {
    if (tags.firstWhereOrNull((element) => element.title == title) != null) {
      return Tag(
        title: title,
        id: 'default',
      );
    }
  }

  Future<void> _initState() async {
    await loadAllNotes();
    rawNoteStreamSubscription =
        model.rawNoteSubject.listen(_noteStreamListener);
    rawTagStreamSubscription =
        model.rawTagSubject.stream.listen(_tagStreamListener);
  }
}
