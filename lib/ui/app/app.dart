import 'package:flutter/material.dart';
import 'package:time_tracker/ui/res/app_colors.dart';
import 'package:time_tracker/ui/screen/note_list_screen/note_list_screen.dart';
import 'package:time_tracker/ui/widgets/snackbar/snack_bars.dart';

/// App main widget.
class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Time Tracker',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          actionsIconTheme: IconThemeData(color: AppColors.primary),
          iconTheme: IconThemeData(color: AppColors.primary),
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusColor: AppColors.primary,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: AppColors.primary,
            ),
          ),
        ),
        primaryColor: Colors.blue,
        fontFamily: 'Roboto',
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.primary,
        ),
      ),
      // home: const TagListScreen(),
      home: const NoteListScreen(),
    );
  }
}
