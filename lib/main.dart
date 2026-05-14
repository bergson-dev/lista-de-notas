import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BigDayApp());
}

class BigDayApp extends StatelessWidget {
  const BigDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Big Day To-Do',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- Model ---
class Task {
  final String id;
  String title;
  String description;
  String category;
  bool isCompleted;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.isCompleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'],
    title: json['title'],
    description: json['description'] ?? '',
    category: json['category'],
    isCompleted: json['isCompleted'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

// --- Main Navigation Screen ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  List<Task> _tasks = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // --- Persistence Logic ---
  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      setState(() {
        _tasks = decoded.map((item) => Task.fromJson(item)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_tasks.map((t) => t.toJson()).toList());
    await prefs.setString('tasks', encoded);
  }

  // --- Task Operations ---
  void _addTask(String title, String category, String description) {
    HapticFeedback.mediumImpact();
    final newTask = Task(
      id: DateTime.now().toString(),
      title: title,
      category: category,
      description: description,
      createdAt: DateTime.now(),
    );

    setState(() {
      _tasks.insert(0, newTask);
      _saveTasks();
    });

    if (_selectedIndex == 0) {
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 500),
      );
    }
  }

  void _editTask(String id, String title, String category, String description) {
    HapticFeedback.mediumImpact();
    int index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      setState(() {
        _tasks[index].title = title;
        _tasks[index].category = category;
        _tasks[index].description = description;
        _saveTasks();
      });
    }
  }

  void _removeTask(Task task) {
    HapticFeedback.heavyImpact();
    int index = _tasks.indexOf(task);
    if (index != -1) {
      setState(() {
        _tasks.removeAt(index);
        _saveTasks();
      });

      if (_selectedIndex == 0) {
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => const SizedBox.shrink(),
          duration: const Duration(milliseconds: 400),
        );
      }
    }
  }

  void _toggleTaskStatus(Task task) {
    HapticFeedback.selectionClick();
    int index = _tasks.indexOf(task);
    if (index != -1) {
      setState(() {
        _tasks[index].isCompleted = !_tasks[index].isCompleted;
        _saveTasks();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF334155),
                ],
              ),
            ),
          ),
          IndexedStack(
            index: _selectedIndex,
            children: [
              ToDoListScreen(
                tasks: _tasks,
                listKey: _listKey,
                onToggle: _toggleTaskStatus,
                onRemove: _removeTask,
                onEdit: _showEditTaskSheet,
              ),
              DashboardScreen(tasks: _tasks),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildCustomNavBar(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildCustomFAB(),
    );
  }

  Widget _buildCustomNavBar() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.list_rounded, "Tarefas", 0),
              const SizedBox(width: 40),
              _navItem(Icons.grid_view_rounded, "Dashboard", 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.white.withOpacity(0.4),
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : Colors.white.withOpacity(0.4),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomFAB() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showAddTaskSheet(context),
        child: Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    String selectedCategory = 'Pessoal';
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final List<String> categories = ['Trabalho', 'Pessoal', 'Saúde', 'Estudo'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 32,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nova Tarefa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'O que precisa ser feito?',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Adicione uma descrição (opcional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Categoria',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: categories.map((cat) {
                  final isSelected = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) =>
                        setModalState(() => selectedCategory = cat),
                    selectedColor: const Color(0xFF6366F1),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.05),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      _addTask(
                        titleController.text,
                        selectedCategory,
                        descController.text,
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Criar Tarefa',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTaskSheet(BuildContext context, Task task) {
    String selectedCategory = task.category;
    final TextEditingController titleController = TextEditingController(
      text: task.title,
    );
    final TextEditingController descController = TextEditingController(
      text: task.description,
    );
    final List<String> categories = ['Trabalho', 'Pessoal', 'Saúde', 'Estudo'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 32,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Editar Tarefa',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'O que precisa ser feito?',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Adicione uma descrição (opcional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Categoria',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: categories.map((cat) {
                  final isSelected = selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) =>
                        setModalState(() => selectedCategory = cat),
                    selectedColor: const Color(0xFF6366F1),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.05),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      _editTask(
                        task.id,
                        titleController.text,
                        selectedCategory,
                        descController.text,
                      );
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Salvar Alterações',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Task List Screen ---
class ToDoListScreen extends StatefulWidget {
  final List<Task> tasks;
  final GlobalKey<AnimatedListState> listKey;
  final Function(Task) onToggle;
  final Function(Task) onRemove;
  final Function(BuildContext, Task) onEdit;

  const ToDoListScreen({
    super.key,
    required this.tasks,
    required this.listKey,
    required this.onToggle,
    required this.onRemove,
    required this.onEdit,
  });

  @override
  State<ToDoListScreen> createState() => _ToDoListScreenState();
}

class _ToDoListScreenState extends State<ToDoListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredTasks = widget.tasks
        .where(
          (t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: widget.tasks.isEmpty
                ? _buildEmptyState()
                : AnimatedList(
                    key: widget.listKey,
                    initialItemCount: filteredTasks.length,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemBuilder: (context, index, animation) {
                      return _buildTaskItem(
                        filteredTasks[index],
                        animation,
                        index,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar tarefas...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minha Jornada',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Foque no que realmente importa.',
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tudo limpo por aqui!',
            style: TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Task task, Animation<double> animation, int index) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Dismissible(
            key: Key(task.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => widget.onRemove(task),
            background: _buildDismissBackground(),
            child: GestureDetector(
              onTap: () => widget.onToggle(task),
              onLongPress: () => widget.onEdit(context, task),
              child: _buildGlassCard(task),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(Task task) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(task.isCompleted ? 0.05 : 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              _PriorityIcon(category: task.category),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(
                          task.isCompleted ? 0.5 : 0.9,
                        ),
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          task.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      task.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusIndicator(isCompleted: task.isCompleted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
    );
  }
}

// --- Dashboard Screen ---
class DashboardScreen extends StatelessWidget {
  final List<Task> tasks;
  const DashboardScreen({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    int completed = tasks.where((t) => t.isCompleted).length;
    int pending = tasks.length - completed;
    double progress = tasks.isEmpty ? 0 : completed / tasks.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 24),
            _buildGlassContainer(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progresso Geral',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Seu desempenho hoje',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white10,
                    color: const Color(0xFF6366F1),
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Concluídas',
                    completed.toString(),
                    Icons.check_circle_outline,
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Pendentes',
                    pending.toString(),
                    Icons.pending_actions,
                    Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Por Categoria',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoryStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return _buildGlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStats() {
    Map<String, int> catCounts = {};
    for (var t in tasks) {
      catCounts[t.category] = (catCounts[t.category] ?? 0) + 1;
    }
    if (catCounts.isEmpty) {
      return const Center(
        child: Text(
          'Sem dados de categorias',
          style: TextStyle(color: Colors.white24),
        ),
      );
    }
    return Column(
      children: catCounts.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildGlassContainer(
            child: Row(
              children: [
                _PriorityIcon(category: entry.key),
                const SizedBox(width: 16),
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  entry.value.toString(),
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// --- Reusable Widgets ---
class _PriorityIcon extends StatelessWidget {
  final String category;
  const _PriorityIcon({required this.category});
  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    switch (category) {
      case 'Trabalho':
        color = const Color(0xFF6366F1);
        icon = Icons.work_outline;
        break;
      case 'Saúde':
        color = const Color(0xFFEC4899);
        icon = Icons.favorite_outline;
        break;
      case 'Estudo':
        color = const Color(0xFF10B981);
        icon = Icons.book_outlined;
        break;
      default:
        color = const Color(0xFFF59E0B);
        icon = Icons.person_outline;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool isCompleted;
  const _StatusIndicator({required this.isCompleted});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted ? const Color(0xFF10B981) : Colors.white24,
          width: 2,
        ),
        color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
      ),
      child: isCompleted
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
