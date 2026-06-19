import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';
import '../../../core/models/auth_user.dart';
import '../../../core/services/admin_service.dart';

class AdminPanelScreen extends StatefulWidget {
  final AuthUser currentUser;

  const AdminPanelScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminService _adminService = const AdminService();

  bool _isLoading = true;
  String? _errorMessage;

  List<AdminStudent> _students = [];
  List<AdminSection> _sections = [];
  List<AcademicUser> _users = [];
  List<TeacherSectionLink> _teacherSectionLinks = [];

  String? get _token => widget.currentUser.accessToken;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _adminService.fetchStudents(authToken: _token),
        _adminService.fetchSections(authToken: _token),
        _adminService.fetchUsers(authToken: _token),
        _adminService.fetchTeacherSectionLinks(authToken: _token),
      ]);

      if (!mounted) return;

      setState(() {
        _students = results[0] as List<AdminStudent>;
        _sections = results[1] as List<AdminSection>;
        _users = results[2] as List<AcademicUser>;
        _teacherSectionLinks = results[3] as List<TeacherSectionLink>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runAction(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      await _loadAdminData();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación realizada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _sectionName(int? seccionId) {
    if (seccionId == null) return 'Sin sección';

    final matches = _sections.where((section) => section.id == seccionId);

    if (matches.isEmpty) {
      return 'Sección $seccionId';
    }

    return matches.first.displayName;
  }

  String _userName(int usuarioId) {
    final matches = _users.where((user) => user.id == usuarioId);

    if (matches.isEmpty) {
      return 'Usuario $usuarioId';
    }

    return matches.first.nombreCompleto;
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.currentUser.rol.toUpperCase();

    if (role != 'DIRECTORA') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Panel administrativo'),
        ),
        body: const Center(
          child: Text(
            'Solo la directora puede acceder al panel administrativo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel administrativo'),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _loadAdminData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(
                icon: Icon(Icons.school_outlined),
                text: 'Estudiantes',
              ),
              Tab(
                icon: Icon(Icons.class_outlined),
                text: 'Secciones',
              ),
              Tab(
                icon: Icon(Icons.people_alt_outlined),
                text: 'Usuarios',
              ),
              Tab(
                icon: Icon(Icons.link_outlined),
                text: 'Docente-sección',
              ),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return TabBarView(
      children: [
        _buildStudentsTab(),
        _buildSectionsTab(),
        _buildUsersTab(),
        _buildTeacherSectionTab(),
      ],
    );
  }

  Widget _buildStudentsTab() {
    return _buildTabWithAction(
      actionLabel: 'Nuevo estudiante',
      actionIcon: Icons.person_add_alt,
      onAction: () => _showStudentDialog(),
      child: ListView.separated(
        itemCount: _students.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = _students[index];

          return ListTile(
            title: Text(student.nombreCompleto),
            subtitle: Text(
              'PIN: ${student.pinCorto ?? "-"} · ${_sectionName(student.seccionId)}',
            ),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(student.activo ? 'Activo' : 'Inactivo'),
                ),
                IconButton(
                  onPressed: () => _showStudentDialog(student: student),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionsTab() {
    return _buildTabWithAction(
      actionLabel: 'Nueva sección',
      actionIcon: Icons.add_business_outlined,
      onAction: () => _showSectionDialog(),
      child: ListView.separated(
        itemCount: _sections.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = _sections[index];

          return ListTile(
            title: Text(section.displayName),
            subtitle: Text('Turno: ${section.turno ?? "-"}'),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(section.activo ? 'Activa' : 'Inactiva'),
                ),
                IconButton(
                  onPressed: () => _showSectionDialog(section: section),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsersTab() {
    return _buildTabWithAction(
      actionLabel: 'Nuevo usuario',
      actionIcon: Icons.person_add_alt_1_outlined,
      onAction: () => _showUserDialog(),
      child: ListView.separated(
        itemCount: _users.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _users[index];

          return ListTile(
            title: Text(user.nombreCompleto),
            subtitle: Text('${user.email} · ${user.rolTexto}'),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(user.activo ? 'Activo' : 'Inactivo'),
                ),
                IconButton(
                  onPressed: () => _showUserDialog(user: user),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeacherSectionTab() {
    final teachers = _users
        .where((user) => user.rol.toUpperCase() == 'MAESTRO')
        .toList();

    return _buildTabWithAction(
      actionLabel: 'Asignar sección',
      actionIcon: Icons.add_link_outlined,
      onAction: teachers.isEmpty || _sections.isEmpty
          ? null
          : () => _showTeacherSectionDialog(),
      child: ListView.separated(
        itemCount: _teacherSectionLinks.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final link = _teacherSectionLinks[index];

          return ListTile(
            title: Text(_userName(link.usuarioId)),
            subtitle: Text(_sectionName(link.seccionId)),
            trailing: IconButton(
              onPressed: () {
                _runAction(
                  () => _adminService.deleteTeacherSectionLink(
                    authToken: _token,
                    linkId: link.id,
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar asignación',
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabWithAction({
    required String actionLabel,
    required IconData actionIcon,
    required VoidCallback? onAction,
    required Widget child,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }

  Future<void> _showStudentDialog({
    AdminStudent? student,
  }) async {
    final nombresController = TextEditingController(
      text: student?.nombres ?? '',
    );
    final apellidosController = TextEditingController(
      text: student?.apellidos ?? '',
    );
    final pinController = TextEditingController(
      text: student?.pinCorto ?? '',
    );
    final seccionController = TextEditingController(
      text: student?.seccionId?.toString() ?? '',
    );

    bool activo = student?.activo ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                student == null ? 'Nuevo estudiante' : 'Editar estudiante',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombresController,
                      decoration: const InputDecoration(
                        labelText: 'Nombres',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apellidosController,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        labelText: 'PIN de 4 dígitos',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: seccionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ID de sección',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: activo,
                      title: const Text('Activo'),
                      onChanged: (value) {
                        setDialogState(() {
                          activo = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final nombres = nombresController.text.trim();
    final apellidos = apellidosController.text.trim();
    final pin = pinController.text.trim();
    final seccionId = int.tryParse(seccionController.text.trim());

    await _runAction(() async {
      if (student == null) {
        await _adminService.createStudent(
          authToken: _token,
          nombres: nombres,
          apellidos: apellidos,
          pinCorto: pin,
          seccionId: seccionId,
          activo: activo,
        );
      } else {
        await _adminService.updateStudent(
          authToken: _token,
          estudianteId: student.id,
          nombres: nombres,
          apellidos: apellidos,
          pinCorto: pin,
          seccionId: seccionId,
          activo: activo,
        );
      }
    });
  }

  Future<void> _showSectionDialog({
    AdminSection? section,
  }) async {
    final gradoController = TextEditingController(
      text: section?.grado.toString() ?? '3',
    );
    final nombreController = TextEditingController(
      text: section?.nombre ?? '',
    );
    final turnoController = TextEditingController(
      text: section?.turno ?? 'MANANA',
    );

    bool activo = section?.activo ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                section == null ? 'Nueva sección' : 'Editar sección',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: gradoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Grado',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de sección',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: turnoController,
                      decoration: const InputDecoration(
                        labelText: 'Turno',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: activo,
                      title: const Text('Activa'),
                      onChanged: (value) {
                        setDialogState(() {
                          activo = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final grado = int.tryParse(gradoController.text.trim()) ?? 3;
    final nombre = nombreController.text.trim();
    final turno = turnoController.text.trim();

    await _runAction(() async {
      if (section == null) {
        await _adminService.createSection(
          authToken: _token,
          grado: grado,
          nombre: nombre,
          turno: turno,
          activo: activo,
        );
      } else {
        await _adminService.updateSection(
          authToken: _token,
          seccionId: section.id,
          grado: grado,
          nombre: nombre,
          turno: turno,
          activo: activo,
        );
      }
    });
  }

  Future<void> _showUserDialog({
    AcademicUser? user,
  }) async {
    final nombresController = TextEditingController(
      text: user?.nombres ?? '',
    );
    final apellidosController = TextEditingController(
      text: user?.apellidos ?? '',
    );
    final emailController = TextEditingController(
      text: user?.email ?? '',
    );
    final passwordController = TextEditingController();
    final gradoScopeController = TextEditingController(
      text: user?.gradoScope?.toString() ?? '',
    );

    String rol = user?.rol.toUpperCase() ?? 'MAESTRO';
    bool activo = user?.activo ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                user == null ? 'Nuevo usuario' : 'Editar usuario',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombresController,
                      decoration: const InputDecoration(
                        labelText: 'Nombres',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apellidosController,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: rol,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'MAESTRO',
                          child: Text('Maestro'),
                        ),
                        DropdownMenuItem(
                          value: 'PSICOLOGA',
                          child: Text('Psicóloga'),
                        ),
                        DropdownMenuItem(
                          value: 'DIRECTORA',
                          child: Text('Directora'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          rol = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: user == null
                            ? 'Contraseña'
                            : 'Nueva contraseña opcional',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: gradoScopeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Grado scope opcional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: activo,
                      title: const Text('Activo'),
                      onChanged: (value) {
                        setDialogState(() {
                          activo = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final nombres = nombresController.text.trim();
    final apellidos = apellidosController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final gradoScope = int.tryParse(gradoScopeController.text.trim());

    await _runAction(() async {
      if (user == null) {
        await _adminService.createUser(
          authToken: _token,
          nombres: nombres,
          apellidos: apellidos,
          email: email,
          rol: rol,
          password: password,
          gradoScope: gradoScope,
          activo: activo,
        );
      } else {
        await _adminService.updateUser(
          authToken: _token,
          usuarioId: user.id,
          nombres: nombres,
          apellidos: apellidos,
          email: email,
          rol: rol,
          password: password,
          gradoScope: gradoScope,
          activo: activo,
        );
      }
    });
  }

  Future<void> _showTeacherSectionDialog() async {
    final teachers = _users
        .where((user) => user.rol.toUpperCase() == 'MAESTRO')
        .toList();

    int? selectedTeacherId = teachers.isNotEmpty ? teachers.first.id : null;
    int? selectedSectionId = _sections.isNotEmpty ? _sections.first.id : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Asignar docente a sección'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedTeacherId,
                    decoration: const InputDecoration(
                      labelText: 'Docente',
                      border: OutlineInputBorder(),
                    ),
                    items: teachers
                        .map(
                          (teacher) => DropdownMenuItem(
                            value: teacher.id,
                            child: Text(teacher.nombreCompleto),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedTeacherId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedSectionId,
                    decoration: const InputDecoration(
                      labelText: 'Sección',
                      border: OutlineInputBorder(),
                    ),
                    items: _sections
                        .map(
                          (section) => DropdownMenuItem(
                            value: section.id,
                            child: Text(section.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSectionId = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Asignar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    if (selectedTeacherId == null || selectedSectionId == null) {
      return;
    }

    await _runAction(() async {
      await _adminService.createTeacherSectionLink(
        authToken: _token,
        usuarioId: selectedTeacherId!,
        seccionId: selectedSectionId!,
      );
    });
  }
}

