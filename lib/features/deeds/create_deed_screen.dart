import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// M0 placeholder — the full deed form arrives in M4.
class CreateDeedScreen extends StatelessWidget {
  const CreateDeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create new deed'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Deed form arrives in M4.\n\nFields: name · icon · category · frequency · goal · parent deed · reasons toggle.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}