import 'package:elementary/elementary.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/domain/note.dart';
import 'package:time_tracker/res/theme/app_edge_insets.dart';
import 'package:time_tracker/ui/screen/note_list_screen/note_list_screen.dart';
import 'package:time_tracker/ui/screen/note_list_screen/note_list_screen_model.dart';
import 'package:uuid/uuid.dart';

part 'i_note_list_widget_model.dart';

/// Factory for [NoteListScreenWidgetModel]
NoteListScreenWidgetModel noteListScreenWidgetModelFactory(
  BuildContext context,
) {
  final model = context.read<NoteListScreenModel>();
  final theme = context.read<ThemeWrapper>();
  return NoteListScreenWidgetModel(model, theme);
}

/// Widget Model for [NoteListScreen]
class NoteListScreenWidgetModel
    extends WidgetModel<NoteListScreen, NoteListScreenModel>
    implements INoteListWidgetModel {
  final ThemeWrapper _themeWrapper;
  final _noteListState = EntityStateNotifier<List<Note>>();

  @override
  ListenableState<EntityState<List<Note>>> get noteListState => _noteListState;

  NoteListScreenWidgetModel(
    NoteListScreenModel model,
    this._themeWrapper,
  ) : super(model);

  @override
  void initWidgetModel() {
    super.initWidgetModel();
    _loadNoteList();
  }

  @override
  void onErrorHandle(Object error) {
    super.onErrorHandle(error);
    // TODO(Zemcov): добавь обработку ошибок
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
    // }
  }

  @override
  Future<void> deleteNote(int index) async {
    final previousData = _noteListState.value?.data;
    if (previousData == null) return;
    final deletingNote = previousData.elementAt(index);

    final optimisticData = [...previousData]..remove(deletingNote);
    _noteListState.content(optimisticData);
    try {
      final resultList = await model.deleteNote(deletingNote.id);
      _noteListState.content(resultList);
    } on Exception catch (_) {
      _noteListState.content(previousData);
    }
  }

  @override
  Future<void> addNoteWithDialogAndUpdateLastNote() async {
    final previousData = _noteListState.value?.data;
    final lastNote = (previousData ?? []).isEmpty ? null : previousData?.last;

    final newNote = await _addNoteWithDialog();
    if (lastNote != null && lastNote.endDateTime == null && newNote != null) {
      await _editNote(
        lastNote.id,
        lastNote.copyWith(endDateTime: DateTime.now()),
      );
    }
  }

  Future<Note?> _addNoteWithDialog() async {
    // TODO(Zemcov): вызвать пользовательский ввод, получить экземпляр заметки
    final newNote = await _getNoteByDialog();
    if (newNote == null) return null;
    final previousData = _noteListState.value?.data;
    final optimisticData = <Note>[...previousData ?? [], newNote];
    _noteListState.content(optimisticData);

    try {
      final resultList = await model.addNote(newNote);
      _noteListState.content(resultList);
      return newNote;
    } on Exception catch (_) {
      _noteListState.content(previousData ?? []);
      return null;
    }
  }

  Future<void> _editNote(String noteId, Note newNoteData) async {
    final previousData = _noteListState.value?.data;
    final index = (previousData ?? []).indexWhere((e) => e.id == noteId);
    if (index == -1) return;

    final optimisticData = <Note>[...previousData ?? []]..[index] = newNoteData;
    _noteListState.content(optimisticData);

    try {
      final resultList = await model.editNote(
        noteId: noteId,
        newNoteData: newNoteData,
      );
      _noteListState.content(resultList);
    } on Exception catch (_) {
      _noteListState.content(previousData ?? []);
    }
  }

  Future<Note?> _getNoteByDialog() => showDialog<Note?>(
        context: context,
        builder: (context) {
          const uuid = Uuid();
          String? title;
          return SimpleDialog(
            contentPadding: AppEdgeInsets.b10h20,
            title: const Text('Ввидите название задачи'),
            children: [
              TextFormField(
                onChanged: (s) => title = s,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        title == null
                            ? null
                            : Note(
                                startDateTime: DateTime.now(),
                                id: uuid.v1(),
                                title: title!,
                              ),
                      );
                    },
                    child: const Text('Ввести'),
                  ),
                ],
              ),
            ],
          );
        },
      );

  Future<void> _loadNoteList() async {
    final previousData = _noteListState.value?.data;
    try {
      final res = await model.loadAllNotes();
      _noteListState.content(res);
    } on Exception catch (e) {
      _noteListState.error(e, previousData);
    }
  }
}
