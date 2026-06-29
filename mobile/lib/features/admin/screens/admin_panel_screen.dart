import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';
import '../../../core/models/auth_user.dart';
import '../../../core/models/jornada_evaluacion.dart';
import '../../../core/models/student.dart';
import '../../../core/repositories/local_classroom_mode_storage.dart';
import '../../../core/repositories/local_student_cache.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/services/jornada_service.dart';
import '../../auth/screens/pin_login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final AuthUser currentUser;

  const AdminPanelScreen({super.key, required this.currentUser});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminService _adminService = const AdminService();
  final JornadaService _jornadaService = const JornadaService();

  bool _isLoading = true;
  String? _errorMessage;

  List<AdminStudent> _students = [];
  List<AdminSection> _sections = [];
  List<AcademicUser> _users = [];
  List<TeacherSectionLink> _teacherSectionLinks = [];

  ClassroomModeState? _classroomMode;
  JornadaEvaluacion? _activeJornada;
  int? _selectedClassroomSectionId;

  String? get _token => widget.currentUser.accessToken;

  bool get _isDirector {
    return widget.currentUser.rol.toUpperCase() == 'DIRECTORA';
  }

  bool get _isTeacher {
    return widget.currentUser.rol.toUpperCase() == 'MAESTRO';
  }

  bool get _canUseAdminPanel {
    return _isDirector || _isTeacher;
  }

  bool get _canManageFullAdmin {
    return _isDirector;
  }

  List<AdminSection> get _activeSections {
    return _sections.where((section) => section.activo).toList();
  }

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
      final students = await _adminService.fetchStudents(authToken: _token);
      final sections = await _adminService.fetchSections(authToken: _token);

      List<AcademicUser> users = [];
      List<TeacherSectionLink> links = [];

      if (_canManageFullAdmin) {
        users = await _adminService.fetchUsers(authToken: _token);
        links = await _adminService.fetchTeacherSectionLinks(authToken: _token);
      }

      final classroomMode = await LocalClassroomModeStorage.getCurrent();

      JornadaEvaluacion? activeJornada;
      int? selectedSectionId = classroomMode?.seccionId;

      if (selectedSectionId == null && sections.isNotEmpty) {
        selectedSectionId = sections.first.id;
      }

      if (selectedSectionId != null) {
        try {
          activeJornada = await _jornadaService.obtenerJornadaActiva(
            authToken: _token,
            seccionId: selectedSectionId,
          );
        } catch (_) {
          activeJornada = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _students = students;
        _sections = sections;
        _users = users;
        _teacherSectionLinks = links;
        _classroomMode = classroomMode;
        _selectedClassroomSectionId = selectedSectionId;
        _activeJornada = activeJornada;
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

  Future<void> _runAction(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();
      await _loadAdminData();

      if (!mounted) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Operacion realizada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  String _sectionName(int? seccionId) {
    if (seccionId == null) return 'Sin seccion';

    final matches = _sections.where((section) => section.id == seccionId);

    if (matches.isEmpty) {
      return 'Seccion $seccionId';
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
    if (!_canUseAdminPanel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel del personal educativo')),
        body: const Center(
          child: Text(
            'Este panel esta disponible para direccion o docentes.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final tabs = _canManageFullAdmin
        ? const [
            Tab(icon: Icon(Icons.meeting_room_outlined), text: 'Modo aula'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Estudiantes'),
            Tab(icon: Icon(Icons.class_outlined), text: 'Secciones'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Usuarios'),
            Tab(icon: Icon(Icons.link_outlined), text: 'Docente-seccion'),
          ]
        : const [
            Tab(icon: Icon(Icons.meeting_room_outlined), text: 'Modo aula'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Estudiantes'),
          ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _canManageFullAdmin ? 'Panel administrativo' : 'Panel docente',
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _loadAdminData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
          ],
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    if (_canManageFullAdmin) {
      return TabBarView(
        children: [
          _buildClassroomModeTab(),
          _buildStudentsTab(),
          _buildSectionsTab(),
          _buildUsersTab(),
          _buildTeacherSectionTab(),
        ],
      );
    }

    return TabBarView(
      children: [_buildClassroomModeTab(), _buildStudentsTab()],
    );
  }

  Widget _buildClassroomModeTab() {
    final selectedId = _selectedClassroomSectionId;
    final activeMode = _classroomMode;
    final activeJornada = _activeJornada;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.meeting_room_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Modo aula',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Activa una jornada semanal para que los estudiantes ingresen solo con su PIN dentro de la seccion seleccionada.',
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  initialValue: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Seccion',
                    border: OutlineInputBorder(),
                  ),
                  items: _activeSections
                      .map(
                        (section) => DropdownMenuItem(
                          value: section.id,
                          child: Text(section.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClassroomSectionId = value;
                      _activeJornada = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (activeMode != null)
                  _buildCurrentClassroomModeCard(activeMode)
                else
                  const _InfoBox(
                    icon: Icons.info_outline,
                    text: 'No hay modo aula guardado en este dispositivo.',
                  ),
                const SizedBox(height: 16),
                if (activeJornada != null)
                  _buildActiveJornadaCard(activeJornada)
                else
                  const _InfoBox(
                    icon: Icons.event_busy_outlined,
                    text:
                        'No se encontro jornada activa para la seccion seleccionada.',
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: selectedId == null
                          ? null
                          : () => _activateClassroomMode(selectedId),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Activar jornada'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedId == null
                          ? null
                          : () => _checkActiveJornada(selectedId),
                      icon: const Icon(Icons.search_outlined),
                      label: const Text('Verificar jornada'),
                    ),
                    OutlinedButton.icon(
                      onPressed: activeMode == null
                          ? null
                          : () => _goToStudentPinScreen(),
                      icon: const Icon(Icons.login_outlined),
                      label: const Text('Ir a PIN estudiante'),
                    ),
                    OutlinedButton.icon(
                      onPressed: activeMode == null
                          ? null
                          : () => _clearClassroomMode(),
                      icon: const Icon(Icons.logout_outlined),
                      label: const Text('Desactivar modo aula local'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentClassroomModeCard(ClassroomModeState mode) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Modo aula activo en este dispositivo: ${mode.sectionDisplayName}\n'
                'Jornada ID: ${mode.jornadaId}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJornadaCard(JornadaEvaluacion jornada) {
    return Card(
      color: Colors.green.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_available_outlined, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Jornada activa en backend.\n'
                'Seccion: ${_sectionName(jornada.seccionId)}\n'
                'Lectura: ${jornada.pruebaLecturaActiva ? "activa" : "inactiva"} - '
                'Fonologia: ${jornada.pruebaFonologiaActiva ? "activa" : "inactiva"}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar jornada',
              onPressed: () => _closeJornada(jornada.id),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateClassroomMode(int seccionId) async {
    final sectionName = _sectionName(seccionId);

    await _runAction(() async {
      JornadaEvaluacion jornada;

      try {
        jornada = await _jornadaService.activarJornada(
          authToken: _token,
          seccionId: seccionId,
          pruebaLecturaActiva: true,
          pruebaFonologiaActiva: true,
          duracionHoras: 8,
        );
      } catch (error) {
        final message = error.toString();

        if (!message.contains('Ya existe una jornada activa')) {
          rethrow;
        }

        jornada = await _jornadaService.obtenerJornadaActiva(
          authToken: _token,
          seccionId: seccionId,
        );
      }

      await LocalClassroomModeStorage.saveFromJornada(
        jornada: jornada,
        sectionDisplayName: sectionName,
      );

      await _refreshOfflineCacheForSection(seccionId);

      if (!mounted) return;

      setState(() {
        _classroomMode = ClassroomModeState(
          seccionId: jornada.seccionId,
          sectionDisplayName: sectionName,
          jornadaId: jornada.id,
          fechaInicio: jornada.fechaInicio,
          fechaExpiracion: jornada.fechaExpiracion,
          pruebaLecturaActiva: jornada.pruebaLecturaActiva,
          pruebaFonologiaActiva: jornada.pruebaFonologiaActiva,
        );
        _activeJornada = jornada;
        _selectedClassroomSectionId = seccionId;
      });
    });
  }

  Future<void> _checkActiveJornada(int seccionId) async {
    await _runAction(() async {
      final jornada = await _jornadaService.obtenerJornadaActiva(
        authToken: _token,
        seccionId: seccionId,
      );

      await LocalClassroomModeStorage.saveFromJornada(
        jornada: jornada,
        sectionDisplayName: _sectionName(seccionId),
      );

      if (!mounted) return;

      setState(() {
        _activeJornada = jornada;
        _classroomMode = ClassroomModeState(
          seccionId: jornada.seccionId,
          sectionDisplayName: _sectionName(seccionId),
          jornadaId: jornada.id,
          fechaInicio: jornada.fechaInicio,
          fechaExpiracion: jornada.fechaExpiracion,
          pruebaLecturaActiva: jornada.pruebaLecturaActiva,
          pruebaFonologiaActiva: jornada.pruebaFonologiaActiva,
        );
      });
    });
  }

  Future<void> _closeJornada(int jornadaId) async {
    await _runAction(() async {
      await _jornadaService.cerrarJornada(
        authToken: _token,
        jornadaId: jornadaId,
      );

      await LocalClassroomModeStorage.clear();

      if (!mounted) return;

      setState(() {
        _classroomMode = null;
        _activeJornada = null;
      });
    });
  }

  Future<void> _clearClassroomMode() async {
    await LocalClassroomModeStorage.clear();

    if (!mounted) return;

    setState(() {
      _classroomMode = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Modo aula local desactivado.')),
    );
  }

  void _goToStudentPinScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );
  }

  Widget _buildStudentsTab() {
    return _buildTabWithAction(
      actionLabel: 'Nuevo estudiante',
      actionIcon: Icons.person_add_alt,
      onAction: _activeSections.isEmpty ? null : () => _showStudentDialog(),
      child: ListView.separated(
        itemCount: _students.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final student = _students[index];

          return ListTile(
            title: Text(student.nombreCompleto),
            subtitle: Text(
              'PIN: ${student.pinCorto ?? "-"} - ${_sectionName(student.seccionId)}\n'
              'Consentimiento: ${student.consentimientoFirmado ? "SI" : "NO"}',
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(student.activo ? 'Activo' : 'Inactivo')),
                IconButton(
                  onPressed: () => _showStudentDialog(student: student),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                ),
                IconButton(
                  onPressed: () => _regeneratePin(student),
                  icon: const Icon(Icons.password_outlined),
                  tooltip: 'Regenerar PIN',
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
      actionLabel: 'Nueva seccion',
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
                Chip(label: Text(section.activo ? 'Activa' : 'Inactiva')),
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
            subtitle: Text('${user.email} - ${user.rolTexto}'),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(user.activo ? 'Activo' : 'Inactivo')),
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
      actionLabel: 'Asignar seccion',
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
              tooltip: 'Eliminar asignacion',
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

  Future<void> _showStudentDialog({AdminStudent? student}) async {
    final codigoController = TextEditingController(
      text: student?.codigoEstudiante ?? '',
    );
    final nombresController = TextEditingController(
      text: student?.nombres ?? '',
    );
    final apellidosController = TextEditingController(
      text: student?.apellidos ?? '',
    );
    final fechaNacimientoController = TextEditingController(
      text: student?.fechaNacimiento ?? '',
    );
    final fechaConsentimientoController = TextEditingController(
      text: student?.fechaConsentimiento ?? _todayIsoDate(),
    );

    int selectedSectionId =
        student?.seccionId ??
        (_activeSections.isNotEmpty ? _activeSections.first.id : 0);

    bool activo = student?.activo ?? true;
    bool consentimientoFirmado = student?.consentimientoFirmado ?? true;

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
                      controller: codigoController,
                      decoration: const InputDecoration(
                        labelText: 'Codigo estudiante',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      controller: fechaNacimientoController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha nacimiento YYYY-MM-DD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedSectionId == 0
                          ? null
                          : selectedSectionId,
                      decoration: const InputDecoration(
                        labelText: 'Seccion',
                        border: OutlineInputBorder(),
                      ),
                      items: _activeSections
                          .map(
                            (section) => DropdownMenuItem(
                              value: section.id,
                              child: Text(section.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedSectionId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fechaConsentimientoController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha consentimiento YYYY-MM-DD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: consentimientoFirmado,
                      title: const Text('Consentimiento firmado'),
                      onChanged: (value) {
                        setDialogState(() {
                          consentimientoFirmado = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      value: activo,
                      title: const Text('Activo'),
                      onChanged: (value) {
                        setDialogState(() {
                          activo = value;
                        });
                      },
                    ),
                    if (student?.pinCorto != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.password_outlined),
                        title: Text('PIN actual: ${student!.pinCorto}'),
                        subtitle: const Text(
                          'El PIN se genera automaticamente. Use regenerar PIN si necesita cambiarlo.',
                        ),
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

    codigoController.dispose();
    nombresController.dispose();
    apellidosController.dispose();
    fechaNacimientoController.dispose();
    fechaConsentimientoController.dispose();

    if (saved != true) {
      return;
    }

    final codigo = codigoController.text.trim();
    final nombres = nombresController.text.trim();
    final apellidos = apellidosController.text.trim();
    final fechaNacimiento = fechaNacimientoController.text.trim();
    final fechaConsentimiento = fechaConsentimientoController.text.trim();

    await _runAction(() async {
      if (student == null) {
        await _adminService.createStudent(
          authToken: _token,
          codigoEstudiante: codigo.isEmpty ? null : codigo,
          nombres: nombres,
          apellidos: apellidos,
          fechaNacimiento: fechaNacimiento.isEmpty ? null : fechaNacimiento,
          seccionId: selectedSectionId,
          consentimientoFirmado: consentimientoFirmado,
          fechaConsentimiento: fechaConsentimiento.isEmpty
              ? null
              : fechaConsentimiento,
          activo: activo,
        );
      } else {
        await _adminService.updateStudent(
          authToken: _token,
          estudianteId: student.id,
          codigoEstudiante: codigo.isEmpty ? null : codigo,
          nombres: nombres,
          apellidos: apellidos,
          fechaNacimiento: fechaNacimiento.isEmpty ? null : fechaNacimiento,
          seccionId: selectedSectionId,
          consentimientoFirmado: consentimientoFirmado,
          fechaConsentimiento: fechaConsentimiento.isEmpty
              ? null
              : fechaConsentimiento,
          activo: activo,
        );
      }
    });
  }

  Future<void> _regeneratePin(AdminStudent student) async {
    await _runAction(() async {
      await _adminService.regenerateStudentPin(
        authToken: _token,
        estudianteId: student.id,
      );
    });
  }

  Future<void> _showSectionDialog({AdminSection? section}) async {
    final gradoController = TextEditingController(
      text: section?.grado.toString() ?? '3',
    );
    final nombreController = TextEditingController(text: section?.nombre ?? '');
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
              title: Text(section == null ? 'Nueva seccion' : 'Editar seccion'),
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
                        labelText: 'Nombre de seccion',
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

    gradoController.dispose();
    nombreController.dispose();
    turnoController.dispose();

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

  Future<void> _showUserDialog({AcademicUser? user}) async {
    final nombresController = TextEditingController(text: user?.nombres ?? '');
    final apellidosController = TextEditingController(
      text: user?.apellidos ?? '',
    );
    final emailController = TextEditingController(text: user?.email ?? '');
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
              title: Text(user == null ? 'Nuevo usuario' : 'Editar usuario'),
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
                          child: Text('Psicologa'),
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
                      obscuringCharacter: '*',
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

    nombresController.dispose();
    apellidosController.dispose();
    emailController.dispose();
    passwordController.dispose();
    gradoScopeController.dispose();

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
              title: const Text('Asignar docente a seccion'),
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
                      labelText: 'Seccion',
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

  Future<int> _refreshOfflineCacheForSection(int seccionId) async {
    final students = await _adminService.fetchStudents(authToken: _token);
    var cachedCount = 0;

    for (final student in students) {
      final pin = student.pinCorto?.trim();

      if (pin == null || pin.isEmpty) {
        continue;
      }

      if (student.seccionId != seccionId) {
        continue;
      }

      if (!student.activo || !student.consentimientoFirmado) {
        continue;
      }

      await LocalStudentCache.saveStudentByPin(
        pin: pin,
        student: Student.fromJson({
          'id': student.id,
          'codigo_estudiante': student.codigoEstudiante,
          'nombres': student.nombres,
          'apellidos': student.apellidos,
          'fecha_nacimiento': student.fechaNacimiento,
          'pin_corto': student.pinCorto,
          'seccion_id': student.seccionId,
          'consentimiento_firmado': student.consentimientoFirmado,
          'nivel_lectura': student.nivelLectura,
          'nivel_fonologia': student.nivelFonologia,
          'activo': student.activo,
        }),
      );

      cachedCount++;
    }

    return cachedCount;
  }

  String _todayIsoDate() {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
