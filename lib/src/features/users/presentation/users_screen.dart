import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../application/users_controller.dart';
import '../application/users_state.dart';
import '../data/repositories/http_users_repository.dart';
import '../domain/models/user_record.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({this.controller, super.key});

  final UsersController? controller;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  UsersController? _controller;
  bool _ownsController = false;
  String _lastErrorMessage = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editEmailController = TextEditingController();
  String? _editingId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final controller = widget.controller ?? _buildControllerFromScope(context);
    _ownsController = widget.controller == null;
    controller.addListener(_handleControllerChange);
    controller.initialize();
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChange);
    if (_ownsController) {
      _controller?.dispose();
    }
    _nameController.dispose();
    _emailController.dispose();
    _editNameController.dispose();
    _editEmailController.dispose();
    super.dispose();
  }

  UsersController _buildControllerFromScope(BuildContext context) {
    final dependencies = AppScope.of(context);
    return UsersController(
      repository: HttpUsersRepository(dependencies.apiClient),
    );
  }

  void _handleControllerChange() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final errorMessage = controller.state.errorMessage;
    if (errorMessage.isEmpty || errorMessage == _lastErrorMessage) {
      return;
    }

    _lastErrorMessage = errorMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await AppErrorDialog.show(context, message: errorMessage);
      _controller?.clearErrorMessage();
      _lastErrorMessage = '';
    });
  }

  void _startEditing(UserRecord user) {
    setState(() {
      _editingId = user.id;
      _editNameController.text = user.name;
      _editEmailController.text = user.email;
    });
  }

  void _stopEditing() {
    setState(() {
      _editingId = null;
      _editNameController.clear();
      _editEmailController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return LoadingOverlay(
          isLoading: state.isBusy,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: _UsersWorkspace(
              controller: controller,
              state: state,
              nameController: _nameController,
              emailController: _emailController,
              editNameController: _editNameController,
              editEmailController: _editEmailController,
              editingId: _editingId,
              onStartEditing: _startEditing,
              onStopEditing: _stopEditing,
            ),
          ),
        );
      },
    );
  }
}

class _UsersWorkspace extends StatelessWidget {
  const _UsersWorkspace({
    required this.controller,
    required this.state,
    required this.nameController,
    required this.emailController,
    required this.editNameController,
    required this.editEmailController,
    required this.editingId,
    required this.onStartEditing,
    required this.onStopEditing,
  });

  final UsersController controller;
  final UsersState state;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController editNameController;
  final TextEditingController editEmailController;
  final String? editingId;
  final ValueChanged<UserRecord> onStartEditing;
  final VoidCallback onStopEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Users',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage user records with the same owner-scoped entity rules as the web app.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _CompactWidth(
                width: 260,
                child: TextField(
                  key: const Key('users_add_name'),
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              _CompactWidth(
                width: 320,
                child: TextField(
                  key: const Key('users_add_email'),
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('users_add_submit'),
                onPressed: state.isBusy
                    ? null
                    : () async {
                        final created = await controller.addUser(
                          name: nameController.text,
                          email: emailController.text,
                        );
                        if (created) {
                          nameController.clear();
                          emailController.clear();
                        }
                      },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add User'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _SurfaceCard(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 780),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Options')),
                          ],
                          rows: [
                            for (final user in state.users)
                              DataRow(
                                cells: [
                                  DataCell(
                                    editingId == user.id
                                        ? TextField(
                                            controller: editNameController,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                          )
                                        : Text(user.name),
                                  ),
                                  DataCell(
                                    editingId == user.id
                                        ? TextField(
                                            controller: editEmailController,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                          )
                                        : Text(user.email),
                                  ),
                                  DataCell(
                                    editingId == user.id
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Save user',
                                                onPressed: () async {
                                                  final saved = await controller
                                                      .updateUser(
                                                        entityId: user.id,
                                                        name: editNameController
                                                            .text,
                                                        email:
                                                            editEmailController
                                                                .text,
                                                      );
                                                  if (saved) {
                                                    onStopEditing();
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.save_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Cancel edit',
                                                onPressed: onStopEditing,
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit user',
                                                onPressed: () =>
                                                    onStartEditing(user),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete user',
                                                onPressed: () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                              'Delete User',
                                                            ),
                                                            content: Text(
                                                              'Delete "${user.name}" permanently?',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              FilledButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(true),
                                                                child:
                                                                    const Text(
                                                                      'Delete',
                                                                    ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                  if (confirmed == true) {
                                                    await controller.deleteUser(
                                                      user.id,
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CompactWidth extends StatelessWidget {
  const _CompactWidth({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 84;
    final constrainedWidth = availableWidth < 160
        ? 160.0
        : availableWidth < width
        ? availableWidth
        : width;
    return SizedBox(width: constrainedWidth, child: child);
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
