import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_bodybuilding_program/app/router.dart';
import 'package:my_bodybuilding_program/app/strings.dart';
import 'package:my_bodybuilding_program/features/catalogue/presentation/catalogue_list.dart';

/// The exercise catalogue: search, muscle filter, archived toggle.
class CatalogueScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.exercisesTitle)),
      body: CatalogueList(
        onExerciseTap: (e) => context.push(Routes.exercise(e.id)),
        onCreate: (name) => context.push(Routes.newExercise(name: name)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newExercise()),
        icon: const Icon(Symbols.add_rounded),
        label: const Text(Strings.newExercise),
      ),
    );
  }
}
