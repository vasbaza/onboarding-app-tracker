import 'dart:async';

import 'package:elementary/elementary.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/domain/note.dart';
import 'package:time_tracker/ui/screen/note_list_screen/note_list_screen.dart';
import 'package:time_tracker/ui/screen/note_list_screen/note_list_screen_model.dart';
import 'package:time_tracker/ui/screen/note_list_screen/widgets/input_note_dialog.dart';
import 'package:time_tracker/ui/widgets/snackbar/snack_bars.dart';
import 'package:uuid/uuid.dart';

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
  final _noteListState = EntityStateNotifier<List<Note>>();

  @override
  ListenableState<EntityState<List<Note>>> get noteListState => _noteListState;

  final ScrollController _listScrollController = ScrollController();

  ScrollController get listScrollController => _listScrollController;

  NoteListScreenWidgetModel(
    NoteListScreenModel model,
  ) : super(model);

  @override
  void initWidgetModel() {
    super.initWidgetModel();
    loadAllNotes();
  }

  @override
  void onErrorHandle(Object error) {
    super.onErrorHandle(error);
    hideCurrentSnackBar();
    // TODO(Zemcov): добавь обработчик ошибок (с компьютерного на человеческий)
    showSimpleSnackBar(error.toString());
  }

  @override
  Future<void> loadAllNotes() async {
    final previousData = _noteListState.value?.data;
    try {
      final res = await model.loadAllNotes();
      _noteListState.content(res);
    } on Exception catch (e) {
      _noteListState.error(e, previousData);
    }
  }

  @override
  Future<Note?> moveNoteToTrash(int index) async {
    final previousData = _noteListState.value?.data;
    if (previousData == null) {
      return null;
    }
    final deletingNote = previousData.elementAt(index);
    final optimisticData = [...previousData]..remove(deletingNote);
    _noteListState.content(optimisticData);
    try {
      await model.moveNoteToTrash(deletingNote.id);
      return deletingNote;
    } on Exception catch (_) {
      final newActualData = (_noteListState.value?.data ?? [])
        ..add(deletingNote)
        ..sort(_sortByStartDateTimeCallback);
      _noteListState.content(newActualData);
      return null;
    }
  }

  @override
  Future<void> showCancelDeleteSnackBar(Note deletedNote) async {
    hideCurrentSnackBar();
    await showRevertSnackBar(
      title: 'Заметка ${deletedNote.title} удалена',
      onRevert: () async => _restoreNoteOptimistic(deletedNote),
    )?.closed;
  }

  @override
  Future<void> showAddNoteDialog() async {
    final previousData = _noteListState.value?.data;
    final lastNote = (previousData ?? []).isEmpty ? null : previousData?.last;
    await _showAddNoteDialog(lastNote);
  }

  Future<void> _showAddNoteDialog(Note? lastNote) => showDialog<void>(
        context: context,
        builder: (context) {
          const uuid = Uuid();
          String? title;

          void onChanged(String s) => title = s;

          Future<void> onSubmit() async {
            if (title == null) {
              return;
            }
            final newNote = Note(
              startDateTime: DateTime.now(),
              id: uuid.v1(),
              title: title!,
            );
            unawaited(_addNoteOptimistic(newNote));
            if (lastNote == null || lastNote.endDateTime != null) {
              return;
            }
            unawaited(_editNoteOptimistic(
              lastNote.id,
              lastNote.copyWith(endDateTime: DateTime.now()),
            ));
            Navigator.pop(context);
          }

          return InputNoteDialog(onChanged: onChanged, onSubmit: onSubmit);
        },
      );

  Future<void> _addNoteOptimistic(Note newNote) async {
    final previousData = _noteListState.value?.data;
    final optimisticData = <Note>[...previousData ?? [], newNote]
      ..sort(_sortByStartDateTimeCallback);
    _noteListState.content(optimisticData);
    try {
      await model.addNote(newNote);
    } on Exception catch (_) {
      final newActualData = (_noteListState.value?.data ?? [newNote])
        ..remove(newNote);
      _noteListState.content(newActualData);
    }
  }

  Future<void> _restoreNoteOptimistic(Note deletedNote) async {
    final previousData = _noteListState.value?.data;
    final optimisticData = <Note>[...previousData ?? [], deletedNote]
      ..sort(_sortByStartDateTimeCallback);
    _noteListState.content(optimisticData);
    try {
      await model.restoreNote(deletedNote.id);
    } on Exception catch (_) {
      final newActualData = (_noteListState.value?.data ?? [deletedNote])
        ..remove(deletedNote);
      _noteListState.content(newActualData);
    }
  }

  Future<void> _editNoteOptimistic(String noteId, Note newNoteData) async {
    final previousData = _noteListState.value?.data;
    final index = (previousData ?? []).indexWhere((e) => e.id == noteId);
    if (index == -1) {
      return;
    }
    final optimisticData = <Note>[...previousData ?? []]..[index] = newNoteData;
    _noteListState.content(optimisticData);
    try {
      await model.editNote(
        noteId: noteId,
        newNoteData: newNoteData,
      );
    } on Exception catch (_) {
      _noteListState.content(previousData ?? []);
    }
  }

  int _sortByStartDateTimeCallback(Note a, Note b) =>
      (a.startDateTime ?? DateTime.now())
          .compareTo(b.startDateTime ?? DateTime.now());
}
