import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';
import '../../../core/models/auth_user.dart';
import '../../../core/models/jornada_evaluacion.dart';
import '../../../core/repositories/auth_session_storage.dart';
import '../../../core/models/student.dart';
import '../../../core/repositories/local_classroom_mode_storage.dart';
import '../../../core/repositories/local_student_cache.dart';
import '../../../core/repositories/phonology_repository.dart';
import '../../../core/repositories/stimuli_repository.dart';
import '../../../core/services/admin_service.dart';
import '../../../core/services/jornada_service.dart';
import '../../auth/screens/pin_login_screen.dart';
import '../widgets/section_form_dialog.dart';

class AdminPanelScreen extends StatefulWidget {
  final AuthUser currentUser;
  final AdminService adminService;
  final JornadaService jornadaService;

  const AdminPanelScreen({
    super.key,
    required this.currentUser,
    this.adminService = const AdminService(),
    this.jornadaService = const JornadaService(),
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  AdminService get _adminService => widget.adminService;
  JornadaService get _jornadaService => widget.jornadaService;

  bool _isLoading = true;
  bool _isImportingStudents = false;
  bool _isPreparingClassroom = false;
  String? _errorMessage;
  int _loadGeneration = 0;
  String? _classroomModeNotice;

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

  @override
  void didUpdateWidget(covariant AdminPanelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id ||
        oldWidget.currentUser.rol != widget.currentUser.rol ||
        oldWidget.currentUser.accessToken != widget.currentUser.accessToken) {
      _students = [];
      _sections = [];
      _users = [];
      _teacherSectionLinks = [];
      _classroomMode = null;
      _classroomModeNotice = null;
      _activeJornada = null;
      _selectedClassroomSectionId = null;
      _loadAdminData();
    }
  }

  Future<void> _loadAdminData() async {
    final generation = ++_loadGeneration;
    final authToken = _token;
    final canManageFullAdmin = _canManageFullAdmin;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final students = await _adminService.fetchStudents(authToken: authToken);
      final sections = await _adminService.fetchSections(authToken: authToken);

      List<AcademicUser> users = [];
      List<TeacherSectionLink> links = [];

      if (canManageFullAdmin) {
        users = await _adminService.fetchUsers(authToken: authToken);
        links = await _adminService.fetchTeacherSectionLinks(
          authToken: authToken,
        );
      }

      if (!mounted || generation != _loadGeneration) return;

      var classroomMode = await LocalClassroomModeStorage.getCurrent();
      if (!mounted || generation != _loadGeneration) return;

      final activeSections = sections
          .where((section) => section.activo)
          .toList();
      final activeSectionIds = activeSections
          .map((section) => section.id)
          .toSet();
      String? classroomModeNotice;

      if (classroomMode != null &&
          !activeSectionIds.contains(classroomMode.seccionId)) {
        await LocalClassroomModeStorage.clear();
        classroomMode = null;
        classroomModeNotice =
            'Se desactivó el modo aula local porque la sección guardada '
            'no está entre tus secciones disponibles.';
      }

      if (!mounted || generation != _loadGeneration) return;

      JornadaEvaluacion? activeJornada;
      int? selectedSectionId =
          classroomMode?.seccionId ?? _selectedClassroomSectionId;

      if (!activeSectionIds.contains(selectedSectionId)) {
        selectedSectionId = activeSections.isEmpty
            ? null
            : activeSections.first.id;
      }

      if (selectedSectionId != null) {
        try {
          activeJornada = await _jornadaService.obtenerJornadaActiva(
            authToken: authToken,
            seccionId: selectedSectionId,
          );
        } catch (_) {
          activeJornada = null;
        }
      }

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _students = students;
        _sections = sections;
        _users = users;
        _teacherSectionLinks = links;
        _classroomMode = classroomMode;
        _classroomModeNotice = classroomModeNotice;
        _selectedClassroomSectionId = selectedSectionId;
        _activeJornada = activeJornada;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String Function()? successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();
      await _loadAdminData();

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            successMessage?.call() ?? 'Operacion realizada correctamente.',
          ),
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

  Future<void> _runClassroomAction(
    Future<void> Function() action, {
    String Function()? successMessage,
  }) async {
    if (_isPreparingClassroom) return;
    setState(() => _isPreparingClassroom = true);
    try {
      await _runAction(action, successMessage: successMessage);
    } finally {
      if (mounted) setState(() => _isPreparingClassroom = false);
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
    if (!_canUseAdminPanel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel del personal educativo')),
        body: const Center(
          child: Text(
            'Este panel está disponible para dirección o docentes.',
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
            Tab(icon: Icon(Icons.link_outlined), text: 'Docente-sección'),
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
              onPressed: _isLoading || _isPreparingClassroom
                  ? null
                  : _loadAdminData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar',
            ),
            IconButton(
              onPressed: _isPreparingClassroom ? null : _logoutStaffSession,
              icon: const Icon(Icons.logout_outlined),
              tooltip: 'Cerrar sesión',
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
    final availableSections = _activeSections;
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
                  'Activa una jornada semanal para que los estudiantes ingresen solo con su PIN dentro de la sección seleccionada.',
                ),
                const SizedBox(height: 18),
                if (availableSections.isEmpty) ...[
                  _InfoBox(
                    icon: Icons.info_outline,
                    text: _isTeacher
                        ? 'No tienes secciones activas asignadas. '
                              'Solicita la asignación al director.'
                        : 'No hay secciones activas disponibles.',
                  ),
                  const SizedBox(height: 16),
                ],
                DropdownButtonFormField<int>(
                  key: ValueKey(selectedId),
                  initialValue: selectedId,
                  decoration: const InputDecoration(
                    labelText: 'Sección',
                    border: OutlineInputBorder(),
                  ),
                  items: availableSections
                      .map(
                        (section) => DropdownMenuItem(
                          value: section.id,
                          child: Text(section.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: availableSections.isEmpty || _isPreparingClassroom
                      ? null
                      : (value) {
                          setState(() {
                            _selectedClassroomSectionId = value;
                            _activeJornada = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                if (_classroomModeNotice != null) ...[
                  _InfoBox(
                    icon: Icons.info_outline,
                    text: _classroomModeNotice!,
                  ),
                  const SizedBox(height: 16),
                ],
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
                        'No se encontró jornada activa para la sección seleccionada.',
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: selectedId == null || _isPreparingClassroom
                          ? null
                          : () => _activateClassroomMode(selectedId),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Activar jornada'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedId == null || _isPreparingClassroom
                          ? null
                          : _downloadSelectedSection,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Descargar sección'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedId == null || _isPreparingClassroom
                          ? null
                          : () => _checkActiveJornada(selectedId),
                      icon: const Icon(Icons.search_outlined),
                      label: const Text('Verificar jornada'),
                    ),
                    OutlinedButton.icon(
                      onPressed: activeMode == null || _isPreparingClassroom
                          ? null
                          : () => _goToStudentPinScreen(),
                      icon: const Icon(Icons.login_outlined),
                      label: const Text('Ir a PIN estudiante'),
                    ),
                    OutlinedButton.icon(
                      onPressed: activeMode == null || _isPreparingClassroom
                          ? null
                          : () => _clearClassroomMode(),
                      icon: const Icon(Icons.logout_outlined),
                      label: const Text('Desactivar modo aula local'),
                    ),
                  ],
                ),
                if (_isPreparingClassroom) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Preparando la sección para uso sin conexión...'),
                ],
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
                'Sección: ${_sectionName(jornada.seccionId)}\n'
                'Lectura: ${jornada.pruebaLecturaActiva ? "activa" : "inactiva"} - '
                'Fonología: ${jornada.pruebaFonologiaActiva ? "activa" : "inactiva"}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Cerrar jornada',
              onPressed: _isPreparingClassroom
                  ? null
                  : () => _closeJornada(jornada.id),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadSelectedSection() async {
    final seccionId = _selectedClassroomSectionId;
    if (seccionId == null) {
      throw StateError('Selecciona una sección disponible para descargar.');
    }
    await _activateClassroomMode(seccionId, announceDownload: true);
  }

  Future<void> _activateClassroomMode(
    int seccionId, {
    bool announceDownload = false,
  }) async {
    final sectionName = _sectionName(seccionId);
    final authToken = _token;
    final userId = widget.currentUser.id;
    final userRole = widget.currentUser.rol;
    var downloadedCount = 0;

    void ensureCurrentSession() {
      if (!mounted ||
          _token != authToken ||
          widget.currentUser.id != userId ||
          widget.currentUser.rol != userRole) {
        throw StateError('La sesión cambió. Vuelve a preparar tu sección.');
      }
    }

    await _runClassroomAction(
      () async {
        final students = await _fetchOfflineStudentsForSection(
          seccionId,
          authToken: authToken,
        );
        ensureCurrentSession();
        if (announceDownload && students.isEmpty) {
          throw StateError(
            'La sección no tiene estudiantes habilitados para descargar.',
          );
        }
        final lectura = await StimuliRepository().loadLecturaStimuli();
        final fonologia = await PhonologyRepository().loadPhonologyStimuli();
        if (lectura.isEmpty || fonologia.isEmpty) {
          throw StateError(
            'Faltan recursos para ejecutar las pruebas sin conexión.',
          );
        }
        ensureCurrentSession();
        JornadaEvaluacion jornada;

        try {
          jornada = await _jornadaService.activarJornada(
            authToken: authToken,
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
            authToken: authToken,
            seccionId: seccionId,
          );
        }

        ensureCurrentSession();
        if (jornada.seccionId != seccionId ||
            !jornada.estaActiva ||
            jornada.estaExpirada) {
          throw StateError('La sección no tiene una jornada vigente.');
        }
        final previousMode = await LocalClassroomModeStorage.getCurrent();
        ensureCurrentSession();
        if (previousMode?.seccionId == seccionId) {
          await LocalClassroomModeStorage.clear();
          ensureCurrentSession();
          setState(() => _classroomMode = null);
        }
        await LocalStudentCache.replaceStudentsForSection(
          seccionId: seccionId,
          studentsByPin: students,
        );
        ensureCurrentSession();
        await LocalClassroomModeStorage.saveFromJornada(
          jornada: jornada,
          sectionDisplayName: sectionName,
        );

        ensureCurrentSession();
        downloadedCount = students.length;

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
      },
      successMessage: announceDownload
          ? () =>
                'Sección $sectionName descargada: $downloadedCount '
                '${downloadedCount == 1 ? "estudiante habilitado" : "estudiantes habilitados"}. '
                'Disponible sin conexión mientras la jornada siga vigente.'
          : null,
    );
  }

  Future<void> _checkActiveJornada(int seccionId) async {
    await _runClassroomAction(() async {
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

  Future<void> _logoutStaffSession() async {
    await AuthSessionStorage.clearSession();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );
  }

  void _goToStudentPinScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );
  }

  Widget _buildStudentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _activeSections.isEmpty
                      ? null
                      : () => _showStudentDialog(),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Nuevo estudiante'),
                ),
                OutlinedButton.icon(
                  onPressed: _isImportingStudents
                      ? null
                      : _importStudentsFromFile,
                  icon: _isImportingStudents
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    _isImportingStudents
                        ? 'Importando...'
                        : 'Importar CSV/XLSX',
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
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
                      onPressed:
                          student.consentimientoFirmado &&
                              student.fechaConsentimiento != null
                          ? () => _regeneratePin(student)
                          : null,
                      icon: const Icon(Icons.password_outlined),
                      tooltip: 'Regenerar PIN',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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

  Future<void> _importStudentsFromFile() async {
    final messenger = ScaffoldMessenger.of(context);

    final picked = await fp.FilePicker.platform.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: false,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final filePath = picked.files.single.path;

    if (filePath == null || filePath.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo leer la ruta del archivo seleccionado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isImportingStudents = true;
    });

    try {
      final result = await _adminService.importStudentsFile(
        authToken: _token,
        filePath: filePath,
      );

      await _loadAdminData();

      if (!mounted) return;

      await _showImportResultDialog(result);
    } catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImportingStudents = false;
        });
      }
    }
  }

  Future<void> _showImportResultDialog(StudentImportResponse result) async {
    final errors = result.results.where((item) => item.isError).toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Resultado de importación'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Archivo: ${result.filename}'),
                  const SizedBox(height: 8),
                  Text('Filas leidas: ${result.totalRows}'),
                  Text('Creados: ${result.createdCount}'),
                  Text('Actualizados: ${result.updatedCount}'),
                  Text('Omitidos: ${result.skippedCount}'),
                  Text('Errores: ${result.errorCount}'),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Errores encontrados:',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ...errors
                        .take(8)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Fila ${item.rowNumber}: ${item.message}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                    if (errors.length > 8)
                      Text('Y ${errors.length - 8} errores mas...'),
                  ],
                  if (result.errorCount == 0) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Importación completada. Los estudiantes con consentimiento firmado ya tienen PIN generado automáticamente.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showStudentDialog({AdminStudent? student}) async {
    final formKey = GlobalKey<FormState>();
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

    int? selectedSectionId = student == null
        ? (_activeSections.isNotEmpty ? _activeSections.first.id : null)
        : student.seccionId;
    if (!_activeSections.any((section) => section.id == selectedSectionId)) {
      selectedSectionId = null;
    }
    String? sectionError;
    String? activationError;

    bool activo = student?.activo ?? true;
    bool consentimientoFirmado = student?.consentimientoFirmado ?? true;
    Future<bool?>? dialogCompleted;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        dialogCompleted = ModalRoute.of<bool>(dialogContext)!.completed;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                student == null ? 'Nuevo estudiante' : 'Editar estudiante',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nombresController,
                        decoration: const InputDecoration(
                          labelText: 'Nombres',
                          errorMaxLines: 2,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingresa los nombres del estudiante.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: apellidosController,
                        decoration: const InputDecoration(
                          labelText: 'Apellidos',
                          errorMaxLines: 2,
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingresa los apellidos del estudiante.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fechaNacimientoController,
                        validator: _validateStudentBirthDate,
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          labelText: 'Fecha nacimiento',
                          errorMaxLines: 3,
                          helperMaxLines: 2,
                          helperText:
                              'Edad permitida: 8 a 9 años cumplidos.\n'
                              'Use YYYY-MM-DD o DD/MM/YYYY',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_outlined),
                            onPressed: () => _pickDateIntoController(
                              controller: fechaNacimientoController,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedSectionId,
                        decoration: InputDecoration(
                          labelText: 'Sección',
                          errorText: sectionError,
                          border: const OutlineInputBorder(),
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
                            sectionError = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fechaConsentimientoController,
                        enabled: consentimientoFirmado,
                        validator: (value) {
                          if (!consentimientoFirmado) return null;
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa la fecha del consentimiento firmado.';
                          }
                          return _dateInputError(
                            value,
                            fieldLabel: 'La fecha de consentimiento',
                          );
                        },
                        keyboardType: TextInputType.datetime,
                        decoration: InputDecoration(
                          labelText: 'Fecha consentimiento',
                          errorMaxLines: 3,
                          helperText: consentimientoFirmado
                              ? 'Use YYYY-MM-DD o DD/MM/YYYY'
                              : 'Solo se registra con consentimiento firmado.',
                          helperMaxLines: 2,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_outlined),
                            onPressed: consentimientoFirmado
                                ? () => _pickDateIntoController(
                                    controller: fechaConsentimientoController,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: consentimientoFirmado,
                        title: const Text('Consentimiento firmado'),
                        subtitle: const Text(
                          'Sin consentimiento, guarda al estudiante como inactivo.',
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            consentimientoFirmado = value;
                            activationError = null;
                          });
                        },
                      ),
                      SwitchListTile(
                        value: activo,
                        title: const Text('Activo'),
                        onChanged: (value) {
                          setDialogState(() {
                            activo = value;
                            activationError = null;
                          });
                        },
                      ),
                      if (activationError != null)
                        Text(
                          activationError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (student?.pinCorto != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.password_outlined),
                          title: Text('PIN actual: ${student!.pinCorto}'),
                          subtitle: const Text(
                            'El PIN se genera automáticamente. Use regenerar PIN si necesita cambiarlo.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final fieldsValid = formKey.currentState!.validate();
                    setDialogState(() {
                      activationError = activo && !consentimientoFirmado
                          ? 'Para activar al estudiante se requiere consentimiento informado firmado.'
                          : null;
                    });
                    if (selectedSectionId == null) {
                      setDialogState(() {
                        sectionError = 'Selecciona una sección disponible.';
                      });
                      return;
                    }
                    if (!fieldsValid || activationError != null) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    final nombres = nombresController.text.trim();
    final apellidos = apellidosController.text.trim();
    final nacimientoInput = fechaNacimientoController.text;
    final consentimientoInput = fechaConsentimientoController.text;

    // El diálogo sigue montado durante su animación de salida.
    await dialogCompleted;
    nombresController.dispose();
    apellidosController.dispose();
    fechaNacimientoController.dispose();
    fechaConsentimientoController.dispose();

    final seccionId = selectedSectionId;
    if (saved != true || seccionId == null || !mounted) {
      return;
    }

    String fechaNacimiento;
    String? fechaConsentimiento;

    try {
      final parsedBirthDate = _normalizeDateInput(
        nacimientoInput,
        fieldLabel: 'Fecha de nacimiento',
      );
      if (parsedBirthDate == null) {
        throw Exception('Ingresa la fecha de nacimiento del estudiante.');
      }
      fechaNacimiento = parsedBirthDate;
      fechaConsentimiento = consentimientoFirmado
          ? _normalizeDateInput(
              consentimientoInput,
              fieldLabel: 'Fecha de consentimiento',
            )
          : null;

      if (consentimientoFirmado && fechaConsentimiento == null) {
        throw Exception(
          'Debe registrar fecha de consentimiento si el consentimiento esta firmado.',
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
      return;
    }

    await _runAction(() async {
      if (student == null) {
        await _adminService.createStudent(
          authToken: _token,
          nombres: nombres,
          apellidos: apellidos,
          fechaNacimiento: fechaNacimiento,
          seccionId: seccionId,
          consentimientoFirmado: consentimientoFirmado,
          fechaConsentimiento: fechaConsentimiento,
          activo: activo,
        );
      } else {
        await _adminService.updateStudent(
          authToken: _token,
          estudianteId: student.id,
          nombres: nombres,
          apellidos: apellidos,
          fechaNacimiento: fechaNacimiento,
          seccionId: seccionId,
          consentimientoFirmado: consentimientoFirmado,
          fechaConsentimiento: fechaConsentimiento,
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
    final data = await showDialog<SectionFormData>(
      context: context,
      builder: (_) => SectionFormDialog(section: section),
    );

    if (data == null || !mounted) {
      return;
    }

    await _runAction(() async {
      if (section == null) {
        await _adminService.createSection(
          authToken: _token,
          nombre: data.nombre,
          turno: data.turno,
          activo: data.activo,
        );
      } else {
        await _adminService.updateSection(
          authToken: _token,
          seccionId: section.id,
          nombre: data.nombre,
          turno: data.turno,
          activo: data.activo,
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
    String rol = user?.rol.toUpperCase() ?? 'MAESTRO';
    bool activo = user?.activo ?? true;
    String? emailError;

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
                      onChanged: (_) {
                        if (emailError != null) {
                          setDialogState(() {
                            emailError = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Correo institucional',
                        helperText: 'Ejemplo: jlinarez@edu.com',
                        errorText: emailError,
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
                          child: Text('Director'),
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
                  onPressed: () {
                    final validationError = _validateInstitutionalEmail(
                      emailController.text,
                    );

                    if (validationError != null) {
                      setDialogState(() {
                        emailError = validationError;
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(true);
                  },
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
    if (saved != true) {
      return;
    }

    final nombres = nombresController.text.trim();
    final apellidos = apellidosController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final gradoScope = user?.gradoScope;

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

  String? _validateInstitutionalEmail(String value) {
    final email = value.trim();
    final emailPattern = RegExp(
      r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@(?:[A-Z0-9-]+\.)?edu\.com$",
      caseSensitive: false,
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Ingresa un correo institucional válido terminado en .edu.com.';
    }

    return null;
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

  Future<Map<String, Student>> _fetchOfflineStudentsForSection(
    int seccionId, {
    required String? authToken,
  }) async {
    final students = await _adminService.fetchStudents(authToken: authToken);
    final studentsByPin = <String, Student>{};

    for (final student in students) {
      if (student.seccionId != seccionId) {
        continue;
      }

      if (!student.activo || !student.consentimientoFirmado) {
        continue;
      }

      final pin = student.pinCorto?.trim();
      if (pin == null || !RegExp(r'^\d{4}$').hasMatch(pin)) {
        throw StateError(
          'El estudiante ${student.nombreCompleto} no tiene un PIN válido. '
          'Corrige su PIN antes de descargar la sección.',
        );
      }
      if (studentsByPin.containsKey(pin)) {
        throw StateError(
          'La sección contiene PIN duplicados. Revisa el padrón.',
        );
      }
      studentsByPin[pin] = Student.fromJson({
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
      });
    }

    return studentsByPin;
  }

  Future<void> _pickDateIntoController({
    required TextEditingController controller,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    var initialDate = _tryParseDateInput(controller.text) ?? DateTime.now();

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selected == null) {
      return;
    }

    controller.text = _toIsoDate(selected);
  }

  String? _validateStudentBirthDate(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return 'Ingresa la fecha de nacimiento del estudiante.';
    }
    final today = DateTime.now().toUtc().subtract(const Duration(hours: 5));
    final error = _dateInputError(
      text,
      fieldLabel: 'La fecha de nacimiento',
      today: today,
    );
    if (error != null) return error;

    final birthDate = _tryParseDateInput(text)!;
    final birthdayHasPassed =
        today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    final age = today.year - birthDate.year - (birthdayHasPassed ? 0 : 1);
    if (age != 8 && age != 9) {
      return 'El estudiante debe tener entre 8 y 9 años cumplidos.';
    }
    return null;
  }

  String? _dateInputError(
    String raw, {
    required String fieldLabel,
    DateTime? today,
  }) {
    final text = raw.trim();

    if (text.isEmpty) {
      return null;
    }

    final parsed = _tryParseDateInput(text);

    if (parsed == null) {
      return '$fieldLabel debe tener formato YYYY-MM-DD o DD/MM/YYYY.';
    }

    final currentDate = today ?? DateTime.now();
    final parsedOnly = DateTime(parsed.year, parsed.month, parsed.day);
    final todayOnly = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );

    if (parsedOnly.isAfter(todayOnly)) {
      return '$fieldLabel no puede ser futura.';
    }

    return null;
  }

  String? _normalizeDateInput(String raw, {required String fieldLabel}) {
    final error = _dateInputError(raw, fieldLabel: fieldLabel);
    if (error != null) throw Exception(error);
    final parsed = _tryParseDateInput(raw);
    return parsed == null ? null : _toIsoDate(parsed);
  }

  DateTime? _tryParseDateInput(String raw) {
    final text = raw.trim();

    if (text.isEmpty) {
      return null;
    }

    final isoMatch = RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$',
    ).firstMatch(text);

    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);

      return _buildValidDate(year, month, day);
    }

    final localMatch = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$',
    ).firstMatch(text);

    if (localMatch != null) {
      final day = int.tryParse(localMatch.group(1)!);
      final month = int.tryParse(localMatch.group(2)!);
      final year = int.tryParse(localMatch.group(3)!);

      return _buildValidDate(year, month, day);
    }

    return null;
  }

  DateTime? _buildValidDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) {
      return null;
    }

    if (year < 1900 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }

    return date;
  }

  String _toIsoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
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
